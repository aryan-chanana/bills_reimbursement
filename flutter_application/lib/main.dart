import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/login_screen.dart';
import 'screens/user_dashboard.dart';
import 'screens/admin_dashboard.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Bills Reimbursement',
      theme: ThemeData(
        primarySwatch: Colors.blue,
        visualDensity: VisualDensity.adaptivePlatformDensity,
      ),
      home: const SplashScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/user_dashboard': (context) => const UserDashboard(),
        '/admin_dashboard': (context) => const AdminDashboard(),
      },
    );
  }
}

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkLoginStatus();
  }

  // --- THIS METHOD IS NOW PROTECTED WITH A TRY-CATCH BLOCK ---
  Future<void> _checkLoginStatus() async {
    // We add a try-catch block to handle any potential errors during startup
    try {
      // Your existing logic goes inside the 'try' block
      await Future.delayed(const Duration(seconds: 2));

      // Use 'if (mounted)' to ensure the widget is still in the tree
      if (!mounted) return;

      SharedPreferences prefs = await SharedPreferences.getInstance();
      int? employeeId = prefs.getInt('employee_id');
      bool? isAdmin = prefs.getBool('is_admin');

      if (employeeId != null) {
        if (isAdmin == true) {
          Navigator.pushReplacementNamed(context, '/admin_dashboard');
        } else {
          Navigator.pushReplacementNamed(context, '/user_dashboard');
        }
      } else {
        Navigator.pushReplacementNamed(context, '/login');
      }
    } catch (e) {
      // If any error occurs (e.g., cannot read preferences),
      // we print the error and safely navigate to the login screen.
      print('Error checking login status: $e');
      if (mounted) {
        Navigator.pushReplacementNamed(context, '/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.blue,
      body: const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              Icons.receipt_long,
              size: 100,
              color: Colors.white,
            ),
            SizedBox(height: 20),
            Text(
              'Bills Reimbursement',
              style: TextStyle(
                fontSize: 28,
                fontWeight: FontWeight.bold,
                color: Colors.white,
              ),
            ),
            SizedBox(height: 20),
            CircularProgressIndicator(color: Colors.white),
          ],
        ),
      ),
    );
  }
}