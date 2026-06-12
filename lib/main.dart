import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:onesignal_flutter/onesignal_flutter.dart';
import 'config/theme.dart';
import 'config/constants.dart';
import 'providers/auth_provider.dart';
import 'screens/splash_screen.dart';

void main() async {
  print("APP START: main() starting...");
  WidgetsFlutterBinding.ensureInitialized();
  print("APP START: WidgetsFlutterBinding initialized");

  // Initialize OneSignal
  try {
    OneSignal.Debug.setLogLevel(OSLogLevel.verbose);
    OneSignal.initialize(AppConstants.oneSignalAppId);
    OneSignal.Notifications.requestPermission(true);
    print("APP START: OneSignal initialized");
  } catch (e) {
    print("APP START: OneSignal initialization error: $e");
  }

  SystemChrome.setSystemUIOverlayStyle(const SystemUiOverlayStyle(
    statusBarColor: Colors.transparent,
    statusBarIconBrightness: Brightness.light,
    systemNavigationBarColor: Color(0xFF0C0A10),
    systemNavigationBarIconBrightness: Brightness.light,
  ));

  SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  runApp(
    ChangeNotifierProvider(
      create: (_) => AuthProvider(),
      child: const KiraClubsApp(),
    ),
  );
  print("APP START: runApp completed");
}

class KiraClubsApp extends StatelessWidget {
  const KiraClubsApp({Key? key}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'KiraClubs',
      theme: AppTheme.darkTheme,
      debugShowCheckedModeBanner: false,
      home: const SplashScreen(),
    );
  }
}
