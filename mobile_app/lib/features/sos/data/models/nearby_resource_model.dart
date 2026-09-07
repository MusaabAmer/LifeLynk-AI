/// Type of nearby emergency resource.
enum NearbyResourceType {
  hospital,
  bloodBank,
  donor,
}

/// Represents a nearby emergency resource.
///
/// This model is intentionally independent of:
/// - SOS state
/// - SosProvider
/// - emergency_sos

/// - navigation services
///
/// It only represents resource information that can be displayed,
/// filtered, sorted, or passed to navigation.
class NearbyResourceModel {
  // ============================================================
  // BASIC INFORMATION
  // ============================================================

  final String id;
  final String name;
  final NearbyResourceType type;

  // ============================================================
  // LOCATION
  // ============================================================

  final double latitude;
  final double longitude;

  // ============================================================
  // DISTANCE / TRAVEL
  // ============================================================

  /// Straight-line distance from the user's current location.
  ///
  /// This value is normally calculated by
  /// NearbyResourceService.
  final double distanceKm;

  /// Optional estimated road travel time.
  ///
  /// Nullable because NearbyResourceService may only calculate
  /// straight-line distance.
  final int? estimatedTravelTimeMinutes;

  // ============================================================
  // BLOOD INFORMATION
  // ============================================================

  /// Total available blood units for the requested blood group.
  ///
  /// null:
  ///   Availability was not requested/calculated.
  ///
  /// 0:
  ///   No units are currently available.
  ///
  /// > 0:
  ///   Units are available.
  final int? availableUnits;

  /// Blood group associated with this resource.
  ///
  /// Examples:
  /// - O+
  /// - A+
  /// - B+
  /// - AB+
  final String? bloodGroup;

  // ============================================================
  // CONTACT
  // ============================================================

  /// Primary emergency contact number.
  final String? emergencyContact;

  /// General organization phone number.
  final String? phone;

  // ============================================================
  // ADDRESS
  // ============================================================

  /// Physical address of the resource.
  final String? address;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  const NearbyResourceModel({
    required this.id,
    required this.name,
    required this.type,
    required this.latitude,
    required this.longitude,
    required this.distanceKm,
    this.estimatedTravelTimeMinutes,
    this.availableUnits,
    this.bloodGroup,
    this.emergencyContact,
    this.phone,
    this.address,
  });

  // ============================================================
  // RESOURCE TYPE HELPERS
  // ============================================================

  bool get isHospital =>
      type == NearbyResourceType.hospital;

  bool get isBloodBank =>
      type == NearbyResourceType.bloodBank;

  bool get isDonor =>
      type == NearbyResourceType.donor;

  // ============================================================
  // TYPE LABEL
  // ============================================================

  String get typeLabel {
    switch (type) {
      case NearbyResourceType.hospital:
        return 'Hospital';

      case NearbyResourceType.bloodBank:
        return 'Blood Bank';

      case NearbyResourceType.donor:
        return 'Donor';
    }
  }

  // ============================================================
  // BLOOD AVAILABILITY
  // ============================================================

  /// Returns true when blood availability is known and at least
  /// one unit is available.
  bool get hasBloodAvailability =>
      availableUnits != null &&
      availableUnits! > 0;

  /// Returns true when an availability value was supplied,
  /// including zero.
  bool get hasAvailabilityData =>
      availableUnits != null;

  // ============================================================
  // AVAILABILITY LABEL
  // ============================================================

  String get availabilityLabel {
    final units = availableUnits;

    if (units == null) {
      return 'Availability unavailable';
    }

    if (units <= 0) {
      return 'No units available';
    }

    if (units == 1) {
      return '1 unit available';
    }

    return '$units units available';
  }

  // ============================================================
  // DISTANCE LABEL
  // ============================================================

  String get distanceLabel {
    if (distanceKm < 0) {
      return 'Distance unavailable';
    }

    if (distanceKm < 1) {
      final meters = (distanceKm * 1000).round();

      if (meters <= 0) {
        return '<1 m';
      }

      return '$meters m';
    }

    return '${distanceKm.toStringAsFixed(1)} km';
  }

