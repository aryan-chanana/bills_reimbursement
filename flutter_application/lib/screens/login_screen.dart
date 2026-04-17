import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
// Adjust these imports based on your actual project structure
import '../models/user_model.dart';
import '../services/api_service.dart';
import '../services/connectivity_service.dart';
import '../services/notification_service.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _employeeIdController = TextEditingController();
  final _nameController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _isLoading = false;
  bool _isSignUp = false;
  bool _obscurePassword = true; // State for password visibility

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

                      // Full Name (only signup)
                      if (_isSignUp) ...[
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
                          validator: (v) =>
                          v == null || v.isEmpty ? "Enter your name" : null,
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Email (only signup)
                      if (_isSignUp) ...[
                        TextFormField(
                          controller: _emailController,
                          keyboardType: TextInputType.emailAddress,
                          style: const TextStyle(fontSize: 16),
                          decoration: InputDecoration(
                            labelText: "Axeno Mail ID",
                            prefixIcon: const Icon(Icons.email_outlined),
                            filled: true,
                            fillColor: Colors.grey.shade100,
                            border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                          ),
                          validator: (v) {
                            if (v == null || v.isEmpty) return "Enter your email";
                            if (!RegExp(r'^[\w-\.]+@([\w-]+\.)+[\w-]{2,4}$').hasMatch(v)) {
                              return "Enter a valid email";
                            }
                            if (!v.toLowerCase().endsWith("@axeno.co")) {
                              return "Only company emails are allowed";
                            }
                            return null;
                          },
                        ),
                        const SizedBox(height: 16),
                      ],

                      // Password
                      TextFormField(
                        controller: _passwordController,
                        obscureText: _obscurePassword,
                        style: const TextStyle(fontSize: 16),
                        decoration: InputDecoration(
                          labelText: "Password",
                          prefixIcon: const Icon(Icons.lock_outline),
                          suffixIcon: IconButton(
                            icon: Icon(
                              _obscurePassword ? Icons.visibility_off : Icons.visibility,
                              color: Colors.grey,
                            ),
                            onPressed: () {
                              setState(() {
                                _obscurePassword = !_obscurePassword;
                              });
                            },
                          ),
                          filled: true,
                          fillColor: Colors.grey.shade100,
                          border: OutlineInputBorder(
                            borderRadius: BorderRadius.circular(12),
                          ),
                        ),
                        validator: (v) =>
                        v == null || v.isEmpty ? "Required field" : null,
                      ),

                      // Forgot Password (only login)
                      if (!_isSignUp)
                        Align(
                          alignment: Alignment.centerRight,
                          child: TextButton(
                            onPressed: _handleForgotPasswordFlow,
                            child: const Text(
                              "Forgot Password?",
                              style: TextStyle(color: Colors.blueAccent),
                            ),
                          ),
                        )
                      else
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
                              ? const CircularProgressIndicator(color: Colors.white)
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
                            _formKey.currentState?.reset();
                            _nameController.clear();
                            _emailController.clear();
                            _obscurePassword = true; // reset visibility
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
    FocusScope.of(context).unfocus(); // Close keyboard on submit

    setState(() {
      _isLoading = true;
    });

    try {
      final employeeId = _employeeIdController.text.trim();
      final password = _passwordController.text.trim();
      final name = _nameController.text.trim();
      final email = _emailController.text.trim().toLowerCase();

      final bool backendAvailable = await ConnectivityService.isBackendAvailable();
      if (!backendAvailable) {
        _showErrorDialog("Unable to connect to server.\nPlease try again later.");
        return;
      }


      if (_isSignUp) {
        // Step 1: Send OTP for Sign Up
        String otpSent = await ApiService.sendOtp(employeeId, email, true);
        // Stop background loading while showing dialogs
        setState(() {
          _isLoading = false;
        });

        if (otpSent != "OTP sent.") {
          _showErrorDialog("Failed to send OTP. $otpSent");
          return;
        }

        // Step 2: Verify OTP
        bool isVerified = await _showOtpVerificationDialog(employeeId, true);

        // Step 3: If verified, proceed with Sign Up request to Admin
        if (isVerified) {
          setState(() {
            _isLoading = true; // Resume loading for final sign up call
          });

          String? fcmToken;
          try {
            fcmToken = await NotificationService.requestPermissionAndGetToken();
          } catch (_) {}
          bool success = await ApiService.signUp(employeeId, name, email, password, false, fcmToken: fcmToken);
          if (success) {
            _showSuccessDialog('Email verified! Request sent to admin. You can login once approved.');
            setState(() {
              _isSignUp = false; // Switch back to login
            });
          } else {
            _showErrorDialog('Sign-up failed. Employee ID or Email already exists.');
          }
        }
      } else {
        // Login Flow
        final user = await ApiService.login(employeeId, password);
        if (user == null) {
          _showErrorDialog('Invalid Employee ID or Password');
          return;
        }
        if (!user.isApproved) {
          _showErrorDialog('User yet to be approved by admin');
          return;
        }

        await _saveUserSession(user, password);

        try {
          final token = await NotificationService.requestPermissionAndGetToken();
          if (token != null) await ApiService.updateFcmToken(employeeId, password, token);
        } catch (_) {}

        if (user.isAdmin) {
          _navigateToAdminDashboard();
        } else {
          _navigateToUserDashboard();
        }
      }
    } catch (e) {
      if (mounted) {
        final msg = e.toString().replaceFirst('Exception: ', '');
        _showErrorDialog(msg);
      }
    } finally {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  // --- OTP Verification Dialog ---
  Future<bool> _showOtpVerificationDialog(String empId, bool signUp) async {
    final otpController = TextEditingController();
    bool isVerified = false;
    bool isVerifying = false;
    String? inlineError;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
        builder: (context, setStateDialog) {
          return AlertDialog(
            title: const Text('Verify Email'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('An OTP has been sent to the registered mail. Please enter it below.'),
                const SizedBox(height: 16),
                TextField(
                  controller: otpController,
                  keyboardType: TextInputType.number,
                  decoration: InputDecoration(
                    labelText: 'Enter OTP',
                    border: const OutlineInputBorder(),
                    errorText: inlineError, // Show error directly under the text field
                  ),
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: isVerifying ? null : () {
                  FocusScope.of(context).unfocus(); // Close keyboard on cancel
                  Navigator.pop(context);
                },
                child: const Text('Cancel'),
              ),
              ElevatedButton(
                onPressed: isVerifying
                    ? null
                    : () async {
                  FocusScope.of(context).unfocus(); // Close keyboard when verifying
                  setStateDialog(() {
                    isVerifying = true;
                    inlineError = null; // Reset error state
                  });

                  isVerified = await ApiService.verifyOtp(empId, otpController.text.trim(), signUp);

                  setStateDialog(() => isVerifying = false);

                  if (isVerified) {
                    if (context.mounted) Navigator.pop(context);
                  } else {
                    setStateDialog(() {
                      inlineError = 'Invalid OTP. Try again.'; // Set inline error
                    });
                  }
                },
                child: isVerifying
                    ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                    : const Text('Verify'),
              ),
            ],
          );
        },
      ),
    );
    return isVerified;
  }

  // --- Forgot Password Flow ---
  Future<void> _handleForgotPasswordFlow() async {
    final fpEmployeeIdController = TextEditingController();
    // final fpEmailController = TextEditingController();
    final formKey = GlobalKey<FormState>();

    bool isSending = false;
    String? apiError;

    // Step 1: Request Employee ID and Email
    bool otpSent = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Forgot Password'),
              content: Form(
                key: formKey,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Enter your details to receive a password reset OTP.'),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: fpEmployeeIdController,
                      keyboardType: TextInputType.number,
                      decoration: const InputDecoration(labelText: 'Employee ID', border: OutlineInputBorder()),
                      validator: (v) => v!.isEmpty ? 'Required' : null,
                    ),
                    // const SizedBox(height: 16),
                    // TextFormField(
                    //   controller: fpEmailController,
                    //   keyboardType: TextInputType.emailAddress,
                    //   decoration: const InputDecoration(labelText: 'Registered Email', border: OutlineInputBorder()),
                    //   validator: (v) => v!.isEmpty ? 'Required' : null,
                    // ),
                    if (apiError != null) ...[
                      const SizedBox(height: 12),
                      Text(apiError!, style: const TextStyle(color: Colors.red, fontSize: 13)),
                    ]
                  ],
                ),
              ),
              actions: [
                TextButton(
                    onPressed: isSending ? null : () => Navigator.pop(context, false),
                    child: const Text('Cancel')
                ),
                ElevatedButton(
                  onPressed: isSending ? null : () async {
                    if (formKey.currentState!.validate()) {
                      FocusScope.of(context).unfocus(); // Close keyboard
                      setStateDialog(() {
                        isSending = true;
                        apiError = null;
                      });

                      // final email = fpEmailController.text.trim();
                      final empId = fpEmployeeIdController.text.trim();

                      String otpStatus = await ApiService.sendOtp(empId, '', false);

                      setStateDialog(() => isSending = false);

                      if (otpStatus == "OTP sent.") {
                        if (context.mounted) Navigator.pop(context, true); // Close dialog on success
                      } else {
                        setStateDialog(() {
                          apiError = "Failed to send OTP. $otpStatus"; // Show error inline
                        });
                      }
                    }
                  },
                  child: isSending
                      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Send OTP'),
                ),
              ],
            );
          }
      ),
    ) ?? false;

    if (!otpSent) return;

    // final email = fpEmailController.text.trim();
    final empId = fpEmployeeIdController.text.trim();

    // Step 2: Verify OTP
    bool isVerified = await
    _showOtpVerificationDialog(empId, false);

    if (!isVerified) return;

    // Step 3: Create New Password
    final newPasswordController = TextEditingController();
    final newPasswordFormKey = GlobalKey<FormState>();
    bool obscureNewPassword = true;

    if (!mounted) return;
    bool resetSuccess = await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => StatefulBuilder(
          builder: (context, setStateDialog) {
            return AlertDialog(
              title: const Text('Create New Password'),
              content: Form(
                key: newPasswordFormKey,
                child: TextFormField(
                  controller: newPasswordController,
                  obscureText: obscureNewPassword,
                  decoration: InputDecoration(
                    labelText: 'New Password',
                    border: const OutlineInputBorder(),
                    suffixIcon: IconButton(
                      icon: Icon(
                        obscureNewPassword ? Icons.visibility_off : Icons.visibility,
                        color: Colors.grey,
                      ),
                      onPressed: () {
                        setStateDialog(() {
                          obscureNewPassword = !obscureNewPassword;
                        });
                      },
                    ),
                  ),
                  validator: (v) => v!.isEmpty ? 'Required' : null,
                ),
              ),
              actions: [
                ElevatedButton(
                  onPressed: () async {
                    if (newPasswordFormKey.currentState!.validate()) {
                      FocusScope.of(context).unfocus(); // Close keyboard
                      bool success = await ApiService.resetPassword(empId, newPasswordController.text.trim());
                      if (context.mounted) Navigator.pop(context, success);
                    }
                  },
                  child: const Text('Save Password'),
                ),
              ],
            );
          }
      ),
    ) ?? false;

    if (resetSuccess) {
      _showSuccessDialog('Password updated successfully. You can now login.');
    } else {
      _showErrorDialog('Failed to reset password. Please try again.');
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

  void _showSuccessDialog(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Success'),
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
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}