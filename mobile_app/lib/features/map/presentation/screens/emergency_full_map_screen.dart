import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/map_place_model.dart';
import '../../../sos/data/models/nearby_resource_model.dart';
import '../../data/models/route_model.dart';
import '../../data/services/places_service.dart';
import '../../data/services/routes_service.dart';

/// Full-screen healthcare/emergency map.
///
/// Data sources:
/// - Real LifeLynk nearby resources supplied by SosProvider
/// - OpenStreetMap / Overpass / Nominatim place data
/// - OSRM driving routes
/// - Real GPS supplied by the caller
///
/// LifeLynk resources are never replaced by OSM results. Both data
/// sources can be displayed together.
///
/// [apiKey] remains only for backwards compatibility with older
/// callers. It is ignored because this screen does not use Google Maps.
class EmergencyFullMapScreen extends StatefulWidget {
  final LatLng? initialLocation;

  /// Real LifeLynk emergency resources supplied by SosProvider.
  ///
  /// These are the resources already resolved from the LifeLynk
  /// backend/database through NearbyResourceService.
  final List<NearbyResourceModel> resources;

  final String? apiKey;

  const EmergencyFullMapScreen({
    super.key,
    this.initialLocation,
    this.resources = const [],
    @Deprecated(
      'Google Maps/OpenStreetMap API keys are not used by this screen.',
    )
    this.apiKey,
  });

  @override
  State<EmergencyFullMapScreen> createState() =>
      _EmergencyFullMapScreenState();
}

