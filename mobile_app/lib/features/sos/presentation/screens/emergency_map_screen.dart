import 'package:flutter/material.dart';
import 'package:latlong2/latlong.dart';

import '../../data/models/emergency_sos_model.dart';
import '../../data/models/nearby_resource_model.dart';
import '../widgets/emergency_map.dart';

/// ============================================================================
/// FULL-SCREEN EMERGENCY MAP
/// ============================================================================
///
/// Thin orchestration layer around [EmergencyMap].
///
/// The reusable EmergencyMap widget owns:
/// - OpenStreetMap rendering
/// - User/SOS marker
/// - Hospital markers
/// - Blood-bank markers
/// - Donor markers
/// - Route rendering
/// - Map gestures
/// - Camera fitting
/// - Map controls
///
/// This screen does NOT:
/// - Query Supabase
/// - Query Google Places
/// - Own realtime subscriptions
/// - Manage SOS state
///
/// Real-time resources continue to come from the parent/provider.
/// ============================================================================

class EmergencyMapScreen extends StatefulWidget {
  // ==========================================================================
  // INITIAL / CURRENT LOCATION
  // ==========================================================================

  /// Latitude used when opening the map.
  final double latitude;

  /// Longitude used when opening the map.
  final double longitude;

  // ==========================================================================
  // OPTIONAL SOS
  // ==========================================================================

  final EmergencySosModel? sos;

  // ==========================================================================
  // REAL-TIME RESOURCES
  // ==========================================================================

  final List<NearbyResourceModel> resources;

  // ==========================================================================
  // RESOURCE CALLBACK
  // ==========================================================================

  final ValueChanged<NearbyResourceModel>? onResourceTap;

  // ==========================================================================
  // UI
  // ==========================================================================

  final double? mapHeight;

  final bool showMyLocationButton;

  const EmergencyMapScreen({
    super.key,
    required this.latitude,
    required this.longitude,
    this.sos,
    this.resources = const [],
    this.onResourceTap,
    this.mapHeight,
    this.showMyLocationButton = true,
  });

  @override
  State<EmergencyMapScreen> createState() =>
      _EmergencyMapScreenState();
}

class _EmergencyMapScreenState
    extends State<EmergencyMapScreen> {
  // ==========================================================================
  // BUILD
  // ==========================================================================

  @override
  Widget build(BuildContext context) {
    final currentLocation = LatLng(
      widget.latitude,
      widget.longitude,
    );

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Emergency Map',
        ),
        actions: [
          if (widget.resources.isNotEmpty)
            Padding(
              padding:
                  const EdgeInsets.only(
                right: 8,
              ),
              child: Center(
                child: Container(
                  padding:
                      const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration:
                      BoxDecoration(
                    color: Theme.of(context)
                        .colorScheme
                        .primaryContainer,
                    borderRadius:
                        BorderRadius.circular(
                      20,
                    ),
                  ),
                  child: Row(
                    mainAxisSize:
                        MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.location_on_rounded,
                        size: 16,
                        color: Theme.of(context)
                            .colorScheme
                            .onPrimaryContainer,
                      ),
                      const SizedBox(
                        width: 4,
                      ),
                      Text(
                        '${widget.resources.length}',
                        style: TextStyle(
                          fontWeight:
                              FontWeight.w800,
                          color: Theme.of(context)
                              .colorScheme
                              .onPrimaryContainer,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
        ],
      ),

      // ========================================================================
      // MAP
      // ========================================================================

      body: SafeArea(
        child: _buildMap(
          currentLocation,
        ),
      ),
    );
  }

  // ==========================================================================
  // BUILD MAP
  // ==========================================================================

  Widget _buildMap(
    LatLng currentLocation,
  ) {
    return SizedBox(
      width: double.infinity,
      height: widget.mapHeight,
      child: EmergencyMap(
        // ----------------------------------------------------------------------
        // ACTIVE SOS
        // ----------------------------------------------------------------------

        sos: widget.sos,

        // ----------------------------------------------------------------------
        // CURRENT DEVICE LOCATION
        // ----------------------------------------------------------------------

        currentLocation:
            currentLocation,

        // ----------------------------------------------------------------------
        // REAL-TIME RESOURCES
        // ----------------------------------------------------------------------

        resources:
            widget.resources,

        // ----------------------------------------------------------------------
        // MAP HEIGHT
        // ----------------------------------------------------------------------

        height:
            widget.mapHeight,

        // ----------------------------------------------------------------------
        // LOCATION BUTTON
        // ----------------------------------------------------------------------

        showMyLocationButton:
            widget.showMyLocationButton,

        // ----------------------------------------------------------------------
        // RESOURCE SELECTION
        // ----------------------------------------------------------------------

        onResourceTap:
            widget.onResourceTap,
      ),
    );
  }
}