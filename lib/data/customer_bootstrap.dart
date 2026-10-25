import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';

/// Logs only operation/collection/error code, without UID or document paths.
Future<T> customerAccess<T>(String operation, String path, String uid,
    Future<T> Function() action) async {
  final active = FirebaseAuth.instance.currentUser;
  if (active?.uid != uid) {
    throw StateError('Sua sessão mudou. Entre novamente.');
  }
  if (kDebugMode) {
    debugPrint('[customer-bootstrap] operation=$operation '
        'collection=${path.split('/').first}');
  }
  try {
    final result = await action();
    if (FirebaseAuth.instance.currentUser?.uid != uid) {
      throw StateError('Sua sessão mudou. Entre novamente.');
    }
    return result;
  } on FirebaseException catch (error) {
    if (kDebugMode) {
      debugPrint('[customer-bootstrap] operation=$operation '
          'collection=${path.split('/').first} code=${error.code}');
    }
    rethrow;
  }
}

/// A transaction never overwrites data created concurrently by another session.
Future<Map<String, dynamic>> initializeCustomerDocument(
        DocumentReference<Map<String, dynamic>> ref,
        String uid,
        Map<String, dynamic> initial) =>
    customerAccess(
        'get-or-create',
        ref.path,
        uid,
        () => ref.firestore.runTransaction((tx) async {
              final snapshot = await tx.get(ref);
              if (snapshot.exists) return snapshot.data()!;
              if (FirebaseAuth.instance.currentUser?.uid != uid) {
                throw StateError('Sua sessão mudou. Entre novamente.');
              }
              tx.set(ref, initial);
              // Local onboarding does not depend on unresolved server timestamps.
              return <String, dynamic>{};
            }));
