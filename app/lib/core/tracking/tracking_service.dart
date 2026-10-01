import 'dart:async';
import 'package:geolocator/geolocator.dart';
import '../network/functions_client.dart';

/// Phase 12: driver-side ping loop. Runs only while the trip is `departed`;
/// call [stop] on completion. ~15s interval to protect battery + data.
class TrackingService {
  final _api = FunctionsClient();
  StreamSubscription<Position>? _sub;
  String? tripId;
  bool get running => _sub != null;

  Future<bool> ensurePermission() async {
    var p = await Geolocator.checkPermission();
    if (p == LocationPermission.denied) p = await Geolocator.requestPermission();
    return p == LocationPermission.always || p == LocationPermission.whileInUse;
  }

  Future<void> start(String tripId) async {
    if (running) return;
    if (!await ensurePermission()) throw Exception('Location permission denied');
    this.tripId = tripId;
    _sub = Geolocator.getPositionStream(
      locationSettings: const LocationSettings(accuracy: LocationAccuracy.high, distanceFilter: 50),
    ).listen((pos) async {
      try {
        await _api.updateTripLocation(
          tripId: tripId, lat: pos.latitude, lng: pos.longitude,
          speedKmh: pos.speed * 3.6);
      } catch (_) {
        // Ping gaps are expected on 2G — server shows last-known. Keep listening.
      }
    });
    // Immediate first ping so passengers see the bus at once.
    try {
      final pos = await Geolocator.getCurrentPosition().timeout(const Duration(seconds: 15));
      await _api.updateTripLocation(
        tripId: tripId, lat: pos.latitude, lng: pos.longitude, speedKmh: pos.speed * 3.6);
    } catch (_) {}
  }

  Future<void> stop() async {
    await _sub?.cancel();
    _sub = null;
    tripId = null;
  }
}
