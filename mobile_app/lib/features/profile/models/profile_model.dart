import 'package:flutter/foundation.dart';

/// Represents the healthcare profile used by the LifeLynk mobile app.
///
/// Database mapping:
///
/// public.users
///   - id
///   - full_name
///   - phone_number
///
/// public.patients
///   - id
///   - user_id
///   - blood_group_id
///   - gender
///
/// Province and city are retained in the Flutter model because the
/// profile UI and location services use them. They are NOT written to
/// public.patients because those columns do not exist in the actual
/// database schema.
@immutable
class ProfileModel {
  final String? id;

  /// User's full name.
  ///
  /// Stored in public.users.full_name.
  final String fullName;

  /// User's phone number.
  ///
  /// Stored in public.users.phone_number.
  final String? phoneNumber;

  /// Optional gender.
  ///
  /// Stored in public.patients.gender.
  final String? gender;

  /// Blood-group display value, for example:
  /// A+, A-, B+, B-, AB+, AB-, O+, O-
  ///
  /// The repository resolves this value to public.blood_groups.id
  /// before writing public.patients.blood_group_id.
  final String? bloodGroup;

  /// Province selected by the profile/location UI.
  ///
  /// There is currently no province column in public.patients.
  final String? province;

  /// City selected by the profile/location UI.
  ///
  /// There is currently no city column in public.patients.
  final String? city;

  const ProfileModel({
    this.id,
    required this.fullName,
    this.phoneNumber,
    this.gender,
    this.bloodGroup,
    this.province,
    this.city,
  });

  // ============================================================
  // FROM JSON
  // ============================================================

  factory ProfileModel.fromJson(Map<String, dynamic> json) {
    return ProfileModel(
      id: json['id']?.toString(),
      fullName: json['full_name']?.toString() ?? '',
      phoneNumber: json['phone_number']?.toString(),
      gender: json['gender']?.toString(),
      bloodGroup: json['blood_group']?.toString(),
      province: json['province']?.toString(),
      city: json['city']?.toString(),
    );
  }

  // ============================================================
  // TO JSON
  // ============================================================

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'full_name': fullName,
      'phone_number': phoneNumber,
      'gender': gender,
      'blood_group': bloodGroup,
      'province': province,
      'city': city,
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  ProfileModel copyWith({
    String? id,
    String? fullName,
    String? phoneNumber,
    String? gender,
    String? bloodGroup,
    String? province,
    String? city,
  }) {
    return ProfileModel(
      id: id ?? this.id,
      fullName: fullName ?? this.fullName,
      phoneNumber: phoneNumber ?? this.phoneNumber,
      gender: gender ?? this.gender,
      bloodGroup: bloodGroup ?? this.bloodGroup,
      province: province ?? this.province,
      city: city ?? this.city,
    );
  }

  // ============================================================
  // TO STRING
  // ============================================================

  @override
  String toString() {
    return 'ProfileModel('
        'id: $id, '
        'fullName: $fullName, '
        'phoneNumber: $phoneNumber, '
        'gender: $gender, '
        'bloodGroup: $bloodGroup, '
        'province: $province, '
        'city: $city'
        ')';
  }

  // ============================================================
  // EQUALITY
  // ============================================================

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other is ProfileModel &&
            other.id == id &&
            other.fullName == fullName &&
            other.phoneNumber == phoneNumber &&
            other.gender == gender &&
            other.bloodGroup == bloodGroup &&
            other.province == province &&
            other.city == city);
  }

  @override
  int get hashCode {
    return Object.hash(
      id,
      fullName,
      phoneNumber,
      gender,
      bloodGroup,
      province,
      city,
    );
  }
}
