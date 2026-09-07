import 'package:flutter/foundation.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/map_place_model.dart';
import '../../data/models/route_model.dart';
import '../../data/repositories/map_repository.dart';

/// Central state manager for the LifeLynk full-screen Map.
///
/// Uses real:
/// - GPS
/// - OSM place data
/// - OSRM routing
///
/// The provider owns state.
/// MapScreen owns camera and rendering.
class MapProvider extends ChangeNotifier {
  final MapRepository _repository;

  MapProvider({
    required MapRepository repository,
  }) : _repository = repository;

  // ============================================================
  // LOCATION / POINT A
  // ============================================================

  LatLng? _currentLocation;

  LatLng? get currentLocation =>
      _currentLocation;

  /// Routing origin.
  ///
  /// Defaults to the user's GPS location.
  LatLng? _routeOrigin;

  LatLng? get routeOrigin =>
      _routeOrigin;

  bool get hasRouteOrigin =>
      _routeOrigin != null;

  // ============================================================
  // POINT B
  // ============================================================

  LatLng? _routeDestination;

  LatLng? get routeDestination =>
      _routeDestination;

  bool get hasRouteDestination =>
      _routeDestination != null;

  // ============================================================
  // LOCATION LOADING
  // ============================================================

  bool _locationLoading = false;

  bool get locationLoading =>
      _locationLoading;

  // ============================================================
  // PLACES
  // ============================================================

  List<MapPlaceModel> _places = [];

  List<MapPlaceModel> get places =>
      List.unmodifiable(_places);

  bool get hasPlaces =>
      _places.isNotEmpty;

  MapPlaceModel? _selectedPlace;

  MapPlaceModel? get selectedPlace =>
      _selectedPlace;

  bool get hasSelectedPlace =>
      _selectedPlace != null;

  // ============================================================
  // SEARCH
  // ============================================================

  String _searchQuery = '';

  String get searchQuery =>
      _searchQuery;

  bool _searchLoading = false;

  bool get searchLoading =>
      _searchLoading;

  // ============================================================
  // CATEGORY
  // ============================================================

  String _selectedCategory =
      'hospital';

  String get selectedCategory =>
      _selectedCategory;

  // ============================================================
  // ROUTE
  // ============================================================

  RouteModel? _route;

  RouteModel? get route =>
      _route;

  bool get hasRoute =>
      _route != null;

  bool _routeLoading = false;

  bool get routeLoading =>
      _routeLoading;

  // ============================================================
  // ROUTE MODE
  // ============================================================

  final String _travelMode =
      'driving';

  String get travelMode =>
      _travelMode;

  // ============================================================
  // BUSY
  // ============================================================

  bool get isBusy {
    return _locationLoading ||
        _searchLoading ||
        _routeLoading;
  }

  // ============================================================
  // ERROR
  // ============================================================

  String? _error;

  String? get error =>
      _error;

  bool get hasError {
    final value = _error;

    return value != null &&
        value.trim().isNotEmpty;
  }

  // ============================================================
  // INITIALIZATION
  // ============================================================

  Future<void> initialize() async {
    await loadCurrentLocation();

    if (_currentLocation != null) {
      _routeOrigin =
          _currentLocation;

      await searchByCategory(
        _selectedCategory,
      );
    }
  }

  // ============================================================
  // GPS
  // ============================================================

  Future<void> loadCurrentLocation() async {
    _locationLoading = true;
    _clearError();

    notifyListeners();

    try {
      final serviceEnabled =
          await Geolocator
              .isLocationServiceEnabled();

      if (!serviceEnabled) {
        throw const MapProviderException(
          'Location services are disabled. '
          'Please enable GPS and try again.',
        );
      }

      LocationPermission permission =
          await Geolocator.checkPermission();

      if (permission ==
          LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      if (permission ==
              LocationPermission.denied ||
          permission ==
              LocationPermission.deniedForever) {
        throw const MapProviderException(
          'Location permission was not granted.',
        );
      }

      final position =
          await Geolocator
              .getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy:
              LocationAccuracy.high,
        ),
      );

      final location = LatLng(
        position.latitude,
        position.longitude,
      );

      if (!_isValidCoordinate(location)) {
        throw const MapProviderException(
          'Received an invalid GPS location.',
        );
      }

      _currentLocation =
    location;

// Keep GPS as the default Point A
// unless the user explicitly selected
// another routing origin.

_routeOrigin ??= location;

    } on MapProviderException catch (e) {
      _error = e.message;
    } catch (e) {
      _error =
          'Unable to get your current location: $e';
    } finally {
      _locationLoading = false;

      notifyListeners();
    }
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> refreshLocation() async {
    await loadCurrentLocation();

    if (_currentLocation != null) {
      await searchByCategory(
        _selectedCategory,
      );
    }
  }

  // ============================================================
  // CATEGORY SEARCH
  // ============================================================

