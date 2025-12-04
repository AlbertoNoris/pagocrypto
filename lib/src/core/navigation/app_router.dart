import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pagocrypto/src/core/config/chain_config.dart';
import 'package:pagocrypto/src/core/services/moralis_service.dart';
import 'package:pagocrypto/src/core/services/qr_proxy_service.dart';
import 'package:pagocrypto/src/features/payment_generator/controllers/payment_generator_controller.dart';
import 'package:pagocrypto/src/features/payment_generator/controllers/passcode_controller.dart';
import 'package:pagocrypto/src/features/payment_generator/views/home_view.dart';
import 'package:pagocrypto/src/features/payment_generator/views/settings_view.dart';
import 'package:pagocrypto/src/features/payment_generator/views/qr_display_view.dart';
import 'package:pagocrypto/src/features/payment_generator/views/passcode_view.dart';

/// Defines the application's routes using GoRouter.
///
/// This router uses a ShellRoute to provide a shared PaymentGeneratorController
/// along with MoralisService, ChainConfig, and QrProxyService to all child routes.
class AppRouter {
  /// Chain configuration for BSC (Binance Smart Chain).
  /// Proxy URL is legacy/unused for Moralis but kept for config compatibility.
  static final _chainConfig = ChainConfig.bsc(
    proxyUrl: 'https://pagocrypto.vercel.app/api/bscscan-proxy',
    tokenAddress: '0x9d1A7A3191102e9F900Faa10540837ba84dCBAE7',
  );

  /// QR Proxy service endpoint (Vercel serverless function).
  static const String _qrProxyEndpoint =
      'https://pagocrypto.vercel.app/api/qr-create';

  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      // Use a ShellRoute to provide shared dependencies and controller
      // to all child routes.
      ShellRoute(
        builder: (context, state, child) {
          // Provide ChainConfig, MoralisService, QrProxyService, and PaymentGeneratorController
          return MultiProvider(
            providers: [
              Provider<ChainConfig>(create: (_) => _chainConfig),
              Provider<MoralisService>(
                create: (context) =>
                    MoralisService(config: context.read<ChainConfig>()),
              ),
              Provider<QrProxyService>(
                create: (_) => QrProxyService(_qrProxyEndpoint),
              ),
              ChangeNotifierProvider(
                create: (context) => PaymentGeneratorController(
                  moralisService: context.read<MoralisService>(),
                  chainConfig: context.read<ChainConfig>(),
                  qrProxyService: context.read<QrProxyService>(),
                ),
              ),
            ],
            child: child,
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
