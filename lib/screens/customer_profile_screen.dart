import '../widgets/commerce_components.dart';
import '../data/binational_identity.dart';
import 'customer_identification_screen.dart';
import '../l10n/customer_localizations.dart';
import '../core/operational_order_id.dart';
import '../widgets/customer_order_history_card.dart';
import '../widgets/customer_visual.dart';
import '../widgets/customer_feedback.dart';
import '../widgets/delivery_pin_card.dart';

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';

import '../core/models.dart';
import '../core/theme.dart';
import 'tracking_screen.dart';
import '../data/customer_auth.dart';
import '../data/customer_account.dart';
import 'customer_account_closure_screen.dart';
import '../data/customer_onboarding.dart';
import 'legal_document_screen.dart';
import 'customer_onboarding_screen.dart';

class CustomerProfileScreen extends StatefulWidget {
  final DeliveryAddress? address;
  final Future<void> Function() selectAddress;
  final CustomerAuth? auth;
  final CustomerOnboardingRepository? onboarding;
  final CustomerAccountRepository? account;
  const CustomerProfileScreen({
    super.key,
    this.address,
    required this.selectAddress,
    this.auth,
    this.onboarding,
    this.account,
  });
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
  void _reloadProfile() {
    final state = _repository?.load();
    setState(() {
      _state = state;
    });
  }

