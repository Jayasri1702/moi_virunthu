import 'package:flutter/material.dart';
import '../../services/auth_service.dart';

class AdminDashboard extends StatelessWidget {
  const AdminDashboard({super.key});

  Future<void> _handleLogout(BuildContext context) async {
    final auth = AuthService();

    // Show confirmation dialog
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false, // Prevent accidental dismissal
      builder: (context) => AlertDialog(
        title: const Text('Logout'),
        content: const Text('Are you sure you want to logout?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Logout'),
          ),
        ],
      ),
    );

    if (confirmed != true) return;

    // Store the navigator before async operation
    final navigator = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);

    try {
      await auth.logout();
      print('Logout completed successfully');

      // Use stored navigator instead of context
      navigator.pushNamedAndRemoveUntil(
        '/',
            (route) => false,
      );
    } catch (e , stackTrace) {
      print('Logout error: $e');
      print('Stack trace: $stackTrace');
      // Use stored messenger instead of context
      messenger.showSnackBar(
        SnackBar(
          content: Text('Error logging out: ${e.toString()}'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final screenHeight = MediaQuery.of(context).size.height;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Stack(
          children: [
            // Logout button in top right corner

            // Main content
            Center(
              child: SingleChildScrollView(
                padding: EdgeInsets.symmetric(
                  horizontal: isMobile ? 20 : 40,
                  vertical: 24,
                ),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    SizedBox(height: isMobile ? 40 : 20),

                    // Admin Page Title
                    Container(
                      padding: EdgeInsets.symmetric(
                        horizontal: isMobile ? 32 : 48,
                        vertical: isMobile ? 16 : 20,
                      ),
                      decoration: BoxDecoration(
                        border: Border.all(color: Colors.black, width: 2),
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(4),
                      ),
                      child: Text(
                        'Admin Page',
                        style: TextStyle(
                          fontSize: isMobile ? 24 : 32,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                    SizedBox(height: isMobile ? 32 : 40),

                    // Profile Icon
                    Container(
                      width: isMobile ? 100 : 140,
                      height: isMobile ? 100 : 140,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.black, width: 3),
                        color: Colors.white,
                      ),
                      child: Icon(
                        Icons.person,
                        size: isMobile ? 60 : 80,
                        color: Colors.black,
                      ),
                    ),
                    SizedBox(height: isMobile ? 16 : 24),

                    // Welcome Admin Text
                    Text(
                      'Welcome Admin',
                      style: TextStyle(
                        fontSize: isMobile ? 22 : 28,
                        fontWeight: FontWeight.w400,
                      ),
                    ),
                    SizedBox(height: isMobile ? 32 : 40),

                    // Menu Buttons
                    _buildMenuButton(
                      context,
                      'Create Event',
                      isMobile: isMobile,
                      onPressed: () {
                        Navigator.pushNamed(context, '/admin/create-event');
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildMenuButton(
                      context,
                      'Create Data Entry Operator',
                      isMobile: isMobile,
                      onPressed: () {
                        Navigator.pushNamed(context, '/admin/create-operator');
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildMenuButton(
                      context,
                      "Today's Event",
                      isMobile: isMobile,
                      onPressed: () {
                        Navigator.pushNamed(context, '/admin/todays-event');
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildMenuButton(
                      context,
                      'All Event',
                      isMobile: isMobile,
                      onPressed: () {
                        Navigator.pushNamed(context, '/admin/all-events');
                      },
                    ),
                    const SizedBox(height: 12),

                    _buildMenuButton(
                      context,
                      'View All Data Entry Operator',
                      isMobile: isMobile,
                      onPressed: () {
                        Navigator.pushNamed(context, '/admin/user-list');
                      },
                    ),
                    SizedBox(height: isMobile ? 32 : 40),
                  ],
                ),
              ),
            ),
// Logout button in top right corner
            Positioned(
              top: 16,
              right: 16,
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border.all(color: Colors.black, width: 2),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: IconButton(
                  onPressed: () {
                    print('Logout button pressed!');
                    _handleLogout(context);
                  },
                  icon: const Icon(Icons.logout, color: Colors.red, size: 24),
                  tooltip: 'Logout',
                  padding: const EdgeInsets.all(8),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildMenuButton(
      BuildContext context,
      String text, {
        required bool isMobile,
        required VoidCallback onPressed,
      }) {
    return SizedBox(
      width: isMobile ? double.infinity : 380,
      height: 56,
      child: OutlinedButton(
        onPressed: onPressed,
        style: OutlinedButton.styleFrom(
          backgroundColor: Colors.white,
          foregroundColor: Colors.black,
          side: const BorderSide(color: Colors.black, width: 1.5),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(8),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
        ),
        child: Text(
          text,
          textAlign: TextAlign.center,
          style: TextStyle(
            fontSize: isMobile ? 16 : 18,
            fontWeight: FontWeight.w400,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
    );
  }
}