  Future<void> searchByCategory(
    String category,
  ) async {
    final location =
        _currentLocation;

    if (location == null) {
      _error =
          'Current location is unavailable.';
      notifyListeners();
      return;
    }

    final normalizedCategory =
        category.trim().toLowerCase();

    if (normalizedCategory.isEmpty) {
      return;
    }

    _selectedCategory =
        normalizedCategory;

    _searchQuery = '';

    _searchLoading = true;

    _selectedPlace = null;

    _clearError();

    notifyListeners();

    try {
      switch (normalizedCategory) {
        case 'hospital':
          _places =
              await _repository
                  .searchHospitals(
            latitude:
                location.latitude,
            longitude:
                location.longitude,
          );
          break;

        case 'blood_bank':
        case 'blood bank':
          _places =
              await _repository
                  .searchBloodBanks(
            latitude:
                location.latitude,
            longitude:
                location.longitude,
          );
          break;

        case 'pharmacy':
          _places =
              await _repository
                  .searchPharmacies(
            latitude:
                location.latitude,
            longitude:
                location.longitude,
          );
          break;

        case 'emergency':
        case 'emergency hospital':
          _places =
              await _repository
                  .searchEmergencyFacilities(
            latitude:
                location.latitude,
            longitude:
                location.longitude,
          );
          break;

        default:
          _places =
              await _repository.searchNearby(
            latitude:
                location.latitude,
            longitude:
                location.longitude,
            query:
                normalizedCategory,
          );
      }
    } on Exception catch (e) {
      _error =
          _exceptionMessage(e);

      _places = [];
    } finally {
      _searchLoading = false;

      notifyListeners();
    }
  }

  // ============================================================
  // TEXT SEARCH
  // ============================================================

  Future<void> searchPlaces(
    String query,
  ) async {
    final trimmedQuery =
        query.trim();

    _searchQuery =
        trimmedQuery;

    if (trimmedQuery.isEmpty) {
      await searchByCategory(
        _selectedCategory,
      );
      return;
    }

    final location =
        _currentLocation;

    if (location == null) {
      _error =
          'Current location is unavailable.';
      notifyListeners();
      return;
    }

    _searchLoading = true;

    _selectedPlace = null;

    _clearError();

    notifyListeners();

    try {
      _places =
          await _repository.searchNearby(
        latitude:
            location.latitude,
        longitude:
            location.longitude,
        query:
            trimmedQuery,
      );
    } on Exception catch (e) {
      _error =
          _exceptionMessage(e);

      _places = [];
    } finally {
      _searchLoading = false;

      notifyListeners();
    }
  }

  // ============================================================
  // SELECT PLACE
  // ============================================================

  Future<void> selectPlace(
    MapPlaceModel? place,
  ) async {
    _selectedPlace = place;

    if (place != null &&
        place.hasValidLocation) {
      _routeDestination =
          place.location;
    }

    notifyListeners();
  }

  // ============================================================
  // PLACE DETAILS
  // ============================================================

  Future<MapPlaceModel?> loadPlaceDetails(
    String placeId,
  ) async {
    final trimmedPlaceId =
        placeId.trim();

    if (trimmedPlaceId.isEmpty) {
      return null;
    }

    _clearError();

    try {
      final place =
          await _repository
              .getPlaceDetails(
        placeId:
            trimmedPlaceId,
      );

      if (place != null) {
        _selectedPlace =
            place;

        if (place.hasValidLocation) {
          _routeDestination =
              place.location;
        }

        final index =
            _places.indexWhere(
          (item) =>
              item.placeId ==
              place.placeId,
        );

        if (index >= 0) {
          final updated =
              [..._places];

          updated[index] =
              place;

          _places =
              updated;
        } else {
          _places = [
            ..._places,
            place,
          ];
        }

        notifyListeners();
      }

      return place;
    } on Exception catch (e) {
      _error =
          _exceptionMessage(e);

      notifyListeners();

      return null;
    }
  }

  // ============================================================
  // SET ROUTE ORIGIN
  // ============================================================

  void setRouteOrigin(
    LatLng location,
  ) {
    if (!_isValidCoordinate(location)) {
      return;
    }

    _routeOrigin =
        location;

    _route = null;

    _clearError();

    notifyListeners();
  }

  // ============================================================
  // SET ROUTE DESTINATION
  // ============================================================

  void setRouteDestination(
    LatLng location,
  ) {
    if (!_isValidCoordinate(location)) {
      return;
    }

    _routeDestination =
        location;

    _route = null;

    _clearError();

    notifyListeners();
  }

  // ============================================================
  // CALCULATE PLACE ROUTE
  // ============================================================

  Future<RouteModel?> calculateRoute(
    MapPlaceModel destination,
  ) async {
    if (!destination.hasValidLocation) {
      _error =
          'Destination location is invalid.';
      notifyListeners();
      return null;
    }

    _routeDestination =
        destination.location;

    return calculateRouteBetween(
      destination.location,
      selectedPlace: destination,
    );
  }

