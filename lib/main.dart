import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const ChamaeDeliveryApp());
}

Future<void> initializeCustomerSession() async {
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
            options: DefaultFirebaseOptions.currentPlatform)
        .timeout(const Duration(seconds: 15));
  }
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);
  final auth = FirebaseAuth.instance;
  if (kIsWeb) await auth.setPersistence(Persistence.LOCAL);
  await auth.authStateChanges().first.timeout(const Duration(seconds: 15));
}

class AppScrollBehavior extends MaterialScrollBehavior {
  @override
  Set<PointerDeviceKind> get dragDevices => {
        PointerDeviceKind.touch,
        PointerDeviceKind.mouse,
        PointerDeviceKind.trackpad,
      };
}

class ChamaeDeliveryApp extends StatelessWidget {
  const ChamaeDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chamaê Delivery • Fronteira',
      debugShowCheckedModeBanner: false,
      scrollBehavior: AppScrollBehavior(),
      theme: AppTheme.lightTheme,
      // TRAVA O APP INTEIRO EM FORMATO DE SMARTPHONE EM QUALQUER TELA
      builder: (context, child) {
        return Container(
          color: const Color(0xFF0F0F0F), // Fundo escuro externo
          child: Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.55),
                      blurRadius: 28,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: LayoutBuilder(
                    builder: (context, constraints) => MediaQuery(
                        data: MediaQuery.of(context).copyWith(
                            size: Size(
                                constraints.maxWidth, constraints.maxHeight)),
                        child: ClipRect(child: child))),
              ),
            ),
          ),
        );
      },
      home: const SplashScreen(initialize: initializeCustomerSession),
    );
  }
}
