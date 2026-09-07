import 'dart:async';

import 'package:flutter/foundation.dart';

import '../models/donation_history_model.dart';
import '../models/donor_profile_model.dart';
import '../repositories/donor_repository.dart';

class DonorProvider extends ChangeNotifier {
  final DonorRepository _repository;

  DonorProvider({
    DonorRepository? repository,
  }) : _repository = repository ?? DonorRepository();

  // ============================================================
  // STATE
  // ============================================================

  bool _disposed = false;

  // ============================================================
  // DONATION HISTORY
  // ============================================================

  List<DonationHistoryModel> _donationHistory = const [];

  bool _donationHistoryLoading = false;

  String? _donationHistoryError;

  bool _donationHistoryRealtimeStarted = false;

  bool _donationHistoryRealtimeStarting = false;

  List<DonationHistoryModel> get donationHistory =>
      List.unmodifiable(_donationHistory);

  bool get donationHistoryLoading => _donationHistoryLoading;

  String? get donationHistoryError => _donationHistoryError;

  int get totalDonationUnits {
    return _donationHistory.fold<int>(
      0,
      (total, donation) => total + donation.unitsDonated,
    );
  }

  int get verifiedDonationCount {
    return _donationHistory.where((donation) => donation.verified).length;
  }

  // ============================================================
  // DONOR PROFILE
  // ============================================================

  DonorProfileModel? _donorProfile;

  bool _loading = false;

  String? _error;

  bool _realtimeStarted = false;

  bool _realtimeStarting = false;

  DonorProfileModel? get donorProfile => _donorProfile;

  bool get loading => _loading;

  String? get error => _error;

  bool get isDonor => _donorProfile != null;

  bool get isAvailable =>
      _donorProfile?.availabilityStatus.trim().toLowerCase() ==
      'available';

  bool get isEligible =>
      _donorProfile?.eligibilityStatus.trim().toLowerCase() == 'eligible';

  // ============================================================
  // LOAD DONATION HISTORY
  // ============================================================

  Future<void> loadDonationHistory() async {
    if (_disposed || _donationHistoryLoading) {
      return;
    }

    _donationHistoryLoading = true;
    _donationHistoryError = null;

    notifyListeners();

    try {
      final history = await _repository.getDonationHistory();

      if (_disposed) {
        return;
      }

      _donationHistory = history;
      _donationHistoryError = null;
    } catch (error) {
      if (_disposed) {
        return;
      }

      _donationHistoryError = _cleanError(error);
    } finally {
      if (!_disposed) {
        _donationHistoryLoading = false;
        notifyListeners();
      }
    }
  }

  // ============================================================
  // START DONATION HISTORY REALTIME
  // ============================================================

  Future<void> startDonationHistoryRealtime() async {
    if (_disposed ||
        _donationHistoryRealtimeStarted ||
        _donationHistoryRealtimeStarting) {
      return;
    }

    _donationHistoryRealtimeStarting = true;

    try {
      await _repository.startDonationHistoryRealtime(
        onChanged: () async {
          if (_disposed) {
            return;
          }

          await loadDonationHistory();
        },
      );

      if (!_disposed) {
        _donationHistoryRealtimeStarted = true;
        _donationHistoryError = null;
      }
    } catch (error) {
      _donationHistoryRealtimeStarted = false;

      if (_disposed) {
        return;
      }

      _donationHistoryError = _cleanError(error);

      notifyListeners();
    } finally {
      _donationHistoryRealtimeStarting = false;
    }
  }

  // ============================================================
  // STOP DONATION HISTORY REALTIME
  // ============================================================

  Future<void> stopDonationHistoryRealtime() async {
    _donationHistoryRealtimeStarted = false;
    _donationHistoryRealtimeStarting = false;

    if (_disposed) {
      return;
    }

    try {
      await _repository.stopDonationHistoryRealtime();
    } catch (error) {
      if (_disposed) {
        return;
      }

      _donationHistoryError = _cleanError(error);

      notifyListeners();
    }
  }

  // ============================================================
  // LOAD DONOR PROFILE
  // ============================================================

