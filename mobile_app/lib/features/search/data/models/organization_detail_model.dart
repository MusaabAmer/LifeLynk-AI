import 'blood_inventory_model.dart';
import 'service_model.dart';

class OrganizationDetailModel {
  final String id;
  final String organizationId;

  final String organizationName;
  final String organizationType;

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

  final List<BloodInventoryModel> inventory;
  final List<ServiceModel> services;

  final double rating;
  final int reviewCount;

  final bool isVerified;
  final bool isOpen;

  const OrganizationDetailModel({
    required this.id,
    required this.organizationId,
    required this.organizationName,
    required this.organizationType,
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
    this.inventory = const [],
    this.services = const [],
    this.rating = 0.0,
    this.reviewCount = 0,
    this.isVerified = false,
    this.isOpen = true,
  });

  factory OrganizationDetailModel.fromJson(
    Map<String, dynamic> json,
  ) {
    final organizationId =
        json['organization_id']?.toString() ??
        json['id']?.toString() ??
        '';

    final organizationType =
        json['organization_type']?.toString() ??
        json['type']?.toString() ??
        '';

    /*
     * Hospital-specific real database data.
     */
    final hospital = json['hospital'] is Map
        ? Map<String, dynamic>.from(
            json['hospital'] as Map,
          )
        : null;

    /*
     * Blood-bank-specific real database data.
     */
    final bloodBank = json['blood_bank'] is Map
        ? Map<String, dynamic>.from(
            json['blood_bank'] as Map,
          )
        : null;

    /*
     * License number can come from the hospital
     * or blood-bank table.
     */
    final licenseNumber =
        json['license_number']?.toString() ??
        hospital?['license_number']?.toString() ??
        bloodBank?['license_number']?.toString();

    /*
     * Operating hours currently exist as a real
     * field on blood_banks.
     */
    final operatingHours =
        json['operating_hours']?.toString() ??
        bloodBank?['operating_hours']?.toString();

    /*
     * Parse real inventory returned by FastAPI.
     */
    final inventoryJson = json['inventory'];

    final inventory = inventoryJson is List
        ? inventoryJson
            .whereType<Map>()
            .map(
              (item) => BloodInventoryModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : const <BloodInventoryModel>[];

    /*
     * Parse real organization capabilities/services
     * returned by FastAPI.
     */
    final servicesJson = json['services'];

    final services = servicesJson is List
        ? servicesJson
            .whereType<Map>()
            .map(
              (item) => ServiceModel.fromJson(
                Map<String, dynamic>.from(item),
              ),
            )
            .toList()
        : const <ServiceModel>[];

    return OrganizationDetailModel(
      id:
          json['id']?.toString() ??
          organizationId,
      organizationId: organizationId,

      organizationName:
          json['organization_name']?.toString() ??
          json['name']?.toString() ??
          '',

      organizationType: organizationType,

      province:
          json['province']?.toString() ?? '',

      city:
          json['city']?.toString() ?? '',

      address:
          json['address']?.toString() ?? '',

      phone:
          json['phone']?.toString(),

      email:
          json['email']?.toString(),

      website:
          json['website']?.toString(),

      licenseNumber:
          licenseNumber,

      operatingHours:
          operatingHours,

      latitude:
          (json['latitude'] as num?)?.toDouble(),

      longitude:
          (json['longitude'] as num?)?.toDouble(),

      inventory:
          inventory,

      services:
          services,

      rating:
          (json['rating'] as num?)?.toDouble() ?? 0.0,

      reviewCount:
          (json['review_count'] as num?)?.toInt() ?? 0,

      isVerified:
          json['is_verified'] as bool? ??
          json['verification_status']
                  ?.toString()
                  .toUpperCase() ==
              'VERIFIED',

      isOpen:
          json['is_open'] as bool? ?? true,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'organization_id': organizationId,
      'organization_name': organizationName,
      'organization_type': organizationType,
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
      'inventory': inventory
          .map((item) => item.toJson())
          .toList(),
      'services': services
          .map((item) => item.toJson())
          .toList(),
      'rating': rating,
      'review_count': reviewCount,
      'is_verified': isVerified,
      'is_open': isOpen,
    };
  }
}