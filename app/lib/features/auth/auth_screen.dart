import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_repo.dart';

/// Separate Login and Signup screens (never shown together).
/// Signup detects an already-registered email first and sends the user to Login.
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

enum _Mode { login, signup, otp }

class _AuthScreenState extends State<AuthScreen> {
  final repo = AuthRepo();
  _Mode mode = _Mode.login;
  bool busy = false;
  bool showPw = false;
  String? error;
  String? notice;

  // login
  final liId = TextEditingController();
  final liPw = TextEditingController();
  // signup
  final sPhone = TextEditingController();
  final sEmail = TextEditingController();
  final sFirst = TextEditingController();
  final sLast = TextEditingController();
  final sUser = TextEditingController();
  final sPw = TextEditingController();
  final sPw2 = TextEditingController();
  String channel = 'email';
  // otp
  bool otpIsEmail = true;
  String? smsVid;
  final otp = TextEditingController();
  int cooldown = 0;

  Future<void> _run(Future<void> Function() fn) async {
    setState(() { busy = true; error = null; });
    try {
      await fn();
    } catch (e) {
      setState(() => error = e.toString().replaceFirst('Exception: ', '').replaceAll(RegExp(r'\[.*?\] '), ''));
    } finally {
      if (mounted) setState(() => busy = false);
    }
  }

  void _toLogin({String? prefill, String? msg}) {
    liId.text = prefill ?? liId.text;
    setState(() { mode = _Mode.login; notice = msg; error = null; });
  }

