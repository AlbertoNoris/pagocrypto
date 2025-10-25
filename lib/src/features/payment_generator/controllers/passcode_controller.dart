import 'package:flutter/material.dart';

/// Controller to manage passcode authentication state and logic.
///
/// This controller handles PIN code entry and validation for accessing settings.
class PasscodeController extends ChangeNotifier {
  // --- Constants ---
  static const String _kCorrectPasscode = '2086';

  // --- Private State ---
  /// The current PIN code entered by the user.
  String _passcodeInput = '';

  /// Whether the passcode was validated successfully.
  bool _isAuthenticated = false;

  /// Error message if passcode is incorrect.
  String? _errorMessage;

  // --- Public Getters ---

  /// The current PIN input (showing only dots for security).
  String get passcodeDisplay => '●' * _passcodeInput.length;

  /// The length of the current input.
  int get inputLength => _passcodeInput.length;

  /// Whether the authentication was successful.
  bool get isAuthenticated => _isAuthenticated;

  /// Error message, if any.
  String? get errorMessage => _errorMessage;

  // --- Public Methods ---

  /// Adds a digit to the passcode input.
  void addDigit(String digit) {
    if (_passcodeInput.length < 4) {
      _passcodeInput += digit;
      _errorMessage = null; // Clear error when user types
      notifyListeners();

      // Auto-validate when 4 digits are entered
      if (_passcodeInput.length == 4) {
        validatePasscode();
      }
    }
  }

  /// Removes the last digit from the passcode input.
  void removeLastDigit() {
    if (_passcodeInput.isNotEmpty) {
      _passcodeInput = _passcodeInput.substring(0, _passcodeInput.length - 1);
      _errorMessage = null;
      notifyListeners();
    }
  }

  /// Clears all input.
  void clearInput() {
    _passcodeInput = '';
    _errorMessage = null;
    notifyListeners();
  }

  /// Validates the entered passcode against the correct one.
  void validatePasscode() {
    if (_passcodeInput == _kCorrectPasscode) {
      _isAuthenticated = true;
      _errorMessage = null;
    } else {
      _isAuthenticated = false;
      _errorMessage = 'Incorrect passcode. Please try again.';
      _passcodeInput = ''; // Clear the input
    }
    notifyListeners();
  }
}
