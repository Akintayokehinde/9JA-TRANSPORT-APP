import 'package:hive_flutter/hive_flutter.dart';

class HiveBoxes {
  static const slips = 'slips'; // bookingId -> slip JSON (offline view, PRD §9)
  static const tripsCache = 'trips_cache'; // search results cache
  static const scanQueue = 'scan_queue'; // offline verify queue (Phase 6)
  static const outbox = 'outbox'; // pending writes

  static Future<void> init() async {
    await Hive.initFlutter();
    await Future.wait([
      Hive.openBox(slips),
      Hive.openBox(tripsCache),
      Hive.openBox(scanQueue),
      Hive.openBox(outbox),
    ]);
  }
}
