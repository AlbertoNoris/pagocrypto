import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pagocrypto/src/core/config/chain_config.dart';
import 'package:pagocrypto/src/core/services/moralis_service.dart';
import 'package:pagocrypto/src/core/services/qr_proxy_service.dart';
import 'package:pagocrypto/src/core/utils/amount_utils.dart';

/// Controller to manage payment QR code generation state and logic.
///
/// This controller adheres to the State-Driven UI pattern.
///
/// UPDATED: Uses MoralisService for block fetching.
class PaymentGeneratorController extends ChangeNotifier {
  // --- Dependencies ---
  final MoralisService _moralisService;
  final ChainConfig _chainConfig;
  final QrProxyService _qrProxyService;

  // --- Constants ---

  // SharedPreferences keys
  static const String _kAddressKey = 'receivingAddress';
  static const String _kMultiplierKey = 'amountMultiplier';
  static const String _kDeviceIdKey = 'deviceId';
  static const String _kApiKeyKey = 'apiKey';

  // --- Private State ---

  /// Internal loading state, true while loading from SharedPreferences.
  bool _isLoading = true;

  /// Loading state while generating QR code (fetching block + creating QR).
  bool _isGeneratingQr = false;

  /// The user's receiving wallet address.
  String? _receivingAddress;

  /// The multiplier to apply to the amount (e.g., 1.03).
  double? _amountMultiplier;

  /// The device ID for identification (optional).
  String? _deviceId;

  /// The API key for Moralis service (optional).
  String? _apiKey;

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

  /// Whether the controller is currently fetching the block number.
  bool _isBlockFetching = false;

  /// The QR code image bytes downloaded from the API.
  Uint8List? _qrCodeImageBytes;

  /// The QR code image URL from the API (used on web to avoid CORS).
  Uint8List? _qrJpgUrl;

  // --- Public Getters ---

  /// Whether the controller is loading initial settings.
  bool get isLoading => _isLoading;

  /// Whether the controller is generating the QR code.
  bool get isGeneratingQr => _isGeneratingQr;

  /// The user's saved receiving wallet address.
  String? get receivingAddress => _receivingAddress;

  /// The user's saved amount multiplier.
  double? get amountMultiplier => _amountMultiplier;

  /// The device ID for identification.
  String? get deviceId => _deviceId;

  /// The API key for Moralis service.
  String? get apiKey => _apiKey;

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

  /// The QR code image bytes from the API.
  Uint8List? get qrCodeImageBytes => _qrCodeImageBytes;

  /// The QR code image URL from the API (used on web to avoid CORS).
  Uint8List? get qrJpgUrl => _qrJpgUrl;

  /// Whether the controller is currently fetching the block number.
  bool get isBlockFetching => _isBlockFetching;

  /// Whether the block number is ready for use (fetched and available).
  bool get isBlockReady => _qrStartBlock != null && !_isBlockFetching;

  /// Constructor. Accepts MoralisService, ChainConfig, and QrProxyService dependencies.
  /// Immediately starts loading settings.
  PaymentGeneratorController({
    required MoralisService moralisService,
    required ChainConfig chainConfig,
    required QrProxyService qrProxyService,
  }) : _moralisService = moralisService,
       _chainConfig = chainConfig,
       _qrProxyService = qrProxyService {
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
      _apiKey = prefs.getString(_kApiKeyKey);
      if (_apiKey == null || _apiKey!.isEmpty) {
        _apiKey =
            'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJub25jZSI6IjAyOTQwNmNkLTczMzQtNDY2Ni05NjBjLTViOGNhZjgzNDJjZSIsIm9yZ0lkIjoiNDg0NDI5IiwidXNlcklkIjoiNDk4MzkwIiwidHlwZUlkIjoiZDc2ZjlhZTYtODY4Yi00MDY5LThmNWUtZmJkYjhiNGQ3YmMxIiwidHlwZSI6IlBST0pFQ1QiLCJpYXQiOjE3NjQ3ODAwNzMsImV4cCI6NDkyMDU0MDA3M30.wHlylOMJUgfSRwEOBM7b7efhgnw4MqyofRXCD4qjYGY';
      }
    } catch (e) {
      debugPrint("Error loading settings: $e");
      _errorMessage = "Could not load saved settings.";
    }

    _isLoading = false;
    notifyListeners();

