import 'package:flutter/foundation.dart';

import '../repositories/dashboard_repository.dart';

/// ============================================================================
/// DASHBOARD PROVIDER
/// ============================================================================
///
/// Manages dashboard-specific state.
///
/// Responsibilities:
/// - Load user profile information.
/// - Load patient information.
/// - Load donor information.
/// - Load latest reservation.
/// - Track dashboard loading/error state.
/// - Listen for real-time dashboard database changes.
///
/// Notifications are NOT managed here.
/// Notification state has its own dedicated architecture.
///
/// All dashboard values come from the real Supabase repository.
/// Realtime events are treated as change signals. After a change is detected,
/// the authoritative records are loaded again from DashboardRepository.
///
/// Realtime sources:
/// - users
/// - patients
/// - donors
/// - blood_requests
/// - blood_reservations
/// ============================================================================
class DashboardProvider extends ChangeNotifier {
  final DashboardRepository repository;

  String? _realtimeUserId;

  bool _isRealtimeStarted = false;

  bool _disposed = false;

  // Prevents multiple realtime callbacks from performing overlapping
  // dashboard reloads.
  bool _isRealtimeRefreshing = false;

  // --------------------------------------------------------------------------
  // Constructor
  // --------------------------------------------------------------------------

  DashboardProvider({
    required this.repository,
  });

  // ==========================================================================
  // LOADING
  // ==========================================================================

  bool _isLoading = false;

  bool get isLoading => _isLoading;

  // ==========================================================================
  // ERROR
  // ==========================================================================

  String? _errorMessage;

  String? get errorMessage => _errorMessage;

  // ==========================================================================
  // USER DATA
  // ==========================================================================

  String _userName = '';

  String get userName => _userName;

  String _profileImage = '';

  String get profileImage => _profileImage;

  // ==========================================================================
  // PATIENT DATA
  // ==========================================================================

  String _bloodGroup = '';

  String get bloodGroup => _bloodGroup;

  // ==========================================================================
  // DONOR DATA
  // ==========================================================================

  bool _donorAvailable = false;

  bool get donorAvailable => _donorAvailable;

  // ==========================================================================
  // LATEST RESERVATION
  // ==========================================================================

  Map<String, dynamic>? _latestReservation;

  Map<String, dynamic>? get latestReservation =>
      _latestReservation;

  // ==========================================================================
  // LOAD DASHBOARD
  // ==========================================================================

  Future<void> loadDashboard(
    String userId,
  ) async {
    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty || _disposed) {
      return;
    }

    /*
     * Do not start another complete dashboard load while one is already
     * running.
     */
    if (_isLoading) {
      return;
    }

