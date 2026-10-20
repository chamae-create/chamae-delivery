import 'dart:async';
import 'package:chamae_delivery/core/models.dart';
import 'package:chamae_delivery/data/customer_auth.dart';
import 'package:chamae_delivery/data/customer_onboarding.dart';
import 'package:chamae_delivery/data/customer_workspace.dart';

// Test fixtures only. These are not documents or settings shipped by the app.
const testCustomerPolicy = CustomerPolicy(
    revision: 'TEST-ONLY-1',
    termsVersion: 'TEST-ONLY-1',
    privacyVersion: 'TEST-ONLY-1',
    alcoholVersion: 'TEST-ONLY-1',
    termsText: 'TEST FIXTURE TERMS',
    privacyText: 'TEST FIXTURE PRIVACY',
    alcoholNotice: 'TEST FIXTURE NOTICE',
    contentHash: 'TEST-ONLY-HASH',
    termsUrl: 'https://example.test/terms',
    privacyUrl: 'https://example.test/privacy',
    published: true,
    draft: false);
const testCustomerAddress = DeliveryAddress(
    latitude: -20,
    longitude: -50,
    countryCode: 'BR',
    street: 'Rua de teste',
    number: '1',
    city: 'Cidade de teste',
    addressText: 'Rua de teste, 1',
    label: 'Casa',
    confirmed: true);

class FlowAuth implements CustomerAuth {
  CustomerIdentity? identity;
  final events = StreamController<CustomerIdentity?>.broadcast(sync: true);
  final calls = <CustomerProvider>[];
  bool fail = false;
  int refreshes = 0;
  FlowAuth([this.identity]);
  @override
  CustomerIdentity? get current => identity;
  void change(CustomerIdentity? value) {
    identity = value;
    events.add(value);
  }

  @override
  Stream<CustomerIdentity?> get changes => Stream.multi((controller) {
        controller.add(identity);
        final sub =
            events.stream.listen(controller.add, onError: controller.addError);
        controller.onCancel = sub.cancel;
      });
  @override
  Future<void> refresh() async {
    refreshes++;
    if (fail) throw StateError('offline');
  }

  @override
  Future<void> signIn(CustomerProvider provider,
      {bool useExistingAccount = false}) async {
    calls.add(provider);
    if (fail) {
      throw const CustomerAuthFailure(
          'Não foi possível entrar agora. Tente novamente.');
    }
    change(CustomerIdentity(
        uid: identity?.uid ?? 'buyer',
        name: 'Cliente de teste',
        email: 'buyer@example.test',
        providers: [
          provider == CustomerProvider.google ? 'google.com' : 'apple.com'
        ]));
  }

  @override
  Future<void> signOut() async => change(null);
}

class FlowOnboarding implements CustomerOnboardingRepository {
  CustomerPolicy policy;
  Map<String, dynamic> profile = {};
  int acceptCalls = 0, loads = 0;
  FlowOnboarding({this.policy = testCustomerPolicy, bool accepted = false}) {
    if (accepted) _accept('2000-01-01');
  }
  void _accept(String birthDate) {
    profile = {
      'birthDate': birthDate,
      'termsVersion': policy.termsVersion,
      'privacyVersion': policy.privacyVersion,
      'alcoholVersion': policy.alcoholVersion,
      'policyRevision': policy.revision,
      'policyHash': policy.contentHash,
      'acceptedAt': DateTime.now()
    };
  }

  @override
  Future<CustomerOnboardingState> load() async {
    loads++;
    return CustomerOnboardingState(policy, profile);
  }

  @override
  Future<void> accept(CustomerPolicy policy, String birthDate) async {
    acceptCalls++;
    _accept(birthDate);
  }
}

class FlowWorkspace implements CustomerWorkspace {
  Map<String, dynamic> data = {};
  @override
  Future<Map<String, dynamic>> read() async => Map<String, dynamic>.from(data);
  @override
  Future<void> save(Map<String, dynamic> fields) async => data.addAll(fields);
  @override
  Future<bool> completeOrder(String documentId) async => false;
}
