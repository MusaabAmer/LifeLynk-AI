import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../../services/emergency_location_service.dart';
import '../../services/nearby_resource_service.dart';

import '../../data/models/emergency_sos_model.dart';
import '../../data/models/nearby_resource_model.dart';

import '../../data/repositories/sos_repository.dart';

class SosProvider extends ChangeNotifier {
  final SosRepository repository;

  final EmergencyLocationService locationService =
      EmergencyLocationService();

  final NearbyResourceService nearbyResourceService =
      NearbyResourceService();

  SosProvider({
    required this.repository,
  });

  // ============================================================
  // STATE
  // ============================================================

  EmergencySosModel? _activeSos;

  EmergencySosModel? get activeSos => _activeSos;

  List<EmergencySosModel> _history = [];

  List<EmergencySosModel> get history =>
      List.unmodifiable(_history);

  // ============================================================
  // BLOOD GROUP SELECTION
  // ============================================================

  List<Map<String, String>> _bloodGroups = [];

  List<Map<String, String>> get bloodGroups =>
      List.unmodifiable(_bloodGroups);

  String? _selectedBloodGroupId;

  String? get selectedBloodGroupId =>
      _selectedBloodGroupId;

  /// Human-readable code for the currently selected blood group.
  ///
  /// This represents the blood group that will be used for the
  /// next SOS. It does not modify the patient's profile.
  String get selectedBloodGroupCode {
    final selectedId = _selectedBloodGroupId?.trim();

    if (selectedId == null || selectedId.isEmpty) {
      return '';
    }

    for (final group in _bloodGroups) {
      if (group['id'] == selectedId) {
        final code = group['code']?.trim() ?? '';

        if (code.isNotEmpty) {
          return code;
        }

        final name = group['name']?.trim() ?? '';

        if (name.isNotEmpty) {
          return name;
        }
      }
    }

    return bloodGroupName(selectedId);
  }

  // ============================================================
  // REQUIRED UNITS
  // ============================================================

  static const int minimumUnits = 1;
  static const int maximumUnits = 10;

  int _unitsRequired = minimumUnits;

  int get unitsRequired => _unitsRequired;

  /// Change the selected blood group for this SOS only.
  ///
  /// This does not update the patient's profile.
  void setSelectedBloodGroup(
    String? bloodGroupId,
  ) {
    if (_isDisposed) {
      return;
    }

    final normalizedId = bloodGroupId?.trim();

    if (normalizedId == null || normalizedId.isEmpty) {
      return;
    }

    final exists = _bloodGroups.any(
      (group) => group['id'] == normalizedId,
    );

    if (!exists) {
      return;
    }

    if (_selectedBloodGroupId == normalizedId) {
      return;
    }

    _selectedBloodGroupId = normalizedId;

    _safeNotify();
  }

  void incrementUnits() {
    if (_isDisposed) {
      return;
    }

    if (_unitsRequired >= maximumUnits) {
      return;
    }

    _unitsRequired++;

    _safeNotify();
  }

  void decrementUnits() {
    if (_isDisposed) {
      return;
    }

    if (_unitsRequired <= minimumUnits) {
      return;
    }

    _unitsRequired--;

    _safeNotify();
  }

  void setUnitsRequired(
    int units,
  ) {
    if (_isDisposed) {
      return;
    }

    final normalizedUnits = units.clamp(
      minimumUnits,
      maximumUnits,
    );

    if (_unitsRequired == normalizedUnits) {
      return;
    }

    _unitsRequired = normalizedUnits;

    _safeNotify();
  }

  // ============================================================
  // NEARBY RESOURCES
  // ============================================================

  List<NearbyResourceModel> _nearbyResources = [];

  List<NearbyResourceModel> get nearbyResources =>
      List.unmodifiable(_nearbyResources);

  bool _nearbyResourcesLoading = false;

  bool get nearbyResourcesLoading =>
      _nearbyResourcesLoading;

  String? _nearbyResourcesError;

  String? get nearbyResourcesError =>
      _nearbyResourcesError;

  // ============================================================
  // GENERAL STATE
  // ============================================================

  bool _loading = false;

  bool get loading => _loading;

  bool _creating = false;

  bool get creating => _creating;

  bool _cancelling = false;

  bool get cancelling => _cancelling;

  String? _error;

  String? get error => _error;

  // ============================================================
  // LOCATION STATE
  // ============================================================

  EmergencyLocationErrorType? _locationErrorType;

  EmergencyLocationErrorType? get locationErrorType =>
      _locationErrorType;

  bool get isLocationServiceDisabled =>
      _locationErrorType ==
      EmergencyLocationErrorType.serviceDisabled;

  bool get isLocationPermissionDenied =>
      _locationErrorType ==
      EmergencyLocationErrorType.permissionDenied;

