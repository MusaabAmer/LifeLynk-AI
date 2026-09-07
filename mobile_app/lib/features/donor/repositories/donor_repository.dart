import 'dart:math';

import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../models/donation_history_model.dart';
import '../models/donor_profile_model.dart';

class DonorRepository {
  final SupabaseClient _client = SupabaseService.client;

  RealtimeChannel? _donorsChannel;
  RealtimeChannel? _donorProfilesChannel;
  RealtimeChannel? _donorAvailabilityChannel;
  RealtimeChannel? _donationHistoryChannel;

  // ============================================================
  // CREATE / BECOME DONOR
  // ============================================================

  Future<DonorProfileModel> createDonorProfile({
    required String cityId,
    required DateTime dateOfBirth,
    required double weight,
    DateTime? lastDonationDate,
    required String availabilityStatus,
  }) async {
    final user = _requireAuthenticatedUser();
    final userId = user.id;

    final normalizedCityId = cityId.trim();
    final normalizedAvailabilityStatus =
        availabilityStatus.trim().toLowerCase();

    if (normalizedCityId.isEmpty) {
      throw Exception(
        'Your city is required before becoming a donor.',
      );
    }

    _validateDonorData(
      dateOfBirth: dateOfBirth,
      weight: weight,
      lastDonationDate: lastDonationDate,
      availabilityStatus: normalizedAvailabilityStatus,
    );

    // ----------------------------------------------------------
    // Load authoritative phone from public.users.
    // ----------------------------------------------------------

    final phoneNumber = await _getRequiredProfilePhone(
      userId: userId,
    );

    // ----------------------------------------------------------
    // Load the real patient profile.
    // ----------------------------------------------------------

    final patientRows = await _client
        .from('patients')
        .select('id, blood_group_id, gender')
        .eq('user_id', userId)
        .isFilter('deleted_at', null)
        .limit(1);

    final patientRow =
        patientRows.isNotEmpty ? patientRows.first : null;

    if (patientRow == null) {
      throw Exception(
        'Complete your patient profile before becoming a donor.',
      );
    }

    final bloodGroupId =
        patientRow['blood_group_id']?.toString().trim();

    if (bloodGroupId == null || bloodGroupId.isEmpty) {
      throw Exception(
        'Your blood group is required before becoming a donor.',
      );
    }

    final gender = patientRow['gender']?.toString().trim();

    if (gender == null || gender.isEmpty) {
      throw Exception(
        'Your gender is required before becoming a donor.',
      );
    }

    // ----------------------------------------------------------
    // Validate city against the real database.
    // ----------------------------------------------------------

    final cityRows = await _client
        .from('cities')
        .select('id, name, province_id')
        .eq('id', normalizedCityId)
        .limit(1);

    if (cityRows.isEmpty) {
      throw Exception(
        'The selected city could not be found.',
      );
    }

    // ----------------------------------------------------------
    // Find existing donor identity.
    //
    // Do not filter deleted_at here because a previous donor
    // must be reactivated instead of duplicated.
    // ----------------------------------------------------------

    final donorRows = await _client
        .from('donors')
        .select(
          'id, user_id, blood_group_id, city_id, '
          'phone_number, date_of_birth, gender, '
          'is_available, total_donations, '
          'last_donation_date, created_at, updated_at, '
          'deleted_at',
        )
        .eq('user_id', userId)
        .limit(1);

    final existingDonor =
        donorRows.isNotEmpty ? donorRows.first : null;

    late final String donorId;

    // ----------------------------------------------------------
    // Update / reactivate existing donor.
    // ----------------------------------------------------------

    if (existingDonor != null) {
      final existingDonorId =
          existingDonor['id']?.toString().trim();

      if (existingDonorId == null || existingDonorId.isEmpty) {
        throw Exception(
          'Your donor record has an invalid ID.',
        );
      }

      donorId = existingDonorId;

      await _client
          .from('donors')
          .update({
            'blood_group_id': bloodGroupId,
            'city_id': normalizedCityId,
            'phone_number': phoneNumber,
            'date_of_birth': _formatDate(dateOfBirth),
            'gender': gender,
            'is_available':
                normalizedAvailabilityStatus == 'available',
            'last_donation_date': lastDonationDate == null
                ? null
                : _formatDate(lastDonationDate),
            'deleted_at': null,
            'updated_at': _nowIso(),
          })
          .eq('id', donorId);
    }

    // ----------------------------------------------------------
    // Create new donor.
    //
    // Explicit UUID generation is required by the current
    // database schema.
    // ----------------------------------------------------------

    else {
      donorId = _generateUuidV4();

      await _client.from('donors').insert({
        'id': donorId,
        'user_id': userId,
        'blood_group_id': bloodGroupId,
        'city_id': normalizedCityId,
        'phone_number': phoneNumber,
        'date_of_birth': _formatDate(dateOfBirth),
        'gender': gender,
        'is_available':
            normalizedAvailabilityStatus == 'available',
        'total_donations': 0,
        'last_donation_date': lastDonationDate == null
            ? null
            : _formatDate(lastDonationDate),
      });
    }

    // ----------------------------------------------------------
    // Create / reactivate donor profile.
    // ----------------------------------------------------------

    final profileRows = await _client
        .from('donor_profiles')
        .select('id, deleted_at')
        .eq('user_id', userId)
        .limit(1);

    final existingProfile =
        profileRows.isNotEmpty ? profileRows.first : null;

    final now = _nowIso();

    final profilePayload = {
      'user_id': userId,
      'date_of_birth': _formatDate(dateOfBirth),
      'weight': weight,
      'last_donation_date': lastDonationDate == null
          ? null
          : _formatDate(lastDonationDate),
      'availability_status': normalizedAvailabilityStatus,
      'eligibility_status': 'pending',
      'deleted_at': null,
      'updated_at': now,
    };

    if (existingProfile == null) {
      await _client.from('donor_profiles').insert({
        'id': _generateUuidV4(),
        ...profilePayload,
      });
    } else {
      final profileId =
          existingProfile['id']?.toString().trim();

      if (profileId == null || profileId.isEmpty) {
        throw Exception(
          'Your donor profile has an invalid ID.',
        );
      }

      await _client
          .from('donor_profiles')
          .update(profilePayload)
          .eq('id', profileId);
    }

    // ----------------------------------------------------------
    // Synchronize donor availability.
    // ----------------------------------------------------------

    await _synchronizeAvailability(
      donorId: donorId,
      availabilityStatus: normalizedAvailabilityStatus,
    );

    // ----------------------------------------------------------
    // Always return authoritative database record.
    // ----------------------------------------------------------

    final profile = await getDonorProfile();

    if (profile == null) {
      throw Exception(
        'Donor profile was created but could not be loaded.',
      );
    }

    return profile;
  }

