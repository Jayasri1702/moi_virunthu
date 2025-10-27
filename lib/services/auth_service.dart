import 'dart:convert';
import 'dart:typed_data';
import 'package:argon2/argon2.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/user.dart';

class AuthService {
  final SupabaseClient client = Supabase.instance.client;

  static const String _fixedSalt = 'jA3tzygBFa8JHR3E';
  static const int _hashLength = 16;

  static final Argon2Parameters _params = Argon2Parameters(
    Argon2Parameters.ARGON2_id,
    Uint8List.fromList(utf8.encode(_fixedSalt)),
    iterations: 2,
    memoryPowerOf2: 16,
    lanes: 1,
  );

  final Argon2BytesGenerator _argon2 = Argon2BytesGenerator();

  /// Validates password requirements
  /// Returns null if valid, otherwise returns error message
  String? validatePassword(String password) {
    if (password.length < 8) {
      return 'Password must be at least 8 characters long';
    }

    if (!password.contains(RegExp(r'[A-Z]'))) {
      return 'Password must contain at least one uppercase letter';
    }

    if (!password.contains(RegExp(r'[a-z]'))) {
      return 'Password must contain at least one lowercase letter';
    }

    if (!password.contains(RegExp(r'[0-9]'))) {
      return 'Password must contain at least one number';
    }

    return null; // Password is valid
  }

  /// Hash password to match backend format
  /// Made public so it can be used for password resets
  Future<String> hashPassword(String password) async {
    _argon2.init(_params);
    final Uint8List passwordBytes = _params.converter.convert(password);
    final Uint8List out = Uint8List(_hashLength);
    _argon2.generateBytes(passwordBytes, out, 0, out.length);

    final saltBase64 = base64Encode(utf8.encode(_fixedSalt)).replaceAll('=', '');
    final hashBase64 = base64Encode(out).replaceAll('=', '');

    return '\$argon2id\$v=19\$m=65536,t=2,p=1\$' + saltBase64 + '\$' + hashBase64;
  }

  /// Verify password against stored hash
  Future<bool> _verifyPassword(String password, String storedHash) async {
    try {
      final parts = storedHash.split('\$');
      if (parts.length < 6) return false;

      final storedHashBase64 = parts[5].replaceAll('=', '');

      _argon2.init(_params);
      final Uint8List passwordBytes = _params.converter.convert(password);
      final Uint8List out = Uint8List(_hashLength);
      _argon2.generateBytes(passwordBytes, out, 0, out.length);
      final newHashBase64 = base64Encode(out).replaceAll('=', '');

      return newHashBase64 == storedHashBase64;
    } catch (e) {
      print('Password verification error: $e');
      return false;
    }
  }

  Future<UserModel?> login(String fullName, String password) async {
    try {
      print('Attempting login for full_name: $fullName');

      final data = await client
          .from('users')
          .select()
          .eq('full_name', fullName)
          .limit(1);

      if (data == null || data is! List || data.isEmpty) {
        print('No user found with full_name: $fullName');
        return null;
      }

      final row = data[0] as Map<String, dynamic>;
      final storedHash = row['password_hash']?.toString();

      if (storedHash == null) {
        print('No password hash found for user');
        return null;
      }

      final isValid = await _verifyPassword(password, storedHash);

      if (!isValid) {
        print('Password verification failed');
        return null;
      }

      print('Login successful');
      return UserModel.fromMap(row);
    } catch (e) {
      print('Login error: $e');
      return null;
    }
  }

  /// Logout user and clear any stored session data
  Future<void> logout() async {
    // Since we're using custom authentication (not Supabase Auth),
    // we don't need to sign out from Supabase Auth.
    // Just return successfully - navigation will handle clearing the stack
    print('Logout successful');
  }

  /// Creates a new operator or admin
  /// Returns a Map with 'success' (bool) and 'message' (String)
  Future<Map<String, dynamic>> createOperator({
    required String fullName,
    required String password,
    required String phone,
    String? email,
    String role = 'operator',
  }) async {
    try {
      // Validate password before creating operator
      final validationError = validatePassword(password);
      if (validationError != null) {
        return {
          'success': false,
          'message': validationError,
        };
      }

      // Validate phone number is not empty
      if (phone.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Phone number is required',
        };
      }

      // Validate full name is not empty
      if (fullName.trim().isEmpty) {
        return {
          'success': false,
          'message': 'Full name is required',
        };
      }

      final hash = await hashPassword(password);

      final insert = {
        'full_name': fullName,
        'password_hash': hash,
        'phone': phone,
        'role': role,
        'is_active': true,
        'email': email,
      };

      await client.from('users').insert([insert]);
      return {
        'success': true,
        'message': '${role == 'admin' ? 'Administrator' : 'Operator'} created successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error creating user: ${e.toString()}',
      };
    }
  }
}