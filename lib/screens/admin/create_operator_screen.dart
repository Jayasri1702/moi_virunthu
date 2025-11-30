import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../models/user.dart';
import '../../utils/network_utils.dart';

class CreateOperatorScreen extends StatefulWidget {
  final UserModel? userToEdit;

  const CreateOperatorScreen({super.key, this.userToEdit});

  @override
  State<CreateOperatorScreen> createState() => _CreateOperatorScreenState();
}

class _CreateOperatorScreenState extends State<CreateOperatorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _name = TextEditingController();
  final _email = TextEditingController();
  final _password = TextEditingController();
  final _contactNumber = TextEditingController();
  final _auth = AuthService();
  bool _passwordVisible = false;
  bool _resetPassword = false;

  String _selectedUserType = 'Operator';
  bool _loading = false;
  bool get isEditing => widget.userToEdit != null;

  @override
  void initState() {
    super.initState();
    // Pre-fill form if editing
    if (isEditing) {
      _name.text = widget.userToEdit!.fullName;
      _email.text = widget.userToEdit!.email ?? '';
      _contactNumber.text = widget.userToEdit!.phone ?? '';
      _selectedUserType = widget.userToEdit!.role == 'admin' ? 'Administrator' : 'Operator';
    }
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _loading = true);

    try {
      Map<String, dynamic> result;

      if (isEditing) {
        // Update existing user
        result = await _updateUser();
      } else {
        // Create new user
        result = await _auth.createOperator(
          fullName: _name.text.trim(),
          password: _password.text,
          phone: _contactNumber.text.trim(),
          email: _email.text.trim().isEmpty ? null : _email.text.trim(),
          role: _selectedUserType == 'Administrator' ? 'admin' : 'operator',
        );
      }

      setState(() => _loading = false);

      if (!mounted) return;

      if (result['success']) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(result['message']),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.pop(context, true);
      } else {
        // Check if it's a network error that should trigger retry dialog
        if (result['error'] != null) {
          NetworkUtils.handleError(
            context,
            result['error'],
            onRetry: _save,
            customMessage: result['message'],
          );
        } else {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(result['message']),
              backgroundColor: Colors.red,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      }
    } catch (e) {
      setState(() => _loading = false);
      if (mounted) {
        NetworkUtils.handleError(
          context,
          e,
          onRetry: _save,
          customMessage: isEditing ? 'Error updating user' : 'Error creating operator',
        );
      }
    }
  }

  Future<Map<String, dynamic>> _updateUser() async {
    try {
      final updateData = <String, dynamic>{
        'full_name': _name.text.trim(),
        'phone': _contactNumber.text.trim(),
        'role': _selectedUserType == 'Administrator' ? 'admin' : 'operator',
      };

      // Only add email if it's not empty
      if (_email.text.trim().isNotEmpty) {
        updateData['email'] = _email.text.trim();
      }

      // Handle password update if user wants to reset it
      if (_resetPassword && _password.text.isNotEmpty) {
        // Validate the new password
        final validationError = _auth.validatePassword(_password.text);
        if (validationError != null) {
          return {
            'success': false,
            'message': validationError,
          };
        }

        // Hash the new password
        final newPasswordHash = await _auth.hashPassword(_password.text);
        updateData['password_hash'] = newPasswordHash;
      }

      await _auth.client
          .from('users')
          .update(updateData)
          .eq('id', widget.userToEdit!.id);

      return {
        'success': true,
        'message': 'User updated successfully',
      };
    } catch (e) {
      return {
        'success': false,
        'message': 'Error updating user: ${e.toString()}',
        'error': e,
      };
    }
  }

  void _clear() {
    _name.clear();
    _email.clear();
    _password.clear();
    _contactNumber.clear();
    setState(() {
      _selectedUserType = 'Operator';
      _resetPassword = false;
    });
  }

  @override
  void dispose() {
    _name.dispose();
    _email.dispose();
    _password.dispose();
    _contactNumber.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final screenWidth = MediaQuery.of(context).size.width;
    final isMobile = screenWidth < 600;

    return Scaffold(
      backgroundColor: Colors.grey[100],
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: EdgeInsets.symmetric(
              horizontal: isMobile ? 16 : 24,
              vertical: 24,
            ),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                // Title
                Container(
                  padding: EdgeInsets.symmetric(
                    horizontal: isMobile ? 20 : 32,
                    vertical: isMobile ? 12 : 16,
                  ),
                  decoration: BoxDecoration(
                    border: Border.all(color: Colors.black, width: 2),
                    color: Colors.white,
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    isEditing ? 'Edit User' : 'Create Data Entry Operator',
                    textAlign: TextAlign.center,
                    style: TextStyle(
                      fontSize: isMobile ? 18 : 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
                const SizedBox(height: 20),

                // Form Card
                Container(
                  width: double.infinity,
                  constraints: const BoxConstraints(maxWidth: 650),
                  decoration: BoxDecoration(
                    color: Colors.white,
                    border: Border.all(color: Colors.grey[400]!),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Column(
                    children: [
                      // Header
                      Container(
                        width: double.infinity,
                        padding: EdgeInsets.symmetric(
                          horizontal: isMobile ? 12 : 16,
                          vertical: 12,
                        ),
                        decoration: const BoxDecoration(
                          gradient: LinearGradient(
                            colors: [Color(0xFF7B3A99), Color(0xFF9B4DB8)],
                          ),
                          borderRadius: BorderRadius.only(
                            topLeft: Radius.circular(4),
                            topRight: Radius.circular(4),
                          ),
                        ),
                        child: Row(
                          children: [
                            const Text(
                              'USER',
                              style: TextStyle(
                                color: Colors.white,
                                fontSize: 16,
                                fontWeight: FontWeight.w500,
                              ),
                            ),
                            const Spacer(),
                            if (!isMobile) ...[
                              IconButton(
                                icon: const Icon(Icons.remove, color: Colors.white, size: 20),
                                onPressed: () {},
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 16),
                              IconButton(
                                icon: const Icon(Icons.crop_square, color: Colors.white, size: 20),
                                onPressed: () {},
                                padding: EdgeInsets.zero,
                                constraints: const BoxConstraints(),
                              ),
                              const SizedBox(width: 16),
                            ],
                            IconButton(
                              icon: const Icon(Icons.close, color: Colors.white, size: 20),
                              onPressed: () => Navigator.pop(context),
                              padding: EdgeInsets.zero,
                              constraints: const BoxConstraints(),
                            ),
                          ],
                        ),
                      ),

                      // Form
                      Padding(
                        padding: EdgeInsets.all(isMobile ? 16.0 : 24.0),
                        child: Form(
                          key: _formKey,
                          child: Column(
                            children: [
                              // Name
                              _buildFormRow(
                                label: 'Name',
                                required: true,
                                isMobile: isMobile,
                                child: TextFormField(
                                  controller: _name,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Name is required';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Email
                              _buildFormRow(
                                label: 'EMail',
                                required: false,
                                isMobile: isMobile,
                                child: TextFormField(
                                  controller: _email,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  keyboardType: TextInputType.emailAddress,
                                ),
                              ),
                              const SizedBox(height: 16),

                              // Reset Password Checkbox (only when editing)
                              if (isEditing) ...[
                                Row(
                                  children: [
                                    if (!isMobile) const SizedBox(width: 138),
                                    Checkbox(
                                      value: _resetPassword,
                                      onChanged: (value) {
                                        setState(() {
                                          _resetPassword = value ?? false;
                                          if (!_resetPassword) {
                                            _password.clear();
                                          }
                                        });
                                      },
                                    ),
                                    const Text(
                                      'Reset Password',
                                      style: TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w500,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 8),
                              ],

                              // Password (only show when creating new user OR when reset checkbox is checked)
                              if (!isEditing || _resetPassword) ...[
                                _buildFormRow(
                                  label: 'Password',
                                  required: !isEditing || _resetPassword,
                                  isMobile: isMobile,
                                  child: TextFormField(
                                    controller: _password,
                                    decoration: InputDecoration(
                                      border: const OutlineInputBorder(),
                                      contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                      hintText: isEditing ? 'Enter new password' : null,
                                      hintStyle: TextStyle(fontSize: 11, color: Colors.grey[600]),
                                      suffixIcon: IconButton(
                                        icon: Icon(
                                          _passwordVisible ? Icons.visibility : Icons.visibility_off,
                                          color: Colors.grey[600],
                                        ),
                                        onPressed: () {
                                          setState(() {
                                            _passwordVisible = !_passwordVisible;
                                          });
                                        },
                                      ),
                                    ),
                                    obscureText: !_passwordVisible,
                                    validator: (value) {
                                      // If resetting password, new password is required
                                      if (isEditing && _resetPassword && (value == null || value.isEmpty)) {
                                        return 'New password is required';
                                      }
                                      if (!isEditing && (value == null || value.isEmpty)) {
                                        return 'Password is required';
                                      }
                                      if (value != null && value.isNotEmpty) {
                                        final validationError = _auth.validatePassword(value);
                                        return validationError;
                                      }
                                      return null;
                                    },
                                  ),
                                ),
                                const SizedBox(height: 16),
                              ],

                              // Contact Number
                              _buildFormRow(
                                label: 'Contact Number',
                                required: true,
                                isMobile: isMobile,
                                child: TextFormField(
                                  controller: _contactNumber,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  keyboardType: TextInputType.phone,
                                  inputFormatters: [
                                    FilteringTextInputFormatter.digitsOnly,
                                  ],
                                  validator: (value) {
                                    if (value == null || value.trim().isEmpty) {
                                      return 'Contact number is required';
                                    }
                                    if (value.trim().length != 10) {
                                      return 'Contact number must be exactly 10 digits';
                                    }
                                    return null;
                                  },
                                ),
                              ),
                              const SizedBox(height: 16),

                              // User Type
                              _buildFormRow(
                                label: 'User Type',
                                required: true,
                                isMobile: isMobile,
                                child: DropdownButtonFormField<String>(
                                  value: _selectedUserType,
                                  decoration: const InputDecoration(
                                    border: OutlineInputBorder(),
                                    contentPadding: EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                  ),
                                  items: const [
                                    DropdownMenuItem(value: 'Operator', child: Text('Operator')),
                                    DropdownMenuItem(value: 'Administrator', child: Text('Administrator')),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _selectedUserType = value!);
                                  },
                                ),
                              ),
                              const SizedBox(height: 24),

                              // Buttons
                              isMobile
                                  ? Column(
                                children: [
                                  // SAVE/UPDATE Button
                                  SizedBox(
                                    width: double.infinity,
                                    height: 45,
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : _save,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFB846D7),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      child: _loading
                                          ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                          : Text(
                                        isEditing ? 'UPDATE' : 'SAVE',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 12),

                                  // Clear and Exit buttons
                                  Row(
                                    children: [
                                      Expanded(
                                        child: SizedBox(
                                          height: 45,
                                          child: OutlinedButton(
                                            onPressed: _clear,
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.black,
                                              side: BorderSide(color: Colors.grey[400]!),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),
                                            child: const Text(
                                              'Clear',
                                              style: TextStyle(fontSize: 15),
                                            ),
                                          ),
                                        ),
                                      ),
                                      const SizedBox(width: 12),
                                      Expanded(
                                        child: SizedBox(
                                          height: 45,
                                          child: OutlinedButton(
                                            onPressed: () => Navigator.pop(context),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: Colors.black,
                                              side: BorderSide(color: Colors.grey[400]!),
                                              shape: RoundedRectangleBorder(
                                                borderRadius: BorderRadius.circular(4),
                                              ),
                                            ),
                                            child: const Text(
                                              'Exit',
                                              style: TextStyle(fontSize: 15),
                                            ),
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                ],
                              )
                                  : Row(
                                mainAxisAlignment: MainAxisAlignment.center,
                                children: [
                                  // SAVE/UPDATE Button
                                  SizedBox(
                                    width: 110,
                                    height: 45,
                                    child: ElevatedButton(
                                      onPressed: _loading ? null : _save,
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: const Color(0xFFB846D7),
                                        foregroundColor: Colors.white,
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      child: _loading
                                          ? const SizedBox(
                                        height: 20,
                                        width: 20,
                                        child: CircularProgressIndicator(
                                          strokeWidth: 2,
                                          color: Colors.white,
                                        ),
                                      )
                                          : Text(
                                        isEditing ? 'UPDATE' : 'SAVE',
                                        style: const TextStyle(
                                          fontSize: 15,
                                          fontWeight: FontWeight.w500,
                                        ),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Clear Button
                                  SizedBox(
                                    width: 110,
                                    height: 45,
                                    child: OutlinedButton(
                                      onPressed: _clear,
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.black,
                                        side: BorderSide(color: Colors.grey[400]!),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      child: const Text(
                                        'Clear',
                                        style: TextStyle(fontSize: 15),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(width: 12),

                                  // Exit Button
                                  SizedBox(
                                    width: 110,
                                    height: 45,
                                    child: OutlinedButton(
                                      onPressed: () => Navigator.pop(context),
                                      style: OutlinedButton.styleFrom(
                                        foregroundColor: Colors.black,
                                        side: BorderSide(color: Colors.grey[400]!),
                                        shape: RoundedRectangleBorder(
                                          borderRadius: BorderRadius.circular(4),
                                        ),
                                      ),
                                      child: const Text(
                                        'Exit',
                                        style: TextStyle(fontSize: 15),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildFormRow({
    required String label,
    required bool required,
    required bool isMobile,
    required Widget child,
  }) {
    if (isMobile) {
      // Stack labels on top of inputs for mobile
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text(
                label,
                style: const TextStyle(fontSize: 14, fontWeight: FontWeight.w500),
              ),
              if (required)
                const Text(
                  ' *',
                  style: TextStyle(color: Colors.red, fontSize: 14),
                ),
            ],
          ),
          const SizedBox(height: 6),
          child,
        ],
      );
    }

    // Side-by-side layout for larger screens
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        SizedBox(
          width: 130,
          child: Padding(
            padding: const EdgeInsets.only(top: 14),
            child: Row(
              children: [
                Flexible(
                  child: Text(
                    label,
                    style: const TextStyle(fontSize: 14),
                  ),
                ),
                if (required)
                  const Text(
                    ' *',
                    style: TextStyle(color: Colors.red, fontSize: 14),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(child: child),
      ],
    );
  }
}