  // ============================================================
  // GET AUTHORITATIVE PROFILE PHONE
  // ============================================================

  Future<String> _getRequiredProfilePhone({
    required String userId,
  }) async {
    final rows = await _client
        .from('users')
        .select('id, phone_number')
        .eq('id', userId)
        .limit(1);

    if (rows.isEmpty) {
      throw Exception(
        'Your public user profile could not be found. '
        'Please complete your profile first.',
      );
    }

    final phoneNumber =
        rows.first['phone_number']?.toString().trim();

    if (phoneNumber == null || phoneNumber.isEmpty) {
      throw Exception(
        'Your phone number is required before becoming a donor. '
        'Please complete your profile first.',
      );
    }

    if (phoneNumber.length > 20) {
      throw Exception(
        'Your registered phone number is too long.',
      );
    }

    return phoneNumber;
  }

  // ============================================================
  // GET ACTIVE DONOR PROFILE
  // ============================================================

  Future<DonorProfileModel?> getDonorProfile() async {
    final user = _requireAuthenticatedUser();

    final rows = await _client
        .from('donor_profiles')
        .select(
          'id, user_id, date_of_birth, weight, '
          'last_donation_date, availability_status, '
          'eligibility_status, created_at, '
          'updated_at, deleted_at',
        )
        .eq('user_id', user.id)
        .isFilter('deleted_at', null)
        .limit(1);

    if (rows.isEmpty) {
      return null;
    }

    return DonorProfileModel.fromJson(
      Map<String, dynamic>.from(rows.first),
    );
  }

