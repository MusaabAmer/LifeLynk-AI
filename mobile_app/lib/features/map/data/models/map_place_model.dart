import 'package:latlong2/latlong.dart';

/// Represents a healthcare/place result displayed on the LifeLynk map.
///
/// Place data comes from OpenStreetMap-derived services rather than
/// OpenStreetMap places.
///
/// The model is intentionally provider-neutral:
/// - [placeId] contains an OSM identifier such as N123456.
/// - [rating] and [userRatingsTotal] remain nullable because OSM
///   does not provide Google-style ratings/review counts.
/// - [isOpen] remains nullable unless reliable opening-hours parsing
///   is available.
class MapPlaceModel {
  // ============================================================
  // BASIC INFORMATION
  // ============================================================

  final String id;

  final String name;

  /// OpenStreetMap object identifier.
  ///
  /// Examples:
  /// N123456
  /// W987654
  /// R123456
  final String? placeId;

  // ============================================================
  // LOCATION
  // ============================================================

  final double latitude;

  final double longitude;

  // ============================================================
  // ADDRESS
  // ============================================================

  final String? address;

  // ============================================================
  // CONTACT
  // ============================================================

  final String? phone;

  // ============================================================
  // PLACE INFORMATION
  // ============================================================

  /// LifeLynk-normalized category.
  ///
  /// Examples:
  /// hospital
  /// blood_bank
  /// pharmacy
  /// clinic
  /// emergency
  final String? category;

  /// OSM does not provide Google-style ratings.
  ///
  /// Kept nullable for compatibility with the existing UI.
  final double? rating;

  /// OSM does not provide Google-style review counts.
  ///
  /// Kept nullable for compatibility with the existing UI.
  final int? userRatingsTotal;

  /// Whether the place is currently open.
  ///
  /// This remains null when the available OSM data does not provide
  /// a reliably parsed current opening state.
  final bool? isOpen;

  // ============================================================
  // CONSTRUCTOR
  // ============================================================

  const MapPlaceModel({
    required this.id,
    required this.name,
    required this.latitude,
    required this.longitude,
    this.placeId,
    this.address,
    this.phone,
    this.category,
    this.rating,
    this.userRatingsTotal,
    this.isOpen,
  });

  // ============================================================
  // LATLONG2 LOCATION
  // ============================================================

  LatLng get location {
    return LatLng(
      latitude,
      longitude,
    );
  }

  // ============================================================
  // LOCATION VALIDATION
  // ============================================================

  bool get hasValidLocation {
    return latitude.isFinite &&
        longitude.isFinite &&
        latitude >= -90.0 &&
        latitude <= 90.0 &&
        longitude >= -180.0 &&
        longitude <= 180.0;
  }

  // ============================================================
  // CATEGORY HELPERS
  // ============================================================

  String get categoryLabel {
    final value = category?.trim();

    if (value == null || value.isEmpty) {
      return 'Place';
    }

    switch (value.toLowerCase()) {
      case 'hospital':
        return 'Hospital';

      case 'blood_bank':
      case 'blood bank':
        return 'Blood Bank';

      case 'pharmacy':
        return 'Pharmacy';

      case 'clinic':
        return 'Clinic';

      case 'doctor':
        return 'Doctor';

      case 'healthcare':
        return 'Healthcare';

      case 'emergency':
        return 'Emergency';

      case 'donor':
        return 'Donor';

      default:
        return value;
    }
  }

  // ============================================================
  // RATING
  // ============================================================

  bool get hasRating {
    return rating != null &&
        rating!.isFinite &&
        rating! >= 0;
  }

  String get ratingLabel {
    if (!hasRating) {
      return 'No rating';
    }

    return rating!.toStringAsFixed(1);
  }

  String get reviewsLabel {
    final count = userRatingsTotal;

    if (count == null || count <= 0) {
      return 'No reviews';
    }

    if (count == 1) {
      return '1 review';
    }

    return '$count reviews';
  }

  // ============================================================
  // OPEN STATUS
  // ============================================================

  bool get hasOpenStatus {
    return isOpen != null;
  }

  String get openStatusLabel {
    if (isOpen == null) {
      return 'Status unavailable';
    }

    return isOpen! ? 'Open now' : 'Closed';
  }

  // ============================================================
  // ADDRESS
  // ============================================================

  bool get hasAddress {
    final value = address?.trim();

    return value != null &&
        value.isNotEmpty;
  }

  // ============================================================
  // PHONE
  // ============================================================

  bool get hasPhone {
    final value = phone?.trim();

    return value != null &&
        value.isNotEmpty;
  }

  // ============================================================
  // PLACE ID
  // ============================================================

  bool get hasPlaceId {
    final value = placeId?.trim();

    return value != null &&
        value.isNotEmpty;
  }

  // ============================================================
  // COPY WITH
  // ============================================================

  MapPlaceModel copyWith({
    String? id,
    String? name,
    String? placeId,
    double? latitude,
    double? longitude,
    String? address,
    String? phone,
    String? category,
    double? rating,
    int? userRatingsTotal,
    bool? isOpen,
  }) {
    return MapPlaceModel(
      id: id ?? this.id,
      name: name ?? this.name,
      placeId: placeId ?? this.placeId,
      latitude: latitude ?? this.latitude,
      longitude: longitude ?? this.longitude,
      address: address ?? this.address,
      phone: phone ?? this.phone,
      category: category ?? this.category,
      rating: rating ?? this.rating,
      userRatingsTotal:
          userRatingsTotal ??
              this.userRatingsTotal,
      isOpen:
          isOpen ??
              this.isOpen,
    );
  }

  // ============================================================
  // DEBUG
  // ============================================================

  @override
  String toString() {
    return 'MapPlaceModel('
        'id: $id, '
        'name: $name, '
        'placeId: $placeId, '
        'latitude: $latitude, '
        'longitude: $longitude, '
        'category: $category, '
        'address: $address, '
        'phone: $phone, '
        'isOpen: $isOpen'
        ')';
  }
}