    try {
      _isLoading = true;
      _errorMessage = null;

      notifyListeners();

      // ======================================================================
      // RESET DASHBOARD DATA
      // ======================================================================

      _userName = '';
      _profileImage = '';
      _bloodGroup = '';
      _donorAvailable = false;
      _latestReservation = null;

      // ======================================================================
      // USER PROFILE
      // ======================================================================

      final user = await repository.getUserProfile(
        normalizedUserId,
      );

      if (_disposed) {
        return;
      }

      _userName =
          user['full_name']?.toString() ?? '';

      _profileImage =
          user['profile_image']?.toString() ?? '';

      // ======================================================================
      // PATIENT DATA
      // ======================================================================

      final patient = await repository.getPatientData(
        normalizedUserId,
      );

      if (_disposed) {
        return;
      }

      if (patient != null) {
        _bloodGroup =
            patient['blood_group']?.toString() ?? '';
      }

      // ======================================================================
      // DONOR DATA
      // ======================================================================

      final donor = await repository.getDonorData(
        normalizedUserId,
      );

      if (_disposed) {
        return;
      }

      if (donor != null) {
        _donorAvailable =
            donor['availability_status'] == 'available';
      }

      // ======================================================================
      // LATEST RESERVATION
      // ======================================================================

      _latestReservation =
          await repository.getLatestReservation(
        normalizedUserId,
      );

      if (_disposed) {
        return;
      }

      // ======================================================================
      // START DASHBOARD REALTIME
      // ======================================================================

      await startRealtime(
        normalizedUserId,
      );
    } catch (error) {
      if (_disposed) {
        return;
      }

      _errorMessage = _cleanError(error);

      debugPrint(
        'DashboardProvider.loadDashboard error: $error',
      );
    } finally {
      if (!_disposed) {
        _isLoading = false;

        notifyListeners();
      }
    }
  }

  // ==========================================================================
  // DASHBOARD REALTIME
  // ==========================================================================

  Future<void> startRealtime(
    String userId,
  ) async {
    if (_disposed) {
      return;
    }

    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return;
    }

    /*
     * Prevent duplicate dashboard channels for the same authenticated user.
     */
    if (_isRealtimeStarted &&
        _realtimeUserId == normalizedUserId) {
      return;
    }

    await stopRealtime();

    if (_disposed) {
      return;
    }

    _realtimeUserId = normalizedUserId;
    _isRealtimeStarted = true;

    try {
      await repository.startRealtime(
        userId: normalizedUserId,
        onChanged: () {
          _handleRealtimeChange(
            normalizedUserId,
          );
        },
      );
    } catch (error) {
      _isRealtimeStarted = false;
      _realtimeUserId = null;

      if (_disposed) {
        return;
      }

      _errorMessage = _cleanError(error);

      debugPrint(
        'Dashboard realtime start error: $error',
      );

      notifyListeners();
    }
  }

  // ==========================================================================
  // HANDLE REALTIME CHANGE
  // ==========================================================================

  Future<void> _handleRealtimeChange(
    String userId,
  ) async {
    if (_disposed || !hasListeners) {
      return;
    }

    /*
     * Supabase can emit multiple events in a short period.
     *
     * Prevent overlapping reloads. The next realtime event can trigger another
     * reload after the current one has finished.
     */
    if (_isRealtimeRefreshing) {
      return;
    }

    _isRealtimeRefreshing = true;

    try {
      await _refreshDashboardDataFromDatabase(
        userId,
      );
    } catch (error) {
      if (!_disposed) {
        debugPrint(
          'Dashboard realtime refresh error: $error',
        );
      }
    } finally {
      _isRealtimeRefreshing = false;
    }
  }

  // ==========================================================================
  // REFRESH DASHBOARD DATA FROM AUTHORITATIVE DATABASE
  // ==========================================================================

  Future<void> _refreshDashboardDataFromDatabase(
    String userId,
  ) async {
    if (_disposed) {
      return;
    }

    /*
     * Reload each dashboard section from the repository.
     *
     * The realtime payload itself is intentionally not used as the dashboard
     * model because the repository queries provide the authoritative joined
     * records required by the UI.
     */

    final user = await repository.getUserProfile(
      userId,
    );

    if (_disposed) {
      return;
    }

    final patient = await repository.getPatientData(
      userId,
    );

    if (_disposed) {
      return;
    }

    final donor = await repository.getDonorData(
      userId,
    );

    if (_disposed) {
      return;
    }

    final latestReservation =
        await repository.getLatestReservation(
      userId,
    );

    if (_disposed) {
      return;
    }

    // ========================================================================
    // APPLY USER DATA
    // ========================================================================

    _userName =
        user['full_name']?.toString() ?? '';

    _profileImage =
        user['profile_image']?.toString() ?? '';

    // ========================================================================
    // APPLY PATIENT DATA
    // ========================================================================

    _bloodGroup = '';

    if (patient != null) {
      _bloodGroup =
          patient['blood_group']?.toString() ?? '';
    }

    // ========================================================================
    // APPLY DONOR DATA
    // ========================================================================

    _donorAvailable = false;

    if (donor != null) {
      _donorAvailable =
          donor['availability_status'] == 'available';
    }

    // ========================================================================
    // APPLY RESERVATION
    // ========================================================================

    _latestReservation =
        latestReservation;

    if (!_disposed && hasListeners) {
      notifyListeners();
    }
  }

  // ==========================================================================
  // STOP DASHBOARD REALTIME
  // ==========================================================================

  Future<void> stopRealtime() async {
    if (!_isRealtimeStarted) {
      _realtimeUserId = null;
      return;
    }

    try {
      await repository.stopRealtime();
    } catch (error) {
      debugPrint(
        'Dashboard realtime dispose error: $error',
      );
    } finally {
      _realtimeUserId = null;
      _isRealtimeStarted = false;
      _isRealtimeRefreshing = false;
    }
  }

  // ==========================================================================
  // BACKWARD-COMPATIBLE BLOOD REQUEST REALTIME METHOD
  // ==========================================================================

  /*
   * Existing dashboard code may still call this method.
   *
   * Keep it as a compatibility wrapper, but route it through the new
   * dashboard-wide realtime architecture.
   */
  Future<void> startBloodRequestRealtime(
    String userId,
  ) async {
    await startRealtime(
      userId,
    );
  }

  // ==========================================================================
  // STOP BACKWARD-COMPATIBLE REALTIME METHOD
  // ==========================================================================

  Future<void> stopBloodRequestRealtime() async {
    await stopRealtime();
  }

  // ==========================================================================
  // REFRESH USER PROFILE
  // ==========================================================================

  Future<void> refreshUserProfile(
    String userId,
  ) async {
    if (_disposed) {
      return;
    }

    final normalizedUserId = userId.trim();

    if (normalizedUserId.isEmpty) {
      return;
    }

    try {
      final user =
          await repository.getUserProfile(
        normalizedUserId,
      );

      if (_disposed) {
        return;
      }

      _userName =
          user['full_name']?.toString() ?? '';

      _profileImage =
          user['profile_image']?.toString() ?? '';

      if (hasListeners) {
        notifyListeners();
      }
    } catch (error) {
      debugPrint(
        'Failed to refresh user profile: $error',
      );
    }
  }

  // ==========================================================================
  // REFRESH DASHBOARD
  // ==========================================================================

  Future<void> refreshDashboard(
    String userId,
  ) async {
    if (_disposed) {
      return;
    }

    await loadDashboard(
      userId,
    );
  }

  // ==========================================================================
  // CLEAR ERROR
  // ==========================================================================

  void clearError() {
    if (_disposed || _errorMessage == null) {
      return;
    }

    _errorMessage = null;

    if (hasListeners) {
      notifyListeners();
    }
  }

  // ==========================================================================
  // ERROR HANDLING
  // ==========================================================================

  String _cleanError(
    Object error,
  ) {
    final message = error
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        )
        .trim();

    return message.isEmpty
        ? 'Something went wrong.'
        : message;
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _disposed = true;

    _realtimeUserId = null;
    _isRealtimeStarted = false;
    _isRealtimeRefreshing = false;

    /*
     * Repository owns the Supabase realtime channel.
     *
     * dispose() cannot await asynchronous cleanup, so the cleanup is started
     * without blocking ChangeNotifier disposal.
     */
    repository.stopRealtime();

    super.dispose();
  }
}