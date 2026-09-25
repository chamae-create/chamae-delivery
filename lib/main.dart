import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'dart:convert';
import 'dart:async';
import 'dart:math';

// Importações nativas para Web no Flutter atual (3.19+)
// ignore: avoid_web_libraries_in_flutter
import 'dart:html' as html;
// ignore: avoid_web_libraries_in_flutter
import 'dart:ui_web' as ui_web;

void main() {
  runApp(const ChamaeDeliveryApp());
}

// ============================================================================
// 1. INTERNACIONALIZAÇÃO E CONFIGURAÇÃO
// ============================================================================
class AppStrings {
  static String get(String key, String lang) {
    final Map<String, Map<String, String>> translations = {
      'app_title': {'PT': 'Chamaê Delivery 🍻', 'ES': 'Chamaê Delivery 🍻'},
      'lang_title': {'PT': 'Escolha o seu país:', 'ES': 'Elija su país:'},
      'reg_title': {'PT': 'Cadastro do Cliente', 'ES': 'Registro de Cliente'},
      'name': {'PT': 'Nome Completo *', 'ES': 'Nombre Completo *'},
      'social_name': {'PT': 'Nome Social (Opcional)', 'ES': 'Nombre Social (Opcional)'},
      'whatsapp': {'PT': 'WhatsApp / Telefone *', 'ES': 'WhatsApp / Teléfono *'},
      'doc_br': {'PT': 'CPF *', 'ES': 'CPF *'},
      'doc_py': {'PT': 'Cédula de Identidad (C.I.) *', 'ES': 'Cédula de Identidad (C.I.) *'},
      'delivery_to': {'PT': 'Entregar em:', 'ES': 'Entregar en:'},
      'checkout_btn': {'PT': 'Ir para o Pagamento', 'ES': 'Ir al Pago'},
    };
    return translations[key]?[lang] ?? translations[key]?['PT'] ?? key;
  }
}

// ============================================================================
// 2. MODELOS DE DADOS, CÁLCULO DE FRETE E ESTADO DA SESSÃO
// ============================================================================
class DeliveryCalculator {
  // Coordenadas base da loja (Ponto de Partida dos Produtos)
  static const double storeLat = -22.5646; 
  static const double storeLon = -55.7255;

  static double calculateDistance(double customerLat, double customerLon) {
    const p = 0.017453292519943295; // Math.PI / 180
    final c = cos;
    final a = 0.5 - c((customerLat - storeLat) * p) / 2 +
        c(storeLat * p) * c(customerLat * p) *
            (1 - c((customerLon - storeLon) * p)) / 2;
    return 12742 * asin(sqrt(a)); // Distância em Quilómetros
  }

  static double calculateFee(double customerLat, double customerLon) {
    double km = calculateDistance(customerLat, customerLon);
    double baseFee = 6.0; // Taxa fixa inicial de entrega
    double perKmFee = 2.5; // Custo adicional por quilómetro
    double totalFee = baseFee + (km * perKmFee);
    return totalFee < 8.0 ? 8.0 : totalFee; // Taxa mínima de R$ 8,00
  }
}

class CurrencyRates {
  static double brlToPyg = 1500.0; // 1 Real = 1.500 Guaranis
  static double brlToUsd = 0.20; // 1 Dólar = 5 Reais (R$ 1 = US$ 0.20)
}

class Product {
  String id, name, category, description;
  double priceBRL;

  Product({required this.id, required this.name, required this.category, required this.priceBRL, required this.description});

  static String formatPrice(double priceBRL, String currency) {
    switch (currency) {
      case 'PYG':
        final pyg = priceBRL * CurrencyRates.brlToPyg;
        return '₲ ${pyg.toStringAsFixed(0).replaceAllMapped(RegExp(r'(\d{1,3})(?=(\d{3})+(?!\d))'), (match) => '${match[1]}.')}';
      case 'USD':
        final usd = priceBRL * CurrencyRates.brlToUsd;
        return 'US\$ ${usd.toStringAsFixed(2)}';
      case 'BRL':
      default:
        return 'R\$ ${priceBRL.toStringAsFixed(2)}';
    }
  }
}

class CartItem {
  final Product product;
  int quantity;
  CartItem({required this.product, this.quantity = 1});
}

class OrderModel {
  final String id;
  final List<CartItem> items;
  final double totalBRL;
  String status;
  final String address;
  final String paymentMethod;
  final String currencyUsed;
  final String changeInfo;
  final DateTime createdAt;

