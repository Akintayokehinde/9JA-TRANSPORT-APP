import 'package:flutter/material.dart';
import '../../core/network/functions_client.dart';
import '../../widgets/driver_card.dart';
import 'slip_screen.dart';
import '../payments/pay_options_screen.dart';

/// Trip detail: fare + charge + cancel rules + driver (PRD §16, §10, §11).
/// CTAs: Pay Now (Paystack test) or Reserve & Pay at Park.
class TripDetailScreen extends StatefulWidget {
  final String tripId;
  const TripDetailScreen({super.key, required this.tripId});
  @override
  State<TripDetailScreen> createState() => _TripDetailScreenState();
}

class _TripDetailScreenState extends State<TripDetailScreen> {
  final api = FunctionsClient();
  final name = TextEditingController();
  Map? trip;
  bool loading = true;
  bool booking = false;
  String? error;

  static const int bookingChargeKobo = 10000; // ₦100 flat (Phase 0)

  @override
  void initState() { super.initState(); _load(); }

  Future<void> _load() async {
    try {
      final res = await api.tripDetail(widget.tripId);
      setState(() { trip = Map.from(res['trip'] as Map); loading = false; });
    } catch (e) {
      setState(() { error = e.toString(); loading = false; });
    }
  }

  Future<void> _book(String payMode) async {
    if (name.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter passenger name')));
      return;
    }
    setState(() => booking = true);
    try {
      final res = await api.createBooking(
        tripId: widget.tripId, seats: 1, passengerName: name.text.trim(), payMode: payMode);
      if (!mounted) return;
      var finalPayMode = payMode;
      if (payMode == 'pay_now') {
        // Payment options: Paystack / Bank Card / 9JA Wallet.
        final paid = await Navigator.of(context).push(MaterialPageRoute(builder: (_) =>
          PayOptionsScreen(bookingId: res['bookingId'] as String, amountKobo: (trip!['fare_kobo'] as int))));
        if (paid != true && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
            content: Text('Payment pending — slip saved, pay before boarding or choose cash at park')));
        }
      }
      if (!mounted) return;
      Navigator.of(context).push(MaterialPageRoute(builder: (_) => SlipScreen(
        bookingId: res['bookingId'] as String,
        bookingNo: res['bookingNo'] as String,
        tripCode: res['tripCode'] as String,
        qrPayload: Map<String, dynamic>.from(res['qrPayload'] as Map),
        trip: trip ?? {},
        passengerName: name.text.trim(),
        payMode: finalPayMode,
      )));
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Booking failed: $e')));
    } finally {
      setState(() => booking = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (loading) return const Scaffold(body: Center(child: CircularProgressIndicator()));
    if (error != null) return Scaffold(appBar: AppBar(), body: Center(child: Text(error!)));
    final t = trip!;
    final fare = (t['fare_kobo'] as int) / 100;
    final total = ((t['fare_kobo'] as int) + bookingChargeKobo) / 100;
    final left = (t['capacity'] as int) - (t['booked_count'] as int);
    return Scaffold(
      appBar: AppBar(title: Text('${t['from_park']} → ${t['to_park']}')),
      body: ListView(padding: const EdgeInsets.all(16), children: [
        Text('${t['from_park']} → ${t['to_park']}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        Text('${t['departs_at']} · $left spaces left', style: const TextStyle(color: Color(0xFF6B7280))),
        const SizedBox(height: 12),
        DriverCard(name: t['driver_name'] as String?, phone: t['driver_phone'] as String?,
          vehicleType: t['vehicle_type'] as String?, plateNo: t['plate_no'] as String?,
          verified: (t['driver_verified'] as bool?) ?? false,
          rating: (t['driver_rating'] as num?)?.toDouble(), trips: t['trips_completed'] as int?),
        const SizedBox(height: 12),
        Card(child: Padding(padding: const EdgeInsets.all(12), child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Fare'), Text('₦${fare.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800))]),
          const Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            Text('Booking charge'), Text('₦100', style: TextStyle(fontWeight: FontWeight.w800))]),
          const Divider(),
          Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
            const Text('Total', style: TextStyle(fontWeight: FontWeight.w800)),
            Text('₦${total.toStringAsFixed(0)}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18))]),
          const SizedBox(height: 4),
          const Text('Cancel: >6h full refund · 1–6h 50% · <1h no refund · 15-min no-show expiry.',
            style: TextStyle(fontSize: 12, color: Color(0xFF6B7280))),
        ]))),
        const SizedBox(height: 12),
        TextField(controller: name, decoration: const InputDecoration(
          labelText: 'Passenger name', border: OutlineInputBorder())),
        const SizedBox(height: 12),
        ElevatedButton(onPressed: booking ? null : () => _book('pay_now'),
          child: Text(booking ? 'Booking…' : 'Pay Now — ₦${total.toStringAsFixed(0)}')),
        const SizedBox(height: 8),
        OutlinedButton(onPressed: booking ? null : () => _book('reserve'),
          child: const Text('Reserve & Pay at Park')),
      ]),
    );
  }
}
