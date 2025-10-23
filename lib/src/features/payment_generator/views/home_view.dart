import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pagocrypto/src/features/payment_generator/controllers/payment_generator_controller.dart';

class HomeView extends StatelessWidget {
  const HomeView({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Generate Payment'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.go('/settings'),
          ),
        ],
      ),
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          // Consumer rebuilds the UI when state changes
          child: Consumer<PaymentGeneratorController>(
            builder: (context, controller, child) {
              if (controller.isLoading) {
                return const CircularProgressIndicator();
              }
              if (controller.receivingAddress == null) {
                return _buildSettingsPrompt(context);
              }
              if (controller.generatedUrl != null) {
                return _buildQrDisplay(context, controller);
              }
              return _buildAmountInput(context, controller);
            },
          ),
        ),
      ),
    );
  }

  Widget _buildSettingsPrompt(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const Text('Please configure your settings first.'),
        const SizedBox(height: 16),
        ElevatedButton(
          onPressed: () => context.go('/settings'),
          child: const Text('Go to Settings'),
        ),
      ],
    );
  }

  Widget _buildAmountInput(BuildContext context, PaymentGeneratorController controller) {
    final amountController = TextEditingController();
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        TextField(
          controller: amountController,
          decoration: const InputDecoration(
            labelText: 'Amount (e.g., 14.61)',
            border: OutlineInputBorder(),
          ),
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
        ),
        if (controller.errorMessage != null)
          Padding(
            padding: const EdgeInsets.only(top: 16.0),
            child: Text(
              controller.errorMessage!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            context.read<PaymentGeneratorController>().generateUrl(
                  importo: amountController.text,
                );
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Generate QR Code'),
        ),
      ],
    );
  }

  Widget _buildQrDisplay(BuildContext context, PaymentGeneratorController controller) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          color: Colors.white,
          padding: const EdgeInsets.all(16),
          child: QrImageView(
            data: controller.generatedUrl!,
            version: QrVersions.auto,
            size: 250.0,
          ),
        ),
        const SizedBox(height: 16),
        Text(
          'Monitoring URL:',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        SelectableText(
          controller.bscScanUrl ?? 'Error',
          style: Theme.of(context).textTheme.bodySmall,
        ),
        const SizedBox(height: 24),
        ElevatedButton(
          onPressed: () {
            controller.clearGeneratedUrl();
          },
          style: ElevatedButton.styleFrom(
            padding: const EdgeInsets.symmetric(vertical: 16),
          ),
          child: const Text('Generate New Payment'),
        ),
      ],
    );
  }
}
