import 'package:cloud_functions/cloud_functions.dart';

enum AgeVerificationStatus {
  notStarted,
  required,
  inProgress,
  approved,
  declined,
  expired,
  appealPending,
  unavailable
}

class AgeVerificationResult {
  const AgeVerificationResult(
      this.status, this.ageVerified, this.identityVerified);
  final AgeVerificationStatus status;
  final bool ageVerified, identityVerified;
  factory AgeVerificationResult.fromMap(Map data) {
    var status = AgeVerificationStatus.values
            .where((e) => e.name == data["status"])
            .firstOrNull ??
        AgeVerificationStatus.unavailable;
    final valid = status == AgeVerificationStatus.approved &&
        data["ageVerified"] == true &&
        data["identityVerified"] == true;
    if (status == AgeVerificationStatus.approved && !valid) {
      status = AgeVerificationStatus.unavailable;
    }
    return AgeVerificationResult(status, valid, valid);
  }
}

abstract class AgeVerificationProvider {
  Future<AgeVerificationResult> read();
  Future<AgeVerificationResult> begin(String requestId);
}

class FirebaseAgeVerificationProvider implements AgeVerificationProvider {
  Future<AgeVerificationResult> _call(
      String name, Map<String, dynamic> data) async {
    final result =
        await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
            .httpsCallable(name)
            .call(data);
    return AgeVerificationResult.fromMap(result.data as Map);
  }

  @override
  Future<AgeVerificationResult> read() =>
      _call('chamaeConsultarVerificacaoEtaria', {});
  @override
  Future<AgeVerificationResult> begin(String requestId) =>
      _call('chamaeIniciarVerificacaoEtaria', {'requestId': requestId});
}
// No fake provider is part of the application. Provider activation and verified
// results are server-side; no UI setter can approve an alcohol purchase.
