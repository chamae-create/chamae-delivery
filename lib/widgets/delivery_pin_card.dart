import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../core/theme.dart';
import '../data/customer_auth.dart';
import 'customer_visual.dart';

class DeliveryPinCard extends StatefulWidget {
  const DeliveryPinCard({
    super.key,
    this.allowReset = false,
    this.compact = false,
    this.pinLoader,
    this.onSupportRequest,
  });

  final bool allowReset;
  final bool compact;
  final Future<Map<String, dynamic>> Function({required bool reset})? pinLoader;
  final VoidCallback? onSupportRequest;

  @override
  State<DeliveryPinCard> createState() => _DeliveryPinCardState();
}

class _DeliveryPinCardState extends State<DeliveryPinCard>
    with WidgetsBindingObserver {
  String? _pin, _error, _uid;
  bool _busy = false;
  bool _canReset = true;
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
            _canReset = true;
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

  Future<Map<String, dynamic>> _callBackend({required bool reset}) async {
    if (widget.pinLoader != null) {
      return widget.pinLoader!(reset: reset);
    }
    final uid = FirebaseAuth.instance.currentUser?.uid;
    if (uid == null) throw StateError('Sessão indisponível');
    if (reset) await FirebaseCustomerAuth().confirmIdentity();
    final response =
        await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
            .httpsCallable(
              reset ? 'chamaeRedefinirPinEntrega' : 'chamaeObterPinEntrega',
            )
            .call<dynamic>()
            .timeout(const Duration(seconds: 15));
    if (response.data is Map) {
      return Map<String, dynamic>.from(response.data as Map);
    }
    return const {};
  }

  Future<void> _load({bool reset = false}) async {
    if (_busy) return;
    if (reset) {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Redefinir PIN de entrega?'),
          content: const Text(
            'A redefinição direta é permitida apenas 1 vez. Confirme sua identidade e conclua pedidos ativos antes de continuar.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cancelar'),
            ),
            TextButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Redefinir'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
    }
    setState(() {
      _busy = true;
      _error = null;
      _pin = null;
    });
    final expectedUid =
        widget.pinLoader == null && Firebase.apps.isNotEmpty
            ? FirebaseAuth.instance.currentUser?.uid
            : null;
    try {
      final data = await _callBackend(reset: reset);
      if (!mounted) return;
      if (expectedUid != null &&
          FirebaseAuth.instance.currentUser?.uid != expectedUid) {
        return;
      }
      final pin = data['pin'];
      final canReset = data['canReset'];
      setState(() {
        if (pin is String && RegExp(r'^\d{4}$').hasMatch(pin)) {
          _pin = pin;
        }
        if (canReset is bool) {
          _canReset = canReset;
        } else if (reset) {
          _canReset = false;
        }
      });
    } on FirebaseFunctionsException catch (e) {
      final reason = e.details is Map ? e.details['reason']?.toString() : null;
      if (!mounted) return;
      if (reason == 'PIN_RESET_LIMIT_REACHED') {
        setState(() {
          _canReset = false;
          _error =
              'Você já utilizou sua redefinição direta. Abra um chamado com o suporte para alterar o PIN novamente.';
        });
      } else {
        setState(() {
          _error =
              'PIN indisponível. Verifique sua conta e conclua pedidos em andamento antes de redefinir.';
        });
      }
    } catch (_) {
      if (mounted) {
        setState(
          () => _error =
              'PIN indisponível. Verifique sua conta e tente novamente.',
        );
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _openSupportTicket() {
    if (widget.onSupportRequest != null) {
      widget.onSupportRequest!();
      return;
    }
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Suporte para PIN de entrega'),
        content: const Text(
          'Sua redefinição direta única já foi utilizada. Solicite uma nova alteração ao atendimento oficial Chamaê informando seu e-mail cadastrado e documento.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Entendi'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pinValue = _pin ?? '••••';
    return Container(
      decoration: CustomerVisual.panel(),
      padding: EdgeInsets.all(widget.compact ? 12 : 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(7),
                decoration: BoxDecoration(
                  gradient: CustomerVisual.gold,
                  borderRadius: BorderRadius.circular(10),
                ),
                child: const Icon(
                  Icons.pin_outlined,
                  size: 18,
                  color: AppTheme.obsidianDark,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      'PIN de entrega',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                        fontWeight: FontWeight.w800,
                        fontSize: 14,
                        color: AppTheme.textDark,
                      ),
                    ),
                    Text(
                      widget.compact
                          ? 'Informe somente ao receber o pedido.'
                          : 'Informe este código fixo somente na entrega.',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        fontSize: 11.5,
                        color: AppColors.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: AppColors.surfaceWhite,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: AppColors.borderLight, width: 1),
                ),
                child: Semantics(
                  label: _pin == null ? 'PIN oculto' : 'PIN $_pin',
                  child: Text(
                    pinValue,
                    style: const TextStyle(
                      fontSize: 20,
                      letterSpacing: 4,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textDark,
                    ),
                  ),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
            Text(
              _error!,
              style: const TextStyle(
                color: AppColors.error,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
          if (_busy) ...[
            const SizedBox(height: 8),
            const LinearProgressIndicator(color: AppTheme.primaryYellow),
          ],
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  backgroundColor: Colors.white,
                  foregroundColor: AppTheme.textDark,
                  side: const BorderSide(color: AppColors.borderLight, width: 1),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                  minimumSize: const Size(48, 40),
                ),
                onPressed: _busy
                    ? null
                    : () {
                        if (_pin != null) {
                          setState(() => _pin = null);
                        } else {
                          _load();
                        }
                      },
                icon: Icon(
                  _pin == null
                      ? Icons.visibility_outlined
                      : Icons.visibility_off_outlined,
                  size: 16,
                  color: AppColors.darkGold,
                ),
                label: Text(
                  _pin == null ? 'Revelar PIN' : 'Ocultar PIN',
                  style: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              if (widget.allowReset && _canReset)
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryYellow,
                    foregroundColor: AppTheme.obsidianDark,
                    elevation: 0,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(48, 40),
                  ),
                  onPressed: _busy ? null : () => _load(reset: true),
                  icon: const Icon(Icons.lock_reset_rounded, size: 16),
                  label: const Text(
                    'Redefinir PIN',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
              if (widget.allowReset && !_canReset)
                OutlinedButton.icon(
                  style: OutlinedButton.styleFrom(
                    backgroundColor: const Color(0xFFFFF8E1),
                    foregroundColor: AppTheme.textDark,
                    side: const BorderSide(
                      color: AppColors.borderLight,
                      width: 1,
                    ),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    minimumSize: const Size(48, 40),
                  ),
                  onPressed: _busy ? null : _openSupportTicket,
                  icon: const Icon(
                    Icons.support_agent_outlined,
                    size: 16,
                    color: AppColors.darkGold,
                  ),
                  label: const Text(
                    'Abrir chamado com o suporte',
                    style: TextStyle(
                      fontSize: 12.5,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
