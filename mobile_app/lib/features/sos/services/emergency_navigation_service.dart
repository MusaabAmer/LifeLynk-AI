import 'package:url_launcher/url_launcher.dart';

import '../data/models/nearby_resource_model.dart';

/// ============================================================================
/// EMERGENCY NAVIGATION SERVICE
/// ============================================================================
///
/// Centralized navigation and communication service for LifeLynk AI.
///
/// Responsibilities:
///
/// - Open OpenStreetMap driving directions to emergency resources.
/// - Open OpenStreetMap directions from a specific origin to a destination.
/// - Open a resource location in OpenStreetMap.
/// - Open arbitrary coordinates in OpenStreetMap.
/// - Call hospitals, blood banks and donors.
/// - Validate GPS coordinates.
/// - Normalize phone numbers.
///
/// IMPORTANT:
///
/// This service does NOT:
///
/// - Query Supabase.
/// - Read device GPS.
/// - Store location state.
/// - Draw routes on the in-app map.
/// - Manage map camera.
/// - Manage markers.
/// - Manage realtime resources.
///
/// Location state must come from the Provider/GPS layer.
///
/// The in-app map handles camera, markers, polylines and gestures.
/// This service is only responsible for external navigation/location
/// actions and phone calls.
/// ============================================================================

class EmergencyNavigationService {
  const EmergencyNavigationService();

  // ==========================================================================
  // GET DIRECTIONS TO RESOURCE
  // ==========================================================================

  /// Opens OpenStreetMap directions to the supplied resource.
  Future<bool> navigateTo(
    NearbyResourceModel resource,
  ) async {
    return navigateToResource(resource);
  }

  /// Opens OpenStreetMap directions to a resource.
  ///
  /// If [originLatitude] and [originLongitude] are supplied, the route
  /// starts from those coordinates.
  ///
  /// Otherwise the destination is opened in OpenStreetMap and the user
  /// can use their current location through their navigation application.
  static Future<bool> navigateToResource(
    NearbyResourceModel resource, {
    double? originLatitude,
    double? originLongitude,
    NavigationTravelMode travelMode =
        NavigationTravelMode.driving,
  }) async {
    if (!_isValidCoordinate(
      resource.latitude,
      resource.longitude,
    )) {
      return false;
    }

    if ((originLatitude == null) !=
        (originLongitude == null)) {
      return false;
    }

    return navigateToCoordinates(
      latitude: resource.latitude,
      longitude: resource.longitude,
      label: resource.name,
      originLatitude: originLatitude,
      originLongitude: originLongitude,
      travelMode: travelMode,
    );
  }

  // ==========================================================================
  // GET DIRECTIONS TO COORDINATES
  // ==========================================================================

  /// Opens an OpenStreetMap route to arbitrary coordinates.
  ///
  /// When an explicit origin is supplied, the OSM directions URL contains
  /// both origin and destination coordinates.
  ///
  /// When no origin is supplied, the destination is opened in OpenStreetMap.
  static Future<bool> navigateToCoordinates({
    required double latitude,
    required double longitude,
    String? label,
    double? originLatitude,
    double? originLongitude,
    NavigationTravelMode travelMode =
        NavigationTravelMode.driving,
  }) async {
    if (!_isValidCoordinate(
      latitude,
      longitude,
    )) {
      return false;
    }

    if ((originLatitude == null) !=
        (originLongitude == null)) {
      return false;
    }

    if (originLatitude != null &&
        originLongitude != null &&
        !_isValidCoordinate(
          originLatitude,
          originLongitude,
        )) {
      return false;
    }

    // ------------------------------------------------------------------------
    // Explicit origin
    // ------------------------------------------------------------------------

    if (originLatitude != null &&
        originLongitude != null) {
      final route =
          '${_coordinateString(originLatitude, originLongitude)};'
          '${_coordinateString(latitude, longitude)}';

      final uri = Uri.https(
        'www.openstreetmap.org',
        '/directions',
        <String, String>{
          'engine': _engineForTravelMode(travelMode),
          'route': route,
        },
      );

      return _openExternalUrl(uri);
    }

    // ------------------------------------------------------------------------
    // No explicit origin.
    //
    // Open the destination in OpenStreetMap. The user's navigation app can
    // then use the device's current location as the origin.
    // ------------------------------------------------------------------------

    return openCoordinates(
      latitude: latitude,
      longitude: longitude,
      label: label,
    );
  }

  // ==========================================================================
  // OPEN RESOURCE LOCATION
  // ==========================================================================

  /// Opens the resource's location in OpenStreetMap.
  ///
  /// This does NOT start navigation.
  static Future<bool> openResourceLocation(
    NearbyResourceModel resource,
  ) async {
    return openCoordinates(
      latitude: resource.latitude,
      longitude: resource.longitude,
      label: resource.name,
    );
  }

  // ==========================================================================
  // OPEN COORDINATES
  // ==========================================================================