  OrderModel({
    required this.id,
    required this.items,
    required this.totalBRL,
    required this.status,
    required this.address,
    required this.paymentMethod,
    required this.currencyUsed,
    required this.changeInfo,
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();
}

class UserSession {
  static bool isRegistered = false;
  static String language = 'PT';
  static String currency = 'BRL';
  static String fullName = '';
  static String socialName = '';
  static String whatsapp = '';
  static String document = '';
  static String address = 'A detetar localização atual...';
  
  static double mapLat = -22.5646;
  static double mapLon = -55.7255;
}

class AppState {
  static List<CartItem> cart = [];
  static List<OrderModel> orders = [];

  static List<Product> products = [
    Product(id: '1', name: 'Heineken Long Neck 330ml', category: 'Cervejas', priceBRL: 7.90, description: 'Bem gelada.'),
    Product(id: '2', name: 'Budweiser 330ml', category: 'Cervejas', priceBRL: 5.50, description: 'Standard de excelente qualidade.'),
    Product(id: '3', name: 'Corona Extra 330ml', category: 'Cervejas', priceBRL: 8.50, description: 'Com limão fresco.'),
    Product(id: '4', name: 'Whisky Red Label 1L', category: 'Destilados', priceBRL: 99.90, description: 'Scotch original importado.'),
    Product(id: '5', name: 'Vodka Smirnoff 998ml', category: 'Destilados', priceBRL: 45.00, description: 'Base perfeita para caipiroscas.'),
    Product(id: '6', name: 'Gin Tanqueray 750ml', category: 'Destilados', priceBRL: 129.90, description: 'Gin londrino clássico.'),
    Product(id: '7', name: 'Essência Zomo 50g', category: 'Tabacaria', priceBRL: 14.00, description: 'Sabor melancia gelada.'),
    Product(id: '8', name: 'Carvão de Côco 1kg', category: 'Tabacaria', priceBRL: 28.00, description: 'Alta durabilidade.'),
    Product(id: '9', name: 'Gelo em Cubo 5kg', category: 'Gelo & Conveniência', priceBRL: 12.00, description: 'Gelo cristal pacote 5kg.'),
    Product(id: '10', name: 'Água Mineral 500ml', category: 'Gelo & Conveniência', priceBRL: 3.50, description: 'Pura e refrescante.'),
    Product(id: '11', name: 'Batata Lay\'s Classic 90g', category: 'Snacks', priceBRL: 11.90, description: 'Crocante original.'),
    Product(id: '12', name: 'Combo Resenha Suprema', category: 'Combos', priceBRL: 149.90, description: '1 Red Label + 4 Red Bulls + Gelo.'),
  ];
}

// ============================================================================
// 3. APLICATIVO PRINCIPAL E SPLASH
// ============================================================================
class ChamaeDeliveryApp extends StatelessWidget {
  const ChamaeDeliveryApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Chamaê Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        brightness: Brightness.dark,
        primarySwatch: Colors.amber,
        scaffoldBackgroundColor: const Color(0xFF121212),
        colorScheme: ColorScheme.dark(primary: Colors.amber.shade600, secondary: Colors.amberAccent, surface: const Color(0xFF1E1E1E)),
        cardColor: const Color(0xFF1E1E1E),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

class ChamaeOfficialLogo extends StatelessWidget {
  final double size;
  const ChamaeOfficialLogo({super.key, this.size = 100});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size, height: size,
      decoration: BoxDecoration(shape: BoxShape.circle, boxShadow: [BoxShadow(color: Colors.amber.withOpacity(0.4), blurRadius: 25, spreadRadius: 6)]),
      child: ClipOval(child: Image.asset('assets/images/logo.png', width: size, height: size, fit: BoxFit.cover, errorBuilder: (_, __, ___) => Container(color: Colors.amber.shade700, child: const Center(child: Icon(Icons.local_bar, size: 50, color: Colors.black87))))),
    );
  }
}

class SplashScreen extends StatefulWidget { const SplashScreen({super.key}); @override State<SplashScreen> createState() => _SplashScreenState(); }
class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  late AnimationController _controller; late Animation<double> _animation;
  @override void initState() {
    super.initState();
    _controller = AnimationController(duration: const Duration(seconds: 2), vsync: this);
    _animation = CurvedAnimation(parent: _controller, curve: Curves.easeInOut);
    _controller.forward();
    
    Future.delayed(const Duration(seconds: 3), () {
      if (mounted) {
        if (UserSession.isRegistered) {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const AutoGPSInitScreen()));
        } else {
          Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const LanguageSelectionScreen()));
        }
      }
    });
  }
  @override void dispose() { _controller.dispose(); super.dispose(); }
  @override Widget build(BuildContext context) => Scaffold(backgroundColor: const Color(0xFF121212), body: Center(child: FadeTransition(opacity: _animation, child: const Column(mainAxisAlignment: MainAxisAlignment.center, children: [ChamaeOfficialLogo(size: 130), SizedBox(height: 30), Text('CHAMAÊ DELIVERY', style: TextStyle(fontSize: 28, fontWeight: FontWeight.bold, letterSpacing: 2.5, color: Colors.white)), SizedBox(height: 10), Text('Bebidas e Conveniência na Fronteira\nPonta Porã 🇧🇷 / Pedro Juan Caballero 🇵🇾', style: TextStyle(color: Colors.white70, fontSize: 13, height: 1.4), textAlign: TextAlign.center)]))));
}

class AutoGPSInitScreen extends StatefulWidget {
  const AutoGPSInitScreen({super.key});

  @override
  State<AutoGPSInitScreen> createState() => _AutoGPSInitScreenState();
}

class _AutoGPSInitScreenState extends State<AutoGPSInitScreen> {
  @override
  void initState() {
    super.initState();
    _fetchLocationAndProceed();
  }

  Future<void> _fetchLocationAndProceed() async {
    if (kIsWeb) {
      try {
        final p = await html.window.navigator.geolocation.getCurrentPosition();
        UserSession.mapLat = p.coords?.latitude?.toDouble() ?? UserSession.mapLat;
        UserSession.mapLon = p.coords?.longitude?.toDouble() ?? UserSession.mapLon;

        final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=${UserSession.mapLat}&lon=${UserSession.mapLon}';
        final response = await html.HttpRequest.getString(url);
        final data = json.decode(response);
        if (data['display_name'] != null) {
          UserSession.address = data['display_name'];
        }
      } catch (_) {
        UserSession.address = 'Localização Atual via GPS';
      }
    }

    if (mounted) {
      Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
    }
  }

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFF121212),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            ChamaeOfficialLogo(size: 100),
            SizedBox(height: 25),
            CircularProgressIndicator(color: Colors.amber),
            SizedBox(height: 20),
            Text('A atualizar a sua localização GPS automática...', style: TextStyle(color: Colors.white70, fontSize: 14)),
          ],
        ),
      ),
    );
  }
}

class LanguageSelectionScreen extends StatefulWidget {
  const LanguageSelectionScreen({super.key});

  @override
  State<LanguageSelectionScreen> createState() => _LanguageSelectionScreenState();
}

class _LanguageSelectionScreenState extends State<LanguageSelectionScreen> {
  @override
  Widget build(BuildContext context) {
    final lang = UserSession.language;
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 450),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const ChamaeOfficialLogo(size: 90), const SizedBox(height: 25),
                  Text(AppStrings.get('lang_title', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  const SizedBox(height: 25),
                  InkWell(
                    onTap: () => setState(() { UserSession.language = 'PT'; UserSession.currency = 'BRL'; }),
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(color: lang == 'PT' ? Colors.amber.shade700 : const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: lang == 'PT' ? Colors.amber : Colors.white24, width: 2)),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('🇧🇷', style: TextStyle(fontSize: 24)), SizedBox(width: 15), Text('Brasil', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))]),
                    ),
                  ),
                  const SizedBox(height: 15),
                  InkWell(
                    onTap: () => setState(() { UserSession.language = 'ES'; UserSession.currency = 'PYG'; }),
                    child: Container(
                      width: double.infinity, padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 20),
                      decoration: BoxDecoration(color: lang == 'ES' ? Colors.amber.shade700 : const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(12), border: Border.all(color: lang == 'ES' ? Colors.amber : Colors.white24, width: 2)),
                      child: const Row(mainAxisAlignment: MainAxisAlignment.center, children: [Text('🇵🇾', style: TextStyle(fontSize: 24)), SizedBox(width: 15), Text('Paraguay', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.white))]),
                    ),
                  ),
                  const SizedBox(height: 40),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 52), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12))),
                    onPressed: () => Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const RegistrationScreen())),
                    child: const Text('Continuar', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  ),
                  const SizedBox(height: 30),
                  const Text('🔞 Proibida a venda de bebidas alcoólicas e tabacos a menores de 18 anos.', style: TextStyle(color: Colors.white54, fontSize: 11), textAlign: TextAlign.center),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 4. MAPA COMPARTILHADO
