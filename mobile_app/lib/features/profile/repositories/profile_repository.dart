import 'package:supabase_flutter/supabase_flutter.dart';

import '../../../core/services/supabase_service.dart';
import '../models/profile_model.dart';

class ProfileRepository {
  final SupabaseClient _supabase = SupabaseService.client;

  // ============================================================
  // CURRENT USER
  // ============================================================

  User? get _currentUser => _supabase.auth.currentUser;

  // ============================================================
  // CREATE / COMPLETE PROFILE
  // ============================================================

  Future<void> createProfile(ProfileModel profile) async {
    final user = _currentUser;

    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    final userId = user.id;

    final fullName = profile.fullName.trim();

    if (fullName.isEmpty) {
      throw Exception('Full name is required.');
    }

    final bloodGroup = profile.bloodGroup?.trim();

    if (bloodGroup == null || bloodGroup.isEmpty) {
      throw Exception('Blood group is required.');
    }

    // ----------------------------------------------------------
    // Resolve blood group display value to the real UUID.
    // ----------------------------------------------------------

    final bloodGroupId = await _getBloodGroupId(bloodGroup);

    // ----------------------------------------------------------
    // Update public.users.
    // ----------------------------------------------------------

    final userUpdate = <String, dynamic>{
      'full_name': fullName,
    };

    final phoneNumber = _normalizeNullable(profile.phoneNumber);

    if (phoneNumber != null) {
      userUpdate['phone_number'] = phoneNumber;
    }

    await _updateUserRecord(
      userId: userId,
      userUpdate: userUpdate,
      expectedPhoneNumber: phoneNumber,
    );

    // ----------------------------------------------------------
    // Check whether this authenticated user already has a
    // patient profile.
    //
    // Use a list response instead of maybeSingle().
    //
    // This avoids PGRST116 when there are zero rows.
    // ----------------------------------------------------------

    final existingPatients = await _supabase
        .from('patients')
        .select(
          'id, user_id, blood_group_id, '
          'gender, date_of_birth, '
          'emergency_contact, medical_notes',
        )
        .eq('user_id', userId)
        .limit(1);

    final existingPatient = existingPatients.isNotEmpty
        ? existingPatients.first
        : null;

    // ----------------------------------------------------------
    // Update existing patient.
    // ----------------------------------------------------------

    if (existingPatient != null) {
      final patientId = existingPatient['id']?.toString();

      if (patientId == null || patientId.isEmpty) {
        throw Exception(
          'Existing patient profile has an invalid ID.',
        );
      }

      await _supabase
          .from('patients')
          .update({
            'blood_group_id': bloodGroupId,
            'gender': _normalizeNullable(profile.gender),
          })
          .eq('id', patientId);

      return;
    }

    // ----------------------------------------------------------
    // Create patient profile for THIS authenticated user.
    // ----------------------------------------------------------

    await _supabase.from('patients').insert({
      'user_id': userId,
      'blood_group_id': bloodGroupId,
      'gender': _normalizeNullable(profile.gender),
    });
  }

  // ============================================================
  // GET PROFILE
  // ============================================================

  Future<ProfileModel?> getProfile() async {
    final user = _currentUser;

    if (user == null) {
      return null;
    }

    // ----------------------------------------------------------
    // Read the real public.users record.
    //
    // IMPORTANT:
    // Do not use maybeSingle() here because a newly authenticated
    // user may temporarily have no public.users row.
    // ----------------------------------------------------------

    final userRows = await _supabase
        .from('users')
        .select('id, full_name, phone_number')
        .eq('id', user.id)
        .limit(1);

    if (userRows.isEmpty) {
      return null;
    }

    final userData = userRows.first;

    // ----------------------------------------------------------
    // Read real patient data.
    // ----------------------------------------------------------

    final patientRows = await _supabase
        .from('patients')
        .select(
          'id, user_id, blood_group_id, '
          'gender, date_of_birth, '
          'emergency_contact, medical_notes, '
          'blood_groups(id, name, code)',
        )
        .eq('user_id', user.id)
        .limit(1);

    final patientData =
        patientRows.isNotEmpty ? patientRows.first : null;

    String? bloodGroup;
    String? gender;

    if (patientData != null) {
      gender = patientData['gender']?.toString();

      final bloodGroupData = patientData['blood_groups'];

      if (bloodGroupData is Map) {
        bloodGroup = bloodGroupData['name']?.toString();

        if (bloodGroup == null || bloodGroup.trim().isEmpty) {
          bloodGroup = bloodGroupData['code']?.toString();
        }
      }
    }

    return ProfileModel(
      id: userData['id']?.toString(),
      fullName: userData['full_name']?.toString() ?? '',
      phoneNumber: userData['phone_number']?.toString(),
      gender: gender,
      bloodGroup: bloodGroup,
    );
  }

  // ============================================================
  // UPDATE PROFILE
  // ============================================================

