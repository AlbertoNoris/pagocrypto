import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Controller to manage payment QR code generation state and logic.
///
/// This controller adheres to the State-Driven UI pattern:
/// 1. It extends ChangeNotifier.
/// 2. State variables are private (`_variable`).
/// 3. State is exposed via public getters (`get variable`).
/// 4. notifyListeners() is called after state modification.
class PaymentGeneratorController extends ChangeNotifier {
  // --- Constants ---

  // SharedPreferences keys
  static const String _kAddressKey = 'receivingAddress';
  static const String _kMultiplierKey = 'amountMultiplier';

  // Hardcoded blockchain values from the PDF
  static const String _kTokenAddress =
      '0x9d1A7A3191102e9F900Faa10540837ba84dCBAE7';
  static const String _kNetworkId = '56'; // 56 is the chain ID for BSC

  // --- Private State ---

  /// Internal loading state, true while loading from SharedPreferences.
  bool _isLoading = true;

  /// The user's receiving wallet address.
  String? _receivingAddress;

  /// The multiplier to apply to the amount (e.g., 1.03).
  double? _amountMultiplier;

  /// The final generated URL for the QR code.
  String? _generatedUrl;

  /// The URL to monitor the transaction on BscScan.
  String? _bscScanUrl;

  /// The input amount entered by the user.
  String? _inputAmount;

  /// The calculated final amount to request.
  double? _finalAmount;

  /// An error message for the UI, if any.
  String? _errorMessage;

  /// One-time event to notify the view that URL was successfully generated (for navigation).
  bool _navigateToQr = false;

  // --- Public Getters ---

  /// Whether the controller is loading initial settings.
  bool get isLoading => _isLoading;

  /// The user's saved receiving wallet address.
  String? get receivingAddress => _receivingAddress;

  /// The user's saved amount multiplier.
  double? get amountMultiplier => _amountMultiplier;

  /// The generated payment URL. Null if no URL is generated.
  String? get generatedUrl => _generatedUrl;

  /// The BscScan URL to monitor the receiving address. Null if no URL is generated.
  String? get bscScanUrl => _bscScanUrl;

  /// The input amount entered by the user.
  String? get inputAmount => _inputAmount;

  /// The calculated final amount to request.
  double? get finalAmount => _finalAmount;

  /// A displayable error message.
  String? get errorMessage => _errorMessage;

  /// One-time event flag for navigating to QR display.
  bool get navigateToQr => _navigateToQr;

  /// Constructor. Immediately starts loading settings.
  PaymentGeneratorController() {
    loadSettings();
  }

  // --- Public Methods ---

  /// Loads saved address and multiplier from SharedPreferences.
  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _receivingAddress = prefs.getString(_kAddressKey);
      _amountMultiplier = prefs.getDouble(_kMultiplierKey);
    } catch (e) {
      // In a real app, you might want more robust error handling
      debugPrint("Error loading settings: $e");
      _errorMessage = "Could not load saved settings.";
    }

    _isLoading = false;
    notifyListeners();
  }

  /// Validates and saves the user's settings to SharedPreferences.
  Future<void> saveSettings({
    required String address,
    required String multiplierString,
  }) async {
    _errorMessage = null;

    // --- Validation ---
    final double? multiplier = double.tryParse(multiplierString);
    if (!address.startsWith('0x') || address.length < 42) {
      _errorMessage = "Invalid receiving address.";
      notifyListeners();
      return;
    }
    if (multiplier == null || multiplier < 1.0) {
      _errorMessage = "Invalid multiplier. Must be 1.0 or greater.";
      notifyListeners();
      return;
    }

    // --- Persistence ---
    try {
      final prefs = await SharedPreferences.getInstance();
      await prefs.setString(_kAddressKey, address);
      await prefs.setDouble(_kMultiplierKey, multiplier);

      // --- Update State ---
      _receivingAddress = address;
      _amountMultiplier = multiplier;
    } catch (e) {
      debugPrint("Error saving settings: $e");
      _errorMessage = "Could not save settings.";
    }

    notifyListeners();
  }

  /// Calculates the final amount to request based on the input amount.
  /// Returns the calculated amount or null if invalid.
  double? calculateFinalAmount(String amountString) {
    final double? amount = double.tryParse(amountString);
    if (amount == null || amount <= 0) {
      return null;
    }
    if (_amountMultiplier == null) {
      return null;
    }

    // 1. Calculate amount_to_request
    // PDF Example: 14.61 * 1.03 = 15.0483. Result: 15.04.
    // This implies flooring (truncating) at 2 decimal places, not rounding.
    final double rawAmount = amount * _amountMultiplier!;
    final double amountToRequest = (rawAmount * 100).floor() / 100.0;
    return amountToRequest;
  }

  /// Generates the payment URL based on the user's input amount.
  void generateUrl({required String importo}) {
    // Clear any previous state
    _generatedUrl = null;
    _bscScanUrl = null;
    _inputAmount = null;
    _finalAmount = null;
    _errorMessage = null;
    _navigateToQr = false;

    // --- Validation ---
    if (_receivingAddress == null || _amountMultiplier == null) {
      _errorMessage = "Please configure settings before generating a URL.";
      notifyListeners();
      return;
    }

    final double? amount = double.tryParse(importo);
    if (amount == null || amount <= 0) {
      _errorMessage = "Please enter a valid amount.";
      notifyListeners();
      return;
    }

    // --- Logic from PDF ---

    // 1. Calculate amount_to_request
    // PDF Example: 14.61 * 1.03 = 15.0483. Result: 15.04.
    // This implies flooring (truncating) at 2 decimal places, not rounding.
    final double rawAmount = amount * _amountMultiplier!;
    final double amountToRequest = (rawAmount * 100).floor() / 100.0;

    // 2. Convert to uint256 (wei)
    // We must use BigInt to avoid precision loss.
    // 15.04 * 10^18 is the same as 1504 * 10^16
    final BigInt amountInCents = BigInt.from((amountToRequest * 100).round());
    final BigInt multiplierWei = BigInt.parse('10000000000000000'); // 10^16
    final BigInt amountUint256 = amountInCents * multiplierWei;

    // 3. Format the QR code content (the "final URL")
    _generatedUrl =
        'ethereum:$_kTokenAddress@$_kNetworkId/transfer?address=$_receivingAddress&uint256=${amountUint256.toString()}';

    // 4. Create the BscScan monitoring URL
    _bscScanUrl = 'https://bscscan.com/token/$_kTokenAddress?a=$_receivingAddress';

    // 5. Store the input amount and calculated final amount
    _inputAmount = importo;
    _finalAmount = amountToRequest;

    // 6. Set the navigation event flag
    _navigateToQr = true;

    notifyListeners();
  }

  /// Clears the generated URL and error state to return to the input screen.
  void clearGeneratedUrl() {
    _generatedUrl = null;
    _bscScanUrl = null;
    _inputAmount = null;
    _finalAmount = null;
    _errorMessage = null;
    notifyListeners();
  }

  /// Resets the navigation event flag after the view has handled it.
  void onNavigatedToQr() {
    _navigateToQr = false;
    // No notifyListeners() here, as per the one-time-event pattern
  }
}