  Future<void> _submitSignup() async {
    if (sPw.text != sPw2.text) {
      setState(() => error = 'Passwords do not match');
      return;
    }
    _run(() async {
      // Old user? A registered email goes straight to Login — never registers twice.
      final email = sEmail.text.trim();
      try {
        await repo.resolveEmail(email);
        _toLogin(prefill: email, msg: 'This email is already registered — please log in.');
        return;
      } catch (_) {
        // not found → continue with signup
      }
      late Map<String, dynamic> out;
      try {
        out = await repo.register(
          phone: sPhone.text, email: email, firstName: sFirst.text,
          lastName: sLast.text, username: sUser.text,
          password: sPw.text, confirmPassword: sPw2.text, otpChannel: channel);
      } catch (e) {
        // Race: account created between check and submit.
        if (e.toString().contains('Email already registered')) {
          _toLogin(prefill: email, msg: 'This email is already registered — please log in.');
          return;
        }
        rethrow;
      }
      otpIsEmail = channel == 'email';
      if (!otpIsEmail) {
        await repo.verifyPhoneAndLink(
          phoneNumber: sPhone.text.startsWith('+')
              ? sPhone.text.trim()
              : '+234${sPhone.text.trim().replaceFirst(RegExp(r'^0'), '')}',
          onCodeSent: (vid) => setState(() => smsVid = vid),
        );
      }
      setState(() => mode = _Mode.otp);
      if (otpIsEmail && out['devCode'] != null && mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Test mode code: ${out['devCode']} (configure SMTP for real email)')));
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('9ja Transport')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        if (notice != null)
          Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: const Color(0xFFE0EAFF), borderRadius: BorderRadius.circular(8)),
            child: Text(notice!, style: const TextStyle(color: Color(0xFF175CD3)))),
        if (error != null)
          Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: const Color(0xFFFEE4E2), borderRadius: BorderRadius.circular(8)),
            child: Text(error!, style: const TextStyle(color: Color(0xFFD92D20)))),
        if (mode == _Mode.login) _loginCard()
        else if (mode == _Mode.signup) _signupCard()
        else _otpCard(),
      ]),
    );
  }

  InputDecoration _dec(String l) => InputDecoration(labelText: l, border: const OutlineInputBorder());

  // ---------------- LOGIN (standalone) ----------------
  Widget _loginCard() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('Welcome back', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
    const SizedBox(height: 4),
    const Text('Log in with your email, phone number or username.', style: TextStyle(color: Color(0xFF6B7280))),
    const SizedBox(height: 14),
    TextField(controller: liId, keyboardType: TextInputType.emailAddress,
      decoration: _dec('Email or Phone Number or Username')),
    const SizedBox(height: 10),
    TextField(controller: liPw, obscureText: !showPw,
      decoration: _dec('Password').copyWith(
        suffixIcon: IconButton(icon: Icon(showPw ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => showPw = !showPw)))),
    const SizedBox(height: 12),
    ElevatedButton(onPressed: busy ? null : () => _run(() =>
      repo.login(identifier: liId.text, password: liPw.text)),
      child: Text(busy ? 'Logging in…' : 'Log in')),
    TextButton(
      onPressed: () => setState(() { mode = _Mode.signup; error = null; notice = null; }),
      child: const Text("New here? Create an account")),
  ]);

  // ---------------- SIGNUP (standalone) ----------------
  Widget _signupCard() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    const Text('Create your account', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
    const SizedBox(height: 4),
    const Text('Takes a minute — then we verify you with a code.', style: TextStyle(color: Color(0xFF6B7280))),
    const SizedBox(height: 14),
    Row(children: [
      Expanded(child: TextField(controller: sFirst, textCapitalization: TextCapitalization.words, decoration: _dec('First Name'))),
      const SizedBox(width: 8),
      Expanded(child: TextField(controller: sLast, textCapitalization: TextCapitalization.words, decoration: _dec('Last Name'))),
    ]),
    const SizedBox(height: 10),
    TextField(controller: sUser, decoration: _dec('Username (3–20 letters/numbers)')),
    const SizedBox(height: 10),
    TextField(controller: sPhone, keyboardType: TextInputType.phone, decoration: _dec('Phone No e.g. 0803…')),
    const SizedBox(height: 10),
    TextField(controller: sEmail, keyboardType: TextInputType.emailAddress, decoration: _dec('Email Address')),
    const SizedBox(height: 10),
    TextField(controller: sPw, obscureText: !showPw, decoration: _dec('Password (8+ characters)').copyWith(
      suffixIcon: IconButton(icon: Icon(showPw ? Icons.visibility_off : Icons.visibility),
        onPressed: () => setState(() => showPw = !showPw)))),
    const SizedBox(height: 10),
    TextField(controller: sPw2, obscureText: true, decoration: _dec('Confirm Password')),
    const SizedBox(height: 10),
    const Text('Send OTP code to:', style: TextStyle(fontWeight: FontWeight.w700)),
    Row(children: [
      Expanded(child: RadioListTile(value: 'email', groupValue: channel, title: const Text('Email'), onChanged: (v) => setState(() => channel = v!))),
      Expanded(child: RadioListTile(value: 'sms', groupValue: channel, title: const Text('SMS'), onChanged: (v) => setState(() => channel = v!))),
    ]),
    ElevatedButton(onPressed: busy ? null : _submitSignup,
      child: Text(busy ? 'Creating account…' : 'Create account')),
    TextButton(
      onPressed: () => setState(() { mode = _Mode.login; error = null; notice = null; }),
      child: const Text('Already registered? Log in')),
  ]);

  // ---------------- OTP (standalone, after signup) ----------------
  Widget _otpCard() => Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
    Text(otpIsEmail ? 'Check your email' : 'Check your SMS',
      style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
    const SizedBox(height: 4),
    Text(otpIsEmail
      ? 'Enter the 6-digit code sent to your email address.'
      : 'Enter the 6-digit code sent to your phone.',
      style: const TextStyle(color: Color(0xFF6B7280))),
    const SizedBox(height: 14),
    TextField(controller: otp, keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
      decoration: _dec('OTP Code')),
    const SizedBox(height: 12),
    ElevatedButton(onPressed: busy ? null : () => _run(() async {
      if (otpIsEmail) {
        await repo.verifyEmailOtp(otp.text);
      } else {
        if (smsVid == null) throw Exception('No verification in progress — go back and sign up again');
        await repo.confirmSmsCode(verificationId: smsVid!, smsCode: otp.text);
      }
      if (mounted) ScaffoldMessenger.of(context)
        .showSnackBar(const SnackBar(content: Text('Verified — welcome to 9ja Transport!')));
    }), child: Text(busy ? 'Verifying…' : 'Verify')),
    if (otpIsEmail)
      TextButton(onPressed: (busy || cooldown > 0) ? null : () => _run(() async {
        final out = await repo.resendOtp();
        if (out['devCode'] != null && mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Test mode code: ${out['devCode']}')));
        }
        setState(() => cooldown = 30);
        while (cooldown > 0 && mounted) {
          await Future.delayed(const Duration(seconds: 1));
          if (mounted) setState(() => cooldown--);
        }
      }), child: Text(cooldown > 0 ? 'Resend in $cooldown s' : 'Resend code')),
    if (!otpIsEmail) const Text('SMS codes come from Firebase — check your messages.',
      style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
  ]);
}
