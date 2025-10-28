import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pagocrypto/src/core/config/chain_config.dart';
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

  /// Initializes the monitoring controller and starts monitoring.
  ///
  /// Uses block-cursor anchoring: monitors from the startBlock forward
  /// instead of using timestamp filtering.
  void _initializeMonitoring(PaymentGeneratorController generator) {
    if (_monitoringInitialized) return;

    // Validate required data exists before proceeding
    if (generator.finalAmount == null ||
        generator.qrStartBlock == null ||
        generator.receivingAddress == null) {
      debugPrint('Cannot initialize monitoring: missing required data');
      debugPrint('  finalAmount: ${generator.finalAmount}');
      debugPrint('  qrStartBlock: ${generator.qrStartBlock}');
      debugPrint('  receivingAddress: ${generator.receivingAddress}');
      return;
    }

    // Create monitor controller with block-cursor anchor
    _monitorController = PaymentMonitorController(
      amountRequested: generator.finalAmount!,
      startBlock: generator.qrStartBlock!,
      receivingAddress: generator.receivingAddress!,
      etherscanService: context.read<EtherscanService>(),
      chainConfig: context.read<ChainConfig>(),
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

  /// Builds the QR code widget - shows loading indicator while generating,
  /// then displays the QR code image from qr.io API.
  Widget _buildQrCodeWidget(PaymentGeneratorController controller) {
    // Show loading indicator while QR code is being generated
    if (controller.isGeneratingQrCode || controller.qrCodeImageData == null) {
      return const SizedBox(
        width: 250.0,
        height: 250.0,
        child: Center(
          child: CircularProgressIndicator(),
        ),
      );
    }

    // Display the QR code image from the API
    // Check if it's a URL or base64 data
    if (controller.qrCodeImageData!.startsWith('http')) {
      // It's a URL
      return Image.network(
        controller.qrCodeImageData!,
        width: 250.0,
        height: 250.0,
        fit: BoxFit.contain,
        loadingBuilder: (context, child, loadingProgress) {
          if (loadingProgress == null) return child;
          return SizedBox(
            width: 250.0,
            height: 250.0,
            child: Center(
              child: CircularProgressIndicator(
                value: loadingProgress.expectedTotalBytes != null
                    ? loadingProgress.cumulativeBytesLoaded /
                        loadingProgress.expectedTotalBytes!
                    : null,
              ),
            ),
          );
        },
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 250.0,
            height: 250.0,
            color: const Color(0xFFECD354),
            child: const Center(
              child: Icon(Icons.error, size: 48, color: Colors.red),
            ),
          );
        },
      );
    } else {
      // Assume it's base64 data
      return Image.memory(
        Uri.parse(controller.qrCodeImageData!).data!.contentAsBytes(),
        width: 250.0,
        height: 250.0,
        fit: BoxFit.contain,
        errorBuilder: (context, error, stackTrace) {
          return Container(
            width: 250.0,
            height: 250.0,
            color: const Color(0xFFECD354),
            child: const Center(
              child: Icon(Icons.error, size: 48, color: Colors.red),
            ),
          );
        },
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        //title: const Text('Payment QR Code'),
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
                  // QR Code Card - hidden when payment is completed
                  if (!(_monitoringInitialized &&
                      _monitorController.status == PaymentStatus.completed))
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
                                child: _buildQrCodeWidget(generatorController),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  if (!(_monitoringInitialized &&
                      _monitorController.status == PaymentStatus.completed))
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
              SizedBox.shrink(),
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
        statusText = 'In attesa del pagamento';
        statusIcon = Icons.hourglass_empty;
        break;
      case PaymentStatus.partiallyPaid:
        statusText = 'Somma corrisposta solo in parte';
        statusIcon = Icons.downloading;
        break;
      case PaymentStatus.completed:
        statusText = 'Pagamento completato!';
        statusIcon = Icons.check_circle;
        break;
      case PaymentStatus.error:
        statusText = controller.errorMessage ?? '';
        statusIcon = Icons.hourglass_empty;
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
                RichText(
                  text: TextSpan(
                    text: statusText,
                    style: style.titleLarge?.copyWith(color: Colors.white),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text.rich(
              TextSpan(
                text: 'Importo dovuto: ',
                style: style.titleMedium?.copyWith(color: Colors.white),
                children: [
                  TextSpan(
                    text:
                        '${controller.amountLeft.toStringAsFixed(2).replaceAll('.', ',')} EURI',
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
              'Totale previsto: ${controller.amountRequested.toStringAsFixed(2).replaceAll('.', ',')} EURI',
              style: style.bodyMedium?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            Text(
              'Incassato: ${controller.amountReceived.toStringAsFixed(2).replaceAll('.', ',')} EURI',
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
          'Cronologia transazioni',
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
              title: Text(
                '${tx.amount.toStringAsFixed(2).replaceAll('.', ',')} EURI',
              ),
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
            'Emesso scontrino per',
            style: TextStyle(
              color: Colors.white.withValues(alpha: 0.9),
              fontSize: 14,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            '${controller.finalAmountFormatted} €',
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