class _EmergencyFullMapScreenState
    extends State<EmergencyFullMapScreen> {
  // ============================================================
  // MAP
  // ============================================================

  final MapController _mapController = MapController();

  bool _mapReady = false;

  // ============================================================
  // SERVICES
  // ============================================================

  late final PlacesService _placesService;

  late final RoutesService _routesService;

  // ============================================================
  // STATE
  // ============================================================

  LatLng? _currentLocation;

  /// OSM / Overpass / Nominatim places.
  List<MapPlaceModel> _places = [];

  MapPlaceModel? _selectedPlace;

  NearbyResourceModel? _selectedResource;

  String _selectedCategory = 'hospital';

  RouteModel? _currentRoute;

  bool _loading = false;

  bool _routeLoading = false;

  String? _error;

  final TextEditingController _searchController =
      TextEditingController();

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    _placesService = PlacesService();

    _routesService = RoutesService();

    _currentLocation = widget.initialLocation;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> _initialize() async {
    final location = _currentLocation;

    if (location == null) {
      return;
    }

    await _searchCategory(_selectedCategory);
  }

  // ============================================================
  // LIFE LYNK RESOURCE FILTER
  // ============================================================

  List<NearbyResourceModel> get _visibleResources {
    final validResources = widget.resources.where(
      (resource) => resource.hasValidLocation,
    );

    switch (_selectedCategory) {
      case 'hospital':
        return validResources
            .where(
              (resource) => resource.isHospital,
            )
            .toList();

      case 'blood_bank':
        return validResources
            .where(
              (resource) => resource.isBloodBank,
            )
            .toList();

      case 'donor':
        return validResources
            .where(
              (resource) => resource.isDonor,
            )
            .toList();

      case 'emergency':
        // Emergency view intentionally exposes every real
        // LifeLynk emergency resource.
        return validResources.toList();

      case 'pharmacy':
      default:
        // LifeLynk currently supplies hospitals, blood banks and
        // donors through NearbyResourceModel. Pharmacy results
        // therefore remain OSM-based.
        return <NearbyResourceModel>[];
    }
  }

  // ============================================================
  // CATEGORY
  // ============================================================

  Future<void> _searchCategory(
    String category,
  ) async {
    final location = _currentLocation;

    if (location == null) {
      _setError(
        'Current location is unavailable.',
      );
      return;
    }

    setState(() {
      _selectedCategory = category;
      _loading = true;
      _error = null;
      _selectedPlace = null;
      _selectedResource = null;
      _currentRoute = null;
    });

    try {
      List<MapPlaceModel> results;

      switch (category) {
        case 'hospital':
          results = await _placesService.searchHospitals(
            latitude: location.latitude,
            longitude: location.longitude,
          );
          break;

        case 'blood_bank':
          results = await _placesService.searchBloodBanks(
            latitude: location.latitude,
            longitude: location.longitude,
          );
          break;

        case 'pharmacy':
          results = await _placesService.searchPharmacies(
            latitude: location.latitude,
            longitude: location.longitude,
          );
          break;

        case 'emergency':
          results =
              await _placesService.searchEmergencyFacilities(
            latitude: location.latitude,
            longitude: location.longitude,
          );
          break;

        case 'donor':
          // Donors are already supplied by LifeLynk. There is no
          // need to query OSM for individual donor records.
          results = <MapPlaceModel>[];
          break;

        default:
          results = await _placesService.searchNearby(
            latitude: location.latitude,
            longitude: location.longitude,
            query: category,
          );
      }

      if (!mounted) {
        return;
      }

      setState(() {
        _places = results;
      });

      _fitVisibleLocations();
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _places = [];
        _error = _exceptionMessage(e);
      });

      // Even when OSM lookup fails, real LifeLynk resources
      // remain available and should still be fitted/displayed.
      _fitVisibleLocations();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // TEXT SEARCH
  // ============================================================

  Future<void> _search(
    String value,
  ) async {
    final query = value.trim();

    if (query.isEmpty) {
      await _searchCategory(
        _selectedCategory,
      );
      return;
    }

    final location = _currentLocation;

    if (location == null) {
      _setError(
        'Current location is unavailable.',
      );
      return;
    }

    setState(() {
      _loading = true;
      _error = null;
      _selectedPlace = null;
      _selectedResource = null;
      _currentRoute = null;
    });

    try {
      final results = await _placesService.searchNearby(
        latitude: location.latitude,
        longitude: location.longitude,
        query: query,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _places = results;
      });

      _fitVisibleLocations();
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _places = [];
        _error = _exceptionMessage(e);
      });

      _fitVisibleLocations();
    } finally {
      if (mounted) {
        setState(() {
          _loading = false;
        });
      }
    }
  }

  // ============================================================
  // LIFE LYNK RESOURCE SEARCH MATCH
  // ============================================================

  bool _resourceMatchesSearch(
    NearbyResourceModel resource,
    String query,
  ) {
    final normalized = query.toLowerCase();

    final values = <String>[
      resource.name,
      resource.typeLabel,
      resource.address ?? '',
      resource.bloodGroup ?? '',
      resource.phone ?? '',
      resource.emergencyContact ?? '',
    ];

    return values.any(
      (value) => value.toLowerCase().contains(normalized),
    );
  }

  List<NearbyResourceModel> get _searchMatchedResources {
    final query = _searchController.text.trim();

    if (query.isEmpty) {
      return _visibleResources;
    }

    return widget.resources
        .where(
          (resource) =>
              resource.hasValidLocation &&
              _resourceMatchesSearch(
                resource,
                query,
              ),
        )
        .toList();
  }

  // ============================================================
  // PLACE TAP
  // ============================================================

  Future<void> _selectPlace(
    MapPlaceModel place,
  ) async {
    setState(() {
      _selectedPlace = place;
      _selectedResource = null;
    });

    _moveTo(
      place.location,
      zoom: 16,
    );

    if (place.hasPlaceId) {
      try {
        final details = await _placesService.getPlaceDetails(
          placeId: place.placeId!,
        );

        if (details != null && mounted) {
          setState(() {
            _selectedPlace = details;

            final index = _places.indexWhere(
              (item) => item.id == place.id,
            );

            if (index >= 0) {
              final updated = [..._places];

              updated[index] = details;

              _places = updated;
            }
          });
        }
      } catch (_) {
        // Base POI result remains usable when details lookup fails.
      }
    }

    if (!mounted) {
      return;
    }

    _showPlaceSheet(
      _selectedPlace ?? place,
    );
  }

  // ============================================================
  // LIFE LYNK RESOURCE TAP
  // ============================================================

  void _selectResource(
    NearbyResourceModel resource,
  ) {
    setState(() {
      _selectedResource = resource;
      _selectedPlace = null;
    });

    _moveTo(
      LatLng(
        resource.latitude,
        resource.longitude,
      ),
      zoom: 16,
    );

    _showResourceSheet(resource);
  }

  // ============================================================
  // PLACE SHEET
  // ============================================================

  void _showPlaceSheet(
    MapPlaceModel place,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  place.name,
                  style: Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 5),
                Text(
                  place.categoryLabel,
                  style: Theme.of(context)
                      .textTheme
                      .bodyMedium,
                ),
                if (place.hasAddress) ...[
                  const SizedBox(height: 12),
                  Text(
                    place.address!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium,
                  ),
                ],
                if (place.hasPhone) ...[
                  const SizedBox(height: 8),
                  Text(
                    place.phone!,
                    style: Theme.of(context)
                        .textTheme
                        .bodyMedium,
                  ),
                ],
                const SizedBox(height: 18),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: () async {
                      Navigator.of(context).pop();

                      await _getDirections(place);
                    },
                    icon: const Icon(
                      Icons.directions_rounded,
                    ),
                    label: const Text(
                      'Get Directions',
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // LIFE LYNK RESOURCE SHEET
  // ============================================================

  void _showResourceSheet(
    NearbyResourceModel resource,
  ) {
    final colors = Theme.of(context).colorScheme;

    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (_) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      _LifeLynkResourceIcon(
                        type: resource.type,
                        size: 48,
                      ),
                      const SizedBox(width: 14),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment.start,
                          children: [
                            Text(
                              resource.name,
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight:
                                        FontWeight.w800,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'LifeLynk ${resource.typeLabel}',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodyMedium
                                  ?.copyWith(
                                    color: colors
                                        .onSurfaceVariant,
                                    fontWeight:
                                        FontWeight.w600,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  if (resource.hasAddress)
                    _ResourceInfoRow(
                      icon: Icons.location_on_rounded,
                      text: resource.address!,
                    ),
                  if (resource.hasContactNumber)
                    _ResourceInfoRow(
                      icon: Icons.phone_rounded,
                      text: resource.contactNumber!,
                    ),
                  if (resource.bloodGroup != null &&
                      resource.bloodGroup!.trim().isNotEmpty)
                    _ResourceInfoRow(
                      icon: Icons.bloodtype_rounded,
                      text:
                          'Blood group: ${resource.bloodGroup}',
                    ),
                  if (resource.hasAvailabilityData)
                    _ResourceInfoRow(
                      icon: Icons.inventory_2_rounded,
                      text: resource.availabilityLabel,
                    ),
                  _ResourceInfoRow(
                    icon: Icons.near_me_rounded,
                    text:
                        'Approx. ${resource.distanceLabel} away',
                  ),
                  if (resource.estimatedTravelTimeMinutes !=
                      null)
                    _ResourceInfoRow(
                      icon: Icons.access_time_rounded,
                      text: resource.travelTimeLabel,
                    ),
                  const SizedBox(height: 18),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.icon(
                      onPressed: () async {
                        Navigator.of(context).pop();

                        await _getDirectionsToResource(
                          resource,
                        );
                      },
                      icon: const Icon(
                        Icons.directions_rounded,
                      ),
                      label: const Text(
                        'Get Directions',
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // OSM ROUTE
  // ============================================================

  Future<void> _getDirections(
    MapPlaceModel place,
  ) async {
    final origin = _currentLocation;

    if (origin == null) {
      _setError(
        'Current location is unavailable.',
      );
      return;
    }

    await _getDirectionsToLocation(
      destination: place.location,
    );
  }

  // ============================================================
  // LIFE LYNK ROUTE
  // ============================================================

  Future<void> _getDirectionsToResource(
    NearbyResourceModel resource,
  ) async {
    if (!resource.hasValidLocation) {
      _setError(
        'This resource does not have a valid location.',
      );
      return;
    }

    await _getDirectionsToLocation(
      destination: LatLng(
        resource.latitude,
        resource.longitude,
      ),
    );
  }

  // ============================================================
  // ROUTE TO LOCATION
  // ============================================================

  Future<void> _getDirectionsToLocation({
    required LatLng destination,
  }) async {
    final origin = _currentLocation;

    if (origin == null) {
      _setError(
        'Current location is unavailable.',
      );
      return;
    }

    setState(() {
      _routeLoading = true;
      _error = null;
    });

    try {
      final route = await _routesService.getDrivingRoute(
        origin: origin,
        destination: destination,
      );

      if (!mounted) {
        return;
      }

      setState(() {
        _currentRoute = route;
      });

      if (route != null) {
        _fitRoute(route);
      } else {
        _setError(
          'Driving directions could not be found.',
        );
      }
    } on Exception catch (e) {
      if (!mounted) {
        return;
      }

      setState(() {
        _currentRoute = null;
        _error = _exceptionMessage(e);
      });
    } finally {
      if (mounted) {
        setState(() {
          _routeLoading = false;
        });
      }
    }
  }

  // ============================================================
  // CAMERA
  // ============================================================

  void _moveTo(
    LatLng location, {
    double zoom = 14,
  }) {
    if (!_mapReady) {
      return;
    }

    try {
      _mapController.move(
        location,
        zoom,
      );
    } catch (_) {}
  }

  // ============================================================
  // FIT ALL VISIBLE LOCATIONS
  // ============================================================

  void _fitVisibleLocations() {
    if (!_mapReady) {
      return;
    }

    final points = <LatLng>[];

    if (_currentLocation != null &&
        _isValidCoordinate(_currentLocation!)) {
      points.add(_currentLocation!);
    }

    final resources = _searchMatchedResources;

    for (final resource in resources) {
      if (resource.hasValidLocation) {
        final point = LatLng(
          resource.latitude,
          resource.longitude,
        );

        if (_isValidCoordinate(point)) {
          points.add(point);
        }
      }
    }

    for (final place in _places) {
      if (place.hasValidLocation) {
        points.add(place.location);
      }
    }

    if (points.isEmpty) {
      return;
    }

    if (points.length == 1) {
      _moveTo(
        points.first,
        zoom: 15,
      );
      return;
    }

    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: points,
          padding: const EdgeInsets.fromLTRB(
            40,
            150,
            40,
            120,
          ),
          maxZoom: 16,
        ),
      );
    } catch (_) {}
  }

  // ============================================================
  // FIT ROUTE
  // ============================================================

  void _fitRoute(
    RouteModel route,
  ) {
    if (!_mapReady) {
      return;
    }

    final points = <LatLng>[
      route.origin,
      route.destination,
      ...route.polylinePoints,
    ];

    final valid = points.where(
      _isValidCoordinate,
    ).toList();

    if (valid.isEmpty) {
      return;
    }

    if (valid.length == 1) {
      _moveTo(
        valid.first,
        zoom: 15,
      );
      return;
    }

    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: valid,
          padding: const EdgeInsets.fromLTRB(
            50,
            150,
            50,
            220,
          ),
          maxZoom: 16,
        ),
      );
    } catch (_) {}
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    final location = _currentLocation;

    final center = location ??
        const LatLng(
          31.5204,
          74.3587,
        );

    final visibleResources =
        _searchMatchedResources;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Emergency Map',
        ),
        actions: [
          IconButton(
            tooltip: 'Clear route',
            onPressed: _currentRoute == null
                ? null
                : () {
                    setState(() {
                      _currentRoute = null;
                    });
                  },
            icon: const Icon(
              Icons.route_rounded,
            ),
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: center,
              initialZoom:
                  location != null ? 14 : 11,
              interactionOptions:
                  const InteractionOptions(
                flags: InteractiveFlag.all,
              ),
              onMapReady: () {
                _mapReady = true;

                if (_currentLocation != null) {
                  _moveTo(
                    _currentLocation!,
                    zoom: 14,
                  );
                }

                _fitVisibleLocations();
              },
              onTap: (_, _) {
                if (!mounted) {
                  return;
                }

                setState(() {
                  _selectedPlace = null;
                  _selectedResource = null;
                });
              },
            ),
            children: [
              // ==================================================
              // OPENSTREETMAP TILES
              // ==================================================

              TileLayer(
                urlTemplate:
                    'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName:
                    'com.lifelynk.ai',
                maxZoom: 19,
              ),

              // ==================================================
              // ROUTE
              // ==================================================

              if (_currentRoute != null &&
                  _currentRoute!.hasPolyline)
                PolylineLayer(
                  polylines: [
                    Polyline(
                      points:
                          _currentRoute!
                              .polylinePoints,
                      strokeWidth: 5,
                      color: Theme.of(context)
                          .colorScheme
                          .primary,
                    ),
                  ],
                ),

              // ==================================================
              // MARKERS
              // ==================================================

              MarkerLayer(
                markers: [
                  // ----------------------------------------------
                  // CURRENT LOCATION
                  // ----------------------------------------------

                  if (_currentLocation != null)
                    Marker(
                      point:
                          _currentLocation!,
                      width: 48,
                      height: 48,
                      child:
                          const _FullMapCurrentMarker(),
                    ),

                  // ----------------------------------------------
                  // REAL LIFE LYNK RESOURCES
                  // ----------------------------------------------

                  ...visibleResources.map(
                    (resource) {
                      return Marker(
                        point: LatLng(
                          resource.latitude,
                          resource.longitude,
                        ),
                        width: 58,
                        height: 72,
                        alignment:
                            Alignment.bottomCenter,
                        child: GestureDetector(
                          onTap: () {
                            _selectResource(
                              resource,
                            );
                          },
                          child:
                              _FullMapResourceMarker(
                            resource: resource,
                            selected:
                                _selectedResource
                                        ?.id ==
                                    resource.id,
                          ),
                        ),
                      );
                    },
                  ),

                  // ----------------------------------------------
                  // OSM PLACES
                  // ----------------------------------------------

                  ..._places
                      .where(
                        (place) =>
                            place.hasValidLocation,
                      )
                      .map(
                        (place) => Marker(
                          point: place.location,
                          width: 54,
                          height: 66,
                          alignment:
                              Alignment.bottomCenter,
                          child:
                              GestureDetector(
                            onTap: () {
                              _selectPlace(
                                place,
                              );
                            },
                            child:
                                _FullMapPlaceMarker(
                              place: place,
                              selected:
                                  _selectedPlace
                                          ?.id ==
                                      place.id,
                            ),
                          ),
                        ),
                      ),
                ],
              ),

              // ==================================================
              // ATTRIBUTION
              // ==================================================

              RichAttributionWidget(
                attributions: [
                  TextSourceAttribution(
                    'OpenStreetMap contributors',
                    onTap: () {},
                  ),
                ],
              ),
            ],
          ),

          // ======================================================
          // SEARCH
          // ======================================================

          Positioned(
            top: 12,
            left: 16,
            right: 16,
            child: Material(
              elevation: 5,
              borderRadius:
                  BorderRadius.circular(16),
              child: TextField(
                controller:
                    _searchController,
                textInputAction:
                    TextInputAction.search,
                onChanged: (_) {
                  if (mounted) {
                    setState(() {});
                  }
                },
                onSubmitted: _search,
                decoration: InputDecoration(
                  hintText:
                      'Search healthcare facilities...',
                  prefixIcon: const Icon(
                    Icons.search_rounded,
                  ),
                  suffixIcon: _loading
                      ? const Padding(
                          padding:
                              EdgeInsets.all(14),
                          child: SizedBox(
                            width: 18,
                            height: 18,
                            child:
                                CircularProgressIndicator(
                              strokeWidth: 2,
                            ),
                          ),
                        )
                      : _searchController
                              .text
                              .isNotEmpty
                          ? IconButton(
                              tooltip:
                                  'Clear search',
                              onPressed: () {
                                _searchController
                                    .clear();

                                setState(() {});

                                _searchCategory(
                                  _selectedCategory,
                                );
                              },
                              icon: const Icon(
                                Icons
                                    .close_rounded,
                              ),
                            )
                          : null,
                  filled: true,
                  border:
                      OutlineInputBorder(
                    borderRadius:
                        BorderRadius.circular(
                      16,
                    ),
                    borderSide:
                        BorderSide.none,
                  ),
                ),
              ),
            ),
          ),

          // ======================================================
          // CATEGORY SELECTOR
          // ======================================================

          Positioned(
            top: 76,
            left: 0,
            right: 0,
            child:
                _FullMapCategorySelector(
              selected:
                  _selectedCategory,
              onSelected:
                  _searchCategory,
            ),
          ),

          // ======================================================
          // LOCATION BUTTON
          // ======================================================

          Positioned(
            right: 16,
            bottom:
                _currentRoute != null
                    ? 190
                    : 30,
            child:
                FloatingActionButton.small(
              heroTag:
                  'emergency_full_map_location',
              onPressed:
                  _currentLocation == null
                      ? null
                      : () {
                          _moveTo(
                            _currentLocation!,
                            zoom: 15,
                          );
                        },
              tooltip: 'My location',
              child: const Icon(
                Icons.my_location_rounded,
              ),
            ),
          ),

          // ======================================================
          // ROUTE LOADING
          // ======================================================

          if (_routeLoading)
            const Positioned(
              top: 132,
              left: 16,
              right: 16,
              child:
                  LinearProgressIndicator(),
            ),

          // ======================================================
          // ERROR
          // ======================================================

          if (_error != null)
            Positioned(
              left: 16,
              right: 16,
              bottom:
                  _currentRoute != null
                      ? 92
                      : 16,
              child: Material(
                elevation: 5,
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
                color: Theme.of(context)
                    .colorScheme
                    .errorContainer,
                child: Padding(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 14,
                    vertical: 10,
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.warning_rounded,
                        color: Theme.of(context)
                            .colorScheme
                            .onErrorContainer,
                      ),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Text(
                          _error!,
                          maxLines: 2,
                          overflow:
                              TextOverflow.ellipsis,
                          style: TextStyle(
                            color: Theme.of(context)
                                .colorScheme
                                .onErrorContainer,
                          ),
                        ),
                      ),
                      IconButton(
                        onPressed: () {
                          setState(() {
                            _error = null;
                          });
                        },
                        icon: const Icon(
                          Icons.close_rounded,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),

          // ======================================================
          // ROUTE CARD
          // ======================================================

          if (_currentRoute != null)
            Positioned(
              left: 16,
              right: 16,
              bottom: 16,
              child: _FullMapRouteCard(
                route: _currentRoute!,
                loading: _routeLoading,
                onClear: () {
                  setState(() {
                    _currentRoute = null;
                  });
                },
              ),
            ),
        ],
      ),
    );
  }

  // ============================================================
  // ERROR
  // ============================================================

  void _setError(
    String message,
  ) {
    if (!mounted) {
      return;
    }

    setState(() {
      _error = message;
    });
  }

  String _exceptionMessage(
    Object error,
  ) {
    final value = error.toString();

    if (value.startsWith('Exception: ')) {
      return value.substring(11);
    }

    return value;
  }

  // ============================================================
  // VALIDATION
  // ============================================================

  bool _isValidCoordinate(
    LatLng point,
  ) {
    return point.latitude.isFinite &&
        point.longitude.isFinite &&
        point.latitude >= -90 &&
        point.latitude <= 90 &&
        point.longitude >= -180 &&
        point.longitude <= 180;
  }

  // ============================================================
  // DISPOSE
  // ============================================================

  @override
  void dispose() {
    _searchController.dispose();

    _placesService.dispose();
    _routesService.dispose();

    super.dispose();
  }
}

