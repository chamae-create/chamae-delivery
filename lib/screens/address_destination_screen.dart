import 'package:flutter/material.dart';
import '../core/models.dart';
import '../data/customer_workspace.dart';
import 'address_map_screen.dart';
import 'home_screen.dart';

class AddressDestinationScreen extends StatefulWidget {
  final bool onboarding;
  final CustomerWorkspace? workspace;
  final ValueChanged<DeliveryAddress?>? onComplete;
  final Future<AddressMapResult?> Function(bool gps, String query)? mapPicker;
  const AddressDestinationScreen(
      {super.key,
      this.onboarding = true,
      this.workspace,
      this.mapPicker,
      this.onComplete});
  @override
  State<AddressDestinationScreen> createState() =>
      _AddressDestinationScreenState();
}

class _AddressDestinationScreenState extends State<AddressDestinationScreen> {
  late final CustomerWorkspace _workspace =
      widget.workspace ?? FirebaseCustomerWorkspace();
  Map<String, dynamic> _data = {};
  bool _loading = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await _workspace.read();
      if (mounted) setState(() => _data = data);
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Não foi possível carregar seus endereços. Você pode escolher outro destino.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _finish(DeliveryAddress? address) {
    if (widget.onComplete != null) {
      widget.onComplete!(address);
      return;
    }
    if (widget.onboarding) {
      Navigator.pushReplacement(
          context,
          MaterialPageRoute<void>(
              builder: (_) => DeliveryHomeScreen(initialAddress: address)));
    } else {
      Navigator.pop(context, address);
    }
  }

