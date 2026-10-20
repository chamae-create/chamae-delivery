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
    final data = result.data;
    final fee = data['deliveryFee'];
    if (fee is! num || !fee.isFinite || fee < 0) {
      throw StateError('Entrega indisponível. Tente novamente.');
    }
    final mode = data['mode'];
    if (mode != 'legacy' && mode != 'routeBands') {
      throw StateError('Configuração de entrega indisponível.');
    }
    if (mode == 'routeBands' &&
        (data['quoteId'] is! String ||
            data['version'] is! String ||
            data['distanceMeters'] is! num)) {
      throw StateError('Cotação de entrega incompleta.');
    }
    return DeliveryQuote(fee.toDouble(), data['quoteId'] as String?, mode,
        distanceMeters: (data['distanceMeters'] as num?)?.toDouble(),
        version: data['version'] as String?,
        routingProvider: data['routingProvider'] as String?,
        quotedAtMs: (data['quotedAtMs'] as num?)?.toInt(),
        expiresAtMs: (data['expiresAtMs'] as num?)?.toInt());
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