  // ============================================================
  // GET DONOR ID
  // ============================================================

  Future<String?> getDonorId() async {
    final user = _requireAuthenticatedUser();

    final rows = await _client
        .from('donors')
        .select('id, deleted_at')
        .eq('user_id', user.id)
        .limit(1);

    if (rows.isEmpty) {
      return null;
    }

    final donorId =
        rows.first['id']?.toString().trim();

    if (donorId == null || donorId.isEmpty) {
      return null;
    }

    return donorId;
  }

  // ============================================================
  // IS ACTIVE DONOR
  // ============================================================

  Future<bool> isDonor() async {
    final profile = await getDonorProfile();
    return profile != null;
  }

  // ============================================================
  // UPDATE DONOR PROFILE
  // ============================================================

  Future<DonorProfileModel> updateDonorProfile({
    required DateTime dateOfBirth,
    required double weight,
    DateTime? lastDonationDate,
    required String availabilityStatus,
  }) async {
    final user = _requireAuthenticatedUser();

    final normalizedAvailabilityStatus =
        availabilityStatus.trim().toLowerCase();

    _validateDonorData(
      dateOfBirth: dateOfBirth,
      weight: weight,
      lastDonationDate: lastDonationDate,
      availabilityStatus: normalizedAvailabilityStatus,
    );

    final profileRows = await _client
        .from('donor_profiles')
        .select('id')
        .eq('user_id', user.id)
        .isFilter('deleted_at', null)
        .limit(1);

    if (profileRows.isEmpty) {
      throw Exception(
        'Donor profile not found.',
      );
    }

    final profileId =
        profileRows.first['id']?.toString().trim();

    if (profileId == null || profileId.isEmpty) {
      throw Exception(
        'Donor profile has an invalid ID.',
      );
    }

    final now = _nowIso();

    await _client
        .from('donor_profiles')
        .update({
          'date_of_birth': _formatDate(dateOfBirth),
          'weight': weight,
          'last_donation_date': lastDonationDate == null
              ? null
              : _formatDate(lastDonationDate),
          'availability_status': normalizedAvailabilityStatus,
          'deleted_at': null,
          'updated_at': now,
        })
        .eq('id', profileId);

    final donorId = await getDonorId();

    if (donorId != null) {
      final phoneNumber = await _getRequiredProfilePhone(
        userId: user.id,
      );

      await _client
          .from('donors')
          .update({
            'phone_number': phoneNumber,
            'date_of_birth': _formatDate(dateOfBirth),
            'is_available':
                normalizedAvailabilityStatus == 'available',
            'last_donation_date': lastDonationDate == null
                ? null
                : _formatDate(lastDonationDate),
            'deleted_at': null,
            'updated_at': now,
          })
          .eq('id', donorId);

      await _synchronizeAvailability(
        donorId: donorId,
        availabilityStatus: normalizedAvailabilityStatus,
      );
    }

    final updated = await getDonorProfile();

    if (updated == null) {
      throw Exception(
        'Donor profile could not be reloaded.',
      );
    }

    return updated;
  }

  // ============================================================
  // UPDATE AVAILABILITY
  // ============================================================

  Future<DonorProfileModel> updateAvailability(
    bool isAvailable,
  ) async {
    final user = _requireAuthenticatedUser();

    final status =
        isAvailable ? 'available' : 'unavailable';

    final profileRows = await _client
        .from('donor_profiles')
        .select('id')
        .eq('user_id', user.id)
        .isFilter('deleted_at', null)
        .limit(1);

    if (profileRows.isEmpty) {
      throw Exception(
        'Donor profile not found.',
      );
    }

    final profileId =
        profileRows.first['id']?.toString().trim();

    if (profileId == null || profileId.isEmpty) {
      throw Exception(
        'Donor profile has an invalid ID.',
      );
    }

    final now = _nowIso();

    await _client
        .from('donor_profiles')
        .update({
          'availability_status': status,
          'updated_at': now,
        })
        .eq('id', profileId);

    final donorId = await getDonorId();

    if (donorId != null) {
      await _client
          .from('donors')
          .update({
            'is_available': isAvailable,
            'updated_at': now,
          })
          .eq('id', donorId);

      await _synchronizeAvailability(
        donorId: donorId,
        availabilityStatus: status,
      );
    }

    final updated = await getDonorProfile();

    if (updated == null) {
      throw Exception(
        'Donor profile could not be reloaded.',
      );
    }

    return updated;
  }

