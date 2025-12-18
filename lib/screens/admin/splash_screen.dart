import 'package:flutter/material.dart';
import '../../services/session_manager.dart';
import '../../models/user.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  @override
  void initState() {
    super.initState();
    _checkSession();
  }

  Future<void> _checkSession() async {
    // Small delay for splash effect
    await Future.delayed(const Duration(seconds: 1));

    if (!mounted) return;

    // Check if session is valid
    final isValid = await SessionManager.isSessionValid();

    if (isValid) {
      // Get stored user
      final user = await SessionManager.getStoredUser();

      if (user != null && mounted) {
        // Navigate to appropriate screen based on role
        if (user.role == 'admin') {
          Navigator.pushReplacementNamed(context, '/admin', arguments: user);
        } else {
          Navigator.pushReplacementNamed(context, '/operator/home', arguments: user);
        }
        return;
      }
    }

    // No valid session, go to login
    if (mounted) {
      Navigator.pushReplacementNamed(context, '/login');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      body: Center(
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
            const SizedBox(height: 20),
            const CircularProgressIndicator(color: Colors.black),
          ],
        ),
      ),
    );
  }
}