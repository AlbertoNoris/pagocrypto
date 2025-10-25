import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pagocrypto/src/core/config/chain_config.dart';
import 'package:pagocrypto/src/core/services/etherscan_service.dart';
import 'package:pagocrypto/src/features/payment_generator/controllers/payment_generator_controller.dart';
import 'package:pagocrypto/src/features/payment_generator/controllers/passcode_controller.dart';
import 'package:pagocrypto/src/features/payment_generator/views/home_view.dart';
import 'package:pagocrypto/src/features/payment_generator/views/settings_view.dart';
import 'package:pagocrypto/src/features/payment_generator/views/qr_display_view.dart';
import 'package:pagocrypto/src/features/payment_generator/views/passcode_view.dart';

/// Defines the application's routes using GoRouter.
///
/// This router uses a ShellRoute to provide a shared PaymentGeneratorController
/// along with EtherscanService and ChainConfig to all child routes, enabling
/// block-cursor anchoring for payment monitoring.
class AppRouter {
  /// Chain configuration for BSC (Binance Smart Chain).
  /// API Key and token address are configured here.
  static final _chainConfig = ChainConfig.bsc(
    apiKey: 'UP1PWX9D5Y4PWRVBQ5WY2Q9SQCN9WC8TVI',
    tokenAddress: '0x9d1A7A3191102e9F900Faa10540837ba84dCBAE7',
  );

  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      // Use a ShellRoute to provide shared dependencies and controller
      // to all child routes. This ensures HomeView, SettingsView, and QrDisplayView
      // use the SAME PaymentGeneratorController instance.
      ShellRoute(
        builder: (context, state, child) {
          // Provide ChainConfig, EtherscanService, and PaymentGeneratorController
          // at this level so they're shared across all routes
          return MultiProvider(
            providers: [
              Provider<ChainConfig>(create: (_) => _chainConfig),
              Provider<EtherscanService>(
                create: (context) =>
                    EtherscanService(config: context.read<ChainConfig>()),
              ),
              ChangeNotifierProvider(
                create: (context) => PaymentGeneratorController(
                  etherscanService: context.read<EtherscanService>(),
                  chainConfig: context.read<ChainConfig>(),
                ),
              ),
            ],
            child:
                child, // The child will be either HomeView, SettingsView, or QrDisplayView
          );
        },
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => const HomeView(),
            routes: [
              GoRoute(
                path: 'qr',
                builder: (context, state) => const QrDisplayView(),
              ),
            ],
          ),
          GoRoute(
            path: '/passcode',
            builder: (context, state) => ChangeNotifierProvider(
              create: (_) => PasscodeController(),
              child: const PasscodeView(),
            ),
          ),
          GoRoute(
            path: '/settings',
            builder: (context, state) => const SettingsView(),
          ),
        ],
      ),
    ],
  );
}