    // Start fetching block number in background for first QR generation
    // Only if API key is present, as Moralis requires it
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      startBlockFetching();
    }
  }

  /// Starts fetching the current block number in the background.
  Future<void> startBlockFetching() async {
    if (_apiKey == null || _apiKey!.isEmpty) {
      debugPrint('Skipping block fetch: No API Key');
      return;
    }

    _isBlockFetching = true;
    _qrStartBlock = null;
    notifyListeners();

    try {
      _qrStartBlock = await _moralisService.getCurrentBlock(apiKey: _apiKey);
      debugPrint('Background block fetch completed: $_qrStartBlock');
    } catch (e) {
      debugPrint('Background block fetch failed: $e');
      // Don't set error message here - let generateUrl() handle it
    } finally {
      _isBlockFetching = false;
      notifyListeners();
    }
  }

  /// Validates and saves the user's settings to SharedPreferences.
  Future<void> saveSettings({
    required String address,
    required String multiplierString,
    String? deviceId,
    String? apiKey,
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
      if (apiKey != null && apiKey.isNotEmpty) {
        await prefs.setString(_kApiKeyKey, apiKey);
      } else {
        await prefs.remove(_kApiKeyKey);
      }

      // --- Update State ---
      _receivingAddress = address;
      _amountMultiplier = multiplier;
      _deviceId = deviceId;
      _apiKey = apiKey;

      // Trigger block fetch if we just saved a key
      if (apiKey != null && apiKey.isNotEmpty) {
        startBlockFetching();
      }
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

    // Calculate amount_to_request with floor rounding to 2 decimal places
    final double rawAmount = amount * _amountMultiplier!;
    final double amountToRequest = floorToTwoDecimals(rawAmount);
    return amountToRequest;
  }

  /// Generates the payment URL based on the user's input amount.
  Future<void> generateUrl({required String importo}) async {
    // Set loading state
    _isGeneratingQr = true;
    notifyListeners();

    // Clear any previous state
    _generatedUrl = null;
    _bscScanUrl = null;
    _inputAmount = null;
    _finalAmount = null;
    _errorMessage = null;
    _navigateToQr = false;
    _qrCodeImageBytes = null;
    _qrJpgUrl = null;

    // --- Validation ---
    if (_receivingAddress == null || _amountMultiplier == null) {
      _errorMessage =
          "Per favore configura le impostazioni prima di generare un URL.";
      _isGeneratingQr = false;
      notifyListeners();
      return;
    }

    if (_apiKey == null || _apiKey!.isEmpty) {
      _errorMessage = "API Key mancante. Configura le impostazioni.";
      _isGeneratingQr = false;
      notifyListeners();
      return;
    }

    // Parse the amount from comma-separated format (e.g., "1,89" -> 1.89)
    final String normalizedImporto = importo.replaceAll(',', '.');
    final double? amount = double.tryParse(normalizedImporto);
    if (amount == null || amount <= 0) {
      _errorMessage = "Per favore inserisci un importo valido.";
      _isGeneratingQr = false;
      notifyListeners();
      return;
    }

    // --- Wait for block fetch if still in progress ---
    if (_isBlockFetching) {
      debugPrint('Waiting for background block fetch to complete...');
      // Wait for block fetch to complete by polling
      while (_isBlockFetching) {
        await Future.delayed(const Duration(milliseconds: 100));
      }
    }

    // If block is still null (fetch failed or never started), try one last time
    if (_qrStartBlock == null) {
      debugPrint('Block not ready, trying immediate fetch...');
      try {
        _qrStartBlock = await _moralisService.getCurrentBlock(apiKey: _apiKey);
      } catch (e) {
        debugPrint('Immediate block fetch failed: $e');
      }
    }

    // --- Verify block was fetched successfully ---
    if (_qrStartBlock == null) {
      debugPrint('Block fetch failed or not available');
      _errorMessage = "Impossibile ottenere il blocco corrente. Riprova.";
      _isGeneratingQr = false;
      notifyListeners();
      return;
    }

    debugPrint('Using block: $_qrStartBlock for QR generation');

    // --- Logic from PDF ---

    // 1. Calculate amount_to_request with floor rounding to 2 decimal places
    final double rawAmount = amount * _amountMultiplier!;
    final double amountToRequest = floorToTwoDecimals(rawAmount);

    // 2. Convert to uint256 (wei)
    final BigInt amountInCents = BigInt.from((amountToRequest * 100).round());
    final BigInt multiplierWei = BigInt.parse('10000000000000000'); // 10^16
    final BigInt amountUint256 = amountInCents * multiplierWei;

    // 3. Format the QR code content (the "final URL")
    _generatedUrl =
        'ethereum:${_chainConfig.tokenAddress}@${_chainConfig.chainId}/transfer?address=$_receivingAddress&uint256=${amountUint256.toString()}';

    // 4. Create the block explorer monitoring URL
    _bscScanUrl =
        '${_chainConfig.explorerUrl}/token/${_chainConfig.tokenAddress}?a=$_receivingAddress';

    // 5. Store the input amount and calculated final amount
    _inputAmount = importo;
    _finalAmount = amountToRequest;

    // 6. Record the QR creation timestamp for backward compatibility
    _qrCreationTimestamp =
        DateTime.now().toUtc().millisecondsSinceEpoch ~/ 1000;

    // 7. Generate the styled QR code from qr.io API
    await generateQrCodeFromApi(_generatedUrl!);

    // Clear loading state
    _isGeneratingQr = false;
    notifyListeners();
  }

  /// Clears the generated URL and error state to return to the input screen.
  void clearGeneratedUrl() {
    _generatedUrl = null;
    _bscScanUrl = null;
    _inputAmount = null;
    _finalAmount = null;
    _errorMessage = null;
    _qrCodeImageBytes = null;
    _qrJpgUrl = null;
    _qrStartBlock = null;
    notifyListeners();

    // Start fetching a new block for the next payment
    if (_apiKey != null && _apiKey!.isNotEmpty) {
      startBlockFetching();
    }
  }

  /// Updates the input amount and triggers a rebuild.
  void updateInputAmount(String amount) {
    _inputAmount = amount;
    notifyListeners();
  }

  /// Resets the navigation event flag after the view has handled it.
  void onNavigatedToQr() {
    _navigateToQr = false;
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

  /// Generates a QR code using the QR proxy service.
  Future<void> generateQrCodeFromApi(String paymentUrl) async {
    try {
      _qrJpgUrl = await _qrProxyService.create(data: paymentUrl);
      _navigateToQr = true;
    } catch (e) {
      debugPrint('Error calling QR proxy: $e');
      _errorMessage = 'Error generating QR code: $e';
    }
  }
}
