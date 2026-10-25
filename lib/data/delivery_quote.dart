import 'package:flutter/foundation.dart';
import 'dart:math';
import 'package:cloud_functions/cloud_functions.dart';
import '../core/models.dart';

class DeliveryQuoteException implements Exception {
  final String message;
  const DeliveryQuoteException(this.message);
}

class DeliveryQuote {
  final double fee;
  final String? id;
  final String mode;
  final double? distanceMeters;
  final String? version, routingProvider;
  final int? quotedAtMs, expiresAtMs;
  const DeliveryQuote(this.fee, this.id, this.mode,
      {this.distanceMeters,
      this.version,
      this.routingProvider,
      this.quotedAtMs,
      this.expiresAtMs});

  factory DeliveryQuote.fromMap(dynamic data) {
    if (data is! Map) throw StateError('Cotação de entrega incompleta.');
    final fee = data['deliveryFee'];
    final distance = data['distanceMeters'];
    final created = data['quotedAtMs'], expires = data['expiresAtMs'];
    if (data['mode'] != 'routeBands' ||
        fee is! num ||
        !fee.isFinite ||
        fee < 0 ||
        distance is! num ||
        !distance.isFinite ||
        distance < 0 ||
        distance > 30000 ||
        data['quoteId'] is! String ||
        !RegExp(r'^[a-f0-9]{64}$').hasMatch(data['quoteId']) ||
        data['version'] is! String ||
        (data['version'] as String).isEmpty ||
        data['distanceUnit'] != 'm' ||
        data['distanceSource'] != 'route' ||
        data['routingProvider'] is! String ||
        (data['routingProvider'] as String).isEmpty ||
        created is! int ||
        expires is! int ||
        expires <= created ||
        expires <= DateTime.now().millisecondsSinceEpoch) {
      throw StateError('Cotação de entrega inválida ou expirada.');
    }
    return DeliveryQuote(fee.toDouble(), data['quoteId'], 'routeBands',
        distanceMeters: distance.toDouble(),
        version: data['version'],
        routingProvider: data['routingProvider'],
        quotedAtMs: created,
        expiresAtMs: expires);
  }
}

abstract class DeliveryQuoter {
  Future<DeliveryQuote> quote(DeliveryAddress destination);
}

class FirebaseDeliveryQuoter implements DeliveryQuoter {
  @override
  Future<DeliveryQuote> quote(DeliveryAddress destination) async {
    final requestId =
        List.generate(24, (_) => Random.secure().nextInt(16).toRadixString(16))
            .join();
    dynamic result;
    try {
      result = await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
          .httpsCallable('chamaeCotarEntrega')
          .call({
        'destination': destination.toMap(),
        'requestId': requestId
      }).timeout(const Duration(seconds: 15));
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      if (details is Map && details['reason'] == 'OUT_OF_RANGE') {
        throw const DeliveryQuoteException(
            'Este endereço está fora da área de entrega disponível no momento.');
      }
      rethrow;
    }
    return DeliveryQuote.fromMap(result.data);
  }
}

// A destination change invalidates the previous quote immediately. Results from
// older requests cannot overwrite a newer destination, even if they arrive last.
class DeliveryQuoteController extends ChangeNotifier {
  final DeliveryQuoter quoter;
  DeliveryQuoteController(this.quoter);
  DeliveryAddress? destination;
  DeliveryQuote? value;
  String? error;
  bool loading = false, _disposed = false;
  int _generation = 0;

  Future<void> refresh(DeliveryAddress address) async {
    if (_disposed) return;
    final generation = ++_generation;
    destination = address;
    value = null;
    error = null;
    loading = true;
    notifyListeners();
    try {
      if (!address.confirmed ||
          !address.hasCoordinates ||
          !['BR', 'PY'].contains(address.countryCode)) {
        throw const DeliveryQuoteException('Confirme o destino da entrega.');
      }
      final result = await quoter.quote(address);
      if (_disposed || generation != _generation) return;
      value = result;
    } catch (e) {
      if (_disposed || generation != _generation) return;
      error = e is DeliveryQuoteException
          ? e.message
          : 'Não foi possível calcular a entrega agora. Tente novamente.';
    } finally {
      if (!_disposed && generation == _generation) {
        loading = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _disposed = true;
    _generation++;
    super.dispose();
  }
}