  /// Opens arbitrary coordinates in OpenStreetMap.
  static Future<bool> openCoordinates({
    required double latitude,
    required double longitude,
    String? label,
  }) async {
    if (!_isValidCoordinate(
      latitude,
      longitude,
    )) {
      return false;
    }

    final uri = Uri.https(
      'www.openstreetmap.org',
      '/',
      <String, String>{
        'mlat': latitude.toStringAsFixed(6),
        'mlon': longitude.toStringAsFixed(6),
      },
    );

    return _openExternalUrl(uri);
  }

  // ==========================================================================
  // CALL RESOURCE
  // ==========================================================================

  /// Calls the resource's primary phone number.
  ///
  /// Falls back to [emergencyContact] when [phone] is unavailable.
  static Future<bool> callResource(
    NearbyResourceModel resource,
  ) async {
    final phone =
        _resolvePhoneNumber(resource);

    if (phone == null) {
      return false;
    }

    final cleanedPhone =
        _cleanPhoneNumber(phone);

    if (cleanedPhone.isEmpty) {
      return false;
    }

    final uri = Uri(
      scheme: 'tel',
      path: cleanedPhone,
    );

    return _launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  // ==========================================================================
  // CALL PHONE NUMBER
  // ==========================================================================

  /// Calls an arbitrary phone number.
  static Future<bool> callPhone(
    String phone,
  ) async {
    final cleanedPhone =
        _cleanPhoneNumber(phone);

    if (cleanedPhone.isEmpty) {
      return false;
    }

    final uri = Uri(
      scheme: 'tel',
      path: cleanedPhone,
    );

    return _launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  // ==========================================================================
  // RESOLVE PHONE
  // ==========================================================================

  static String? _resolvePhoneNumber(
    NearbyResourceModel resource,
  ) {
    final phone = resource.phone;

    if (phone != null &&
        phone.trim().isNotEmpty) {
      return phone.trim();
    }

    final emergencyContact =
        resource.emergencyContact;

    if (emergencyContact != null &&
        emergencyContact.trim().isNotEmpty) {
      return emergencyContact.trim();
    }

    return null;
  }

  // ==========================================================================
  // CLEAN PHONE NUMBER
  // ==========================================================================

  static String _cleanPhoneNumber(
    String phone,
  ) {
    final trimmed = phone.trim();

    if (trimmed.isEmpty) {
      return '';
    }

    final hasLeadingPlus =
        trimmed.startsWith('+');

    final digits =
        trimmed.replaceAll(
      RegExp(r'[^0-9]'),
      '',
    );

    if (digits.isEmpty) {
      return '';
    }

    return hasLeadingPlus
        ? '+$digits'
        : digits;
  }

  // ==========================================================================
  // COORDINATE STRING
  // ==========================================================================

  static String _coordinateString(
    double latitude,
    double longitude,
  ) {
    return '${latitude.toStringAsFixed(6)},'
        '${longitude.toStringAsFixed(6)}';
  }

  // ==========================================================================
  // OSM ROUTING ENGINE
  // ==========================================================================

  /// Maps LifeLynk AI travel modes to OpenStreetMap routing engines.
  ///
  /// OSRM is used for driving, walking and cycling.
  /// OpenStreetMap itself provides the map data; routing is supplied by
  /// the selected routing engine.
  static String _engineForTravelMode(
    NavigationTravelMode travelMode,
  ) {
    switch (travelMode) {
      case NavigationTravelMode.driving:
        return 'fossgis_osrm_car';

      case NavigationTravelMode.walking:
        return 'fossgis_osrm_foot';

      case NavigationTravelMode.bicycling:
        return 'fossgis_osrm_bike';

      case NavigationTravelMode.transit:
        return 'fossgis_osrm_car';
    }
  }

  // ==========================================================================
  // VALIDATE COORDINATES
  // ==========================================================================

  static bool _isValidCoordinate(
    double latitude,
    double longitude,
  ) {
    if (!latitude.isFinite ||
        !longitude.isFinite) {
      return false;
    }

    return latitude >= -90 &&
        latitude <= 90 &&
        longitude >= -180 &&
        longitude <= 180;
  }

  // ==========================================================================
  // OPEN EXTERNAL URL
  // ==========================================================================

  static Future<bool> _openExternalUrl(
    Uri uri,
  ) async {
    return _launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
  }

  // ==========================================================================
  // SAFE URL LAUNCH
  // ==========================================================================

  static Future<bool> _launchUrl(
    Uri uri, {
    LaunchMode mode =
        LaunchMode.platformDefault,
  }) async {
    try {
      if (!await canLaunchUrl(uri)) {
        return false;
      }

      return await launchUrl(
        uri,
        mode: mode,
      );
    } catch (_) {
      return false;
    }
  }
}

// ============================================================================
// NAVIGATION TRAVEL MODE
// ============================================================================

enum NavigationTravelMode {
  driving,
  walking,
  bicycling,
  transit,
}