// ============================================================================
class RealWebMapWidget extends StatefulWidget {
  final double lat;
  final double lon;
  final Function(double, double) onLocationChanged;

  const RealWebMapWidget({super.key, required this.lat, required this.lon, required this.onLocationChanged});
  @override State<RealWebMapWidget> createState() => _RealWebMapWidgetState();
}

class _RealWebMapWidgetState extends State<RealWebMapWidget> {
  late String _viewType; StreamSubscription? _msgSub;
  @override void initState() { super.initState(); _registerMap(); _setupMessageListener(); }

  void _setupMessageListener() {
    if (kIsWeb) {
      _msgSub = html.window.onMessage.listen((event) {
        try { if (event.data is String) { final data = json.decode(event.data); if (data['type'] == 'map_drag') widget.onLocationChanged(data['lat'], data['lng']); } } catch (_) {}
      });
    }
  }
  @override void didUpdateWidget(RealWebMapWidget oldWidget) { super.didUpdateWidget(oldWidget); if ((oldWidget.lat - widget.lat).abs() > 0.0001 || (oldWidget.lon - widget.lon).abs() > 0.0001) _registerMap(); }
  @override void dispose() { _msgSub?.cancel(); super.dispose(); }

  void _registerMap() {
    _viewType = 'map-${widget.lat}-${widget.lon}-${DateTime.now().millisecondsSinceEpoch}';
    if (kIsWeb) {
      final String htmlContent = '''
      <!DOCTYPE html><html><head><meta charset="utf-8"><meta name="viewport" content="width=device-width, initial-scale=1.0">
      <link rel="stylesheet" href="https://unpkg.com/leaflet@1.9.4/dist/leaflet.css" /><script src="https://unpkg.com/leaflet@1.9.4/dist/leaflet.js"></script>
      <style>body{margin:0;padding:0;background-color:#1E1E1E;}#map{width:100vw;height:100vh;}.leaflet-control-attribution{display:none;}</style></head>
      <body><div id="map"></div><script>
      var map = L.map('map').setView([${widget.lat}, ${widget.lon}], 16);
      L.tileLayer('https://mt1.google.com/vt/lyrs=m&x={x}&y={y}&z={z}', {maxZoom:20}).addTo(map);
      var marker = L.marker([${widget.lat}, ${widget.lon}], {draggable:true, autoPan:true}).addTo(map);
      function sendPos(lat, lng) { window.parent.postMessage(JSON.stringify({'type':'map_drag', 'lat':lat, 'lng':lng}), "*"); }
      marker.on('dragend', function(e) { var p = marker.getLatLng(); map.panTo(p); sendPos(p.lat, p.lng); });
      map.on('click', function(e) { marker.setLatLng(e.latlng); map.panTo(e.latlng); sendPos(e.latlng.lat, e.latlng.lng); });
      </script></body></html>''';
      final base64Html = base64Encode(utf8.encode(htmlContent));
      ui_web.platformViewRegistry.registerViewFactory(_viewType, (int viewId) { final iframe = html.IFrameElement(); iframe.src = 'data:text/html;base64,$base64Html'; iframe.style.border = 'none'; iframe.style.width = '100%'; iframe.style.height = '100%'; return iframe; });
    }
  }
  @override Widget build(BuildContext context) {
    if (!kIsWeb) return Container(height: 240, decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(12)), child: const Center(child: Text('Mapa web não suportado')));
    return Container(height: 240, width: double.infinity, decoration: BoxDecoration(borderRadius: BorderRadius.circular(12), border: Border.all(color: Colors.amber.shade700, width: 2)), child: ClipRRect(borderRadius: BorderRadius.circular(10), child: HtmlElementView(key: ValueKey(_viewType), viewType: _viewType)));
  }
}

// ============================================================================
// 5. DIALOGO DE CONFIRMAÇÃO DE ENDEREÇO
// ============================================================================
class AddressConfirmationDialog extends StatefulWidget {
  const AddressConfirmationDialog({super.key});

  @override
  State<AddressConfirmationDialog> createState() => _AddressConfirmationDialogState();
}

class _AddressConfirmationDialogState extends State<AddressConfirmationDialog> {
  final _searchCtrl = TextEditingController();
  late TextEditingController _addressCtrl;
  
  late double _mapLat;
  late double _mapLon;
  
  Timer? _debounce;
  List<dynamic> _suggestions = [];
  bool _isSearching = false;

