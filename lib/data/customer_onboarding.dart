import 'package:flutter/foundation.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'customer_bootstrap.dart';

class CustomerPolicy {
  final String revision, termsVersion, privacyVersion, alcoholVersion;
  final String termsText, privacyText, alcoholNotice, contentHash;
  final String? termsUrl, privacyUrl;
  final bool published, draft;
  const CustomerPolicy(
      {required this.revision,
      required this.termsVersion,
      required this.privacyVersion,
      required this.alcoholVersion,
      required this.termsText,
      required this.privacyText,
      required this.alcoholNotice,
      required this.contentHash,
      this.termsUrl,
      this.privacyUrl,
      this.published = false,
      this.draft = true});
  factory CustomerPolicy.fromMap(Map<String, dynamic> map) => CustomerPolicy(
      revision: map['revision']?.toString() ?? '',
      termsVersion: map['termsVersion']?.toString() ?? '',
      privacyVersion: map['privacyVersion']?.toString() ?? '',
      alcoholVersion: map['alcoholVersion']?.toString() ?? '',
      termsText: map['termsText']?.toString() ?? '',
      privacyText: map['privacyText']?.toString() ?? '',
      alcoholNotice: map['alcoholNotice']?.toString() ?? '',
      contentHash: map['contentHash']?.toString() ?? '',
      termsUrl: map['termsUrl'] as String?,
      privacyUrl: map['privacyUrl'] as String?,
      published: map['published'] == true,
      draft: map['draft'] != false ||
          [map['termsVersion'], map['privacyVersion'], map['alcoholVersion']]
              .any((v) => v.toString().toLowerCase().contains('draft')));
  // This override exists only to test the build-mode matrix. Runtime callers
  // always use the compile-time kDebugMode default (profile also stays blocked).
  bool allowsDevelopmentOnboarding({bool debugMode = kDebugMode}) =>
      debugMode && draft;

  bool canContinueOnboarding({bool debugMode = kDebugMode}) =>
      available || allowsDevelopmentOnboarding(debugMode: debugMode);

  // Keep every version in the session key so a policy change invalidates access.
  String get developmentSessionKey =>
      '$revision|$termsVersion|$privacyVersion|$alcoholVersion|$contentHash';

  bool get available =>
      published &&
      !draft &&
      revision.isNotEmpty &&
      contentHash.isNotEmpty &&
      termsVersion.isNotEmpty &&
      privacyVersion.isNotEmpty &&
      alcoholVersion.isNotEmpty &&
      termsText.trim().isNotEmpty &&
      privacyText.trim().isNotEmpty &&
      alcoholNotice.trim().isNotEmpty &&
      Uri.tryParse(termsUrl ?? '')?.scheme == 'https' &&
      Uri.tryParse(privacyUrl ?? '')?.scheme == 'https';
}

const developmentCustomerPolicy = CustomerPolicy(
    revision: 'draft-2026-10-18',
    termsVersion: 'draft-2026-10-18',
    privacyVersion: 'draft-2026-10-18',
    alcoholVersion: 'draft-2026-10-18',
    contentHash: '',
    draft: true,
    termsText:
        'DRAFT — Documento de desenvolvimento. Os Termos de Uso oficiais ainda não foram publicados.',
    privacyText:
        'DRAFT — Documento de desenvolvimento. A Política de Privacidade oficial ainda não foi publicada.',
    alcoholNotice:
        'DRAFT — As regras oficiais de elegibilidade e conferência de documento no recebimento estão pendentes de aprovação.');

class CustomerOnboardingState {
  final CustomerPolicy policy;
  final Map<String, dynamic> profile;
  const CustomerOnboardingState(this.policy, this.profile);
  bool get acceptedCurrent =>
      policy.available &&
      profile['birthDate'] is String &&
      parseBirthDate(profile['birthDate']) != null &&
      profile['termsVersion'] == policy.termsVersion &&
      profile['privacyVersion'] == policy.privacyVersion &&
      profile['alcoholVersion'] == policy.alcoholVersion &&
      profile['policyHash'] == policy.contentHash &&
      profile['policyRevision'] == policy.revision &&
      profile['acceptedAt'] != null;
}

DateTime? parseBirthDate(String value) {
  final match = RegExp(r'^(\d{4})-(\d{2})-(\d{2})$').firstMatch(value);
  if (match == null) return null;
  final year = int.parse(match[1]!),
      month = int.parse(match[2]!),
      day = int.parse(match[3]!);
  final date = DateTime.utc(year, month, day);
  final now = DateTime.now().toUtc();
  if (year < 1900 ||
      date.year != year ||
      date.month != month ||
      date.day != day ||
      date.isAfter(now)) {
    return null;
  }
  return date;
}

abstract class CustomerOnboardingRepository {
  Future<CustomerOnboardingState> load();
  Future<void> accept(CustomerPolicy policy, String birthDate);
}

class FirebaseCustomerOnboarding implements CustomerOnboardingRepository {
  final String uid;
  FirebaseCustomerOnboarding() : uid = FirebaseAuth.instance.currentUser!.uid;
  void _check() {
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Sua sessão mudou. Entre novamente.');
    }
  }

  @override
  Future<CustomerOnboardingState> load() async {
    _check();
    final policy = await customerAccess(
        'get',
        'customerPolicies/current',
        uid,
        () => FirebaseFirestore.instance
            .collection('customerPolicies')
            .doc('current')
            .get()).timeout(const Duration(seconds: 12));
    final profile = await initializeCustomerDocument(
            FirebaseFirestore.instance.collection('customerProfiles').doc(uid),
            uid,
            {'createdAt': FieldValue.serverTimestamp()})
        .timeout(const Duration(seconds: 12));
    _check();
    return CustomerOnboardingState(
        policy.exists
            ? CustomerPolicy.fromMap(policy.data()!)
            : developmentCustomerPolicy,
        profile);
  }

  @override
  Future<void> accept(CustomerPolicy policy, String birthDate) async {
    _check();
    if (!policy.available || parseBirthDate(birthDate) == null) {
      throw StateError('Confira seus dados e os documentos disponíveis.');
    }
    await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
        .httpsCallable('chamaeAceitarDocumentosCliente')
        .call({
      'birthDate': birthDate,
      'termsVersion': policy.termsVersion,
      'privacyVersion': policy.privacyVersion,
      'alcoholVersion': policy.alcoholVersion,
      'policyRevision': policy.revision,
      'policyHash': policy.contentHash,
      'acceptTerms': true,
      'acknowledgePrivacy': true,
      'acknowledgeAlcohol': true,
    }).timeout(const Duration(seconds: 15));
    _check();
  }
}
