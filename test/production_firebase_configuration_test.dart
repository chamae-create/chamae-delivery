import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:chamae_delivery/firebase_options.dart';

String plistString(String source, String key) =>
    RegExp('<key>$key</key>\\s*<string>([^<]+)</string>')
        .firstMatch(source)!
        .group(1)!;

void main() {
  test('Android initialization selects the official native Firebase app', () {
    final json =
        jsonDecode(File('android/app/google-services.json').readAsStringSync());
    final clients = (json['client'] as List)
        .where((c) =>
            c['client_info']['android_client_info']['package_name'] ==
            'br.com.loumak.chamae')
        .toList();
    expect(clients, hasLength(1));
    debugDefaultTargetPlatformOverride = TargetPlatform.android;
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      expect(options, same(DefaultFirebaseOptions.android));
      expect(options.appId, clients.single['client_info']['mobilesdk_app_id']);
      expect(options.appId, '1:302882774102:android:4c5058e95fed7870b92ff7');
      expect(options.projectId, json['project_info']['project_id']);
      expect(options.projectId, 'chamae-delivery');
      expect(options.messagingSenderId, json['project_info']['project_number']);
      expect(options.storageBucket, json['project_info']['storage_bucket']);
      expect(options.apiKey, clients.single['api_key'][0]['current_key']);
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: kIsWeb);

  test('iOS initialization selects the official plist Firebase app', () {
    final plist =
        File('ios/Runner/GoogleService-Info.plist').readAsStringSync();
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    try {
      final options = DefaultFirebaseOptions.currentPlatform;
      expect(options, same(DefaultFirebaseOptions.ios));
      expect(options.appId, plistString(plist, 'GOOGLE_APP_ID'));
      expect(options.appId, '1:302882774102:ios:e4e61ce4ae1ffcbfb92ff7');
      expect(options.iosBundleId, plistString(plist, 'BUNDLE_ID'));
      expect(options.iosBundleId, 'br.com.loumak.chamae');
      expect(options.projectId, plistString(plist, 'PROJECT_ID'));
      expect(options.projectId, 'chamae-delivery');
      expect(options.messagingSenderId, plistString(plist, 'GCM_SENDER_ID'));
      expect(options.storageBucket, plistString(plist, 'STORAGE_BUCKET'));
      expect(options.apiKey, plistString(plist, 'API_KEY'));
    } finally {
      debugDefaultTargetPlatformOverride = null;
    }
  }, skip: kIsWeb);

  test('existing Web Firebase app is preserved by native configuration', () {
    expect(DefaultFirebaseOptions.web.projectId, 'chamae-delivery');
    expect(DefaultFirebaseOptions.web.appId,
        '1:302882774102:web:ebcfd1d1c59a7cc3b92ff7');
    expect(DefaultFirebaseOptions.web.authDomain,
        'chamae-delivery.firebaseapp.com');
    expect(DefaultFirebaseOptions.web.storageBucket,
        'chamae-delivery.firebasestorage.app');
    if (kIsWeb) {
      expect(DefaultFirebaseOptions.currentPlatform,
          same(DefaultFirebaseOptions.web));
    }
  });

  test('FlutterFire mappings match all configured platforms and native files',
      () {
    final config = jsonDecode(File('firebase.json').readAsStringSync());
    final platforms = config['flutter']['platforms'];
    final mappings =
        platforms['dart']['lib/firebase_options.dart']['configurations'];
    expect(mappings['android'], DefaultFirebaseOptions.android.appId);
    expect(mappings['ios'], DefaultFirebaseOptions.ios.appId);
    expect(mappings['web'], DefaultFirebaseOptions.web.appId);
    expect(mappings['macos'], DefaultFirebaseOptions.macos.appId);
    expect(mappings['windows'], DefaultFirebaseOptions.windows.appId);
    for (final platform in ['android', 'ios']) {
      expect(platforms[platform]['default']['appId'], mappings[platform]);
      expect(platforms[platform]['default']['projectId'], 'chamae-delivery');
      expect(
          File(platforms[platform]['default']['fileOutput'] as String)
              .existsSync(),
          isTrue);
    }
  }, skip: kIsWeb);

  test('official iOS plist belongs to Runner group and resource build phase',
      () {
    final pbx = File('ios/Runner.xcodeproj/project.pbxproj').readAsStringSync();
    final fileId = RegExp(
            r'([A-F0-9]{24}) /\* GoogleService-Info.plist \*/ = \{isa = PBXFileReference;')
        .firstMatch(pbx)!
        .group(1)!;
    final build = RegExp(
            r'([A-F0-9]{24}) /\* GoogleService-Info.plist in Resources \*/ = \{isa = PBXBuildFile; fileRef = ([A-F0-9]{24})')
        .firstMatch(pbx)!;
    expect(build.group(2), fileId);
    final runnerGroup = pbx
        .split('97C146F01CF9000F007C117D /* Runner */ = {')[1]
        .split('};')[0];
    final resources = pbx
        .split('97C146EC1CF9000F007C117D /* Resources */ = {')[1]
        .split('};')[0];
    expect(runnerGroup, contains('$fileId /* GoogleService-Info.plist */,'));
    expect(
        resources,
        contains(
            '${build.group(1)} /* GoogleService-Info.plist in Resources */,'));
  }, skip: kIsWeb);
}
