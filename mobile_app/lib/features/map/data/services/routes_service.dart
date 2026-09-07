import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:latlong2/latlong.dart';

import '../models/route_model.dart';

/// Real routing service for LifeLynk AI.
///
/// Uses OSRM with OpenStreetMap-derived road data.
///
/// No Google Maps API is used.
class RoutesService {
  // ============================================================
  // CONFIGURATION
  // ============================================================

  static const String _baseUrl =
      'https://router.project-osrm.org';

  static const String _userAgent =
      'LifeLynkAI/1.0 (+LifeLynk AI healthcare map)';

  final http.Client _client;

  RoutesService({
    http.Client? client,
  }) : _client = client ?? http.Client();

  // ============================================================
  // DRIVING ROUTE
  // ============================================================

  Future<RouteModel?> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) {
    return getRoute(
      origin: origin,
      destination: destination,
      profile: 'driving',
    );
  }

  // ============================================================
  // GENERIC OSRM ROUTE
  // ============================================================

  Future<RouteModel?> getRoute({
    required LatLng origin,
    required LatLng destination,
    String profile = 'driving',
  }) async {
    if (!_isValidCoordinate(origin) ||
        !_isValidCoordinate(destination)) {
      throw const RoutesServiceException(
        'Invalid route coordinates.',
      );
    }

    final normalizedProfile =
        profile.trim().toLowerCase();

    const allowedProfiles = <String>{
      'driving',
      'walking',
      'cycling',
    };

    if (!allowedProfiles.contains(
      normalizedProfile,
    )) {
      throw const RoutesServiceException(
        'Unsupported travel mode.',
      );
    }

    if (_sameCoordinate(
      origin,
      destination,
    )) {
      return RouteModel(
        origin: origin,
        destination: destination,
        distanceText: '0 m',
        distanceMeters: 0,
        durationText: '0 min',
        durationSeconds: 0,
        polylinePoints: [
          origin,
          destination,
        ],
        summary: 'Same location',
        warning: null,
        travelMode: normalizedProfile,
      );
    }

    final coordinates =
        '${origin.longitude},${origin.latitude};'
        '${destination.longitude},${destination.latitude}';

    final uri = Uri.parse(
      '$_baseUrl/route/v1/'
      '$normalizedProfile/'
      '$coordinates',
    ).replace(
      queryParameters: const {
        'overview': 'full',
        'geometries': 'geojson',
        'steps': 'true',
        'alternatives': 'true',
      },
    );

    try {
      final response = await _client
          .get(
            uri,
            headers: const {
              'Accept': 'application/json',
              'User-Agent': _userAgent,
            },
          )
          .timeout(
            const Duration(seconds: 30),
          );

      if (response.statusCode != 200) {
        throw RoutesServiceException(
          'OSRM route request failed '
          '(${response.statusCode}).',
        );
      }

      final decoded =
          jsonDecode(response.body);

      if (decoded is! Map) {
        throw const RoutesServiceException(
          'Invalid response from OSRM.',
        );
      }

      final code =
          decoded['code']?.toString();

      if (code != 'Ok') {
        throw RoutesServiceException(
          _osrmCodeMessage(
            code,
            decoded['message']?.toString(),
          ),
        );
      }

      final routes =
          decoded['routes'];

      if (routes is! List ||
          routes.isEmpty ||
          routes.first is! Map) {
        return null;
      }

      final route =
          Map<String, dynamic>.from(
        routes.first as Map,
      );

      final distance =
          _toDouble(route['distance']);

      final duration =
          _toDouble(route['duration']);

      if (distance == null ||
          duration == null) {
        throw const RoutesServiceException(
          'OSRM returned an incomplete route.',
        );
      }

      final points =
          _parseGeoJsonGeometry(
        route['geometry'],
      );

      if (points.isEmpty) {
        throw const RoutesServiceException(
          'OSRM returned a route without geometry.',
        );
      }

      final distanceMeters =
          distance.round();

      final durationSeconds =
          duration.round();

      String? summary;

      final legs = route['legs'];

      if (legs is List &&
          legs.isNotEmpty &&
          legs.first is Map) {
        final firstLeg =
            Map<String, dynamic>.from(
          legs.first as Map,
        );

        final summaryValue =
            firstLeg['summary']
                ?.toString()
                .trim();

        if (summaryValue != null &&
            summaryValue.isNotEmpty) {
          summary = summaryValue;
        }
      }

      return RouteModel(
        origin: origin,
        destination: destination,
        distanceText:
            _formatDistance(
          distanceMeters,
        ),
        distanceMeters:
            distanceMeters,
        durationText:
            _formatDuration(
          durationSeconds,
        ),
        durationSeconds:
            durationSeconds,
        encodedPolyline: null,
        polylinePoints: points,
        summary: summary,
        warning: null,
        travelMode: normalizedProfile,
      );
    } on RoutesServiceException {
      rethrow;
    } on TimeoutException {
      throw const RoutesServiceException(
        'Route calculation timed out. '
        'Please try again.',
      );
    } on FormatException {
      throw const RoutesServiceException(
        'OSRM returned invalid route data.',
      );
    } catch (e) {
      throw RoutesServiceException(
        'Unable to calculate route: $e',
      );
    }
  }

  // ============================================================
  // GEOJSON
  // ============================================================

  List<LatLng> _parseGeoJsonGeometry(
    dynamic geometry,
  ) {
    if (geometry is! Map) {
      return [];
    }

    final type =
        geometry['type']?.toString();

    if (type != 'LineString') {
      return [];
    }

    final coordinates =
        geometry['coordinates'];

    if (coordinates is! List) {
      return [];
    }

    final points = <LatLng>[];

    for (final coordinate in coordinates) {
      if (coordinate is! List ||
          coordinate.length < 2) {
        continue;
      }

      final longitude =
          _toDouble(coordinate[0]);

      final latitude =
          _toDouble(coordinate[1]);

      if (latitude == null ||
          longitude == null) {
        continue;
      }

      final point = LatLng(
        latitude,
        longitude,
      );

      if (_isValidCoordinate(point)) {
        points.add(point);
      }
    }

    return points;
  }

  // ============================================================
  // FORMATTING
  // ============================================================

  String _formatDistance(
    int meters,
  ) {
    if (meters < 1000) {
      return '$meters m';
    }

    final kilometers =
        meters / 1000.0;

    if (kilometers >= 100) {
      return '${kilometers.toStringAsFixed(0)} km';
    }

    return '${kilometers.toStringAsFixed(1)} km';
  }

  String _formatDuration(
    int seconds,
  ) {
    if (seconds <= 0) {
      return '0 min';
    }

    final minutes =
        (seconds / 60).ceil();

    if (minutes < 60) {
      return '$minutes min';
    }

    final hours =
        minutes ~/ 60;

    final remainingMinutes =
        minutes % 60;

    if (remainingMinutes == 0) {
      return '$hours hr';
    }

    return '$hours hr '
        '$remainingMinutes min';
  }

  // ============================================================
  // OSRM STATUS
  // ============================================================

  String _osrmCodeMessage(
    String? code,
    String? message,
  ) {
    switch (code) {
      case 'NoRoute':
        return 'No route was found between these locations.';

      case 'NoSegment':
        return 'The selected location could not be matched to a road.';

      case 'InvalidQuery':
      case 'InvalidValue':
      case 'InvalidUrl':
        return 'The route request was invalid.';

      case 'TooBig':
        return 'The route request was too large.';

      default:
        final text =
            message?.trim();

        if (text != null &&
            text.isNotEmpty) {
          return text;
        }

        return 'OSRM could not calculate the route.';
    }
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  bool _isValidCoordinate(
    LatLng coordinate,
  ) {
    return coordinate.latitude.isFinite &&
        coordinate.longitude.isFinite &&
        coordinate.latitude >= -90 &&
        coordinate.latitude <= 90 &&
        coordinate.longitude >= -180 &&
        coordinate.longitude <= 180;
  }

  bool _sameCoordinate(
    LatLng first,
    LatLng second,
  ) {
    return (first.latitude -
                second.latitude)
            .abs() <
        0.000001 &&
        (first.longitude -
                    second.longitude)
                .abs() <
            0.000001;
  }

  double? _toDouble(
    dynamic value,
  ) {
    if (value == null) {
      return null;
    }

    if (value is num) {
      final result =
          value.toDouble();

      return result.isFinite
          ? result
          : null;
    }

    final result =
        double.tryParse(
      value.toString(),
    );

    if (result == null ||
        !result.isFinite) {
      return null;
    }

    return result;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _client.close();
  }
}

// ================================================================
// EXCEPTION
// ================================================================

class RoutesServiceException
    implements Exception {
  final String message;

  const RoutesServiceException(
    this.message,
  );

  @override
  String toString() {
    return 'RoutesServiceException: $message';
  }
}