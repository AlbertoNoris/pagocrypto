import 'dart:async';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:pagocrypto/src/core/services/etherscan_service.dart';
import 'package:pagocrypto/src/features/payment_generator/models/received_transaction.dart';

enum PaymentStatus { monitoring, partiallyPaid, completed, error }

class PaymentMonitorController extends ChangeNotifier {
  // --- Dependencies & Config ---
  final EtherscanService _etherscanService;
  final double amountRequested;
  final int qrCreationTimestamp;
  final String receivingAddress;

  // --- Constants (from PDF and user) ---
  static const String _apiKey = 'UP1PWX9D5Y4PWRVBQ5WY2Q9SQCN9WC8TVI';
  static const String _tokenContractAddress =
      '0x9d1A7A3191102e9F900Faa10540837ba84dCBAE7';
  static const String _apiBaseUrl = 'https://api.etherscan.io';
  static const int _chainId = 1; // Ethereum mainnet Chain ID

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

  PaymentMonitorController({
    required this.amountRequested,
    required this.qrCreationTimestamp,
    required this.receivingAddress,
    required EtherscanService etherscanService,
  }) : _etherscanService = etherscanService;

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

  Future<void> _checkPaymentStatus() async {
    // Don't proceed if controller has been disposed
    if (_disposed) {
      return;
    }

    try {
      final transactions = await _etherscanService.getTokenTransactions(
        apiBaseUrl: _apiBaseUrl,
        address: receivingAddress,
        contractAddress: _tokenContractAddress,
        apiKey: _apiKey,
        chainId: _chainId,
      );

      // Check again after async operation in case dispose was called
      if (_disposed) {
        return;
      }

      final newTransactions = transactions.where((tx) {
        return tx.timestamp > qrCreationTimestamp &&
            tx.to.toLowerCase() == receivingAddress.toLowerCase();
      }).toList();

      final double totalReceived = newTransactions.fold(
        0.0,
        (sum, tx) => sum + tx.amount,
      );

      _isLoading = false;
      _errorMessage = null;
      _amountReceived = totalReceived;
      _receivedTransactions = newTransactions;

      if (_amountReceived >= amountRequested) {
        _status = PaymentStatus.completed;
        debugPrint('Payment COMPLETED. Received $_amountReceived');
        stopMonitoring();
      } else if (_amountReceived > 0) {
        _status = PaymentStatus.partiallyPaid;
      } else {
        _status = PaymentStatus.monitoring;
      }
    } catch (e) {
      debugPrint('Error checking payment: $e');
      _errorMessage = 'Failed to check payment status. Retrying...';
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
