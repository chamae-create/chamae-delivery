import 'dart:async';
import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:cloud_functions/cloud_functions.dart';
import '../data/customer_auth.dart';

class DeliveryPinCard extends StatefulWidget {
  const DeliveryPinCard({super.key, this.allowReset = false});
  final bool allowReset;
  @override
  State<DeliveryPinCard> createState() => _DeliveryPinCardState();
}

class _DeliveryPinCardState extends State<DeliveryPinCard>
    with WidgetsBindingObserver {
  String? _pin, _error, _uid;
  bool _busy = false;
  StreamSubscription<User?>? _session;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    if (Firebase.apps.isNotEmpty) {
      _uid = FirebaseAuth.instance.currentUser?.uid;
      _session = FirebaseAuth.instance.idTokenChanges().listen((user) {
        if (user?.uid != _uid && mounted) {
          setState(() {
            _uid = user?.uid;
            _pin = null;
          });
        }
      });
    }
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state != AppLifecycleState.resumed && mounted) {
      setState(() => _pin = null);
    }
  }

  @override
  void dispose() {
    _session?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  Future<void> _load({bool reset = false}) async {
    if (_busy) return;
    if (reset) {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('Redefinir PIN de entrega?'),
                  content: const Text(
                      'Será necessário confirmar sua identidade recentemente e não possuir pedido em andamento.'),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Cancelar')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Redefinir'))
                  ]));
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _pin = null;
    });
    try {
      final uid = FirebaseAuth.instance.currentUser?.uid;
      if (uid == null) throw StateError('Sessão indisponível');
      if (reset) await FirebaseCustomerAuth().confirmIdentity();
      final response =
          await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
              .httpsCallable(
                  reset ? 'chamaeRedefinirPinEntrega' : 'chamaeObterPinEntrega')
              .call()
              .timeout(const Duration(seconds: 15));
      final pin = response.data['pin'];
      if (mounted &&
          FirebaseAuth.instance.currentUser?.uid == uid &&
          pin is String &&
          RegExp(r'^\d{4}$').hasMatch(pin)) {
        setState(() => _pin = pin);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'PIN indisponível. Verifique sua conta e tente novamente. Para redefinir, conclua seus pedidos e confirme sua identidade.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) => Card(
      child: Padding(
          padding: const EdgeInsets.all(16),
          child:
              Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('Seu PIN de entrega',
                style: TextStyle(fontWeight: FontWeight.w800)),
            const Text('Informe este PIN somente ao receber seu pedido.'),
            const Text('Ele não é o código temporário de autenticação.'),
            if (_pin != null)
              Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_pin!,
                      style: const TextStyle(fontSize: 32, letterSpacing: 8))),
            if (_pin == null)
              const Padding(
                  padding: EdgeInsets.symmetric(vertical: 12),
                  child: Text('••••',
                      semanticsLabel: 'PIN oculto',
                      style: TextStyle(fontSize: 32, letterSpacing: 8))),
            if (_error != null) Text(_error!),
            if (_busy) const LinearProgressIndicator(),
            Wrap(spacing: 12, children: [
              TextButton(
                  onPressed: _busy
                      ? null
                      : () {
                          if (_pin != null) {
                            setState(() => _pin = null);
                          } else {
                            _load();
                          }
                        },
                  child: Text(_pin == null ? 'Revelar PIN' : 'Ocultar PIN')),
              if (widget.allowReset)
                TextButton(
                    onPressed: _busy ? null : () => _load(reset: true),
                    child: const Text('Redefinir PIN'))
            ]),
          ])));
}