// ============================================================================
// CATEGORY SELECTOR
// ============================================================================

class _FullMapCategorySelector
    extends StatelessWidget {
  final String selected;

  final ValueChanged<String>
      onSelected;

  const _FullMapCategorySelector({
    required this.selected,
    required this.onSelected,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    const categories = [
      (
        'hospital',
        'Hospitals',
        Icons.local_hospital_rounded,
      ),
      (
        'blood_bank',
        'Blood Banks',
        Icons.bloodtype_rounded,
      ),
      (
        'donor',
        'Donors',
        Icons.volunteer_activism_rounded,
      ),
      (
        'pharmacy',
        'Pharmacies',
        Icons.local_pharmacy_rounded,
      ),
      (
        'emergency',
        'Emergency',
        Icons.emergency_rounded,
      ),
    ];

    return SizedBox(
      height: 48,
      child: ListView.separated(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
        ),
        scrollDirection:
            Axis.horizontal,
        itemCount:
            categories.length,
        separatorBuilder:
            (_, _) =>
                const SizedBox(
          width: 8,
        ),
        itemBuilder:
            (
          context,
          index,
        ) {
          final item =
              categories[index];

          return FilterChip(
            selected:
                selected == item.$1,
            onSelected:
                (_) {
              onSelected(
                item.$1,
              );
            },
            avatar:
                Icon(
              item.$3,
              size: 18,
            ),
            label:
                Text(
              item.$2,
            ),
            showCheckmark:
                false,
          );
        },
      ),
    );
  }
}

