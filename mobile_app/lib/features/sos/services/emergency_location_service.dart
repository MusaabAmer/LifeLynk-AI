import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:geolocator/geolocator.dart';

class EmergencyLocationService {
  // ============================================================
  // OPENSTREETMAP / NOMINATIM
  // ============================================================

  /*
   * LifeLynk AI uses OpenStreetMap for map functionality.
   *
   * Nominatim is used here only for reverse geocoding:
   *
   * GPS latitude + longitude
   *          ↓
   * OpenStreetMap Nominatim
   *          ↓
   * Human-readable address
   *
   * GPS coordinates remain the source of truth.
   */

  static const String _nominatimBaseUrl =
      'https://nominatim.openstreetmap.org/reverse';

  /*
   * Nominatim requires applications to identify themselves.
   *
   * Keep this descriptive rather than pretending to be a browser.
   */
  static const String _userAgent =
      'LifeLynk-AI-Emergency-SOS/1.0';

  // ============================================================
  // LOCATION SERVICE
  // ============================================================

  /// Returns whether the device location/GPS service is enabled.
  Future<bool> isLocationServiceEnabled() async {
    return Geolocator.isLocationServiceEnabled();
  }

  // ============================================================
  // PERMISSION
  // ============================================================

  /// Returns the current location permission state.
  Future<LocationPermission> checkPermission() async {
    return Geolocator.checkPermission();
  }

  /// Requests location permission when it has not already been
  /// granted.
  ///
  /// This method does not attempt to request permission again when
  /// Android has permanently denied it.
  Future<LocationPermission> requestPermission() async {
    var permission =
        await Geolocator.checkPermission();

    if (permission ==
        LocationPermission.denied) {
      permission =
          await Geolocator.requestPermission();
    }

    return permission;
  }

  // ============================================================
  // GET CURRENT EMERGENCY LOCATION
  // ============================================================

  /// Gets the device's current high-accuracy location for SOS.
  ///
  /// This method:
  /// 1. Verifies that GPS/location services are enabled.
  /// 2. Checks and requests location permission.
  /// 3. Handles permanently denied permission.
  /// 4. Gets a high-accuracy GPS position.
  /// 5. Converts common location failures into a
  ///    [EmergencyLocationException].
  Future<Position> getCurrentLocation() async {
    // ----------------------------------------------------------
    // 1. CHECK LOCATION SERVICE
    // ----------------------------------------------------------

    final serviceEnabled =
        await Geolocator.isLocationServiceEnabled();

    if (!serviceEnabled) {
      throw const EmergencyLocationException(
        'Location services are disabled. '
        'Please enable GPS and try again.',
        type:
            EmergencyLocationErrorType
                .serviceDisabled,
      );
    }

    // ----------------------------------------------------------
    // 2. CHECK / REQUEST PERMISSION
    // ----------------------------------------------------------

    final permission =
        await requestPermission();

    // Permission denied but can still be requested again.
    if (permission ==
        LocationPermission.denied) {
      throw const EmergencyLocationException(
        'Location permission was denied. '
        'Please allow location access to activate SOS.',
        type:
            EmergencyLocationErrorType
                .permissionDenied,
      );
    }

    // Permission permanently denied.
    if (permission ==
        LocationPermission.deniedForever) {
      throw const EmergencyLocationException(
        'Location permission is permanently denied. '
        'Please enable location permission from app settings.',
        type:
            EmergencyLocationErrorType
                .permissionDeniedForever,
      );
    }

    // ----------------------------------------------------------
    // 3. GET CURRENT GPS POSITION
    // ----------------------------------------------------------

    try {
      final position =
          await Geolocator
              .getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
          distanceFilter: 0,
        ),
      ).timeout(
        const Duration(
          seconds: 15,
        ),
      );