  bool get isLocationPermissionDeniedForever =>
      _locationErrorType ==
      EmergencyLocationErrorType.permissionDeniedForever;

  bool get isLocationTimeout =>
      _locationErrorType ==
      EmergencyLocationErrorType.timeout;

  void clearLocationError() {
    if (_isDisposed) {
      return;
    }

    _locationErrorType = null;

    _safeNotify();
  }

  Future<bool> openLocationSettings() async {
    try {
      return await locationService.openLocationSettings();
    } catch (e) {
      if (!_isDisposed) {
        _error = _cleanError(e);
        _safeNotify();
      }

      return false;
    }
  }

  Future<bool> openAppSettings() async {
    try {
      return await locationService.openAppSettings();
    } catch (e) {
      if (!_isDisposed) {
        _error = _cleanError(e);
        _safeNotify();
      }

      return false;
    }
  }

  // ============================================================
  // REALTIME
  // ============================================================

  StreamSubscription<EmergencySosModel?>? _sosSubscription;

  String? _realtimeUserId;

  // ============================================================
  // RESOURCE LOCATION / BLOOD GROUP TRACKING
  // ============================================================

  double? _lastResourceLatitude;

  double? _lastResourceLongitude;

  String? _lastResourceBloodGroupId;

  // ============================================================
  // BLOOD GROUP NAME CACHE
  // ============================================================

  final Map<String, String> _bloodGroupNames = {};

  // ============================================================
  // CITY NAME CACHE
  // ============================================================

  final Map<String, String> _cityNames = {};

  // ============================================================
  // CITY -> PROVINCE ID CACHE
  // ============================================================

  final Map<String, String> _cityProvinceIds = {};

  // ============================================================
  // PROVINCE NAME CACHE
  // ============================================================

  final Map<String, String> _provinceNames = {};

  // ============================================================
  // SOS ADDRESS CACHE
  // ============================================================

  /*
   * Addresses are derived from the actual SOS GPS coordinates.
   *
   * We intentionally do not add an address column to
   * emergency_sos.
   *
   * GPS latitude/longitude remain the source of truth.
   */
  final Map<String, String> _sosAddresses = {};

  /// Returns the reverse-geocoded address for an SOS.
  ///
  /// If reverse geocoding has not completed yet, this returns null.
  String? sosAddress(
    String sosId,
  ) {
    final id = sosId.trim();

    if (id.isEmpty) {
      return null;
    }

    final address = _sosAddresses[id]?.trim();

    if (address == null || address.isEmpty) {
      return null;
    }

    return address;
  }

  /// Returns the active SOS's resolved address, if available.
  String? get activeSosAddress {
    final sos = _activeSos;

    if (sos == null) {
      return null;
    }

    return sosAddress(sos.id);
  }

  // ============================================================
  // LOAD SOS DATA
  // ============================================================

  Future<void> loadSosData() async {
    if (_isDisposed) {
      return;
    }

    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _error = 'User is not authenticated.';
      _safeNotify();
      return;
    }