  // ============================================================
  // UPDATE ELIGIBILITY
  // ============================================================

  Future<DonorProfileModel> updateEligibility(
    String eligibilityStatus,
  ) async {
    final user = _requireAuthenticatedUser();

    final normalizedStatus =
        eligibilityStatus.trim().toLowerCase();

    const validStatuses = {
      'pending',
      'eligible',
      'ineligible',
    };

    if (!validStatuses.contains(normalizedStatus)) {
      throw Exception(
        'Invalid donor eligibility status.',
      );
    }

    final profileRows = await _client
        .from('donor_profiles')
        .select('id')
        .eq('user_id', user.id)
        .isFilter('deleted_at', null)
        .limit(1);

    if (profileRows.isEmpty) {
      throw Exception(
        'Donor profile not found.',
      );
    }

    final profileId =
        profileRows.first['id']?.toString().trim();

    if (profileId == null || profileId.isEmpty) {
      throw Exception(
        'Donor profile has an invalid ID.',
      );
    }

    await _client
        .from('donor_profiles')
        .update({
          'eligibility_status': normalizedStatus,
          'updated_at': _nowIso(),
        })
        .eq('id', profileId);

    final updated = await getDonorProfile();

    if (updated == null) {
      throw Exception(
        'Donor profile could not be reloaded.',
      );
    }

    return updated;
  }

  // ============================================================
  // LEAVE DONOR PROGRAM
  // ============================================================

  Future<void> deleteDonorProfile() async {
    final user = _requireAuthenticatedUser();

    final profileRows = await _client
        .from('donor_profiles')
        .select('id')
        .eq('user_id', user.id)
        .isFilter('deleted_at', null)
        .limit(1);

    if (profileRows.isEmpty) {
      return;
    }

    final profileId =
        profileRows.first['id']?.toString().trim();

    if (profileId == null || profileId.isEmpty) {
      return;
    }

    final now = _nowIso();

    // ----------------------------------------------------------
    // Soft-delete donor profile.
    // ----------------------------------------------------------

    await _client
        .from('donor_profiles')
        .update({
          'deleted_at': now,
          'availability_status': 'unavailable',
          'updated_at': now,
        })
        .eq('id', profileId);

    // ----------------------------------------------------------
    // Disable donor identity.
    // ----------------------------------------------------------

    final donorId = await getDonorId();

    if (donorId != null) {
      await _client
          .from('donors')
          .update({
            'is_available': false,
            'updated_at': now,
          })
          .eq('id', donorId);

      // --------------------------------------------------------
      // Keep availability table synchronized.
      // --------------------------------------------------------

      await _client
          .from('donor_availability')
          .update({
            'is_available': false,
            'last_checked_at': now,
            'updated_at': now,
          })
          .eq('donor_id', donorId);
    }
  }

  // ============================================================
  // REACTIVATE DONOR
  // ============================================================

