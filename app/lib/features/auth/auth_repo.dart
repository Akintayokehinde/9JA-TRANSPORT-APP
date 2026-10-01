import 'package:cloud_functions/cloud_functions.dart';
import 'package:firebase_auth/firebase_auth.dart';

/// Auth helper: email/phone/username + password login, full signup + OTP verify.
/// Passwords live only in Firebase Auth; profile in Postgres via Functions.
class AuthRepo {
  final _auth = FirebaseAuth.instance;
  final _f = FirebaseFunctions.instance;

  Future<void> login({required String identifier, required String password}) async {
    final r = await _f.httpsCallable('loginResolve').call({'identifier': identifier.trim()});
    final email = (Map<String, dynamic>.from(r.data as Map))['email'] as String;
    await _auth.signInWithEmailAndPassword(email: email, password: password);
  }

  Future<Map<String, dynamic>> register({
    required String phone, required String email,
    required String firstName, required String lastName, required String username,
    required String password, required String confirmPassword, required String otpChannel,
  }) async {
    final r = await _f.httpsCallable('register').call({
      'phone': phone.trim(), 'email': email.trim(), 'firstName': firstName.trim(),
      'lastName': lastName.trim(), 'username': username.trim(),
      'password': password, 'confirmPassword': confirmPassword, 'otpChannel': otpChannel,
    });
    final out = Map<String, dynamic>.from(r.data as Map);
    // Sign in immediately so OTP verify/resend calls are authenticated.
    await _auth.signInWithEmailAndPassword(email: out['email'] as String, password: password);
    return out;
  }

  Future<void> verifyEmailOtp(String code) async {
    await _f.httpsCallable('verifyEmailOtp').call({'code': code.trim()});
  }

  Future<Map<String, dynamic>> resendOtp() async {
    final r = await _f.httpsCallable('resendOtp').call();
    return Map<String, dynamic>.from(r.data as Map);
  }

  /// SMS path: verify phone via Firebase, LINK to the signed-in email user, confirm server-side.
  Future<void> verifyPhoneAndLink({
    required String phoneNumber,
    required void Function(String msg) onCodeSent,
  }) async {
    await _auth.verifyPhoneNumber(
      phoneNumber: phoneNumber.trim(),
      verificationCompleted: (cred) async {
        await _auth.currentUser?.linkWithCredential(cred);
        await _f.httpsCallable('confirmPhoneLink').call();
      },
      verificationFailed: (e) => throw Exception(e.message ?? 'Phone verification failed'),
      codeSent: (vid, _) => onCodeSent(vid),
      codeAutoRetrievalTimeout: (_) {},
    );
  }

  Future<void> confirmSmsCode({required String verificationId, required String smsCode}) async {
    final cred = PhoneAuthProvider.credential(verificationId: verificationId, smsCode: smsCode.trim());
    await _auth.currentUser?.linkWithCredential(cred);
    await _f.httpsCallable('confirmPhoneLink').call();
  }

  Future<void> signOut() => _auth.signOut();
}
