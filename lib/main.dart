import 'l10n/customer_localizations.dart';
import 'l10n/locale_controller.dart';
import 'dart:ui';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'firebase_options.dart';
import 'core/theme.dart';
import 'screens/splash_screen.dart';
import 'data/customer_staging_bootstrap.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final locale = await LocaleController.load();
  runApp(ChamaeDeliveryApp(localeController: locale));
}

Future<void> initializeCustomerSession() async {
  if (const String.fromEnvironment('CHAMAE_ENV') == 'STAGING') {
    return initializeCustomerStagingSession();
  }
  if (const String.fromEnvironment('CHAMAE_ENV').isNotEmpty) {
    throw StateError('CHAMAE_ENV_INVALID');
  }
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
  final Future<void> Function() initialize;
  final LocaleController? localeController;
  static final fallbackLocale = LocaleController(persist: (_) async {});
  const ChamaeDeliveryApp(
      {super.key,
      this.initialize = initializeCustomerSession,
      this.localeController});

  @override
  Widget build(BuildContext context) {
    final controller = localeController ?? fallbackLocale;
    return AnimatedBuilder(
        animation: controller,
        builder: (context, _) => LocaleScope(
            controller: controller,
            child: MaterialApp(
              locale: controller.locale,
              supportedLocales: const [Locale("pt", "BR"), Locale("es", "PY")],
              localizationsDelegates: AppLocalizations.localizationsDelegates,
              localeResolutionCallback: (locale, supported) =>
                  LocaleController.resolve(locale),
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
                                    size: Size(constraints.maxWidth,
                                        constraints.maxHeight)),
                                child: ClipRect(child: child))),
                      ),
                    ),
                  ),
                );
              },
              home: SplashScreen(initialize: initialize),
            )));
  }
}