  @override
  void initState() {
    super.initState();
    _addressCtrl = TextEditingController(text: UserSession.address);
    _mapLat = UserSession.mapLat;
    _mapLon = UserSession.mapLon;
  }

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.length < 4) { setState(() => _suggestions = []); return; }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 700), () async {
      try {
        if (kIsWeb) {
          final url = 'https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=4';
          final response = await html.HttpRequest.getString(url);
          setState(() { _suggestions = json.decode(response); _isSearching = false; });
        }
      } catch (e) { setState(() => _isSearching = false); }
    });
  }

  void _selectSuggestion(dynamic item) {
    setState(() {
      _mapLat = double.parse(item['lat']);
      _mapLon = double.parse(item['lon']);
      _addressCtrl.text = item['display_name'];
      _searchCtrl.text = '';
      _suggestions = [];
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      if (kIsWeb) {
        final url = 'https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon';
        final response = await html.HttpRequest.getString(url);
        final data = json.decode(response);
        if (data['display_name'] != null) setState(() => _addressCtrl.text = data['display_name']);
      }
    } catch (e) {}
  }

  @override
  Widget build(BuildContext context) {
    return Dialog(
      backgroundColor: const Color(0xFF1E1E1E),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      insetPadding: const EdgeInsets.all(16),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 750),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Confirmar Endereço de Entrega', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18, color: Colors.white)),
              const SizedBox(height: 10),
              const Text('O motoboy irá recolher os produtos na loja e entregar neste local. Ajuste o pino se necessário:', style: TextStyle(fontSize: 13, color: Colors.white70)),
              const SizedBox(height: 15),

              TextField(
                controller: _searchCtrl,
                onChanged: _onSearchChanged,
                decoration: InputDecoration(
                  hintText: 'Buscar outro endereço...',
                  prefixIcon: const Icon(Icons.search, color: Colors.amber),
                  suffixIcon: _isSearching ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: const Color(0xFF2C2C2C),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 10, vertical: 0),
                ),
              ),

              if (_suggestions.isNotEmpty)
                Container(
                  margin: const EdgeInsets.only(top: 4, bottom: 8),
                  decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber)),
                  child: ListView.separated(
                    shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                    itemCount: _suggestions.length,
                    separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white24),
                    itemBuilder: (context, index) {
                      final item = _suggestions[index];
                      return ListTile(
                        leading: const Icon(Icons.location_on, color: Colors.amber),
                        title: Text(item['display_name'], style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                        onTap: () => _selectSuggestion(item),
                      );
                    },
                  ),
                ),
              
              const SizedBox(height: 12),
              
              RealWebMapWidget(
                lat: _mapLat, 
                lon: _mapLon,
                onLocationChanged: (newLat, newLon) {
                  _mapLat = newLat;
                  _mapLon = newLon;
                  _reverseGeocode(newLat, newLon);
                },
              ),

              const SizedBox(height: 15),
              
              TextField(
                controller: _addressCtrl,
                maxLines: 2,
                decoration: InputDecoration(
                  labelText: 'Endereço Final Confirmado',
                  labelStyle: const TextStyle(color: Colors.amber),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  filled: true, fillColor: const Color(0xFF2C2C2C),
                ),
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
              ),

              const SizedBox(height: 25),
              
              Row(
                children: [
                  Expanded(child: TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Revisar', style: TextStyle(color: Colors.white70)))),
                  const SizedBox(width: 10),
                  Expanded(
                    flex: 2,
                    child: ElevatedButton(
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(vertical: 14)),
                      onPressed: () {
                        UserSession.address = _addressCtrl.text;
                        UserSession.mapLat = _mapLat;
                        UserSession.mapLon = _mapLon;
                        Navigator.pop(context, true);
                      },
                      child: const Text('Confirmar Endereço', style: TextStyle(fontWeight: FontWeight.bold)),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 6. TELA DE CADASTRO (APENAS NO 1º ACESSO)
// ============================================================================
class RegistrationScreen extends StatefulWidget { const RegistrationScreen({super.key}); @override State<RegistrationScreen> createState() => _RegistrationScreenState(); }
class _RegistrationScreenState extends State<RegistrationScreen> {
  final _nameCtrl = TextEditingController(); 
  final _socialCtrl = TextEditingController();
  final _whatsappCtrl = TextEditingController(); 
  final _docCtrl = TextEditingController();
  final _searchCtrl = TextEditingController(); 
  final _addressCtrl = TextEditingController();
  
  bool _acceptedTerms = false;
  double _mapLat = -22.5646; 
  double _mapLon = -55.7255;
  Timer? _debounce; 
  List<dynamic> _suggestions = []; 
  bool _isSearching = false;

  void _onSearchChanged(String query) {
    if (_debounce?.isActive ?? false) _debounce!.cancel();
    if (query.length < 4) { setState(() => _suggestions = []); return; }
    setState(() => _isSearching = true);
    _debounce = Timer(const Duration(milliseconds: 700), () async {
      try {
        if (kIsWeb) {
          final r = await html.HttpRequest.getString('https://nominatim.openstreetmap.org/search?q=$query&format=json&addressdetails=1&limit=4');
          setState(() { _suggestions = json.decode(r); _isSearching = false; });
        }
      } catch (e) { setState(() => _isSearching = false); }
    });
  }

  void _selectSuggestion(dynamic item) {
    setState(() {
      _mapLat = double.parse(item['lat']);
      _mapLon = double.parse(item['lon']);
      _addressCtrl.text = item['display_name'];
      _searchCtrl.text = '';
      _suggestions = [];
    });
    FocusScope.of(context).unfocus();
  }

  Future<void> _reverseGeocode(double lat, double lon) async {
    try {
      if (kIsWeb) {
        final r = await html.HttpRequest.getString('https://nominatim.openstreetmap.org/reverse?format=json&lat=$lat&lon=$lon');
        final data = json.decode(r);
        if (data['display_name'] != null) setState(() => _addressCtrl.text = data['display_name']);
      }
    } catch (e) {}
  }

  void _getCurrentLocation() async {
    if (kIsWeb) {
      try {
        final p = await html.window.navigator.geolocation.getCurrentPosition();
        setState(() {
          _mapLat = p.coords?.latitude?.toDouble() ?? _mapLat;
          _mapLon = p.coords?.longitude?.toDouble() ?? _mapLon;
        });
        await _reverseGeocode(_mapLat, _mapLon);
      } catch (e) {}
    }
  }

  void _proceedToCatalog() {
    if (_nameCtrl.text.trim().isEmpty || _whatsappCtrl.text.trim().isEmpty || _docCtrl.text.trim().isEmpty || _addressCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Preencha os campos obrigatórios (*).')));
      return;
    }

    if (!_acceptedTerms) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('⚠️ Cadastro cancelado: É necessário aceitar os Termos e confirmar que tem mais de 18 anos.'),
          backgroundColor: Colors.redAccent,
          duration: Duration(seconds: 4),
        ),
      );
      return;
    }

    UserSession.isRegistered = true; 
    UserSession.fullName = _nameCtrl.text; 
    UserSession.socialName = _socialCtrl.text;
    UserSession.whatsapp = _whatsappCtrl.text; 
    UserSession.document = _docCtrl.text; 
    UserSession.address = _addressCtrl.text;
    UserSession.mapLat = _mapLat; 
    UserSession.mapLon = _mapLon;
    
    Navigator.pushReplacement(context, MaterialPageRoute(builder: (_) => const HomeScreen()));
  }

  @override Widget build(BuildContext context) {
    final lang = UserSession.language;
    final isBrazil = lang == 'PT';
    return Scaffold(
      appBar: AppBar(title: Text(AppStrings.get('reg_title', lang))),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                TextField(controller: _nameCtrl, decoration: InputDecoration(labelText: AppStrings.get('name', lang), prefixIcon: const Icon(Icons.person, color: Colors.amber), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 12),
                TextField(controller: _socialCtrl, decoration: InputDecoration(labelText: AppStrings.get('social_name', lang), prefixIcon: const Icon(Icons.person_outline, color: Colors.amber), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 12),
                TextField(controller: _whatsappCtrl, keyboardType: TextInputType.phone, decoration: InputDecoration(labelText: AppStrings.get('whatsapp', lang), prefixIcon: const Icon(Icons.phone, color: Colors.amber), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 12),
                TextField(controller: _docCtrl, decoration: InputDecoration(labelText: isBrazil ? AppStrings.get('doc_br', lang) : AppStrings.get('doc_py', lang), prefixIcon: const Icon(Icons.badge, color: Colors.amber), filled: true, fillColor: const Color(0xFF1E1E1E), border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)))),
                const SizedBox(height: 30),
                const Text('🗺️ Defina seu Local de Entrega', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber)),
                const SizedBox(height: 12),
                TextField(
                  controller: _searchCtrl,
                  onChanged: _onSearchChanged,
                  decoration: InputDecoration(
                    hintText: 'Digite a rua, bairro ou local...',
                    prefixIcon: const Icon(Icons.search, color: Colors.amber),
                    suffixIcon: _isSearching ? const Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(strokeWidth: 2)) : null,
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true, fillColor: const Color(0xFF1E1E1E),
                  ),
                ),
                if (_suggestions.isNotEmpty)
                  Container(
                    margin: const EdgeInsets.only(top: 4, bottom: 12),
                    decoration: BoxDecoration(color: const Color(0xFF2C2C2C), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.amber)),
                    child: ListView.separated(
                      shrinkWrap: true, physics: const NeverScrollableScrollPhysics(),
                      itemCount: _suggestions.length,
                      separatorBuilder: (_, __) => const Divider(height: 1, color: Colors.white24),
                      itemBuilder: (context, index) {
                        final item = _suggestions[index];
                        return ListTile(
                          leading: const Icon(Icons.location_on, color: Colors.amber),
                          title: Text(item['display_name'], style: const TextStyle(fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
                          onTap: () => _selectSuggestion(item),
                        );
                      },
                    ),
                  ),
                const SizedBox(height: 12),
                const Text('Arraste o pino ou toque no mapa para ajuste fino:', style: TextStyle(color: Colors.white60, fontSize: 12)),
                const SizedBox(height: 5),
                RealWebMapWidget(
                  lat: _mapLat, lon: _mapLon,
                  onLocationChanged: (lat, lon) {
                    _mapLat = lat; _mapLon = lon;
                    _reverseGeocode(lat, lon);
                  },
                ),
                const SizedBox(height: 12),
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.grey.shade800, foregroundColor: Colors.amber, padding: const EdgeInsets.symmetric(vertical: 14)),
                  icon: const Icon(Icons.my_location, size: 20),
                  label: const Text('Localizar Pelo Meu GPS Real', style: TextStyle(fontWeight: FontWeight.bold)),
                  onPressed: _getCurrentLocation,
                ),
                const SizedBox(height: 20),
                TextField(
                  controller: _addressCtrl, maxLines: 2,
                  decoration: InputDecoration(
                    labelText: 'Endereço Final Confirmado (Adicione o Nº da casa) *',
                    prefixIcon: const Icon(Icons.check_circle, color: Colors.green),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true, fillColor: const Color(0xFF1E1E1E),
                  ),
                ),
                const SizedBox(height: 20),

                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(color: const Color(0xFF1E1E1E), borderRadius: BorderRadius.circular(10), border: Border.all(color: Colors.white24)),
                  child: Row(
                    children: [
                      Checkbox(
                        value: _acceptedTerms,
                        activeColor: Colors.amber.shade700,
                        checkColor: Colors.black,
                        onChanged: (bool? value) {
                          setState(() {
                            _acceptedTerms = value ?? false;
                          });
                        },
                      ),
                      Expanded(
                        child: GestureDetector(
                          onTap: () => setState(() => _acceptedTerms = !_acceptedTerms),
                          child: const Text(
                            'Declaro que tenho mais de 18 anos e concordo com os Termos de Uso e Política de Privacidade da plataforma.',
                            style: TextStyle(fontSize: 12, color: Colors.white70),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 30),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.black, minimumSize: const Size(double.infinity, 50), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                  onPressed: _proceedToCatalog,
                  child: const Text('Avançar para o Catálogo', style: TextStyle(fontSize: 15, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(height: 25),

                const Center(
                  child: Text(
                    '🔞 Proibida a venda e o consumo de bebidas alcoólicas e tabaco para menores de 18 anos.',
                    style: TextStyle(color: Colors.white54, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 7. TELA PRINCIPAL (CATÁLOGO)
// ============================================================================
class HomeScreen extends StatefulWidget { const HomeScreen({super.key}); @override State<HomeScreen> createState() => _HomeScreenState(); }
class _HomeScreenState extends State<HomeScreen> {
  String _selectedCategory = 'Todos'; 
  String _searchQuery = '';

  void _addToCart(Product product) {
    setState(() {
      final idx = AppState.cart.indexWhere((i) => i.product.id == product.id);
      if (idx >= 0) AppState.cart[idx].quantity++;
      else AppState.cart.add(CartItem(product: product));
    });
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('${product.name} adicionado!'), duration: const Duration(milliseconds: 500), behavior: SnackBarBehavior.floating));
  }

  void _removeFromCart(Product product) {
    setState(() {
      final idx = AppState.cart.indexWhere((i) => i.product.id == product.id);
      if (idx >= 0) {
        if (AppState.cart[idx].quantity > 1) AppState.cart[idx].quantity--;
        else AppState.cart.removeAt(idx);
      }
    });
  }

  int _getQty(String id) {
    final item = AppState.cart.where((i) => i.product.id == id);
    return item.isNotEmpty ? item.first.quantity : 0;
  }

  @override Widget build(BuildContext context) {
    final lang = UserSession.language;
    final categories = ['Todos', 'Cervejas', 'Destilados', 'Tabacaria', 'Gelo & Conveniência', 'Snacks', 'Combos'];
    
    final filtered = AppState.products.where((p) {
      final matchesCat = _selectedCategory == 'Todos' || p.category == _selectedCategory;
      final matchesSearch = p.name.toLowerCase().contains(_searchQuery.toLowerCase());
      return matchesCat && matchesSearch;
    }).toList();

    double totalBRL = AppState.cart.fold(0, (s, i) => s + (i.product.priceBRL * i.quantity));
    int totalItems = AppState.cart.fold(0, (s, i) => s + i.quantity);

    return Scaffold(
      appBar: AppBar(
        backgroundColor: const Color(0xFF161616),
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(AppStrings.get('delivery_to', lang), style: const TextStyle(fontSize: 10, color: Colors.white60)),
            Text(UserSession.address, style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.white), overflow: TextOverflow.ellipsis),
          ],
        ),
        actions: [
          DropdownButton<String>(
            value: UserSession.currency,
            dropdownColor: const Color(0xFF2C2C2C),
            underline: const SizedBox(),
            items: const [
              DropdownMenuItem(value: 'BRL', child: Text('R\$ BRL', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold))),
              DropdownMenuItem(value: 'PYG', child: Text('₲ PYG', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold))),
              DropdownMenuItem(value: 'USD', child: Text('\$ USD', style: TextStyle(color: Colors.amber, fontSize: 12, fontWeight: FontWeight.bold))),
            ],
            onChanged: (v) => setState(() => UserSession.currency = v!),
          ),
          IconButton(
            icon: const Icon(Icons.admin_panel_settings),
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const AdminScreen())).then((_) => setState(() {})),
          ),
        ],
      ),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 700),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.all(12.0),
                child: TextField(
                  onChanged: (v) => setState(() => _searchQuery = v),
                  decoration: InputDecoration(
                    hintText: 'Buscar produto...',
                    prefixIcon: const Icon(Icons.search, color: Colors.amber),
                    filled: true, fillColor: const Color(0xFF1E1E1E),
                    contentPadding: const EdgeInsets.symmetric(vertical: 0),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12), borderSide: BorderSide.none),
                  ),
                ),
              ),
              SizedBox(
                height: 45,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 10),
                  itemCount: categories.length,
                  itemBuilder: (context, index) {
                    final cat = categories[index];
                    final isSelected = cat == _selectedCategory;
                    return Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      child: ChoiceChip(
                        label: Text(cat),
                        selected: isSelected,
                        selectedColor: Colors.amber.shade700,
                        backgroundColor: const Color(0xFF1E1E1E),
                        labelStyle: TextStyle(color: isSelected ? Colors.black : Colors.white, fontWeight: FontWeight.bold, fontSize: 12),
                        onSelected: (_) => setState(() => _selectedCategory = cat),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 5),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.all(10),
                  itemCount: filtered.length,
                  itemBuilder: (context, index) {
                    final product = filtered[index];
                    final qty = _getQty(product.id);
                    return Card(
                      margin: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(product.name, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                  const SizedBox(height: 4),
                                  Text(product.description, style: const TextStyle(color: Colors.white70, fontSize: 12)),
                                  const SizedBox(height: 8),
                                  Text(Product.formatPrice(product.priceBRL, UserSession.currency), style: TextStyle(color: Colors.amber.shade400, fontWeight: FontWeight.bold, fontSize: 15)),
                                ],
                              ),
                            ),
                            const SizedBox(width: 10),
                            Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                if (qty > 0)
                                  Row(
                                    children: [
                                      IconButton(icon: const Icon(Icons.remove_circle_outline, color: Colors.amber), onPressed: () => _removeFromCart(product)),
                                      Text('$qty', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                                      IconButton(icon: const Icon(Icons.add_circle, color: Colors.amber), onPressed: () => _addToCart(product)),
                                    ],
                                  )
                                else
                                  ElevatedButton.icon(
                                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8)),
                                    icon: const Icon(Icons.add, size: 18),
                                    label: const Text('Adicionar', style: TextStyle(fontWeight: FontWeight.bold)),
                                    onPressed: () => _addToCart(product),
                                  ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
      bottomNavigationBar: totalItems > 0
          ? Container(
              padding: const EdgeInsets.all(14),
              color: const Color(0xFF1E1E1E),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('$totalItems itens selecionados', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text(Product.formatPrice(totalBRL, UserSession.currency), style: TextStyle(color: Colors.amber.shade400, fontWeight: FontWeight.bold, fontSize: 18)),
                    ],
                  ),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(backgroundColor: Colors.amber.shade700, foregroundColor: Colors.black, padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12), shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10))),
                    onPressed: () {
                      Navigator.push(context, MaterialPageRoute(builder: (_) => CheckoutScreen(onUpdate: () => setState(() {})))).then((_) => setState(() {}));
                    },
                    child: Text(AppStrings.get('checkout_btn', lang), style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                  ),
                ],
              ),
            )
          : null,
    );
  }
}

