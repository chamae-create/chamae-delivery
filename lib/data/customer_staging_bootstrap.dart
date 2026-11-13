import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart';
import 'customer_staging_configuration.dart';
import '../firebase_options.dart' show DefaultFirebaseOptions;

/// Does not contact Firebase until all staging defines have passed validation.
Future<void> initializeCustomerStagingSession() async {
  final config = CustomerStagingConfiguration.fromEnvironment();
  // Auth endpoints use the API key. A renamed project must never reuse a
  // production key even when other supplied identifiers look like staging.
  final operationalOptions = [
    DefaultFirebaseOptions.web,
    DefaultFirebaseOptions.android,
    DefaultFirebaseOptions.ios,
    DefaultFirebaseOptions.macos,
    DefaultFirebaseOptions.windows
  ];
  if (operationalOptions
      .any((o) => o.apiKey == config.apiKey || o.appId == config.appId)) {
    throw StateError('CHAMAE_STAGING_OPERATIONAL_CONFIGURATION_FORBIDDEN');
  }
  final expectedPlatform = kIsWeb
      ? 'web'
      : switch (defaultTargetPlatform) {
          TargetPlatform.android => 'android',
          TargetPlatform.iOS || TargetPlatform.macOS => 'ios',
          _ => throw StateError('CHAMAE_STAGING_PLATFORM_UNSUPPORTED'),
        };
  if (config.appId.split(':')[2] != expectedPlatform) {
    throw StateError('CHAMAE_STAGING_PLATFORM_MISMATCH');
  }
  if (Firebase.apps.any((app) => app.name != '[DEFAULT]')) {
    throw StateError('CHAMAE_STAGING_UNEXPECTED_FIREBASE_APP');
  }
  if (Firebase.apps.isEmpty) {
    await Firebase.initializeApp(
        options: FirebaseOptions(
      apiKey: config.apiKey,
      appId: config.appId,
      messagingSenderId: config.senderId,
      projectId: config.projectId,
      storageBucket: config.storageBucket,
      authDomain: config.authDomain,
    )).timeout(const Duration(seconds: 15));
  }
  final app = Firebase.app();
  config.checkExistingProject(app.options.projectId);
  if (app.options.appId != config.appId ||
      app.options.apiKey != config.apiKey ||
      app.options.messagingSenderId != config.senderId ||
      app.options.storageBucket != config.storageBucket) {
    throw StateError('CHAMAE_STAGING_EXISTING_APP_MISMATCH');
  }
  FirebaseFirestore.instance.settings =
      const Settings(persistenceEnabled: true);
  final auth = FirebaseAuth.instance;
  if (kIsWeb) await auth.setPersistence(Persistence.LOCAL);
  await auth.authStateChanges().first.timeout(const Duration(seconds: 15));
}
