import 'package:bills_reimbursement/services/api_service.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/user_model.dart';
import '../services/ConnectivityService.dart';

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
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFe3f2fd), Color(0xFFbbdefb)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: SafeArea(
          child: Center(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 300),
                curve: Curves.easeOut,
                padding: const EdgeInsets.all(32),
                decoration: BoxDecoration(
                  color: Colors.white.withOpacity(0.95),
                  borderRadius: BorderRadius.circular(20),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black12.withOpacity(0.08),
                      blurRadius: 20,
                      offset: const Offset(0, 8),
                    ),
                  ],
                ),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [

                      // Animated Icon
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 300),
                        child: Icon(
                          _isSignUp ? Icons.person_add_alt_1 : Icons.login,
                          key: ValueKey(_isSignUp),
                          size: 90,
                          color: Colors.blueAccent,
                        ),
                      ),

                      const SizedBox(height: 16),

                      // Title
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          _isSignUp ? "Create Account" : "Welcome",
                          key: ValueKey(_isSignUp),
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            color: Colors.black87,
                          ),
                        ),
                      ),

                      const SizedBox(height: 4),
                      Text(
                        _isSignUp
                            ? "Fill details to get started"
                            : "Login to continue",
                        style: TextStyle(
                          fontSize: 14,
                          color: Colors.grey.shade600,
                        ),
                      ),

                      const SizedBox(height: 32),

                      // Employee ID
                      TextFormField(
                        controller: _employeeIdController,
                        keyboardType: TextInputType.number,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: "Employee ID",
                          prefixIcon: const Icon(Icons.badge_outlined),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) =>
                        v == null || v.isEmpty ? "Required field" : null,
                      ),

                      const SizedBox(height: 16),

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: true,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: "Password",
                          prefixIcon: const Icon(Icons.lock_outline),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) =>
                        v == null || v.isEmpty ? "Required field" : null,
                      ),

                      if (_isSignUp) const SizedBox(height: 16),

                      // Full Name (only signup)
                      if (_isSignUp)
                        TextFormField(
                          controller: _nameController,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            labelText: "Full Name",
                            prefixIcon: const Icon(Icons.person_outline),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            if (_isSignUp && (v == null || v.isEmpty)) {
                              return "Enter your name";
                            }
                            return null;
                          },
                        ),

                      const SizedBox(height: 28),

                      // Submit Button
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: ElevatedButton(
                          onPressed: _isLoading ? null : _handleSubmit,
                          style: ElevatedButton.styleFrom(
                            foregroundColor: Colors.white,
                            backgroundColor: Colors.blueAccent,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            elevation: 4,
                          ),
                          child: _isLoading
                              ? const CircularProgressIndicator(
                              color: Colors.white)
                              : Text(
                            _isSignUp ? "Sign Up" : "Login",
                            style: const TextStyle(fontSize: 17),
                          ),
                        ),
                      ),

                      const SizedBox(height: 18),

                      // Switch Login/Signup
                      TextButton(
                        onPressed: () {
                          setState(() {
                            _isSignUp = !_isSignUp;
                            _nameController.clear();
                          });
                        },
                        child: Text(
                          _isSignUp
                              ? "Already have an account? Login"
                              : "Don't have an account? Sign Up",
                          style: const TextStyle(
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            color: Colors.blueAccent,
                          ),
                        ),
                      ),

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

      final bool backendAvailable = await ConnectivityService.isBackendAvailable();
      if (!backendAvailable) {
        _showErrorDialog("\nUnable to connect to server.\nPlease try again later.");
      }
      else {
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
    }
    catch (e) {
      print("LOGIN / SIGNUP ERROR = $e");
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Error: ${e.toString()}'), backgroundColor: Colors.red));
      }
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