      return position;
    }

    // ----------------------------------------------------------
    // LOCATION SERVICE DISABLED DURING REQUEST
    // ----------------------------------------------------------

    on LocationServiceDisabledException {
      throw const EmergencyLocationException(
        'Location services were disabled while '
        'getting your location.',
        type:
            EmergencyLocationErrorType
                .serviceDisabled,
      );
    }

    // ----------------------------------------------------------
    // PERMISSION FAILURE DURING REQUEST
    // ----------------------------------------------------------

    on PermissionDeniedException {
      throw const EmergencyLocationException(
        'Location permission was denied.',
        type:
            EmergencyLocationErrorType
                .permissionDenied,
      );
    }

    // ----------------------------------------------------------
    // GPS TIMEOUT
    // ----------------------------------------------------------

    on TimeoutException {
      throw const EmergencyLocationException(
        'Unable to get your current location within the '
        'allowed time. Please make sure GPS is enabled and '
        'try again in an area with a better GPS signal.',
        type:
            EmergencyLocationErrorType
                .timeout,
      );
    }

    // ----------------------------------------------------------
    // OTHER LOCATION FAILURE
    // ----------------------------------------------------------

    catch (e) {
      throw EmergencyLocationException(
        'Unable to determine your current location. '
        'Please try again.',
        type:
            EmergencyLocationErrorType
                .unknown,
        originalError: e,
      );
    }
  }

  // ============================================================
  // REVERSE GEOCODING
  // ============================================================

  /// Converts actual GPS coordinates into a human-readable
  /// address using OpenStreetMap Nominatim.
  ///
  /// Example result:
  ///
  ///     Jail Road, Lahore, Punjab, Pakistan
  ///
  /// The returned address is derived from the supplied coordinates.
  /// No address is written back to the SOS database.
  ///
  /// Returns null when the coordinates cannot be reverse-geocoded.
  Future<String?> getAddressFromCoordinates({
    required double latitude,
    required double longitude,
  }) async {
    // ----------------------------------------------------------
    // VALIDATE COORDINATES
    // ----------------------------------------------------------

    if (!_isValidLatitude(latitude) ||
        !_isValidLongitude(longitude)) {
      return null;
    }

    HttpClient? client;

    try {
      client = HttpClient()
        ..connectionTimeout =
            const Duration(
          seconds: 8,
        );

      final uri = Uri.parse(
        _nominatimBaseUrl,
      ).replace(
        queryParameters: {
          'format': 'jsonv2',
          'lat': latitude.toStringAsFixed(
            7,
          ),
          'lon': longitude.toStringAsFixed(
            7,
          ),
          'zoom': '18',
          'addressdetails': '1',
          'accept-language': 'en',
        },
      );

      final request =
          await client.getUrl(uri);

      request.headers.set(
        HttpHeaders.userAgentHeader,
        _userAgent,
      );

      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/json',
      );

      final response =
          await request.close().timeout(
        const Duration(
          seconds: 8,
        ),
      );

      if (response.statusCode !=
          HttpStatus.ok) {
        /*
         * Reverse geocoding is a presentation enhancement.
         * A failed geocoding request must never invalidate
         * the actual SOS GPS location.
         */
        await response.drain();

        return null;
      }

      final body =
          await response
              .transform(
                utf8.decoder,
              )
              .join();

      if (body.trim().isEmpty) {
        return null;
      }

      final decoded =
          jsonDecode(body);

      if (decoded is! Map) {
        return null;
      }

      return _buildReadableAddress(
        decoded,
      );
    } on TimeoutException {
      return null;
    } on SocketException {
      return null;
    } on HttpException {
      return null;
    } on FormatException {
      return null;
    } catch (_) {
      /*
       * Never let an address lookup failure break SOS.
       *
       * GPS latitude/longitude are already safely stored in
       * emergency_sos and remain the authoritative location.
       */
      return null;
    } finally {
      client?.close(
        force: true,
      );
    }
  }

  // ============================================================
  // BUILD HUMAN-READABLE ADDRESS
  // ============================================================

  String? _buildReadableAddress(
    Map<dynamic, dynamic> data,
  ) {
    // ----------------------------------------------------------
    // FIRST CHOICE: NOMINATIM DISPLAY NAME
    // ----------------------------------------------------------

    final displayName =
        data['display_name']
            ?.toString()
            .trim();

    /*
     * Nominatim's display_name is already a complete,
     * human-readable address.
     *
     * We still try to construct a cleaner LifeLynk address
     * below so the UI does not become excessively long.
     */
    final address =
        data['address'];

    if (address is Map) {
      final parts =
          _buildAddressParts(
        address,
      );

      if (parts.isNotEmpty) {
        return parts.join(
          ', ',
        );
      }
    }

    if (displayName != null &&
        displayName.isNotEmpty) {
      return displayName;
    }

    return null;
  }

  // ============================================================
  // BUILD ADDRESS PARTS
  // ============================================================

  List<String> _buildAddressParts(
    Map<dynamic, dynamic> address,
  ) {
    final parts =
        <String>[];

    /*
     * Street / road
     *
     * Example:
     * Jail Road
     * Mall Road
     * Canal Bank Road
     */
    _addUniquePart(
      parts,
      _value(
        address,
        'road',
      ),
    );

    /*
     * Neighbourhood/suburb.
     *
     * Only add one of these where appropriate.
     */
    final neighbourhood =
        _firstNonEmpty([
      _value(
        address,
        'neighbourhood',
      ),
      _value(
        address,
        'suburb',
      ),
      _value(
        address,
        'quarter',
      ),
    ]);

    _addUniquePart(
      parts,
      neighbourhood,
    );

    /*
     * City hierarchy.
     *
     * Nominatim may use:
     * city
     * town
     * municipality
     * village
     */
    final city =
        _firstNonEmpty([
      _value(
        address,
        'city',
      ),
      _value(
        address,
        'town',
      ),
      _value(
        address,
        'municipality',
      ),
      _value(
        address,
        'village',
      ),
    ]);

    _addUniquePart(
      parts,
      city,
    );

    /*
     * State/province.
     *
     * For Pakistan this commonly becomes:
     * Punjab
     * Sindh
     * Khyber Pakhtunkhwa
     * Balochistan
     */
    final state =
        _firstNonEmpty([
      _value(
        address,
        'state',
      ),
      _value(
        address,
        'province',
      ),
    ]);

    _addUniquePart(
      parts,
      state,
    );

    /*
     * Country is useful when reverse geocoding but we avoid
     * unnecessarily long addresses if the service has already
     * identified Pakistan.
     */
    final country =
        _value(
      address,
      'country',
    );

    if (country != null &&
        country.isNotEmpty &&
        !parts.any(
          (part) =>
              part.toLowerCase() ==
              country.toLowerCase(),
        )) {
      _addUniquePart(
        parts,
        country,
      );
    }

    return parts;
  }

  // ============================================================
  // ADDRESS VALUE HELPERS
  // ============================================================

  String? _value(
    Map<dynamic, dynamic> map,
    String key,
  ) {
    final value =
        map[key]
            ?.toString()
            .trim();

    if (value == null ||
        value.isEmpty) {
      return null;
    }

    return value;
  }

  String? _firstNonEmpty(
    List<String?> values,
  ) {
    for (final value in values) {
      if (value != null &&
          value.trim().isNotEmpty) {
        return value.trim();
      }
    }

    return null;
  }

  void _addUniquePart(
    List<String> parts,
    String? value,
  ) {
    if (value == null ||
        value.trim().isEmpty) {
      return;
    }

    final normalized =
        value.trim();

    final alreadyExists =
        parts.any(
      (part) =>
          part.toLowerCase() ==
          normalized.toLowerCase(),
    );

    if (!alreadyExists) {
      parts.add(
        normalized,
      );
    }
  }

  // ============================================================
  // COORDINATE VALIDATION
  // ============================================================

  bool _isValidLatitude(
    double value,
  ) {
    return value.isFinite &&
        value >= -90.0 &&
        value <= 90.0;
  }

  bool _isValidLongitude(
    double value,
  ) {
    return value.isFinite &&
        value >= -180.0 &&
        value <= 180.0;
  }

  // ============================================================
  // OPEN LOCATION SETTINGS
  // ============================================================

  /// Opens the device's location/GPS settings.
  Future<bool> openLocationSettings() async {
    return Geolocator.openLocationSettings();
  }

  // ============================================================
  // OPEN APP SETTINGS
  // ============================================================

  /// Opens this application's settings page.
  ///
  /// Useful when location permission has been permanently denied.
  Future<bool> openAppSettings() async {
    return Geolocator.openAppSettings();
  }
}

// ============================================================================
// ERROR TYPES
// ============================================================================

enum EmergencyLocationErrorType {
  /// Device GPS/location service is disabled.
  serviceDisabled,

  /// User denied location permission.
  permissionDenied,

  /// User permanently denied location permission.
  permissionDeniedForever,

  /// Getting the GPS position took too long.
  timeout,

  /// An unexpected location error occurred.
  unknown,
}

// ============================================================================
// LOCATION EXCEPTION
// ============================================================================

class EmergencyLocationException
    implements Exception {
  final String message;

  final EmergencyLocationErrorType type;

  final Object? originalError;

  const EmergencyLocationException(
    this.message, {
    required this.type,
    this.originalError,
  });

  @override
  String toString() {
    return message;
  }
}
