import 'package:bills_reimbursement/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;
  bool _isSignUp = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Card(
              elevation: 8,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
              child: Padding(
                padding: const EdgeInsets.all(32.0),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(
                        Icons.receipt_long,
                        size: 80,
                        color: Colors.blue,
                      ),
                      const SizedBox(height: 24),
                      Text(
                        _isSignUp ? 'Sign Up' : 'Login',
                        style: const TextStyle(
                          fontSize: 28,
                          fontWeight: FontWeight.bold,
                          color: Colors.blue,
                        ),
                      ),
                      const SizedBox(height: 32),
                      TextFormField(
                        controller: _employeeIdController,
                        decoration: const InputDecoration(
                          labelText: 'Employee ID',
                          prefixIcon: Icon(Icons.badge),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your employee ID';
                          }
                          return null;
                        },
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true, // This hides the text (for passwords)
                        decoration: const InputDecoration(
                          labelText: 'Password',
                          prefixIcon: Icon(Icons.lock),
                          border: OutlineInputBorder(),
                        ),
                        validator: (value) {
                          if (value == null || value.isEmpty) {
                            return 'Please enter your password';
                          }
                          return null;
                        },
                      ),
                      if (_isSignUp)
                        TextFormField(
                          controller: _nameController,
                          decoration: const InputDecoration(
                            labelText: 'Full Name',
                            prefixIcon: Icon(Icons.person),
                            border: OutlineInputBorder(),
                          ),
                          validator: (value) {
                            if (_isSignUp && (value == null || value.isEmpty)) {
                              return 'Please enter your full name';
                            }
                            return null;
                          },
                        ),
                      if (_isSignUp) const SizedBox(height: 24),
                      if (!_isSignUp) const SizedBox(height: 24),
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(8),
                            ),
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(color: Colors.white)
                              : Text(
                            _isSignUp ? 'Sign Up' : 'Login',
                            style: const TextStyle(fontSize: 16),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isSignUp = !_isSignUp;
                            _nameController.clear();
                          });
                        },
                        child: Text(
                          _isSignUp
                              ? 'Already have an account? Login'
                              : 'Don\'t have an account? Sign Up',
                        ),
                      ),
                      const SizedBox(height: 16),
                      const Divider(),
                      const SizedBox(height: 8),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _handleSubmit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _isLoading = true;
    });

    try {
      final employeeId = _employeeIdController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();

      if (_isSignUp) {
        bool success = await ApiService.signUp(employeeId, name, password);
        if (success) {
          final user = await ApiService.login(employeeId, password);
          if (user != null) {
            await _saveUserSession(user, password);
            _navigateToUserDashboard();
          } else {
            _showErrorDialog('Sign-up succeeded but auto-login failed.');
          }
        } else {
          _showErrorDialog('Sign-up failed. Employee ID already exist.');
        }

      }
      else {
        final user = await ApiService.login(employeeId, password);
        if (user == null) {
          _showErrorDialog('Invalid Employee ID or Password');
          return;
        }

        await _saveUserSession(user, password);

        if (user.isAdmin) {
          _navigateToAdminDashboard();
        } else {
          _navigateToUserDashboard();
        }
      }
    }
    catch (e) {
      _showErrorDialog('An error occurred. Please check your connection.');
    } finally {
      setState(() {
        _isLoading = false;
      });
    }
  }

  Future<void> _saveUserSession(User user, String password) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt('employee_id', user.employeeId);
    await prefs.setString('name', user.name);
    await prefs.setBool('is_admin', user.isAdmin);
    await prefs.setString('password', password);
  }

  void _navigateToUserDashboard() {
    Navigator.pushReplacementNamed(context, '/user_dashboard');
  }

  void _navigateToAdminDashboard() {
    Navigator.pushReplacementNamed(context, '/admin_dashboard');
  }

  void _showErrorDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _employeeIdController.dispose();
    _nameController.dispose();
    super.dispose();
  }
}