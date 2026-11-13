import 'dart:async';
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

  bool isFresh({int? nowMs}) =>
      mode == 'routeBands' &&
      id != null &&
      RegExp(r'^[a-f0-9]{64}$').hasMatch(id!) &&
      version?.isNotEmpty == true &&
      routingProvider?.isNotEmpty == true &&
      fee.isFinite &&
      fee >= 0 &&
      distanceMeters != null &&
      distanceMeters!.isFinite &&
      distanceMeters! >= 0 &&
      distanceMeters! <= 30000 &&
      quotedAtMs != null &&
      expiresAtMs != null &&
      expiresAtMs! > quotedAtMs! &&
      expiresAtMs! > (nowMs ?? DateTime.now().millisecondsSinceEpoch);

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

// Widget-lifetime reuse only; never a financial authority or offline quote.
class DeliveryQuoteCache {
  DeliveryQuote? _value;
  DeliveryAddress? _destination;
  DeliveryQuote? forDestination(DeliveryAddress address, {int? nowMs}) {
    final previous = _destination;
    if (previous == null ||
        !address.confirmed ||
        !address.hasCoordinates ||
        !['BR', 'PY'].contains(address.countryCode) ||
        previous.latitude != address.latitude ||
        previous.longitude != address.longitude ||
        previous.countryCode != address.countryCode ||
        _value?.isFresh(nowMs: nowMs) != true) {
      return null;
    }
    return _value;
  }

  void remember(DeliveryAddress address, DeliveryQuote quote) {
    _destination = address;
    _value = quote;
  }

  void clear() {
    _value = null;
    _destination = null;
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
      }).timeout(const Duration(seconds: 40));
    } on FirebaseFunctionsException catch (error) {
      final details = error.details;
      if (details is Map && details['reason'] == 'OUT_OF_RANGE') {
        throw const DeliveryQuoteException(
            'Este endereço está fora da área de entrega disponível no momento.');
      }
      throw DeliveryQuoteException(deliveryQuoteErrorMessage(error));
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
  Timer? _expiry;

  void clear() {
    if (_disposed) return;
    _generation++;
    _expiry?.cancel();
    destination = null;
    value = null;
    error = null;
    loading = false;
    notifyListeners();
  }

  Future<void> refresh(DeliveryAddress address) async {
    if (_disposed) return;
    final generation = ++_generation;
    _expiry?.cancel();
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
      if (!result.isFresh()) {
        throw const DeliveryQuoteException(
            'Cotacao expirada. Calcule a entrega novamente.');
      }
      value = result;
      _expiry = Timer(
          Duration(
              milliseconds: result.expiresAtMs! -
                  DateTime.now().millisecondsSinceEpoch), () {
        if (generation != _generation) return;
        value = null;
        error = 'Cotacao expirada. Calcule a entrega novamente.';
        notifyListeners();
      });
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
    _expiry?.cancel();
    _generation++;
    super.dispose();
  }
}

// Public error categories only; never surface provider messages or request data.
String deliveryQuoteErrorMessage(FirebaseFunctionsException error) =>
    switch (error.code) {
      'permission-denied' =>
        'Esta conta não está autorizada a calcular a entrega. Contate o suporte.',
      'unauthenticated' =>
        'Entre novamente na sua conta para calcular a entrega.',
      'resource-exhausted' =>
        'Limite de cotações atingido. Aguarde antes de tentar novamente.',
      'failed-precondition' =>
        'A entrega está indisponível no momento. Tente novamente ou contate o suporte.',
      _ =>
        'Não foi possível calcular a entrega agora. Confira sua conexão e tente novamente.',
    };
