class SearchResultModel {
  final String id;
  final String organizationId;
  final String organizationName;
  final String organizationType;

  final String bloodGroup;
  final int availableUnits;

  final String province;
  final String city;
  final String address;

  final String? phone;
  final String? email;
  final String? website;

  final String? licenseNumber;
  final String? operatingHours;

  final double? latitude;
  final double? longitude;
  final double? distanceKm;

  final double? rating;
  final int? reviewCount;

  final List<String> services;

  final bool isVerified;
  final bool isOpen;

  const SearchResultModel({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.organizationType,
    required this.bloodGroup,
    required this.availableUnits,
    required this.province,
    required this.city,
    required this.address,
    this.phone,
    this.email,
    this.website,
    this.licenseNumber,
    this.operatingHours,
    this.latitude,
    this.longitude,
    this.distanceKm,
    this.rating,
    this.reviewCount,
    this.services = const [],
    this.isVerified = false,
    this.isOpen = true,
  });

  factory SearchResultModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final organizationId =
        json['organization_id']?.toString() ??
        json['id']?.toString() ??
        '';

    final verificationStatus =
        json['verification_status']?.toString().toUpperCase();

    return SearchResultModel(
      id: json['id']?.toString() ?? organizationId,
      organizationId: organizationId,

      organizationName:
          json['organization_name']?.toString() ??
          json['name']?.toString() ??
          '',

      organizationType:
          json['organization_type']?.toString() ??
          json['type']?.toString() ??
          '',

      bloodGroup:
          json['blood_group']?.toString() ?? '',

      availableUnits:
          (json['available_units'] as num?)?.toInt() ?? 0,

      province:
          json['province']?.toString() ?? '',

      city:
          json['city']?.toString() ?? '',

      address:
          json['address']?.toString() ?? '',

      phone:
          _nullableString(json['phone']),

      email:
          _nullableString(json['email']),

      website:
          _nullableString(json['website']),

      licenseNumber:
          _nullableString(json['license_number']),

      operatingHours:
          _nullableString(json['operating_hours']),

      latitude:
          (json['latitude'] as num?)?.toDouble(),

      longitude:
          (json['longitude'] as num?)?.toDouble(),

      distanceKm:
          (json['distance_km'] as num?)?.toDouble(),

      rating:
          (json['rating'] as num?)?.toDouble(),

      reviewCount:
          (json['review_count'] as num?)?.toInt(),

      services: json['services'] is List
          ? (json['services'] as List)
              .map((item) => item.toString())
              .toList()
          : const [],

      isVerified:
          json['is_verified'] as bool? ??
          verificationStatus == 'VERIFIED',

      isOpen:
          json['is_open'] as bool? ?? true,
    );
  }

  static String? _nullableString(dynamic value) {
    final text = value?.toString().trim();

    if (text == null || text.isEmpty) {
      return null;
    }

    return text;
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'organization_name': organizationName,
      'organization_type': organizationType,
      'blood_group': bloodGroup,
      'available_units': availableUnits,
      'province': province,
      'city': city,
      'address': address,
      'phone': phone,
      'email': email,
      'website': website,
      'license_number': licenseNumber,
      'operating_hours': operatingHours,
      'latitude': latitude,
      'longitude': longitude,
      'distance_km': distanceKm,
      'rating': rating,
      'review_count': reviewCount,
      'services': services,
      'is_verified': isVerified,
      'is_open': isOpen,
    };
  }
}