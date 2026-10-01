import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:hive_flutter/hive_flutter.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/storage/hive_boxes.dart';

/// Digital transport slip — saved to Hive, viewable offline (PRD §7, §9).
class SlipScreen extends StatefulWidget {
  final String bookingId;
  final String bookingNo;
  final String tripCode;
  final Map<String, dynamic> qrPayload;
  final Map trip;
  final String passengerName;
  final String payMode;
  const SlipScreen({super.key, required this.bookingId, required this.bookingNo,
    required this.tripCode, required this.qrPayload, required this.trip,
    required this.passengerName, required this.payMode});

  @override
  State<SlipScreen> createState() => _SlipScreenState();
}

class _SlipScreenState extends State<SlipScreen> {
  @override
  void initState() {
    super.initState();
    Hive.box(HiveBoxes.slips).put(widget.bookingId, {
      'bookingId': widget.bookingId, 'bookingNo': widget.bookingNo,
      'tripCode': widget.tripCode, 'qrPayload': widget.qrPayload,
      'trip': widget.trip, 'passengerName': widget.passengerName,
      'payMode': widget.payMode, 'savedAt': DateTime.now().toIso8601String(),
    });
    // Phase 8: subscribe to trip topic for delay/cancel/refund pushes.
    final tid = widget.qrPayload['tid']?.toString();
    if (tid != null) FirebaseMessaging.instance.subscribeToTopic('trip_$tid').catchError((_) {});
  }

  @override
  Widget build(BuildContext context) {
    final t = widget.trip;
    final paid = widget.payMode == 'pay_now';
    return Scaffold(
      appBar: AppBar(title: const Text('Transport Slip')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(color: const Color(0xFFFFF8E1),
            borderRadius: BorderRadius.circular(16), border: Border.all(style: BorderStyle.solid, width: 2)),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            const Text('🎫 Digital Transport Slip', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
            const SizedBox(height: 8),
            _row('Passenger', widget.passengerName),
            _row('Booking', widget.bookingNo),
            _row('Route', '${t['from_park'] ?? ''} → ${t['to_park'] ?? ''}'),
            _row('Departure', '${t['departs_at'] ?? ''}'),
            _row('Fare', paid ? '₦ — paid online (verify)' : '₦ — pay cash at park'),
            _row('Driver', '${t['driver_name'] ?? 'TBD'} · ${t['driver_phone'] ?? ''}'),
            _row('Vehicle', '${t['vehicle_type'] ?? ''} · ${t['plate_no'] ?? ''}'),
            const SizedBox(height: 12),
            Center(child: QrImageView(data: jsonEncode(widget.qrPayload), version: QrVersions.auto, size: 160)),
            const SizedBox(height: 8),
            Center(child: Text('TRIP CODE: ${widget.tripCode}',
              style: const TextStyle(fontWeight: FontWeight.w800, letterSpacing: 2))),
            const Center(child: Text('Saved offline · shows without internet',
              style: TextStyle(fontSize: 12, color: Color(0xFF6B7280)))),
          ]),
        ),
        const SizedBox(height: 12),
        const Text('Show this at the park. Worker scans → VALID → board any free seat.',
          style: TextStyle(color: Color(0xFF6B7280))),
      ]),
    );
  }

  Widget _row(String k, String v) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 2),
    child: Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
      Text(k, style: const TextStyle(color: Color(0xFF6B7280))),
      Flexible(child: Text(v, style: const TextStyle(fontWeight: FontWeight.w700), textAlign: TextAlign.right)),
    ]),
  );
}
