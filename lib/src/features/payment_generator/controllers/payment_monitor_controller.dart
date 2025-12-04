import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pagocrypto/src/core/config/chain_config.dart';
import 'package:pagocrypto/src/core/services/moralis_service.dart';
import 'package:pagocrypto/src/features/payment_generator/models/received_transaction.dart';

/// Payment status enum for monitoring state.
enum PaymentStatus { monitoring, partiallyPaid, completed, error }

/// Controller to monitor incoming ERC-20 token payments.
///
/// This controller uses block-cursor anchoring to monitor payments from a
/// specific starting block.
///
/// UPDATED: Uses MoralisService and manual refresh (pull-to-refresh) instead of polling
/// to respect API rate limits (Free Tier).
class PaymentMonitorController extends ChangeNotifier {
  // --- Dependencies & Config ---
  final MoralisService _moralisService;
  final ChainConfig _chainConfig;
  final double amountRequested;
  final int startBlock; // Block-cursor anchor
  final String receivingAddress;
  final String? apiKey; // Required for Moralis service

  // --- Private State ---
  PaymentStatus _status = PaymentStatus.monitoring;
  bool _isLoading = false; // Default to false, user triggers load
  String? _errorMessage;
  double _amountReceived = 0.0;
  List<ReceivedTransaction> _receivedTransactions = [];
  bool _disposed = false;
  bool _inFlight = false; // Prevent overlapping checks
  late int _nextFromBlock; // Moving cursor for incremental monitoring

  // --- Public Getters ---
  PaymentStatus get status => _status;
  bool get isLoading => _isLoading;
  String? get errorMessage => _errorMessage;
  double get amountReceived => _amountReceived;
  List<ReceivedTransaction> get receivedTransactions => _receivedTransactions;
  double get amountLeft => max(0, amountRequested - _amountReceived);

  Timer? _pollingTimer;

  /// Constructor for block-cursor anchoring payment monitoring.
  ///
  /// Parameters:
  /// - [amountRequested]: Expected amount to receive.
  /// - [startBlock]: Block number to start monitoring from (block-cursor anchor).
  /// - [receivingAddress]: Wallet address to monitor.
  /// - [moralisService]: Service for API calls.
  /// - [chainConfig]: Chain configuration for API requests.
  /// - [apiKey]: API key for Moralis service.
  PaymentMonitorController({
    required this.amountRequested,
    required this.startBlock,
    required this.receivingAddress,
    required MoralisService moralisService,
    required ChainConfig chainConfig,
    this.apiKey,
  }) : _moralisService = moralisService,
       _chainConfig = chainConfig {
    _nextFromBlock = startBlock;
  }

  /// Manually checks for new payments.
  ///
  /// Call this method on "Pull-to-Refresh" or initial load.
  Future<void> refresh() async {
    debugPrint('PaymentMonitor refreshing...');
    await _checkPaymentStatus();
  }

  /// Starts polling for payment status.
  ///
  /// Polls every 15 seconds to respect Moralis Free Tier limits.
  void startMonitoring() {
    stopMonitoring();
    debugPrint('PaymentMonitor started polling.');

    // Initial check
    _checkPaymentStatus();

    _pollingTimer = Timer.periodic(const Duration(seconds: 15), (_) {
      _checkPaymentStatus();
    });
  }

  /// Stops the polling timer.
  void stopMonitoring() {
    _pollingTimer?.cancel();
    _pollingTimer = null;
    debugPrint('PaymentMonitor stopped polling.');
  }

  /// Checks payment status by querying the blockchain via Moralis.
  ///
  /// This method uses a moving block cursor to fetch only new transactions
  /// since the last check.
  Future<void> _checkPaymentStatus() async {
    if (_disposed || _inFlight) return; // No overlap

    if (apiKey == null || apiKey!.isEmpty) {
      _errorMessage = "API Key missing. Cannot check payments.";
      _status = PaymentStatus.error;
      notifyListeners();
      return;
    }

    _inFlight = true;
    // Only show loading indicator on first load or manual refresh, not every poll?
    // Actually, for polling, we might not want to flicker the UI with loading state every 15s.
    // But let's keep it simple for now.
    // _isLoading = true;
    // notifyListeners();

    try {
      final newTransactions = await _moralisService.getTokenTransactions(
        address: receivingAddress,
        contractAddress: _chainConfig.tokenAddress,
        startBlock: _nextFromBlock,
        limit: 50, // Conservative limit
        apiKey: apiKey!,
      );

      if (_disposed) return;

      // Filter inbound to the receiving address (Moralis returns all transfers for address)
      final inboundTransactions = newTransactions
          .where((tx) => tx.to.toLowerCase() == receivingAddress.toLowerCase())
          .toList();

      // Sum amounts
      final double totalReceived = inboundTransactions.fold<double>(
        0.0,
        (sum, tx) => sum + tx.amount,
      );

      // Advance the cursor to the highest seen block + 1
      if (newTransactions.isNotEmpty) {
        final maxBlock = newTransactions
            .map((t) => t.blockNumber)
            .fold<int>(_nextFromBlock, (a, b) => a > b ? a : b);
        _nextFromBlock = maxBlock + 1;
      }

      _errorMessage = null;
      if (totalReceived > 0) {
        _amountReceived = (_amountReceived + totalReceived);
        _receivedTransactions.addAll(inboundTransactions);
      }

      // Status Update
      if (_amountReceived >= amountRequested) {
        _status = PaymentStatus.completed;
        debugPrint('✅ Payment COMPLETED. Received $_amountReceived');
        stopMonitoring(); // Stop polling on completion
      } else if (_amountReceived > 0) {
        _status = PaymentStatus.partiallyPaid;
        debugPrint(
          '⚠️ Partial payment received: $_amountReceived / $amountRequested',
        );
      } else {
        _status = PaymentStatus.monitoring;
      }
    } catch (e) {
      debugPrint('❌ Error checking payment: $e');
      _errorMessage = e.toString();
      // Don't change status to error immediately if it's just a network blip?
      // But for manual refresh, showing error is good.
      // _status = PaymentStatus.error;
    } finally {
      _inFlight = false;
      _isLoading = false;
      if (!_disposed) {
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    stopMonitoring();
    _disposed = true;
    super.dispose();
  }
}
