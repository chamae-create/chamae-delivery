class JourneyEstimate {
  JourneyEstimate(
      {required this.durationSeconds,
      required this.departure,
      required this.originLat,
      required this.originLng,
      required this.destinationLat,
      required this.destinationLng});
  final int durationSeconds;
  final DateTime? departure;
  final double originLat, originLng, destinationLat, destinationLng;
  static JourneyEstimate? parse(Map<String, dynamic> data) {
    if (data['available'] != true ||
        data['illustrativeOnly'] != true ||
        data['liveGps'] != false ||
        data['provider'] != 'google-routes' ||
        data['durationSeconds'] is! int ||
        data['durationSeconds'] <= 0 ||
        data['durationSeconds'] > 86400) return null;
    final a = data['origin'], b = data['destination'];
    bool valid(dynamic p) =>
        p is Map &&
        p['latitude'] is num &&
        p['longitude'] is num &&
        (p['latitude'] as num).isFinite &&
        (p['longitude'] as num).isFinite &&
        (p['latitude'] as num).abs() <= 90 &&
        (p['longitude'] as num).abs() <= 180;
    if (!valid(a) ||
        !valid(b) ||
        data['departureAtMs'] != null && data['departureAtMs'] is! int)
      return null;
    return JourneyEstimate(
        durationSeconds: data['durationSeconds'],
        departure: data['departureAtMs'] == null
            ? null
            : DateTime.fromMillisecondsSinceEpoch(data['departureAtMs'],
                isUtc: true),
        originLat: (a['latitude'] as num).toDouble(),
        originLng: (a['longitude'] as num).toDouble(),
        destinationLat: (b['latitude'] as num).toDouble(),
        destinationLng: (b['longitude'] as num).toDouble());
  }

  double progress(DateTime now) => departure == null
      ? 0
      : (now.difference(departure!).inSeconds / durationSeconds)
          .clamp(0.0, 0.9);
  bool overdue(DateTime now) =>
      departure != null &&
      now.difference(departure!).inSeconds >= durationSeconds;
}
