import 'package:flutter/material.dart';
import 'data/customer_staging_bootstrap.dart';
import 'main.dart' show ChamaeDeliveryApp;
import 'l10n/locale_controller.dart';
export 'data/customer_staging_bootstrap.dart'
    show initializeCustomerStagingSession;

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final locale = await LocaleController.load();
  runApp(ChamaeDeliveryApp(initialize: initializeCustomerStagingSession,
    localeController: locale));
}
