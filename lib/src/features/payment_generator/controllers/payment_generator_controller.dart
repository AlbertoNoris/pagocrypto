import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pagocrypto/src/core/config/chain_config.dart';
import 'package:pagocrypto/src/core/services/etherscan_service.dart';

/// Controller to manage payment QR code generation state and logic.
///
/// This controller adheres to the State-Driven UI pattern:
/// 1. It extends ChangeNotifier.
/// 2. State variables are private (`_variable`).
/// 3. State is exposed via public getters (`get variable`).
/// 4. notifyListeners() is called after state modification.
///
/// It integrates with EtherscanService to fetch the current block number at
/// the time of QR generation, enabling block-cursor anchoring for deterministic
/// payment monitoring.
class PaymentGeneratorController extends ChangeNotifier {
  // --- Dependencies ---
  final EtherscanService _etherscanService;
  final ChainConfig _chainConfig;

  // --- Constants ---

  // SharedPreferences keys
  static const String _kAddressKey = 'receivingAddress';
  static const String _kMultiplierKey = 'amountMultiplier';
  static const String _kDeviceIdKey = 'deviceId';

  // --- Private State ---

  /// Internal loading state, true while loading from SharedPreferences.
  bool _isLoading = true;

  /// The user's receiving wallet address.
  String? _receivingAddress;

  /// The multiplier to apply to the amount (e.g., 1.03).
  double? _amountMultiplier;

  /// The device ID for identification (optional).
  String? _deviceId;

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

  /// One-time event message for clipboard feedback.
  String? _clipboardMessage;

  /// Timestamp when the QR code was created (Unix timestamp in seconds).
  /// Deprecated: Use _qrStartBlock for block-cursor anchoring instead.
  int? _qrCreationTimestamp;

  /// The block number at the time of QR generation (block-cursor anchor).
  /// Used to monitor payments from this block forward without timestamp filtering.
  int? _qrStartBlock;

  // --- Public Getters ---

  /// Whether the controller is loading initial settings.
  bool get isLoading => _isLoading;

  /// The user's saved receiving wallet address.
  String? get receivingAddress => _receivingAddress;

  /// The user's saved amount multiplier.
  double? get amountMultiplier => _amountMultiplier;

  /// The device ID for identification.
  String? get deviceId => _deviceId;

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

  /// One-time event message for clipboard feedback.
  String? get clipboardMessage => _clipboardMessage;

  /// Formatted final amount for display.
  String get finalAmountFormatted =>
      (_finalAmount?.toStringAsFixed(2) ?? '0.00').replaceAll('.', ',');

  /// Timestamp when the QR code was created (Unix timestamp in seconds).
  int? get qrCreationTimestamp => _qrCreationTimestamp;

  /// The block number at the time of QR generation (block-cursor anchor).
  int? get qrStartBlock => _qrStartBlock;

  /// Constructor. Accepts EtherscanService and ChainConfig dependencies.
  /// Immediately starts loading settings.
  PaymentGeneratorController({
    required EtherscanService etherscanService,
    required ChainConfig chainConfig,
  }) : _etherscanService = etherscanService,
       _chainConfig = chainConfig {
    loadSettings();
  }

  // --- Public Methods ---

  /// Loads saved address, multiplier, and device ID from SharedPreferences.
  Future<void> loadSettings() async {
    _isLoading = true;
    notifyListeners();

    try {
      final prefs = await SharedPreferences.getInstance();
      _receivingAddress = prefs.getString(_kAddressKey);
      _amountMultiplier = prefs.getDouble(_kMultiplierKey);
      _deviceId = prefs.getString(_kDeviceIdKey);
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
    String? deviceId,
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
      if (deviceId != null && deviceId.isNotEmpty) {
        await prefs.setString(_kDeviceIdKey, deviceId);
      } else {
        await prefs.remove(_kDeviceIdKey);
      }

      // --- Update State ---
      _receivingAddress = address;
      _amountMultiplier = multiplier;
      _deviceId = deviceId;
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
  ///
  /// This is now async to fetch the current block number from the blockchain.
  /// The block number is stored as _qrStartBlock for block-cursor anchoring.
  ///
  /// Throws an exception if the block fetch fails.
  Future<void> generateUrl({required String importo}) async {
    // Clear any previous state
    _generatedUrl = null;
    _bscScanUrl = null;
    _inputAmount = null;
    _finalAmount = null;
    _errorMessage = null;
    _navigateToQr = false;
    _qrStartBlock = null;

    // --- Validation ---
    if (_receivingAddress == null || _amountMultiplier == null) {
      _errorMessage =
          "Per favore configura le impostazioni prima di generare un URL.";
      notifyListeners();
      return;
    }

    // Parse the amount from comma-separated format (e.g., "1,89" -> 1.89)
    final String normalizedImporto = importo.replaceAll(',', '.');
    final double? amount = double.tryParse(normalizedImporto);
    if (amount == null || amount <= 0) {
      _errorMessage = "Per favore inserisci un importo valido.";
      notifyListeners();
      return;
    }

    // --- Fetch current block (block-cursor anchor) ---
    try {
      _qrStartBlock = await _etherscanService.getCurrentBlock();
      debugPrint('Captured start block: $_qrStartBlock');
    } catch (e) {
      debugPrint('Error fetching current block: $e');
      _errorMessage = "Failed to fetch current block. Please try again.";
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
    // Use chain config for token address and chain ID
    _generatedUrl =
        'ethereum:${_chainConfig.tokenAddress}@${_chainConfig.chainId}/transfer?address=$_receivingAddress&uint256=${amountUint256.toString()}';

    // 4. Create the block explorer monitoring URL
    // Construct the base explorer URL from the API base URL
    final explorerUrl = _chainConfig.apiBaseUrl.replaceFirst('/api', '');
    _bscScanUrl =
        '$explorerUrl/token/${_chainConfig.tokenAddress}?a=$_receivingAddress';

    // 5. Store the input amount and calculated final amount
    _inputAmount = importo;
    _finalAmount = amountToRequest;

    // 6. Record the QR creation timestamp for backward compatibility
    _qrCreationTimestamp =
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    // 7. Set the navigation event flag
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

  /// Updates the input amount and triggers a rebuild.
  /// This allows the view to reactively display the final amount.
  void updateInputAmount(String amount) {
    _inputAmount = amount;
    notifyListeners();
  }

  /// Resets the navigation event flag after the view has handled it.
  void onNavigatedToQr() {
    _navigateToQr = false;
    // No notifyListeners() here, as per the one-time-event pattern
  }

  /// Copies the monitoring URL to clipboard and sets a feedback message.
  Future<void> copyMonitoringUrlToClipboard() async {
    if (_bscScanUrl != null) {
      await Clipboard.setData(ClipboardData(text: _bscScanUrl!));
      _clipboardMessage = 'Monitoring URL copied to clipboard';
      notifyListeners();
    }
  }

  /// Resets the clipboard message after the view has displayed it.
  void onClipboardMessageShown() {
    _clipboardMessage = null;
  }
}