  Future<DonorProfileModel> reactivateDonorProfile({
    required DateTime dateOfBirth,
    required double weight,
    DateTime? lastDonationDate,
    required String availabilityStatus,
  }) async {
    final user = _requireAuthenticatedUser();

    final normalizedAvailabilityStatus =
        availabilityStatus.trim().toLowerCase();

    _validateDonorData(
      dateOfBirth: dateOfBirth,
      weight: weight,
      lastDonationDate: lastDonationDate,
      availabilityStatus: normalizedAvailabilityStatus,
    );

    // ----------------------------------------------------------
    // Find previous donor profile without deleted_at filtering.
    // ----------------------------------------------------------

    final profileRows = await _client
        .from('donor_profiles')
        .select('id')
        .eq('user_id', user.id)
        .limit(1);

    if (profileRows.isEmpty) {
      throw Exception(
        'Previous donor profile was not found.',
      );
    }

    final profileId =
        profileRows.first['id']?.toString().trim();

    if (profileId == null || profileId.isEmpty) {
      throw Exception(
        'Previous donor profile has an invalid ID.',
      );
    }

    final phoneNumber = await _getRequiredProfilePhone(
      userId: user.id,
    );

    final now = _nowIso();

    // ----------------------------------------------------------
    // Reactivate donor profile.
    //
    // Existing eligibility is preserved intentionally.
    // ----------------------------------------------------------

    await _client
        .from('donor_profiles')
        .update({
          'date_of_birth': _formatDate(dateOfBirth),
          'weight': weight,
          'last_donation_date': lastDonationDate == null
              ? null
              : _formatDate(lastDonationDate),
          'availability_status': normalizedAvailabilityStatus,
          'deleted_at': null,
          'updated_at': now,
        })
        .eq('id', profileId);

    // ----------------------------------------------------------
    // Find donor identity.
    // ----------------------------------------------------------

    final donorRows = await _client
        .from('donors')
        .select('id')
        .eq('user_id', user.id)
        .limit(1);

    if (donorRows.isEmpty) {
      throw Exception(
        'Donor identity could not be found.',
      );
    }

    final donorId =
        donorRows.first['id']?.toString().trim();

    if (donorId == null || donorId.isEmpty) {
      throw Exception(
        'Donor identity has an invalid ID.',
      );
    }

    // ----------------------------------------------------------
    // Reactivate donor identity.
    // ----------------------------------------------------------

    await _client
        .from('donors')
        .update({
          'phone_number': phoneNumber,
          'is_available':
              normalizedAvailabilityStatus == 'available',
          'date_of_birth': _formatDate(dateOfBirth),
          'last_donation_date': lastDonationDate == null
              ? null
              : _formatDate(lastDonationDate),
          'deleted_at': null,
          'updated_at': now,
        })
        .eq('id', donorId);

    // ----------------------------------------------------------
    // Restore availability record.
    // ----------------------------------------------------------

    await _synchronizeAvailability(
      donorId: donorId,
      availabilityStatus: normalizedAvailabilityStatus,
    );

    final updated = await getDonorProfile();

    if (updated == null) {
      throw Exception(
        'Donor profile could not be reloaded.',
      );
    }

    return updated;
  }

  // ============================================================
  // CHECK PREVIOUS DONOR PROFILE
  // ============================================================

  Future<bool> hasPreviousDonorProfile() async {
    final user = _requireAuthenticatedUser();

    final rows = await _client
        .from('donor_profiles')
        .select('id')
        .eq('user_id', user.id)
        .limit(1);

    return rows.isNotEmpty;
  }

  // ============================================================
  // GET DONATION HISTORY
  // ============================================================

  Future<List<DonationHistoryModel>> getDonationHistory() async {
    final donorId = await getDonorId();

    if (donorId == null) {
      return const <DonationHistoryModel>[];
    }

    final rows = await _client
        .from('donation_history')
        .select('''
          id,
          donor_id,
          organization_id,
          blood_group_id,
          units_donated,
          donation_date,
          verified,
          notes,
          created_at,
          updated_at,
          organizations (
            id,
            name
          ),
          blood_groups (
            id,
            code,
            name
          )
        ''')
        .eq('donor_id', donorId)
        .order(
          'donation_date',
          ascending: false,
        );

    return rows
        .map(
          (row) => DonationHistoryModel.fromJson(
            Map<String, dynamic>.from(
              row as Map,
            ),
          ),
        )
        .toList(growable: false);
  }

  // ============================================================
  // START DONATION HISTORY REALTIME
  // ============================================================

