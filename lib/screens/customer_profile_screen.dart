import '../widgets/customer_order_history_card.dart';
import '../widgets/customer_visual.dart';
import '../widgets/delivery_pin_card.dart';
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import '../core/models.dart';
import '../core/theme.dart';
import 'tracking_screen.dart';
import '../data/customer_auth.dart';
import '../data/customer_onboarding.dart';
import 'legal_document_screen.dart';
import 'customer_onboarding_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  final DeliveryAddress? address;
  final Future<void> Function() selectAddress;
  final CustomerAuth? auth;
  final CustomerOnboardingRepository? onboarding;
  const CustomerProfileScreen(
      {super.key,
      this.address,
      required this.selectAddress,
      this.auth,
      this.onboarding});
  @override
  State<CustomerProfileScreen> createState() => _CustomerProfileScreenState();
}

class _CustomerProfileScreenState extends State<CustomerProfileScreen> {
  late final CustomerAuth? _auth =
      widget.auth ?? (Firebase.apps.isNotEmpty ? FirebaseCustomerAuth() : null);
  late final CustomerOnboardingRepository? _repository = widget.onboarding ??
      (Firebase.apps.isNotEmpty ? FirebaseCustomerOnboarding() : null);
  late Future<CustomerOnboardingState>? _state = _repository?.load();
  bool _busy = false;
  String? _error;
  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
                title: const Text('Sair da conta?'),
                content: const Text(
                    'Seus pedidos e seu carrinho continuarão vinculados a esta conta.'),
                actions: [
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, false),
                      child: const Text('Voltar')),
                  TextButton(
                      onPressed: () => Navigator.pop(ctx, true),
                      child: const Text('Sair')),
                ]));
    if (confirmed != true || !mounted) return;
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth?.signOut();
    } catch (_) {
      if (mounted) {
        setState(
            () => _error = 'Não foi possível sair agora. Tente novamente.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _link(CustomerProvider provider) async {
    setState(() {
      _busy = true;
      _error = null;
    });
    try {
      await _auth?.signIn(provider);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Não foi possível vincular essa identidade. Use uma conta que ainda não esteja vinculada a outro perfil.');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  void _legal(CustomerPolicy policy, bool privacy) => Navigator.push(
      context,
      MaterialPageRoute(
          builder: (_) => LegalDocumentScreen(
              title: privacy ? 'Política de Privacidade' : 'Termos de Uso',
              version: privacy ? policy.privacyVersion : policy.termsVersion,
              text: privacy ? policy.privacyText : policy.termsText,
              sourceUrl: privacy ? policy.privacyUrl : policy.termsUrl,
              draft: policy.draft)));

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Seu perfil')),
        body: SafeArea(
            child: FutureBuilder<CustomerOnboardingState>(
                future: _state,
                builder: (context, snapshot) {
                  final identity = _auth?.current;
                  final policy =
                      snapshot.data?.policy ?? developmentCustomerPolicy;
                  final dob = snapshot.data?.profile['birthDate'];
                  return SingleChildScrollView(
                      padding: CustomerVisual.pagePadding(context),
                      child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            CustomerHero(
                                title: UserSession.fullName.isEmpty
                                    ? 'Bem-vindo ao Chamaê'
                                    : UserSession.fullName,
                                subtitle: 'Seu perfil Chamaê',
                                icon: Icons.person_outline_rounded,
                                trailing: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      if (UserSession.whatsapp.isNotEmpty)
                                        Text(UserSession.whatsapp,
                                            style: const TextStyle(
                                                color: Colors.white)),
                                      if (identity?.email.isNotEmpty == true)
                                        Text(identity!.email,
                                            style: const TextStyle(
                                                color: Colors.white)),
                                    ])),
                            const CustomerSectionTitle(
                                title: 'Minha conta',
                                icon: Icons.person_outline_rounded),
                            ListTile(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: const BorderSide(
                                        color: AppColors.borderLight)),
                                tileColor: AppColors.surfaceWhite,
                                iconColor: AppColors.darkGold,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                leading: const Icon(Icons.login),
                                title: const Text('Método de login'),
                                subtitle: Text(identity?.providers
                                        .map((p) => p == 'google.com'
                                            ? 'Google'
                                            : p == 'apple.com'
                                                ? 'Apple'
                                                : 'Conta vinculada')
                                        .join(' • ') ??
                                    'Conta Chamaê')),
                            if (dob is String)
                              ListTile(
                                  shape: RoundedRectangleBorder(
                                      borderRadius: BorderRadius.circular(20),
                                      side: const BorderSide(
                                          color: AppColors.borderLight)),
                                  tileColor: AppColors.surfaceWhite,
                                  iconColor: AppColors.darkGold,
                                  contentPadding: const EdgeInsets.symmetric(
                                      horizontal: 16, vertical: 10),
                                  leading: const Icon(Icons.cake_outlined),
                                  title: const Text('Data de nascimento'),
                                  subtitle: Text(
                                      'Data declarada: ${dob.split('-').reversed.join('/')}')),
                            if (snapshot.hasError)
                              TextButton(
                                  onPressed: () => setState(
                                      () => _state = _repository?.load()),
                                  child: const Text(
                                      'Tentar carregar dados novamente')),
                            if (snapshot.data != null &&
                                !snapshot.data!.acceptedCurrent &&
                                _repository != null)
                              TextButton(
                                  onPressed: () => Navigator.push(
                                      context,
                                      MaterialPageRoute(
                                          builder: (_) =>
                                              CustomerOnboardingScreen(
                                                  state: snapshot.data!,
                                                  repository: _repository!,
                                                  onComplete: () {
                                                    Navigator.pop(context);
                                                    setState(() => _state =
                                                        _repository!.load());
                                                  }))),
                                  child: const Text(
                                      'Conferir documentos atualizados')),
                            const SizedBox(height: 24),
                            ListTile(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: const BorderSide(
                                        color: AppColors.borderLight)),
                                tileColor: AppColors.surfaceWhite,
                                iconColor: AppColors.darkGold,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                leading: const Icon(Icons.location_on_outlined),
                                title: const Text('Endereço de entrega'),
                                subtitle: Text(widget.address?.addressText ??
                                    'Selecione o endereço na tela inicial'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () async {
                                  await widget.selectAddress();
                                  if (context.mounted) Navigator.pop(context);
                                }),
                            ListTile(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: const BorderSide(
                                        color: AppColors.borderLight)),
                                tileColor: AppColors.surfaceWhite,
                                iconColor: AppColors.darkGold,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                leading:
                                    const Icon(Icons.receipt_long_outlined),
                                title: const Text('Meus pedidos'),
                                trailing: const Icon(Icons.chevron_right),
                                onTap: () => Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                        builder: (_) =>
                                            const CustomerHistoryScreen()))),
                            const DeliveryPinCard(allowReset: true),
                            ListTile(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: const BorderSide(
                                        color: AppColors.borderLight)),
                                tileColor: AppColors.surfaceWhite,
                                iconColor: AppColors.darkGold,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                leading: const Icon(Icons.description_outlined),
                                title: const Text('Termos de Uso'),
                                onTap: () => _legal(policy, false)),
                            ListTile(
                                shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(20),
                                    side: const BorderSide(
                                        color: AppColors.borderLight)),
                                tileColor: AppColors.surfaceWhite,
                                iconColor: AppColors.darkGold,
                                contentPadding: const EdgeInsets.symmetric(
                                    horizontal: 16, vertical: 10),
                                leading: const Icon(Icons.privacy_tip_outlined),
                                title: const Text('Política de Privacidade'),
                                onTap: () => _legal(policy, true)),
                            if (identity != null) ...[
                              if (!identity.providers.contains('google.com'))
                                TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _link(CustomerProvider.google),
                                    child:
                                        const Text('Vincular Google à conta')),
                              if (!identity.providers.contains('apple.com'))
                                TextButton(
                                    onPressed: _busy
                                        ? null
                                        : () => _link(CustomerProvider.apple),
                                    child:
                                        const Text('Vincular Apple à conta')),
                            ],
                            if (_error != null)
                              Text(_error!,
                                  style:
                                      const TextStyle(color: AppColors.error)),
                            if (_busy) const LinearProgressIndicator(),
                            TextButton.icon(
                                onPressed:
                                    _busy || _auth == null ? null : _logout,
                                icon: const Icon(Icons.logout),
                                label: const Text('Sair da conta')),
                            const Divider(),
                            const Padding(
                                padding: EdgeInsets.all(16),
                                child: Text(
                                  'Usamos seu nome, WhatsApp e endereço para preparar e entregar seus pedidos. '
                                  'A localização é usada quando você solicita encontrar seu endereço. '
                                  'O histórico fica vinculado à sua conta.',
                                )),
                          ]));
                })),
      );
}

