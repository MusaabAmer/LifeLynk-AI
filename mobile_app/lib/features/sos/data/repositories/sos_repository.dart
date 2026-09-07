import 'dart:math' as math;

import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/emergency_sos_model.dart';

class SosRepository {
  final SupabaseClient supabase;

  SosRepository({
    required this.supabase,
  });

  // ============================================================
  // STATUS DEFINITIONS
  // ============================================================

  static const List<String> activeStatuses = [
    'pending',
    'matched',
    'in_progress',
  ];

  static const List<String> terminalStatuses = [
    'completed',
    'cancelled',
  ];

  static const List<String> allStatuses = [
    'pending',
    'matched',
    'in_progress',
    'completed',
    'cancelled',
  ];

  // ============================================================
  // USER BLOOD GROUP
  // ============================================================

  /// Returns the blood group ID currently stored against the
  /// authenticated patient's profile.
  ///
  /// This is used as the initial/default SOS blood group.
  /// Selecting another blood group in the SOS UI does not modify
  /// the patient's profile.
  Future<String?> getUserBloodGroupId(
    String userId,
  ) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return null;
    }

    final response = await supabase
        .from('patients')
        .select('blood_group_id')
        .eq(
          'user_id',
          normalizedUserId,
        )
        .isFilter(
          'deleted_at',
          null,
        )
        .maybeSingle();

    return response?['blood_group_id']?.toString().trim();
  }

  // ============================================================
  // BLOOD GROUPS
  // ============================================================

  /// Loads the real blood groups from public.blood_groups.
  ///
  /// No blood groups are hard-coded here because the database is
  /// the source of truth.
  Future<List<Map<String, String>>> getBloodGroups() async {
    final response = await supabase
        .from('blood_groups')
        .select('id, code, name')
        .isFilter(
          'deleted_at',
          null,
        )
        .order(
          'code',
          ascending: true,
        );

    return response
        .map<Map<String, String>>((raw) {
          final id = raw['id']?.toString().trim() ?? '';
          final code = raw['code']?.toString().trim() ?? '';
          final name = raw['name']?.toString().trim() ?? '';

          return {
            'id': id,
            'code': code.isNotEmpty ? code : name,
            'name': name.isNotEmpty ? name : code,
          };
        })
        .where(
          (group) => group['id']!.isNotEmpty,
        )
        .toList();
  }

  // ============================================================
  // CREATE SOS
  // ============================================================

  Future<EmergencySosModel> createSos({
    required String userId,
    required String bloodGroupId,
    required int unitsRequired,
    required String urgencyLevel,
    String? description,
    required double latitude,
    required double longitude,
    double? gpsAccuracy,
    DateTime? locationTimestamp,
  }) async {
    final normalizedUserId = userId.trim();
    final normalizedBloodGroupId = bloodGroupId.trim();
    final urgency = urgencyLevel.trim().toLowerCase();

    if (normalizedUserId.isEmpty) {
      throw Exception(
        'User is not authenticated.',
      );
    }

    if (normalizedBloodGroupId.isEmpty) {
      throw Exception(
        'Blood group is required.',
      );
    }

    if (unitsRequired <= 0) {
      throw Exception(
        'Units required must be greater than zero.',
      );
    }

    if (!_isValidLatitude(latitude)) {
      throw Exception(
        'Invalid latitude.',
      );
    }

    if (!_isValidLongitude(longitude)) {
      throw Exception(
        'Invalid longitude.',
      );
    }

    if (gpsAccuracy != null &&
        (!gpsAccuracy.isFinite || gpsAccuracy < 0)) {
      throw Exception(
        'Invalid GPS accuracy.',
      );
    }

    if (urgency.isEmpty) {
      throw Exception(
        'Urgency level is required.',
      );
    }

    // ==========================================================
    // RESOLVE NEAREST CITY
    // ==========================================================

    final cityId = await _findNearestCityId(
      latitude: latitude,
      longitude: longitude,
    );

    // ==========================================================
    // BUILD DATABASE RECORD
    // ==========================================================

    final data = <String, dynamic>{
      'user_id': normalizedUserId,
      'blood_group_id': normalizedBloodGroupId,
      'city_id': cityId,
      'units_required': unitsRequired,
      'urgency_level': urgency,
      'description': _cleanNullableString(
        description,
      ),
      'status': 'pending',
      'latitude': latitude,
      'longitude': longitude,
      'gps_accuracy': gpsAccuracy,
      'location_timestamp':
          locationTimestamp?.toUtc().toIso8601String(),
    };

    final response = await supabase
        .from('emergency_sos')
        .insert(data)
        .select()
        .single();

    return EmergencySosModel.fromMap(
      response,
    );
  }

  // ============================================================
  // FIND NEAREST CITY
  // ============================================================

  Future<String?> _findNearestCityId({
    required double latitude,
    required double longitude,
  }) async {
    try {
      final response = await supabase
          .from('cities')
          .select(
            'id, latitude, longitude, deleted_at',
          )
          .isFilter(
            'deleted_at',
            null,
          );

      if (response.isEmpty) {
        return null;
      }

      String? nearestCityId;
      double nearestDistanceKm = double.infinity;

      for (final raw in response) {
        final id = raw['id']?.toString().trim();

        if (id == null || id.isEmpty) {
          continue;
        }

        final cityLatitude = _toDouble(
          raw['latitude'],
        );

        final cityLongitude = _toDouble(
          raw['longitude'],
        );

        if (cityLatitude == null ||
            cityLongitude == null) {
          continue;
        }

        if (!_isValidLatitude(cityLatitude)) {
          continue;
        }

        if (!_isValidLongitude(cityLongitude)) {
          continue;
        }

        final distanceKm = _calculateDistanceKm(
          latitude,
          longitude,
          cityLatitude,
          cityLongitude,
        );

        if (distanceKm < nearestDistanceKm) {
          nearestDistanceKm = distanceKm;
          nearestCityId = id;
        }
      }

      /*
       * Do not attach an SOS to a completely unrelated city.
       *
       * GPS coordinates remain the primary emergency location.
       */
      if (nearestDistanceKm > 50.0) {
        return null;
      }

      return nearestCityId;
    } catch (_) {
      /*
       * City resolution must never prevent an emergency SOS
       * from being created.
       *
       * latitude and longitude remain the actual location.
       */
      return null;
    }
  }

  // ============================================================
  // ACTIVE SOS
  // ============================================================

  Future<EmergencySosModel?> getActiveSos(
    String userId,
  ) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return null;
    }

    final response = await supabase
        .from('emergency_sos')
        .select()
        .eq(
          'user_id',
          normalizedUserId,
        )
        .inFilter(
          'status',
          activeStatuses,
        )
        .order(
          'created_at',
          ascending: false,
        )
        .limit(1)
        .maybeSingle();

    if (response == null) {
      return null;
    }

    return EmergencySosModel.fromMap(
      response,
    );
  }

  // ============================================================
  // SOS HISTORY
  // ============================================================

  Future<List<EmergencySosModel>> getSosHistory(
    String userId,
  ) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return <EmergencySosModel>[];
    }

    final response = await supabase
        .from('emergency_sos')
        .select()
        .eq(
          'user_id',
          normalizedUserId,
        )
        .order(
          'created_at',
          ascending: false,
        );

    return response
        .map<EmergencySosModel>(
          EmergencySosModel.fromMap,
        )
        .toList();
  }

  // ============================================================
  // DELETE SOS HISTORY
  // ============================================================

  /// Permanently deletes one terminal SOS belonging to the
  /// authenticated user.
  ///
  /// Active SOS records cannot be deleted through this method.
  /// RLS remains responsible for the final database-level
  /// authorization check.
  Future<void> deleteSosHistory(
    String sosId,
  ) async {
    final normalizedSosId = sosId.trim();

    if (normalizedSosId.isEmpty) {
      throw Exception(
        'SOS ID is required.',
      );
    }

    final user = supabase.auth.currentUser;

    if (user == null) {
      throw Exception(
        'User is not authenticated.',
      );
    }

    final response = await supabase
        .from('emergency_sos')
        .delete()
        .eq(
          'id',
          normalizedSosId,
        )
        .eq(
          'user_id',
          user.id,
        )
        .inFilter(
          'status',
          terminalStatuses,
        )
        .select('id');

    if (response.isEmpty) {
      throw Exception(
        'This SOS cannot be deleted because it is active '
        'or no longer exists.',
      );
    }
  }

  // ============================================================
  // UPDATE STATUS
  // ============================================================

  Future<EmergencySosModel> updateStatus({
    required String sosId,
    required String status,
  }) async {
    final normalizedSosId = sosId.trim();
    final normalizedStatus = status.trim().toLowerCase();

    if (normalizedSosId.isEmpty) {
      throw Exception(
        'SOS ID is required.',
      );
    }

    if (!allStatuses.contains(normalizedStatus)) {
      throw Exception(
        'Invalid SOS status: $status',
      );
    }

    final response = await supabase
        .from('emergency_sos')
        .update({
          'status': normalizedStatus,
        })
        .eq(
          'id',
          normalizedSosId,
        )
        .select()
        .single();

    return EmergencySosModel.fromMap(
      response,
    );
  }

  // ============================================================
  // CANCEL SOS
  // ============================================================

  Future<EmergencySosModel> cancelSos(
    String sosId,
  ) {
    return updateStatus(
      sosId: sosId,
      status: 'cancelled',
    );
  }

  // ============================================================
  // COMPLETE SOS
  // ============================================================

  Future<EmergencySosModel> completeSos(
    String sosId,
  ) {
    return updateStatus(
      sosId: sosId,
      status: 'completed',
    );
  }

  // ============================================================
  // REALTIME ACTIVE SOS
  // ============================================================

  Stream<EmergencySosModel?> watchActiveSos(
    String userId,
  ) {
    final normalizedUserId = userId.trim();

    return supabase
        .from('emergency_sos')
        .stream(
          primaryKey: ['id'],
        )
        .eq(
          'user_id',
          normalizedUserId,
        )
        .map((rows) {
      final activeRows = rows.where((row) {
        final status =
            row['status']?.toString().trim().toLowerCase() ??
                '';

        return activeStatuses.contains(status);
      }).toList();

      if (activeRows.isEmpty) {
        return null;
      }

      activeRows.sort((a, b) {
        final aDate = _parseDateTime(
          a['created_at'],
        );

        final bDate = _parseDateTime(
          b['created_at'],
        );

        if (aDate == null && bDate == null) {
          return 0;
        }

        if (aDate == null) {
          return 1;
        }

        if (bDate == null) {
          return -1;
        }

        return bDate.compareTo(aDate);
      });

      return EmergencySosModel.fromMap(
        activeRows.first,
      );
    });
  }

  // ============================================================
  // DISTANCE
  // ============================================================

  double _calculateDistanceKm(
    double latitude1,
    double longitude1,
    double latitude2,
    double longitude2,
  ) {
    const earthRadiusKm = 6371.0088;

    final lat1 = latitude1 * math.pi / 180.0;
    final lat2 = latitude2 * math.pi / 180.0;

    final deltaLat =
        (latitude2 - latitude1) * math.pi / 180.0;

    final deltaLon =
        (longitude2 - longitude1) * math.pi / 180.0;

    final sinLat = math.sin(
      deltaLat / 2,
    );

    final sinLon = math.sin(
      deltaLon / 2,
    );

    final a =
        (sinLat * sinLat) +
        math.cos(lat1) *
            math.cos(lat2) *
            (sinLon * sinLon);

    final clampedA = a.clamp(
      0.0,
      1.0,
    );

    final c = 2 *
        math.atan2(
          math.sqrt(clampedA),
          math.sqrt(
            1 - clampedA,
          ),
        );

    return earthRadiusKm * c;
  }

  // ============================================================
  // VALUE HELPERS
  // ============================================================

  double? _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      final number = value.toDouble();

      return number.isFinite ? number : null;
    }

    final parsed = double.tryParse(
      value.toString(),
    );

    if (parsed == null || !parsed.isFinite) {
      return null;
    }

    return parsed;
  }

  String? _cleanNullableString(
    String? value,
  ) {
    final normalized = value?.trim();

    if (normalized == null ||
        normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  bool _isValidLatitude(
    double value,
  ) {
    return value.isFinite &&
        value >= -90.0 &&
        value <= 90.0;
  }

  bool _isValidLongitude(
    double value,
  ) {
    return value.isFinite &&
        value >= -180.0 &&
        value <= 180.0;
  }

  // ============================================================
  // DATETIME
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

