import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:pagocrypto/src/features/payment_generator/controllers/payment_generator_controller.dart';
import 'package:pagocrypto/src/features/payment_generator/controllers/passcode_controller.dart';
import 'package:pagocrypto/src/features/payment_generator/views/home_view.dart';
import 'package:pagocrypto/src/features/payment_generator/views/settings_view.dart';
import 'package:pagocrypto/src/features/payment_generator/views/qr_display_view.dart';
import 'package:pagocrypto/src/features/payment_generator/views/passcode_view.dart';

/// Defines the application's routes using GoRouter.
class AppRouter {
  static final router = GoRouter(
    initialLocation: '/',
    routes: [
      // Use a ShellRoute to provide a shared ChangeNotifierProvider
      // to all child routes. This ensures HomeView and SettingsView
      // use the SAME controller instance.
      ShellRoute(
        builder: (context, state, child) {
          // The provider is injected here, above the views
          return ChangeNotifierProvider(
            create: (_) => PaymentGeneratorController(),
            child: child, // The child will be either HomeView or SettingsView
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
