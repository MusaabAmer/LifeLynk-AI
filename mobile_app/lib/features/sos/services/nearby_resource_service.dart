import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../data/models/nearby_resource_model.dart';

class NearbyResourceService {
  final SupabaseClient supabase;

  NearbyResourceService({
    SupabaseClient? supabase,
  }) : supabase = supabase ?? Supabase.instance.client;

  // ============================================================
  // CONFIGURATION
  // ============================================================

  /// Maximum distance from the emergency GPS location.
  static const double _maxSearchRadiusKm = 50.0;

  /// Maximum number of nearby resources returned.
  static const int _maxResults = 30;

  // ============================================================
  // FIND NEARBY RESOURCES
  // ============================================================

  Future<List<NearbyResourceModel>> findNearbyResources({
    required double latitude,
    required double longitude,
    String? bloodGroupId,
  }) async {
    final resources = <NearbyResourceModel>[];

    // ==========================================================
    // VALIDATE USER LOCATION
    // ==========================================================

    if (!_isValidLatitude(latitude)) {
      throw Exception(
        'Invalid emergency latitude.',
      );
    }

    if (!_isValidLongitude(longitude)) {
      throw Exception(
        'Invalid emergency longitude.',
      );
    }

    try {
      // ========================================================
      // NORMALIZE BLOOD GROUP ID
      // ========================================================

      final normalizedBloodGroupId =
          bloodGroupId?.trim();

      // ========================================================
      // RESOLVE BLOOD GROUP CODE
      // ========================================================

      String? bloodGroupCode;

      if (normalizedBloodGroupId != null &&
          normalizedBloodGroupId.isNotEmpty) {
        bloodGroupCode =
            await _getBloodGroupCode(
          normalizedBloodGroupId,
        );
      }

      // ========================================================
      // 1. LOAD ORGANIZATIONS
      // ========================================================

      await _loadOrganizations(
        resources: resources,
        latitude: latitude,
        longitude: longitude,
        bloodGroupId: normalizedBloodGroupId,
        bloodGroupCode: bloodGroupCode,
      );

      // ========================================================
      // 2. LOAD DONORS
      // ========================================================

      await _loadDonors(
        resources: resources,
        latitude: latitude,
        longitude: longitude,
        bloodGroupId: normalizedBloodGroupId,
        bloodGroupCode: bloodGroupCode,
      );

      // ========================================================
      // SORT BY DISTANCE
      // ========================================================

      resources.sort(
        (a, b) => a.distanceKm.compareTo(
          b.distanceKm,
        ),
      );

      // ========================================================
      // LIMIT RESULTS
      // ========================================================

      if (resources.length > _maxResults) {
        return resources.sublist(
          0,
          _maxResults,
        );
      }

      return resources;
    } on PostgrestException catch (e) {
      throw Exception(
        'Unable to load nearby emergency resources: '
        '${e.message}',
      );
    } catch (e) {
      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to load nearby emergency resources.',
      );
    }
  }

  // ============================================================
  // LOAD ORGANIZATIONS
  // ============================================================

  Future<void> _loadOrganizations({
    required List<NearbyResourceModel> resources,
    required double latitude,
    required double longitude,
    required String? bloodGroupId,
    required String? bloodGroupCode,
  }) async {
    // ==========================================================
    // LOAD ORGANIZATIONS
    // ==========================================================

    final response = await supabase
        .from('organizations')
        .select(
          '''
          id,
          name,
          organization_type,
          phone,
          email,
          address,
          latitude,
          longitude,
          verification_status,
          deleted_at
          ''',
        )
        .isFilter(
          'deleted_at',
          null,
        );

    // ==========================================================
    // PREPARE ORGANIZATION DATA
    // ==========================================================

    final organizations =
        <Map<String, dynamic>>[];

    for (final raw in response) {
      final organization =
          Map<String, dynamic>.from(raw);

      // ========================================================
      // ORGANIZATION ID
      // ========================================================

      final organizationId =
          organization['id']
              ?.toString()
              .trim();

      if (organizationId == null ||
          organizationId.isEmpty) {
        continue;
      }

      // ========================================================
      // ORGANIZATION NAME
      // ========================================================

      final organizationName =
          organization['name']
              ?.toString()
              .trim();

      if (organizationName == null ||
          organizationName.isEmpty) {
        continue;
      }

      // ========================================================
      // GPS
      // ========================================================

      final organizationLatitude =
          _toDouble(
        organization['latitude'],
      );

      final organizationLongitude =
          _toDouble(
        organization['longitude'],
      );

      if (organizationLatitude == null ||
          organizationLongitude == null) {
        continue;
      }

      if (!_isValidLatitude(
        organizationLatitude,
      )) {
        continue;
      }

      if (!_isValidLongitude(
        organizationLongitude,
      )) {
        continue;
      }

      // ========================================================
      // ORGANIZATION TYPE
      // ========================================================

      final organizationType =
          organization['organization_type']
              ?.toString()
              .trim()
              .toLowerCase();

      NearbyResourceType? resourceType;

      if (_isHospitalType(
        organizationType,
      )) {
        resourceType =
            NearbyResourceType.hospital;
      } else if (_isBloodBankType(
        organizationType,
      )) {
        resourceType =
            NearbyResourceType.bloodBank;
      }

      if (resourceType == null) {
        continue;
      }

      // ========================================================
      // VERIFICATION
      // ========================================================

      final verificationStatus =
          organization['verification_status']
              ?.toString()
              .trim()
              .toLowerCase();

      if (_shouldExcludeVerificationStatus(
        verificationStatus,
      )) {
        continue;
      }

      // ========================================================
      // DISTANCE
      // ========================================================

      final distanceKm =
          _calculateDistanceKm(
        latitude,
        longitude,
        organizationLatitude,
        organizationLongitude,
      );

      if (distanceKm >
          _maxSearchRadiusKm) {
        continue;
      }

      // ========================================================
      // STORE VALID ORGANIZATION
      // ========================================================

      organizations.add({
        'id': organizationId,
        'name': organizationName,
        'type': resourceType,
        'latitude': organizationLatitude,
        'longitude': organizationLongitude,
        'distanceKm': distanceKm,
        'phone': organization['phone'],
        'address': organization['address'],
      });
    }

    // ==========================================================
    // LOAD BLOOD INVENTORY IN ONE QUERY
    // ==========================================================

    final inventoryByOrganization =
        <String, int>{};

    if (bloodGroupId != null &&
        bloodGroupId.isNotEmpty &&
        organizations.isNotEmpty) {
      final organizationIds =
          organizations
              .map(
                (organization) =>
                    organization['id']
                        .toString(),
              )
              .toList();

      final inventoryResponse =
          await supabase
              .from('blood_inventory')
              .select(
                '''
                organization_id,
                available_units,
                status,
                expiry_date
                ''',
              )
              .inFilter(
                'organization_id',
                organizationIds,
              )
              .eq(
                'blood_group_id',
                bloodGroupId,
              );

      final now =
          DateTime.now().toUtc();

      for (final raw
          in inventoryResponse) {
        final item =
            Map<String, dynamic>.from(raw);

        final organizationId =
            item['organization_id']
                ?.toString()
                .trim();

        if (organizationId == null ||
            organizationId.isEmpty) {
          continue;
        }

        // ======================================================
        // INVENTORY STATUS
        // ======================================================

        final status =
            item['status']
                ?.toString()
                .trim()
                .toLowerCase();

        if (status != null &&
            status.isNotEmpty &&
            !_isActiveInventoryStatus(
              status,
            )) {
          continue;
        }

        // ======================================================
        // EXPIRY
        // ======================================================

        final expiryDate =
            _parseDateTime(
          item['expiry_date'],
        );

        if (expiryDate != null &&
            expiryDate.isBefore(now)) {
          continue;
        }

        // ======================================================
        // AVAILABLE UNITS
        // ======================================================

        final units =
            _toInt(
          item['available_units'],
        );

        if (units <= 0) {
          continue;
        }

        inventoryByOrganization[
                organizationId] =
            (inventoryByOrganization[
                    organizationId] ??
                0) +
            units;
      }
    }

    // ==========================================================
    // CONVERT ORGANIZATIONS TO RESOURCES
    // ==========================================================

    for (final organization
        in organizations) {
      final organizationId =
          organization['id']
              .toString();

      final organizationName =
          organization['name']
              .toString();

      final resourceType =
          organization['type']
              as NearbyResourceType;

      final organizationLatitude =
          organization['latitude']
              as double;

      final organizationLongitude =
          organization['longitude']
              as double;

      final distanceKm =
          organization['distanceKm']
              as double;

      // ========================================================
      // PHONE
      // ========================================================

      final organizationPhone =
          organization['phone']
              ?.toString()
              .trim();

      final phone =
          organizationPhone != null &&
                  organizationPhone.isNotEmpty
              ? organizationPhone
              : null;

      // ========================================================
      // ADDRESS
      // ========================================================

      final organizationAddress =
          organization['address']
              ?.toString()
              .trim();

      final address =
          organizationAddress != null &&
                  organizationAddress.isNotEmpty
              ? organizationAddress
              : null;

      // ========================================================
      // AVAILABLE BLOOD UNITS
      // ========================================================

      int? availableUnits;

      if (bloodGroupId != null &&
          bloodGroupId.isNotEmpty) {
        availableUnits =
            inventoryByOrganization[
                    organizationId] ??
                0;
      }

      // ========================================================
      // ADD RESOURCE
      // ========================================================

      resources.add(
        NearbyResourceModel(
          id: organizationId,
          name: organizationName,
          type: resourceType,
          latitude: organizationLatitude,
          longitude: organizationLongitude,
          distanceKm: distanceKm,
          estimatedTravelTimeMinutes: null,
          availableUnits: availableUnits,
          bloodGroup: bloodGroupCode,
          emergencyContact: phone,
          phone: phone,
          address: address,
        ),
      );
    }
  }

  // ============================================================
  // LOAD DONORS
  // ============================================================

  Future<void> _loadDonors({
    required List<NearbyResourceModel> resources,
    required double latitude,
    required double longitude,
    required String? bloodGroupId,
    required String? bloodGroupCode,
  }) async {
    // ==========================================================
    // WITHOUT BLOOD GROUP
    // ==========================================================
    //
    // We should not expose every donor when the SOS has no
    // blood-group requirement.
    //
    // Therefore donor discovery requires bloodGroupId.
    //
    // ==========================================================

    if (bloodGroupId == null ||
        bloodGroupId.isEmpty) {
      return;
    }

    // ==========================================================
    // LOAD DONORS
    // ==========================================================

    final response = await supabase
        .from('donors')
        .select(
          '''
          id,
          user_id,
          blood_group_id,
          city_id,
          phone_number,
          date_of_birth,
          gender,
          is_available,
          total_donations,
          last_donation_date,
          created_at,
          updated_at
          ''',
        )
        .eq(
          'blood_group_id',
          bloodGroupId,
        )
        .eq(
          'is_available',
          true,
        );

    // ==========================================================
    // PREPARE DONORS
    // ==========================================================

    final donors =
        <Map<String, dynamic>>[];

    final cityIds = <String>{};
    final userIds = <String>{};

    for (final raw in response) {
      final donor =
          Map<String, dynamic>.from(raw);

      // ========================================================
      // DONOR ID
      // ========================================================

      final donorId =
          donor['id']
              ?.toString()
              .trim();

      if (donorId == null ||
          donorId.isEmpty) {
        continue;
      }

      // ========================================================
      // USER ID
      // ========================================================

      final userId =
          donor['user_id']
              ?.toString()
              .trim();

      if (userId == null ||
          userId.isEmpty) {
        continue;
      }

      // ========================================================
      // CITY ID
      // ========================================================

      final cityId =
          donor['city_id']
              ?.toString()
              .trim();

      if (cityId == null ||
          cityId.isEmpty) {
        continue;
      }

      donors.add({
        'id': donorId,
        'user_id': userId,
        'city_id': cityId,
        'phone_number':
            donor['phone_number'],
      });

      cityIds.add(cityId);
      userIds.add(userId);
    }

    if (donors.isEmpty) {
      return;
    }

    // ==========================================================
    // LOAD CITIES IN ONE QUERY
    // ==========================================================

    final citiesById =
        <String, Map<String, dynamic>>{};

    if (cityIds.isNotEmpty) {
      final cityResponse =
          await supabase
              .from('cities')
              .select(
                '''
                id,
                name,
                latitude,
                longitude,
                deleted_at
                ''',
              )
              .inFilter(
                'id',
                cityIds.toList(),
              )
              .isFilter(
                'deleted_at',
                null,
              );

      for (final raw
          in cityResponse) {
        final city =
            Map<String, dynamic>.from(raw);

        final cityId =
            city['id']
                ?.toString()
                .trim();

        if (cityId == null ||
            cityId.isEmpty) {
          continue;
        }

        final cityLatitude =
            _toDouble(
          city['latitude'],
        );

        final cityLongitude =
            _toDouble(
          city['longitude'],
        );

        if (cityLatitude == null ||
            cityLongitude == null) {
          continue;
        }

        if (!_isValidLatitude(
          cityLatitude,
        )) {
          continue;
        }

        if (!_isValidLongitude(
          cityLongitude,
        )) {
          continue;
        }

        citiesById[cityId] = {
          'latitude': cityLatitude,
          'longitude': cityLongitude,
        };
      }
    }

    // ==========================================================
    // LOAD USERS IN ONE QUERY
    // ==========================================================

    final usersById =
        <String, Map<String, dynamic>>{};

    if (userIds.isNotEmpty) {
      final userResponse =
          await supabase
              .from('users')
              .select(
                '''
                id,
                full_name,
                phone_number,
                is_active,
                is_verified,
                deleted_at
                ''',
              )
              .inFilter(
                'id',
                userIds.toList(),
              )
              .isFilter(
                'deleted_at',
                null,
              );

      for (final raw
          in userResponse) {
        final user =
            Map<String, dynamic>.from(raw);

        final userId =
            user['id']
                ?.toString()
                .trim();

        if (userId == null ||
            userId.isEmpty) {
          continue;
        }

        usersById[userId] = user;
      }
    }

    // ==========================================================
    // BUILD DONOR RESOURCES
    // ==========================================================

    for (final donor in donors) {
      final donorId =
          donor['id']
              .toString();

      final userId =
          donor['user_id']
              .toString();

      final cityId =
          donor['city_id']
              .toString();

      // ========================================================
      // CITY
      // ========================================================

      final city =
          citiesById[cityId];

      if (city == null) {
        continue;
      }

      final donorLatitude =
          city['latitude'] as double;

      final donorLongitude =
          city['longitude'] as double;

      // ========================================================
      // CALCULATE DISTANCE
      // ========================================================

      final distanceKm =
          _calculateDistanceKm(
        latitude,
        longitude,
        donorLatitude,
        donorLongitude,
      );

      if (distanceKm >
          _maxSearchRadiusKm) {
        continue;
      }

      // ========================================================
      // USER
      // ========================================================

      final user =
          usersById[userId];

      if (user == null) {
        continue;
      }

      // ========================================================
      // USER ACTIVE CHECK
      // ========================================================

      final isActive =
          user['is_active'] == true;

      if (!isActive) {
        continue;
      }

      // ========================================================
      // USER VERIFIED CHECK
      // ========================================================

      final isVerified =
          user['is_verified'] == true;

      if (!isVerified) {
        continue;
      }

      // ========================================================
      // DONOR NAME
      // ========================================================

      final fullName =
          user['full_name']
              ?.toString()
              .trim();

      final donorName =
          fullName != null &&
                  fullName.isNotEmpty
              ? fullName
              : 'Available Donor';

      // ========================================================
      // PHONE
      // ========================================================

      final donorPhone =
          donor['phone_number']
              ?.toString()
              .trim();

      final userPhone =
          user['phone_number']
              ?.toString()
              .trim();

      String? phone;

      if (donorPhone != null &&
          donorPhone.isNotEmpty) {
        phone = donorPhone;
      } else if (userPhone != null &&
          userPhone.isNotEmpty) {
        phone = userPhone;
      }

      // ========================================================
      // ADD DONOR RESOURCE
      // ========================================================

      resources.add(
        NearbyResourceModel(
          id: donorId,
          name: donorName,
          type: NearbyResourceType.donor,
          latitude: donorLatitude,
          longitude: donorLongitude,
          distanceKm: distanceKm,
          estimatedTravelTimeMinutes: null,

          // A donor represents one potential donor,
          // not one guaranteed blood unit.
          availableUnits: 1,

          bloodGroup: bloodGroupCode,
          emergencyContact: phone,
          phone: phone,

          // Intentionally null.
          //
          // Donor's exact physical address is not exposed.
          // Location is represented by city coordinates.
          address: null,
        ),
      );
    }
  }

  // ============================================================
  // GET BLOOD GROUP CODE
  // ============================================================

  Future<String?> _getBloodGroupCode(
    String bloodGroupId,
  ) async {
    try {
      final response =
          await supabase
              .from('blood_groups')
              .select(
                '''
                id,
                code,
                name
                ''',
              )
              .eq(
                'id',
                bloodGroupId,
              )
              .isFilter(
                'deleted_at',
                null,
              )
              .maybeSingle();

      if (response == null) {
        return null;
      }

      final code =
          response['code']
              ?.toString()
              .trim();

      if (code != null &&
          code.isNotEmpty) {
        return code;
      }

      final name =
          response['name']
              ?.toString()
              .trim();

      if (name != null &&
          name.isNotEmpty) {
        return name;
      }

      return null;
    } on PostgrestException {
      return null;
    } catch (_) {
      return null;
    }
  }

  // ============================================================
  // HOSPITAL TYPE
  // ============================================================

  bool _isHospitalType(
    String? type,
  ) {
    if (type == null ||
        type.isEmpty) {
      return false;
    }

    final normalized =
        type.trim().toLowerCase();

    return normalized == 'hospital' ||
        normalized.contains('hospital');
  }

  // ============================================================
  // BLOOD BANK TYPE
  // ============================================================

  bool _isBloodBankType(
    String? type,
  ) {
    if (type == null ||
        type.isEmpty) {
      return false;
    }

    final normalized =
        type.trim().toLowerCase();

    return normalized == 'blood_bank' ||
        normalized == 'blood bank' ||
        normalized == 'bloodbank' ||
        normalized.contains(
          'blood_bank',
        ) ||
        normalized.contains(
          'blood bank',
        );
  }

  // ============================================================
  // VERIFICATION STATUS
  // ============================================================

  bool _shouldExcludeVerificationStatus(
    String? status,
  ) {
    if (status == null ||
        status.isEmpty) {
      return false;
    }

    return status == 'rejected' ||
        status == 'suspended' ||
        status == 'blocked' ||
        status == 'unverified';
  }

  // ============================================================
  // ACTIVE INVENTORY STATUS
  // ============================================================

  bool _isActiveInventoryStatus(
    String status,
  ) {
    return status == 'available' ||
        status == 'active' ||
        status == 'in_stock' ||
        status == 'in-stock';
  }

  // ============================================================
  // HAVERSINE DISTANCE
  // ============================================================

  double _calculateDistanceKm(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const earthRadiusKm = 6371.0;

    final latitudeDifference =
        _degreesToRadians(
      latitude2 - latitude1,
    );

    final longitudeDifference =
        _degreesToRadians(
      longitude2 - longitude1,
    );

    final latitude1Radians =
        _degreesToRadians(
      latitude1,
    );

    final latitude2Radians =
        _degreesToRadians(
      latitude2,
    );

    final a =
        math.sin(
              latitudeDifference / 2,
            ) *
            math.sin(
              latitudeDifference / 2,
            ) +
        math.cos(
              latitude1Radians,
            ) *
            math.cos(
              latitude2Radians,
            ) *
            math.sin(
              longitudeDifference / 2,
            ) *
            math.sin(
              longitudeDifference / 2,
            );

    final safeA =
        a.clamp(
      0.0,
      1.0,
    );

    final c =
        2 *
        math.atan2(
          math.sqrt(
            safeA,
          ),
          math.sqrt(
            1 - safeA,
          ),
        );

    return earthRadiusKm * c;
  }

  // ============================================================
  // DEGREES → RADIANS
  // ============================================================

  double _degreesToRadians(
    double degrees,
  ) {
    return degrees *
        math.pi /
        180.0;
  }

  // ============================================================
  // LATITUDE VALIDATION
  // ============================================================

  bool _isValidLatitude(
    double latitude,
  ) {
    return latitude >= -90.0 &&
        latitude <= 90.0;
  }

  // ============================================================
  // LONGITUDE VALIDATION
  // ============================================================

  bool _isValidLongitude(
    double longitude,
  ) {
    return longitude >= -180.0 &&
        longitude <= 180.0;
  }

  // ============================================================
  // DOUBLE PARSER
  // ============================================================

  double? _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is double) {
      return value;
    }

    if (value is num) {
      return value.toDouble();
    }

    return double.tryParse(
      value.toString().trim(),
    );
  }

  // ============================================================
  // INTEGER PARSER
  // ============================================================

  int _toInt(
    dynamic value,
  ) {
    if (value == null) {
      return 0;
    }

    if (value is int) {
      return value;
    }

    if (value is num) {
      return value.toInt();
    }

    return int.tryParse(
          value.toString().trim(),
        ) ??
        0;
  }

  // ============================================================
  // DATETIME PARSER
  // ============================================================

  DateTime? _parseDateTime(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is DateTime) {
      return value.toUtc();
    }

    return DateTime.tryParse(
      value.toString(),
    )?.toUtc();
  }
}