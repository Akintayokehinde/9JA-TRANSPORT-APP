import 'package:flutter/material.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'core/theme/app_theme.dart';
import 'core/firebase/firebase_init.dart';
import 'core/storage/hive_boxes.dart';
import 'core/network/functions_client.dart';
import 'features/auth/auth_screen.dart';
import 'features/search/search_screen.dart';
import 'features/booking/my_bookings_screen.dart';
import 'features/dashboard/dashboard_screen.dart';
import 'features/verify/park_mode_screen.dart';
import 'features/driver/driver_trips_screen.dart';
import 'features/payments/notifications_screen.dart';
import 'features/payments/daily_close_screen.dart';
import 'features/support/support_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Never let init failures white-screen the app: Firebase isn't configured
  // in this test build, so boot into offline demo mode instead of crashing.
  ErrorWidget.builder = (d) => Material(
    child: Center(child: Padding(padding: const EdgeInsets.all(24),
      child: Text('Something went wrong starting the app:\n$d',
        textAlign: TextAlign.center))),
  );
  String? initError;
  try {
    await initFirebase();
  } catch (e) {
    initError = 'Backend not connected: $e';
  }
  try {
    await HiveBoxes.init();
  } catch (e) {
    initError = '${initError ?? ''} Storage unavailable: $e';
  }
  runApp(NineJaApp(initError: initError));
}

class NineJaApp extends StatelessWidget {
  final String? initError;
  const NineJaApp({super.key, this.initError});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '9ja Transport',
      theme: AppTheme.light(),
      home: _Boot(initError: initError),
    );
  }
}

/// Chooses auth-gated home, but survives Firebase being unconfigured:
/// any auth stream error lands on the login screen with an offline notice.
class _Boot extends StatelessWidget {
  final String? initError;
  const _Boot({this.initError});
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Column(children: [
        if (initError != null)
          Container(width: double.infinity, padding: const EdgeInsets.fromLTRB(16, 40, 16, 10),
            color: const Color(0xFF121212),
            child: Text('📴 Demo mode — $initError',
              style: const TextStyle(color: Color(0xFFFFC300), fontSize: 12))),
        Expanded(child: StreamBuilder<User?>(
          stream: _authStream(),
          builder: (_, snap) => snap.data == null ? const AuthScreen() : const HomeShell(),
        )),
      ]),
    );
  }

  Stream<User?> _authStream() {
    try {
      return FirebaseAuth.instance.authStateChanges();
    } catch (_) {
      return Stream.value(null);
    }
  }
}

/// Bottom tabs: Book, Bookings, Dashboard (profile/wallet/history/support), Park, Driver, More.
class HomeShell extends StatefulWidget {
  const HomeShell({super.key});
  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int idx = 0;
  static const screens = [SearchScreen(), MyBookingsScreen(), DashboardScreen(), ParkModeScreen(), DriverTripsScreen(), _MoreScreen()];

  @override
  void initState() {
    super.initState();
    // Phase 8: register FCM token for the 4 critical pushes.
    FirebaseMessaging.instance.getToken().then((t) {
      if (t != null) FunctionsClient().saveFcmToken(t).catchError((_) {});
    });
  }
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(index: idx, children: screens),
      bottomNavigationBar: BottomNavigationBar(
        currentIndex: idx,
        type: BottomNavigationBarType.fixed,
        selectedFontSize: 11, unselectedFontSize: 11,
        onTap: (i) => setState(() => idx = i),
        items: const [
          BottomNavigationBarItem(icon: Icon(Icons.search), label: 'Book'),
          BottomNavigationBarItem(icon: Icon(Icons.confirmation_number), label: 'History'),
          BottomNavigationBarItem(icon: Icon(Icons.account_balance_wallet), label: 'Wallet'),
          BottomNavigationBarItem(icon: Icon(Icons.qr_code_scanner), label: 'Park'),
          BottomNavigationBarItem(icon: Icon(Icons.directions_bus), label: 'Driver'),
          BottomNavigationBarItem(icon: Icon(Icons.more_horiz), label: 'More'),
        ],
      ),
    );
  }
}

class _MoreScreen extends StatelessWidget {
  const _MoreScreen();
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More')),
      body: ListView(children: [
        ListTile(title: const Text('Notifications'), onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const NotificationsScreen()))),
        ListTile(title: const Text('Daily close (workers)'), onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const DailyCloseScreen()))),
        ListTile(title: const Text('Safety & Support'), onTap: () =>
          Navigator.of(context).push(MaterialPageRoute(builder: (_) => const SupportScreen()))),
        ListTile(title: const Text('Sign out'), onTap: () => FirebaseAuth.instance.signOut()),
      ]),
    );
  }
}
