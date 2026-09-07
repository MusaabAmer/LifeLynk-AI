import 'package:latlong2/latlong.dart';

/// Represents a calculated route between two geographic points.
///
/// Route geometry is produced by OSRM using OpenStreetMap-derived
/// road data. The model contains the route summary, distance,
/// duration, travel mode, and road-following polyline.
class RouteModel {
  final LatLng origin;
  final LatLng destination;

  final String distanceText;
  final int distanceMeters;

  final String durationText;
  final int durationSeconds;

  final String? encodedPolyline;
  final List<LatLng> polylinePoints;

  final String? summary;
  final String? warning;

  /// OSRM routing profile used for this route.
  ///
  /// Supported values:
  /// - driving
  /// - walking
  /// - cycling
  final String travelMode;

  const RouteModel({
    required this.origin,
    required this.destination,
    required this.distanceText,
    required this.distanceMeters,
    required this.durationText,
    required this.durationSeconds,
    this.encodedPolyline,
    this.polylinePoints = const [],
    this.summary,
    this.warning,
    this.travelMode = 'driving',
  });

  // ============================================================
  // DISTANCE
  // ============================================================

  String get distanceLabel {
    if (distanceText.trim().isNotEmpty) {
      return distanceText;
    }

    return _formatDistance(distanceMeters);
  }

  bool get hasDistance {
    return distanceMeters >= 0;
  }

  // ============================================================
  // DURATION
  // ============================================================

  String get durationLabel {
    if (durationText.trim().isNotEmpty) {
      return durationText;
    }

    return _formatDuration(durationSeconds);
  }

  bool get hasDuration {
    return durationSeconds >= 0;
  }

  // ============================================================
  // POLYLINE
  // ============================================================

  bool get hasPolyline {
    return polylinePoints.length >= 2;
  }

  int get polylinePointCount {
    return polylinePoints.length;
  }

  // ============================================================
  // SUMMARY / WARNING
  // ============================================================

  bool get hasSummary {
    return summary != null &&
        summary!.trim().isNotEmpty;
  }

  bool get hasWarning {
    return warning != null &&
        warning!.trim().isNotEmpty;
  }

  // ============================================================
  // ROUTE STATE
  // ============================================================

  bool get isZeroDistance {
    return distanceMeters <= 0;
  }

  bool get isDriving {
    return travelMode == 'driving';
  }

  bool get isWalking {
    return travelMode == 'walking';
  }

  bool get isCycling {
    return travelMode == 'cycling';
  }

  String get travelModeLabel {
    switch (travelMode) {
      case 'walking':
        return 'Walking';

      case 'cycling':
        return 'Cycling';

      case 'driving':
      default:
        return 'Driving';
    }
  }

  // ============================================================
  // COPY
  // ============================================================

  RouteModel copyWith({
    LatLng? origin,
    LatLng? destination,
    String? distanceText,
    int? distanceMeters,
    String? durationText,
    int? durationSeconds,
    String? encodedPolyline,
    List<LatLng>? polylinePoints,
    String? summary,
    String? warning,
    String? travelMode,
    bool clearEncodedPolyline = false,
    bool clearSummary = false,
    bool clearWarning = false,
  }) {
    return RouteModel(
      origin: origin ?? this.origin,
      destination: destination ?? this.destination,
      distanceText:
          distanceText ?? this.distanceText,
      distanceMeters:
          distanceMeters ?? this.distanceMeters,
      durationText:
          durationText ?? this.durationText,
      durationSeconds:
          durationSeconds ?? this.durationSeconds,
      encodedPolyline:
          clearEncodedPolyline
              ? null
              : encodedPolyline ??
                  this.encodedPolyline,
      polylinePoints:
          polylinePoints ??
              this.polylinePoints,
      summary:
          clearSummary
              ? null
              : summary ?? this.summary,
      warning:
          clearWarning
              ? null
              : warning ?? this.warning,
      travelMode:
          travelMode ?? this.travelMode,
    );
  }

  // ============================================================
  // FORMATTING
  // ============================================================

  static String _formatDistance(
    int meters,
  ) {
    if (meters < 0) {
      return 'Unknown distance';
    }

    if (meters < 1000) {
      return '$meters m';
    }

    final kilometers =
        meters / 1000.0;

    if (kilometers < 10) {
      return '${kilometers.toStringAsFixed(1)} km';
    }

    return '${kilometers.toStringAsFixed(0)} km';
  }

  static String _formatDuration(
    int seconds,
  ) {
    if (seconds < 0) {
      return 'Unknown time';
    }

    if (seconds < 60) {
      return '$seconds sec';
    }

    final minutes =
        (seconds / 60).round();

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
  // DEBUG
  // ============================================================

  @override
  String toString() {
    return 'RouteModel('
        'origin: $origin, '
        'destination: $destination, '
        'distance: $distanceLabel, '
        'duration: $durationLabel, '
        'travelMode: $travelMode, '
        'polylinePoints: '
        '${polylinePoints.length}'
        ')';
  }
}