  // ============================================================
  // CALCULATE TWO-POINT ROUTE
  // ============================================================

  Future<RouteModel?> calculateRouteBetween(
  LatLng destination, {
  MapPlaceModel? selectedPlace,
}) async {
  var origin = _routeOrigin;

  origin ??= _currentLocation;

  if (origin == null) {
    _error =
        'Route origin is unavailable.';
    notifyListeners();
    return null;
  }

    if (!_isValidCoordinate(origin)) {
      _error =
          'Route origin is invalid.';
      notifyListeners();
      return null;
    }

    if (!_isValidCoordinate(destination)) {
      _error =
          'Route destination is invalid.';
      notifyListeners();
      return null;
    }

    _routeOrigin =
        origin;

    _routeDestination =
        destination;

    _selectedPlace =
        selectedPlace;

    _routeLoading = true;

    _clearError();

    notifyListeners();

    try {
      final result =
          await _repository.getDrivingRoute(
        origin: origin,
        destination: destination,
      );

      _route = result;

      return result;
    } on Exception catch (e) {
      _error =
          _exceptionMessage(e);

      _route = null;

      return null;
    } finally {
      _routeLoading = false;

      notifyListeners();
    }
  }

  // ============================================================
  // SWAP A / B
  // ============================================================

  Future<RouteModel?> swapRoute() async {
    final origin =
        _routeOrigin;

    final destination =
        _routeDestination;

    if (origin == null ||
        destination == null) {
      _error =
          'Both route points are required.';
      notifyListeners();
      return null;
    }

    _routeOrigin =
        destination;

    _routeDestination =
        origin;

    _route = null;

    notifyListeners();

    return calculateRouteBetween(
      destination,
      selectedPlace: null,
    );
  }

  // ============================================================
  // USE CURRENT LOCATION AS A
  // ============================================================

  Future<void> useCurrentLocationAsOrigin() async {
    if (_currentLocation == null) {
      await loadCurrentLocation();
    }

    if (_currentLocation == null) {
      return;
    }

    _routeOrigin =
        _currentLocation;

    _route = null;

    _clearError();

    notifyListeners();
  }

  // ============================================================
  // CLEAR ROUTE
  // ============================================================

  void clearRoute() {
    _route = null;

    _routeDestination = null;

    _selectedPlace = null;

    notifyListeners();
  }

  // ============================================================
  // CLEAR ROUTE AND RESET A
  // ============================================================

  void resetRouteToCurrentLocation() {
    _route =
        null;

    _routeOrigin =
        _currentLocation;

    _routeDestination =
        null;

    _selectedPlace =
        null;

    _clearError();

    notifyListeners();
  }

  // ============================================================
  // CLEAR SELECTION
  // ============================================================

  void clearSelection() {
    _selectedPlace = null;

    notifyListeners();
  }

  // ============================================================
  // CLEAR SEARCH
  // ============================================================

  Future<void> clearSearch() async {
    _searchQuery = '';

    await searchByCategory(
      _selectedCategory,
    );
  }

  // ============================================================
  // CAMERA STATE HELPERS
  // ============================================================

  Future<void> moveToCurrentLocation() async {
    if (_currentLocation == null) {
      await loadCurrentLocation();
    }

    notifyListeners();
  }

  Future<void> moveToPlace(
    MapPlaceModel place,
  ) async {
    if (!place.hasValidLocation) {
      return;
    }

    _selectedPlace =
        place;

    notifyListeners();
  }

  Future<void> moveToLocation(
    LatLng location, {
    double zoom = 14.0,
  }) async {
    if (!_isValidCoordinate(location)) {
      return;
    }

    notifyListeners();
  }

  // ============================================================
  // ERROR
  // ============================================================

  void clearError() {
    _clearError();

    notifyListeners();
  }

  void _clearError() {
    _error = null;
  }

  String _exceptionMessage(
    Object error,
  ) {
    if (error is MapProviderException) {
      return error.message;
    }

    final message =
        error.toString();

    if (message.startsWith(
      'Exception: ',
    )) {
      return message.substring(
        'Exception: '.length,
      );
    }

    return message;
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  bool _isValidCoordinate(
    LatLng coordinate,
  ) {
    return coordinate.latitude.isFinite &&
        coordinate.longitude.isFinite &&
        coordinate.latitude >= -90.0 &&
        coordinate.latitude <= 90.0 &&
        coordinate.longitude >= -180.0 &&
        coordinate.longitude <= 180.0;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _repository.dispose();

    super.dispose();
  }
}

// ================================================================
// EXCEPTION
// ================================================================

class MapProviderException
    implements Exception {
  final String message;

  const MapProviderException(
    this.message,
  );

  @override
  String toString() {
    return 'MapProviderException: $message';
  }
}