class CustomerHistoryScreen extends StatefulWidget {
  const CustomerHistoryScreen({super.key});
  @override
  State<CustomerHistoryScreen> createState() => _CustomerHistoryScreenState();
}

class _CustomerHistoryScreenState extends State<CustomerHistoryScreen> {
  late final Stream<User?> _session = FirebaseAuth.instance.idTokenChanges();
  Stream<QuerySnapshot<Map<String, dynamic>>>? _orders;
  String? _uid;
  int _limit = 50;
  void _retry() => setState(() {
        _uid = null;
        _orders = null;
      });
  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(title: const Text('Meus pedidos')),
        body: StreamBuilder<User?>(
            stream: _session,
            builder: (context, session) {
              final uid = session.data?.uid;
              if (session.hasError) return _error();
              if (session.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (uid == null ||
                  uid != FirebaseAuth.instance.currentUser?.uid) {
                _uid = null;
                _orders = null;
                return const Center(
                    child: Text('Conecte-se para ver seus pedidos.'));
              }
              if (_uid != uid) {
                _uid = uid;
                _orders = FirebaseFirestore.instance
                    .collection('orders')
                    .where('customerUid', isEqualTo: uid)
                    .limit(_limit)
                    .snapshots();
              }
              return StreamBuilder<QuerySnapshot<Map<String, dynamic>>>(
                  key: ValueKey('$uid:$_limit'),
                  stream: _orders,
                  builder: (context, snapshot) {
                    if (snapshot.hasError) return _error();
                    if (!snapshot.hasData) {
                      return const Center(child: CircularProgressIndicator());
                    }
                    if (FirebaseAuth.instance.currentUser?.uid != uid) {
                      return const SizedBox.shrink();
                    }
                    final docs = snapshot.data!.docs
                        .where((d) => d.data()['customerUid'] == uid)
                        .toList()
                      ..sort(
                          (a, b) => _date(b.data()).compareTo(_date(a.data())));
                    if (docs.isEmpty) {
                      return const Center(
                          child: Text('Seus pedidos aparecerão aqui.'));
                    }
                    return ListView.separated(
                        padding: const EdgeInsets.all(AppSpace.md),
                        itemCount: docs.length +
                            (snapshot.data!.docs.length >= _limit ? 1 : 0),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                        itemBuilder: (context, index) {
                          if (index == docs.length) {
                            return TextButton(
                                onPressed: () => setState(() {
                                      _limit += 50;
                                      _uid = null;
                                    }),
                                child: const Text('Carregar mais pedidos'));
                          }
                          final doc = docs[index], data = doc.data();
                          final id = (data['id'] ?? 'Pedido').toString();
                          final date = _date(data).toLocal();
                          final total = (data['totalBRL'] as num? ?? 0)
                              .toStringAsFixed(2);
                          return CustomerOrderHistoryCard(
                            id: id,
                            total: total,
                            date: date,
                            status: customerStatus(data['status']?.toString()),
                            onTap: () => Navigator.push(
                                context,
                                MaterialPageRoute(
                                    builder: (_) => TrackingScreen(
                                        orderId: id, documentId: doc.id))),
                          );
                        });
                  });
            }),
      );
  DateTime _date(Map<String, dynamic> data) => data['createdAt'] is Timestamp
      ? (data['createdAt'] as Timestamp).toDate()
      : DateTime.fromMillisecondsSinceEpoch(0);
  Widget _error() => Center(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Text('Não foi possível carregar os pedidos.'),
        TextButton(onPressed: _retry, child: const Text('Tentar novamente')),
      ]));
}

String customerStatus(String? status) => switch (status) {
      'Novo' => 'Pedido recebido',
      'Em Separação' => 'Em separação',
      'Aguardando Retirada' => 'Aguardando retirada',
      'Saiu para Entrega' => 'Saiu para entrega',
      'Concluído' => 'Entregue',
      'Cancelado' => 'Pedido cancelado',
      'Aguardando pagamento' => 'Aguardando pagamento',
      _ => 'Atualizando pedido',
    };
