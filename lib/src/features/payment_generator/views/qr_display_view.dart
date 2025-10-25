import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pagocrypto/src/features/payment_generator/controllers/payment_generator_controller.dart';

class QrDisplayView extends StatefulWidget {
  const QrDisplayView({super.key});

  @override
  State<QrDisplayView> createState() => _QrDisplayViewState();
}

class _QrDisplayViewState extends State<QrDisplayView> {
  late PaymentGeneratorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<PaymentGeneratorController>();
    _controller.addListener(_handleEvents);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleEvents);
    super.dispose();
  }

  /// Handles all one-time events from the controller
  void _handleEvents() {
    // Handle URL cleared event - navigate back to home
    if (_controller.generatedUrl == null && mounted) {
      context.go('/');
    }

    // Handle navigation to monitor route
    if (_controller.navigateToMonitor && mounted) {
      context.replace('/monitor');
      _controller.onNavigatedToMonitor();
    }

    // Handle clipboard message feedback
    if (_controller.clipboardMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_controller.clipboardMessage!),
          duration: const Duration(seconds: 2),
        ),
      );
      _controller.onClipboardMessageShown();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment QR Code'),
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back),
          onPressed: () => context.go('/'),
        ),
      ),
      body: Consumer<PaymentGeneratorController>(
        builder: (context, controller, child) {
          // Show content if URL exists
          if (controller.generatedUrl == null) {
            return const SizedBox.shrink();
          }

          return SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(20.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // QR Code Card
                  Card(
                    color: Colors.transparent,
                    child: Padding(
                      padding: const EdgeInsets.all(16),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Center(
                            child: Container(
                              color: Colors.transparent,
                              padding: const EdgeInsets.all(16),
                              child: QrImageView(
                                data: controller.generatedUrl!,
                                version: QrVersions.auto,
                                size: 250.0,
                                backgroundColor: const Color(0xFFECD354),
                                eyeStyle: const QrEyeStyle(
                                  eyeShape: QrEyeShape.circle,
                                  color: Color(0xFF672400),
                                ),
                                dataModuleStyle: const QrDataModuleStyle(
                                  dataModuleShape: QrDataModuleShape.circle,
                                  color: Color(0xFF672400),
                                ),
                                embeddedImage: const AssetImage(
                                  'assets/icon.png',
                                ),
                                embeddedImageStyle: const QrEmbeddedImageStyle(
                                  size: Size(60, 60),
                                ),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 24),

                  // Final Amount Display (Large)
                  _buildFinalAmountDisplay(controller),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    onPressed: () {
                      context
                          .read<PaymentGeneratorController>()
                          .requestMonitorNavigation();
                    },
                    child: const Text(
                      'Check Payment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),

                  const SizedBox(height: 24),

                  // Payment Details Card
                  // _buildPaymentDetailsCard(controller),
                  const SizedBox(height: 24),

                  // Monitoring URL Card
                  // _buildMonitoringUrlCard(controller),
                  const SizedBox(height: 24),

                  // Check Payment Button
                  const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPaymentDetailsCard(PaymentGeneratorController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Payment Details',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              label: 'Receiving Address',
              value: controller.receivingAddress ?? 'Not set',
              isAddress: true,
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              label: 'Amount Multiplier',
              value: controller.amountMultiplier?.toString() ?? 'Not set',
            ),
            const SizedBox(height: 16),
            _buildInfoRow(
              label: 'Amount',
              value: controller.inputAmount ?? 'Not set',
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFinalAmountDisplay(PaymentGeneratorController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Final Amount to Request',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            controller.finalAmountFormatted,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringUrlCard(PaymentGeneratorController controller) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Monitoring URL',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            GestureDetector(
              onTap: () {
                context
                    .read<PaymentGeneratorController>()
                    .copyMonitoringUrlToClipboard();
              },
              child: SelectableText(
                controller.bscScanUrl ?? 'Not available',
                style: TextStyle(
                  fontSize: 12,
                  fontFamily: 'Courier',
                  color: Colors.grey[600],
                ),
              ),
            ),
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
        Text(
          label,
          style: Theme.of(
            context,
          ).textTheme.labelSmall?.copyWith(color: Colors.grey[600]),
        ),
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
