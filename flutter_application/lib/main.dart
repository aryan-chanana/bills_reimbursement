import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:firebase_core/firebase_core.dart';
import 'screens/login_screen.dart';
import 'screens/user_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'services/notification_service.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  await SystemChrome.setPreferredOrientations([
    DeviceOrientation.portraitUp,
    DeviceOrientation.portraitDown,
  ]);

  try {
    await Firebase.initializeApp();
    await NotificationService.initialize();
  } catch (_) {}

  String initialRoute = '/login';
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? employeeId = prefs.getInt('employee_id');
    bool? isAdmin = prefs.getBool('is_admin');

    if (employeeId != null) {
      initialRoute = (isAdmin == true) ? '/admin_dashboard' : '/user_dashboard';
    }
  } catch (e) {
    initialRoute = '/login';
  }

  runApp(MyApp(initialRoute: initialRoute));
  await Future.delayed(const Duration(milliseconds: 500));
  FlutterNativeSplash.remove();
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'ExpenZ',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      debugShowCheckedModeBanner: false,

      initialRoute: initialRoute,

      routes: {
        '/login': (context) => const LoginScreen(),
        '/user_dashboard': (context) => const UserDashboard(),
        '/admin_dashboard': (context) => const AdminDashboard(),
      },
    );
  }
}