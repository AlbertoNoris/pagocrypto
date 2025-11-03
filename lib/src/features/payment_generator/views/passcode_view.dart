import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pagocrypto/src/core/widgets/max_width_container.dart';
import 'package:pagocrypto/src/features/payment_generator/controllers/passcode_controller.dart';

class PasscodeView extends StatefulWidget {
  const PasscodeView({super.key});

  @override
  State<PasscodeView> createState() => _PasscodeViewState();
}

class _PasscodeViewState extends State<PasscodeView> {
  late final PasscodeController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<PasscodeController>();
    _controller.addListener(_handleAuthenticationChange);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleAuthenticationChange);
    super.dispose();
  }

  void _handleAuthenticationChange() {
    if (_controller.isAuthenticated) {
      // Navigate to settings after successful authentication
      if (mounted) {
        context.go('/settings');
      }
    }
  }

  void _onDigitPressed(String digit) {
    _controller.addDigit(digit);
  }

  void _onDeletePressed() {
    _controller.removeLastDigit();
  }

  void _onClearPressed() {
    _controller.clearInput();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Logs Amministratore')),
      body: MaxWidthContainer(
        child: Padding(
          padding: const EdgeInsets.all(24.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
            const Text(
              'Enter passcode',
              textAlign: TextAlign.center,
              style: TextStyle(fontSize: 20, fontWeight: FontWeight.w600),
            ),
            const SizedBox(height: 32),

            // Passcode display
            Consumer<PasscodeController>(
              builder: (context, controller, child) {
                return Container(
                  padding: const EdgeInsets.symmetric(vertical: 20),
                  decoration: BoxDecoration(
                    color: Theme.of(context).colorScheme.surface,
                    border: Border.all(
                      color: Theme.of(context).colorScheme.onSurface.withValues(alpha: 0.3),
                    ),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    controller.passcodeDisplay.isEmpty
                        ? '----'
                        : controller.passcodeDisplay,
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: 36,
                      letterSpacing: 16,
                      fontWeight: FontWeight.w600,
                      color: Theme.of(context).colorScheme.onSurface,
                    ),
                  ),
                );
              },
            ),
            const SizedBox(height: 24),

            // Error message
            Consumer<PasscodeController>(
              builder: (context, controller, child) {
                if (controller.errorMessage != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Theme.of(context).colorScheme.error.withValues(alpha: 0.2),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        controller.errorMessage!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Theme.of(context).colorScheme.error,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),

            // Numeric keypad
            Expanded(
              child: GridView.count(
                crossAxisCount: 3,
                mainAxisSpacing: 12,
                crossAxisSpacing: 12,
                padding: const EdgeInsets.only(top: 24),
                children: [
                  // Numbers 1-9
                  for (int i = 1; i <= 9; i++)
                    _buildKeypadButton(
                      i.toString(),
                      onPressed: () => _onDigitPressed(i.toString()),
                    ),
                  // Delete button
                  _buildKeypadButton(
                    '←',
                    onPressed: _onDeletePressed,
                    isDelete: true,
                  ),
                  // 0
                  _buildKeypadButton(
                    '0',
                    onPressed: () => _onDigitPressed('0'),
                  ),
                  // Clear button
                  _buildKeypadButton(
                    'C',
                    onPressed: _onClearPressed,
                    isClear: true,
                  ),
                ],
              ),
            ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildKeypadButton(
    String label, {
    required VoidCallback onPressed,
    bool isDelete = false,
    bool isClear = false,
  }) {
    final theme = Theme.of(context);
    final Color buttonColor = isDelete || isClear
        ? theme.colorScheme.error
        : theme.colorScheme.surface;
    final Color textColor = theme.colorScheme.onSurface;

    return Material(
      color: buttonColor,
      borderRadius: BorderRadius.circular(12),
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Center(
          child: Text(
            label,
            style: TextStyle(
              fontSize: 24,
              fontWeight: FontWeight.w600,
              color: textColor,
            ),
          ),
        ),
      ),
    );
  }
}
