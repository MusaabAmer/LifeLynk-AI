import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/emergency_sos_model.dart';
import '../../data/models/nearby_resource_model.dart';

/// ============================================================================
/// LIFELYNK AI — EMERGENCY MAP
/// ============================================================================
///
/// OpenStreetMap presentation widget.
///
/// Responsibilities:
/// - Display current GPS location.
/// - Fall back to active SOS coordinates.
/// - Display real Supabase-backed nearby resources.
/// - Display selected destination.
/// - Display route polylines.
/// - Support pan / pinch zoom / double-tap zoom.
/// - Provide camera controls.
/// - Fit relevant markers.
///
/// This widget does NOT:
/// - Query Supabase.
/// - Query OSM search APIs.
/// - Read device GPS.
/// - Manage SOS state.
/// - Own realtime subscriptions.
/// - Perform external navigation.
///
/// Data flow:
///
/// Provider / Repository / Services
///              ↓
///        EmergencyMap
///              ↓
///      flutter_map + OSM
/// ============================================================================

class EmergencyMap extends StatefulWidget {
  // ==========================================================================
  // LOCATION
  // ==========================================================================

  /// Active SOS.
  ///
  /// Used as the fallback map location when current GPS is unavailable.
  final EmergencySosModel? sos;

  /// Current device GPS location.
  ///
  /// Takes priority over SOS coordinates.
  final LatLng? currentLocation;

  // ==========================================================================
  // RESOURCES
  // ==========================================================================

  /// Real nearby LifeLynk resources.
  ///
  /// These may include:
  /// - hospitals
  /// - blood banks
  /// - donors
  final List<NearbyResourceModel> resources;

  // ==========================================================================
  // ROUTE
  // ==========================================================================

  /// Optional route polylines.
  ///
  /// Each inner list represents one route.
  final List<List<LatLng>> polylines;

  /// Optional selected destination.
  final LatLng? destination;

  /// Optional destination title.
  final String? destinationTitle;

  // ==========================================================================
  // UI
  // ==========================================================================

  final double? height;

  final bool showMyLocationButton;

  final bool showDirectionControls;

  /// Kept for backwards compatibility.
  ///
  /// Standard OSM does not provide satellite/terrain through the standard
  /// tile endpoint.
  final bool showMapTypeButton;

  /// Kept for backwards compatibility.
  ///
  /// No fake traffic layer is rendered.
  final bool showTrafficButton;

  final bool showFitAllButton;

  // ==========================================================================
  // CALLBACKS
  // ==========================================================================

  final ValueChanged<NearbyResourceModel>? onResourceTap;

  final VoidCallback? onDestinationTap;

  final ValueChanged<LatLng>? onMapTap;

  final ValueChanged<LatLng>? onMapLongPress;

  final VoidCallback? onFullscreenTap;

  const EmergencyMap({
    super.key,
    this.sos,
    this.currentLocation,
    required this.resources,
    this.polylines = const <List<LatLng>>[],
    this.destination,
    this.destinationTitle,
    this.height = 360,
    this.showMyLocationButton = true,
    this.showDirectionControls = true,
    this.showMapTypeButton = true,
    this.showTrafficButton = false,
    this.showFitAllButton = true,
    this.onResourceTap,
    this.onDestinationTap,
    this.onMapTap,
    this.onMapLongPress,
    this.onFullscreenTap,
  });

  @override
  State<EmergencyMap> createState() => _EmergencyMapState();
}

// ============================================================================
// STATE
// ============================================================================

class _EmergencyMapState extends State<EmergencyMap> {
  final MapController _mapController = MapController();

  List<Marker> _markers = <Marker>[];

  bool _mapReady = false;

  bool _hasInitialCameraFit = false;

  bool _isFollowingUser = false;

  bool _isProgrammaticCameraMove = false;

  // ==========================================================================
  // CONSTANTS
  // ==========================================================================

  static const double _initialZoom = 14.5;

  static const double _userZoom = 15.5;

  static const double _minimumZoom = 3;

  static const double _maximumZoom = 19;

  static const double _minimumLatitude = -90;

  static const double _maximumLatitude = 90;

  static const double _minimumLongitude = -180;

  static const double _maximumLongitude = 180;

  static const String _osmTileUrl =
      'https://tile.openstreetmap.org/{z}/{x}/{y}.png';

  // ==========================================================================
  // INIT
  // ==========================================================================

