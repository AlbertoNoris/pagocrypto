import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:pagocrypto/src/core/services/etherscan_service.dart';
import 'package:pagocrypto/src/features/payment_generator/controllers/payment_generator_controller.dart';
import 'package:pagocrypto/src/features/payment_generator/controllers/payment_monitor_controller.dart';

class QrDisplayView extends StatefulWidget {
  const QrDisplayView({super.key});

  @override
  State<QrDisplayView> createState() => _QrDisplayViewState();
}

class _QrDisplayViewState extends State<QrDisplayView> {
  late PaymentGeneratorController _generatorController;
  late PaymentMonitorController _monitorController;
  bool _monitoringInitialized = false;

  @override
  void initState() {
    super.initState();
    _generatorController = context.read<PaymentGeneratorController>();
    _generatorController.addListener(_handleGeneratorEvents);
  }

  @override
  void dispose() {
    _generatorController.removeListener(_handleGeneratorEvents);
    _monitorController.stopMonitoring();
    super.dispose();
  }

  /// Initializes the monitoring controller and starts monitoring
  void _initializeMonitoring(PaymentGeneratorController generator) {
    if (_monitoringInitialized) return;

    // Validate required data exists before proceeding
    if (generator.finalAmount == null ||
        generator.qrCreationTimestamp == null ||
        generator.receivingAddress == null) {
      return;
    }

    _monitorController = PaymentMonitorController(
      amountRequested: generator.finalAmount!,
      qrCreationTimestamp: generator.qrCreationTimestamp!,
      receivingAddress: generator.receivingAddress!,
      etherscanService: EtherscanService(),
    );
    _monitorController.startMonitoring();
    _monitoringInitialized = true;
  }

  /// Handles all one-time events from the generator controller
  void _handleGeneratorEvents() {
    // Handle URL cleared event - navigate back to home
    if (_generatorController.generatedUrl == null && mounted) {
      context.go('/');
    }

    // Handle clipboard message feedback
    if (_generatorController.clipboardMessage != null && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(_generatorController.clipboardMessage!),
          duration: const Duration(seconds: 2),
        ),
      );
      _generatorController.onClipboardMessageShown();
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
        builder: (context, generatorController, child) {
          // Show content if URL exists
          if (generatorController.generatedUrl == null) {
            return const SizedBox.shrink();
          }

          // Initialize monitoring on first render when URL is available
          _initializeMonitoring(generatorController);

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
                                data: generatorController.generatedUrl!,
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

                  // Final Amount Display
                  _buildFinalAmountDisplay(generatorController),
                  const SizedBox(height: 24),

                  // Payment Monitoring Section
                  if (_monitoringInitialized)
                    ChangeNotifierProvider.value(
                      value: _monitorController,
                      child: _buildMonitoringSection(),
                    )
                  else
                    const SizedBox(height: 32),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildMonitoringSection() {
    return Consumer<PaymentMonitorController>(
      builder: (context, monitorController, child) {
        return Column(
          children: [
            _buildStatusHeader(monitorController),
            const SizedBox(height: 24),
            if (monitorController.receivedTransactions.isNotEmpty)
              _buildTransactionList(monitorController)
            else
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 24.0),
                child: Text(
                  'No incoming transactions detected yet.',
                  textAlign: TextAlign.center,
                  style: Theme.of(context).textTheme.bodyMedium,
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _buildStatusHeader(PaymentMonitorController controller) {
    final style = Theme.of(context).textTheme;
    String statusText;
    IconData statusIcon;

    switch (controller.status) {
      case PaymentStatus.monitoring:
        statusText = 'Waiting for payment...';
        statusIcon = Icons.hourglass_empty;
        break;
      case PaymentStatus.partiallyPaid:
        statusText = 'Partial payment received!';
        statusIcon = Icons.downloading;
        break;
      case PaymentStatus.completed:
        statusText = 'Payment Completed!';
        statusIcon = Icons.check_circle;
        break;
      case PaymentStatus.error:
        statusText = controller.errorMessage ?? 'Error checking status.';
        statusIcon = Icons.error_outline;
        break;
    }

    return Container(
      decoration: BoxDecoration(
        color: Theme.of(context).colorScheme.secondary,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(statusIcon, color: Colors.white, size: 28),
                const SizedBox(width: 12),
                Text(
                  statusText,
                  style: style.titleLarge?.copyWith(color: Colors.white),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text.rich(
              TextSpan(
                text: 'Amount Left: ',
                style: style.titleMedium?.copyWith(color: Colors.white),
                children: [
                  TextSpan(
                    text: '${controller.amountLeft.toStringAsFixed(2)} EURI',
                    style: style.headlineMedium?.copyWith(
                      fontWeight: FontWeight.bold,
                      color: Colors.white,
                    ),
                  ),
                ],
              ),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            Text(
              'Total Requested: ${controller.amountRequested.toStringAsFixed(2)} EURI',
              style: style.bodyMedium?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            Text(
              'Total Received: ${controller.amountReceived.toStringAsFixed(2)} EURI',
              style: style.bodyMedium?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildTransactionList(PaymentMonitorController controller) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Received Transactions',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Divider(),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: controller.receivedTransactions.length,
          itemBuilder: (context, index) {
            final tx = controller.receivedTransactions[index];
            return ListTile(
              title: Text('${tx.amount} EURI'),
              subtitle: Text(
                'From: ${tx.from}',
                overflow: TextOverflow.ellipsis,
              ),
              trailing: const Icon(Icons.check_box, color: Colors.green),
            );
          },
        ),
      ],
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

}
