import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pagocrypto/src/core/config/chain_config.dart';
import 'package:pagocrypto/src/core/services/etherscan_service.dart';
import 'package:pagocrypto/src/features/payment_generator/models/received_transaction.dart';

/// Payment status enum for monitoring state.
enum PaymentStatus { monitoring, partiallyPaid, completed, error }

/// Controller to monitor incoming ERC-20 token payments.
///
/// This controller uses block-cursor anchoring to monitor payments from a
/// specific starting block, eliminating the need for timestamp-based filtering.
/// It polls the Etherscan API at regular intervals to check for incoming
/// transactions.
class PaymentMonitorController extends ChangeNotifier {
  // --- Dependencies & Config ---
  final EtherscanService _etherscanService;
  final ChainConfig _chainConfig;
  final double amountRequested;
  final int startBlock; // Block-cursor anchor (replaces timestamp)
  final String receivingAddress;
  final String? apiKey; // Optional API key for Etherscan service

  // --- Private State ---
  PaymentStatus _status = PaymentStatus.monitoring;
  bool _isLoading = true;
  String? _errorMessage;
  double _amountReceived = 0.0;
  List<ReceivedTransaction> _receivedTransactions = [];
  Timer? _pollingTimer;
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

  /// Constructor for block-cursor anchoring payment monitoring.
  ///
  /// Parameters:
  /// - [amountRequested]: Expected amount to receive.
  /// - [startBlock]: Block number to start monitoring from (block-cursor anchor).
  /// - [receivingAddress]: Wallet address to monitor.
  /// - [etherscanService]: Service for API calls.
  /// - [chainConfig]: Chain configuration for API requests.
  /// - [apiKey]: Optional API key for Etherscan service.
  PaymentMonitorController({
    required this.amountRequested,
    required this.startBlock,
    required this.receivingAddress,
    required EtherscanService etherscanService,
    required ChainConfig chainConfig,
    this.apiKey,
  }) : _etherscanService = etherscanService,
       _chainConfig = chainConfig {
    _nextFromBlock = startBlock;
  }

  void startMonitoring() {
    debugPrint('PaymentMonitor started. Monitoring for $amountRequested');
    stopMonitoring();

    void schedule() {
      final jitterMs = 250 + Random().nextInt(500); // 250–750 ms
      _pollingTimer = Timer(
        Duration(seconds: 4) + Duration(milliseconds: jitterMs),
        () async {
          await _checkPaymentStatus();
          if (!_disposed && _status != PaymentStatus.completed) {
            schedule();
          }
        },
      );
    }

    // Start timer-based polling without immediate check
    // (newly generated QR codes won't have transactions yet)
    schedule();
  }

  void stopMonitoring() {
    debugPrint('PaymentMonitor stopping.');
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Checks payment status by querying the blockchain.
  ///
  /// This method uses a moving block cursor to fetch only new transactions
  /// since the last check, avoiding re-downloading historical data.
  ///
  /// Updates controller state with results and notifies listeners.
  Future<void> _checkPaymentStatus() async {
    if (_disposed || _inFlight) return; // No overlap
    _inFlight = true;

    try {
      final rawTransactions = await _etherscanService.getTokenTxFromBlock(
        address: receivingAddress,
        contractAddress: _chainConfig.tokenAddress,
        startBlock: _nextFromBlock, // Only fetch new items
        offset: 200, // Smaller page size for monitoring
        maxPages: 3, // Cap bursts
        perPagePause: const Duration(milliseconds: 300),
        apiKey: apiKey,
      );

      if (_disposed) return;

      // Parse as before
      final parsedTransactions = <ReceivedTransaction>[];
      for (final raw in rawTransactions) {
        try {
          parsedTransactions.add(ReceivedTransaction.fromJson(raw));
        } catch (e) {
          debugPrint('Error parsing transaction ${raw['hash']}: $e');
        }
      }

      // Filter inbound to the receiving address
      final inboundTransactions = parsedTransactions
          .where((tx) => tx.to.toLowerCase() == receivingAddress.toLowerCase())
          .toList();

      // Sum amounts
      final double totalReceived = inboundTransactions.fold<double>(
        0.0,
        (sum, tx) => sum + tx.amount,
      );

      // Advance the cursor to the highest seen block + 1
      if (rawTransactions.isNotEmpty) {
        final maxBlock = rawTransactions
            .map((m) => int.parse(m['blockNumber'] as String))
            .fold<int>(_nextFromBlock, (a, b) => a > b ? a : b);
        _nextFromBlock = maxBlock + 1;
      }

      _isLoading = false;
      _errorMessage = null;
      _amountReceived = (_amountReceived + totalReceived);
      _receivedTransactions.addAll(inboundTransactions);

      // De‑duplicate if needed (optional)
      // _receivedTransactions = {for (var t in _receivedTransactions) t.hash: t}.values.toList();

      // Status
      if (_amountReceived >= amountRequested) {
        _status = PaymentStatus.completed;
        debugPrint('✅ Payment COMPLETED. Received $_amountReceived');
        stopMonitoring();
      } else if (_amountReceived > 0) {
        _status = PaymentStatus.partiallyPaid;
        debugPrint(
          '⚠️ Partial payment received: $_amountReceived / $amountRequested',
        );
      } else {
        _status = PaymentStatus.monitoring;
      }
    } catch (e) {
      final errorText = e.toString().toLowerCase();
      final isThrottleError =
          errorText.contains('temporarily unavailable') ||
          errorText.contains('rate limit') ||
          errorText.contains('too many requests');

      if (isThrottleError) {
        // Throttle errors are transparent to user - retry will handle it
        debugPrint('⏱️ API throttled, will retry on next poll: $e');
        _isLoading = false;
        // Keep current status (monitoring/partiallyPaid), don't show error
      } else {
        // Real errors are shown to the user
        debugPrint('❌ Error checking payment: $e');
        _errorMessage = e.toString();
        _status = PaymentStatus.error;
      }
    } finally {
      _inFlight = false;
    }

    if (!_disposed) {
      notifyListeners();
    }
  }

  @override
  void dispose() {
    _disposed = true;
    stopMonitoring();
    super.dispose();
  }
}