  Future<void> _logout() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        scrollable: true,
        title: const LocalizedText('Sair da conta?'),
        content: const LocalizedText(
          'Seus pedidos e seu carrinho continuarão vinculados a esta conta.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const LocalizedText('Voltar'),
          ),
          TextButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const LocalizedText('Sair'),
          ),
        ],
      ),
    );
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
          () => _error = 'Não foi possível sair agora. Tente novamente.',
        );
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
        setState(
          () => _error =
              'Não foi possível vincular essa identidade. Use uma conta que ainda não esteja vinculada a outro perfil.',
        );
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
            draft: policy.draft,
          ),
        ),
      );

  Future<void> _identify(CustomerOnboardingState state) async {
    await Navigator.push<void>(
      context,
      MaterialPageRoute(
        builder: (_) => CustomerIdentificationScreen(
          profile: state.profile,
          repository: FirebaseIdentificationRepository(),
          onComplete: () => Navigator.pop(context),
        ),
      ),
    );
    if (mounted) _reloadProfile();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        bottomNavigationBar: CommerceRouteNavigation.bar(context, 3),
        appBar: CommerceAppBar(
          title: 'Seu perfil',
          address: widget.address?.addressText,
          actions: const [LanguagePicker(compact: true)],
        ),
        body: SafeArea(
          child: FutureBuilder<CustomerOnboardingState>(
            future: _state,
            builder: (context, snapshot) {
              final identity = _auth?.current;
              final policy = snapshot.data?.policy ?? developmentCustomerPolicy;
              final profile = snapshot.data?.profile ?? <String, dynamic>{};
              final fullName = profile['fullName'] is String
                  ? profile['fullName'] as String
                  : UserSession.fullName;
              final actions = <Widget>[
                ProfileActionTile(
                  title: 'Meus pedidos',
                  subtitle: 'Histórico da sua conta',
                  icon: Icons.inventory_2_outlined,
                  onTap: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const CustomerHistoryScreen(),
                    ),
                  ),
                ),
                ProfileActionTile(
                  title: 'Endereço de entrega',
                  subtitle: 'Escolha seu endereço',
                  icon: Icons.location_on_outlined,
                  onTap: () async {
                    await widget.selectAddress();
                    if (context.mounted && Navigator.canPop(context)) {
                      Navigator.pop(context);
                    }
                  },
                ),
                ProfileActionTile(
                  title: context.l10n.identification,
                  icon: Icons.badge_outlined,
                  onTap: snapshot.data != null && _auth is FirebaseCustomerAuth
                      ? () => _identify(snapshot.data!)
                      : null,
                ),
                ProfileActionTile(
                  title: 'Termos de Uso',
                  icon: Icons.description_outlined,
                  onTap: () => _legal(policy, false),
                ),
                ProfileActionTile(
                  title: 'Política de Privacidade',
                  icon: Icons.privacy_tip_outlined,
                  onTap: () => _legal(policy, true),
                ),
                ProfileActionTile(
                  title: Localizations.localeOf(context).languageCode == 'es'
                      ? 'Idioma'
                      : 'Idioma',
                  icon: Icons.language,
                  onTap: () => showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => const SafeArea(
                      child: Padding(
                        padding: EdgeInsets.all(24),
                        child: LanguagePicker(),
                      ),
                    ),
                  ),
                ),
              ];
              return SingleChildScrollView(
                padding: CustomerVisual.pagePadding(context),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    CommerceProfileBanner(
                      name: fullName,
                      phone: UserSession.whatsapp,
                      email: identity?.email,
                    ),
                    const SizedBox(height: 12),
                    LayoutBuilder(
                      builder: (context, constraints) {
                        final columns = constraints.maxWidth < 420 ||
                                MediaQuery.textScalerOf(context).scale(1) > 1.2
                            ? 1
                            : 2;
                        final width =
                            (constraints.maxWidth - (columns - 1) * 10) /
                                columns;
                        return Wrap(
                          spacing: 10,
                          runSpacing: 10,
                          children: [
                            for (final action in actions)
                              SizedBox(
                                width: width,
                                child: ConstrainedBox(
                                  constraints:
                                      const BoxConstraints(minHeight: 72),
                                  child: action,
                                ),
                              ),
                          ],
                        );
                      },
                    ),
                    if (snapshot.connectionState == ConnectionState.waiting)
                      const CustomerFeedback(
                        title: 'Buscando os dados da sua conta',
                        message: 'Seu perfil já vai aparecer por aqui.',
                        loading: true,
                      ),
                    if (snapshot.hasError)
                      CustomerFeedback(
                        title: 'Não foi possível atualizar seu perfil.',
                        message:
                            'Confira sua conexão e tente novamente. Seus dados não foram apagados.',
                        icon: Icons.cloud_off_outlined,
                        onRetry: _reloadProfile,
                      ),
                    if (snapshot.data != null &&
                        !snapshot.data!.acceptedCurrent &&
                        _repository != null)
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => CustomerOnboardingScreen(
                              state: snapshot.data!,
                              repository: _repository!,
                              onComplete: () {
                                Navigator.pop(context);
                                _reloadProfile();
                              },
                            ),
                          ),
                        ),
                        child: const LocalizedText(
                          'Conferir documentos atualizados',
                        ),
                      ),
                    const CustomerSectionTitle(
                      title: 'Últimos pedidos',
                      icon: Icons.history,
                    ),
                    Card(
                      child: ListTile(
                        leading: const Icon(
                          Icons.receipt_long_outlined,
                          color: AppColors.darkGold,
                        ),
                        title: const LocalizedText('Histórico da sua conta'),
                        subtitle: const LocalizedText(
                          'Consulte seus pedidos e acompanhe os detalhes.',
                        ),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => const CustomerHistoryScreen(),
                          ),
                        ),
                      ),
                    ),
                    const CustomerSectionTitle(
                      title: 'Minha conta',
                      icon: Icons.person_outline_rounded,
                    ),
                    ListTile(
                      leading: const Icon(Icons.login),
                      title: const LocalizedText('Método de login'),
                      subtitle: Text(
                        identity?.providers
                                .map(
                                  (p) => p == 'google.com'
                                      ? 'Google'
                                      : p == 'apple.com'
                                          ? 'Apple'
                                          : 'Conta vinculada',
                                )
                                .join(' • ') ??
                            'Conta Chamaê',
                      ),
                    ),
                    if (profile['birthDate'] is String)
                      ListTile(
                        leading: const Icon(Icons.cake_outlined),
                        title: const LocalizedText('Data de nascimento'),
                        subtitle: Text(
                          'Data declarada: ${(profile['birthDate'] as String)
                                  .split('-')
                                  .reversed
                                  .join('/')}',
                        ),
                      ),
                    const DeliveryPinCard(allowReset: true),
                    if (identity != null) ...[
                      if (!identity.providers.contains('google.com'))
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _link(CustomerProvider.google),
                          child: const LocalizedText('Vincular Google à conta'),
                        ),
                      if (!identity.providers.contains('apple.com'))
                        TextButton(
                          onPressed: _busy
                              ? null
                              : () => _link(CustomerProvider.apple),
                          child: const LocalizedText('Vincular Apple à conta'),
                        ),
                    ],
                    if (_error != null)
                      LocalizedText(
                        _error!,
                        style: const TextStyle(color: AppColors.error),
                      ),
                    if (_busy) const LinearProgressIndicator(),
                    TextButton.icon(
                      onPressed: _busy || _auth == null ? null : _logout,
                      icon: const Icon(Icons.logout),
                      label: const LocalizedText('Sair da conta'),
                    ),
                    if (widget.account != null ||
                        identity != null &&
                            !identity.anonymous &&
                            _auth is FirebaseCustomerAuth)
                      TextButton.icon(
                        onPressed: _busy
                            ? null
                            : () => Navigator.push(
                                  context,
                                  MaterialPageRoute(
                                    builder: (_) =>
                                        CustomerAccountClosureScreen(
                                      repository: widget.account ??
                                          FirebaseCustomerAccount(
                                            _auth as FirebaseCustomerAuth,
                                          ),
                                    ),
                                  ),
                                ),
                        icon: const Icon(
                          Icons.delete_outline,
                          color: AppColors.error,
                        ),
                        label: const LocalizedText(
                          'Excluir minha conta',
                          style: TextStyle(color: AppColors.error),
                        ),
                      ),
                    const Divider(),
                    const Padding(
                      padding: EdgeInsets.all(16),
                      child: LocalizedText(
                        'Usamos seu nome, WhatsApp e endereço para preparar e entregar seus pedidos. '
                        'A localização é usada quando você solicita encontrar seu endereço. '
                        'O histórico fica vinculado à sua conta.',
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        ),
      );
}

