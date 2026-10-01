import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'auth_repo.dart';

/// Login: Email / Phone Number / Username + Password.
/// Signup: Phone, Email, First/Last name, Username, Password + Confirm → OTP (email or SMS).
class AuthScreen extends StatefulWidget {
  const AuthScreen({super.key});
  @override
  State<AuthScreen> createState() => _AuthScreenState();
}

class _AuthScreenState extends State<AuthScreen> {
  final repo = AuthRepo();
  bool loginMode = true;
  bool busy = false;
  bool showPw = false;
  String? error;

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
  String? pendingChannel;
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('9ja Transport')),
      body: ListView(padding: const EdgeInsets.all(18), children: [
        Row(children: [
          Expanded(child: _tab('Log in', loginMode, () => setState(() { loginMode = true; pendingChannel = null; }))),
          const SizedBox(width: 8),
          Expanded(child: _tab('Sign up', !loginMode, () => setState(() { loginMode = false; pendingChannel = null; }))),
        ]),
        const SizedBox(height: 14),
        if (error != null)
          Container(padding: const EdgeInsets.all(10), margin: const EdgeInsets.only(bottom: 10),
            decoration: BoxDecoration(color: const Color(0xFFFEE4E2), borderRadius: BorderRadius.circular(8)),
            child: Text(error!, style: const TextStyle(color: Color(0xFFD92D20)))),
        if (pendingChannel != null) _otpCard() else if (loginMode) _loginCard() else _signupCard(),
      ]),
    );
  }

  Widget _tab(String t, bool on, VoidCallback tap) => ElevatedButton(
    style: ElevatedButton.styleFrom(backgroundColor: on ? const Color(0xFFFFC300) : const Color(0xFFF3F4F6),
      foregroundColor: Colors.black, elevation: 0),
    onPressed: tap, child: Text(t));

  InputDecoration _dec(String l) => InputDecoration(labelText: l, border: const OutlineInputBorder());

  Widget _loginCard() => Column(children: [
    TextField(controller: liId, keyboardType: TextInputType.emailAddress,
      decoration: _dec('Email or Phone Number or Username')),
    const SizedBox(height: 10),
    TextField(controller: liPw, obscureText: !showPw,
      decoration: _dec('Password').copyWith(
        suffixIcon: IconButton(icon: Icon(showPw ? Icons.visibility_off : Icons.visibility),
          onPressed: () => setState(() => showPw = !showPw)))),
    const SizedBox(height: 12),
    SizedBox(width: double.infinity,
      child: ElevatedButton(onPressed: busy ? null : () => _run(() =>
        repo.login(identifier: liId.text, password: liPw.text)),
        child: Text(busy ? 'Logging in…' : 'Log in'))),
  ]);

  Widget _signupCard() => Column(children: [
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
    const Align(alignment: Alignment.centerLeft, child: Text('Send OTP code to:', style: TextStyle(fontWeight: FontWeight.w700))),
    Row(children: [
      Expanded(child: RadioListTile(value: 'email', groupValue: channel, title: const Text('Email'), onChanged: (v) => setState(() => channel = v!))),
      Expanded(child: RadioListTile(value: 'sms', groupValue: channel, title: const Text('SMS'), onChanged: (v) => setState(() => channel = v!))),
    ]),
    SizedBox(width: double.infinity,
      child: ElevatedButton(onPressed: busy ? null : () => _run(() async {
        if (sPw.text != sPw2.text) throw Exception('Passwords do not match');
        final out = await repo.register(
          phone: sPhone.text, email: sEmail.text, firstName: sFirst.text,
          lastName: sLast.text, username: sUser.text,
          password: sPw.text, confirmPassword: sPw2.text, otpChannel: channel);
        if (channel == 'sms') {
          await repo.verifyPhoneAndLink(
            phoneNumber: sPhone.text.startsWith('+') ? sPhone.text.trim() : '+234${sPhone.text.trim().replaceFirst(RegExp(r'^0'), '')}',
            onCodeSent: (vid) => setState(() { smsVid = vid; pendingChannel = 'sms'; }),
          );
          if (smsVid == null) setState(() => pendingChannel = 'sms'); // auto-verified path
        } else {
          setState(() => pendingChannel = 'email');
          if (out['devCode'] != null && mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(content: Text('Test mode code: ${out['devCode']} (configure SMTP for real email)')));
          }
        }
      }), child: Text(busy ? 'Creating account…' : 'Create account'))),
  ]);

  Widget _otpCard() {
    final isEmail = pendingChannel == 'email';
    return Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
      Text(isEmail ? 'Enter the 6-digit code sent to your email' : 'Enter the 6-digit code sent via SMS',
        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
      const SizedBox(height: 10),
      TextField(controller: otp, keyboardType: TextInputType.number,
        inputFormatters: [FilteringTextInputFormatter.digitsOnly, LengthLimitingTextInputFormatter(6)],
        decoration: _dec('OTP Code')),
      const SizedBox(height: 12),
      SizedBox(width: double.infinity,
        child: ElevatedButton(onPressed: busy ? null : () => _run(() async {
          if (isEmail) {
            await repo.verifyEmailOtp(otp.text);
          } else {
            if (smsVid == null) throw Exception('No verification in progress — resend the code');
            await repo.confirmSmsCode(verificationId: smsVid!, smsCode: otp.text);
          }
          if (mounted) ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Verified — welcome to 9ja Transport!')));
        }), child: Text(busy ? 'Verifying…' : 'Verify'))),
      TextButton(onPressed: (busy || cooldown > 0 || !isEmail) ? null : () => _run(() async {
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
      }), child: Text(cooldown > 0 ? 'Resend in $cooldown s' : 'Resend code (email)')),
      if (!isEmail) const Text('SMS codes come from Firebase — check your messages.',
        style: TextStyle(color: Color(0xFF6B7280), fontSize: 12)),
    ]);
  }
}
