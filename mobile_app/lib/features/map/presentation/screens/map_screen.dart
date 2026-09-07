import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:provider/provider.dart';

import '../../data/models/map_place_model.dart';
import '../../data/models/route_model.dart';
import '../providers/map_provider.dart';

/// Full-screen LifeLynk Map.
///
/// Uses:
/// - flutter_map
/// - OpenStreetMap tiles
/// - real OSM/Overpass/Nominatim place data
/// - real OSRM road routing
/// - real device GPS
///
/// Features:
/// - Google-Maps-like A → B route preview
/// - Current location as Point A
/// - Long press to choose Point A
/// - Healthcare place as Point B
/// - Route distance
/// - ETA
/// - Route camera fitting
/// - Swap A/B
/// - Clear route
///
/// Google Maps is NOT used.
class MapScreen extends StatefulWidget {
  const MapScreen({
    super.key,
  });

  @override
  State<MapScreen> createState() =>
      _MapScreenState();
}

class _MapScreenState
    extends State<MapScreen> {
  // ============================================================
  // MAP
  // ============================================================

  final MapController _mapController =
      MapController();

  bool _mapReady = false;

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance
        .addPostFrameCallback(
      (_) {
        if (!mounted) {
          return;
        }

        context
            .read<MapProvider>()
            .initialize();
      },
    );
  }

  // ============================================================
  // SEARCH
  // ============================================================

  Future<void> _search(
    String query,
  ) async {
    await context
        .read<MapProvider>()
        .searchPlaces(query);
  }

  // ============================================================
  // CATEGORY
  // ============================================================

  Future<void> _selectCategory(
    String category,
  ) async {
    await context
        .read<MapProvider>()
        .searchByCategory(
          category,
        );
  }

  // ============================================================
  // PLACE TAP
  // ============================================================

  Future<void> _onPlaceTap(
    MapPlaceModel place,
  ) async {
    final provider =
        context.read<MapProvider>();

    await provider.selectPlace(
      place,
    );

    _moveMapTo(
      place.location,
      zoom: 16,
    );

    if (place.hasPlaceId) {
      await provider.loadPlaceDetails(
        place.placeId!,
      );
    }

    if (!mounted) {
      return;
    }

    final selected =
        provider.selectedPlace ??
        place;

    _showPlaceBottomSheet(
      context,
      selected,
    );
  }

  // ============================================================
  // LONG PRESS
  // ============================================================

  Future<void> _onMapLongPress(
    LatLng location,
  ) async {
    final provider =
        context.read<MapProvider>();

    provider.setRouteOrigin(
      location,
    );

    _moveMapTo(
      location,
      zoom: 16,
    );

    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(
      context,
    ).showSnackBar(
      const SnackBar(
        content: Text(
          'Point A selected. Tap a healthcare location for Point B.',
        ),
        duration:
            Duration(seconds: 2),
      ),
    );
  }

  // ============================================================
  // PLACE BOTTOM SHEET
  // ============================================================

  void _showPlaceBottomSheet(
    BuildContext context,
    MapPlaceModel place,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (context) {
        return _PlaceBottomSheet(
          place: place,
          onDirections: () async {
            Navigator.of(
              context,
            ).pop();

            await _calculateRoute(
              place,
            );
          },
        );
      },
    );
  }

  // ============================================================
  // ROUTE
  // ============================================================

  Future<void> _calculateRoute(
    MapPlaceModel place,
  ) async {
    final provider =
        context.read<MapProvider>();

    final result =
        await provider.calculateRoute(
      place,
    );

    if (!mounted) {
      return;
    }

    if (result == null) {
      return;
    }

    _fitRoute(
      result,
    );

    _showRouteBottomSheet(
      result,
    );
  }

  // ============================================================
  // MANUAL DESTINATION
  // ============================================================

  Future<void> _setDestinationFromMap(
    LatLng location,
  ) async {
    final provider =
        context.read<MapProvider>();

    if (provider.routeOrigin == null) {
      provider.setRouteOrigin(
        provider.currentLocation ??
            location,
      );
    }

    provider.setRouteDestination(
      location,
    );

    final result =
        await provider.calculateRouteBetween(
      location,
    );

    if (!mounted) {
      return;
    }

    if (result == null) {
      return;
    }

    _fitRoute(
      result,
    );

    _showRouteBottomSheet(
      result,
    );
  }

  // ============================================================
  // ROUTE BOTTOM SHEET
  // ============================================================
  void _showRouteBottomSheet(
  RouteModel route,
) {
  showModalBottomSheet<void>(
    context: context,
    showDragHandle: true,
    isScrollControlled: true,
    builder: (sheetContext) {
      return _RouteBottomSheet(
        route: route,
        onClose: () {
          Navigator.of(sheetContext).pop();
        },
        onSwap: () async {
          Navigator.of(sheetContext).pop();

          final provider = context.read<MapProvider>();

          final swapped = await provider.swapRoute();

          if (!mounted || swapped == null) {
            return;
          }

          _fitRoute(swapped);

          _showRouteBottomSheet(swapped);
        },
      );
    },
  );
}
  
  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    final provider =
        context.read<MapProvider>();

    await provider.loadCurrentLocation();

    if (!mounted) {
      return;
    }

    final location =
        provider.currentLocation;

    if (location != null) {
      _moveMapTo(
        location,
        zoom: 14,
      );

      await provider.searchByCategory(
        provider.selectedCategory,
      );
    }
  }

  // ============================================================
  // MY LOCATION
  // ============================================================

  Future<void>
      _moveToCurrentLocation() async {
    final provider =
        context.read<MapProvider>();

    await provider
        .useCurrentLocationAsOrigin();

    if (!mounted) {
      return;
    }

    final location =
        provider.currentLocation;

    if (location != null) {
      _moveMapTo(
        location,
        zoom: 15,
      );
    }
  }

  // ============================================================
  // CLEAR ROUTE
  // ============================================================

  void _clearRoute() {
    context
        .read<MapProvider>()
        .clearRoute();
  }

  // ============================================================
  // CAMERA
  // ============================================================

  void _moveMapTo(
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

    final validPoints =
        points.where(
      _isValidCoordinate,
    ).toList();

    if (validPoints.isEmpty) {
      return;
    }

    if (validPoints.length == 1) {
      _moveMapTo(
        validPoints.first,
        zoom: 15,
      );
      return;
    }

    try {
      _mapController.fitCamera(
        CameraFit.coordinates(
          coordinates:
              validPoints,
          padding:
              const EdgeInsets.fromLTRB(
            60,
            150,
            60,
            230,
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
    return Consumer<MapProvider>(
      builder: (
        context,
        provider,
        child,
      ) {
        return Scaffold(
          backgroundColor:
              Theme.of(context)
                  .colorScheme
                  .surface,
          appBar:
              _buildAppBar(
            context,
            provider,
          ),
          body: SafeArea(
            child: _buildBody(
              context,
              provider,
            ),
          ),
        );
      },
    );
  }

  // ============================================================
  // APP BAR
  // ============================================================

  PreferredSizeWidget
      _buildAppBar(
    BuildContext context,
    MapProvider provider,
  ) {
    return AppBar(
      title: const Text(
        'LifeLynk Map',
      ),
      centerTitle: false,
      actions: [
        if (provider.hasRoute)
          IconButton(
            tooltip:
                'Clear route',
            onPressed:
                _clearRoute,
            icon:
                const Icon(
              Icons
                  .close_rounded,
            ),
          ),
        IconButton(
          tooltip: 'Refresh',
          onPressed:
              provider.locationLoading ||
                      provider.searchLoading
                  ? null
                  : _refresh,
          icon:
              const Icon(
            Icons.refresh_rounded,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody(
    BuildContext context,
    MapProvider provider,
  ) {
    if (provider.locationLoading &&
        provider.currentLocation ==
            null) {
      return const _MapLoadingState();
    }

    if (provider.hasError &&
        provider.currentLocation ==
            null) {
      return _MapErrorState(
        message:
            provider.error!,
        onRetry:
            _refresh,
      );
    }

    return Stack(
      children: [
        Positioned.fill(
          child:
              _buildOpenStreetMap(
            context,
            provider,
          ),
        ),

        Positioned(
          top: 12,
          left: 16,
          right: 16,
          child:
              _MapSearchBar(
            initialValue:
                provider.searchQuery,
            loading:
                provider.searchLoading,
            onSubmitted:
                _search,
          ),
        ),

        Positioned(
          top: 76,
          left: 0,
          right: 0,
          child:
              _CategorySelector(
            selectedCategory:
                provider.selectedCategory,
            onCategorySelected:
                _selectCategory,
          ),
        ),

        // A/B status bar.
        if (provider.routeOrigin !=
                null &&
            provider.routeDestination ==
                null)
          Positioned(
            left: 16,
            right: 16,
            top: 130,
            child:
                _RoutePointHint(
              text:
                  'Point A selected — tap a place for Point B',
            ),
          ),

        Positioned(
          right: 16,
          bottom:
              provider.route != null
                  ? 190
                  : 110,
          child:
              FloatingActionButton.small(
            heroTag:
                'map_location_button',
            onPressed:
                provider.locationLoading
                    ? null
                    : _moveToCurrentLocation,
            tooltip:
                'Use my location as Point A',
            child:
                const Icon(
              Icons
                  .my_location_rounded,
            ),
          ),
        ),

        if (provider.hasError)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child:
                _MapErrorBanner(
              message:
                  provider.error!,
              onRetry:
                  _refresh,
            ),
          ),

        if (provider.route != null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child:
                _RouteInfoCard(
              route:
                  provider.route!,
              loading:
                  provider.routeLoading,
              onClear:
                  _clearRoute,
              onSwap:
                  () async {
                final swapped =
                    await provider
                        .swapRoute();

                if (!mounted ||
                    swapped == null) {
                  return;
                }

                _fitRoute(
                  swapped,
                );
              },
            ),
          ),

        if (provider.route == null &&
            provider.currentLocation !=
                null)
          Positioned(
            left: 16,
            right: 16,
            bottom: 16,
            child:
                _PlaceSummary(
              count:
                  provider.places.length,
              loading:
                  provider.searchLoading,
            ),
          ),
      ],
    );
  }

  // ============================================================
  // MAP
  // ============================================================

  Widget _buildOpenStreetMap(
    BuildContext context,
    MapProvider provider,
  ) {
    final location =
        provider.currentLocation;

    final center =
        location ??
            const LatLng(
              31.5204,
              74.3587,
            );

    final route =
        provider.route;

    final routeOrigin =
        provider.routeOrigin;

    final routeDestination =
        provider.routeDestination;

    final markers =
        <Marker>[
      // Current GPS marker.
      if (location != null)
        Marker(
          point: location,
          width: 48,
          height: 48,
          alignment:
              Alignment.center,
          child:
              const _CurrentLocationMarker(),
        ),

      // Route Point A.
      if (routeOrigin != null &&
          _isValidCoordinate(
            routeOrigin,
          ) &&
          (location == null ||
              !_sameCoordinate(
                routeOrigin,
                location,
              )))
        Marker(
          point:
              routeOrigin,
          width: 54,
          height: 64,
          alignment:
              Alignment.bottomCenter,
          child:
              const _RoutePointMarker(
            label: 'A',
          ),
        ),

      // Route Point B.
      if (routeDestination != null &&
          _isValidCoordinate(
            routeDestination,
          ))
        Marker(
          point:
              routeDestination,
          width: 54,
          height: 64,
          alignment:
              Alignment.bottomCenter,
          child:
              const _RoutePointMarker(
            label: 'B',
          ),
        ),

      ...provider.places
          .where(
        (place) =>
            place.hasValidLocation,
      )
          .map(
        (place) {
          final selected =
              provider.selectedPlace
                      ?.id ==
                  place.id;

          return Marker(
            point:
                place.location,
            width:
                selected
                    ? 58
                    : 50,
            height:
                selected
                    ? 70
                    : 62,
            alignment:
                Alignment.bottomCenter,
            child:
                GestureDetector(
              onTap: () {
                _onPlaceTap(
                  place,
                );
              },
              child:
                  _PlaceMarker(
                place:
                    place,
                selected:
                    selected,
              ),
            ),
          );
        },
      ),

      if (provider.selectedPlace !=
                  null &&
              provider.selectedPlace!
                  .hasValidLocation &&
          !provider.places.any(
            (place) =>
                place.id ==
                provider
                    .selectedPlace!
                    .id,
          ))
        Marker(
          point: provider
              .selectedPlace!
              .location,
          width: 58,
          height: 70,
          alignment:
              Alignment.bottomCenter,
          child:
              GestureDetector(
            onTap: () {
              _onPlaceTap(
                provider.selectedPlace!,
              );
            },
            child:
                _PlaceMarker(
              place:
                  provider.selectedPlace!,
              selected:
                  true,
            ),
          ),
        ),
    ];

    final routePoints =
        route != null &&
                route.hasPolyline
            ? route.polylinePoints
            : <LatLng>[];

    return FlutterMap(
      mapController:
          _mapController,
      options:
          MapOptions(
        initialCenter:
            center,
        initialZoom:
            location != null
                ? 14
                : 11,
        interactionOptions:
            const InteractionOptions(
          flags:
              InteractiveFlag.all,
        ),

        onMapReady: () {
          _mapReady = true;

          final latest =
              provider.currentLocation;

          if (latest != null) {
            _moveMapTo(
              latest,
              zoom: 14,
            );
          }
        },

        // Single tap clears selection.
        onTap: (
  _,
  location,
) {
  if (provider.routeOrigin != null) {
    _setDestinationFromMap(location);
    return;
  }

  provider.clearSelection();
},

        // Long press selects a manual
        // Point A.
        onLongPress: (
          _,
          location,
        ) async {
          await _onMapLongPress(
            location,
          );
        },
      ),
      children: [
        // ========================================================
        // OSM TILES
        // ========================================================

        TileLayer(
          urlTemplate:
              'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
          userAgentPackageName:
              'com.lifelynk.ai',
          maxZoom: 19,
        ),

        // ========================================================
        // ROUTE
        // ========================================================

        if (routePoints.isNotEmpty)
          PolylineLayer(
            polylines: [
              Polyline(
                points:
                    routePoints,
                strokeWidth:
                    8,
                color:
                    Theme.of(context)
                        .colorScheme
                        .surface,
              ),
              Polyline(
                points:
                    routePoints,
                strokeWidth:
                    5,
                color:
                    Theme.of(context)
                        .colorScheme
                        .primary,
              ),
            ],
          ),

        // ========================================================
        // MARKERS
        // ========================================================

        MarkerLayer(
          markers:
              markers,
        ),

        // ========================================================
        // ATTRIBUTION
        // ========================================================

        RichAttributionWidget(
          attributions: [
            TextSourceAttribution(
              'OpenStreetMap contributors',
              onTap: () {},
            ),
          ],
        ),
      ],
    );
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
}

// ============================================================================
// ROUTE POINT MARKER
// ============================================================================

class _RoutePointMarker
    extends StatelessWidget {
  final String label;

  const _RoutePointMarker({
    required this.label,
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
          width: 40,
          height: 40,
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
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black
                        .withValues(
                  alpha: 0.25,
                ),
                blurRadius: 7,
                offset:
                    const Offset(
                  0,
                  3,
                ),
              ),
            ],
          ),
          alignment:
              Alignment.center,
          child: Text(
            label,
            style:
                TextStyle(
              color:
                  colors.onPrimary,
              fontWeight:
                  FontWeight.w900,
              fontSize: 17,
            ),
          ),
        ),
        CustomPaint(
          size:
              const Size(
            14,
            8,
          ),
          painter:
              _MarkerTailPainter(
            color:
                colors.primary,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// CURRENT LOCATION MARKER
// ============================================================================

class _CurrentLocationMarker
    extends StatelessWidget {
  const _CurrentLocationMarker();

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Stack(
      alignment:
          Alignment.center,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration:
              BoxDecoration(
            shape:
                BoxShape.circle,
            color:
                colors.primary
                    .withValues(
              alpha: 0.20,
            ),
          ),
        ),
        Container(
          width: 20,
          height: 20,
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
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// PLACE MARKER
// ============================================================================

class _PlaceMarker
    extends StatelessWidget {
  final MapPlaceModel place;
  final bool selected;

  const _PlaceMarker({
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

    final color =
        colors.primary;

    return Column(
      mainAxisSize:
          MainAxisSize.min,
      children: [
        Container(
          width:
              selected
                  ? 44
                  : 38,
          height:
              selected
                  ? 44
                  : 38,
          decoration:
              BoxDecoration(
            color:
                color,
            shape:
                BoxShape.circle,
            border:
                Border.all(
              color:
                  colors.surface,
              width: 3,
            ),
            boxShadow: [
              BoxShadow(
                color:
                    Colors.black
                        .withValues(
                  alpha: 0.20,
                ),
                blurRadius: 6,
                offset:
                    const Offset(
                  0,
                  2,
                ),
              ),
            ],
          ),
          child:
              Icon(
            _categoryIcon(
              place.category,
            ),
            color:
                colors.onPrimary,
            size:
                selected
                    ? 23
                    : 20,
          ),
        ),
        CustomPaint(
          size:
              const Size(
            14,
            8,
          ),
          painter:
              _MarkerTailPainter(
            color:
                color,
          ),
        ),
      ],
    );
  }

  IconData _categoryIcon(
    String? category,
  ) {
    switch (
        category?.toLowerCase()) {
      case 'hospital':
        return Icons
            .local_hospital_rounded;

      case 'blood_bank':
      case 'blood bank':
        return Icons
            .bloodtype_rounded;

      case 'pharmacy':
        return Icons
            .local_pharmacy_rounded;

      case 'clinic':
        return Icons
            .medical_services_rounded;

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

class _MarkerTailPainter
    extends CustomPainter {
  final Color color;

  const _MarkerTailPainter({
    required this.color,
  });

  @override
  void paint(
    Canvas canvas,
    Size size,
  ) {
    final path =
        ui.Path()
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
    covariant _MarkerTailPainter oldDelegate,
  ) {
    return oldDelegate.color !=
        color;
  }
}

// ============================================================================
// ROUTE POINT HINT
// ============================================================================

class _RoutePointHint
    extends StatelessWidget {
  final String text;

  const _RoutePointHint({
    required this.text,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Material(
      elevation: 4,
      borderRadius:
          BorderRadius.circular(14),
      color:
          colors.surface
              .withValues(
        alpha: 0.96,
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 14,
          vertical: 10,
        ),
        child: Row(
          children: [
            Icon(
              Icons
                  .touch_app_rounded,
              size: 19,
              color:
                  colors.primary,
            ),
            const SizedBox(
              width: 8,
            ),
            Expanded(
              child: Text(
                text,
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
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// SEARCH BAR
// ============================================================================

class _MapSearchBar
    extends StatefulWidget {
  final String initialValue;
  final bool loading;
  final ValueChanged<String>
      onSubmitted;

  const _MapSearchBar({
    required this.initialValue,
    required this.loading,
    required this.onSubmitted,
  });

  @override
  State<_MapSearchBar>
      createState() =>
          _MapSearchBarState();
}

class _MapSearchBarState
    extends State<_MapSearchBar> {
  late final TextEditingController
      _controller;

  @override
  void initState() {
    super.initState();

    _controller =
        TextEditingController(
      text:
          widget.initialValue,
    );
  }

  @override
  void didUpdateWidget(
    covariant _MapSearchBar
        oldWidget,
  ) {
    super.didUpdateWidget(
      oldWidget,
    );

    if (widget.initialValue !=
            _controller.text &&
        widget.initialValue.isEmpty) {
      _controller.clear();
    }
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Material(
      elevation: 5,
      borderRadius:
          BorderRadius.circular(16),
      color:
          colors.surface,
      child: TextField(
        controller:
            _controller,
        textInputAction:
            TextInputAction.search,
        onSubmitted:
            widget.onSubmitted,
        decoration:
            InputDecoration(
          hintText:
              'Search hospitals, blood banks, pharmacies...',
          prefixIcon:
              const Icon(
            Icons
                .search_rounded,
          ),
          suffixIcon:
              widget.loading
                  ? const Padding(
                      padding:
                          EdgeInsets.all(
                        14,
                      ),
                      child:
                          SizedBox(
                        width: 18,
                        height: 18,
                        child:
                            CircularProgressIndicator(
                          strokeWidth:
                              2,
                        ),
                      ),
                    )
                  : _controller
                          .text
                          .isNotEmpty
                      ? IconButton(
                          onPressed:
                              () {
                            _controller
                                .clear();

                            widget
                                .onSubmitted(
                              '',
                            );

                            setState(
                              () {},
                            );
                          },
                          icon:
                              const Icon(
                            Icons
                                .close_rounded,
                          ),
                        )
                      : null,
          filled: true,
          fillColor:
              colors.surface,
          border:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            borderSide:
                BorderSide.none,
          ),
          enabledBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            borderSide:
                BorderSide.none,
          ),
          focusedBorder:
              OutlineInputBorder(
            borderRadius:
                BorderRadius.circular(
              16,
            ),
            borderSide:
                BorderSide(
              color:
                  colors.primary,
              width: 1.5,
            ),
          ),
        ),
        onChanged: (_) {
          setState(() {});
        },
      ),
    );
  }
}

// ============================================================================
// CATEGORY SELECTOR
// ============================================================================

class _CategorySelector
    extends StatelessWidget {
  final String selectedCategory;

  final ValueChanged<String>
      onCategorySelected;

  const _CategorySelector({
    required this.selectedCategory,
    required this.onCategorySelected,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final categories = [
      const _CategoryItem(
        value:
            'hospital',
        label:
            'Hospitals',
        icon:
            Icons
                .local_hospital_rounded,
      ),
      const _CategoryItem(
        value:
            'blood_bank',
        label:
            'Blood Banks',
        icon:
            Icons
                .bloodtype_rounded,
      ),
      const _CategoryItem(
        value:
            'pharmacy',
        label:
            'Pharmacies',
        icon:
            Icons
                .local_pharmacy_rounded,
      ),
      const _CategoryItem(
        value:
            'emergency',
        label:
            'Emergency',
        icon:
            Icons
                .emergency_rounded,
      ),
    ];

    return SizedBox(
      height: 48,
      child:
          ListView.separated(
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
          final category =
              categories[
                  index];

          final selected =
              selectedCategory
                      .toLowerCase() ==
                  category.value;

          return FilterChip(
            selected:
                selected,
            onSelected:
                (_) {
              onCategorySelected(
                category.value,
              );
            },
            avatar:
                Icon(
              category.icon,
              size: 18,
            ),
            label:
                Text(
              category.label,
            ),
            showCheckmark:
                false,
          );
        },
      ),
    );
  }
}

class _CategoryItem {
  final String value;
  final String label;
  final IconData icon;

  const _CategoryItem({
    required this.value,
    required this.label,
    required this.icon,
  });
}

// ============================================================================
// PLACE SUMMARY
// ============================================================================

class _PlaceSummary
    extends StatelessWidget {
  final int count;
  final bool loading;

  const _PlaceSummary({
    required this.count,
    required this.loading,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Material(
      elevation: 5,
      borderRadius:
          BorderRadius.circular(16),
      color:
          colors.surface
              .withValues(
        alpha: 0.96,
      ),
      child: Padding(
        padding:
            const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 13,
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration:
                  BoxDecoration(
                color:
                    colors.primaryContainer,
                borderRadius:
                    BorderRadius.circular(
                  12,
                ),
              ),
              child: Icon(
                Icons
                    .medical_services_rounded,
                color:
                    colors.primary,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    count == 0
                        ? 'No places found'
                        : '$count places nearby',
                    style:
                        Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),
                  const SizedBox(
                    height: 3,
                  ),
                  Text(
                    'Long press the map to choose Point A',
                    style:
                        Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                      color:
                          colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (loading)
              const SizedBox(
                width: 18,
                height: 18,
                child:
                    CircularProgressIndicator(
                  strokeWidth: 2,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// PLACE BOTTOM SHEET
// ============================================================================

class _PlaceBottomSheet
    extends StatelessWidget {
  final MapPlaceModel place;
  final VoidCallback onDirections;

  const _PlaceBottomSheet({
    required this.place,
    required this.onDirections,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration:
                      BoxDecoration(
                    color:
                        colors.primaryContainer,
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Icon(
                    _categoryIcon(
                      place.category,
                    ),
                    color:
                        colors.primary,
                    size: 27,
                  ),
                ),
                const SizedBox(
                  width: 13,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        place.name,
                        maxLines: 2,
                        overflow:
                            TextOverflow
                                .ellipsis,
                        style:
                            Theme.of(
                          context,
                        )
                                .textTheme
                                .titleMedium
                                ?.copyWith(
                          fontWeight:
                              FontWeight
                                  .w800,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        place.categoryLabel,
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
              ],
            ),
            const SizedBox(
              height: 18,
            ),
            if (place.hasOpenStatus)
              _PlaceInfoRow(
                icon:
                    place.isOpen == true
                        ? Icons
                            .check_circle_rounded
                        : Icons
                            .cancel_rounded,
                label:
                    'Status',
                value:
                    place.openStatusLabel,
              ),
            if (place.hasAddress)
              _PlaceInfoRow(
                icon:
                    Icons
                        .location_on_rounded,
                label:
                    'Address',
                value:
                    place.address!,
              ),
            if (place.hasPhone)
              _PlaceInfoRow(
                icon:
                    Icons.phone_rounded,
                label:
                    'Phone',
                value:
                    place.phone!,
              ),
            const SizedBox(
              height: 14,
            ),
            SizedBox(
              width:
                  double.infinity,
              child:
                  FilledButton.icon(
                onPressed:
                    onDirections,
                icon:
                    const Icon(
                  Icons
                      .directions_rounded,
                ),
                label:
                    const Text(
                  'Get Directions',
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  IconData _categoryIcon(
    String? category,
  ) {
    switch (
        category?.toLowerCase()) {
      case 'hospital':
        return Icons
            .local_hospital_rounded;

      case 'blood_bank':
      case 'blood bank':
        return Icons
            .bloodtype_rounded;

      case 'pharmacy':
        return Icons
            .local_pharmacy_rounded;

      case 'clinic':
        return Icons
            .medical_services_rounded;

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
// PLACE INFO
// ============================================================================

class _PlaceInfoRow
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _PlaceInfoRow({
    required this.icon,
    required this.label,
    required this.value,
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
          const EdgeInsets.symmetric(
        vertical: 6,
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
            width: 12,
          ),
          SizedBox(
            width: 75,
            child: Text(
              label,
              style:
                  Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                color:
                    colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              value,
              textAlign:
                  TextAlign.end,
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
        ],
      ),
    );
  }
}

// ============================================================================
// ROUTE INFO CARD
// ============================================================================

class _RouteInfoCard
    extends StatelessWidget {
  final RouteModel route;
  final bool loading;
  final VoidCallback onClear;
  final VoidCallback onSwap;

  const _RouteInfoCard({
    required this.route,
    required this.loading,
    required this.onClear,
    required this.onSwap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Material(
      elevation: 7,
      borderRadius:
          BorderRadius.circular(18),
      color:
          colors.surface,
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          16,
          14,
          8,
          14,
        ),
        child: Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration:
                  BoxDecoration(
                color:
                    colors.primaryContainer,
                borderRadius:
                    BorderRadius.circular(
                  13,
                ),
              ),
              child: Icon(
                Icons
                    .directions_car_rounded,
                color:
                    colors.primary,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Text(
                    '${route.durationLabel} • ${route.distanceLabel}',
                    style:
                        Theme.of(context)
                            .textTheme
                            .titleSmall
                            ?.copyWith(
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                  const SizedBox(
                    height: 4,
                  ),
                  Text(
                    route.travelModeLabel,
                    style:
                        Theme.of(context)
                            .textTheme
                            .bodySmall
                            ?.copyWith(
                      color:
                          colors.onSurfaceVariant,
                    ),
                  ),
                ],
              ),
            ),
            if (loading)
              const Padding(
                padding:
                    EdgeInsets.only(
                  right: 4,
                ),
                child:
                    SizedBox(
                  width: 20,
                  height: 20,
                  child:
                      CircularProgressIndicator(
                    strokeWidth: 2,
                  ),
                ),
              ),
            IconButton(
              tooltip:
                  'Swap A and B',
              onPressed:
                  loading
                      ? null
                      : onSwap,
              icon:
                  const Icon(
                Icons
                    .swap_vert_rounded,
              ),
            ),
            IconButton(
              tooltip:
                  'Clear route',
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

// ============================================================================
// ROUTE BOTTOM SHEET
// ============================================================================

class _RouteBottomSheet
    extends StatelessWidget {
  final RouteModel route;
  final VoidCallback onClose;
  final VoidCallback onSwap;

  const _RouteBottomSheet({
    required this.route,
    required this.onClose,
    required this.onSwap,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return SafeArea(
      child: Padding(
        padding:
            const EdgeInsets.fromLTRB(
          20,
          4,
          20,
          24,
        ),
        child: Column(
          mainAxisSize:
              MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 52,
                  height: 52,
                  decoration:
                      BoxDecoration(
                    color:
                        colors.primaryContainer,
                    borderRadius:
                        BorderRadius.circular(
                      14,
                    ),
                  ),
                  child: Icon(
                    Icons
                        .directions_rounded,
                    color:
                        colors.primary,
                    size: 28,
                  ),
                ),
                const SizedBox(
                  width: 13,
                ),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Route Preview',
                        style:
                            Theme.of(context)
                                .textTheme
                                .titleLarge
                                ?.copyWith(
                          fontWeight:
                              FontWeight.w900,
                        ),
                      ),
                      const SizedBox(
                        height: 3,
                      ),
                      Text(
                        route.travelModeLabel,
                        style:
                            Theme.of(context)
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                          color:
                              colors.onSurfaceVariant,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(
              height: 20,
            ),
            _RouteDetailRow(
              icon:
                  Icons
                      .straighten_rounded,
              label:
                  'Distance',
              value:
                  route.distanceLabel,
            ),
            _RouteDetailRow(
              icon:
                  Icons
                      .access_time_rounded,
              label:
                  'Travel time',
              value:
                  route.durationLabel,
            ),
            if (route.hasSummary)
              _RouteDetailRow(
                icon:
                    Icons.route_rounded,
                label:
                    'Road',
                value:
                    route.summary!,
              ),
            if (route.hasWarning)
              _RouteDetailRow(
                icon:
                    Icons.warning_rounded,
                label:
                    'Warning',
                value:
                    route.warning!,
              ),
            const SizedBox(
              height: 14,
            ),
            Row(
              children: [
                Expanded(
                  child:
                      OutlinedButton.icon(
                    onPressed:
                        onSwap,
                    icon:
                        const Icon(
                      Icons
                          .swap_vert_rounded,
                    ),
                    label:
                        const Text(
                      'Swap',
                    ),
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child:
                      FilledButton(
                    onPressed:
                        onClose,
                    child:
                        const Text(
                      'Done',
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ROUTE DETAIL
// ============================================================================

class _RouteDetailRow
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _RouteDetailRow({
    required this.icon,
    required this.label,
    required this.value,
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
          const EdgeInsets.symmetric(
        vertical: 7,
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            icon,
            size: 20,
            color:
                colors.primary,
          ),
          const SizedBox(
            width: 12,
          ),
          SizedBox(
            width: 90,
            child: Text(
              label,
              style:
                  Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                color:
                    colors.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Text(
              value,
              textAlign:
                  TextAlign.end,
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
        ],
      ),
    );
  }
}

// ============================================================================
// LOADING STATE
// ============================================================================

class _MapLoadingState
    extends StatelessWidget {
  const _MapLoadingState();

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Center(
      child: Padding(
        padding:
            const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 70,
              height: 70,
              decoration:
                  BoxDecoration(
                color:
                    colors.primaryContainer,
                shape:
                    BoxShape.circle,
              ),
              child: Padding(
                padding:
                    const EdgeInsets.all(
                  20,
                ),
                child:
                    CircularProgressIndicator(
                  strokeWidth: 3,
                  color:
                      colors.primary,
                ),
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Text(
              'Finding your location',
              style:
                  Theme.of(context)
                      .textTheme
                      .titleMedium
                      ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 8,
            ),
            Text(
              'Getting your GPS location and finding nearby healthcare facilities.',
              textAlign:
                  TextAlign.center,
              style:
                  Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                color:
                    colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// ERROR STATE
// ============================================================================

class _MapErrorState
    extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _MapErrorState({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    final lowerMessage =
        message.toLowerCase();

    final isLocationError =
        lowerMessage.contains(
              'location',
            ) ||
        lowerMessage.contains(
          'gps',
        );

    return Center(
      child:
          SingleChildScrollView(
        padding:
            const EdgeInsets.all(
          28,
        ),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 76,
              height: 76,
              decoration:
                  BoxDecoration(
                color:
                    colors.errorContainer,
                shape:
                    BoxShape.circle,
              ),
              child: Icon(
                isLocationError
                    ? Icons
                        .location_off_rounded
                    : Icons
                        .map_rounded,
                size: 36,
                color:
                    colors.onErrorContainer,
              ),
            ),
            const SizedBox(
              height: 20,
            ),
            Text(
              isLocationError
                  ? 'Location Unavailable'
                  : 'Unable to Load Map',
              textAlign:
                  TextAlign.center,
              style:
                  Theme.of(context)
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                fontWeight:
                    FontWeight.w800,
              ),
            ),
            const SizedBox(
              height: 10,
            ),
            Text(
              message,
              textAlign:
                  TextAlign.center,
              style:
                  Theme.of(context)
                      .textTheme
                      .bodyMedium
                      ?.copyWith(
                color:
                    colors.onSurfaceVariant,
                height: 1.5,
              ),
            ),
            const SizedBox(
              height: 24,
            ),
            SizedBox(
              width:
                  double.infinity,
              child:
                  FilledButton.icon(
                onPressed:
                    onRetry,
                icon:
                    const Icon(
                  Icons
                      .refresh_rounded,
                ),
                label:
                    const Text(
                  'Try Again',
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
// ERROR BANNER
// ============================================================================

class _MapErrorBanner
    extends StatelessWidget {
  final String message;
  final VoidCallback onRetry;

  const _MapErrorBanner({
    required this.message,
    required this.onRetry,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context)
            .colorScheme;

    return Material(
      elevation: 5,
      borderRadius:
          BorderRadius.circular(14),
      color:
          colors.errorContainer,
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
              color:
                  colors.onErrorContainer,
              size: 20,
            ),
            const SizedBox(
              width: 10,
            ),
            Expanded(
              child: Text(
                message,
                maxLines: 2,
                overflow:
                    TextOverflow.ellipsis,
                style: TextStyle(
                  color:
                      colors.onErrorContainer,
                  fontSize: 12,
                  fontWeight:
                      FontWeight.w600,
                ),
              ),
            ),
            TextButton(
              onPressed:
                  onRetry,
              child:
                  const Text(
                'Retry',
              ),
            ),
          ],
        ),
      ),
    );
  }
}