class ProfileActionTile extends StatelessWidget {
  const ProfileActionTile({
    super.key,
    required this.title,
    required this.icon,
    this.onTap,
    this.subtitle,
  });
  final String title;
  final String? subtitle;
  final IconData icon;
  final VoidCallback? onTap;
  @override
  Widget build(BuildContext context) => Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(16),
          child: Ink(
            decoration: CustomerVisual.panel(),
            padding: const EdgeInsets.all(10),
            child: Row(
              children: [
                Container(
                  width: 38,
                  height: 44,
                  decoration: BoxDecoration(
                    gradient: CustomerVisual.gold,
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Icon(icon, color: AppTheme.darkBg, size: 27),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      LocalizedText(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w800,
                          fontSize: 14,
                          height: 1.25,
                        ),
                      ),
                      if (subtitle != null)
                        Padding(
                          padding: const EdgeInsets.only(top: 4),
                          child: LocalizedText(
                            subtitle!,
                            style: const TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 12,
                              height: 1.1,
                            ),
                          ),
                        ),
                    ],
                  ),
                ),
                if (onTap != null) const Icon(Icons.chevron_right, size: 17),
              ],
            ),
          ),
        ),
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
        appBar: AppBar(title: const LocalizedText('Meus pedidos')),
        body: StreamBuilder<User?>(
          stream: _session,
          builder: (context, session) {
            final uid = session.data?.uid;
            if (session.hasError) return _error();
            if (session.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (uid == null || uid != FirebaseAuth.instance.currentUser?.uid) {
              _uid = null;
              _orders = null;
              return const Center(
                child: LocalizedText('Conecte-se para ver seus pedidos.'),
              );
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
                  ..sort((a, b) => _date(b.data()).compareTo(_date(a.data())));
                if (docs.isEmpty) {
                  return const Center(
                    child: LocalizedText('Seus pedidos aparecerão aqui.'),
                  );
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
                        child: const LocalizedText('Carregar mais pedidos'),
                      );
                    }
                    final doc = docs[index], data = doc.data();
                    final id = customerOrderLabel(data);
                    final date = _date(data).toLocal();
                    final total =
                        (data['totalBRL'] as num? ?? 0).toStringAsFixed(
                      2,
                    );
                    return CustomerOrderHistoryCard(
                      id: id,
                      total: total,
                      date: date,
                      status: customerStatus(data['status']?.toString()),
                      onTap: () => Navigator.push(
                        context,
                        MaterialPageRoute(
                          builder: (_) =>
                              TrackingScreen(orderId: id, documentId: doc.id),
                        ),
                      ),
                    );
                  },
                );
              },
            );
          },
        ),
      );
  DateTime _date(Map<String, dynamic> data) => data['createdAt'] is Timestamp
      ? (data['createdAt'] as Timestamp).toDate()
      : DateTime.fromMillisecondsSinceEpoch(0);
  Widget _error() => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const LocalizedText('Não foi possível carregar os pedidos.'),
            TextButton(
              onPressed: _retry,
              child: const LocalizedText('Tentar novamente'),
            ),
          ],
        ),
      );
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
