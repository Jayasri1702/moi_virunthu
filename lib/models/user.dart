class UserModel {
  final String id;
  final String fullName;
  final String role;
  final bool isActive;
  final String? email;
  final String? phone;

  UserModel({
    required this.id,
    required this.fullName,
    required this.role,
    required this.isActive,
    this.email,
    this.phone,
  });

  factory UserModel.fromMap(Map<String, dynamic> m) {
    return UserModel(
      id: m['id']?.toString() ?? '',
      fullName: m['full_name']?.toString() ?? '',
      role: (m['role'] ?? 'operator').toString(),
      isActive: (m['is_active'] == null) ? true : (m['is_active'] as bool),
      email: m['email']?.toString(),
      phone: m['phone']?.toString(),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'full_name': fullName,
      'role': role,
      'is_active': isActive,
      'email': email,
      'phone': phone,
    };
  }
}