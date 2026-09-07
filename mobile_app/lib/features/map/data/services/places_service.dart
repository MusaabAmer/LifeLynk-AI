import 'dart:async';
import 'dart:convert';
import 'dart:math' as math;

import 'package:http/http.dart' as http;

import '../models/map_place_model.dart';

/// Real OpenStreetMap place-search service.
///
/// Data sources:
/// - Overpass API for nearby healthcare POIs.
/// - Nominatim for explicit text search and OSM object lookup.
///
/// No mock data or placeholder data is used.
class PlacesService {
  // ============================================================
  // ENDPOINTS
  // ============================================================

  static const List<String> _overpassEndpoints = [
    'https://overpass-api.de/api/interpreter',
    'https://overpass.kumi.systems/api/interpreter',
    'https://overpass.private.coffee/api/interpreter',
  ];

  static const String _nominatimEndpoint =
      'https://nominatim.openstreetmap.org';

  // ============================================================
  // HTTP
  // ============================================================

  final http.Client _client;

  PlacesService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  // ============================================================
  // REQUEST IDENTIFICATION
  // ============================================================

  static const String _userAgent =
      'LifeLynkAI/1.0 (healthcare map; Pakistan)';

  // ============================================================
  // SEARCH RADIUS
  // ============================================================

  static const int _defaultRadiusMeters = 10000;

  static const int _maxRadiusMeters = 50000;

  // ============================================================
  // NEARBY TEXT SEARCH
  // ============================================================

  Future<List<MapPlaceModel>> searchNearby({
    required double latitude,
    required double longitude,
    required String query,
    int radiusMeters = _defaultRadiusMeters,
  }) async {
    _validateCoordinates(
      latitude,
      longitude,
    );

    final trimmedQuery = query.trim();

    if (trimmedQuery.isEmpty) {
      return [];
    }

    final safeRadius = _normalizeRadius(
      radiusMeters,
    );

    try {
      final results = await _nominatimSearch(
        latitude: latitude,
        longitude: longitude,
        query: trimmedQuery,
        radiusMeters: safeRadius,
      );

      return _sortByDistance(
        results,
        latitude,
        longitude,
      );
    } on PlacesServiceException {
      rethrow;
    } catch (e) {
      throw PlacesServiceException(
        'Unable to search nearby places: $e',
      );
    }
  }

  // ============================================================
  // HOSPITALS
  // ============================================================

  Future<List<MapPlaceModel>> searchHospitals({
    required double latitude,
    required double longitude,
    int radiusMeters = _defaultRadiusMeters,
  }) {
    return _searchOverpassCategory(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      category: 'hospital',
      filters: const [
        'nwr["amenity"="hospital"]',
        'nwr["healthcare"="hospital"]',
      ],
    );
  }

  // ============================================================
  // BLOOD BANKS
  // ============================================================

  Future<List<MapPlaceModel>> searchBloodBanks({
    required double latitude,
    required double longitude,
    int radiusMeters = _defaultRadiusMeters,
  }) {
    return _searchOverpassCategory(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      category: 'blood_bank',
      filters: const [
        'nwr["healthcare"="blood_bank"]',
        'nwr["amenity"="blood_bank"]',
        'nwr["healthcare"="blood_donation"]',
      ],
    );
  }

  // ============================================================
  // PHARMACIES
  // ============================================================

  Future<List<MapPlaceModel>> searchPharmacies({
    required double latitude,
    required double longitude,
    int radiusMeters = _defaultRadiusMeters,
  }) {
    return _searchOverpassCategory(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      category: 'pharmacy',
      filters: const [
        'nwr["amenity"="pharmacy"]',
        'nwr["healthcare"="pharmacy"]',
      ],
    );
  }

  // ============================================================
  // EMERGENCY FACILITIES
  // ============================================================

