import 'package:flutter/material.dart';


class OperatorDashboard extends StatelessWidget {
  const OperatorDashboard({super.key});


  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Operator Dashboard')),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Welcome, operator!'),
            const SizedBox(height: 12),
            ElevatedButton(onPressed: () => Navigator.pushReplacementNamed(context, '/'), child: const Text('Logout')),
          ],
        ),
      ),
    );
  }
}