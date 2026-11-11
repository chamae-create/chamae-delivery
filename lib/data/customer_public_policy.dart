import 'package:cloud_firestore/cloud_firestore.dart';
import 'customer_onboarding.dart';

/// Public legal content only: never signs in or creates a customer profile.
class CustomerPublicPolicy {
  final FirebaseFirestore? firestore;
  CustomerPublicPolicy({this.firestore});

  Future<CustomerPolicy> load() async {
    final snapshot = await (firestore ?? FirebaseFirestore.instance)
        .collection('customerPolicies')
        .doc('current')
        .get(const GetOptions(source: Source.server))
        .timeout(const Duration(seconds: 12));
    if (!snapshot.exists) throw StateError('POLICY_UNAVAILABLE');
    final policy = CustomerPolicy.fromMap(snapshot.data()!);
    if (!policy.available) throw StateError('POLICY_UNAVAILABLE');
    return policy;
  }
}