// ============================================================================
// CURRENT MARKER
// ============================================================================

class _FullMapCurrentMarker
    extends StatelessWidget {
  const _FullMapCurrentMarker();

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Container(
      decoration:
          BoxDecoration(
        shape:
            BoxShape.circle,
        color:
            colors.primary,
        border:
            Border.all(
          color:
              colors.surface,
          width: 3,
        ),
        boxShadow: [
          BoxShadow(
            blurRadius: 8,
            color:
                Colors.black.withValues(
              alpha: 0.25,
            ),
          ),
        ],
      ),
      child:
          Icon(
        Icons
            .my_location_rounded,
        color:
            colors.onPrimary,
        size: 22,
      ),
    );
  }
}

// ============================================================================
// REAL LIFE LYNK RESOURCE MARKER
// ============================================================================

class _FullMapResourceMarker
    extends StatelessWidget {
  final NearbyResourceModel resource;

  final bool selected;

  const _FullMapResourceMarker({
    required this.resource,
    required this.selected,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final color =
        _markerColor(
      context,
      resource.type,
    );

    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Container(
          width:
              selected ? 46 : 40,
          height:
              selected ? 46 : 40,
          decoration:
              BoxDecoration(
            color: color,
            shape:
                BoxShape.circle,
            border:
                Border.all(
              color:
                  Theme.of(context)
                      .colorScheme
                      .surface,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                blurRadius: 8,
                color: Colors.black
                    .withValues(
                  alpha: 0.22,
                ),
              ),
            ],
          ),
          child: Icon(
            _icon(
              resource.type,
            ),
            color: Colors.white,
            size: 22,
          ),
        ),
        CustomPaint(
          size:
              const Size(
            14,
            8,
          ),
          painter:
              _FullMarkerTailPainter(
            color: color,
          ),
        ),
      ],
    );
  }

  Color _markerColor(
    BuildContext context,
    NearbyResourceType type,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    switch (type) {
      case NearbyResourceType.hospital:
        return colors.error;

      case NearbyResourceType.bloodBank:
        return colors.primary;

      case NearbyResourceType.donor:
        // Preserve the donor marker distinction used by
        // the LifeLynk SOS map.
        return Colors.deepPurple;
    }
  }

  IconData _icon(
    NearbyResourceType type,
  ) {
    switch (type) {
      case NearbyResourceType.hospital:
        return Icons.local_hospital_rounded;

      case NearbyResourceType.bloodBank:
        return Icons.bloodtype_rounded;

      case NearbyResourceType.donor:
        return Icons.volunteer_activism_rounded;
    }
  }
}

