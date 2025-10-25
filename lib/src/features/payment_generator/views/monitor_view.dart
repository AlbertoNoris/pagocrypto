import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pagocrypto/src/features/payment_generator/controllers/payment_monitor_controller.dart';

class MonitorView extends StatefulWidget {
  const MonitorView({super.key});

  @override
  State<MonitorView> createState() => _MonitorViewState();
}

class _MonitorViewState extends State<MonitorView> {
  late final PaymentMonitorController _controller;

  @override
  void initState() {
    super.initState();
    _controller = context.read<PaymentMonitorController>();
    _controller.startMonitoring(); // Start polling
  }

  @override
  void dispose() {
    _controller.stopMonitoring(); // Stop polling
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Monitoring Payment'),
        leading: IconButton(
          icon: const Icon(Icons.close),
          onPressed: () {
            _controller.stopMonitoring();
            context.go('/');
          },
        ),
      ),
      body: Consumer<PaymentMonitorController>(
        builder: (context, controller, child) {
          if (controller.isLoading) {
            return const Center(child: CircularProgressIndicator());
          }
          return Padding(
            padding: const EdgeInsets.all(16.0),
            child: Column(
              children: [
                _buildStatusHeader(context, controller),
                const SizedBox(height: 24),
                _buildTransactionList(context, controller),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _buildStatusHeader(
    BuildContext context,
    PaymentMonitorController controller,
  ) {
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

  Widget _buildTransactionList(
    BuildContext context,
    PaymentMonitorController controller,
  ) {
    if (controller.receivedTransactions.isEmpty) {
      return const Expanded(
        child: Center(child: Text('No incoming transactions detected yet.')),
      );
    }
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Received Transactions',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const Divider(),
          Expanded(
            child: ListView.builder(
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
          ),
        ],
      ),
    );
  }
}