  Future<void> _choose(
      {bool gps = false, DeliveryAddress? saved, bool edit = false}) async {
    var draft = saved;
    if (draft == null || edit) {
      AddressInput? input;
      if (!gps && !edit) {
        input = await Navigator.push<AddressInput>(context,
            MaterialPageRoute(builder: (_) => const ManualAddressScreen()));
        if (!mounted || input == null) return;
      }
      final result = widget.mapPicker != null
          ? await widget.mapPicker!(gps, input?.query ?? '')
          : await Navigator.push<AddressMapResult>(
              context,
              MaterialPageRoute(
                  builder: (_) => AddressMapScreen(
                      useCurrentLocation: gps,
                      initialLatitude: saved?.latitude,
                      initialLongitude: saved?.longitude,
                      initialQuery: input?.query ?? '')));
      if (!mounted || result == null) return;
      draft = DeliveryAddress(
          latitude: result.latitude,
          longitude: result.longitude,
          addressText: result.addressText,
          countryCode: result.countryCode,
          complement: result.complement.isEmpty
              ? saved?.complement ?? ''
              : result.complement,
          reference: result.reference.isEmpty
              ? saved?.reference ?? ''
              : result.reference,
          street: input?.street ?? result.street,
          number: input?.number ?? result.number,
          district: input?.district ?? result.district,
          city: input?.city ?? result.city,
          noNumber: input?.noNumber ?? saved?.noNumber ?? false,
          label: saved?.label ?? 'Outro',
          createdAtMs: saved?.createdAtMs);
    }
    final resultAddress = await Navigator.push<DeliveryAddress>(
        context,
        MaterialPageRoute(
            builder: (_) => AddressReviewScreen(
                address: draft!, initialLabel: edit ? saved?.label : null)));
    if (!mounted || resultAddress == null) return;
    final now = DateTime.now().millisecondsSinceEpoch;
    final reviewed = resultAddress.copyWith(
        createdAtMs: saved?.createdAtMs ?? now, updatedAtMs: now);
    final addresses = (_data['addresses'] as List? ?? [])
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList();
    if (reviewed.label != 'Não salvar') {
      addresses.removeWhere((e) =>
          e['label'] == reviewed.label || (edit && e['label'] == saved?.label));
      addresses.add(reviewed.toMap());
    }
    try {
      final updates = <String, dynamic>{
        'lastAddress': reviewed.toMap(),
        'addresses': addresses
      };
      if (reviewed.label != 'Não salvar' &&
          (_data['defaultAddress'] == null ||
              (edit && _data['defaultAddress']?['label'] == saved?.label))) {
        updates['defaultAddress'] = reviewed.toMap();
      }
      await _workspace.save(updates);
    } catch (_) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Destino confirmado neste uso. A sincronização está pendente; confira a conexão.')));
    }
    if (mounted) _finish(reviewed);
  }

  Future<void> _savedAction(String action, Map saved) async {
    final address = DeliveryAddress.fromMap(Map<String, dynamic>.from(saved));
    if (action == 'edit') {
      await _choose(saved: address, edit: true);
      return;
    }
    final updates = <String, dynamic>{};
    if (action == 'default') {
      updates['defaultAddress'] = address.toMap();
      updates['lastAddress'] = address.toMap();
    } else {
      final confirmed = await showDialog<bool>(
          context: context,
          builder: (ctx) => AlertDialog(
                  title: const Text('Excluir endereço salvo?'),
                  content: Text(address.label),
                  actions: [
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Voltar')),
                    TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Excluir')),
                  ]));
      if (confirmed != true || !mounted) return;
      updates['addresses'] = (_data['addresses'] as List? ?? [])
          .whereType<Map>()
          .where((item) => item['label'] != address.label)
          .toList();
      if (_data['lastAddress']?['label'] == address.label) {
        updates['lastAddress'] = null;
      }
      if (_data['defaultAddress']?['label'] == address.label) {
        updates['defaultAddress'] = null;
      }
    }
    try {
      await _workspace.save(updates);
      if (mounted) setState(() => _data.addAll(updates));
    } catch (_) {
      if (mounted) {
        setState(() => _error =
            'Não foi possível atualizar seus endereços. Tente novamente.');
      }
    }
  }

  Future<void> _useSaved(Map saved) async {
    final address = DeliveryAddress.fromMap(Map<String, dynamic>.from(saved));
    if (!address.confirmed || !address.hasCoordinates) {
      await _choose(saved: address);
      return;
    }
    try {
      await _workspace.save({'lastAddress': address.toMap()});
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text(
                'Destino selecionado. A sincronização ainda está pendente.')));
      }
    }
    if (mounted) _finish(address);
  }

  @override
  Widget build(BuildContext context) => Scaffold(
        appBar: AppBar(
            title: const Text('Onde vamos entregar?'),
            automaticallyImplyLeading: !widget.onboarding),
        body: ListView(padding: const EdgeInsets.all(24), children: [
          const Text(
              'Escolha o destino. A localização do telefone pode ser diferente do local da entrega.'),
          const SizedBox(height: 24),
          ElevatedButton.icon(
              onPressed: () => _choose(gps: true),
              icon: const Icon(Icons.my_location),
              label: const Text('Usar minha localização')),
          const SizedBox(height: 12),
          OutlinedButton.icon(
              onPressed: () => _choose(),
              icon: const Icon(Icons.edit_location_alt_outlined),
              label: const Text('Digitar endereço')),
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator())),
          if (_error != null) ...[
            Text(_error!),
            TextButton(onPressed: _load, child: const Text('Tentar novamente'))
          ],
          if (_data['lastAddress'] is Map)
            Card(
                child: ListTile(
                    title: const Text('Reutilizar último destino'),
                    subtitle: Text(
                        (_data['lastAddress']['addressText'] ?? '').toString()),
                    onTap: () => _useSaved(_data['lastAddress']))),
          for (final saved
              in (_data['addresses'] as List? ?? []).whereType<Map>())
            ListTile(
                leading: const Icon(Icons.bookmark_outline),
                title: Text(
                    '${saved['label'] ?? 'Endereço'}${_data['defaultAddress']?['label'] == saved['label'] ? ' • Padrão' : ''}'),
                subtitle: Text(saved['addressText']?.toString() ?? ''),
                trailing: PopupMenuButton<String>(
                    tooltip: 'Opções do endereço',
                    onSelected: (value) => _savedAction(value, saved),
                    itemBuilder: (_) => const [
                          PopupMenuItem(
                              value: 'edit', child: Text('Editar endereço')),
                          PopupMenuItem(
                              value: 'default',
                              child: Text('Definir como padrão')),
                          PopupMenuItem(
                              value: 'delete', child: Text('Excluir endereço'))
                        ]),
                onTap: () => _useSaved(saved)),
          const SizedBox(height: 24),
          TextButton(
              onPressed: () => _finish(null),
              child: const Text('Explorar catálogo sem endereço')),
          const Text(
              'Defina seu endereço para calcular entrega. Você pode explorar o catálogo antes disso.',
              textAlign: TextAlign.center),
        ]),
      );
}

class AddressInput {
  final String street, number, district, city;
  final bool noNumber;
  const AddressInput(
      this.street, this.number, this.district, this.city, this.noNumber);
  String get query => [street, if (!noNumber) number, district, city]
      .where((s) => s.isNotEmpty)
      .join(', ');
}

class ManualAddressScreen extends StatefulWidget {
  const ManualAddressScreen({super.key});
  @override
  State<ManualAddressScreen> createState() => _ManualAddressScreenState();
}

class _ManualAddressScreenState extends State<ManualAddressScreen> {
  final _form = GlobalKey<FormState>();
  final _street = TextEditingController(),
      _number = TextEditingController(),
      _district = TextEditingController(),
      _city = TextEditingController();
  bool _noNumber = false;
  @override
  void dispose() {
    for (final c in [_street, _number, _district, _city]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Digitar endereço')),
      body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            addressField(_street, 'Rua', required: true),
            addressField(_number, 'Número',
                required: !_noNumber, enabled: !_noNumber),
            CheckboxListTile(
                value: _noNumber,
                onChanged: (v) => setState(() => _noNumber = v!),
                title: const Text('Sem número')),
            addressField(_district, 'Bairro'),
            addressField(_city, 'Cidade', required: true),
            ElevatedButton(
                onPressed: () {
                  if (_form.currentState!.validate()) {
                    Navigator.pop(
                        context,
                        AddressInput(
                            _street.text.trim(),
                            _number.text.trim(),
                            _district.text.trim(),
                            _city.text.trim(),
                            _noNumber));
                  }
                },
                child: const Text('Confirmar no mapa')),
          ])));
}

