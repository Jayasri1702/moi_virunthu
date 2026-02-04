import 'package:shared_preferences/shared_preferences.dart';
import '../models/user.dart';

class SessionManager {
  static const String _userIdKey = 'user_id';
  static const String _userNameKey = 'user_name';
  static const String _userRoleKey = 'user_role';
  static const String _userPhoneKey = 'user_phone';
  static const String _userEmailKey = 'user_email';
  static const String _lastActiveKey = 'last_active';
  static const int _sessionTimeoutMinutes = 10;

  // Save user session
  static Future<void> saveSession(UserModel user) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_userIdKey, user.id);
    await prefs.setString(_userNameKey, user.fullName);
    await prefs.setString(_userRoleKey, user.role);

    // ✅ FIX: Handle nullable phone
    if (user.phone != null) {
      await prefs.setString(_userPhoneKey, user.phone!);
    }

    if (user.email != null) {
      await prefs.setString(_userEmailKey, user.email!);
    }

    await prefs.setInt(_lastActiveKey, DateTime.now().millisecondsSinceEpoch);
    print('✅ Session saved for user: ${user.fullName}');
  }

  /// Update last active timestamp
  static Future<void> updateLastActive() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setInt(_lastActiveKey, DateTime.now().millisecondsSinceEpoch);
  }

  /// Check if session is valid (not expired)
  /// Check if session is valid (not expired)
  static Future<bool> isSessionValid() async {
    final prefs = await SharedPreferences.getInstance();
    final lastActive = prefs.getInt(_lastActiveKey);

    if (lastActive == null) {
      print('❌ No session found');
      return false;
    }

    final lastActiveTime = DateTime.fromMillisecondsSinceEpoch(lastActive);
    final now = DateTime.now();
    final difference = now.difference(lastActiveTime);

    final isValid = difference.inMinutes < _sessionTimeoutMinutes;

    if (isValid) {
      print('✅ Session valid (${difference.inMinutes} mins old)');
      // ✅ DON'T auto-refresh here - let the app control when to refresh
    } else {
      print('❌ Session expired (${difference.inMinutes} mins old)');
    }

    return isValid;
  }

  // Get stored user from session
  static Future<UserModel?> getStoredUser() async {
    final prefs = await SharedPreferences.getInstance();

    final userId = prefs.getString(_userIdKey);
    final userName = prefs.getString(_userNameKey);
    final userRole = prefs.getString(_userRoleKey);
    final userPhone = prefs.getString(_userPhoneKey); // ✅ Can be null now
    final userEmail = prefs.getString(_userEmailKey);

    // ✅ FIX: Only check for required fields
    if (userId == null || userName == null || userRole == null) {
      print('❌ Incomplete session data');
      return null;
    }

    return UserModel(
      id: userId,
      fullName: userName,
      role: userRole,
      phone: userPhone, // ✅ Can be null
      email: userEmail,
      isActive: true,
    );
  }

  /// Clear session (logout)
  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_userIdKey);
    await prefs.remove(_userNameKey);
    await prefs.remove(_userRoleKey);
    await prefs.remove(_userPhoneKey);
    await prefs.remove(_userEmailKey);
    await prefs.remove(_lastActiveKey);
    print('✅ Session cleared');
  }
}