  Future<List<MapPlaceModel>> searchEmergencyFacilities({
    required double latitude,
    required double longitude,
    int radiusMeters = _defaultRadiusMeters,
  }) {
    return _searchOverpassCategory(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
      category: 'emergency',
      filters: const [
        'nwr["amenity"="hospital"]["emergency"="yes"]',
        'nwr["healthcare"="hospital"]["emergency"="yes"]',
        'nwr["emergency"="yes"]["amenity"="hospital"]',
        'nwr["emergency"="emergency_ward_entrance"]',
      ],
    );
  }

  // ============================================================
  // OVERPASS CATEGORY SEARCH
  // ============================================================

  Future<List<MapPlaceModel>> _searchOverpassCategory({
    required double latitude,
    required double longitude,
    required int radiusMeters,
    required String category,
    required List<String> filters,
  }) async {
    _validateCoordinates(
      latitude,
      longitude,
    );

    final safeRadius = _normalizeRadius(
      radiusMeters,
    );

    /*
     * IMPORTANT:
     *
     * The radius selector must be attached to every
     * nwr statement.
     *
     * Invalid:
     *
     *   (
     *     nwr["amenity"="hospital"];
     *   );
     *   (around:10000,lat,lon);
     *
     * Correct:
     *
     *   (
     *     nwr["amenity"="hospital"](around:10000,lat,lon);
     *   );
     */
    final query = '''
[out:json][timeout:25];
(
${filters.map(
  (filter) =>
      '  $filter(around:$safeRadius,$latitude,$longitude);',
).join('\n')}
);
out center tags;
''';

    PlacesServiceException? lastError;

    for (final endpoint in _overpassEndpoints) {
      try {
        final response = await _client
            .post(
              Uri.parse(endpoint),
              headers: const {
                'Accept': 'application/json',
                'Content-Type':
                    'application/x-www-form-urlencoded',
                'User-Agent': _userAgent,
              },
              body: {
                'data': query,
              },
            )
            .timeout(
              const Duration(seconds: 35),
            );

        if (response.statusCode != 200) {
          final body = response.body.trim();

          lastError = PlacesServiceException(
            'OpenStreetMap place search failed '
            '(${response.statusCode})'
            '${body.isEmpty ? '' : ': $body'}',
          );

          /*
           * Try another Overpass instance instead of immediately
           * failing the entire healthcare search.
           */
          continue;
        }

        final decoded = jsonDecode(
          response.body,
        );

        if (decoded is! Map) {
          throw const PlacesServiceException(
            'Invalid response from OpenStreetMap place search.',
          );
        }

        final elements = decoded['elements'];

        if (elements is! List) {
          return [];
        }

        final places = <MapPlaceModel>[];

        for (final item in elements) {
          if (item is! Map) {
            continue;
          }

          final place = _parseOverpassPlace(
            Map<String, dynamic>.from(item),
            category,
          );

          if (place != null) {
            places.add(place);
          }
        }

        return _sortByDistance(
          places,
          latitude,
          longitude,
        );
      } on PlacesServiceException catch (e) {
        lastError = e;
      } on TimeoutException {
        lastError = const PlacesServiceException(
          'OpenStreetMap place search timed out.',
        );
      } on FormatException catch (e) {
        lastError = PlacesServiceException(
          'OpenStreetMap returned invalid JSON: $e',
        );
      } on http.ClientException catch (e) {
        lastError = PlacesServiceException(
          'Could not connect to OpenStreetMap: $e',
        );
      } catch (e) {
        lastError = PlacesServiceException(
          'Unable to search OpenStreetMap places: $e',
        );
      }
    }

    throw lastError ??
        const PlacesServiceException(
          'Unable to search OpenStreetMap places.',
        );
  }

  // ============================================================
  // NOMINATIM TEXT SEARCH
  // ============================================================

  Future<List<MapPlaceModel>> _nominatimSearch({
    required double latitude,
    required double longitude,
    required String query,
    required int radiusMeters,
  }) async {
    final boundingBox = _buildViewBox(
      latitude,
      longitude,
      radiusMeters,
    );

    final uri = Uri.parse(
      _nominatimEndpoint,
    ).replace(
      path: '/search',
      queryParameters: {
        'q': query,
        'format': 'jsonv2',
        'addressdetails': '1',
        'limit': '20',
        'bounded': '1',
        'viewbox': boundingBox,
        'countrycodes': 'pk',
      },
    );

    try {
      final response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': _userAgent,
              'Accept-Language': 'en',
            },
          )
          .timeout(
            const Duration(seconds: 20),
          );