    try {
      _loading = true;
      _error = null;

      _safeNotify();

      // ========================================================
      // LOAD BLOOD GROUPS
      // ========================================================

      await _loadBloodGroups(user.id);

      if (_isDisposed) {
        return;
      }

      // ========================================================
      // ACTIVE SOS
      // ========================================================

      _activeSos = await repository.getActiveSos(
        user.id,
      );

      if (_isDisposed) {
        return;
      }

      // ========================================================
      // SOS HISTORY
      // ========================================================

      _history = await repository.getSosHistory(
        user.id,
      );

      if (_isDisposed) {
        return;
      }

      // ========================================================
      // LOAD HISTORY NAMES
      // ========================================================

      await _loadBloodGroupNames(_history);

      await _loadLocationNames(_history);

      await _loadAddresses(_history);

      if (_isDisposed) {
        return;
      }

      // ========================================================
      // LOAD ACTIVE SOS NAMES
      // ========================================================

      if (_activeSos != null) {
        await _loadBloodGroupNames([
          _activeSos!,
        ]);

        await _loadLocationNames([
          _activeSos!,
        ]);

        await _loadAddresses([
          _activeSos!,
        ]);

        if (_isDisposed) {
          return;
        }

        // Keep the form synchronized with the actual active SOS.
        _selectedBloodGroupId =
            _activeSos!.bloodGroupId.trim();

        _unitsRequired = _normalizeUnits(
          _activeSos!.unitsRequired,
        );
      } else {
        // ======================================================
        // RESTORE NEXT SOS FORM
        // ======================================================

        await _restoreDefaultSosForm();

        if (_isDisposed) {
          return;
        }
      }

      // ========================================================
      // LOAD NEARBY RESOURCES
      // ========================================================

      if (_activeSos != null &&
          _activeSos!.hasLocation) {
        await _loadNearbyResources(
          _activeSos!,
          forceRefresh: true,
        );
      } else {
        _clearNearbyResources();
      }

      if (_isDisposed) {
        return;
      }

      // ========================================================
      // REALTIME
      // ========================================================

      _startRealtimeListener(user.id);
    } catch (e) {
      if (!_isDisposed) {
        _error = _cleanError(e);
      }
    } finally {
      if (!_isDisposed) {
        _loading = false;
        _safeNotify();
      }
    }
  }

  // ============================================================
  // LOAD BLOOD GROUPS
  // ============================================================

  Future<void> _loadBloodGroups(
    String userId,
  ) async {
    if (_isDisposed) {
      return;
    }

    try {
      final groups = await repository.getBloodGroups();

      if (_isDisposed) {
        return;
      }

      _bloodGroups = groups;

      // ========================================================
      // KEEP CURRENT SELECTION IF STILL VALID
      // ========================================================

      if (_selectedBloodGroupId != null &&
          _bloodGroups.any(
            (group) =>
                group['id'] == _selectedBloodGroupId,
          )) {
        return;
      }

      // ========================================================
      // DEFAULT TO PATIENT BLOOD GROUP
      // ========================================================

      final patientBloodGroupId =
          await repository.getUserBloodGroupId(
        userId,
      );

      if (_isDisposed) {
        return;
      }

      final normalizedPatientBloodGroupId =
          patientBloodGroupId?.trim();

      if (normalizedPatientBloodGroupId != null &&
          normalizedPatientBloodGroupId.isNotEmpty &&
          _bloodGroups.any(
            (group) =>
                group['id'] ==
                normalizedPatientBloodGroupId,
          )) {
        _selectedBloodGroupId =
            normalizedPatientBloodGroupId;

        return;
      }

      // ========================================================
      // DATABASE FALLBACK
      // ========================================================

      if (_bloodGroups.isNotEmpty) {
        _selectedBloodGroupId =
            _bloodGroups.first['id'];
      }
    } catch (e) {
      if (_isDisposed) {
        return;
      }

      /*
       * Blood group data is required for SOS creation.
       * Surface the actual database error.
       */
      _error = _cleanError(e);
    }
  }

  // ============================================================
  // ACTIVATE SOS
  // ============================================================

  Future<bool> activateSos() async {
    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) {
      _error = 'User is not authenticated.';
      _safeNotify();
      return false;
    }

    // ==========================================================
    // PREVENT DUPLICATE ACTIVE SOS
    // ==========================================================

    if (_activeSos != null &&
        _activeSos!.isActive) {
      _error =
          'You already have an active SOS request.';

      _safeNotify();

      return false;
    }

    if (_creating) {
      return false;
    }

    try {
      _creating = true;
      _error = null;
      _locationErrorType = null;

      _safeNotify();

      // ========================================================
      // 1. VALIDATE SELECTED BLOOD GROUP
      // ========================================================

      final selectedBloodGroupId =
          _selectedBloodGroupId?.trim();

      if (selectedBloodGroupId == null ||
          selectedBloodGroupId.isEmpty) {
        _error =
            'Please select a blood group before activating SOS.';

        return false;
      }

      final bloodGroupExists = _bloodGroups.any(
        (group) =>
            group['id'] == selectedBloodGroupId,
      );

      if (!bloodGroupExists) {
        _error =
            'The selected blood group is no longer available. Please refresh and try again.';

        return false;
      }

      // ========================================================
      // 2. VALIDATE REQUIRED UNITS
      // ========================================================

      if (_unitsRequired < minimumUnits ||
          _unitsRequired > maximumUnits) {
        _error =
            'Please select a valid number of required blood units.';

        return false;
      }

      if (_isDisposed) {
        return false;
      }

      // ========================================================
      // 3. GET REAL GPS LOCATION
      // ========================================================

      PositionWithLocation? location;

      try {
        final position =
            await locationService.getCurrentLocation();

        location = PositionWithLocation(
          latitude: position.latitude,
          longitude: position.longitude,
          accuracy: position.accuracy,
          timestamp: position.timestamp,
        );
      } on EmergencyLocationException catch (e) {
        if (!_isDisposed) {
          _locationErrorType = e.type;
          _error = e.message;

          _safeNotify();
        }

        return false;
      }

      if (_isDisposed) {
        return false;
      }

      // ========================================================
      // 4. CREATE REAL SOS RECORD
      // ========================================================

      final sos = await repository.createSos(
        userId: user.id,
        bloodGroupId: selectedBloodGroupId,
        unitsRequired: _unitsRequired,
        urgencyLevel: 'critical',
        description:
            'Emergency SOS activated from current device location.',
        latitude: location.latitude,
        longitude: location.longitude,
        gpsAccuracy: location.accuracy,
        locationTimestamp: location.timestamp,
      );

      if (_isDisposed) {
        return false;
      }

      // ========================================================
      // 5. SAVE ACTIVE SOS
      // ========================================================

      _activeSos = sos;

      _locationErrorType = null;

      // ========================================================
      // 6. KEEP FORM SYNCHRONIZED WITH ACTIVE SOS
      // ========================================================

      _selectedBloodGroupId =
          sos.bloodGroupId.trim();

      _unitsRequired = _normalizeUnits(
        sos.unitsRequired,
      );

      // ========================================================
      // 7. LOAD DISPLAY NAMES
      // ========================================================

      await _loadBloodGroupNames([
        sos,
      ]);

      await _loadLocationNames([
        sos,
      ]);

      // ========================================================
      // 8. REVERSE GEOCODE ACTUAL GPS LOCATION
      // ========================================================

      await _loadAddresses([
        sos,
      ]);

      if (_isDisposed) {
        return false;
      }

      // ========================================================
      // 9. FIND NEARBY REAL RESOURCES
      // ========================================================

      await _loadNearbyResources(
        sos,
        forceRefresh: true,
      );

      if (_isDisposed) {
        return false;
      }

      // ========================================================
      // 10. REFRESH HISTORY
      // ========================================================

      _history = await repository.getSosHistory(
        user.id,
      );

      await _loadBloodGroupNames(_history);

      await _loadLocationNames(_history);

      await _loadAddresses(_history);

      if (_isDisposed) {
        return false;
      }

      // ========================================================
      // 11. REALTIME LISTENER
      // ========================================================

      _startRealtimeListener(user.id);

      _safeNotify();

      return true;
    } catch (e) {
      if (!_isDisposed) {
        _error = _cleanError(e);
      }

      return false;
    } finally {
      if (!_isDisposed) {
        _creating = false;
        _safeNotify();
      }
    }
  }

  // ============================================================
  // START REALTIME LISTENER
  // ============================================================

  void _startRealtimeListener(
    String userId,
  ) {
    if (_isDisposed) {
      return;
    }

    if (_realtimeUserId == userId &&
        _sosSubscription != null) {
      return;
    }

    _sosSubscription?.cancel();

    _sosSubscription = null;

    _realtimeUserId = userId;

    _sosSubscription = repository
        .watchActiveSos(userId)
        .listen(
      (sos) {
        if (_isDisposed) {
          return;
        }

        _handleRealtimeSosUpdate(sos);
      },
      onError: (error) {
        if (_isDisposed) {
          return;
        }

        _error = _cleanError(error);

        _safeNotify();
      },
      cancelOnError: false,
    );
  }

  // ============================================================
  // HANDLE REALTIME SOS UPDATE
  // ============================================================

  Future<void> _handleRealtimeSosUpdate(
    EmergencySosModel? sos,
  ) async {
    if (_isDisposed) {
      return;
    }

    final previousSos = _activeSos;

    // ==========================================================
    // SOS NO LONGER ACTIVE
    // ==========================================================

    if (sos == null) {
      _activeSos = null;

      _clearNearbyResources();

      await _reloadHistory();

      if (_isDisposed) {
        return;
      }

      await _restoreDefaultSosForm();

      if (_isDisposed) {
        return;
      }

      _safeNotify();

      return;
    }

    // ==========================================================
    // CHECK LOCATION CHANGE
    // ==========================================================

    final locationChanged =
        previousSos == null ||
        previousSos.latitude != sos.latitude ||
        previousSos.longitude != sos.longitude;

    // ==========================================================
    // CHECK BLOOD GROUP CHANGE
    // ==========================================================

    final bloodGroupChanged =
        previousSos == null ||
        previousSos.bloodGroupId != sos.bloodGroupId;

    // ==========================================================
    // CHECK STATUS CHANGE
    // ==========================================================

    final statusChanged =
        previousSos == null ||
        previousSos.status != sos.status;

    // ==========================================================
    // CHECK UNITS CHANGE
    // ==========================================================

    final unitsChanged =
        previousSos == null ||
        previousSos.unitsRequired != sos.unitsRequired;

    // ==========================================================
    // UPDATE ACTIVE SOS
    // ==========================================================

    _activeSos = sos;

    /*
     * The database record is the source of truth for an active SOS.
     * Keep the UI form synchronized with it.
     */
    _selectedBloodGroupId =
        sos.bloodGroupId.trim();

    _unitsRequired = _normalizeUnits(
      sos.unitsRequired,
    );

    // ==========================================================
    // RESOLVE DISPLAY NAMES
    // ==========================================================

    await _loadBloodGroupNames([
      sos,
    ]);

    await _loadLocationNames([
      sos,
    ]);

    // ==========================================================
    // RESOLVE ACTUAL GPS ADDRESS
    // ==========================================================

    if (locationChanged) {
      _sosAddresses.remove(sos.id);

      await _loadAddresses([
        sos,
      ]);
    } else {
      final cachedAddress =
          _sosAddresses[sos.id]?.trim();

      if (cachedAddress == null ||
          cachedAddress.isEmpty) {
        await _loadAddresses([
          sos,
        ]);
      }
    }

    if (_isDisposed) {
      return;
    }

    _safeNotify();

    // ==========================================================
    // REFRESH NEARBY RESOURCES
    // ==========================================================

    if (sos.hasLocation &&
        (locationChanged || bloodGroupChanged)) {
      await _loadNearbyResources(
        sos,
        notify: true,
        forceRefresh: true,
      );
    }

    if (_isDisposed) {
      return;
    }

    if (statusChanged || unitsChanged) {
      _safeNotify();
    }
  }

  // ============================================================
  // LOAD SOS ADDRESSES
  // ============================================================

  Future<void> _loadAddresses(
    List<EmergencySosModel> sosList,
  ) async {
    if (_isDisposed || sosList.isEmpty) {
      return;
    }

    bool addressChanged = false;

    for (final sos in sosList) {
      if (_isDisposed) {
        return;
      }

      if (!sos.hasLocation) {
        continue;
      }

      final existingAddress =
          _sosAddresses[sos.id]?.trim();

      if (existingAddress != null &&
          existingAddress.isNotEmpty) {
        continue;
      }

      final latitude = sos.latitude;
      final longitude = sos.longitude;

      if (latitude == null || longitude == null) {
        continue;
      }

      try {
        final address =
            await locationService.getAddressFromCoordinates(
          latitude: latitude,
          longitude: longitude,
        );

        if (_isDisposed) {
          return;
        }

        final normalizedAddress = address?.trim();

        if (normalizedAddress != null &&
            normalizedAddress.isNotEmpty) {
          _sosAddresses[sos.id] =
              normalizedAddress;

          addressChanged = true;
        }
      } catch (_) {
        /*
         * Reverse-geocoding failure must never prevent
         * SOS data from loading.
         *
         * The UI falls back to city/province/GPS.
         */
      }
    }

    if (!_isDisposed && addressChanged) {
      _safeNotify();
    }
  }

  // ============================================================
  // LOAD NEARBY RESOURCES
  // ============================================================

  Future<void> _loadNearbyResources(
    EmergencySosModel sos, {
    bool notify = false,
    bool forceRefresh = false,
  }) async {
    if (_isDisposed) {
      return;
    }

    if (!sos.hasLocation) {
      _clearNearbyResources();

      if (notify) {
        _safeNotify();
      }

      return;
    }

    final latitude = sos.latitude!;
    final longitude = sos.longitude!;
    final bloodGroupId = sos.bloodGroupId.trim();

    // ==========================================================
    // PREVENT UNNECESSARY DUPLICATE REQUEST
    // ==========================================================

    if (!forceRefresh &&
        _lastResourceLatitude == latitude &&
        _lastResourceLongitude == longitude &&
        _lastResourceBloodGroupId == bloodGroupId &&
        _nearbyResources.isNotEmpty) {
      return;
    }

    try {
      _nearbyResourcesLoading = true;
      _nearbyResourcesError = null;

      if (notify) {
        _safeNotify();
      }

      // ========================================================
      // FIND NEARBY REAL RESOURCES
      // ========================================================

      final resources =
          await nearbyResourceService.findNearbyResources(
        latitude: latitude,
        longitude: longitude,
        bloodGroupId:
            bloodGroupId.isEmpty
                ? null
                : bloodGroupId,
      );

      if (_isDisposed) {
        return;
      }

      // ========================================================
      // SAVE RESOURCES
      // ========================================================

      _nearbyResources = resources;

      // ========================================================
      // SAVE CACHE PARAMETERS
      // ========================================================

      _lastResourceLatitude = latitude;
      _lastResourceLongitude = longitude;

      _lastResourceBloodGroupId =
          bloodGroupId.isEmpty
              ? null
              : bloodGroupId;

      _nearbyResourcesError = null;
    } catch (e) {
      if (_isDisposed) {
        return;
      }

      /*
       * Nearby-resource failure must never invalidate the SOS.
       */
      _nearbyResources = [];

      _lastResourceLatitude = null;
      _lastResourceLongitude = null;
      _lastResourceBloodGroupId = null;

      _nearbyResourcesError = _cleanError(e);
    } finally {
      if (!_isDisposed) {
        _nearbyResourcesLoading = false;

        if (notify) {
          _safeNotify();
        }
      }
    }
  }

  // ============================================================
  // CANCEL SOS
  // ============================================================

  Future<bool> cancelSos() async {
    final sos = _activeSos;

    if (sos == null) {
      _error = 'There is no active SOS request.';
      _safeNotify();
      return false;
    }

    if (_cancelling) {
      return false;
    }

    try {
      _cancelling = true;
      _error = null;

      _safeNotify();

      // ========================================================
      // DATABASE IS SOURCE OF TRUTH
      // ========================================================

      await repository.cancelSos(
        sos.id,
      );

      if (_isDisposed) {
        return true;
      }

      // ========================================================
      // CLEAR ACTIVE SOS
      // ========================================================

      _activeSos = null;

      // ========================================================
      // CLEAR ACTIVE ADDRESS
      // ========================================================

      _sosAddresses.remove(
        sos.id,
      );

      // ========================================================
      // CLEAR OLD RESOURCES
      // ========================================================

      _clearNearbyResources();

      // ========================================================
      // REFRESH HISTORY
      // ========================================================

      await _reloadHistory();

      if (_isDisposed) {
        return true;
      }

      // ========================================================
      // RESET FORM
      // ========================================================

      await _restoreDefaultSosForm();

      if (_isDisposed) {
        return true;
      }

      _safeNotify();

      return true;
    } catch (e) {
      if (!_isDisposed) {
        _error = _cleanError(e);
      }

      return false;
    } finally {
      if (!_isDisposed) {
        _cancelling = false;
        _safeNotify();
      }
    }
  }

  // ============================================================
  // COMPLETE SOS
  // ============================================================

  Future<bool> completeSos() async {
    final sos = _activeSos;

    if (sos == null) {
      _error = 'There is no active SOS request.';
      _safeNotify();
      return false;
    }

    try {
      _loading = true;
      _error = null;

      _safeNotify();

      // ========================================================
      // DATABASE UPDATE
      // ========================================================

      await repository.completeSos(
        sos.id,
      );

      if (_isDisposed) {
        return true;
      }

      // ========================================================
      // CLEAR ACTIVE SOS
      // ========================================================

      _activeSos = null;

      // ========================================================
      // CLEAR ACTIVE ADDRESS
      // ========================================================

      _sosAddresses.remove(
        sos.id,
      );

      // ========================================================
      // CLEAR RESOURCES
      // ========================================================

      _clearNearbyResources();

      // ========================================================
      // REFRESH HISTORY
      // ========================================================

      await _reloadHistory();

      if (_isDisposed) {
        return true;
      }

      // ========================================================
      // RESET FORM
      // ========================================================

      await _restoreDefaultSosForm();

      if (_isDisposed) {
        return true;
      }

      _safeNotify();

      return true;
    } catch (e) {
      if (!_isDisposed) {
        _error = _cleanError(e);
      }

      return false;
    } finally {
      if (!_isDisposed) {
        _loading = false;
        _safeNotify();
      }
    }
  }

  // ============================================================
  // DELETE SOS HISTORY
  // ============================================================

  Future<bool> deleteSosHistory(
    String sosId,
  ) async {
    if (_isDisposed) {
      return false;
    }

    final normalizedSosId = sosId.trim();

    if (normalizedSosId.isEmpty) {
      _error = 'SOS ID is required.';
      _safeNotify();
      return false;
    }

    // ==========================================================
    // NEVER DELETE ACTIVE SOS
    // ==========================================================

    if (_activeSos?.id == normalizedSosId) {
      _error =
          'An active SOS cannot be deleted. Please cancel or complete it first.';

      _safeNotify();

      return false;
    }

    // ==========================================================
    // FIND HISTORY RECORD
    // ==========================================================

    final historyIndex = _history.indexWhere(
      (sos) => sos.id == normalizedSosId,
    );

    if (historyIndex == -1) {
      _error = 'SOS history record was not found.';
      _safeNotify();
      return false;
    }

    final sos = _history[historyIndex];

    final status = sos.status.trim().toLowerCase();

    // ==========================================================
    // ONLY TERMINAL SOS RECORDS MAY BE DELETED
    // ==========================================================

    if (!SosRepository.terminalStatuses.contains(
      status,
    )) {
      _error =
          'Only completed or cancelled SOS records can be deleted.';

      _safeNotify();

      return false;
    }

    try {
      _error = null;

      // ========================================================
      // REAL DATABASE DELETE
      // ========================================================

      await repository.deleteSosHistory(
        normalizedSosId,
      );

      if (_isDisposed) {
        return true;
      }

      // ========================================================
      // REMOVE LOCAL HISTORY RECORD
      // ========================================================

      _history.removeWhere(
        (item) => item.id == normalizedSosId,
      );

      // ========================================================
      // REMOVE REVERSE-GEOCODE CACHE
      // ========================================================

      _sosAddresses.remove(
        normalizedSosId,
      );

      _safeNotify();

      return true;
    } catch (e) {
      if (!_isDisposed) {
        _error = _cleanError(e);
        _safeNotify();
      }

      return false;
    }
  }

  // ============================================================
  // REFRESH NEARBY RESOURCES
  // ============================================================

  Future<void> refreshNearbyResources() async {
    if (_isDisposed) {
      return;
    }

    final sos = _activeSos;

    if (sos == null || !sos.hasLocation) {
      _clearNearbyResources();
      _safeNotify();
      return;
    }

    _nearbyResourcesError = null;

    await _loadNearbyResources(
      sos,
      notify: true,
      forceRefresh: true,
    );
  }

  // ============================================================
  // CLEAR NEARBY RESOURCE ERROR
  // ============================================================

  void clearNearbyResourcesError() {
    if (_isDisposed) {
      return;
    }

    _nearbyResourcesError = null;

    _safeNotify();
  }

  // ============================================================
  // RELOAD HISTORY
  // ============================================================

  Future<void> _reloadHistory() async {
    if (_isDisposed) {
      return;
    }

    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return;
    }

    _history = await repository.getSosHistory(
      user.id,
    );

    if (_isDisposed) {
      return;
    }

    await _loadBloodGroupNames(
      _history,
    );

    await _loadLocationNames(
      _history,
    );

    await _loadAddresses(
      _history,
    );
  }

  // ============================================================
  // RESTORE DEFAULT SOS FORM
  // ============================================================

  Future<void> _restoreDefaultSosForm() async {
    if (_isDisposed) {
      return;
    }

    _unitsRequired = minimumUnits;

    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return;
    }

    try {
      final patientBloodGroupId =
          await repository.getUserBloodGroupId(
        user.id,
      );

      if (_isDisposed) {
        return;
      }

      final normalizedPatientBloodGroupId =
          patientBloodGroupId?.trim();

      if (normalizedPatientBloodGroupId != null &&
          normalizedPatientBloodGroupId.isNotEmpty &&
          _bloodGroups.any(
            (group) =>
                group['id'] ==
                normalizedPatientBloodGroupId,
          )) {
        _selectedBloodGroupId =
            normalizedPatientBloodGroupId;

        return;
      }

      // Keep the current valid selection if the profile
      // does not currently have a matching blood group.
      if (_selectedBloodGroupId != null &&
          _bloodGroups.any(
            (group) =>
                group['id'] ==
                _selectedBloodGroupId,
          )) {
        return;
      }

      if (_bloodGroups.isNotEmpty) {
        _selectedBloodGroupId =
            _bloodGroups.first['id'];
      }
    } catch (_) {
      if (_isDisposed) {
        return;
      }

      if (_selectedBloodGroupId == null &&
          _bloodGroups.isNotEmpty) {
        _selectedBloodGroupId =
            _bloodGroups.first['id'];
      }
    }
  }

  // ============================================================
  // NORMALIZE UNITS
  // ============================================================

  int _normalizeUnits(
    int units,
  ) {
    return units.clamp(
      minimumUnits,
      maximumUnits,
    );
  }

  // ============================================================
  // CLEAR NEARBY RESOURCES
  // ============================================================

  void _clearNearbyResources() {
    _nearbyResources = [];

    _lastResourceLatitude = null;
    _lastResourceLongitude = null;
    _lastResourceBloodGroupId = null;

    _nearbyResourcesLoading = false;
    _nearbyResourcesError = null;
  }

  // ============================================================
  // BLOOD GROUP NAME
  // ============================================================

  String bloodGroupName(
    String bloodGroupId,
  ) {
    final id = bloodGroupId.trim();

    if (id.isEmpty) {
      return 'Unknown';
    }

    return _bloodGroupNames[id] ??
        _findBloodGroupDisplayName(id) ??
        id;
  }

  String? _findBloodGroupDisplayName(
    String id,
  ) {
    for (final group in _bloodGroups) {
      if (group['id'] == id) {
        final code = group['code']?.trim();

        if (code != null && code.isNotEmpty) {
          return code;
        }

        final name = group['name']?.trim();

        if (name != null && name.isNotEmpty) {
          return name;
        }
      }
    }

    return null;
  }

  // ============================================================
  // LOAD BLOOD GROUP NAMES
  // ============================================================

  Future<void> _loadBloodGroupNames(
    List<EmergencySosModel> sosList,
  ) async {
    if (_isDisposed || sosList.isEmpty) {
      return;
    }

    final ids = sosList
        .map(
          (sos) => sos.bloodGroupId.trim(),
        )
        .where(
          (id) => id.isNotEmpty,
        )
        .toSet()
        .where(
          (id) => !_bloodGroupNames.containsKey(id),
        )
        .toList();

    if (ids.isEmpty) {
      return;
    }

    try {
      final response =
          await Supabase.instance.client
              .from('blood_groups')
              .select('id, code, name')
              .inFilter(
                'id',
                ids,
              )
              .isFilter(
                'deleted_at',
                null,
              );

      if (_isDisposed) {
        return;
      }

      for (final raw in response) {
        final id = raw['id']?.toString().trim();

        final code = raw['code']?.toString().trim();

        final name = raw['name']?.toString().trim();

        if (id == null || id.isEmpty) {
          continue;
        }

        if (code != null && code.isNotEmpty) {
          _bloodGroupNames[id] = code;
        } else if (name != null && name.isNotEmpty) {
          _bloodGroupNames[id] = name;
        }
      }
    } catch (_) {
      /*
       * Keep the blood-group ID or already loaded blood-group
       * data as fallback if this display lookup fails.
       */
    }
  }

  // ============================================================
  // CITY NAME
  // ============================================================

  String cityName(
    String cityId,
  ) {
    final id = cityId.trim();

    if (id.isEmpty) {
      return 'Unknown';
    }

    return _cityNames[id] ?? id;
  }

  // ============================================================
  // PROVINCE NAME
  // ============================================================

  String? provinceName(
    String cityId,
  ) {
    final cityIdValue = cityId.trim();

    if (cityIdValue.isEmpty) {
      return null;
    }

    final provinceId =
        _cityProvinceIds[cityIdValue];

    if (provinceId == null || provinceId.isEmpty) {
      return null;
    }

    return _provinceNames[provinceId];
  }

  // ============================================================
  // LOAD CITY + PROVINCE NAMES
  // ============================================================

  Future<void> _loadLocationNames(
    List<EmergencySosModel> sosList,
  ) async {
    if (_isDisposed || sosList.isEmpty) {
      return;
    }

    final cityIds = sosList
        .map(
          (sos) => sos.cityId?.trim(),
        )
        .whereType<String>()
        .where(
          (id) => id.isNotEmpty,
        )
        .toSet()
        .where(
          (id) =>
              !_cityNames.containsKey(id) ||
              !_cityProvinceIds.containsKey(id),
        )
        .toList();

    if (cityIds.isEmpty) {
      return;
    }

    try {
      // ========================================================
      // LOAD CITIES
      // ========================================================

      final cityResponse =
          await Supabase.instance.client
              .from('cities')
              .select('id, name, province_id')
              .inFilter(
                'id',
                cityIds,
              )
              .isFilter(
                'deleted_at',
                null,
              );

      if (_isDisposed) {
        return;
      }

      final provinceIds = <String>{};

      for (final raw in cityResponse) {
        final id = raw['id']?.toString().trim();

        final name = raw['name']?.toString().trim();

        final provinceId =
            raw['province_id']?.toString().trim();

        if (id == null || id.isEmpty) {
          continue;
        }

        if (name != null && name.isNotEmpty) {
          _cityNames[id] = name;
        }

        if (provinceId != null &&
            provinceId.isNotEmpty) {
          _cityProvinceIds[id] = provinceId;
          provinceIds.add(provinceId);
        }
      }

      // ========================================================
      // LOAD PROVINCES
      // ========================================================

      if (provinceIds.isEmpty) {
        return;
      }

      final provinceResponse =
          await Supabase.instance.client
              .from('provinces')
              .select('id, name')
              .inFilter(
                'id',
                provinceIds.toList(),
              )
              .isFilter(
                'deleted_at',
                null,
              );

      if (_isDisposed) {
        return;
      }

      for (final raw in provinceResponse) {
        final id = raw['id']?.toString().trim();

        final name = raw['name']?.toString().trim();

        if (id == null || id.isEmpty) {
          continue;
        }

        if (name != null && name.isNotEmpty) {
          _provinceNames[id] = name;
        }
      }
    } catch (_) {
      /*
       * Keep ID fallback if lookup fails.
       *
       * Reverse-geocoded GPS addresses remain independent
       * from these city/province lookups.
       */
    }
  }

  // ============================================================
  // CLEAR ERROR
  // ============================================================

  void clearError() {
    if (_isDisposed) {
      return;
    }

    _error = null;

    _safeNotify();
  }

  // ============================================================
  // CLEAN ERROR
  // ============================================================

  String _cleanError(
    Object error,
  ) {
    if (error is EmergencyLocationException) {
      return error.message;
    }

    final message = error.toString();

    if (message.startsWith('Exception: ')) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  // ============================================================
  // SAFE NOTIFY
  // ============================================================

  void _safeNotify() {
    if (!_isDisposed) {
      notifyListeners();
    }
  }

  // ============================================================
  // DISPOSE TRACKING
  // ============================================================

  bool _isDisposed = false;

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _isDisposed = true;

    _sosSubscription?.cancel();

    _sosSubscription = null;

    _realtimeUserId = null;

    super.dispose();
  }
}

// ============================================================================
// INTERNAL LOCATION DATA
// ============================================================================
//
// Keeps the provider independent from the concrete Geolocator Position type
// while preserving the location values required by SosRepository.
//

class PositionWithLocation {
  final double latitude;
  final double longitude;
  final double accuracy;
  final DateTime timestamp;

  const PositionWithLocation({
    required this.latitude,
    required this.longitude,
    required this.accuracy,
    required this.timestamp,
  });
}