Widget addressField(TextEditingController controller, String label,
        {bool required = false, bool enabled = true}) =>
    Padding(
        padding: const EdgeInsets.only(bottom: 16),
        child: TextFormField(
            controller: controller,
            enabled: enabled,
            textCapitalization: TextCapitalization.words,
            decoration: InputDecoration(labelText: label),
            validator: (v) => required && (v?.trim().isEmpty ?? true)
                ? 'Informe $label'
                : null));

class AddressReviewScreen extends StatefulWidget {
  final DeliveryAddress address;
  final String? initialLabel;
  const AddressReviewScreen(
      {super.key, required this.address, this.initialLabel});
  @override
  State<AddressReviewScreen> createState() => _AddressReviewScreenState();
}

class _AddressReviewScreenState extends State<AddressReviewScreen> {
  final _form = GlobalKey<FormState>();
  late final _street = TextEditingController(text: widget.address.street),
      _number = TextEditingController(text: widget.address.number),
      _district = TextEditingController(text: widget.address.district),
      _city = TextEditingController(text: widget.address.city),
      _complement = TextEditingController(text: widget.address.complement),
      _reference = TextEditingController(text: widget.address.reference);
  late bool _noNumber = widget.address.noNumber;
  late String? _country = widget.address.countryCode;
  late String _label = widget.initialLabel ?? 'Não salvar';
  @override
  void dispose() {
    for (final c in [
      _street,
      _number,
      _district,
      _city,
      _complement,
      _reference
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
      appBar: AppBar(title: const Text('Confira o endereço')),
      body: Form(
          key: _form,
          child: ListView(padding: const EdgeInsets.all(24), children: [
            const Text(
                'A entrega segue o ponto confirmado no mapa. Confira os dados para ajudar o entregador.'),
            const SizedBox(height: 16),
            addressField(_street, 'Rua', required: true),
            addressField(_number, 'Número',
                required: !_noNumber, enabled: !_noNumber),
            CheckboxListTile(
                value: _noNumber,
                onChanged: (v) => setState(() => _noNumber = v!),
                title: const Text('Sem número')),
            addressField(_district, 'Bairro'),
            addressField(_city, 'Cidade', required: true),
            if (_country == null || _country!.isEmpty) ...[
              const Text(
                  'Não foi possível identificar o país. Esta entrega é no Brasil ou Paraguai?'),
              Wrap(spacing: 12, children: [
                for (final code in ['BR', 'PY'])
                  ChoiceChip(
                      label: Text(code == 'BR' ? 'Brasil' : 'Paraguai'),
                      selected: _country == code,
                      onSelected: (_) => setState(() => _country = code))
              ]),
            ] else
              Text(_country == 'BR'
                  ? 'Destino: Brasil'
                  : _country == 'PY'
                      ? 'Destino: Paraguai'
                      : 'Destino fora da área atendida'),
            const SizedBox(height: 16),
            addressField(_complement, 'Complemento'),
            addressField(_reference, 'Ponto de referência'),
            DropdownButtonFormField<String>(
                initialValue: _label,
                decoration:
                    const InputDecoration(labelText: 'Salvar endereço como'),
                items: ['Não salvar', 'Casa', 'Trabalho', 'Outro']
                    .map((s) => DropdownMenuItem(value: s, child: Text(s)))
                    .toList(),
                onChanged: (v) => setState(() => _label = v!)),
            const SizedBox(height: 24),
            ElevatedButton(
                onPressed: !['BR', 'PY'].contains(_country)
                    ? null
                    : () {
                        if (!_form.currentState!.validate()) return;
                        Navigator.pop(
                            context,
                            DeliveryAddress(
                                latitude: widget.address.latitude,
                                longitude: widget.address.longitude,
                                street: _street.text.trim(),
                                number: _noNumber ? '' : _number.text.trim(),
                                noNumber: _noNumber,
                                district: _district.text.trim(),
                                city: _city.text.trim(),
                                countryCode: _country,
                                complement: _complement.text.trim(),
                                reference: _reference.text.trim(),
                                label: _label,
                                confirmed: true,
                                addressText: [
                                  _street.text.trim(),
                                  _noNumber ? 's/n' : _number.text.trim(),
                                  _district.text.trim(),
                                  _city.text.trim()
                                ].where((s) => s.isNotEmpty).join(', ')));
                      },
                child: const Text('Confirmar destino')),
          ])));
}
