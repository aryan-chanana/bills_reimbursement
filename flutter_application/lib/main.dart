import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/user_dashboard.dart';
import 'screens/admin_dashboard.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';

void main() async {
  WidgetsBinding widgetsBinding = WidgetsFlutterBinding.ensureInitialized();
  FlutterNativeSplash.preserve(widgetsBinding: widgetsBinding);

  String initialRoute = '/login';
  try {
    SharedPreferences prefs = await SharedPreferences.getInstance();
    int? employeeId = prefs.getInt('employee_id');
    bool? isAdmin = prefs.getBool('is_admin');

    if (employeeId != null) {
      initialRoute = (isAdmin == true) ? '/admin_dashboard' : '/user_dashboard';
    }
  } catch (e) {
    print('Error checking login status in main: $e');
    initialRoute = '/login';
  }

  runApp(MyApp(initialRoute: initialRoute));
  // await Future.delayed(const Duration(milliseconds: 500));
  // FlutterNativeSplash.remove();
}

class MyApp extends StatelessWidget {
  final String initialRoute;
  const MyApp({super.key, required this.initialRoute});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bills Reimbursement',
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