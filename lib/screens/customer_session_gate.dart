import 'package:flutter/material.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../core/models.dart';
import '../data/customer_auth.dart';
import '../data/customer_onboarding.dart';
import '../data/customer_workspace.dart';
import 'customer_login_screen.dart';
import 'customer_onboarding_screen.dart';
import 'address_destination_screen.dart';
import 'home_screen.dart';

class CustomerSessionGate extends StatefulWidget {
  final CustomerAuth? auth;
  final CustomerOnboardingRepository Function(String uid)? onboarding;
  final CustomerWorkspace Function(String uid)? workspace;
  final Widget Function(DeliveryAddress? address)? catalog;
  final Widget Function(ValueChanged<DeliveryAddress?> complete)? destination;
  const CustomerSessionGate(
      {super.key,
      this.auth,
      this.onboarding,
      this.workspace,
      this.catalog,
      this.destination});
  @override
  State<CustomerSessionGate> createState() => _CustomerSessionGateState();
}

class _CustomerSessionGateState extends State<CustomerSessionGate>
    with WidgetsBindingObserver {
  late final CustomerAuth _auth = widget.auth ?? FirebaseCustomerAuth();
  late Stream<CustomerIdentity?> _session = _auth.changes;
  CustomerOnboardingRepository? _repository;
  CustomerWorkspace? _workspace;
  String? _sessionKey;
  Future<_Journey>? _future;
  _Journey? _last;
  int _generation = 0;
  String? _developmentPolicy;
  bool _onboardingComplete(CustomerOnboardingState state) =>
      state.acceptedCurrent ||
      (state.policy.allowsDevelopmentOnboarding() &&
          _developmentPolicy == state.policy.developmentSessionKey);

  void _completeOnboarding() {
    final policy = _last?.onboarding.policy;
    if (policy != null && policy.allowsDevelopmentOnboarding()) {
      _developmentPolicy = policy.developmentSessionKey;
    }
    _reload();
  }

  bool _enteredCatalog = false;
  DeliveryAddress? _chosenAddress;
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed &&
        _auth.current?.anonymous == false) {
      _recheck();
    }
  }

  Future<void> _recheck() async {
    final generation = _generation;
    try {
      await _auth.refresh();
      final current = await _repository?.load();
      if (!mounted || generation != _generation || current == null) return;
      if (!_onboardingComplete(current) ||
          _last?.onboarding.policy.contentHash != current.policy.contentHash) {
        _reload();
      }
    } catch (_) {
      if (mounted && generation == _generation) _reload();
    }
  }

  void _reload() {
    setState(() {
      _generation++;
      _last = null;
      _future = _load();
    });
  }

  void _restartSession() => setState(() {
        _generation++;
        _sessionKey = null;
        _developmentPolicy = null;
        _future = null;
        _last = null;
        _session = _auth.changes;
      });

  Future<_Journey> _load() async {
    final generation = _generation;
    await _auth.refresh();
    final onboarding = _repository!, workspace = _workspace!;
    final results =
        await Future.wait<Object>([onboarding.load(), workspace.read()]);
    final journey = _Journey(results[0] as CustomerOnboardingState,
        results[1] as Map<String, dynamic>);
    if (generation == _generation) _last = journey;
    return journey;
  }

  @override
  Widget build(BuildContext context) => StreamBuilder<CustomerIdentity?>(
      stream: _session,
      initialData: _auth.current,
      builder: (context, snapshot) {
        if (snapshot.hasError) return _error();
        if (snapshot.connectionState == ConnectionState.waiting &&
            !snapshot.hasData) {
          return _loading();
        }
        final user = snapshot.data;
        if (user == null || user.anonymous) {
          _developmentPolicy = null;
          _enteredCatalog = false;
          _chosenAddress = null;
          _sessionKey = null;
          _last = null;
          _generation++;
          UserSession.fullName = '';
          UserSession.whatsapp = '';
          return CustomerLoginScreen(auth: _auth);
        }
        if (_sessionKey != user.uid) {
          _developmentPolicy = null;
          _enteredCatalog = false;
          _chosenAddress = null;
          _sessionKey = user.uid;
          _generation++;
          _last = null;
          UserSession.fullName = user.name;
          UserSession.whatsapp = '';
          _repository =
              widget.onboarding?.call(user.uid) ?? FirebaseCustomerOnboarding();
          _workspace =
              widget.workspace?.call(user.uid) ?? FirebaseCustomerWorkspace();
          _future = _load();
        }
        return FutureBuilder<_Journey>(
            future: _future,
            builder: (context, state) {
              if (state.hasError) return _error(state.error);
              if (state.connectionState != ConnectionState.done ||
                  !state.hasData) {
                return _loading();
              }
              final data = state.data!;
              // All authenticated routes live in this navigator. Logout/account
              // changes dispose the complete private route stack, including dialogs.
              return Navigator(
                  key: ValueKey('${user.uid}:$_generation'),
                  onGenerateRoute: (_) => MaterialPageRoute(builder: (_) {
                        if (!_onboardingComplete(data.onboarding)) {
                          return CustomerOnboardingScreen(
                              state: data.onboarding,
                              repository: _repository!,
                              onComplete: _completeOnboarding,
                              onRetry: _reload,
                              onSignOut: () => _auth.signOut());
                        }
                        final address = _chosenAddress ?? data.address;
                        if (address != null || _enteredCatalog) {
                          return widget.catalog?.call(address) ??
                              DeliveryHomeScreen(
                                  initialAddress: address,
                                  workspace: _workspace);
                        }
                        void complete(DeliveryAddress? address) => setState(() {
                              _chosenAddress = address;
                              _enteredCatalog = true;
                              _generation++;
                            });
                        return widget.destination?.call(complete) ??
                            AddressDestinationScreen(
                                workspace: _workspace, onComplete: complete);
                      }));
            });
      });
  Widget _loading() => const Scaffold(
      body: SafeArea(child: Center(child: CircularProgressIndicator())));
  Widget _error([Object? error]) => Scaffold(
      body: SafeArea(
          child: Center(
              child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    Text(
                        error is FirebaseException &&
                                error.code == 'permission-denied'
                            ? 'Sua conta entrou, mas o acesso aos dados foi negado. Tente novamente ou entre em contato com o suporte.'
                            : 'Não foi possível preparar sua conta. Confira a conexão e tente novamente.',
                        textAlign: TextAlign.center),
                    TextButton(
                        onPressed: _restartSession,
                        child: const Text('Tentar novamente')),
                    TextButton(
                        onPressed: () => _auth.signOut(),
                        child: const Text('Sair da conta')),
                  ])))));
}

class _Journey {
  final CustomerOnboardingState onboarding;
  final Map<String, dynamic> workspace;
  _Journey(this.onboarding, this.workspace);
  DeliveryAddress? get address {
    final saved = workspace['lastAddress'] ?? workspace['defaultAddress'];
    if (saved is! Map) return null;
    try {
      final address = DeliveryAddress.fromMap(Map<String, dynamic>.from(saved));
      return address.confirmed &&
              address.hasCoordinates &&
              ['BR', 'PY'].contains(address.countryCode)
          ? address
          : null;
    } catch (_) {
      return null;
    }
  }
}
