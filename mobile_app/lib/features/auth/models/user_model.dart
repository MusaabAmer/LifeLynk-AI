class UserModel {
  final String id;

  final String roleId;

  final String email;

  final String fullName;

  final String? phoneNumber;

  final bool isActive;

  final bool isVerified;

  final DateTime? lastLoginAt;

  final DateTime createdAt;

  final DateTime updatedAt;

  final DateTime? deletedAt;

  const UserModel({
    required this.id,
    required this.roleId,
    required this.email,
    required this.fullName,
    this.phoneNumber,
    required this.isActive,
    required this.isVerified,
    this.lastLoginAt,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'],
      roleId: json['role_id'],
      email: json['email'],
      fullName: json['full_name'],
      phoneNumber: json['phone_number'],
      isActive: json['is_active'],
      isVerified: json['is_verified'],
      lastLoginAt: json['last_login_at'] == null
          ? null
          : DateTime.parse(json['last_login_at']),
      createdAt: DateTime.parse(json['created_at']),
      updatedAt: DateTime.parse(json['updated_at']),
      deletedAt: json['deleted_at'] == null
          ? null
          : DateTime.parse(json['deleted_at']),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role_id': roleId,
      'email': email,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'is_active': isActive,
      'is_verified': isVerified,
      'last_login_at': lastLoginAt?.toIso8601String(),
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}