// ============================================================================
// LIFE LYNK RESOURCE ICON
// ============================================================================

class _LifeLynkResourceIcon
    extends StatelessWidget {
  final NearbyResourceType type;

  final double size;

  const _LifeLynkResourceIcon({
    required this.type,
    required this.size,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    final Color color;

    final IconData icon;

    switch (type) {
      case NearbyResourceType.hospital:
        color = colors.error;
        icon = Icons.local_hospital_rounded;
        break;

      case NearbyResourceType.bloodBank:
        color = colors.primary;
        icon = Icons.bloodtype_rounded;
        break;

      case NearbyResourceType.donor:
        color = Colors.deepPurple;
        icon = Icons.volunteer_activism_rounded;
        break;
    }

    return Container(
      width: size,
      height: size,
      decoration:
          BoxDecoration(
        color: color.withValues(
          alpha: 0.12,
        ),
        shape:
            BoxShape.circle,
      ),
      child: Icon(
        icon,
        color: color,
        size: size * 0.52,
      ),
    );
  }
}

// ============================================================================
// RESOURCE INFO ROW
// ============================================================================

class _ResourceInfoRow
    extends StatelessWidget {
  final IconData icon;

  final String text;

  const _ResourceInfoRow({
    required this.icon,
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 9,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 19,
            color:
                colors.primary,
          ),
          const SizedBox(
            width: 10,
          ),
          Expanded(
            child: Text(
              text,
              style:
                  Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                        height: 1.35,
                      ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// OSM PLACE MARKER
// ============================================================================

class _FullMapPlaceMarker
    extends StatelessWidget {
  final MapPlaceModel place;

  final bool selected;

  const _FullMapPlaceMarker({
    required this.place,
    required this.selected,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Container(
          width:
              selected ? 44 : 38,
          height:
              selected ? 44 : 38,
          decoration:
              BoxDecoration(
            color:
                colors.primary,
            shape:
                BoxShape.circle,
            border:
                Border.all(
              color:
                  colors.surface,
              width: 3,
            ),
          ),
          child:
              Icon(
            _icon(
              place.category,
            ),
            color:
                colors.onPrimary,
          ),
        ),
        CustomPaint(
          size:
              const Size(
            14,
            8,
          ),
          painter:
              _FullMarkerTailPainter(
            color:
                colors.primary,
          ),
        ),
      ],
    );
  }

  IconData _icon(
    String? category,
  ) {
    switch (
        category?.toLowerCase()) {
      case 'hospital':
        return Icons
            .local_hospital_rounded;

      case 'blood_bank':
        return Icons
            .bloodtype_rounded;

      case 'pharmacy':
        return Icons
            .local_pharmacy_rounded;

      case 'emergency':
        return Icons
            .emergency_rounded;

      default:
        return Icons
            .location_on_rounded;
    }
  }
}

// ============================================================================
// MARKER TAIL
// ============================================================================

class _FullMarkerTailPainter
    extends CustomPainter {
  final Color color;

  const _FullMarkerTailPainter({
    required this.color,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final path = ui.Path()
      ..moveTo(
        0,
        0,
      )
      ..lineTo(
        size.width / 2,
        size.height,
      )
      ..lineTo(
        size.width,
        0,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(
    covariant _FullMarkerTailPainter
        oldDelegate,
  ) {
    return oldDelegate.color != color;
  }
}

// ============================================================================
// ROUTE CARD
// ============================================================================

class _FullMapRouteCard
    extends StatelessWidget {
  final RouteModel route;

  final bool loading;

  final VoidCallback onClear;

  const _FullMapRouteCard({
    required this.route,
    required this.loading,
    required this.onClear,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Material(
      elevation:
          6,
      borderRadius:
          BorderRadius.circular(
        18,
      ),
      color:
          colors.surface,
      child:
          Padding(
        padding:
            const EdgeInsets.fromLTRB(
          16,
          14,
          10,
          14,
        ),
        child:
            Row(
          children: [
            Icon(
              Icons
                  .directions_car_rounded,
              color:
                  colors.primary,
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child:
                  Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    route
                        .distanceLabel,
                    style:
                        Theme.of(
                      context,
                    )
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                      fontWeight:
                          FontWeight
                              .w800,
                    ),
                  ),
                  const SizedBox(
                    height:
                        3,
                  ),
                  Text(
                    route
                        .durationLabel,
                    style:
                        Theme.of(
                      context,
                    )
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                      color:
                          colors
                              .onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (loading)
              const SizedBox(
                width:
                    20,
                height:
                    20,
                child:
                    CircularProgressIndicator(
                  strokeWidth:
                      2,
                ),
              ),
            IconButton(
              onPressed:
                  onClear,
              icon:
                  const Icon(
                Icons
                    .close_rounded,
              ),
            ),
          ],
        ),
      ),
    );
  }
}