import 'package:latlong2/latlong.dart';

import '../models/map_place_model.dart';
import '../models/route_model.dart';
import '../services/places_service.dart';
import '../services/routes_service.dart';

/// Repository for the LifeLynk full-screen Map feature.
///
/// This repository is provider-agnostic and contains no OpenStreetMap
/// dependency.
///
/// Responsibilities:
/// - Search real nearby healthcare places.
/// - Load real OSM place details.
/// - Calculate real driving routes.
class MapRepository {
  final PlacesService _placesService;
  final RoutesService _routesService;

  MapRepository({
    required PlacesService placesService,
    required RoutesService routesService,
  })  : _placesService = placesService,
        _routesService = routesService;

  // ============================================================
  // NEARBY SEARCH
  // ============================================================

  Future<List<MapPlaceModel>> searchNearby({
    required double latitude,
    required double longitude,
    required String query,
    int radiusMeters = 10000,
  }) {
    return _placesService.searchNearby(
      latitude: latitude,
      longitude: longitude,
      query: query,
      radiusMeters: radiusMeters,
    );
  }

  // ============================================================
  // HOSPITALS
  // ============================================================

  Future<List<MapPlaceModel>> searchHospitals({
    required double latitude,
    required double longitude,
    int radiusMeters = 10000,
  }) {
    return _placesService.searchHospitals(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
  }

  // ============================================================
  // BLOOD BANKS
  // ============================================================

  Future<List<MapPlaceModel>> searchBloodBanks({
    required double latitude,
    required double longitude,
    int radiusMeters = 10000,
  }) {
    return _placesService.searchBloodBanks(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
  }

  // ============================================================
  // PHARMACIES
  // ============================================================

  Future<List<MapPlaceModel>> searchPharmacies({
    required double latitude,
    required double longitude,
    int radiusMeters = 10000,
  }) {
    return _placesService.searchPharmacies(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
  }

  // ============================================================
  // EMERGENCY FACILITIES
  // ============================================================

  Future<List<MapPlaceModel>> searchEmergencyFacilities({
    required double latitude,
    required double longitude,
    int radiusMeters = 10000,
  }) {
    return _placesService.searchEmergencyFacilities(
      latitude: latitude,
      longitude: longitude,
      radiusMeters: radiusMeters,
    );
  }

  // ============================================================
  // PLACE DETAILS
  // ============================================================

  Future<MapPlaceModel?> getPlaceDetails({
    required String placeId,
  }) {
    return _placesService.getPlaceDetails(
      placeId: placeId,
    );
  }

  // ============================================================
  // DRIVING ROUTE
  // ============================================================

  Future<RouteModel?> getDrivingRoute({
    required LatLng origin,
    required LatLng destination,
  }) {
    return _routesService.getDrivingRoute(
      origin: origin,
      destination: destination,
    );
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  void dispose() {
    _placesService.dispose();
    _routesService.dispose();
  }
}
