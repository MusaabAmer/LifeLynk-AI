import 'package:supabase_flutter/supabase_flutter.dart';

class BloodRequestRealtimeRepository {
  final SupabaseClient supabase;

  RealtimeChannel? _patientRequestChannel;

  BloodRequestRealtimeRepository({
    required this.supabase,
  });

  // ============================================================
  // PATIENT BLOOD REQUEST REALTIME
  // ============================================================

  void watchPatientRequests({
    required String userId,
    required void Function() onChanged,
  }) {
    final normalizedUserId =
        userId.trim();

    if (normalizedUserId.isEmpty) {
      return;
    }

    /*
     * Remove an existing patient channel before
     * creating a new one.
     */
    if (_patientRequestChannel != null) {
      supabase.removeChannel(
        _patientRequestChannel!,
      );

      _patientRequestChannel = null;
    }

    final channelName =
        'patient-blood-requests-$normalizedUserId';

    final channel =
        supabase.channel(channelName);

    _patientRequestChannel =
        channel;

    channel.onPostgresChanges(
      event: PostgresChangeEvent.insert,
      schema: 'public',
      table: 'blood_requests',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'requester_id',
        value: normalizedUserId,
      ),
      callback: (payload) {
        onChanged();
      },
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.update,
      schema: 'public',
      table: 'blood_requests',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'requester_id',
        value: normalizedUserId,
      ),
      callback: (payload) {
        onChanged();
      },
    );

    channel.subscribe();
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  Future<void> dispose() async {
    final channel =
        _patientRequestChannel;

    if (channel == null) {
      return;
    }

    _patientRequestChannel = null;

    await supabase.removeChannel(
      channel,
    );
  }
}