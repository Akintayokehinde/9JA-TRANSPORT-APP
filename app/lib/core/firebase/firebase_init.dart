import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_app_check/firebase_app_check.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../../firebase_options.dart';

Future<void> initFirebase() async {
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  await FirebaseAppCheck.instance.activate(androidProvider: AndroidProvider.playIntegrity);
  FirebaseMessaging.onBackgroundMessage(_bgHandler);
  await FirebaseMessaging.instance.requestPermission();
}

@pragma('vm:entry-point')
Future<void> _bgHandler(RemoteMessage m) async {}