      if (response.statusCode != 200) {
        final body = response.body.trim();

        throw PlacesServiceException(
          'OpenStreetMap text search failed '
          '(${response.statusCode})'
          '${body.isEmpty ? '' : ': $body'}',
        );
      }

      final decoded = jsonDecode(
        response.body,
      );

      if (decoded is! List) {
        throw const PlacesServiceException(
          'Invalid response from OpenStreetMap text search.',
        );
      }

      final places = <MapPlaceModel>[];

      for (final item in decoded) {
        if (item is! Map) {
          continue;
        }

        final place = _parseNominatimPlace(
          Map<String, dynamic>.from(item),
        );

        if (place != null) {
          places.add(place);
        }
      }

      return _sortByDistance(
        places,
        latitude,
        longitude,
      );
    } on PlacesServiceException {
      rethrow;
    } on TimeoutException {
      throw const PlacesServiceException(
        'OpenStreetMap text search timed out. '
        'Please check your internet connection and try again.',
      );
    } on FormatException catch (e) {
      throw PlacesServiceException(
        'OpenStreetMap returned invalid JSON: $e',
      );
    } on http.ClientException catch (e) {
      throw PlacesServiceException(
        'Could not connect to OpenStreetMap: $e',
      );
    } catch (e) {
      throw PlacesServiceException(
        'Unable to search OpenStreetMap: $e',
      );
    }
  }

  // ============================================================
  // PLACE DETAILS
  // ============================================================

  Future<MapPlaceModel?> getPlaceDetails({
    required String placeId,
  }) async {
    final identifier = placeId.trim();

    if (identifier.isEmpty) {
      return null;
    }

    final parsed = _parseOsmIdentifier(
      identifier,
    );

    if (parsed == null) {
      throw const PlacesServiceException(
        'Invalid OpenStreetMap place identifier.',
      );
    }

    final uri = Uri.parse(
      _nominatimEndpoint,
    ).replace(
      path: '/lookup',
      queryParameters: {
        'osm_ids': '${parsed.type}${parsed.id}',
        'format': 'jsonv2',
        'addressdetails': '1',
      },
    );

    try {
      final response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': _userAgent,
              'Accept-Language': 'en',
            },
          )
          .timeout(
            const Duration(seconds: 20),
          );

      if (response.statusCode != 200) {
        final body = response.body.trim();

        throw PlacesServiceException(
          'OpenStreetMap place details failed '
          '(${response.statusCode})'
          '${body.isEmpty ? '' : ': $body'}',
        );
      }

      final decoded = jsonDecode(
        response.body,
      );

      if (decoded is! List ||
          decoded.isEmpty ||
          decoded.first is! Map) {
        return null;
      }

      return _parseNominatimPlace(
        Map<String, dynamic>.from(
          decoded.first as Map,
        ),
      );
    } on PlacesServiceException {
      rethrow;
    } on TimeoutException {
      throw const PlacesServiceException(
        'OpenStreetMap place details timed out. '
        'Please check your internet connection and try again.',
      );
    } on FormatException catch (e) {
      throw PlacesServiceException(
        'OpenStreetMap returned invalid JSON: $e',
      );
    } on http.ClientException catch (e) {
      throw PlacesServiceException(
        'Could not connect to OpenStreetMap: $e',
      );
    } catch (e) {
      throw PlacesServiceException(
        'Unable to load place details: $e',
      );
    }
  }

  // ============================================================
  // OVERPASS PARSER
  // ============================================================

  MapPlaceModel? _parseOverpassPlace(
    Map<String, dynamic> json,
    String fallbackCategory,
  ) {
    final tagsRaw = json['tags'];

    final tags = tagsRaw is Map
        ? Map<String, dynamic>.from(tagsRaw)
        : <String, dynamic>{};

    final coordinates = _extractOverpassCoordinates(
      json,
    );

    if (coordinates == null) {
      return null;
    }

    final name = _cleanString(
      tags['name'],
    );

    if (name == null) {
      return null;
    }

    final type = json['type']?.toString();

    final osmId = json['id']?.toString();

    if (type == null ||
        type.isEmpty ||
        osmId == null ||
        osmId.isEmpty) {
      return null;
    }

    final placeId =
        '${type.substring(0, 1).toUpperCase()}$osmId';

    final category = _resolveCategoryFromTags(
      tags,
      fallbackCategory,
    );

    final address = _buildAddressFromTags(
      tags,
    );

    final phone = _firstNonEmptyString([
      tags['phone'],
      tags['contact:phone'],
    ]);

    return MapPlaceModel(
      id: placeId,
      name: name,
      placeId: placeId,
      latitude: coordinates.$1,
      longitude: coordinates.$2,
      address: address,
      phone: phone,
      category: category,
      rating: null,
      userRatingsTotal: null,
      isOpen: null,
    );
  }

  // ============================================================
  // NOMINATIM PARSER
  // ============================================================

  MapPlaceModel? _parseNominatimPlace(
    Map<String, dynamic> json,
  ) {
    final latitude = double.tryParse(
      json['lat']?.toString() ?? '',
    );

    final longitude = double.tryParse(
      json['lon']?.toString() ?? '',
    );

    if (latitude == null ||
        longitude == null ||
        !_isValidCoordinate(
          latitude,
          longitude,
        )) {
      return null;
    }

    final name =
        _cleanString(json['name']) ??
        _cleanString(json['display_name']);

    if (name == null) {
      return null;
    }

    final osmType = json['osm_type']?.toString();

    final osmId = json['osm_id']?.toString();

    String? placeId;

    if (osmType != null &&
        osmType.isNotEmpty &&
        osmId != null &&
        osmId.isNotEmpty) {
      placeId =
          '${osmType.substring(0, 1).toUpperCase()}$osmId';
    }

    final address = _buildNominatimAddress(
      json,
    );

    final category = _resolveNominatimCategory(
      json,
    );

    return MapPlaceModel(
      id: placeId ?? '${latitude}_$longitude',
      name: name,
      placeId: placeId,
      latitude: latitude,
      longitude: longitude,
      address: address,
      phone: null,
      category: category,
      rating: null,
      userRatingsTotal: null,
      isOpen: null,
    );
  }

  // ============================================================
  // COORDINATES
  // ============================================================

  (double, double)? _extractOverpassCoordinates(
    Map<String, dynamic> json,
  ) {
    final lat = _toDouble(
      json['lat'],
    );

    final lon = _toDouble(
      json['lon'],
    );

    if (lat != null &&
        lon != null &&
        _isValidCoordinate(
          lat,
          lon,
        )) {
      return (
        lat,
        lon,
      );
    }

    final center = json['center'];

    if (center is Map) {
      final centerLat = _toDouble(
        center['lat'],
      );

      final centerLon = _toDouble(
        center['lon'],
      );

      if (centerLat != null &&
          centerLon != null &&
          _isValidCoordinate(
            centerLat,
            centerLon,
          )) {
        return (
          centerLat,
          centerLon,
        );
      }
    }

    return null;
  }

  // ============================================================
  // CATEGORY
  // ============================================================

  String? _resolveCategoryFromTags(
    Map<String, dynamic> tags,
    String fallback,
  ) {
    final amenity = tags['amenity']
        ?.toString()
        .trim()
        .toLowerCase();

    final healthcare = tags['healthcare']
        ?.toString()
        .trim()
        .toLowerCase();

    if (amenity == 'hospital' ||
        healthcare == 'hospital') {
      return 'hospital';
    }

    if (amenity == 'blood_bank' ||
        healthcare == 'blood_bank' ||
        healthcare == 'blood_donation') {
      return 'blood_bank';
    }

    if (amenity == 'pharmacy' ||
        healthcare == 'pharmacy') {
      return 'pharmacy';
    }

    if (amenity == 'clinic' ||
        healthcare == 'clinic') {
      return 'clinic';
    }

    if (amenity == 'doctors' ||
        healthcare == 'doctor') {
      return 'doctor';
    }

    if (tags['emergency'] != null &&
        tags['emergency']
                .toString()
                .trim()
                .toLowerCase() ==
            'yes') {
      return 'emergency';
    }

    return fallback;
  }

  String? _resolveNominatimCategory(
    Map<String, dynamic> json,
  ) {
    final type = json['type']
        ?.toString()
        .trim()
        .toLowerCase();

    final category = json['category']
        ?.toString()
        .trim()
        .toLowerCase();

    final value = '$category $type';

    if (value.contains('hospital')) {
      return 'hospital';
    }

    if (value.contains('blood')) {
      return 'blood_bank';
    }

    if (value.contains('pharmacy')) {
      return 'pharmacy';
    }

    if (value.contains('clinic')) {
      return 'clinic';
    }

    if (value.contains('doctor')) {
      return 'doctor';
    }

    if (value.contains('health')) {
      return 'healthcare';
    }

    return null;
  }

  // ============================================================
  // ADDRESS
  // ============================================================

  String? _buildAddressFromTags(
    Map<String, dynamic> tags,
  ) {
    final parts = <String>[];

    final houseNumber = _cleanString(
      tags['addr:housenumber'],
    );

    final street = _cleanString(
      tags['addr:street'],
    );

    final locality =
        _cleanString(tags['addr:suburb']) ??
        _cleanString(tags['addr:neighbourhood']);

    final city =
        _cleanString(tags['addr:city']) ??
        _cleanString(tags['addr:town']) ??
        _cleanString(tags['addr:village']);

    final postcode = _cleanString(
      tags['addr:postcode'],
    );

    if (houseNumber != null &&
        street != null) {
      parts.add(
        '$houseNumber $street',
      );
    } else if (street != null) {
      parts.add(street);
    }

    if (locality != null) {
      parts.add(locality);
    }

    if (city != null) {
      parts.add(city);
    }

    if (postcode != null) {
      parts.add(postcode);
    }

    if (parts.isEmpty) {
      return null;
    }

    return parts.join(', ');
  }

  String? _buildNominatimAddress(
    Map<String, dynamic> json,
  ) {
    final addressRaw = json['address'];

    if (addressRaw is! Map) {
      return _cleanString(
        json['display_name'],
      );
    }

    final address = Map<String, dynamic>.from(
      addressRaw,
    );

    final parts = <String>[];

    final houseNumber = _cleanString(
      address['house_number'],
    );

    final road = _cleanString(
      address['road'],
    );

    final neighbourhood = _cleanString(
      address['neighbourhood'],
    );

    final suburb = _cleanString(
      address['suburb'],
    );

    final city =
        _cleanString(address['city']) ??
        _cleanString(address['town']) ??
        _cleanString(address['village']);

    final postcode = _cleanString(
      address['postcode'],
    );

    if (houseNumber != null &&
        road != null) {
      parts.add(
        '$houseNumber $road',
      );
    } else if (road != null) {
      parts.add(road);
    }

    if (neighbourhood != null) {
      parts.add(neighbourhood);
    } else if (suburb != null) {
      parts.add(suburb);
    }

    if (city != null) {
      parts.add(city);
    }

    if (postcode != null) {
      parts.add(postcode);
    }

    if (parts.isEmpty) {
      return _cleanString(
        json['display_name'],
      );
    }

    return parts.join(', ');
  }

  // ============================================================
  // SORTING
  // ============================================================

  List<MapPlaceModel> _sortByDistance(
    List<MapPlaceModel> places,
    double latitude,
    double longitude,
  ) {
    final origin = _Coordinate(
      latitude,
      longitude,
    );

    final sorted = [...places];

    sorted.sort(
      (a, b) {
        final distanceA = _distanceSquared(
          origin,
          a.latitude,
          a.longitude,
        );

        final distanceB = _distanceSquared(
          origin,
          b.latitude,
          b.longitude,
        );

        return distanceA.compareTo(
          distanceB,
        );
      },
    );

    return sorted;
  }

  double _distanceSquared(
    _Coordinate origin,
    double latitude,
    double longitude,
  ) {
    final latDifference =
        latitude - origin.latitude;

    final lonDifference =
        longitude - origin.longitude;

    return (latDifference * latDifference) +
        (lonDifference * lonDifference);
  }

  // ============================================================
  // VIEWBOX
  // ============================================================

  String _buildViewBox(
    double latitude,
    double longitude,
    int radiusMeters,
  ) {
    final latitudeDegrees =
        radiusMeters / 111320.0;

    final longitudeDegrees =
        radiusMeters /
            (111320.0 *
                _cosineLatitude(latitude));

    final west =
        longitude - longitudeDegrees;

    final north =
        latitude + latitudeDegrees;

    final east =
        longitude + longitudeDegrees;

    final south =
        latitude - latitudeDegrees;

    return '$west,$north,$east,$south';
  }

  double _cosineLatitude(
    double latitude,
  ) {
    final radians =
        latitude * math.pi / 180.0;

    final cosine = math.cos(
      radians,
    );

    if (cosine.abs() < 0.01) {
      return 0.01;
    }

    return cosine.abs();
  }

  // ============================================================
  // OSM IDENTIFIER
  // ============================================================

  _OsmIdentifier? _parseOsmIdentifier(
    String value,
  ) {
    final match = RegExp(
      r'^([NnWwRr])(\d+)$',
    ).firstMatch(value);

    if (match == null) {
      return null;
    }

    return _OsmIdentifier(
      type: match.group(1)!.toUpperCase(),
      id: match.group(2)!,
    );
  }

  // ============================================================
  // VALUE HELPERS
  // ============================================================

  String? _cleanString(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    final text = value.toString().trim();

    if (text.isEmpty) {
      return null;
    }

    return text;
  }

  String? _firstNonEmptyString(
    List<dynamic> values,
  ) {
    for (final value in values) {
      final result = _cleanString(
        value,
      );

      if (result != null) {
        return result;
      }
    }

    return null;
  }

  double? _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      final result = value.toDouble();

      return result.isFinite
          ? result
          : null;
    }

    final result = double.tryParse(
      value.toString(),
    );

    if (result == null ||
        !result.isFinite) {
      return null;
    }

    return result;
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  void _validateCoordinates(
    double latitude,
    double longitude,
  ) {
    if (!_isValidCoordinate(
      latitude,
      longitude,
    )) {
      throw const PlacesServiceException(
        'Invalid map coordinates.',
      );
    }
  }

  bool _isValidCoordinate(
    double latitude,
    double longitude,
  ) {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90.0 &&
        latitude <= 90.0 &&
        longitude >= -180.0 &&
        longitude <= 180.0;
  }

  int _normalizeRadius(
    int radiusMeters,
  ) {
    if (radiusMeters <= 0) {
      throw const PlacesServiceException(
        'Search radius must be greater than zero.',
      );
    }

    if (radiusMeters > _maxRadiusMeters) {
      return _maxRadiusMeters;
    }

    return radiusMeters;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _client.close();
  }
}

// ================================================================
// INTERNAL TYPES
// ================================================================

class _Coordinate {
  final double latitude;
  final double longitude;

  const _Coordinate(
    this.latitude,
    this.longitude,
  );
}

class _OsmIdentifier {
  final String type;
  final String id;

  const _OsmIdentifier({
    required this.type,
    required this.id,
  });
}

// ================================================================
// EXCEPTION
// ================================================================

class PlacesServiceException
    implements Exception {
  final String message;

  const PlacesServiceException(
    this.message,
  );

  @override
  String toString() {
    return 'PlacesServiceException: $message';
  }
}