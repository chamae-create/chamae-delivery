import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

enum IdentificationType { cpf, cedula, other }

bool cpfFormatValid(String input) {
  if (!RegExp(r'^[0-9.\- ]+$').hasMatch(input)) return false;
  final value = input.replaceAll(RegExp(r'[^0-9]'), '');
  if (value.length != 11 || RegExp(r'^(\d)\1{10}$').hasMatch(value))
    return false;
  final digits = value.split('').map(int.parse).toList();
  for (var size = 9; size <= 10; size++) {
    var sum = 0;
    for (var i = 0; i < size; i++) {
      sum += digits[i] * (size + 1 - i);
    }
    final remainder = (sum * 10) % 11;
    if ((remainder == 10 ? 0 : remainder) != digits[size]) return false;
  }
  return true; // Structure only: never identity, registry status or age proof.
}

bool documentFormatValid(IdentificationType type, String input) {
  if (type == IdentificationType.cpf) return cpfFormatValid(input);
  if (type == IdentificationType.cedula) {
    // Basic numeric entry only. No CPF checksum, invented CI check digit or
    // assertion of official issuance. Exact supported CI variants await provider.
    return RegExp(r'^[0-9][0-9. ]{0,24}$').hasMatch(input.trim()) &&
        input.replaceAll(RegExp(r'[^0-9]'), '').length <= 20;
  }
  return input.trim().isNotEmpty && input.trim().length <= 40;
}

class BinationalIdentity {
  const BinationalIdentity(
      {required this.fullName,
      required this.type,
      required this.issuer,
      required this.phone,
      required this.language});
  final String fullName, issuer, phone, language;
  final IdentificationType type;
  factory BinationalIdentity.fromProfile(Map<String, dynamic> profile) =>
      BinationalIdentity(
          fullName: profile['fullName'] as String? ?? '',
          type: IdentificationType.values
                  .where((t) => t.name == profile['documentType'])
                  .firstOrNull ??
              IdentificationType.cpf,
          issuer: profile['documentIssuer'] as String? ?? 'BR',
          phone: profile['phone'] as String? ?? '',
          language: profile['preferredLanguage'] as String? ?? 'pt-BR');
  Map<String, dynamic> toMap() => {
        'fullName': fullName.trim(),
        'documentType': type.name,
        'documentIssuer': issuer,
        'phone': phone,
        'preferredLanguage': language
      };
  // No raw number, DOB, nationality, address or verified flag is serialized.
}

abstract class IdentificationRepository {
  Future<void> save(BinationalIdentity identity);
}

class FirebaseIdentificationRepository implements IdentificationRepository {
  FirebaseIdentificationRepository()
      : uid = FirebaseAuth.instance.currentUser!.uid;
  final String uid;
  @override
  Future<void> save(BinationalIdentity identity) async {
    if (FirebaseAuth.instance.currentUser?.uid != uid)
      throw StateError('SESSION_CHANGED');
    await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
        .httpsCallable('chamaeAtualizarIdentificacaoCliente')
        .call(identity.toMap());
    if (FirebaseAuth.instance.currentUser?.uid != uid)
      throw StateError('SESSION_CHANGED');
  }
}
