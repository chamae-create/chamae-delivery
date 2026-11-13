import 'dart:async';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:cloud_functions/cloud_functions.dart';
import 'package:google_maps_flutter/google_maps_flutter.dart';
import '../core/journey_estimate.dart';

class CustomerJourneyMap extends StatefulWidget {
  const CustomerJourneyMap(
      {required this.orderId,
      required this.status,
      this.estimateLoader,
      this.illustrationBuilder,
      super.key});
  final String orderId, status;
  final Future<Map<String, dynamic>> Function(String)? estimateLoader;
  final Widget Function(double, JourneyEstimate)? illustrationBuilder;
  @override
  State<CustomerJourneyMap> createState() => _CustomerJourneyMapState();
}

class _CustomerJourneyMapState extends State<CustomerJourneyMap> {
  JourneyEstimate? estimate;
  Timer? timer;
  BitmapDescriptor? bike;
  int generation = 0;
  @override
  void initState() {
    super.initState();
    _load();
    if (widget.illustrationBuilder == null) _icon();
  }

  @override
  void didUpdateWidget(CustomerJourneyMap old) {
    super.didUpdateWidget(old);
    if (old.orderId != widget.orderId || old.status != widget.status) {
      timer?.cancel();
      estimate = null;
      _load();
    }
  }

  Future<void> _icon() async {
    try {
      final recorder = ui.PictureRecorder(), canvas = Canvas(recorder);
      final painter = TextPainter(
          textDirection: TextDirection.ltr,
          text: TextSpan(
              text: String.fromCharCode(Icons.two_wheeler.codePoint),
              style: TextStyle(
                  fontSize: 48,
                  color: Colors.black,
                  fontFamily: Icons.two_wheeler.fontFamily)));
      painter.layout();
      painter.paint(canvas, Offset.zero);
      final picture = recorder.endRecording(),
          image = await picture.toImage(64, 64);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      picture.dispose();
      if (mounted && bytes != null) {
        setState(
            () => bike = BitmapDescriptor.bytes(bytes.buffer.asUint8List()));
      }
    } catch (_) {/* Icon failure never affects order state. */}
  }

  Future<void> _load() async {
    final version = ++generation;
    if (!['Em Separação', 'Saiu para Entrega'].contains(widget.status)) return;
    try {
      final Map<String, dynamic> data;
      if (widget.estimateLoader != null) {
        data = await widget.estimateLoader!(widget.orderId);
      } else {
        final response =
            await FirebaseFunctions.instanceFor(region: 'southamerica-east1')
                .httpsCallable('chamaePrevisaoEntrega')
                .call({'orderId': widget.orderId});
        data = Map<String, dynamic>.from(response.data as Map);
      }
      if (!mounted || version != generation) return;
      if (data['orderId'] != widget.orderId || data['status'] != widget.status) {
        return;
      }
      setState(() => estimate = JourneyEstimate.parse(data));
      timer = Timer.periodic(const Duration(seconds: 15), (_) {
        if (mounted) setState(() {});
      });
    } catch (_) {
      if (mounted && version == generation) setState(() => estimate = null);
    }
  }

  @override
  void dispose() {
    generation++;
    timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final e = estimate;
    if (e == null ||
        !['Em Separação', 'Saiu para Entrega'].contains(widget.status)) {
      return const SizedBox.shrink();
    }
    final now = DateTime.now().toUtc(),
        p = MediaQuery.disableAnimationsOf(context)
            ? 0.0
            : e.progress(DateTime.now().toUtc());
    final origin = LatLng(e.originLat, e.originLng),
        destination = LatLng(e.destinationLat, e.destinationLng);
    return Card(
        child: Padding(
            padding: const EdgeInsets.all(12),
            child:
                Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(e.overdue(now)
                  ? 'Estimativa excedida; aguarde atualização da loja.'
                  : 'Trajeto estimado: ${(e.durationSeconds / 60).ceil()} min${e.departure == null ? ' após a saída' : ''}'),
              const Text(
                  'Moto ilustrativa — não é GPS real do entregador. Trajeto esquemático.'),
              SizedBox(
                  height: 220,
                  child: TweenAnimationBuilder<double>(
                      tween: Tween(end: p),
                      duration: MediaQuery.disableAnimationsOf(context)
                          ? Duration.zero
                          : const Duration(seconds: 1),
                      builder: (_, value, __) =>
                          widget.illustrationBuilder?.call(value, e) ??
                          GoogleMap(
                            key: ValueKey(widget.orderId),
                            initialCameraPosition:
                                CameraPosition(target: origin, zoom: 13),
                            myLocationEnabled: false,
                            myLocationButtonEnabled: false,
                            mapToolbarEnabled: false,
                            markers: {
                              Marker(
                                  markerId: const MarkerId('illustrative-bike'),
                                  position: LatLng(
                                      e.originLat +
                                          (e.destinationLat - e.originLat) *
                                              value,
                                      e.originLng +
                                          (e.destinationLng - e.originLng) *
                                              value),
                                  icon: bike ?? BitmapDescriptor.defaultMarker,
                                  infoWindow: const InfoWindow(
                                      title:
                                          'Moto ilustrativa · sem GPS real')),
                              Marker(
                                  markerId:
                                      const MarkerId('delivery-destination'),
                                  position: destination)
                            },
                            polylines: {
                              Polyline(
                                  polylineId: const PolylineId('illustration'),
                                  points: [origin, destination],
                                  color: Colors.amber,
                                  width: 3)
                            },
                          ))),
              const Text('O tempo estimado não confirma chegada ou entrega.'),
            ])));
  }
}