  @override
  void initState() {
    super.initState();

    _markers = _createMarkers();
  }

  // ==========================================================================
  // WIDGET UPDATE
  // ==========================================================================

  @override
  void didUpdateWidget(
    covariant EmergencyMap oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);

    final locationChanged =
        oldWidget.sos?.latitude != widget.sos?.latitude ||
            oldWidget.sos?.longitude != widget.sos?.longitude ||
            oldWidget.currentLocation?.latitude !=
                widget.currentLocation?.latitude ||
            oldWidget.currentLocation?.longitude !=
                widget.currentLocation?.longitude;

    final resourcesChanged = _resourcesChanged(
      oldWidget.resources,
      widget.resources,
    );

    final destinationChanged =
        oldWidget.destination?.latitude !=
                widget.destination?.latitude ||
            oldWidget.destination?.longitude !=
                widget.destination?.longitude ||
            oldWidget.destinationTitle !=
                widget.destinationTitle;

    final routeChanged = !_polylinesEqual(
      oldWidget.polylines,
      widget.polylines,
    );

    if (locationChanged ||
        resourcesChanged ||
        destinationChanged) {
      _updateMarkers();
    }

    // ------------------------------------------------------------------------
    // The map should follow live GPS only after the user explicitly presses
    // "My location".
    // ------------------------------------------------------------------------

    if (locationChanged &&
        _isFollowingUser &&
        _getUserLocation() != null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mapReady) {
          return;
        }

