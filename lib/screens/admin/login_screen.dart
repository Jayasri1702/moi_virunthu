import 'package:flutter/material.dart';
import '../../services/auth_service.dart';
import '../../utils/network_utils.dart';
import '../../models/user.dart';
import '../../services/session_manager.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();
  final _auth = AuthService();
  bool _loading = false;
  bool _obscurePassword = true;

  void _showMessage(String m) => ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text(m))
  );

  Future<void> _login() async {
    // Basic validation first (no internet needed)
    if (_usernameController.text.trim().isEmpty) {
      _showMessage('Please enter username');
      return;
    }

    if (_passwordController.text.isEmpty) {
      _showMessage('Please enter password');
      return;
    }

    // ✅ STEP 1: Check internet connection BEFORE attempting login
    if (!await NetworkUtils.checkConnectionBeforeRequest(
      context,
      onRetry: _login,
    )) {
      return; // Internet dialog will be shown, exit early
    }

    // ✅ STEP 2: Show loading
    setState(() => _loading = true);

    try {
      // ✅ STEP 3: Attempt login
      final result = await _auth.login(
        _usernameController.text.trim(),
        _passwordController.text,
      );

      if (!mounted) return;

      setState(() => _loading = false);

      // ✅ STEP 4: Handle response
      if (result['success'] == true) {
        final user = result['user'] as UserModel;

        // ✅ NEW: Get auth token from login result
        final authToken = result['token'] as String?;

        if (authToken != null) {
          print('✅ Using auth token from backend: ${authToken.substring(0, 30)}...');
        } else {
          print('⚠️ No auth token in login response');
        }

        // ✅ Save session WITH auth token
        await SessionManager.saveSession(
          user,
          authToken: authToken,
        );

        // Navigate based on role
        if (user.role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin', arguments: user);
        } else {
          Navigator.pushReplacementNamed(
            context,
            '/operator/home',
            arguments: user,
          );
        }
      } else {
        // ✅ STEP 5: Handle errors based on error type
        final errorType = result['error'] ?? 'unknown';
        final errorMessage = result['message'] ?? 'Login failed';

        if (errorType == 'network_error') {
          // Show network error dialog
          if (mounted) {
            NetworkUtils.showConnectionErrorDialog(
              context,
              onRetry: _login,
            );
          }
        } else if (errorType == 'invalid_credentials') {
          // Show invalid credentials message
          if (mounted) {
            _showMessage(errorMessage);
          }
        } else {
          // Show generic error
          if (mounted) {
            _showMessage(errorMessage);
          }
        }
      }
    } catch (e) {
      if (!mounted) return;

      setState(() => _loading = false);

      // ✅ Handle unexpected errors with NetworkUtils
      NetworkUtils.handleError(
        context,
        e,
        onRetry: _login,
        customMessage: 'Error logging in',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.all(24.0),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text(
                  'Hi Tech Moi',
                  style: TextStyle(
                    fontSize: 32,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),
                const SizedBox(height: 40),

                // Money transfer image
                Container(
                  padding: const EdgeInsets.all(20),
                  child: Image.asset(
                    'assets/images/money_transfer.png',
                    height: 150,
                    width: 200,
                    fit: BoxFit.contain,
                  ),
                ),

                const SizedBox(height: 40),

                const Text(
                  'Welcome!',
                  style: TextStyle(
                    fontSize: 28,
                    fontWeight: FontWeight.bold,
                    color: Colors.black,
                  ),
                ),

                const SizedBox(height: 30),

                // User ID Field
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _usernameController,
                    decoration: InputDecoration(
                      hintText: 'User ID',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      suffixIcon: const Icon(
                        Icons.person,
                        color: Colors.black,
                        size: 28,
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Password Field with visibility toggle
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: TextField(
                    controller: _passwordController,
                    obscureText: _obscurePassword,
                    decoration: InputDecoration(
                      hintText: 'Password',
                      hintStyle: TextStyle(color: Colors.grey[400]),
                      border: InputBorder.none,
                      contentPadding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 16,
                      ),
                      suffixIcon: IconButton(
                        icon: Icon(
                          _obscurePassword ? Icons.lock : Icons.lock_open,
                          color: Colors.black,
                          size: 28,
                        ),
                        onPressed: () {
                          setState(() {
                            _obscurePassword = !_obscurePassword;
                          });
                        },
                      ),
                    ),
                  ),
                ),

                const SizedBox(height: 30),

                // Login Button
                SizedBox(
                  width: 160,
                  height: 50,
                  child: OutlinedButton(
                    onPressed: _loading ? null : _login,
                    style: OutlinedButton.styleFrom(
                      side: const BorderSide(color: Colors.black, width: 2),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8),
                      ),
                    ),
                    child: _loading
                        ? const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.black,
                      ),
                    )
                        : const Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Text(
                          'Login',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: Colors.black,
                          ),
                        ),
                        SizedBox(width: 8),
                        Icon(Icons.login, color: Colors.black),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }
}