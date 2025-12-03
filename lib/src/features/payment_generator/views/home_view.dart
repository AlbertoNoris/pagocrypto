import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pagocrypto/src/core/widgets/max_width_container.dart';
import 'package:pagocrypto/src/features/payment_generator/controllers/payment_generator_controller.dart';

class HomeView extends StatefulWidget {
  const HomeView({super.key});

  @override
  State<HomeView> createState() => _HomeViewState();
}

class _HomeViewState extends State<HomeView> {
  late TextEditingController _amountController;
  late PaymentGeneratorController _controller;

  @override
  void initState() {
    super.initState();
    _amountController = TextEditingController();

    // Listen for navigation events
    _controller = context.read<PaymentGeneratorController>();
    _controller.addListener(_handleNavigationEvent);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleNavigationEvent);
    _amountController.dispose();
    super.dispose();
  }

  /// Handles the navigation event when URL is successfully generated.
  void _handleNavigationEvent() {
    final controller = context.read<PaymentGeneratorController>();
    if (controller.navigateToQr && mounted) {
      controller.onNavigatedToQr();
      context.push('/qr');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        leading: SizedBox(width: 48), // Placeholder for centering the logo
        title: SizedBox(
          height: 30,
          child: Image.asset('assets/name3.png', fit: BoxFit.contain),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/passcode'),
          ),
        ],
      ),
      body: MaxWidthContainer(
        child: Consumer<PaymentGeneratorController>(
          builder: (context, controller, child) {
            if (controller.isLoading) {
              return const Center(child: CircularProgressIndicator());
            }
            if (controller.receivingAddress == null) {
              return _buildSettingsPrompt(context);
            }
            return _buildAmountInput(context, controller);
          },
        ),
      ),
    );
  }

  Widget _buildSettingsPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Perfavore configura le impostazioni prima di procedere.'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.push('/passcode'),
            child: Padding(
              padding: const EdgeInsets.all(8.0),
              child: const Text('Vai alle Impostazioni'),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAmountInput(
    BuildContext context,
    PaymentGeneratorController controller,
  ) {
    return SingleChildScrollView(
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.start,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Settings Info Card
              //_buildCard(
              //  title: 'Payment Settings',
              //  children: [
              //    _buildInfoRow(
              //      label: 'Receiving Address',
              //      value: controller.receivingAddress ?? 'Not set',
              //      isAddress: true,
              //    ),
              //    const SizedBox(height: 16),
              //    _buildInfoRow(
              //      label: 'Amount Multiplier',
              //      value: controller.amountMultiplier?.toString() ?? 'Not set',
              //    ),
              //  ],
              //),
              const SizedBox(height: 24),
              // Amount Input Card with Real-time Final Amount Display
              Consumer<PaymentGeneratorController>(
                builder: (context, controller, child) {
                  return Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      _buildCard(
                        title: 'Importo',
                        children: [
                          TextField(
                            controller: _amountController,
                            onChanged: (value) {
                              // Update controller state to trigger reactive rebuild
                              context
                                  .read<PaymentGeneratorController>()
                                  .updateInputAmount(value);
                            },
                            decoration: InputDecoration(
                              hintText: 'e.g., 18,90',
                              suffixText: '€',
                              hintStyle: const TextStyle(fontSize: 18),
                            ),
                            keyboardType: TextInputType.number,
                            style: const TextStyle(fontSize: 18),
                            inputFormatters: [
                              FilteringTextInputFormatter.digitsOnly,
                              TextInputFormatter.withFunction((
                                oldValue,
                                newValue,
                              ) {
                                if (newValue.text.isEmpty) {
                                  return newValue;
                                }

                                // Remove any non-digit characters
                                String digitsOnly = newValue.text.replaceAll(
                                  RegExp(r'\D'),
                                  '',
                                );

                                if (digitsOnly.isEmpty) {
                                  return newValue.copyWith(text: '');
                                }

                                // Pad with leading zero if needed to ensure at least 2 digits
                                if (digitsOnly.length == 1) {
                                  digitsOnly = '0$digitsOnly';
                                }

                                // Format: last 2 digits are cents
                                // e.g., "189" -> "1,89", "89" -> "0,89", "1890" -> "18,90"
                                String integerPart = digitsOnly.substring(
                                  0,
                                  digitsOnly.length - 2,
                                );
                                String decimalPart = digitsOnly.substring(
                                  digitsOnly.length - 2,
                                );

                                if (integerPart.isEmpty) {
                                  integerPart = '0';
                                } else {
                                  // Remove leading zeros from integer part (except if it's just "0")
                                  integerPart = integerPart.replaceFirst(
                                    RegExp(r'^0+(?=\d)'),
                                    '',
                                  );
                                  if (integerPart.isEmpty) {
                                    integerPart = '0';
                                  }
                                }

                                final formattedText =
                                    '$integerPart,$decimalPart';

                                return newValue.copyWith(
                                  text: formattedText,
                                  selection: TextSelection.collapsed(
                                    offset: formattedText.length,
                                  ),
                                );
                              }),
                            ],
                          ),
                        ],
                      ),
                      // const SizedBox(height: 24),
                      // Final Amount Display
                      //if (finalAmount != null)
                      //  Container(
                      //    padding: const EdgeInsets.all(16),
                      //    decoration: BoxDecoration(
                      //      color: Theme.of(context).colorScheme.secondary,
                      //      borderRadius: BorderRadius.circular(12),
                      //    ),
                      //    child: Column(
                      //      children: [
                      //        Text(
                      //          'Final Amount to Request',
                      //          style: TextStyle(
                      //            color: Colors.white.withValues(alpha: 0.9),
                      //            fontSize: 14,
                      //            fontWeight: FontWeight.w500,
                      //          ),
                      //        ),
                      //        const SizedBox(height: 8),
                      //        Text(
                      //          finalAmount.toStringAsFixed(2),
                      //          style: const TextStyle(
                      //            fontSize: 32,
                      //            fontWeight: FontWeight.bold,
                      //            color: Colors.white,
                      //          ),
                      //        ),
                      //      ],
                      //    ),
                      //  ),
                    ],
                  );
                },
              ),
              const SizedBox(height: 24),
              if (controller.errorMessage != null)
                Padding(
                  padding: const EdgeInsets.only(bottom: 16.0),
                  child: Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: Theme.of(
                        context,
                      ).colorScheme.error.withValues(alpha: 0.2),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      controller.errorMessage!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ),
              const SizedBox(height: 32),
              // Generate Button
              Consumer<PaymentGeneratorController>(
                builder: (context, controller, child) {
                  final isGenerating = controller.isGeneratingQr;
                  return ElevatedButton(
                    onPressed: isGenerating
                        ? null
                        : () async {
                            // generateUrl is now async due to block fetching
                            await context
                                .read<PaymentGeneratorController>()
                                .generateUrl(importo: _amountController.text);
                            // Navigation is now handled by the listener in initState
                          },
                    child: isGenerating
                        ? const Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Generazione in corso...',
                                style: TextStyle(fontSize: 18),
                              ),
                            ],
                          )
                        : const Text(
                            'Genera codice qr',
                            style: TextStyle(fontSize: 18),
                          ),
                  );
                },
              ),
              SizedBox(height: 56),
              // Device ID Display
              if (controller.deviceId != null)
                Text(
                  'Device ID: ${controller.deviceId}',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    // color: Colors.grey,
                  ),
                  textAlign: TextAlign.center,
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Card(
      margin: EdgeInsets.zero,
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }
}
