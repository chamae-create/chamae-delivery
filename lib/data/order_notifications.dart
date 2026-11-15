import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';

enum OrderNotificationPermission { granted, denied, unavailable }

/// Top-level background FCM handler required by Firebase Messaging on iOS/Android.
@pragma('vm:entry-point')
Future<void> chamaeBackgroundMessagingHandler(RemoteMessage message) async {
  // Firebase Messaging handles system notification display automatically when
  // `notification` payload is present; keep handler lightweight and crash-free.
}

/// Permission is requested only after the customer chooses updates for an order
/// or during authorized post-login session activation.
abstract class OrderNotifications {
  Future<OrderNotificationPermission> requestForOrder(String orderId);
}

class UnconfiguredOrderNotifications implements OrderNotifications {
  const UnconfiguredOrderNotifications();
  @override
  Future<OrderNotificationPermission> requestForOrder(String orderId) async =>
      OrderNotificationPermission.unavailable;
}

/// Real Firebase Cloud Messaging adapter for customer push notifications.
class FirebaseCustomerPushNotifications implements OrderNotifications {
  FirebaseCustomerPushNotifications._();
  static final FirebaseCustomerPushNotifications instance =
      FirebaseCustomerPushNotifications._();

  static bool _listenersAttached = false;
  static String? pendingOrderId;
  static void Function(String orderId)? _onOrderOpened;
  static void Function(String title, String body, String? orderId)?
      _onForegroundMessage;

  String get _platformName {
    if (kIsWeb) return 'web';
    return switch (defaultTargetPlatform) {
      TargetPlatform.iOS => 'ios',
      TargetPlatform.android => 'android',
      _ => 'web',
    };
  }

  static Future<void> configureBackgroundHandler() async {
    if (kIsWeb) return;
    try {
      FirebaseMessaging.onBackgroundMessage(chamaeBackgroundMessagingHandler);
    } catch (_) {
      // Unsupported platform or test binding without messaging channel.
    }
  }

  Future<void> initializeAndSyncToken({
    void Function(String orderId)? onOrderOpened,
    void Function(String title, String body, String? orderId)?
        onForegroundMessage,
  }) async {
    if (Firebase.apps.isEmpty) return;
    if (onOrderOpened != null) _onOrderOpened = onOrderOpened;
    if (onForegroundMessage != null) {
      _onForegroundMessage = onForegroundMessage;
    }

    try {
      final messaging = FirebaseMessaging.instance;
      if (!kIsWeb) {
        await messaging.setForegroundNotificationPresentationOptions(
          alert: true,
          badge: true,
          sound: true,
        );
      }

      if (!_listenersAttached) {
        _listenersAttached = true;

        messaging.onTokenRefresh.listen((token) {
          unawaited(_persistToken(token));
        });

        FirebaseMessaging.onMessage.listen((message) {
          final title = message.notification?.title ?? '';
          final body = message.notification?.body ?? '';
          final orderId = message.data['orderId']?.toString();
          if (title.isNotEmpty || body.isNotEmpty) {
            _onForegroundMessage?.call(title, body, orderId);
          }
        });

        FirebaseMessaging.onMessageOpenedApp.listen((message) {
          final orderId = message.data['orderId']?.toString();
          if (orderId != null && orderId.isNotEmpty) {
            pendingOrderId = orderId;
            _onOrderOpened?.call(orderId);
          }
        });
      }

      final initial = await messaging.getInitialMessage();
      final initialOrderId = initial?.data['orderId']?.toString();
      if (initialOrderId != null && initialOrderId.isNotEmpty) {
        pendingOrderId = initialOrderId;
        _onOrderOpened?.call(initialOrderId);
      }

      await ensureRegisteredSilently();
    } catch (_) {
      // Never block app navigation when push services are unavailable.
    }
  }

  static Future<void> ensureRegisteredSilently() async {
    try {
      await instance.requestForOrder('session');
    } catch (_) {}
  }

  @override
  Future<OrderNotificationPermission> requestForOrder(String orderId) async {
    if (Firebase.apps.isEmpty) {
      return OrderNotificationPermission.unavailable;
    }
    try {
      final messaging = FirebaseMessaging.instance;
      final settings = await messaging.requestPermission(
        alert: true,
        badge: true,
        sound: true,
      );
      final granted =
          settings.authorizationStatus == AuthorizationStatus.authorized ||
              settings.authorizationStatus == AuthorizationStatus.provisional;
      if (!granted) {
        return OrderNotificationPermission.denied;
      }
      final token = await messaging.getToken();
      if (token != null && token.trim().length >= 20) {
        await _persistToken(token.trim());
      }
      return OrderNotificationPermission.granted;
    } catch (_) {
      return OrderNotificationPermission.unavailable;
    }
  }

  Future<void> _persistToken(String token) async {
    if (Firebase.apps.isEmpty) return;
    final user = FirebaseAuth.instance.currentUser;
    if (user == null || user.isAnonymous || token.trim().length < 20) return;
    try {
      await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
          .httpsCallable('chamaeRegistrarTokenPushCliente')
          .call<dynamic>({
        'token': token.trim(),
        'platform': _platformName,
      }).timeout(const Duration(seconds: 12));
    } catch (_) {
      // Silent retry will happen on next token refresh or session resume.
    }
  }
}