        _moveToUser();
      });
    }

    // ------------------------------------------------------------------------
    // If the map was previously displaying only the user location and new
    // resources/routes arrive, fit everything once.
    // ------------------------------------------------------------------------

    if ((resourcesChanged ||
            destinationChanged ||
            routeChanged) &&
        !_hasInitialCameraFit &&
        _mapReady) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted || !_mapReady) {
          return;
        }

        fitAllMarkers();
      });
    }
  }

  // ==========================================================================
  // RESOURCE CHANGE DETECTION
  // ==========================================================================

  bool _resourcesChanged(
    List<NearbyResourceModel> oldResources,
    List<NearbyResourceModel> newResources,
  ) {
    if (oldResources.length != newResources.length) {
      return true;
    }

    for (var i = 0; i < oldResources.length; i++) {
      final oldResource = oldResources[i];
      final newResource = newResources[i];

      if (oldResource.id != newResource.id ||
          oldResource.name != newResource.name ||
          oldResource.type != newResource.type ||
          oldResource.latitude != newResource.latitude ||
          oldResource.longitude != newResource.longitude ||
          oldResource.distanceKm != newResource.distanceKm ||
          oldResource.estimatedTravelTimeMinutes !=
              newResource.estimatedTravelTimeMinutes ||
          oldResource.availableUnits !=
              newResource.availableUnits ||
          oldResource.bloodGroup !=
              newResource.bloodGroup ||
          oldResource.phone != newResource.phone ||
          oldResource.address != newResource.address) {
        return true;
      }
    }

    return false;
  }

  // ==========================================================================
  // POLYLINE CHANGE DETECTION
  // ==========================================================================

  bool _polylinesEqual(
    List<List<LatLng>> first,
    List<List<LatLng>> second,
  ) {
    if (identical(first, second)) {
      return true;
    }

    if (first.length != second.length) {
      return false;
    }

    for (var routeIndex = 0;
        routeIndex < first.length;
        routeIndex++) {
      final firstRoute = first[routeIndex];
      final secondRoute = second[routeIndex];

      if (firstRoute.length != secondRoute.length) {
        return false;
      }

      for (var pointIndex = 0;
          pointIndex < firstRoute.length;
          pointIndex++) {
        if (firstRoute[pointIndex] !=
            secondRoute[pointIndex]) {
          return false;
        }
      }
    }

    return true;
  }

  // ==========================================================================
  // GET USER / EMERGENCY LOCATION
  // ==========================================================================

  LatLng? _getUserLocation() {
    final currentLocation = widget.currentLocation;

    // Current real device GPS takes priority.
    if (currentLocation != null &&
        _isValidCoordinate(
          currentLocation.latitude,
          currentLocation.longitude,
        )) {
      return currentLocation;
    }

    // Active SOS GPS is the fallback.
    final sos = widget.sos;

    if (sos != null &&
        sos.hasLocation &&
        sos.latitude != null &&
        sos.longitude != null &&
        _isValidCoordinate(
          sos.latitude!,
          sos.longitude!,
        )) {
      return LatLng(
        sos.latitude!,
        sos.longitude!,
      );
    }

    return null;
  }

  // ==========================================================================
  // CREATE MARKERS
  // ==========================================================================

  List<Marker> _createMarkers() {
    final markers = <Marker>[];

    final currentLocation = widget.currentLocation;

    final userLocation = _getUserLocation();

    // =========================================================================
    // USER / SOS MARKER
    // =========================================================================

    if (userLocation != null) {
      final showingCurrentLocation =
          currentLocation != null &&
              _isValidCoordinate(
                currentLocation.latitude,
                currentLocation.longitude,
              );

      markers.add(
        Marker(
          point: userLocation,
          width: 48,
          height: 58,
          child: _UserLocationMarker(
            isCurrentLocation: showingCurrentLocation,
            isEmergency: widget.sos != null,
          ),
        ),
      );
    }

    // =========================================================================
    // REAL RESOURCE MARKERS
    // =========================================================================

    for (final resource in widget.resources) {
      if (!_isValidCoordinate(
        resource.latitude,
        resource.longitude,
      )) {
        continue;
      }

      markers.add(
        Marker(
          point: LatLng(
            resource.latitude,
            resource.longitude,
          ),
          width: 50,
          height: 62,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () {
              widget.onResourceTap?.call(resource);
            },
            child: _ResourceMarker(
              type: resource.type,
            ),
          ),
        ),
      );
    }

    // =========================================================================
    // DESTINATION MARKER
    // =========================================================================

    final destination = widget.destination;

    if (destination != null &&
        _isValidCoordinate(
          destination.latitude,
          destination.longitude,
        )) {
      markers.add(
        Marker(
          point: destination,
          width: 48,
          height: 58,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: widget.onDestinationTap,
            child: const _DestinationMarker(),
          ),
        ),
      );
    }

    return markers;
  }

  // ==========================================================================
  // UPDATE MARKERS
  // ==========================================================================

  void _updateMarkers() {
    if (!mounted) {
      return;
    }

    setState(() {
      _markers = _createMarkers();
    });
  }

  // ==========================================================================
  // INITIAL CENTER
  // ==========================================================================

  LatLng _initialCenter() {
    return _getUserLocation() ??
        const LatLng(
          31.5204,
          74.3587,
        );
  }

  // ==========================================================================
  // MOVE TO USER
  // ==========================================================================

  void _moveToUser() {
    if (!_mapReady) {
      return;
    }

    final userLocation = _getUserLocation();

    if (userLocation == null) {
      return;
    }

    _isFollowingUser = true;
    _isProgrammaticCameraMove = true;

    try {
      _mapController.move(
        userLocation,
        _userZoom,
      );
    } catch (_) {
      // Map may temporarily be unavailable during rebuild/disposal.
    } finally {
      _isProgrammaticCameraMove = false;
    }
  }

  // ==========================================================================
  // CAMERA MOVE
  // ==========================================================================

  void _onPositionChanged(
    MapCamera camera,
    bool hasGesture,
  ) {
    // Any manual pan/zoom means the user no longer wants automatic following.
    if (hasGesture && !_isProgrammaticCameraMove) {
      _isFollowingUser = false;
    }
  }

  // ==========================================================================
  // FIT ALL MARKERS
  // ==========================================================================

  void fitAllMarkers() {
    if (!_mapReady || _markers.isEmpty) {
      return;
    }

    final coordinates = _markers
        .map((marker) => marker.point)
        .where(
          (point) => _isValidCoordinate(
            point.latitude,
            point.longitude,
          ),
        )
        .toList();

    if (coordinates.isEmpty) {
      return;
    }

    _isFollowingUser = false;
    _isProgrammaticCameraMove = true;

    try {
      // Only one marker.
      if (coordinates.length == 1) {
        _mapController.move(
          coordinates.first,
          _userZoom,
        );

        _hasInitialCameraFit = true;
        return;
      }

      // Multiple resources/destination/route points.
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates: coordinates,
          padding: const EdgeInsets.fromLTRB(
            90,
            100,
            90,
            120,
          ),
          maxZoom: 16,
        ),
      );

      _hasInitialCameraFit = true;
    } catch (_) {
      // Ignore camera errors while flutter_map is transitioning.
    } finally {
      _isProgrammaticCameraMove = false;
    }
  }

  // ==========================================================================
  // MAP READY
  // ==========================================================================

  void _onMapReady() {
    if (!mounted) {
      return;
    }

    _mapReady = true;

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_mapReady) {
        return;
      }

      // Fit resources when they exist.
      if (_markers.length > 1) {
        fitAllMarkers();
      }
    });
  }

  // ==========================================================================
  // MAP TYPE
  // ==========================================================================

  void _showMapTypeSelector() {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) {
        final colors =
            Theme.of(sheetContext).colorScheme;

        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              20,
              8,
              20,
              24,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  'Map Layer',
                  style: Theme.of(sheetContext)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w800,
                      ),
                ),
                const SizedBox(height: 12),
                ListTile(
                  leading: Icon(
                    Icons.map_rounded,
                    color: colors.primary,
                  ),
                  title: const Text(
                    'OpenStreetMap Standard',
                  ),
                  subtitle: const Text(
                    'OpenStreetMap map tiles',
                  ),
                  trailing: Icon(
                    Icons.check_circle_rounded,
                    color: colors.primary,
                  ),
                  selectedTileColor:
                      colors.primaryContainer
                          .withValues(alpha: 0.35),
                  shape:
                      RoundedRectangleBorder(
                    borderRadius:
                        BorderRadius.circular(14),
                  ),
                  onTap: () {
                    Navigator.pop(sheetContext);
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ==========================================================================
  // CAMERA DIRECTION CONTROLS
  // ==========================================================================

  void _moveCameraBy({
    required double latitudeDelta,
    required double longitudeDelta,
  }) {
    if (!_mapReady) {
      return;
    }

    final camera = _mapController.camera;

    _isFollowingUser = false;
    _isProgrammaticCameraMove = true;

    try {
      final current = camera.center;

      final nextLatitude =
          (current.latitude + latitudeDelta).clamp(
        _minimumLatitude,
        _maximumLatitude,
      );

      final nextLongitude =
          (current.longitude + longitudeDelta).clamp(
        _minimumLongitude,
        _maximumLongitude,
      );

      _mapController.move(
        LatLng(
          nextLatitude.toDouble(),
          nextLongitude.toDouble(),
        ),
        camera.zoom,
      );
    } catch (_) {
      // Ignore camera transition errors.
    } finally {
      _isProgrammaticCameraMove = false;
    }
  }

  void _moveCameraUp() {
    _moveCameraBy(
      latitudeDelta: 0.0015,
      longitudeDelta: 0,
    );
  }

  void _moveCameraDown() {
    _moveCameraBy(
      latitudeDelta: -0.0015,
      longitudeDelta: 0,
    );
  }

  void _moveCameraLeft() {
    _moveCameraBy(
      latitudeDelta: 0,
      longitudeDelta: -0.0015,
    );
  }

  void _moveCameraRight() {
    _moveCameraBy(
      latitudeDelta: 0,
      longitudeDelta: 0.0015,
    );
  }

  // ==========================================================================
  // ZOOM IN
  // ==========================================================================

  void _zoomIn() {
    if (!_mapReady) {
      return;
    }

    _isFollowingUser = false;
    _isProgrammaticCameraMove = true;

    try {
      final camera = _mapController.camera;

      _mapController.move(
        camera.center,
        (camera.zoom + 1).clamp(
          _minimumZoom,
          _maximumZoom,
        ),
      );
    } catch (_) {
      // Ignore camera transition errors.
    } finally {
      _isProgrammaticCameraMove = false;
    }
  }

  // ==========================================================================
  // ZOOM OUT
  // ==========================================================================

  void _zoomOut() {
    if (!_mapReady) {
      return;
    }

    _isFollowingUser = false;
    _isProgrammaticCameraMove = true;

    try {
      final camera = _mapController.camera;

      _mapController.move(
        camera.center,
        (camera.zoom - 1).clamp(
          _minimumZoom,
          _maximumZoom,
        ),
      );
    } catch (_) {
      // Ignore camera transition errors.
    } finally {
      _isProgrammaticCameraMove = false;
    }
  }

  // ==========================================================================
  // VALIDATE COORDINATE
  // ==========================================================================

  bool _isValidCoordinate(
    double latitude,
    double longitude,
  ) {
    if (!latitude.isFinite ||
        !longitude.isFinite) {
      return false;
    }

    return latitude >= _minimumLatitude &&
        latitude <= _maximumLatitude &&
        longitude >= _minimumLongitude &&
        longitude <= _maximumLongitude;
  }

  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final userLocation = _getUserLocation();

    // =========================================================================
    // LOCATION UNAVAILABLE
    // =========================================================================

    if (userLocation == null) {
      return Container(
        height: widget.height,
        width: double.infinity,
        decoration: BoxDecoration(
          color:
              colors.surfaceContainerHighest,
          borderRadius:
              BorderRadius.circular(24),
        ),
        child: const _NoLocationState(),
      );
    }

    // =========================================================================
    // ROUTES
    // =========================================================================

    final routePolylines = <Polyline>[];

    for (final route in widget.polylines) {
      final points = route
          .where(
            (point) => _isValidCoordinate(
              point.latitude,
              point.longitude,
            ),
          )
          .toList();

      if (points.length < 2) {
        continue;
      }

      routePolylines.add(
        Polyline(
          points: points,
          strokeWidth: 5,
          color: colors.primary,
          borderStrokeWidth: 1,
          borderColor: colors.surface,
        ),
      );
    }

    // =========================================================================
    // MAP
    // =========================================================================

    return ClipRRect(
      borderRadius:
          BorderRadius.circular(24),
      child: SizedBox(
        height: widget.height,
        width: double.infinity,
        child: Stack(
          children: [
            // =================================================================
            // OPENSTREETMAP
            // =================================================================

            FlutterMap(
              mapController: _mapController,
              options: MapOptions(
                initialCenter: _initialCenter(),
                initialZoom: _initialZoom,
                minZoom: _minimumZoom,
                maxZoom: _maximumZoom,

                // Full normal map interaction:
                // - pan
                // - pinch zoom
                // - double tap zoom
                // - fling
                // - keyboard/mouse interaction where supported
                interactionOptions:
                    const InteractionOptions(
                  flags: InteractiveFlag.all,
                ),

                onMapReady: _onMapReady,

                onPositionChanged:
                    _onPositionChanged,

                onTap: (tapPosition, point) {
                  widget.onMapTap?.call(point);
                },

                onLongPress:
                    (tapPosition, point) {
                  widget.onMapLongPress
                      ?.call(point);
                },
              ),
              children: [
                // =============================================================
                // OSM TILE LAYER
                // =============================================================

                TileLayer(
                  urlTemplate: _osmTileUrl,

                  // IMPORTANT:
                  // Use the real Android application ID.
                  userAgentPackageName:
                      'com.lifelynk.ai',

                  maxNativeZoom: 19,
                  maxZoom: 19,

                  tileProvider:
                      NetworkTileProvider(),
                ),

                // =============================================================
                // ROUTES
                // =============================================================

                if (routePolylines.isNotEmpty)
                  PolylineLayer(
                    polylines:
                        routePolylines,
                  ),

                // =============================================================
                // MARKERS
                // =============================================================

                MarkerLayer(
                  markers: _markers,
                ),

                // =============================================================
                // OSM ATTRIBUTION
                // =============================================================

                RichAttributionWidget(
                  alignment:
                      AttributionAlignment.bottomRight,
                  attributions: [
                    TextSourceAttribution(
                      'OpenStreetMap contributors',
                      prependCopyright: true,
                    ),
                  ],
                ),
              ],
            ),

            // =================================================================
            // HEADER
            // =================================================================

            Positioned(
              top: 14,
              left: 14,
              right:
                  widget.onFullscreenTap !=
                          null
                      ? 64
                      : 14,
              child: _MapHeader(
                resourceCount:
                    widget.resources.length,
                isEmergency:
                    widget.sos != null,
                hasRoutes:
                    routePolylines.isNotEmpty,
              ),
            ),

            // =================================================================
            // FULLSCREEN BUTTON
            // =================================================================

            if (widget.onFullscreenTap != null)
              Positioned(
                top: 14,
                right: 14,
                child: _MapControlButton(
                  icon:
                      Icons.fullscreen_rounded,
                  tooltip:
                      'Open full screen map',
                  onTap:
                      widget.onFullscreenTap!,
                ),
              ),

            // =================================================================
            // MAP LAYER BUTTON
            // =================================================================

            if (widget.showMapTypeButton)
              Positioned(
                top:
                    widget.onFullscreenTap !=
                            null
                        ? 68
                        : 14,
                right: 14,
                child: _MapControlButton(
                  icon:
                      Icons.layers_rounded,
                  tooltip:
                      'Map layer',
                  onTap:
                      _showMapTypeSelector,
                ),
              ),

            // =================================================================
            // CAMERA CONTROLS
            // =================================================================

            Positioned(
              right: 14,
              bottom: 14,
              child: Column(
                children: [
                  if (widget.showDirectionControls)
                    _DirectionControlPad(
                      onUp:
                          _moveCameraUp,
                      onDown:
                          _moveCameraDown,
                      onLeft:
                          _moveCameraLeft,
                      onRight:
                          _moveCameraRight,
                    ),

                  if (widget.showDirectionControls)
                    const SizedBox(height: 8),

                  // -----------------------------------------------------------
                  // ZOOM IN
                  // -----------------------------------------------------------

                  _MapControlButton(
                    icon:
                        Icons.add_rounded,
                    tooltip:
                        'Zoom in',
                    onTap:
                        _zoomIn,
                  ),

                  const SizedBox(height: 8),

                  // -----------------------------------------------------------
                  // ZOOM OUT
                  // -----------------------------------------------------------

                  _MapControlButton(
                    icon:
                        Icons.remove_rounded,
                    tooltip:
                        'Zoom out',
                    onTap:
                        _zoomOut,
                  ),

                  // -----------------------------------------------------------
                  // MY LOCATION
                  // -----------------------------------------------------------

                  if (widget.showMyLocationButton) ...[
                    const SizedBox(height: 8),
                    _MapControlButton(
                      icon:
                          Icons.my_location_rounded,
                      tooltip:
                          'My location',
                      onTap:
                          _moveToUser,
                    ),
                  ],

                  // -----------------------------------------------------------
                  // FIT ALL
                  // -----------------------------------------------------------

                  if (widget.showFitAllButton &&
                      (widget.resources.isNotEmpty ||
                          widget.destination != null ||
                          widget.polylines.isNotEmpty)) ...[
                    const SizedBox(height: 8),
                    _MapControlButton(
                      icon:
                          Icons.fit_screen_rounded,
                      tooltip:
                          'Show all resources',
                      onTap:
                          fitAllMarkers,
                    ),
                  ],
                ],
              ),
            ),

            // =================================================================
            // LEGEND
            // =================================================================

            if (widget.resources.isNotEmpty ||
                widget.destination != null)
              Positioned(
                left: 14,
                bottom: 14,
                child: _MapLegend(
                  hasDestination:
                      widget.destination != null,
                ),
              ),
          ],
        ),
      ),
    );
  }

  // ==========================================================================
  // DISPOSE
  // ==========================================================================

  @override
  void dispose() {
    _mapReady = false;

    _mapController.dispose();

    super.dispose();
  }
}