  Future<void> loadDonorProfile({
    bool startRealtime = true,
  }) async {
    if (_disposed || _loading) {
      return;
    }

    _loading = true;
    _error = null;

    notifyListeners();

    try {
      final profile = await _repository.getDonorProfile();

      if (_disposed) {
        return;
      }

      _donorProfile = profile;

      if (profile != null && startRealtime) {
        await _startRealtime();
      }
    } catch (error) {
      if (_disposed) {
        return;
      }

      _error = _cleanError(error);
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  // ============================================================
  // BECOME DONOR
  // ============================================================

  Future<bool> becomeDonor({
    required String cityId,
    required DateTime dateOfBirth,
    required double weight,
    DateTime? lastDonationDate,
    required String availabilityStatus,
  }) async {
    if (_disposed) {
      return false;
    }

    final normalizedCityId = cityId.trim();

    if (normalizedCityId.isEmpty) {
      _error = 'Please select your city.';
      notifyListeners();
      return false;
    }

    if (_loading) {
      return false;
    }

    _loading = true;
    _error = null;

    notifyListeners();

    try {
      /*
       * DonorRepository.createDonorProfile() is responsible for:
       *
       * - validating donor information
       * - validating authentication
       * - reading public.users.phone_number
       * - reading the patient's real blood group
       * - reading the patient's real gender
       * - validating the selected city
       * - creating/updating donors
       * - creating/updating donor_profiles
       * - creating/updating donor_availability
       */
      final profile = await _repository.createDonorProfile(
        cityId: normalizedCityId,
        dateOfBirth: dateOfBirth,
        weight: weight,
        lastDonationDate: lastDonationDate,
        availabilityStatus: availabilityStatus,
      );

      if (_disposed) {
        return true;
      }

      _donorProfile = profile;
      _error = null;

      await _startRealtime();

      return true;
    } catch (error) {
      if (!_disposed) {
        _error = _cleanError(error);
      }

      return false;
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  // ============================================================
  // UPDATE DONOR PROFILE
  // ============================================================

  Future<bool> updateDonorProfile({
    required DateTime dateOfBirth,
    required double weight,
    DateTime? lastDonationDate,
    required String availabilityStatus,
  }) async {
    if (_disposed || _loading) {
      return false;
    }

    _loading = true;
    _error = null;

    notifyListeners();

    try {
      final profile = await _repository.updateDonorProfile(
        dateOfBirth: dateOfBirth,
        weight: weight,
        lastDonationDate: lastDonationDate,
        availabilityStatus: availabilityStatus,
      );

      if (_disposed) {
        return true;
      }

      _donorProfile = profile;
      _error = null;

      if (!_realtimeStarted) {
        await _startRealtime();
      }

      return true;
    } catch (error) {
      if (!_disposed) {
        _error = _cleanError(error);
      }

      return false;
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  // ============================================================
  // AVAILABILITY
  // ============================================================

  Future<bool> setAvailability(bool isAvailable) async {
    if (_disposed || _loading) {
      return false;
    }

    _loading = true;
    _error = null;

    notifyListeners();

    try {
      final profile = await _repository.updateAvailability(
        isAvailable,
      );

      if (_disposed) {
        return true;
      }

      _donorProfile = profile;
      _error = null;

      return true;
    } catch (error) {
      if (!_disposed) {
        _error = _cleanError(error);
      }

      return false;
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  // ============================================================
  // ELIGIBILITY
  // ============================================================

  Future<bool> updateEligibility(String status) async {
    if (_disposed || _loading) {
      return false;
    }

    final normalizedStatus = status.trim().toLowerCase();

    if (normalizedStatus.isEmpty) {
      _error = 'Please provide a valid eligibility status.';
      notifyListeners();
      return false;
    }

    _loading = true;
    _error = null;

    notifyListeners();

    try {
      final profile = await _repository.updateEligibility(
        normalizedStatus,
      );

      if (_disposed) {
        return true;
      }

      _donorProfile = profile;
      _error = null;

      return true;
    } catch (error) {
      if (!_disposed) {
        _error = _cleanError(error);
      }

      return false;
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  // ============================================================
  // LEAVE DONOR PROGRAM
  // ============================================================

  Future<bool> leaveDonorProgram() async {
    if (_disposed || _loading) {
      return false;
    }

    _loading = true;
    _error = null;

    notifyListeners();

    try {
      await _repository.deleteDonorProfile();

      if (_disposed) {
        return true;
      }

      /*
       * Stop donor-profile realtime after the database deletion.
       * This prevents a stale realtime callback from restoring the
       * deleted profile into provider state.
       */
      await stopRealtime();

      if (_disposed) {
        return true;
      }

      _donorProfile = null;
      _donationHistory = const [];
      _donationHistoryError = null;

      await stopDonationHistoryRealtime();

      if (_disposed) {
        return true;
      }

      _error = null;

      return true;
    } catch (error) {
      if (!_disposed) {
        _error = _cleanError(error);
      }

      return false;
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  // ============================================================
  // REACTIVATE DONOR
  // ============================================================

  Future<bool> reactivateDonor({
    required DateTime dateOfBirth,
    required double weight,
    DateTime? lastDonationDate,
    required String availabilityStatus,
  }) async {
    if (_disposed || _loading) {
      return false;
    }

    _loading = true;
    _error = null;

    notifyListeners();

    try {
      /*
       * DonorRepository.reactivateDonorProfile() re-reads the
       * authoritative public.users.phone_number and restores the
       * real donor records.
       */
      final profile = await _repository.reactivateDonorProfile(
        dateOfBirth: dateOfBirth,
        weight: weight,
        lastDonationDate: lastDonationDate,
        availabilityStatus: availabilityStatus,
      );

      if (_disposed) {
        return true;
      }

      _donorProfile = profile;
      _error = null;

      await _startRealtime();

      return true;
    } catch (error) {
      if (!_disposed) {
        _error = _cleanError(error);
      }

      return false;
    } finally {
      if (!_disposed) {
        _loading = false;
        notifyListeners();
      }
    }
  }

  // ============================================================
  // DONOR REALTIME
  // ============================================================

  Future<void> _startRealtime() async {
    if (_disposed || _realtimeStarted || _realtimeStarting) {
      return;
    }

    _realtimeStarting = true;

    try {
      await _repository.watchDonorProfile(
        (profile) {
          if (_disposed) {
            return;
          }

          _donorProfile = profile;

          if (profile == null) {
            _realtimeStarted = false;
          }

          notifyListeners();
        },
      );

      if (!_disposed) {
        _realtimeStarted = true;
      }
    } catch (error) {
      _realtimeStarted = false;

      if (_disposed) {
        return;
      }

      _error = _cleanError(error);

      notifyListeners();
    } finally {
      _realtimeStarting = false;
    }
  }

  // ============================================================
  // START DONOR REALTIME
  // ============================================================

  Future<void> startRealtime() async {
    if (_disposed) {
      return;
    }

    await _startRealtime();
  }

  // ============================================================
  // STOP DONOR REALTIME
  // ============================================================

  Future<void> stopRealtime() async {
    _realtimeStarted = false;
    _realtimeStarting = false;

    if (_disposed) {
      return;
    }

    try {
      await _repository.disposeRealtime();
    } catch (error) {
      if (_disposed) {
        return;
      }

      _error = _cleanError(error);
    }

    if (!_disposed) {
      notifyListeners();
    }
  }

  // ============================================================
  // PREVIOUS PROFILE
  // ============================================================

  Future<bool> hasPreviousDonorProfile() async {
    if (_disposed) {
      return false;
    }

    try {
      return await _repository.hasPreviousDonorProfile();
    } catch (_) {
      return false;
    }
  }

  // ============================================================
  // SET PROFILE
  // ============================================================

  void setProfile(DonorProfileModel? profile) {
    if (_disposed) {
      return;
    }

    _donorProfile = profile;
    notifyListeners();
  }

  // ============================================================
  // CLEAR PROFILE
  // ============================================================

  void clearDonorProfile() {
    if (_disposed) {
      return;
    }

    _donorProfile = null;
    notifyListeners();
  }

  // ============================================================
  // CLEAR ERROR
  // ============================================================

  void clearError() {
    if (_disposed) {
      return;
    }

    _error = null;
    notifyListeners();
  }

  void clearDonationHistoryError() {
    if (_disposed) {
      return;
    }

    _donationHistoryError = null;
    notifyListeners();
  }

  // ============================================================
  // ERROR CLEANING
  // ============================================================

  String _cleanError(Object error) {
    var message = error.toString().trim();

    if (message.startsWith('Exception: ')) {
      message = message.substring('Exception: '.length).trim();
    }

    if (message.isEmpty) {
      return 'Something went wrong.';
    }

    return message;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    if (_disposed) {
      return;
    }

    _disposed = true;

    _realtimeStarted = false;
    _realtimeStarting = false;

    _donationHistoryRealtimeStarted = false;
    _donationHistoryRealtimeStarting = false;

    unawaited(
      _repository.disposeRealtime(),
    );

    super.dispose();
  }
}