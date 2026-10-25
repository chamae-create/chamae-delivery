import 'dart:async';
import 'package:flutter/material.dart';
import '../core/store_hours.dart';

/// Refreshes presentation when availability changes. Purchase guards still use
/// the existing store-hours rule; this widget never authorizes an order.
class StoreHoursBuilder extends StatefulWidget {
  final Widget Function(BuildContext context, bool open, String label) builder;
  final DateTime Function()? clock;
  const StoreHoursBuilder({super.key, required this.builder, this.clock});

  @override
  State<StoreHoursBuilder> createState() => _StoreHoursBuilderState();
}

class _StoreHoursBuilderState extends State<StoreHoursBuilder>
    with WidgetsBindingObserver {
  late bool _open;
  Timer? _timer;
  DateTime get _now => widget.clock?.call() ?? DateTime.now();

  @override
  void initState() {
    super.initState();
    _open = isStoreOpen(_now);
    WidgetsBinding.instance.addObserver(this);
    _timer = Timer.periodic(const Duration(seconds: 30), (_) => _refresh());
  }

  void _refresh() {
    final open = isStoreOpen(_now);
    if (mounted && open != _open) setState(() => _open = open);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) _refresh();
  }

  @override
  void dispose() {
    _timer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _open, storeHoursLabel(_now));
}