  Future<void> updateProfile(ProfileModel profile) async {
    final user = _currentUser;

    if (user == null) {
      throw Exception('User is not authenticated.');
    }

    final userId = user.id;

    final fullName = profile.fullName.trim();

    if (fullName.isEmpty) {
      throw Exception('Full name is required.');
    }

    // ----------------------------------------------------------
    // Build the real public.users update.
    // ----------------------------------------------------------

    final userUpdate = <String, dynamic>{
      'full_name': fullName,
    };

    final phoneNumber = _normalizeNullable(profile.phoneNumber);

    if (phoneNumber != null) {
      userUpdate['phone_number'] = phoneNumber;
    }

    await _updateUserRecord(
      userId: userId,
      userUpdate: userUpdate,
      expectedPhoneNumber: phoneNumber,
    );

    // ----------------------------------------------------------
    // Blood group is optional during a generic profile update.
    // ----------------------------------------------------------

    String? bloodGroupId;

    final bloodGroup = profile.bloodGroup?.trim();

    if (bloodGroup != null && bloodGroup.isNotEmpty) {
      bloodGroupId = await _getBloodGroupId(bloodGroup);
    }

    // ----------------------------------------------------------
    // Check existing patient.
    // ----------------------------------------------------------

    final patientRows = await _supabase
        .from('patients')
        .select('id, user_id, blood_group_id')
        .eq('user_id', userId)
        .limit(1);

    final existingPatient =
        patientRows.isNotEmpty ? patientRows.first : null;

    // ----------------------------------------------------------
    // Update existing patient.
    // ----------------------------------------------------------

    if (existingPatient != null) {
      final patientId = existingPatient['id']?.toString();

      if (patientId == null || patientId.isEmpty) {
        throw Exception(
          'Existing patient profile has an invalid ID.',
        );
      }

      final patientUpdate = <String, dynamic>{
        'gender': _normalizeNullable(profile.gender),
      };

      if (bloodGroupId != null) {
        patientUpdate['blood_group_id'] = bloodGroupId;
      }

      await _supabase
          .from('patients')
          .update(patientUpdate)
          .eq('id', patientId);

      return;
    }

    // ----------------------------------------------------------
    // No patient profile exists yet.
    // ----------------------------------------------------------

    if (bloodGroupId == null) {
      throw Exception(
        'Blood group is required to create your patient profile.',
      );
    }

    await _supabase.from('patients').insert({
      'user_id': userId,
      'blood_group_id': bloodGroupId,
      'gender': _normalizeNullable(profile.gender),
    });
  }

  // ============================================================
  // UPDATE USER RECORD
  // ============================================================

  Future<void> _updateUserRecord({
    required String userId,
    required Map<String, dynamic> userUpdate,
    String? expectedPhoneNumber,
  }) async {
    // ----------------------------------------------------------
    // Use a list response instead of maybeSingle().
    //
    // This prevents PGRST116 when the update affects zero rows.
    // We then explicitly report that the public.users record
    // could not be found/updated.
    // ----------------------------------------------------------

    final updatedUsers = await _supabase
        .from('users')
        .update(userUpdate)
        .eq('id', userId)
        .select('id, full_name, phone_number')
        .limit(1);

    if (updatedUsers.isEmpty) {
      throw Exception(
        'Unable to save your account information. '
        'Your public user profile was not found or could not '
        'be updated.',
      );
    }

    final updatedUser = updatedUsers.first;

    // ----------------------------------------------------------
    // Verify phone number specifically when supplied.
    // ----------------------------------------------------------

    if (expectedPhoneNumber != null) {
      final savedPhoneNumber =
          _normalizeNullable(
            updatedUser['phone_number']?.toString(),
          );

      if (savedPhoneNumber != expectedPhoneNumber) {
        throw Exception(
          'Your phone number could not be saved to your account. '
          'Please try again.',
        );
      }
    }
  }

  // ============================================================
  // DELETE PROFILE
  // ============================================================

  Future<void> deleteProfile() async {
    final user = _currentUser;

    if (user == null) {
      return;
    }

    // Do NOT delete public.users.
    await _supabase
        .from('patients')
        .delete()
        .eq('user_id', user.id);
  }

  // ============================================================
  // BLOOD GROUP LOOKUP
  // ============================================================

  Future<String> _getBloodGroupId(String bloodGroup) async {
    final normalized = bloodGroup.trim();

    if (normalized.isEmpty) {
      throw Exception('Blood group is required.');
    }

    // ----------------------------------------------------------
    // First try the human-readable name.
    //
    // Use list + limit(1), avoiding PGRST116 when no name
    // matches.
    // ----------------------------------------------------------

    final nameRows = await _supabase
        .from('blood_groups')
        .select('id, name, code')
        .ilike('name', normalized)
        .limit(1);

    if (nameRows.isNotEmpty) {
      final id = nameRows.first['id']?.toString();

      if (id != null && id.isNotEmpty) {
        return id;
      }
    }

    // ----------------------------------------------------------
    // Try code as a second real database lookup.
    // ----------------------------------------------------------

    final codeRows = await _supabase
        .from('blood_groups')
        .select('id, name, code')
        .ilike('code', normalized)
        .limit(1);

    if (codeRows.isNotEmpty) {
      final id = codeRows.first['id']?.toString();

      if (id != null && id.isNotEmpty) {
        return id;
      }
    }

    throw Exception(
      'Blood group "$normalized" was not found in the '
      'LifeLynk blood group database.',
    );
  }

  // ============================================================
  // NULLABLE STRING NORMALIZATION
  // ============================================================

  String? _normalizeNullable(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }
}