// ============================================================================
// 8. CHECKOUT E PAGAMENTO (CÁLCULO DE FRETE DINÂMICO + PIX DINÂMICO)
// ============================================================================
class CheckoutScreen extends StatefulWidget {
  final VoidCallback onUpdate;
  const CheckoutScreen({super.key, required this.onUpdate});

  @override
  State<CheckoutScreen> createState() => _CheckoutScreenState();
}

class _CheckoutScreenState extends State<CheckoutScreen> {
  String _paymentMethod = 'Pix';
  String _cashCurrency = 'BRL';
  final _changeCtrl = TextEditingController();

  double get _subtotal => AppState.cart.fold(0, (sum, i) => sum + (i.product.priceBRL * i.quantity));
  
  // Cálculo automático do frete baseado na distância em km da loja até o cliente
  double get _deliveryFee => DeliveryCalculator.calculateFee(UserSession.mapLat, UserSession.mapLon);
  
  double get _platformFee => _subtotal * 0.01;
  double get _totalBRL => _subtotal + _deliveryFee + _platformFee;

  String get _displayCurrency => _paymentMethod == 'Dinheiro' ? _cashCurrency : UserSession.currency;

  void _handleCheckoutProcess() {
    showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (_) => const AddressConfirmationDialog(),
    ).then((confirmed) {
      if (confirmed == true) {
        if (_paymentMethod == 'Pix') {
          _showDynamicPixPopup();
        } else {
          _finalizeOrder();
        }
      }
    });
  }

  String _calculateCRC16(String payload) {
    int crc = 0xFFFF;
    for (int i = 0; i < payload.length; i++) {
      int c = payload.codeUnitAt(i);
      crc ^= (c << 8);
      for (int j = 0; j < 8; j++) {
        if ((crc & 0x8000) != 0) {
          crc = ((crc << 1) ^ 0x1021) & 0xFFFF;
        } else {
          crc = (crc << 1) & 0xFFFF;
        }
      }
    }
    return crc.toRadixString(16).toUpperCase().padLeft(4, '0');
  }

  String _gerarPayloadPixDinamico({required double valor, required String txid}) {
    String formatField(String id, String value) {
      int length = value.length;
      String lenStr = length.toString().padLeft(2, '0');
      return '$id$lenStr$value';
    }

    const String chavePix = 'beffdd22-dccb-4d0c-a9d7-7a0555277a57';
    String gui = formatField('00', 'br.gov.bcb.pix');
    String key = formatField('01', chavePix);
    String merchantAccount = formatField('26', gui + key);

    String payload = '';
    payload += formatField('00', '01');
    payload += formatField('01', '12');
    payload += merchantAccount;
    payload += formatField('52', '0000');
    payload += formatField('53', '986');
    payload += formatField('54', valor.toStringAsFixed(2));
    payload += formatField('58', 'BR');
    payload += formatField('59', 'CHAMAE DELIVERY');
    payload += formatField('60', 'Ponta Pora');
    
    String txidField = formatField('05', txid);
    payload += formatField('62', txidField);

    payload += '6304';
    String crc = _calculateCRC16(payload);
    return payload + crc;
  }

  void _showDynamicPixPopup() {
    final String uniqueTxId = 'CH${DateTime.now().millisecondsSinceEpoch}';
    final String emvPixPayload = _gerarPayloadPixDinamico(valor: _totalBRL, txid: uniqueTxId);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (BuildContext dialogContext) {
        return StatefulBuilder(
          builder: (context, setStateModal) {
            Future.delayed(const Duration(seconds: 10), () {
              if (Navigator.canPop(dialogContext)) {
                Navigator.pop(dialogContext);
                _finalizeOrder();
              }
            });

            return AlertDialog(
              backgroundColor: const Color(0xFF1E1E1E),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              title: const Text('Aguardando Pagamento Pix', style: TextStyle(color: Colors.amber, fontWeight: FontWeight.bold)),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Valor do Pedido: R\$ ${_totalBRL.toStringAsFixed(2)}', style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold, color: Colors.amberAccent)),
                    const SizedBox(height: 10),
                    const Text('Escaneie o QR Code ou copie o código Pix abaixo:', style: TextStyle(fontSize: 12, color: Colors.white70), textAlign: TextAlign.center),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(8)),
                      child: Image.network(
                        'https://api.qrserver.com/v1/create-qr-code/?size=150x150&data=${Uri.encodeComponent(emvPixPayload)}',
                        width: 150,
                        height: 150,
                        errorBuilder: (_, __, ___) => const Padding(
                          padding: EdgeInsets.all(40.0),
                          child: Icon(Icons.error, color: Colors.red, size: 40),
                        ),
                      ),
                    ),
                    const SizedBox(height: 15),
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF2C2C2C),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: Colors.amber.shade700),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Text('Pix Copia e Cola:', style: TextStyle(color: Colors.amber, fontSize: 11, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 4),
                          SizedBox(
                            height: 50,
                            child: SingleChildScrollView(
                              child: SelectableText(
                                emvPixPayload,
                                style: const TextStyle(fontSize: 10, color: Colors.white70),
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          ElevatedButton.icon(
                            style: ElevatedButton.styleFrom(
                              backgroundColor: Colors.amber.shade700,
                              foregroundColor: Colors.black,
                              minimumSize: const Size(double.infinity, 36),
                            ),
                            icon: const Icon(Icons.copy, size: 16),
                            label: const Text('Copiar Código Pix', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12)),
                            onPressed: () {
                              Clipboard.setData(ClipboardData(text: emvPixPayload));
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(content: Text('Código Pix copiado! Cole no aplicativo do seu banco.'), duration: Duration(seconds: 2)),
                              );
                            },
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    const CircularProgressIndicator(color: Colors.amber),
                    const SizedBox(height: 10),
                    const Text('Identificando pagamento automaticamente...', style: TextStyle(fontSize: 11, color: Colors.amberAccent), textAlign: TextAlign.center),
                    const SizedBox(height: 8),
                    TextButton(
                      onPressed: () {
                        Navigator.pop(dialogContext);
                        _finalizeOrder();
                      },
                      child: const Text('Simular aprovação imediata', style: TextStyle(color: Colors.white54, fontSize: 11)),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
  }

  void _finalizeOrder() {
    String changeInfo = 'Sem troco';
    if (_paymentMethod == 'Dinheiro') {
      final changeValue = double.tryParse(_changeCtrl.text) ?? 0.0;
      if (changeValue > 0) {
        changeInfo = 'Troco para: $changeValue ($_cashCurrency)';
      }
    }

    final newOrder = OrderModel(
      id: 'CH-${DateTime.now().millisecondsSinceEpoch.toString().substring(7)}',
      items: List.from(AppState.cart),
      totalBRL: _totalBRL,
      status: 'Aguardando Motoboy',
      address: UserSession.address,
      paymentMethod: _paymentMethod,
      currencyUsed: _displayCurrency,
      changeInfo: changeInfo,
      createdAt: DateTime.now(),
    );

    AppState.orders.add(newOrder);
    AppState.cart.clear();
    widget.onUpdate();

    Navigator.pushReplacement(
      context,
      MaterialPageRoute(builder: (_) => TrackingScreen(order: newOrder)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final double distanceKm = DeliveryCalculator.calculateDistance(UserSession.mapLat, UserSession.mapLon);

    return Scaffold(
      appBar: AppBar(title: const Text('Checkout & Pagamento')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text('Forma de Pagamento', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber)),
                const SizedBox(height: 10),
                DropdownButtonFormField<String>(
                  value: _paymentMethod,
                  dropdownColor: const Color(0xFF2C2C2C),
                  decoration: InputDecoration(
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                    filled: true, fillColor: const Color(0xFF1E1E1E),
                  ),
                  items: const [
                    DropdownMenuItem(value: 'Pix', child: Text('Pix Instantâneo')),
                    DropdownMenuItem(value: 'Cartão na Maquininha', child: Text('Cartão (Débito / Crédito na Entrega)')),
                    DropdownMenuItem(value: 'Dinheiro', child: Text('Dinheiro (Efectivo)')),
                  ],
                  onChanged: (val) {
                    setState(() {
                      _paymentMethod = val ?? 'Pix';
                      if (_paymentMethod == 'Dinheiro') {
                        _cashCurrency = UserSession.currency;
                      }
                    });
                  },
                ),
                const SizedBox(height: 20),

                if (_paymentMethod == 'Dinheiro') ...[
                  const Text('Moeda de Pagamento em Dinheiro', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14, color: Colors.amber)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<String>(
                    value: _cashCurrency,
                    dropdownColor: const Color(0xFF2C2C2C),
                    decoration: InputDecoration(
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true, fillColor: const Color(0xFF1E1E1E),
                    ),
                    items: const [
                      DropdownMenuItem(value: 'BRL', child: Text('Real (R\$)')),
                      DropdownMenuItem(value: 'PYG', child: Text('Guarani (₲)')),
                      DropdownMenuItem(value: 'USD', child: Text('Dólar (US\$)')),
                    ],
                    onChanged: (val) => setState(() => _cashCurrency = val ?? 'BRL'),
                  ),
                  const SizedBox(height: 15),
                  TextField(
                    controller: _changeCtrl,
                    keyboardType: TextInputType.number,
                    decoration: InputDecoration(
                      labelText: 'Precisa de troco para quanto?',
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                      filled: true, fillColor: const Color(0xFF1E1E1E),
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                const Divider(height: 30),
                const Text('Resumo dos Valores', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 16, color: Colors.amber)),
                const SizedBox(height: 10),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Subtotal:'), Text(Product.formatPrice(_subtotal, _displayCurrency))]),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [Text('Frete GPS (${distanceKm.toStringAsFixed(1)} km):'), Text(Product.formatPrice(_deliveryFee, _displayCurrency))]),
                const SizedBox(height: 6),
                Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [const Text('Taxa Plataforma (1%):'), Text(Product.formatPrice(_platformFee, _displayCurrency))]),
                const Divider(height: 20),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    const Text('Total Geral:', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18)),
                    Text(Product.formatPrice(_totalBRL, _displayCurrency), style: TextStyle(color: Colors.amber.shade400, fontWeight: FontWeight.bold, fontSize: 20)),
                  ],
                ),
                const SizedBox(height: 40),

                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.amber.shade700, foregroundColor: Colors.black,
                    minimumSize: const Size(double.infinity, 52),
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  onPressed: _handleCheckoutProcess,
                  child: const Text('Realizar Pagamento & Enviar Pedido', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// 9. RASTREAMENTO E PAINEL ADMIN
// ============================================================================
class TrackingScreen extends StatelessWidget {
  final OrderModel order;
  const TrackingScreen({super.key, required this.order});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Acompanhar Pedido #${order.id}')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 600),
          child: Padding(
            padding: const EdgeInsets.all(20.0),
            child: Column(
              children: [
                const Icon(Icons.delivery_dining, size: 85, color: Colors.amber),
                const SizedBox(height: 15),
                const Text('Pedido Enviado ao Motoboy!', style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold)),
                const SizedBox(height: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
                  decoration: BoxDecoration(color: Colors.amber.shade900, borderRadius: BorderRadius.circular(20)),
                  child: Text('Estágio: ${order.status}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                ),
                const SizedBox(height: 25),
                Container(
                  height: 180, width: double.infinity,
                  decoration: BoxDecoration(color: Colors.grey.shade900, borderRadius: BorderRadius.circular(16), border: Border.all(color: Colors.amber.shade700, width: 2)),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.directions_bike, size: 45, color: Colors.amber),
                        SizedBox(height: 10),
                        Text('Google Maps: Motoboy em deslocamento 🛵', style: TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 20),
                Align(
                  alignment: Alignment.centerLeft,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Endereço: ${order.address}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('Pagamento: ${order.paymentMethod} (${order.currencyUsed})', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                      Text('Troco: ${order.changeInfo}', style: const TextStyle(color: Colors.white70, fontSize: 12)),
                    ],
                  ),
                ),
                const Spacer(),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(minimumSize: const Size(double.infinity, 50)),
                  onPressed: () => Navigator.popUntil(context, (route) => route.isFirst),
                  child: const Text('Voltar ao Início'),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class AdminScreen extends StatefulWidget {
  const AdminScreen({super.key});

  @override
  State<AdminScreen> createState() => _AdminScreenState();
}

class _AdminScreenState extends State<AdminScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Painel do Motoboy & Lojista')),
      body: Center(
        child: ConstrainedBox(
          constraints: const BoxConstraints(maxWidth: 800),
          child: AppState.orders.isEmpty
              ? const Center(child: Text('Nenhum pedido enviado ainda.', style: TextStyle(color: Colors.white54)))
              : ListView.builder(
                  itemCount: AppState.orders.length,
                  itemBuilder: (context, index) {
                    final order = AppState.orders[index];
                    return Card(
                      margin: const EdgeInsets.all(10),
                      child: Padding(
                        padding: const EdgeInsets.all(12.0),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Pedido #${order.id}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.amber)),
                                DropdownButton<String>(
                                  value: order.status,
                                  dropdownColor: const Color(0xFF2C2C2C),
                                  items: const [
                                    DropdownMenuItem(value: 'Aguardando Motoboy', child: Text('Aguardando Motoboy', style: TextStyle(color: Colors.amber))),
                                    DropdownMenuItem(value: 'Em Separação', child: Text('Em Separação')),
                                    DropdownMenuItem(value: 'Saiu para Entrega', child: Text('Saiu para Entrega')),
                                    DropdownMenuItem(value: 'Entregue', child: Text('Entregue')),
                                  ],
                                  onChanged: (newStatus) => setState(() => order.status = newStatus ?? order.status),
                                ),
                              ],
                            ),
                            Text('Endereço: ${order.address}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            Text('Pagamento: ${order.paymentMethod}', style: const TextStyle(fontSize: 12, color: Colors.white70)),
                            const Divider(),
                            Text('Total: R\$ ${order.totalBRL.toStringAsFixed(2)}', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                          ],
                        ),
                      ),
                    );
                  },
                ),
        ),
      ),
    );
  }
}