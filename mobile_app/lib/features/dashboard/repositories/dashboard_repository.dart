import 'dart:async';

import 'package:supabase_flutter/supabase_flutter.dart';

class DashboardRepository {
  final SupabaseClient supabase;

  RealtimeChannel? _dashboardRealtimeChannel;

  DashboardRepository({
    required this.supabase,
  });

  // ============================================================
  // USER PROFILE
  // ============================================================
  //
  // The public.users table does not contain profile_image.
  //
  // Keep the dashboard profile image value as an empty fallback
  // at the provider level rather than querying a non-existent
  // database column.
  //
  // The authoritative profile fields used by the mobile app are
  // stored in public.users.
  // ============================================================

  Future<Map<String, dynamic>> getUserProfile(
    String userId,
  ) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      throw Exception(
        'A valid user ID is required.',
      );
    }

    final response = await supabase
        .from('users')
        .select('''
          id,
          full_name,
          phone_number
        ''')
        .eq(
          'id',
          normalizedUserId,
        )
        .maybeSingle();

    if (response == null) {
      throw Exception(
        'User profile could not be found.',
      );
    }

    final profile = Map<String, dynamic>.from(
      response,
    );

    /*
     * DashboardProvider and DashboardAppBar still expose
     * profileImage for compatibility with the existing UI.
     *
     * Do not query a column that does not exist in public.users.
     *
     * An empty value tells the existing UI to use its normal
     * avatar/initials fallback.
     */
    profile['profile_image'] = '';

    return profile;
  }

  // ============================================================
  // PATIENT DATA
  // ============================================================

  Future<Map<String, dynamic>?> getPatientData(
    String userId,
  ) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return null;
    }

    final response = await supabase
        .from('patients')
        .select('''
          id,
          user_id,
          blood_group_id,
          blood_groups(
            id,
            name,
            code
          )
        ''')
        .eq(
          'user_id',
          normalizedUserId,
        )
        .maybeSingle();

    if (response == null) {
      return null;
    }

    final bloodGroups = response['blood_groups'];

    String bloodGroup = '';
    String bloodGroupCode = '';

    if (bloodGroups is Map) {
      bloodGroup =
          bloodGroups['name']?.toString() ?? '';

      bloodGroupCode =
          bloodGroups['code']?.toString() ?? '';
    }

    return {
      'id': response['id'],
      'user_id': response['user_id'],
      'blood_group_id': response['blood_group_id'],
      'blood_group': bloodGroup,
      'blood_group_code': bloodGroupCode,
    };
  }

  // ============================================================
  // DONOR STATUS
  // ============================================================

  Future<Map<String, dynamic>?> getDonorData(
    String userId,
  ) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return null;
    }

    final response = await supabase
        .from('donors')
        .select('''
          id,
          user_id,
          is_available
        ''')
        .eq(
          'user_id',
          normalizedUserId,
        )
        .maybeSingle();

    if (response == null) {
      return null;
    }

    final isAvailable =
        response['is_available'] == true;

    return {
      'id': response['id'],
      'user_id': response['user_id'],
      'availability_status': isAvailable
          ? 'available'
          : 'unavailable',
      'is_available': isAvailable,
    };
  }

  // ============================================================
  // LATEST RESERVATION
  // ============================================================

  Future<Map<String, dynamic>?> getLatestReservation(
    String userId,
  ) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return null;
    }

    /*
     * blood_requests.patient_id references patients.id,
     * not users.id.
     */
    final patient = await supabase
        .from('patients')
        .select('id')
        .eq(
          'user_id',
          normalizedUserId,
        )
        .maybeSingle();

    if (patient == null) {
      return null;
    }

    final patientId =
        patient['id']?.toString();

    if (patientId == null ||
        patientId.isEmpty) {
      return null;
    }

    // ==========================================================
    // RESERVATION QUERY
    // ==========================================================

    final response = await supabase
        .from('blood_reservations')
        .select('''
          id,
          blood_request_id,
          blood_inventory_id,
          units_reserved,
          status,
          reserved_until,
          created_at,
          updated_at,
          blood_requests!inner(
            id,
            requester_id,
            patient_id,
            blood_group_id,
            organization_id,
            units_required,
            urgency,
            status,
            required_date,
            notes,
            created_at,
            updated_at,
            blood_groups(
              id,
              code,
              name
            ),
            organizations(
              id,
              name
            )
          )
        ''')
        .eq(
          'blood_requests.patient_id',
          patientId,
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

    final reservation =
        Map<String, dynamic>.from(
      response,
    );

    // ==========================================================
    // BLOOD REQUEST
    // ==========================================================

    final bloodRequest =
        reservation['blood_requests'];

    if (bloodRequest is! Map) {
      reservation['request_id'] = null;
      reservation['requester_id'] = null;
      reservation['patient_id'] = patientId;
      reservation['blood_group_id'] = null;
      reservation['organization_id'] = null;
      reservation['units_required'] = null;
      reservation['urgency'] = null;
      reservation['request_status'] = null;
      reservation['required_date'] = null;
      reservation['notes'] = null;
      reservation['request_created_at'] = null;
      reservation['request_updated_at'] = null;

      reservation['blood_group'] = '';
      reservation['blood_group_code'] = '';
      reservation['organization_name'] = '';

      /*
       * Kept for compatibility with ReservationCard.
       *
       * We do not invent hospital information because the
       * confirmed relationship is organizations.
       */
      reservation['hospital_name'] = '';

      reservation['blood_request'] = null;

      return reservation;
    }

    final request =
        Map<String, dynamic>.from(
      bloodRequest,
    );

    // ==========================================================
    // COPY REQUEST INFORMATION
    // ==========================================================

    reservation['request_id'] =
        request['id'];

    reservation['requester_id'] =
        request['requester_id'];

    reservation['patient_id'] =
        request['patient_id'];

    reservation['blood_group_id'] =
        request['blood_group_id'];

    reservation['organization_id'] =
        request['organization_id'];

    reservation['units_required'] =
        request['units_required'];

    reservation['urgency'] =
        request['urgency'];

    reservation['request_status'] =
        request['status'];

    reservation['required_date'] =
        request['required_date'];

    reservation['notes'] =
        request['notes'];

    reservation['request_created_at'] =
        request['created_at'];

    reservation['request_updated_at'] =
        request['updated_at'];

    // ==========================================================
    // BLOOD GROUP
    // ==========================================================

    final bloodGroup =
        request['blood_groups'];

    if (bloodGroup is Map) {
      reservation['blood_group'] =
          bloodGroup['name']?.toString() ?? '';

      reservation['blood_group_code'] =
          bloodGroup['code']?.toString() ?? '';
    } else {
      reservation['blood_group'] = '';
      reservation['blood_group_code'] = '';
    }

    // ==========================================================
    // ORGANIZATION
    // ==========================================================

    final organization =
        request['organizations'];

    if (organization is Map) {
      reservation['organization_name'] =
          organization['name']?.toString() ?? '';
    } else {
      reservation['organization_name'] = '';
    }

    /*
     * Do not query a hospitals relationship that has not been
     * confirmed by the current database schema.
     */
    reservation['hospital_name'] = '';

    // ==========================================================
    // COMPLETE NESTED REQUEST
    // ==========================================================

    reservation['blood_request'] =
        request;

    return reservation;
  }

  // ============================================================
  // DASHBOARD REALTIME
  // ============================================================
  //
  // Watches the real tables that can affect dashboard data.
  //
  // Realtime events are used as change signals only. The provider
  // reloads authoritative records from Supabase after receiving
  // an event.
  // ============================================================

  Future<void> startRealtime({
    required String userId,
    required FutureOr<void> Function() onChanged,
  }) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return;
    }

    await stopRealtime();

    final channelName =
        'dashboard-realtime-$normalizedUserId';

    final channel =
        supabase.channel(channelName);

    _dashboardRealtimeChannel = channel;

    // ----------------------------------------------------------
    // USERS
    // ----------------------------------------------------------

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'users',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'id',
        value: normalizedUserId,
      ),
      callback: (_) {
        onChanged();
      },
    );

    // ----------------------------------------------------------
    // PATIENTS
    // ----------------------------------------------------------

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'patients',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: normalizedUserId,
      ),
      callback: (_) {
        onChanged();
      },
    );

    // ----------------------------------------------------------
    // DONORS
    // ----------------------------------------------------------

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'donors',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: normalizedUserId,
      ),
      callback: (_) {
        onChanged();
      },
    );

    // ----------------------------------------------------------
    // BLOOD REQUESTS
    // ----------------------------------------------------------

    /*
     * blood_requests is associated with the patient through
     * patient_id, so we cannot safely filter this realtime
     * subscription by the authenticated user's ID.
     *
     * The dashboard reloads authoritative data whenever any
     * blood request changes.
     */

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'blood_requests',
      callback: (_) {
        onChanged();
      },
    );

    // ----------------------------------------------------------
    // BLOOD RESERVATIONS
    // ----------------------------------------------------------

    /*
     * Reservations are related to blood_requests through
     * blood_request_id.
     *
     * The dashboard therefore reloads the latest reservation
     * from the database whenever reservation state changes.
     */

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'blood_reservations',
      callback: (_) {
        onChanged();
      },
    );

   channel.subscribe();
  }

  // ============================================================
  // STOP DASHBOARD REALTIME
  // ============================================================

  Future<void> stopRealtime() async {
    final channel = _dashboardRealtimeChannel;

    if (channel == null) {
      return;
    }

    _dashboardRealtimeChannel = null;

    await supabase.removeChannel(
      channel,
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> dispose() async {
    await stopRealtime();
  }
}