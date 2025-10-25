import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pagocrypto/src/features/payment_generator/controllers/payment_generator_controller.dart';

class SettingsView extends StatefulWidget {
  const SettingsView({super.key});

  @override
  State<SettingsView> createState() => _SettingsViewState();
}

class _SettingsViewState extends State<SettingsView> {
  late final TextEditingController _addressController;
  late final TextEditingController _multiplierController;
  late final PaymentGeneratorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<PaymentGeneratorController>();

    _addressController = TextEditingController(
      text: _controller.receivingAddress,
    );
    _multiplierController = TextEditingController(
      text: _controller.amountMultiplier?.toString(),
    );
  }

  @override
  void dispose() {
    _addressController.dispose();
    _multiplierController.dispose();
    super.dispose();
  }

  void _save() async {
    await _controller.saveSettings(
      address: _addressController.text,
      multiplierString: _multiplierController.text,
    );

    // If save was successful (no error message), close the settings view
    if (_controller.errorMessage == null && mounted) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings Saved!')));
      // Brief delay to let snackbar display before popping
      await Future.delayed(const Duration(milliseconds: 300));
      if (mounted && context.canPop()) {
        context.pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Settings'),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () {
            if (context.canPop()) {
              context.pop();
            } else {
              context.go('/');
            }
          },
        ),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Receiving Address (0x...)',
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _multiplierController,
              decoration: const InputDecoration(
                labelText: 'Amount Multiplier (e.g., 1.03)',
              ),
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
            ),
            const SizedBox(height: 24),
            // Listen for and display errors
            Consumer<PaymentGeneratorController>(
              builder: (context, controller, child) {
                if (controller.errorMessage != null) {
                  return Padding(
                    padding: const EdgeInsets.only(bottom: 16.0),
                    child: Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFF6B6B),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        controller.errorMessage!,
                        style: const TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            ElevatedButton(onPressed: _save, child: const Text('Save')),
          ],
        ),
      ),
    );
  }
}
