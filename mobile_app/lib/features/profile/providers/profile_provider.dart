import 'package:flutter/material.dart';

import '../models/profile_model.dart';
import '../repositories/profile_repository.dart';

import '../../../core/services/city_service.dart';

class ProfileProvider extends ChangeNotifier {
  final ProfileRepository _repository;

  ProfileProvider({ProfileRepository? repository})
    : _repository = repository ?? ProfileRepository();

  // ============================================================
  // PROFILE
  // ============================================================

  ProfileModel? _profile;

  ProfileModel? get profile => _profile;

  // ============================================================
  // LOADING
  // ============================================================

  bool _loading = false;

  bool get loading => _loading;

  // ============================================================
  // ERROR
  // ============================================================

  String? _error;

  String? get error => _error;

  // ============================================================
  // PROVINCE & CITY
  // ============================================================

  List<String> _provinces = [];

  List<String> get provinces => List.unmodifiable(_provinces);

  List<String> _cities = [];

  List<String> get cities => List.unmodifiable(_cities);

  String? _selectedProvince;

  String? get selectedProvince => _selectedProvince;

  String? _selectedCity;

  String? get selectedCity => _selectedCity;

  // ============================================================
  // LOAD PROVINCES
  // ============================================================

  Future<void> loadProvinces() async {
    try {
      _error = null;

      _provinces = await CityService.getProvinces();

      notifyListeners();
    } catch (e) {
      _error = _cleanError(e);

      notifyListeners();
    }
  }

  // ============================================================
  // SELECT PROVINCE
  // ============================================================

  Future<void> selectProvince(String province) async {
    final normalizedProvince = province.trim();

    if (normalizedProvince.isEmpty) {
      _selectedProvince = null;
      _selectedCity = null;
      _cities = [];

      notifyListeners();
      return;
    }

    _selectedProvince = normalizedProvince;

    // Province changed, therefore the
    // previously selected city is no longer valid.
    _selectedCity = null;
    _cities = [];
    _error = null;

    notifyListeners();

    try {
      _cities = await CityService.getCities(normalizedProvince);

      notifyListeners();
    } catch (e) {
      _error = _cleanError(e);

      notifyListeners();
    }
  }

  // ============================================================
  // SELECT CITY
  // ============================================================

  void selectCity(String city) {
    final normalizedCity = city.trim();

    _selectedCity = normalizedCity.isEmpty ? null : normalizedCity;

    notifyListeners();
  }

  // ============================================================
  // SET PROFILE
  // ============================================================

  void setProfile(ProfileModel profile) {
    _profile = profile;

    _selectedProvince = _normalizeNullable(profile.province);

    _selectedCity = _normalizeNullable(profile.city);

    _error = null;

    notifyListeners();
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<bool> saveProfile(ProfileModel profile) async {
    if (_loading) {
      return false;
    }

    try {
      _loading = true;
      _error = null;

      notifyListeners();

      await _repository.createProfile(profile);

      _profile = profile;

      _selectedProvince = _normalizeNullable(profile.province);

      _selectedCity = _normalizeNullable(profile.city);

      return true;
    } catch (e) {
      _error = _cleanError(e);

      return false;
    } finally {
      _loading = false;

      notifyListeners();
    }
  }

  // ============================================================
  // LOAD PROFILE
  // ============================================================

  Future<void> loadProfile() async {
    if (_loading) {
      return;
    }

    try {
      _loading = true;
      _error = null;

      notifyListeners();

      _profile = await _repository.getProfile();

      if (_profile != null) {
        _selectedProvince = _normalizeNullable(_profile!.province);

        _selectedCity = _normalizeNullable(_profile!.city);
      }
    } catch (e) {
      _error = _cleanError(e);
    } finally {
      _loading = false;

      notifyListeners();
    }
  }

  // ============================================================
  // UPDATE PROFILE
  // ============================================================

  Future<bool> updateProfile(ProfileModel profile) async {
    if (_loading) {
      return false;
    }

    try {
      _loading = true;
      _error = null;

      notifyListeners();

      await _repository.updateProfile(profile);

      _profile = profile;

      _selectedProvince = _normalizeNullable(profile.province);

      _selectedCity = _normalizeNullable(profile.city);

      return true;
    } catch (e) {
      _error = _cleanError(e);

      return false;
    } finally {
      _loading = false;

      notifyListeners();
    }
  }

  // ============================================================
  // CLEAR PROFILE
  // ============================================================

  void clearProfile() {
    _profile = null;

    _error = null;

    _selectedProvince = null;
    _selectedCity = null;

    _provinces = [];
    _cities = [];

    notifyListeners();
  }

  // ============================================================
  // CLEAR ERROR
  // ============================================================

  void clearError() {
    _error = null;

    notifyListeners();
  }

  // ============================================================
  // HELPERS
  // ============================================================

  String? _normalizeNullable(String? value) {
    final normalized = value?.trim();

    if (normalized == null || normalized.isEmpty) {
      return null;
    }

    return normalized;
  }

  String _cleanError(Object error) {
    final message = error.toString().trim();

    if (message.startsWith('Exception: ')) {
      return message.substring('Exception: '.length);
    }

    return message.isEmpty
        ? 'Something went wrong while saving your profile.'
        : message;
  }
}
