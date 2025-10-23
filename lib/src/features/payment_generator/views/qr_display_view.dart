import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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
    _controller.addListener(_handleUrlCleared);
  }

  @override
  void dispose() {
    _controller.removeListener(_handleUrlCleared);
    super.dispose();
  }

  /// Handles navigation when URL is cleared
  void _handleUrlCleared() {
    if (_controller.generatedUrl == null && mounted) {
      context.go('/');
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
          onPressed: () {
            context.read<PaymentGeneratorController>().clearGeneratedUrl();
            context.go('/');
          },
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
                  Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(color: Colors.grey[300]!, width: 1),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Payment QR Code',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        const SizedBox(height: 16),
                        Center(
                          child: Container(
                            color: Colors.white,
                            padding: const EdgeInsets.all(16),
                            child: QrImageView(
                              data: controller.generatedUrl!,
                              version: QrVersions.auto,
                              size: 250.0,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 24),
                  // Payment Details Card
                  _buildPaymentDetailsCard(controller),
                  const SizedBox(height: 24),
                  // Final Amount Display (Large)
                  _buildFinalAmountDisplay(controller),
                  const SizedBox(height: 24),
                  // Monitoring URL Card
                  _buildMonitoringUrlCard(controller),
                  const SizedBox(height: 24),
                  // Check Payment Button
                  ElevatedButton(
                    onPressed: () {
                      context.replace('/monitor');
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: Colors.black,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 18),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(12),
                      ),
                    ),
                    child: const Text(
                      'Check Payment',
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
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
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Payment Details',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
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
    );
  }

  Widget _buildFinalAmountDisplay(PaymentGeneratorController controller) {
    final finalAmountText =
        controller.finalAmount?.toStringAsFixed(2) ?? '0.00';

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.grey[200],
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Text(
            'Final Amount to Request',
            style: TextStyle(
              color: Colors.grey[600],
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            finalAmountText,
            style: const TextStyle(
              fontSize: 32,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMonitoringUrlCard(PaymentGeneratorController controller) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey[300]!, width: 1),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            'Monitoring URL',
            style: TextStyle(
              fontSize: 18,
              fontWeight: FontWeight.bold,
              color: Colors.black,
            ),
          ),
          const SizedBox(height: 12),
          GestureDetector(
            onTap: () async {
              final url = controller.bscScanUrl;
              if (url != null) {
                // Copy to clipboard
                await Clipboard.setData(ClipboardData(text: url));
                // Show snackbar feedback
                if (mounted) {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Monitoring URL copied to clipboard'),
                      duration: Duration(seconds: 2),
                    ),
                  );
                }
              }
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
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w500,
            color: Colors.grey,
          ),
        ),
        const SizedBox(height: 6),
        SelectableText(
          value,
          style: const TextStyle(
            fontSize: 14,
            fontWeight: FontWeight.w600,
            color: Colors.black,
          ),
        ),
      ],
    );
  }
}
