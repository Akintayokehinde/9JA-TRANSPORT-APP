import 'package:cloud_functions/cloud_functions.dart';

/// Thin wrapper over callable Functions (Postgres backend). App never touches SQL.
class FunctionsClient {
  final _f = FirebaseFunctions.instance;

  Future<Map<String, dynamic>> searchTrips({required String fromParkId, required String toParkId, required DateTime date, int seats = 1}) async {
    final r = await _f.httpsCallable('searchTrips').call({
      'fromParkId': fromParkId, 'toParkId': toParkId,
      'date': date.toIso8601String(), 'seats': seats,
    });
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> tripDetail(String tripId) async {
    final r = await _f.httpsCallable('tripDetail').call({'tripId': tripId});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> createBooking({required String tripId, required int seats, required String passengerName, required String payMode}) async {
    final r = await _f.httpsCallable('createBooking').call(
        {'tripId': tripId, 'seats': seats, 'passengerName': passengerName, 'payMode': payMode});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> myBookings() async {
    final r = await _f.httpsCallable('myBookings').call();
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> cancelBooking(String bookingId) async {
    final r = await _f.httpsCallable('cancelBooking').call({'bookingId': bookingId});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> verifyPaystack({required String reference, required String bookingId}) async {
    final r = await _f.httpsCallable('verifyPaystack').call({'reference': reference, 'bookingId': bookingId});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> flutterwaveInit({required String bookingId, String? email}) async {
    final r = await _f.httpsCallable('flutterwaveInit').call({'bookingId': bookingId, 'email': email});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> verifyFlutterwave({required String transactionId, required String bookingId}) async {
    final r = await _f.httpsCallable('verifyFlutterwave').call(
        {'transactionId': transactionId, 'bookingId': bookingId});
    return Map<String, dynamic>.from(r.data as Map);
  }

  // Phase 6
  Future<Map<String, dynamic>> parkTrips() async {
    final r = await _f.httpsCallable('parkTrips').call();
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> tripBookings(String tripId) async {
    final r = await _f.httpsCallable('tripBookings').call({'tripId': tripId});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> verifyScan({String? bid, String? tid, String? nonce, String? code, bool offline = false}) async {
    final r = await _f.httpsCallable('verifyScan').call(
        {'bid': bid, 'tid': tid, 'nonce': nonce, 'code': code, 'offline': offline});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> markTripStatus(String tripId, String to) async {
    final r = await _f.httpsCallable('markTripStatus').call({'tripId': tripId, 'to': to});
    return Map<String, dynamic>.from(r.data as Map);
  }

  // Phase 7
  Future<Map<String, dynamic>> driverTrips() async {
    final r = await _f.httpsCallable('driverTrips').call();
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> driverEarnings() async {
    final r = await _f.httpsCallable('driverEarnings').call();
    return Map<String, dynamic>.from(r.data as Map);
  }

  // Phase 8
  Future<Map<String, dynamic>> paystackInit({required String bookingId, String? email}) async {
    final r = await _f.httpsCallable('paystackInit').call({'bookingId': bookingId, 'email': email});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> paystackInitCard({required String bookingId, String? email}) async {
    final r = await _f.httpsCallable('paystackInit')
        .call({'bookingId': bookingId, 'email': email, 'channel': 'card'});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> topupInit({required int amountKobo, String? email}) async {
    final r = await _f.httpsCallable('paystackInit')
        .call({'purpose': 'topup', 'amountKobo': amountKobo, 'email': email});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> myProfile() async {
    final r = await _f.httpsCallable('myProfile').call();
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<int> walletBalance() async {
    final r = await _f.httpsCallable('walletBalance').call();
    return int.parse((Map<String, dynamic>.from(r.data as Map))['balanceKobo'].toString());
  }

  Future<List> walletHistory() async {
    final r = await _f.httpsCallable('walletHistory').call();
    return List.from((Map<String, dynamic>.from(r.data as Map))['transactions'] ?? []);
  }

  Future<Map<String, dynamic>> payWithWallet(String bookingId) async {
    final r = await _f.httpsCallable('payWithWallet').call({'bookingId': bookingId});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> cardAttempt({required String bookingId, required String last4}) async {
    final r = await _f.httpsCallable('cardAttempt').call({'bookingId': bookingId, 'last4': last4});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<void> confirmCardPayment(String bookingId) async {
    await _f.httpsCallable('confirmCardPayment').call({'bookingId': bookingId});
  }

  Future<void> saveFcmToken(String token) async {
    await _f.httpsCallable('saveFcmToken').call({'token': token});
  }

  Future<Map<String, dynamic>> dailyClose() async {
    final r = await _f.httpsCallable('dailyClose').call();
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> markCashReceived(String bookingId) async {
    final r = await _f.httpsCallable('markCashReceived').call({'bookingId': bookingId});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> myNotifications() async {
    final r = await _f.httpsCallable('myNotifications').call();
    return Map<String, dynamic>.from(r.data as Map);
  }

  // Phase 12 — live tracking
  Future<Map<String, dynamic>> updateTripLocation(
      {required String tripId, required double lat, required double lng, double? speedKmh}) async {
    final r = await _f.httpsCallable('updateTripLocation').call(
        {'tripId': tripId, 'lat': lat, 'lng': lng, 'speedKmh': speedKmh});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> getTripLocation(String tripId) async {
    final r = await _f.httpsCallable('getTripLocation').call({'tripId': tripId});
    return Map<String, dynamic>.from(r.data as Map);
  }

  // Phase 9
  Future<Map<String, dynamic>> createComplaint({String? bookingId, required String category, required String message}) async {
    final r = await _f.httpsCallable('createComplaint').call(
        {'bookingId': bookingId, 'category': category, 'message': message});
    return Map<String, dynamic>.from(r.data as Map);
  }

  Future<Map<String, dynamic>> createRating({required String tripId, required String bookingId, required int score, String? comment}) async {
    final r = await _f.httpsCallable('createRating').call(
        {'tripId': tripId, 'bookingId': bookingId, 'score': score, 'comment': comment});
    return Map<String, dynamic>.from(r.data as Map);
  }
}
