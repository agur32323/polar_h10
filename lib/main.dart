import 'package:flutter/material.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';
import 'package:uyg/screens/PersonalCareScreen.dart';
import 'package:vibration/vibration.dart';
import 'package:flutter_localizations/flutter_localizations.dart';

import 'package:uyg/managers/bluetooth_manager.dart';
import 'package:uyg/screens/heart_provider.dart';
import 'package:uyg/screens/home_screen.dart';
import 'package:uyg/screens/login_screen.dart';
import 'package:uyg/screens/notification_service.dart';
import 'package:uyg/screens/register_screen.dart';
import 'package:uyg/screens/scan_screen.dart';
import 'package:uyg/screens/statistics_screen.dart';
import 'package:uyg/screens/PersonalCareScreen.dart'; // 📌 Kişisel Bakımım ekranı

import 'package:uyg/services/db_service.dart';

final FlutterLocalNotificationsPlugin flutterLocalNotificationsPlugin =
    FlutterLocalNotificationsPlugin();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  const androidSettings = AndroidInitializationSettings('@mipmap/ic_launcher');
  const iosSettings = DarwinInitializationSettings();
  const initSettings = InitializationSettings(
    android: androidSettings,
    iOS: iosSettings,
  );
  await flutterLocalNotificationsPlugin.initialize(initSettings);

  await initializeDateFormatting('tr_TR', null);

  final db = await DBService.getDatabase();
  print("📂 Database Path: ${db.path}");

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => HeartProvider()),
        ChangeNotifierProvider(create: (_) => BluetoothManager()),
      ],
      child: MyApp(),
    ),
  );
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kalp Uygulaması',
      debugShowCheckedModeBanner: false,
      localizationsDelegates: [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      supportedLocales: [const Locale('tr', 'TR'), const Locale('en', 'US')],
      initialRoute: '/',
      routes: {
        '/': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/home': (context) => const HomeScreen(),
        '/scan': (context) => const ScanScreen(),
        '/stats': (context) => StatisticsScreen(),
        '/personalCare': (context) => PersonalCareScreen(),
      },
    );
  }
}