// ============================================================================
// USER LOCATION MARKER
// ============================================================================

class _UserLocationMarker
    extends StatelessWidget {
  final bool isCurrentLocation;

  final bool isEmergency;

  const _UserLocationMarker({
    required this.isCurrentLocation,
    required this.isEmergency,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final markerColor = isEmergency
        ? colors.error
        : colors.primary;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: markerColor,
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.surface,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(
                  alpha: 0.25,
                ),
                blurRadius: 8,
                offset:
                    const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            isEmergency
                ? Icons.emergency_rounded
                : Icons.my_location_rounded,
            color: Colors.white,
            size: 22,
          ),
        ),
        CustomPaint(
          size: const Size(14, 8),
          painter: _MarkerTipPainter(
            color: markerColor,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// RESOURCE MARKER
// ============================================================================

class _ResourceMarker
    extends StatelessWidget {
  final NearbyResourceType type;

  const _ResourceMarker({
    required this.type,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    late final Color color;
    late final IconData icon;

    switch (type) {
      case NearbyResourceType.hospital:
        color = colors.primary;
        icon =
            Icons.local_hospital_rounded;
        break;

      case NearbyResourceType.bloodBank:
        color = colors.error;
        icon = Icons.bloodtype_rounded;
        break;

      case NearbyResourceType.donor:
        color = Colors.deepPurple;
        icon = Icons.person_rounded;
        break;
    }

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: color,
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.surface,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(
                  alpha: 0.22,
                ),
                blurRadius: 7,
                offset:
                    const Offset(0, 3),
              ),
            ],
          ),
          child: Icon(
            icon,
            color: Colors.white,
            size: 21,
          ),
        ),
        CustomPaint(
          size: const Size(14, 8),
          painter:
              _MarkerTipPainter(
            color: color,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// DESTINATION MARKER
// ============================================================================

class _DestinationMarker
    extends StatelessWidget {
  const _DestinationMarker();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: Colors.green,
            shape: BoxShape.circle,
            border: Border.all(
              color: colors.surface,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black.withValues(
                  alpha: 0.22,
                ),
                blurRadius: 7,
                offset:
                    const Offset(0, 3),
              ),
            ],
          ),
          child: const Icon(
            Icons.location_on_rounded,
            color: Colors.white,
            size: 23,
          ),
        ),
        const CustomPaint(
          size: Size(14, 8),
          painter:
              _MarkerTipPainter(
            color: Colors.green,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// MARKER TIP
// ============================================================================

class _MarkerTipPainter
    extends CustomPainter {
  final Color color;

  const _MarkerTipPainter({
    required this.color,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final path = ui.Path()
      ..moveTo(0, 0)
      ..lineTo(size.width, 0)
      ..lineTo(
        size.width / 2,
        size.height,
      )
      ..close();

    canvas.drawPath(
      path,
      Paint()..color = color,
    );
  }

  @override
  bool shouldRepaint(
    covariant _MarkerTipPainter oldDelegate,
  ) {
    return oldDelegate.color != color;
  }
}

// ============================================================================
// MAP HEADER
// ============================================================================

class _MapHeader
    extends StatelessWidget {
  final int resourceCount;

  final bool isEmergency;

  final bool hasRoutes;

  const _MapHeader({
    required this.resourceCount,
    required this.isEmergency,
    required this.hasRoutes,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final String title;

    if (isEmergency) {
      title = resourceCount == 0
          ? 'Emergency location'
          : '$resourceCount nearby resources';
    } else {
      title = resourceCount == 0
          ? 'Your current location'
          : '$resourceCount nearby resources';
    }

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 13,
        vertical: 10,
      ),
      decoration: BoxDecoration(
        color:
            colors.surface.withValues(
          alpha: 0.94,
        ),
        borderRadius:
            BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.10,
            ),
            blurRadius: 10,
            offset:
                const Offset(0, 3),
          ),
        ],
      ),
      child: Row(
        mainAxisSize:
            MainAxisSize.min,
        children: [
          Icon(
            isEmergency
                ? Icons.emergency_rounded
                : Icons.location_on_rounded,
            size: 18,
            color: isEmergency
                ? colors.error
                : colors.primary,
          ),
          const SizedBox(width: 7),
          Flexible(
            child: Text(
              title,
              overflow:
                  TextOverflow.ellipsis,
              style:
                  Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w700,
                      ),
            ),
          ),
          if (hasRoutes) ...[
            const SizedBox(width: 7),
            Icon(
              Icons.route_rounded,
              size: 15,
              color:
                  colors.primary,
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// DIRECTION CONTROL PAD
// ============================================================================

class _DirectionControlPad
    extends StatelessWidget {
  final VoidCallback onUp;
  final VoidCallback onDown;
  final VoidCallback onLeft;
  final VoidCallback onRight;

  const _DirectionControlPad({
    required this.onUp,
    required this.onDown,
    required this.onLeft,
    required this.onRight,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      color:
          colors.surface.withValues(
        alpha: 0.95,
      ),
      borderRadius:
          BorderRadius.circular(14),
      elevation: 3,
      child: SizedBox(
        width: 126,
        height: 126,
        child: Stack(
          children: [
            Positioned(
              top: 4,
              left: 42,
              child: _DirectionButton(
                icon:
                    Icons.keyboard_arrow_up_rounded,
                tooltip: 'Move up',
                onTap: onUp,
              ),
            ),
            Positioned(
              left: 4,
              top: 42,
              child: _DirectionButton(
                icon:
                    Icons.keyboard_arrow_left_rounded,
                tooltip: 'Move left',
                onTap: onLeft,
              ),
            ),
            Positioned(
              right: 4,
              top: 42,
              child: _DirectionButton(
                icon:
                    Icons.keyboard_arrow_right_rounded,
                tooltip: 'Move right',
                onTap: onRight,
              ),
            ),
            Positioned(
              bottom: 4,
              left: 42,
              child: _DirectionButton(
                icon:
                    Icons.keyboard_arrow_down_rounded,
                tooltip: 'Move down',
                onTap: onDown,
              ),
            ),
            Positioned.fill(
              child: IgnorePointer(
                child: Center(
                  child: Container(
                    width: 34,
                    height: 34,
                    decoration:
                        BoxDecoration(
                      color:
                          colors.surfaceContainerHighest,
                      shape:
                          BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.open_with_rounded,
                      size: 16,
                      color:
                          colors.onSurfaceVariant,
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// DIRECTION BUTTON
// ============================================================================

class _DirectionButton
    extends StatelessWidget {
  final IconData icon;

  final String tooltip;

  final VoidCallback onTap;

  const _DirectionButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Tooltip(
      message: tooltip,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius:
              BorderRadius.circular(10),
          child: SizedBox(
            width: 40,
            height: 40,
            child: Icon(
              icon,
              size: 25,
              color:
                  colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MAP CONTROL BUTTON
// ============================================================================

class _MapControlButton
    extends StatelessWidget {
  final IconData icon;

  final String tooltip;

  final VoidCallback onTap;

  const _MapControlButton({
    required this.icon,
    required this.tooltip,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      color:
          colors.surface.withValues(
        alpha: 0.95,
      ),
      borderRadius:
          BorderRadius.circular(12),
      elevation: 3,
      child: InkWell(
        onTap: onTap,
        borderRadius:
            BorderRadius.circular(12),
        child: Tooltip(
          message: tooltip,
          child: SizedBox(
            width: 42,
            height: 42,
            child: Icon(
              icon,
              size: 21,
              color:
                  colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// MAP LEGEND
// ============================================================================

class _MapLegend
    extends StatelessWidget {
  final bool hasDestination;

  const _MapLegend({
    this.hasDestination = false,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 10,
        vertical: 8,
      ),
      decoration: BoxDecoration(
        color: colors.surface.withValues(
          alpha: 0.94,
        ),
        borderRadius:
            BorderRadius.circular(12),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.08,
            ),
            blurRadius: 8,
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          // User / emergency
          _LegendItem(
            color: colors.error,
            label: 'You / Emergency',
          ),

          const SizedBox(height: 4),

          // Hospital
          _LegendItem(
            color: colors.primary,
            label: 'Hospital',
          ),

          const SizedBox(height: 4),

          // Blood bank
          _LegendItem(
            color: colors.error,
            label: 'Blood Bank',
          ),

          const SizedBox(height: 4),

          // Donor
          const _LegendItem(
            color: Colors.deepPurple,
            label: 'Donor',
          ),

          // Destination
          if (hasDestination) ...[
            const SizedBox(height: 4),
            const _LegendItem(
              color: Colors.green,
              label: 'Destination',
            ),
          ],
        ],
      ),
    );
  }
}

// ============================================================================
// LEGEND ITEM
// ============================================================================

class _LegendItem
    extends StatelessWidget {
  final Color color;

  final String label;

  const _LegendItem({
    required this.color,
    required this.label,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration:
              BoxDecoration(
            color: color,
            shape:
                BoxShape.circle,
          ),
        ),
        const SizedBox(width: 6),
        Text(
          label,
          style:
              const TextStyle(
            fontSize: 10,
            fontWeight:
                FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// NO LOCATION STATE
// ============================================================================

class _NoLocationState
    extends StatelessWidget {
  const _NoLocationState();

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(24),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 58,
              height: 58,
              decoration:
                  BoxDecoration(
                color:
                    colors.primaryContainer,
                shape:
                    BoxShape.circle,
              ),
              child: Icon(
                Icons.location_off_rounded,
                color:
                    colors.onPrimaryContainer,
                size: 27,
              ),
            ),
            const SizedBox(height: 13),
            Text(
              'Location unavailable',
              textAlign:
                  TextAlign.center,
              style:
                  Theme.of(context)
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                        fontWeight:
                            FontWeight.w800,
                      ),
            ),
            const SizedBox(height: 6),
            Text(
              'Current GPS or an active SOS location is required to display the map.',
              textAlign:
                  TextAlign.center,
              style:
                  Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color:
                            colors
                                .onSurfaceVariant,
                        height: 1.4,
                      ),
            ),
          ],
        ),
      ),
    );
  }
}