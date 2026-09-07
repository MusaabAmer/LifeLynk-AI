class EmergencySosModel {
  final String id;
  final String userId;
  final String bloodGroupId;
  final String? cityId;
  final int unitsRequired;
  final String urgencyLevel;
  final String? description;
  final String status;

  final double? latitude;
  final double? longitude;
  final double? gpsAccuracy;
  final DateTime? locationTimestamp;

  final DateTime? createdAt;

  const EmergencySosModel({
    required this.id,
    required this.userId,
    required this.bloodGroupId,
    this.cityId,
    required this.unitsRequired,
    required this.urgencyLevel,
    this.description,
    required this.status,
    this.latitude,
    this.longitude,
    this.gpsAccuracy,
    this.locationTimestamp,
    this.createdAt,
  });

  factory EmergencySosModel.fromMap(Map<String, dynamic> map) {
    return EmergencySosModel(
      id: map['id']?.toString() ?? '',
      userId: map['user_id']?.toString() ?? '',
      bloodGroupId: map['blood_group_id']?.toString() ?? '',
      cityId: _parseNullableString(map['city_id']),
      unitsRequired: _parseInt(map['units_required']),
      urgencyLevel:
          map['urgency_level']?.toString().trim().toLowerCase() ??
              'critical',
      description: map['description']?.toString(),
      status:
          map['status']?.toString().trim().toLowerCase() ??
              'pending',
      latitude: _parseDouble(map['latitude']),
      longitude: _parseDouble(map['longitude']),
      gpsAccuracy: _parseDouble(map['gps_accuracy']),
      locationTimestamp: _parseDateTime(
        map['location_timestamp'],
      ),
      createdAt: _parseDateTime(map['created_at']),
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'user_id': userId,
      'blood_group_id': bloodGroupId,
      'city_id': cityId,
      'units_required': unitsRequired,
      'urgency_level': urgencyLevel,
      'description': description,
      'status': status,
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy': gpsAccuracy,
      'location_timestamp':
          locationTimestamp?.toUtc().toIso8601String(),
      'created_at':
          createdAt?.toUtc().toIso8601String(),
    };
  }

  EmergencySosModel copyWith({
    String? id,
    String? userId,
    String? bloodGroupId,
    String? cityId,
    int? unitsRequired,
    String? urgencyLevel,
    String? description,
    String? status,
    double? latitude,
    double? longitude,
    double? gpsAccuracy,
    DateTime? locationTimestamp,
    DateTime? createdAt,
  }) {
    return EmergencySosModel(
      id: id ?? this.id,
      userId: userId ?? this.userId,
      bloodGroupId: bloodGroupId ?? this.bloodGroupId,
      cityId: cityId ?? this.cityId,
      unitsRequired: unitsRequired ?? this.unitsRequired,
      urgencyLevel: urgencyLevel ?? this.urgencyLevel,
      description: description ?? this.description,
      status: status ?? this.status,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      gpsAccuracy: gpsAccuracy ?? this.gpsAccuracy,
      locationTimestamp:
          locationTimestamp ?? this.locationTimestamp,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  String get normalizedStatus =>
      status.trim().toLowerCase();

  bool get hasLocation =>
      latitude != null && longitude != null;

  bool get hasValidLocation {
    if (!hasLocation) return false;

    final lat = latitude!;
    final lng = longitude!;

    return lat >= -90 &&
        lat <= 90 &&
        lng >= -180 &&
        lng <= 180;
  }

  bool get isPending =>
      normalizedStatus == 'pending';

  bool get isMatched =>
      normalizedStatus == 'matched';

  bool get isInProgress =>
      normalizedStatus == 'in_progress';

  bool get isCompleted =>
      normalizedStatus == 'completed';

  bool get isCancelled =>
      normalizedStatus == 'cancelled';

  bool get isActive =>
      isPending ||
      isMatched ||
      isInProgress;

  bool get hasBloodGroup =>
      bloodGroupId.trim().isNotEmpty;

  bool get hasGpsAccuracy =>
      gpsAccuracy != null &&
      gpsAccuracy! >= 0;

  static int _parseInt(dynamic value) {
    if (value == null) return 0;
    if (value is int) return value;
    if (value is num) return value.toInt();

    return int.tryParse(
          value.toString().trim(),
        ) ??
        0;
  }

  static double? _parseDouble(dynamic value) {
    if (value == null) return null;
    if (value is double) return value;
    if (value is num) return value.toDouble();

    return double.tryParse(
      value.toString().trim(),
    );
  }

  static DateTime? _parseDateTime(dynamic value) {
    if (value == null) return null;

    if (value is DateTime) {
      return value.toUtc();
    }

    final parsed =
        DateTime.tryParse(value.toString());

    return parsed?.toUtc();
  }

  static String? _parseNullableString(dynamic value) {
    if (value == null) return null;

    final parsed =
        value.toString().trim();

    return parsed.isEmpty ? null : parsed;
  }
}