  Future<void> startDonationHistoryRealtime({
    required void Function() onChanged,
  }) async {
    final donorId = await getDonorId();

    if (donorId == null) {
      return;
    }

    await stopDonationHistoryRealtime();

    final channel = _client.channel(
      'donation-history-realtime-$donorId',
    );

    channel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'donation_history',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'donor_id',
        value: donorId,
      ),
      callback: (_) {
        onChanged();
      },
    );

    _donationHistoryChannel = channel;

    channel.subscribe();
  }

  // ============================================================
  // STOP DONATION HISTORY REALTIME
  // ============================================================

  Future<void> stopDonationHistoryRealtime() async {
    final channel = _donationHistoryChannel;

    if (channel == null) {
      return;
    }

    _donationHistoryChannel = null;

    await _client.removeChannel(channel);
  }

  // ============================================================
  // DONOR PROFILE REALTIME
  // ============================================================

  Future<void> watchDonorProfile(
    void Function(DonorProfileModel?) onChanged,
  ) async {
    // Only stop donor-profile realtime channels here.
    //
    // Do NOT call disposeRealtime(), because that would also
    // terminate donation-history realtime.
    await _stopDonorProfileRealtime();

    final user = _requireAuthenticatedUser();

    // ----------------------------------------------------------
    // donor_profiles
    // ----------------------------------------------------------

    final donorProfilesChannel = _client.channel(
      'donor-profile-realtime-${user.id}',
    );

    donorProfilesChannel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'donor_profiles',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: user.id,
      ),
      callback: (_) async {
        try {
          final profile = await getDonorProfile();
          onChanged(profile);
        } catch (_) {
          // Keep realtime alive.
        }
      },
    );

    _donorProfilesChannel = donorProfilesChannel;

    donorProfilesChannel.subscribe();

    // ----------------------------------------------------------
    // donors
    // ----------------------------------------------------------

    final donorsChannel = _client.channel(
      'donor-identity-realtime-${user.id}',
    );

    donorsChannel.onPostgresChanges(
      event: PostgresChangeEvent.all,
      schema: 'public',
      table: 'donors',
      filter: PostgresChangeFilter(
        type: PostgresChangeFilterType.eq,
        column: 'user_id',
        value: user.id,
      ),
      callback: (_) async {
        try {
          final profile = await getDonorProfile();
          onChanged(profile);
        } catch (_) {
          // Keep realtime alive.
        }
      },
    );

    _donorsChannel = donorsChannel;

    donorsChannel.subscribe();

    // ----------------------------------------------------------
    // donor_availability
    // ----------------------------------------------------------

    final donorId = await getDonorId();

    if (donorId != null) {
      final availabilityChannel = _client.channel(
        'donor-availability-realtime-$donorId',
      );

      availabilityChannel.onPostgresChanges(
        event: PostgresChangeEvent.all,
        schema: 'public',
        table: 'donor_availability',
        filter: PostgresChangeFilter(
          type: PostgresChangeFilterType.eq,
          column: 'donor_id',
          value: donorId,
        ),
        callback: (_) async {
          try {
            final profile = await getDonorProfile();
            onChanged(profile);
          } catch (_) {
            // Keep realtime alive.
          }
        },
      );

      _donorAvailabilityChannel = availabilityChannel;

      availabilityChannel.subscribe();
    }
  }

  // ============================================================
  // STOP DONOR PROFILE REALTIME ONLY
  // ============================================================

  Future<void> _stopDonorProfileRealtime() async {
    final channels = <RealtimeChannel>[
  ?_donorsChannel,
  ?_donorProfilesChannel,
  ?_donorAvailabilityChannel,
];

    _donorsChannel = null;
    _donorProfilesChannel = null;
    _donorAvailabilityChannel = null;

    for (final channel in channels) {
      await _client.removeChannel(channel);
    }
  }

  // ============================================================
  // DISPOSE ALL REALTIME
  // ============================================================

  Future<void> disposeRealtime() async {
    final channels = <RealtimeChannel>[
  ?_donorsChannel,
  ?_donorProfilesChannel,
  ?_donorAvailabilityChannel,
  ?_donationHistoryChannel,
];

    _donorsChannel = null;
    _donorProfilesChannel = null;
    _donorAvailabilityChannel = null;
    _donationHistoryChannel = null;

    for (final channel in channels) {
      await _client.removeChannel(channel);
    }
  }

  // ============================================================
  // SYNCHRONIZE DONOR AVAILABILITY
  // ============================================================

  Future<void> _synchronizeAvailability({
    required String donorId,
    required String availabilityStatus,
  }) async {
    final normalizedStatus =
        availabilityStatus.trim().toLowerCase();

    final isAvailable =
        normalizedStatus == 'available';

    final now = _nowIso();

    final rows = await _client
        .from('donor_availability')
        .select('id')
        .eq('donor_id', donorId)
        .limit(1);

    final existing =
        rows.isNotEmpty ? rows.first : null;

    final payload = {
      'donor_id': donorId,
      'is_available': isAvailable,
      'last_checked_at': now,
      'next_eligible_date': null,
      'updated_at': now,
    };

    if (existing == null) {
      await _client.from('donor_availability').insert({
        'id': _generateUuidV4(),
        ...payload,
      });
      return;
    }

    final availabilityId =
        existing['id']?.toString().trim();

    if (availabilityId == null ||
        availabilityId.isEmpty) {
      throw Exception(
        'Donor availability record has an invalid ID.',
      );
    }

    await _client
        .from('donor_availability')
        .update(payload)
        .eq('id', availabilityId);
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  void _validateDonorData({
    required DateTime dateOfBirth,
    required double weight,
    DateTime? lastDonationDate,
    required String availabilityStatus,
  }) {
    final now = DateTime.now();

    if (dateOfBirth.isAfter(now)) {
      throw Exception(
        'Date of birth cannot be in the future.',
      );
    }

    final age = now.year -
        dateOfBirth.year -
        ((now.month < dateOfBirth.month ||
                (now.month == dateOfBirth.month &&
                    now.day < dateOfBirth.day))
            ? 1
            : 0);

    if (age < 18) {
      throw Exception(
        'You must be at least 18 years old to donate blood.',
      );
    }

    if (weight <= 0 || weight > 300) {
      throw Exception(
        'Weight must be between 1 and 300 kg.',
      );
    }

    if (lastDonationDate != null) {
      if (lastDonationDate.isAfter(now)) {
        throw Exception(
          'Last donation date cannot be in the future.',
        );
      }

      if (lastDonationDate.isBefore(dateOfBirth)) {
        throw Exception(
          'Last donation date cannot be before your date of birth.',
        );
      }
    }

    const validAvailability = {
      'available',
      'unavailable',
    };

    if (!validAvailability.contains(
      availabilityStatus,
    )) {
      throw Exception(
        'Invalid donor availability status.',
      );
    }
  }

  // ============================================================
  // AUTH
  // ============================================================

  User _requireAuthenticatedUser() {
    final user = _client.auth.currentUser;

    if (user == null) {
      throw Exception(
        'You must be signed in.',
      );
    }

    return user;
  }

  // ============================================================
  // TIME
  // ============================================================

  String _nowIso() {
    return DateTime.now()
        .toUtc()
        .toIso8601String();
  }

  // ============================================================
  // DATE
  // ============================================================

  String _formatDate(DateTime date) {
    final value = date.toUtc();

    return '${value.year.toString().padLeft(4, '0')}-'
        '${value.month.toString().padLeft(2, '0')}-'
        '${value.day.toString().padLeft(2, '0')}';
  }

  // ============================================================
  // UUID
  // ============================================================

  /// Generates a standard RFC 4122 version-4 UUID.
  ///
  /// Explicit IDs are required because the current donor-related
  /// database tables do not reliably generate IDs themselves.
  String _generateUuidV4() {
    final random = Random.secure();

    final bytes = List<int>.generate(
      16,
      (_) => random.nextInt(256),
    );

    // UUID version 4.
    bytes[6] = (bytes[6] & 0x0f) | 0x40;

    // RFC 4122 variant.
    bytes[8] = (bytes[8] & 0x3f) | 0x80;

    String hexByte(int value) {
      return value
          .toRadixString(16)
          .padLeft(2, '0');
    }

    final hex = bytes.map(hexByte).join();

    return '${hex.substring(0, 8)}-'
        '${hex.substring(8, 12)}-'
        '${hex.substring(12, 16)}-'
        '${hex.substring(16, 20)}-'
        '${hex.substring(20, 32)}';
  }
}