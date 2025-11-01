import 'package:flutter/material.dart';

/// A container that constrains its child to a maximum width while keeping
/// the background full-screen width.
///
/// This is used to make the app web-friendly by preventing content from
/// becoming too wide on large screens, while maintaining the background
/// and app bar at full width.
class MaxWidthContainer extends StatelessWidget {
  /// The maximum width constraint in logical pixels.
  /// Default is 700px, which provides a comfortable reading width.
  final double maxWidth;

  /// The child widget to be constrained.
  final Widget child;

  const MaxWidthContainer({
    super.key,
    this.maxWidth = 700,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: ConstrainedBox(
        constraints: BoxConstraints(maxWidth: maxWidth),
        child: child,
      ),
    );
  }
}
