import 'dart:async';
import 'package:flutter/material.dart';
import '../data/customer_location.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../data/reverse_geocode.dart';

class AddressMapResult {
  final double latitude;
  final double longitude;
  final String addressText;
  final String complement;
  final String? countryCode;
  final String reference;
  final String street, number, district, city;
  const AddressMapResult({
    required this.latitude,
    required this.longitude,
    required this.addressText,
    this.complement = '',
    this.countryCode,
    this.reference = '',
    this.street = '',
    this.number = '',
    this.district = '',
    this.city = '',
  });
}

class AddressMapScreen extends StatefulWidget {
  final bool useCurrentLocation;
  final String initialQuery;
  final double? initialLatitude, initialLongitude;
  const AddressMapScreen(
      {super.key,
      this.useCurrentLocation = false,
      this.initialQuery = '',
      this.initialLatitude,
      this.initialLongitude});
  @override
  State<AddressMapScreen> createState() => _AddressMapScreenState();
}

class _AddressMapScreenState extends State<AddressMapScreen> {
  GoogleMapController? _mapController;
  final TextEditingController _complementController = TextEditingController();
  final TextEditingController _referenceController = TextEditingController();
  final TextEditingController _searchController = TextEditingController();
  bool _searching = false;
  LatLng _selectedLocation = _fallbackLocation;
  bool _loadingLocation = true;
  bool _mapReady = false;
  bool _movingMap = false;
  bool _loadingAddress = false;
  int _addressRequestId = 0;
  Timer? _addressDebounce;
  LatLng? _lastAddressLocation;
  String? _locationError;
  String? _countryCode;
  String _street = '', _number = '', _district = '', _city = '';
  String _addressText = 'Localizando endereço...';
  static const LatLng _fallbackLocation = LatLng(
    -22.5361,
    -55.7256,
  );
  @override
  void initState() {
    super.initState();
    if (widget.initialLatitude != null && widget.initialLongitude != null) {
      _selectedLocation =
          LatLng(widget.initialLatitude!, widget.initialLongitude!);
    }
    if (widget.useCurrentLocation) {
      _getCurrentLocation();
    } else {
      _loadingLocation = false;
      _addressText = 'Ajuste o marcador para o local exato da entrega';
      if (widget.initialQuery.isNotEmpty) {
        _searchController.text = widget.initialQuery;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _searchAddress();
        });
      }
    }
  }

  @override
  void dispose() {
    _addressDebounce?.cancel();
    _complementController.dispose();
    _referenceController.dispose();
    _searchController.dispose();
    _mapController?.dispose();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (mounted) {
      setState(() {
        _loadingLocation = true;
        _locationError = null;
      });
    }
    try {
      final position = await const CustomerLocation().request();
      final currentLocation = LatLng(
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      setState(() {
        _selectedLocation = currentLocation;
        _loadingLocation = false;
        _locationError = null;
      });
      await _moveCameraTo(
        currentLocation,
        zoom: 18,
      );
      await _updateAddress(currentLocation);
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _selectedLocation = _fallbackLocation;
        _loadingLocation = false;
        _locationError = e is CustomerLocationFailure
            ? e.message
            : 'Não foi possível obter sua localização. Digite o endereço ou ajuste o ponto no mapa.';
      });
      await _moveCameraTo(
        _fallbackLocation,
        zoom: 16,
      );
      await _updateAddress(_fallbackLocation);
    }
  }

  Future<void> _searchAddress() async {
    final query = _searchController.text.trim();
    if (_searching || query.length < 3) return;
    FocusScope.of(context).unfocus();
    setState(() => _searching = true);
    try {
      final point = await searchAddress(query);
      if (!mounted) return;
      final location = LatLng(point.latitude, point.longitude);
      setState(() {
        _selectedLocation = location;
        _locationError = null;
      });
      await _moveCameraTo(location);
      await _updateAddress(location);
    } catch (_) {
      if (mounted) {
        setState(() => _locationError =
            'Não encontramos esse endereço. Confira rua, número e cidade ou escolha o ponto no mapa.');
      }
    } finally {
      if (mounted) setState(() => _searching = false);
    }
  }

  Future<void> _moveCameraTo(
    LatLng location, {
    double zoom = 18,
  }) async {
    final controller = _mapController;
    if (controller == null) return;
    await controller.animateCamera(
      CameraUpdate.newCameraPosition(
        CameraPosition(
          target: location,
          zoom: zoom,
        ),
      ),
    );
  }

  void _onMapCreated(
    GoogleMapController controller,
  ) {
    _mapController = controller;
    if (!mounted) return;
    setState(() {
      _mapReady = true;
    });
    if (!_loadingLocation) {
      _moveCameraTo(
        _selectedLocation,
        zoom: 18,
      );
    }
  }

  void _onCameraMoveStarted() {
    if (!mounted) return;
    _addressDebounce?.cancel();
    _addressRequestId++;
    _lastAddressLocation = null;
    setState(() {
      _movingMap = true;
      _countryCode = null;
      _loadingAddress = false;
    });
  }

  void _onCameraMove(
    CameraPosition position,
  ) {
    _selectedLocation = position.target;
  }

  void _onCameraIdle() {
    if (!mounted) return;

    setState(() {
      _movingMap = false;
    });

    _scheduleAddressUpdate(_selectedLocation);
  }

  void _scheduleAddressUpdate(LatLng location) {
    _addressDebounce?.cancel();

    final lastLocation = _lastAddressLocation;
    if (lastLocation != null && _isSameAddressPoint(lastLocation, location)) {
      return;
    }

    _addressDebounce = Timer(
      const Duration(milliseconds: 650),
      () {
        if (!mounted) return;
        _updateAddress(location);
      },
    );
  }

  bool _isSameAddressPoint(LatLng a, LatLng b) {
    const tolerance = 0.000015;

    return (a.latitude - b.latitude).abs() < tolerance &&
        (a.longitude - b.longitude).abs() < tolerance;
  }

  Future<void> _updateAddress(
    LatLng location,
  ) async {
    if (!mounted) return;

    final requestId = ++_addressRequestId;

    setState(() {
      _loadingAddress = true;
      _countryCode = null;
    });

    try {
      final result =
          await reverseGeocode(location.latitude, location.longitude);
      final address = result.text;

      if (!mounted || requestId != _addressRequestId) return;

      setState(() {
        _countryCode = result.countryCode;
        _street = result.street;
        _number = result.number;
        _district = result.district;
        _city = result.city;
        _addressText =
            address.isNotEmpty ? address : 'Endereço não identificado';
        _lastAddressLocation = location;
        _loadingAddress = false;
      });
    } catch (e) {
      if (!mounted || requestId != _addressRequestId) return;

      setState(() {
        _countryCode = null;
        _addressText = 'Endereço não identificado';
        _loadingAddress = false;
      });
    }
  }

  void _confirmLocation() {
    Navigator.pop(
      context,
      AddressMapResult(
        countryCode: _countryCode,
        street: _street,
        number: _number,
        district: _district,
        city: _city,
        reference: _referenceController.text.trim(),
        latitude: _selectedLocation.latitude,
        longitude: _selectedLocation.longitude,
        addressText: _addressText,
        complement: _complementController.text.trim(),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF4F5F7),
      appBar: AppBar(
        backgroundColor: const Color(0xFF0C0C0C),
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        titleSpacing: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Local de entrega',
              style: TextStyle(
                color: Colors.white,
                fontSize: 17,
                fontWeight: FontWeight.w900,
              ),
            ),
            Text(
              'Ajuste o marcador para o local exato da entrega',
              style: TextStyle(
                color: Colors.white60,
                fontSize: 10,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => _searchAddress(),
                decoration: InputDecoration(
                    labelText: 'Buscar endereço e número',
                    suffixIcon: _searching
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 20,
                                height: 20,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2)))
                        : IconButton(
                            tooltip: 'Buscar endereço',
                            onPressed: _searchAddress,
                            icon: const Icon(Icons.search))),
              )),
          if (_locationError != null)
            TextButton.icon(
                onPressed: () => Navigator.pop(context),
                icon: const Icon(Icons.edit_location_alt_outlined),
                label: const Text('Digitar endereço')),
          if (_locationError != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(
                horizontal: 16,
                vertical: 10,
              ),
              color: const Color(0xFFFFF4C2),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Icon(
                    Icons.info_outline_rounded,
                    size: 19,
                    color: Colors.black87,
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      _locationError!,
                      style: const TextStyle(
                        fontSize: 11,
                        height: 1.3,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          Expanded(
            child: Stack(
              alignment: Alignment.center,
              children: [
                GoogleMap(
                  initialCameraPosition:
                      CameraPosition(target: _selectedLocation, zoom: 16),
                  onMapCreated: _onMapCreated,
                  onCameraMoveStarted: _onCameraMoveStarted,
                  onCameraMove: _onCameraMove,
                  onCameraIdle: _onCameraIdle,
                  mapType: MapType.normal,
                  myLocationEnabled: false,
                  myLocationButtonEnabled: false,
                  zoomControlsEnabled: false,
                  compassEnabled: true,
                  rotateGesturesEnabled: true,
                  scrollGesturesEnabled: true,
                  zoomGesturesEnabled: true,
                  tiltGesturesEnabled: true,
                  buildingsEnabled: true,
                  trafficEnabled: false,
                  mapToolbarEnabled: false,
                ),
                // Pino fixo no centro.
                IgnorePointer(
                  child: AnimatedContainer(
                    duration: const Duration(
                      milliseconds: 120,
                    ),
                    transform: Matrix4.translationValues(0, 0, 0),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Container(
                          width: 54,
                          height: 54,
                          decoration: BoxDecoration(
                            color: const Color(
                              0xFFFFCC00,
                            ),
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.black,
                              width: 3,
                            ),
                            boxShadow: [
                              BoxShadow(
                                color: Colors.black.withValues(alpha: 0.30),
                                blurRadius: 10,
                                offset: const Offset(
                                  0,
                                  4,
                                ),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.location_on_rounded,
                            color: Colors.black,
                            size: 32,
                          ),
                        ),
                        Container(
                          width: 5,
                          height: 13,
                          decoration: const BoxDecoration(
                            color: Color(
                              0xFF111111,
                            ),
                            borderRadius: BorderRadius.vertical(
                              bottom: Radius.circular(5),
                            ),
                          ),
                        ),
                        AnimatedContainer(
                          duration: const Duration(
                            milliseconds: 120,
                          ),
                          width: 12,
                          height: 4,
                          decoration: BoxDecoration(
                            color: Colors.black.withValues(alpha: 0.30),
                            borderRadius: BorderRadius.circular(
                              20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                if (_loadingLocation)
                  Container(
                    color: Colors.black.withValues(alpha: 0.22),
                    child: const Center(
                      child: Card(
                        child: Padding(
                          padding: EdgeInsets.symmetric(
                            horizontal: 22,
                            vertical: 16,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              SizedBox(
                                width: 20,
                                height: 20,
                                child: CircularProgressIndicator(
                                  strokeWidth: 2.5,
                                  color: Color(
                                    0xFFFFCC00,
                                  ),
                                ),
                              ),
                              SizedBox(width: 12),
                              Text(
                                'Localizando você...',
                                style: TextStyle(
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                Positioned(
                  left: 16,
                  top: 16,
                  child: IgnorePointer(
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 12,
                        vertical: 8,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.94),
                        borderRadius: BorderRadius.circular(20),
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.12),
                            blurRadius: 8,
                          ),
                        ],
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(
                            Icons.open_with_rounded,
                            size: 16,
                            color: Colors.black87,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            _movingMap ? 'Posicionando...' : 'Arraste o mapa',
                            style: const TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                Positioned(
                  right: 16,
                  bottom: 18,
                  child: FloatingActionButton.small(
                    heroTag: 'current_location',
                    backgroundColor: Colors.white,
                    foregroundColor: Colors.black,
                    elevation: 5,
                    onPressed: _loadingLocation ? null : _getCurrentLocation,
                    child: const Icon(
                      Icons.my_location_rounded,
                    ),
                  ),
                ),
              ],
            ),
          ),
          Flexible(
              child: SingleChildScrollView(
                  child: Container(
            color: Colors.white,
            padding: const EdgeInsets.fromLTRB(
              16,
              14,
              16,
              16,
            ),
            child: SafeArea(
              top: false,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.swipe_rounded,
                        color: Color(
                          0xFFFFCC00,
                        ),
                        size: 20,
                      ),
                      SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'Arraste o mapa até o pino ficar exatamente sobre o local da entrega.',
                          style: TextStyle(
                            color: Color(
                              0xFF555555,
                            ),
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: const Color(
                        0xFFF4F5F7,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.location_on_rounded,
                          color: Color(
                            0xFFFFCC00,
                          ),
                        ),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(
                            _loadingAddress
                                ? 'Localizando endereço...'
                                : _addressText,
                            maxLines: 2,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 12,
                              height: 1.25,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                        ),
                        if (_loadingAddress) ...[
                          const SizedBox(width: 10),
                          const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                              strokeWidth: 2,
                              color: Color(
                                0xFFFFCC00,
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _complementController,
                    maxLength: 100,
                    maxLines: 2,
                    minLines: 1,
                    textInputAction: TextInputAction.done,
                    decoration: InputDecoration(
                      labelText: 'Complemento / referência (opcional)',
                      hintText: 'Ex.: Casa 2, ap. 51, portão vermelho...',
                      counterText: '',
                      prefixIcon: const Icon(
                        Icons.home_outlined,
                        color: Color(0xFF111111),
                      ),
                      filled: true,
                      fillColor: const Color(0xFFF4F5F7),
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 14,
                        vertical: 13,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE1E4E8)),
                      ),
                      enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(color: Color(0xFFE1E4E8)),
                      ),
                      focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(12),
                        borderSide: const BorderSide(
                          color: Color(0xFFFFCC00),
                          width: 2,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                      controller: _referenceController,
                      decoration: const InputDecoration(
                          labelText: 'Referência (opcional)')),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 50,
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        elevation: 0,
                        backgroundColor: const Color(
                          0xFFFFCC00,
                        ),
                        foregroundColor: Colors.black,
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(
                            13,
                          ),
                        ),
                      ),
                      onPressed: _loadingLocation ||
                              !_mapReady ||
                              _movingMap ||
                              _loadingAddress ||
                              _searching ||
                              (_addressDebounce?.isActive ?? false)
                          ? null
                          : _confirmLocation,
                      icon: const Icon(
                        Icons.check_circle_rounded,
                      ),
                      label: const Text(
                        'Confirmar localização',
                        style: TextStyle(
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ))),
        ],
      ),
    );
  }
}
