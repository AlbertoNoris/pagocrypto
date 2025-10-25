import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
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
          height: 200,
          child: SvgPicture.asset('assets/name.svg', fit: BoxFit.contain),
        ),
        elevation: 0,
        actions: [
          IconButton(
            icon: const Icon(Icons.settings),
            onPressed: () => context.push('/passcode'),
          ),
        ],
      ),
      body: Consumer<PaymentGeneratorController>(
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
    );
  }

  Widget _buildSettingsPrompt(BuildContext context) {
    return Center(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text('Please configure your settings first.'),
          const SizedBox(height: 16),
          ElevatedButton(
            onPressed: () => context.push('/passcode'),
            child: const Text('Go to Settings'),
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
      child: Padding(
        padding: const EdgeInsets.all(20.0),
        child: Column(
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
                final finalAmount = controller.calculateFinalAmount(
                  _amountController.text,
                );

                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    _buildCard(
                      title: 'Enter Amount',
                      children: [
                        TextField(
                          controller: _amountController,
                          onChanged: (value) {
                            // Update controller state to trigger reactive rebuild
                            context
                                .read<PaymentGeneratorController>()
                                .updateInputAmount(value);
                          },
                          decoration: InputDecoration(hintText: 'e.g., 14.61'),
                          keyboardType: const TextInputType.numberWithOptions(
                            decimal: true,
                          ),
                          style: const TextStyle(fontSize: 18),
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
                    color: const Color(0xFFFF6B6B),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    controller.errorMessage!,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 32),
            // Generate Button
            ElevatedButton(
              onPressed: () {
                context.read<PaymentGeneratorController>().generateUrl(
                  importo: _amountController.text,
                );
                // Navigation is now handled by the listener in initState
              },
              child: const Text(
                'Generate QR Code',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildCard({required String title, required List<Widget> children}) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            ...children,
          ],
        ),
      ),
    );
  }

  Widget _buildInfoRow({
    required String label,
    required String value,
    bool isAddress = false,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: Theme.of(context).textTheme.labelSmall),
        const SizedBox(height: 6),
        SelectableText(
          value,
          style: Theme.of(
            context,
          ).textTheme.bodyMedium?.copyWith(fontWeight: FontWeight.w600),
        ),
      ],
    );
  }
}
