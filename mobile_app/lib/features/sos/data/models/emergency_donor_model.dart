class EmergencyDonorModel {
  final String donorId;
  final String userId;

  final String? donorName;
  final String? phone;

  final String bloodGroupId;
  final String? bloodGroup;

  final String? cityId;

  final bool isAvailable;
  final bool isEligible;

  final double? distanceKm;

  final String? matchStatus;

  final DateTime? nextEligibleDate;
  final DateTime? lastDonationDate;

  const EmergencyDonorModel({
    required this.donorId,
    required this.userId,
    this.donorName,
    this.phone,
    required this.bloodGroupId,
    this.bloodGroup,
    this.cityId,
    required this.isAvailable,
    required this.isEligible,
    this.distanceKm,
    this.matchStatus,
    this.nextEligibleDate,
    this.lastDonationDate,
  });

  // ============================================================
  // FROM MAP
  // ============================================================

  factory EmergencyDonorModel.fromMap(
    Map<String, dynamic> map,
  ) {
    return EmergencyDonorModel(
      donorId:
          map['donor_id']?.toString() ??
          map['id']?.toString() ??
          '',

      userId:
          map['user_id']?.toString() ?? '',

      donorName:
          map['donor_name']?.toString(),

      phone:
          map['phone']?.toString(),

      bloodGroupId:
          map['blood_group_id']?.toString() ?? '',

      bloodGroup:
          map['blood_group']?.toString(),

      cityId:
          map['city_id']?.toString(),

      isAvailable:
          _parseBool(
        map['is_available'],
      ),

      isEligible:
          _parseBool(
        map['is_eligible'],
      ),

      distanceKm:
          _parseDouble(
        map['distance_km'],
      ),

      matchStatus:
          map['match_status']?.toString(),

      nextEligibleDate:
          _parseDateTime(
        map['next_eligible_date'],
      ),

      lastDonationDate:
          _parseDateTime(
        map['last_donation_date'],
      ),
    );
  }

  // ============================================================
  // TO MAP
  // ============================================================

  Map<String, dynamic> toMap() {
    return {
      'donor_id': donorId,
      'user_id': userId,
      'donor_name': donorName,
      'phone': phone,
      'blood_group_id': bloodGroupId,
      'blood_group': bloodGroup,
      'city_id': cityId,
      'is_available': isAvailable,
      'is_eligible': isEligible,
      'distance_km': distanceKm,
      'match_status': matchStatus,
      'next_eligible_date':
          nextEligibleDate
              ?.toUtc()
              .toIso8601String(),
      'last_donation_date':
          lastDonationDate
              ?.toUtc()
              .toIso8601String(),
    };
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  EmergencyDonorModel copyWith({
    String? donorId,
    String? userId,
    String? donorName,
    String? phone,
    String? bloodGroupId,
    String? bloodGroup,
    String? cityId,
    bool? isAvailable,
    bool? isEligible,
    double? distanceKm,
    String? matchStatus,
    DateTime? nextEligibleDate,
    DateTime? lastDonationDate,
  }) {
    return EmergencyDonorModel(
      donorId:
          donorId ?? this.donorId,

      userId:
          userId ?? this.userId,

      donorName:
          donorName ?? this.donorName,

      phone:
          phone ?? this.phone,

      bloodGroupId:
          bloodGroupId ??
          this.bloodGroupId,

      bloodGroup:
          bloodGroup ?? this.bloodGroup,

      cityId:
          cityId ?? this.cityId,

      isAvailable:
          isAvailable ??
          this.isAvailable,

      isEligible:
          isEligible ??
          this.isEligible,

      distanceKm:
          distanceKm ?? this.distanceKm,

      matchStatus:
          matchStatus ?? this.matchStatus,

      nextEligibleDate:
          nextEligibleDate ??
          this.nextEligibleDate,

      lastDonationDate:
          lastDonationDate ??
          this.lastDonationDate,
    );
  }

  // ============================================================
  // HELPERS
  // ============================================================

  static bool _parseBool(
    dynamic value,
  ) {
    if (value is bool) {
      return value;
    }

    if (value is num) {
      return value != 0;
    }

    final text =
        value
            ?.toString()
            .toLowerCase();

    return text == 'true' ||
        text == '1';
  }

  static double? _parseDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString(),
    );
  }

  static DateTime? _parseDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value;
    }

    return DateTime.tryParse(
      value.toString(),
    );
  }

  // ============================================================
  // STATUS HELPERS
  // ============================================================

  bool get canBeContacted {
    return isAvailable &&
        isEligible;
  }

  bool get hasDistance {
    return distanceKm != null;
  }

  String get formattedDistance {
    if (distanceKm == null) {
      return 'Distance unavailable';
    }

    if (distanceKm! < 1) {
      return '${(distanceKm! * 1000).round()} m away';
    }

    return '${distanceKm!.toStringAsFixed(1)} km away';
  }
}