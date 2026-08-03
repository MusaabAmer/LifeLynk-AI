class UserModel {
  final String id;
  final String fullName;
  final String email;
  final String phone;
  final String bloodGroup;
  final String address;
  final String? profileImageUrl;

  const UserModel({
    required this.id,
    required this.fullName,
    required this.email,
    required this.phone,
    required this.bloodGroup,
    required this.address,
    this.profileImageUrl,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] ?? '',
      fullName: json['full_name'] ?? json['fullName'] ?? '',
      email: json['email'] ?? '',
      phone: json['phone'] ?? '',
      bloodGroup: json['blood_group'] ?? json['bloodGroup'] ?? 'O+',
      address: json['address'] ?? '',
      profileImageUrl: json['profile_image_url'] ?? json['profileImageUrl'],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'email': email,
      'phone': phone,
      'blood_group': bloodGroup,
      'address': address,
      'profile_image_url': profileImageUrl,
    };
  }

  UserModel copyWith({
    String? fullName,
    String? email,
    String? phone,
    String? bloodGroup,
    String? address,
    String? profileImageUrl,
  }) {
    return UserModel(
      id: id,
      fullName: fullName ?? this.fullName,
      email: email ?? this.email,
      phone: phone ?? this.phone,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      address: address ?? this.address,
      profileImageUrl: profileImageUrl ?? this.profileImageUrl,
    );
  }
}
