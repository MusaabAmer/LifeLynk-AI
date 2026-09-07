class BloodGroupModel {
  final String id;

  final String groupName;

  final DateTime createdAt;

  final DateTime updatedAt;

  final DateTime? deletedAt;

  const BloodGroupModel({
    required this.id,
    required this.groupName,
    required this.createdAt,
    required this.updatedAt,
    this.deletedAt,
  });

  factory BloodGroupModel.fromJson(Map<String, dynamic> json) {
    return BloodGroupModel(
      id: json['id'],
      groupName: json['group_name'],
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
      'group_name': groupName,
      'created_at': createdAt.toIso8601String(),
      'updated_at': updatedAt.toIso8601String(),
      'deleted_at': deletedAt?.toIso8601String(),
    };
  }
}