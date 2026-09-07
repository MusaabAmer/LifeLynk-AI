class PatientModel {
  final String id;

  final String userId;

  final String? bloodGroupId;

  final DateTime? dateOfBirth;

  final String? gender;

  final String? emergencyContact;

  final String? medicalNotes;

  final DateTime createdAt;

  final DateTime updatedAt;

  final DateTime? deletedAt;

  const PatientModel({
    required this.id,
    required this.userId,
    this.bloodGroupId,
    this.dateOfBirth,
    this.gender,
    this.emergencyContact,
    this.medicalNotes,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory PatientModel.fromJson(Map<String, dynamic> json) {
    return PatientModel(
      id: json['id'],
      userId: json['user_id'],
      bloodGroupId: json['blood_group_id'],
      dateOfBirth: json['date_of_birth'] == null
          ? null
          : DateTime.parse(json['date_of_birth']),
      gender: json['gender'],
      emergencyContact: json['emergency_contact'],
      medicalNotes: json['medical_notes'],
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
      'user_id': userId,
      'blood_group_id': bloodGroupId,
      'date_of_birth': dateOfBirth?.toIso8601String(),
      'gender': gender,
      'emergency_contact': emergencyContact,
      'medical_notes': medicalNotes,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}