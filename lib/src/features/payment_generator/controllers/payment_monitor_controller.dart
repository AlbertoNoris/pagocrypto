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

  // --- Private State ---
  PaymentStatus _status = PaymentStatus.monitoring;
  bool _isLoading = true;
  String? _errorMessage;
  double _amountReceived = 0.0;
  List<ReceivedTransaction> _receivedTransactions = [];
  Timer? _pollingTimer;
  bool _disposed = false;

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
  PaymentMonitorController({
    required this.amountRequested,
    required this.startBlock,
    required this.receivingAddress,
    required EtherscanService etherscanService,
    required ChainConfig chainConfig,
  }) : _etherscanService = etherscanService,
       _chainConfig = chainConfig;

  void startMonitoring() {
    debugPrint('PaymentMonitor started. Monitoring for $amountRequested');
    _pollingTimer?.cancel();
    _checkPaymentStatus(); // Check immediately
    _pollingTimer = Timer.periodic(const Duration(seconds: 5), (_) {
      _checkPaymentStatus();
    });
  }

  void stopMonitoring() {
    debugPrint('PaymentMonitor stopping.');
    _pollingTimer?.cancel();
    _pollingTimer = null;
  }

  /// Checks payment status by querying the blockchain.
  ///
  /// This method fetches all token transactions from the startBlock forward,
  /// filters by the receiving address, and sums the amounts received.
  /// It does NOT use timestamp filtering—the block number acts as the cursor.
  ///
  /// Updates controller state with results and notifies listeners.
  Future<void> _checkPaymentStatus() async {
    // Don't proceed if controller has been disposed
    if (_disposed) {
      return;
    }

    try {
      // Fetch token transactions from the stored start block forward
      final rawTransactions = await _etherscanService.getTokenTxFromBlock(
        address: receivingAddress,
        contractAddress: _chainConfig.tokenAddress,
        startBlock: startBlock,
      );

      // Check again after async operation in case dispose was called
      if (_disposed) {
        return;
      }

      // Parse raw API responses to ReceivedTransaction objects
      final parsedTransactions = <ReceivedTransaction>[];
      for (final raw in rawTransactions) {
        try {
          parsedTransactions.add(ReceivedTransaction.fromJson(raw));
        } catch (e) {
          debugPrint('Error parsing transaction ${raw['hash']}: $e');
        }
      }

      // Filter by receiving address (confirm the transaction recipient)
      final inboundTransactions = parsedTransactions
          .where((tx) => tx.to.toLowerCase() == receivingAddress.toLowerCase())
          .toList();

      // Sum all received amounts
      final double totalReceived = inboundTransactions.fold(
        0.0,
        (sum, tx) => sum + tx.amount,
      );

      _isLoading = false;
      _errorMessage = null;
      _amountReceived = totalReceived;
      _receivedTransactions = inboundTransactions;

      // Update status based on received amount
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
      debugPrint('❌ Error checking payment: $e');
      _errorMessage = '';
      _status = PaymentStatus.error;
    }

    // Only notify if not disposed
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