  // ============================================================
  // TRAVEL TIME LABEL
  // ============================================================

  String get travelTimeLabel {
    final minutes = estimatedTravelTimeMinutes;

    if (minutes == null || minutes < 0) {
      return 'Travel time unavailable';
    }

    if (minutes < 60) {
      return '~$minutes min';
    }

    final hours = minutes ~/ 60;
    final remainingMinutes = minutes % 60;

    if (remainingMinutes == 0) {
      return '~${hours}h';
    }

    return '~${hours}h ${remainingMinutes}m';
  }

  // ============================================================
  // CONTACT HELPERS
  // ============================================================

  /// Returns the best available contact number.
  ///
  /// Emergency contact takes priority over the general phone.
  String? get contactNumber {
    final emergency = emergencyContact?.trim();

    if (emergency != null && emergency.isNotEmpty) {
      return emergency;
    }

    final generalPhone = phone?.trim();

    if (generalPhone != null && generalPhone.isNotEmpty) {
      return generalPhone;
    }

    return null;
  }

  bool get hasContactNumber =>
      contactNumber != null;

  bool get hasEmergencyContact {
    final value = emergencyContact?.trim();

    return value != null && value.isNotEmpty;
  }

  bool get hasPhone {
    final value = phone?.trim();

    return value != null && value.isNotEmpty;
  }

  // ============================================================
  // ADDRESS HELPERS
  // ============================================================

  bool get hasAddress {
    final value = address?.trim();

    return value != null && value.isNotEmpty;
  }

  // ============================================================
  // LOCATION HELPERS
  // ============================================================

  bool get hasValidLocation {
    return latitude >= -90.0 &&
        latitude <= 90.0 &&
        longitude >= -180.0 &&
        longitude <= 180.0;
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  /// Creates a copy of this model with updated values.
  ///
  /// Note:
  /// Nullable values intentionally use [clearX] flags so that
  /// an existing nullable value can be explicitly cleared.
  NearbyResourceModel copyWith({
    String? id,
    String? name,
    NearbyResourceType? type,
    double? latitude,
    double? longitude,
    double? distanceKm,

    int? estimatedTravelTimeMinutes,
    bool clearEstimatedTravelTime = false,

    int? availableUnits,
    bool clearAvailableUnits = false,

    String? bloodGroup,
    bool clearBloodGroup = false,

    String? emergencyContact,
    bool clearEmergencyContact = false,

    String? phone,
    bool clearPhone = false,

    String? address,
    bool clearAddress = false,
  }) {
    return NearbyResourceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      type: type ?? this.type,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      distanceKm: distanceKm ?? this.distanceKm,

      estimatedTravelTimeMinutes:
          clearEstimatedTravelTime
              ? null
              : estimatedTravelTimeMinutes ??
                  this.estimatedTravelTimeMinutes,

      availableUnits:
          clearAvailableUnits
              ? null
              : availableUnits ?? this.availableUnits,

      bloodGroup:
          clearBloodGroup
              ? null
              : bloodGroup ?? this.bloodGroup,

      emergencyContact:
          clearEmergencyContact
              ? null
              : emergencyContact ?? this.emergencyContact,

      phone:
          clearPhone
              ? null
              : phone ?? this.phone,

      address:
          clearAddress
              ? null
              : address ?? this.address,
    );
  }

  // ============================================================
  // DEBUG
  // ============================================================

  @override
  String toString() {
    return 'NearbyResourceModel('
        'id: $id, '
        'name: $name, '
        'type: $type, '
        'latitude: $latitude, '
        'longitude: $longitude, '
        'distanceKm: $distanceKm, '
        'estimatedTravelTimeMinutes: '
        '$estimatedTravelTimeMinutes, '
        'availableUnits: $availableUnits, '
        'bloodGroup: $bloodGroup'
        ')';
  }
}