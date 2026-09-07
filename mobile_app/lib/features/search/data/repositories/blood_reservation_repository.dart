import 'package:dio/dio.dart';

import '../../../../core/network/api_client.dart';

class BloodReservationRepository {
  // ============================================================
  // RESERVE BLOOD
  // ============================================================

  Future<Map<String, dynamic>> reserveBlood({
    required String organizationId,
    required String bloodGroupId,
    required int unitsRequired,
    required String urgency,
    required DateTime requiredDate,
    String? notes,
  }) async {
    // ----------------------------------------------------------
    // Normalize input
    // ----------------------------------------------------------

    final normalizedOrganizationId =
        organizationId.trim();

    final normalizedBloodGroupId =
        bloodGroupId.trim();

    final normalizedUrgency =
        urgency.trim().toUpperCase();

    final normalizedNotes =
        notes?.trim();

    // ----------------------------------------------------------
    // Validate organization
    // ----------------------------------------------------------

    if (normalizedOrganizationId.isEmpty) {
      throw Exception(
        'Organization ID is required.',
      );
    }

    // ----------------------------------------------------------
    // Validate blood group
    // ----------------------------------------------------------

    if (normalizedBloodGroupId.isEmpty) {
      throw Exception(
        'Blood group is required.',
      );
    }

    // ----------------------------------------------------------
    // Validate units
    // ----------------------------------------------------------

    if (unitsRequired <= 0) {
      throw Exception(
        'Required blood units must be greater than zero.',
      );
    }

    // ----------------------------------------------------------
    // Validate urgency
    // ----------------------------------------------------------

    const allowedUrgencies = {
      'LOW',
      'MEDIUM',
      'HIGH',
      'CRITICAL',
    };

    if (!allowedUrgencies.contains(
      normalizedUrgency,
    )) {
      throw Exception(
        'Invalid blood request urgency.',
      );
    }

    // ----------------------------------------------------------
    // Normalize required date to UTC
    // ----------------------------------------------------------

    final utcRequiredDate =
        requiredDate.toUtc();

    // ----------------------------------------------------------
    // Required date must be in the future.
    //
    // Backend also validates this, but validating here gives
    // the patient immediate feedback before making the request.
    // ----------------------------------------------------------

    if (!utcRequiredDate.isAfter(
      DateTime.now().toUtc(),
    )) {
      throw Exception(
        'Required date must be in the future.',
      );
    }

    // ----------------------------------------------------------
    // Send reservation request to FastAPI
    // ----------------------------------------------------------

    try {
      final response =
          await ApiClient.post<dynamic>(
        '/blood-requests/reserve',
        data: {
  'organization_id':
      normalizedOrganizationId,

  'blood_group_id':
      normalizedBloodGroupId,

  'units_required':
      unitsRequired,

  'urgency':
      normalizedUrgency,

  'required_date':
      utcRequiredDate.toIso8601String(),

  'notes':
      normalizedNotes == null ||
              normalizedNotes.isEmpty
          ? null
          : normalizedNotes,
},
      );

      // --------------------------------------------------------
      // Expected backend response:
      //
      // {
      //   "request": {...},
      //   "reservations": [...],
      //   "inventory": [...]
      // }
      // --------------------------------------------------------

      if (response.statusCode != 201) {
        throw Exception(
          'Reservation failed: HTTP '
          '${response.statusCode}',
        );
      }

      final data = response.data;

      if (data is! Map) {
        throw Exception(
          'Invalid reservation response from server.',
        );
      }

      final reservationResponse =
          Map<String, dynamic>.from(
        data,
      );

      // --------------------------------------------------------
      // Make sure the backend returned the expected structure.
      // --------------------------------------------------------

      if (!reservationResponse.containsKey(
        'request',
      )) {
        throw Exception(
          'Reservation response is missing the blood request.',
        );
      }

      if (!reservationResponse.containsKey(
        'reservations',
      )) {
        throw Exception(
          'Reservation response is missing reservation details.',
        );
      }

      if (!reservationResponse.containsKey(
        'inventory',
      )) {
        throw Exception(
          'Reservation response is missing inventory details.',
        );
      }

      return reservationResponse;
    } on DioException catch (e) {
      // --------------------------------------------------------
      // FastAPI HTTP error
      // --------------------------------------------------------

      final responseData =
          e.response?.data;

      String message =
          'Unable to reserve blood.';

      if (responseData is Map &&
          responseData['detail'] != null) {
        message =
            responseData['detail']
                .toString()
                .trim();

        if (message.isEmpty) {
          message =
              'Unable to reserve blood.';
        }
      } else if (e.message != null &&
          e.message!.trim().isNotEmpty) {
        message =
            e.message!.trim();
      }

      throw Exception(message);
    } catch (e) {
      // --------------------------------------------------------
      // Preserve application exceptions.
      // --------------------------------------------------------

      if (e is Exception) {
        rethrow;
      }

      throw Exception(
        'Unable to reserve blood.',
      );
    }
  }
}