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

    // Listen for the one-time save event
    _controller.addListener(_onSettingsSaved);
  }

  @override
  void dispose() {
    _addressController.dispose();
    _multiplierController.dispose();
    _controller.removeListener(_onSettingsSaved);
    super.dispose();
  }

  void _onSettingsSaved() {
    if (_controller.showSettingsSavedNotice) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('Settings Saved!')));
      // Consume the event
      _controller.onSettingsSavedNoticeShown();
      // Pop back to home
      if (context.canPop()) {
        context.pop();
      }
    }
  }

  void _save() {
    _controller.saveSettings(
      address: _addressController.text,
      multiplierString: _multiplierController.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Settings')),
      body: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            TextField(
              controller: _addressController,
              decoration: const InputDecoration(
                labelText: 'Receiving Address (0x...)',
                border: OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _multiplierController,
              decoration: const InputDecoration(
                labelText: 'Amount Multiplier (e.g., 1.03)',
                border: OutlineInputBorder(),
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
                    child: Text(
                      controller.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  );
                }
                return const SizedBox.shrink();
              },
            ),
            ElevatedButton(
              onPressed: _save,
              style: ElevatedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
              child: const Text('Save'),
            ),
          ],
        ),
      ),
    );
  }
}
