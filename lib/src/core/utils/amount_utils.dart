/// Applies floor rounding to 2 decimal places.
///
/// This ensures consistent behavior across payment generation and verification:
/// - If you send 9.99999, it's considered as 9.99
/// - If you send 10.00001, it's considered as 10.00
///
/// Parameters:
/// - [amount]: The raw amount to round
///
/// Returns the amount floored to 2 decimal places.
///
/// Example:
/// ```dart
/// floorToTwoDecimals(9.99999) // returns 9.99
/// floorToTwoDecimals(10.00001) // returns 10.00
/// floorToTwoDecimals(15.0483) // returns 15.04
/// ```
double floorToTwoDecimals(double amount) {
  return (amount * 100).floor() / 100.0;
}
