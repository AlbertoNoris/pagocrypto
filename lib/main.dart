import 'package:flutter/material.dart';
import 'package:pagocrypto/src/core/navigation/app_router.dart';

void main() async {
  // Ensure bindings are initialized, required for SharedPreferences.
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'Crypto QR Generator',
      routerConfig: AppRouter.router,
      theme: ThemeData.dark(useMaterial3: true),
      debugShowCheckedModeBanner: false,
    );
  }
}
