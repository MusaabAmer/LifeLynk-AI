import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:geolocator/geolocator.dart';

import '../../data/models/emergency_sos_model.dart';
import '../../data/models/nearby_resource_model.dart';

import '../../services/emergency_location_service.dart';
import '../../services/emergency_navigation_service.dart';

import '../providers/sos_provider.dart';

import '../widgets/emergency_map.dart';
import '../widgets/emergency_resource_list.dart';
import '../widgets/sos_history_card.dart';

class SosScreen extends StatefulWidget {
  const SosScreen({
    super.key,
  });

  @override
  State<SosScreen> createState() => _SosScreenState();
}

class _SosScreenState extends State<SosScreen> {
  // ============================================================
  // SERVICES
  // ============================================================

  final EmergencyLocationService _locationService =
      EmergencyLocationService();

  // ============================================================
  // INIT
  // ============================================================

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) {
        return;
      }

      context.read<SosProvider>().loadSosData();
    });
  }

  // ============================================================
  // ACTIVATE SOS
  // ============================================================

  Future<void> _activateSos() async {
    final confirmed = await _showActivateConfirmation();

    if (!confirmed || !mounted) {
      return;
    }

    final locationReady = await _ensureLocationReady();

    if (!locationReady || !mounted) {
      return;
    }

    final provider = context.read<SosProvider>();

    final success = await provider.activateSos();

    if (!mounted) {
      return;
    }

    if (success) {
      _showSnackBar(
        'Emergency SOS activated successfully.',
      );
    } else if (provider.error != null) {
      _showError(
        provider.error!,
      );
    }
  }

  // ============================================================
  // ENSURE LOCATION READY
  // ============================================================

  Future<bool> _ensureLocationReady() async {
    final serviceEnabled =
        await _locationService.isLocationServiceEnabled();

    if (!serviceEnabled) {
      if (!mounted) {
        return false;
      }

      return _showLocationServiceDialog();
    }

    final permission =
        await _locationService.requestPermission();

    if (permission == LocationPermission.denied) {
      if (!mounted) {
        return false;
      }

      _showError(
        'Location permission was denied. '
        'Please allow location access to activate SOS.',
      );

      return false;
    }

    if (permission == LocationPermission.deniedForever) {
      if (!mounted) {
        return false;
      }

      return _showPermissionSettingsDialog();
    }

    return true;
  }

  // ============================================================
  // LOCATION SERVICE DIALOG
  // ============================================================

  Future<bool> _showLocationServiceDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colors =
            Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.location_off_rounded,
                color: colors.error,
              ),
              const SizedBox(
                width: 10,
              ),
              const Expanded(
                child: Text(
                  'Location Services Disabled',
                ),
              ),
            ],
          ),
          content: const Text(
            'LifeLynk needs your current GPS location '
            'to activate an emergency SOS and find nearby '
            'hospitals, blood banks and potential donors.\n\n'
            'Please enable location services and try again.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop(
                  true,
                );

                await _locationService
                    .openLocationSettings();
              },
              icon: const Icon(
                Icons.settings_rounded,
              ),
              label: const Text(
                'Open Settings',
              ),
            ),
          ],
        );
      },
    );

    if (result != true) {
      return false;
    }

    if (!mounted) {
      return false;
    }

    final enabled =
        await _locationService.isLocationServiceEnabled();

    if (!enabled && mounted) {
      _showError(
        'Location services are still disabled. '
        'Please enable GPS before activating SOS.',
      );
    }

    return enabled;
  }

  // ============================================================
  // PERMISSION SETTINGS DIALOG
  // ============================================================

  Future<bool> _showPermissionSettingsDialog() async {
    final result = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (dialogContext) {
        final colors =
            Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.location_disabled_rounded,
                color: colors.error,
              ),
              const SizedBox(
                width: 10,
              ),
              const Expanded(
                child: Text(
                  'Location Permission Required',
                ),
              ),
            ],
          ),
          content: const Text(
            'Location permission has been permanently denied '
            'for LifeLynk.\n\n'
            'Please open the app settings and allow location '
            'permission so emergency SOS can capture your '
            'current location.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton.icon(
              onPressed: () async {
                Navigator.of(dialogContext).pop(
                  true,
                );

                await _locationService
                    .openAppSettings();
              },
              icon: const Icon(
                Icons.settings_rounded,
              ),
              label: const Text(
                'App Settings',
              ),
            ),
          ],
        );
      },
    );

    if (result != true) {
      return false;
    }

    return false;
  }

  // ============================================================
  // ACTIVATE CONFIRMATION
  // ============================================================

  Future<bool> _showActivateConfirmation() async {
    final provider = context.read<SosProvider>();

    final bloodGroup =
        provider.selectedBloodGroupCode.trim();

    final units =
        provider.unitsRequired;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors =
            Theme.of(dialogContext).colorScheme;

        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.warning_rounded,
                color: colors.error,
              ),
              const SizedBox(
                width: 10,
              ),
              const Expanded(
                child: Text(
                  'Activate Emergency SOS?',
                ),
              ),
            ],
          ),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const Text(
                'Your current GPS location will be captured '
                'and an emergency SOS will be activated. '
                'Nearby hospitals, blood banks and potential '
                'donors will then be searched.',
              ),
              if (bloodGroup.isNotEmpty) ...[
                const SizedBox(
                  height: 16,
                ),
                Container(
                  width: double.infinity,
                  padding:
                      const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: colors
                        .surfaceContainerHighest
                        .withValues(
                      alpha: 0.45,
                    ),
                    borderRadius:
                        BorderRadius.circular(
                      12,
                    ),
                  ),
                  child: Row(
                    children: [
                      Icon(
                        Icons.bloodtype_rounded,
                        color:
                            colors.primary,
                      ),
                      const SizedBox(
                        width: 9,
                      ),
                      Expanded(
                        child: Text(
                          '$bloodGroup • $units '
                          '${units == 1 ? 'unit' : 'units'}',
                          style: const TextStyle(
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  false,
                );
              },
              child: const Text(
                'Cancel',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  true,
                );
              },
              style: FilledButton.styleFrom(
                backgroundColor:
                    colors.error,
                foregroundColor:
                    colors.onError,
              ),
              child: const Text(
                'Activate SOS',
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ============================================================
  // CANCEL SOS
  // ============================================================

  Future<void> _cancelSos() async {
    final confirmed =
        await _showCancelConfirmation();

    if (!confirmed || !mounted) {
      return;
    }

    final provider = context.read<SosProvider>();

    final success = await provider.cancelSos();

    if (!mounted) {
      return;
    }

    if (success) {
      _showSnackBar(
        'SOS request cancelled.',
      );
    } else if (provider.error != null) {
      _showError(
        provider.error!,
      );
    }
  }

  // ============================================================
  // CANCEL CONFIRMATION
  // ============================================================

  Future<bool> _showCancelConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Cancel Emergency SOS?',
          ),
          content: const Text(
            'Are you sure you want to cancel your active emergency request?',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  false,
                );
              },
              child: const Text(
                'Keep SOS',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  true,
                );
              },
              child: const Text(
                'Cancel SOS',
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ============================================================
  // COMPLETE SOS
  // ============================================================

  Future<void> _completeSos() async {
    final confirmed =
        await _showCompleteConfirmation();

    if (!confirmed || !mounted) {
      return;
    }

    final provider = context.read<SosProvider>();

    final success = await provider.completeSos();

    if (!mounted) {
      return;
    }

    if (success) {
      _showSnackBar(
        'Emergency SOS completed.',
      );
    } else if (provider.error != null) {
      _showError(
        provider.error!,
      );
    }
  }

  // ============================================================
  // COMPLETE CONFIRMATION
  // ============================================================

  Future<bool> _showCompleteConfirmation() async {
    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text(
            'Complete SOS?',
          ),
          content: const Text(
            'Only complete the SOS if the emergency has been resolved and assistance is no longer required.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  false,
                );
              },
              child: const Text(
                'Not Yet',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext).pop(
                  true,
                );
              },
              child: const Text(
                'Complete',
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ============================================================
  // DELETE SOS HISTORY
  // ============================================================

  Future<void> _deleteSosHistory(
    EmergencySosModel sos,
  ) async {
    final confirmed =
        await _showDeleteHistoryConfirmation(
      sos,
    );

    if (!confirmed || !mounted) {
      return;
    }

    final provider =
        context.read<SosProvider>();

    final success =
        await provider.deleteSosHistory(
      sos.id,
    );

    if (!mounted) {
      return;
    }

    if (success) {
      _showSnackBar(
        'SOS history deleted successfully.',
      );
    } else if (provider.error != null) {
      _showError(
        provider.error!,
      );
    }
  }

  // ============================================================
  // DELETE CONFIRMATION
  // ============================================================

  Future<bool> _showDeleteHistoryConfirmation(
    EmergencySosModel sos,
  ) async {
    final provider =
        context.read<SosProvider>();

    final bloodGroup =
        provider
            .bloodGroupName(
              sos.bloodGroupId,
            )
            .trim();

    final units =
        sos.unitsRequired;

    final result = await showDialog<bool>(
      context: context,
      builder: (dialogContext) {
        final colors =
            Theme.of(dialogContext)
                .colorScheme;

        return AlertDialog(
          title: Row(
            children: [
              Icon(
                Icons.delete_outline_rounded,
                color:
                    colors.error,
              ),
              const SizedBox(
                width: 10,
              ),
              const Expanded(
                child: Text(
                  'Delete SOS History?',
                ),
              ),
            ],
          ),
          content: Text(
            'This will permanently delete this '
            'completed/cancelled SOS history record.\n\n'
            '$bloodGroup • $units '
            '${units == 1 ? 'unit' : 'units'}\n\n'
            'This action cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(false);
              },
              child: const Text(
                'Keep',
              ),
            ),
            FilledButton(
              onPressed: () {
                Navigator.of(dialogContext)
                    .pop(true);
              },
              style: FilledButton.styleFrom(
                backgroundColor:
                    colors.error,
                foregroundColor:
                    colors.onError,
              ),
              child: const Text(
                'Delete',
              ),
            ),
          ],
        );
      },
    );

    return result ?? false;
  }

  // ============================================================
  // RESOURCE TAP
  // ============================================================

  void _onResourceTap(
    NearbyResourceModel resource,
  ) {
    _showResourceDetails(
      resource,
    );
  }

  // ============================================================
  // RESOURCE DETAILS
  // ============================================================

  void _showResourceDetails(
    NearbyResourceModel resource,
  ) {
    showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      isScrollControlled: true,
      builder: (sheetContext) {
        final theme =
            Theme.of(sheetContext);

        final colors =
            theme.colorScheme;

        return SafeArea(
          child: Padding(
            padding:
                const EdgeInsets.fromLTRB(
              20,
              4,
              20,
              24,
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize:
                    MainAxisSize.min,
                crossAxisAlignment:
                    CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 50,
                        height: 50,
                        decoration:
                            BoxDecoration(
                          color:
                              colors
                                  .primaryContainer,
                          borderRadius:
                              BorderRadius
                                  .circular(
                            15,
                          ),
                        ),
                        child: Icon(
                          _resourceIcon(
                            resource.type,
                          ),
                          color:
                              colors
                                  .onPrimaryContainer,
                        ),
                      ),
                      const SizedBox(
                        width: 12,
                      ),
                      Expanded(
                        child: Column(
                          crossAxisAlignment:
                              CrossAxisAlignment
                                  .start,
                          children: [
                            Text(
                              resource.name,
                              maxLines: 2,
                              overflow:
                                  TextOverflow
                                      .ellipsis,
                              style: theme
                                  .textTheme
                                  .titleLarge
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
                              resource.typeLabel,
                              style: theme
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                color: colors
                                    .onSurfaceVariant,
                                fontWeight:
                                    FontWeight
                                        .w600,
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

                  _DetailRow(
                    icon:
                        Icons.location_on_rounded,
                    title: 'Distance',
                    value:
                        resource.distanceLabel,
                  ),

                  if (resource
                          .estimatedTravelTimeMinutes !=
                      null)
                    _DetailRow(
                      icon:
                          Icons.access_time_rounded,
                      title: 'Travel time',
                      value:
                          resource.travelTimeLabel,
                    ),

                  if (resource.availableUnits !=
                      null)
                    _DetailRow(
                      icon:
                          Icons.bloodtype_rounded,
                      title: 'Availability',
                      value:
                          resource.hasBloodAvailability
                              ? '${resource.availableUnits} units available'
                              : 'No units currently available',
                    ),

                  if (resource.bloodGroup != null &&
                      resource.bloodGroup!
                          .trim()
                          .isNotEmpty)
                    _DetailRow(
                      icon:
                          Icons.water_drop_rounded,
                      title: 'Blood group',
                      value:
                          resource.bloodGroup!,
                    ),

                  if (resource.phone != null &&
                      resource.phone!
                          .trim()
                          .isNotEmpty)
                    _DetailRow(
                      icon:
                          Icons.phone_rounded,
                      title: 'Phone',
                      value:
                          resource.phone!,
                    ),

                  if (resource.emergencyContact !=
                          null &&
                      resource.emergencyContact!
                          .trim()
                          .isNotEmpty)
                    _DetailRow(
                      icon:
                          Icons.emergency_rounded,
                      title:
                          'Emergency contact',
                      value:
                          resource.emergencyContact!,
                    ),

                  if (resource.address != null &&
                      resource.address!
                          .trim()
                          .isNotEmpty)
                    _DetailRow(
                      icon:
                          Icons.home_rounded,
                      title:
                          'Address',
                      value:
                          resource.address!,
                    ),

                  const SizedBox(
                    height: 12,
                  ),

                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: FilledButton.icon(
                      onPressed: () {
                        Navigator.of(
                          sheetContext,
                        ).pop();

                        _navigateToResource(
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
  // NAVIGATION
  // ============================================================

  Future<void> _navigateToResource(
    NearbyResourceModel resource,
  ) async {
    final success =
        await EmergencyNavigationService
            .navigateToResource(
      resource,
    );

    if (!mounted) {
      return;
    }

    if (!success) {
      _showError(
        'Unable to open OpenStreetMap.',
      );
    }
  }

  // ============================================================
  // RESOURCE ICON
  // ============================================================

  IconData _resourceIcon(
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

  // ============================================================
  // ERROR
  // ============================================================

  void _showError(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
          ),
          backgroundColor:
              Theme.of(context)
                  .colorScheme
                  .error,
          behavior:
              SnackBarBehavior.floating,
        ),
      );

    context
        .read<SosProvider>()
        .clearError();
  }

  // ============================================================
  // SNACKBAR
  // ============================================================

  void _showSnackBar(
    String message,
  ) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(
            message,
          ),
          behavior:
              SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // REFRESH
  // ============================================================

  Future<void> _refresh() async {
    final provider =
        context.read<SosProvider>();

    await provider.loadSosData();

    if (!mounted) {
      return;
    }

    if (provider.activeSos != null) {
      await provider
          .refreshNearbyResources();
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(
    BuildContext context,
  ) {
    return Consumer<SosProvider>(
      builder: (
        context,
        provider,
        child,
      ) {
        return RefreshIndicator(
          onRefresh: _refresh,
          child: CustomScrollView(
            physics:
                const AlwaysScrollableScrollPhysics(),
            slivers: [
              SliverPadding(
                padding:
                    const EdgeInsets.fromLTRB(
                  16,
                  12,
                  16,
                  32,
                ),
                sliver: SliverList(
                  delegate:
                      SliverChildListDelegate(
                    [
                      const _SosHeader(),

                      const SizedBox(
                        height: 18,
                      ),

                      if (provider.error != null)
                        _ErrorBanner(
                          message:
                              provider.error!,
                          onDismiss:
                              provider
                                  .clearError,
                        ),

                      if (provider.error != null)
                        const SizedBox(
                          height: 12,
                        ),

                      if (provider.loading &&
                          provider.activeSos ==
                              null &&
                          provider.history
                              .isEmpty)
                        const _InitialLoadingState(),

                      if (provider.activeSos !=
                          null) ...[
                        _ActiveSosCard(
                          sos:
                              provider.activeSos!,
                          bloodGroupName:
                              provider
                                  .bloodGroupName(
                            provider
                                .activeSos!
                                .bloodGroupId,
                          ),
                          locationAddress:
                              provider
                                  .activeSosAddress,
                          loading:
                              provider.loading,
                          onCancel:
                              _cancelSos,
                          onComplete:
                              _completeSos,
                        ),

                        const SizedBox(
                          height: 18,
                        ),

                        EmergencyMap(
                          sos:
                              provider.activeSos,
                          resources:
                              provider
                                  .nearbyResources,
                          onResourceTap:
                              _onResourceTap,
                        ),

                        const SizedBox(
                          height: 22,
                        ),

                        EmergencyResourceList(
                          resources:
                              provider
                                  .nearbyResources,
                          loading:
                              provider.loading,
                          onRefresh:
                              provider
                                  .refreshNearbyResources,
                          onResourceTap:
                              _onResourceTap,
                          onNavigate:
                              _navigateToResource,
                        ),

                        const SizedBox(
                          height: 24,
                        ),
                      ],

                      if (provider.activeSos ==
                          null)
                        _ActivateSosSection(
                          creating:
                              provider.creating,
                          bloodGroups:
                              provider
                                  .bloodGroups,
                          selectedBloodGroupId:
                              provider
                                  .selectedBloodGroupId,
                          onBloodGroupChanged:
                              provider
                                  .setSelectedBloodGroup,
                          unitsRequired:
                              provider
                                  .unitsRequired,
                          onIncrementUnits:
                              provider
                                  .incrementUnits,
                          onDecrementUnits:
                              provider
                                  .decrementUnits,
                          onActivate:
                              _activateSos,
                        ),

                      if (provider.history
                          .isNotEmpty) ...[
                        const SizedBox(
                          height: 20,
                        ),

                        const _HistoryHeader(),

                        const SizedBox(
                          height: 10,
                        ),

                        ...provider.history.map(
                          (sos) => Padding(
                            padding:
                                const EdgeInsets.only(
                              bottom: 10,
                            ),
                            child:
                                SosHistoryCard(
                              sos: sos,
                              bloodGroupName:
                                  provider
                                      .bloodGroupName(
                                sos.bloodGroupId,
                              ),
                              cityName:
                                  sos.cityId !=
                                          null
                                      ? provider
                                          .cityName(
                                          sos.cityId!,
                                        )
                                      : 'Unknown',
                              provinceName:
                                  sos.cityId !=
                                          null
                                      ? provider
                                          .provinceName(
                                          sos.cityId!,
                                        )
                                      : null,
                              locationAddress:
                                  provider
                                      .sosAddress(
                                sos.id,
                              ),
                              onDelete: () =>
                                  _deleteSosHistory(
                                sos,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ============================================================================
// SOS HEADER
// ============================================================================

class _SosHeader extends StatelessWidget {
  const _SosHeader();

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Container(
              width: 46,
              height: 46,
              decoration:
                  BoxDecoration(
                color:
                    colors.errorContainer,
                borderRadius:
                    BorderRadius.circular(
                  14,
                ),
              ),
              child: Icon(
                Icons.sos_rounded,
                color:
                    colors.onErrorContainer,
                size: 26,
              ),
            ),
            const SizedBox(
              width: 12,
            ),
            Expanded(
              child: Text(
                'Emergency SOS',
                style:
                    Theme.of(context)
                        .textTheme
                        .headlineSmall
                        ?.copyWith(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(
          height: 8,
        ),
        Text(
          'Get nearby emergency healthcare resources using your current GPS location.',
          style:
              Theme.of(context)
                  .textTheme
                  .bodyMedium
                  ?.copyWith(
            color:
                colors.onSurfaceVariant,
            height: 1.4,
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// INITIAL LOADING
// ============================================================================

class _InitialLoadingState
    extends StatelessWidget {
  const _InitialLoadingState();

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.symmetric(
        vertical: 42,
        horizontal: 20,
      ),
      decoration:
          BoxDecoration(
        color: colors
            .surfaceContainerHighest
            .withValues(
          alpha: 0.35,
        ),
        borderRadius:
            BorderRadius.circular(
          22,
        ),
      ),
      child: Column(
        children: [
          const SizedBox(
            width: 30,
            height: 30,
            child:
                CircularProgressIndicator(
              strokeWidth: 2.5,
            ),
          ),
          const SizedBox(
            height: 14,
          ),
          Text(
            'Loading emergency services...',
            style:
                Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ACTIVATE SOS
// ============================================================================

class _ActivateSosSection
    extends StatelessWidget {
  final bool creating;

  final List<Map<String, String>>
      bloodGroups;

  final String? selectedBloodGroupId;

  final ValueChanged<String?>
      onBloodGroupChanged;

  final int unitsRequired;

  final VoidCallback onIncrementUnits;

  final VoidCallback onDecrementUnits;

  final VoidCallback onActivate;

  const _ActivateSosSection({
    required this.creating,
    required this.bloodGroups,
    required this.selectedBloodGroupId,
    required this.onBloodGroupChanged,
    required this.unitsRequired,
    required this.onIncrementUnits,
    required this.onDecrementUnits,
    required this.onActivate,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final hasBloodGroups =
        bloodGroups.isNotEmpty;

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color:
            colors.errorContainer,
        borderRadius:
            BorderRadius.circular(24),
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Center(
            child: Container(
              width: 76,
              height: 76,
              decoration:
                  BoxDecoration(
                color:
                    colors.error,
                shape:
                    BoxShape.circle,
              ),
              child: Icon(
                Icons.sos_rounded,
                color:
                    colors.onError,
                size: 42,
              ),
            ),
          ),

          const SizedBox(
            height: 16,
          ),

          Center(
            child: Text(
              'Need Emergency Help?',
              textAlign:
                  TextAlign.center,
              style:
                  theme
                      .textTheme
                      .titleLarge
                      ?.copyWith(
                fontWeight:
                    FontWeight.w900,
              ),
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          Center(
            child: Text(
              'Select the blood group and required units before activating SOS.',
              textAlign:
                  TextAlign.center,
              style:
                  theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                color:
                    colors.onErrorContainer,
                height: 1.45,
              ),
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          // ==========================================================
          // BLOOD GROUP
          // ==========================================================

          Text(
            'Blood Group',
            style:
                theme.textTheme.labelLarge
                    ?.copyWith(
              fontWeight:
                  FontWeight.w800,
              color:
                  colors.onErrorContainer,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          // Explicit Material ancestor for the dropdown.
          //
          // This prevents:
          // "No Material widget found."
          //
          // The Material is transparent so it does not alter
          // the existing visual design or container background.
          Material(
            type: MaterialType.transparency,
            child: DropdownButtonFormField<String>(
              initialValue:
                  selectedBloodGroupId,
              isExpanded: true,
              decoration:
                  InputDecoration(
                filled: true,
                fillColor:
                    colors.surface,
                hintText:
                    hasBloodGroups
                        ? 'Select blood group'
                        : 'Blood groups unavailable',
                prefixIcon:
                    Icon(
                  Icons.bloodtype_rounded,
                  color:
                      colors.primary,
                ),
                border:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  borderSide:
                      BorderSide.none,
                ),
                enabledBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  borderSide:
                      BorderSide(
                    color: colors
                        .outlineVariant,
                  ),
                ),
                focusedBorder:
                    OutlineInputBorder(
                  borderRadius:
                      BorderRadius.circular(
                    14,
                  ),
                  borderSide:
                      BorderSide(
                    color:
                        colors.primary,
                    width: 1.5,
                  ),
                ),
                contentPadding:
                    const EdgeInsets
                        .symmetric(
                  horizontal: 14,
                  vertical: 15,
                ),
              ),
              items: bloodGroups
                  .map(
                    (
                      group,
                    ) {
                      final id =
                          group['id']
                                  ?.trim() ??
                              '';

                      final code =
                          group['code']
                                  ?.trim() ??
                              '';

                      final name =
                          group['name']
                                  ?.trim() ??
                              '';

                      final display =
                          code.isNotEmpty
                              ? code
                              : name;

                      if (id.isEmpty ||
                          display.isEmpty) {
                        return null;
                      }

                      return DropdownMenuItem<
                          String>(
                        value: id,
                        child: Text(
                          display,
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),
                      );
                    },
                  )
                  .whereType<
                      DropdownMenuItem<
                          String>>()
                  .toList(),
              onChanged:
                  creating ||
                          !hasBloodGroups
                      ? null
                      : onBloodGroupChanged,
            ),
          ),

          const SizedBox(
            height: 18,
          ),

          // ==========================================================
          // REQUIRED UNITS
          // ==========================================================

          Text(
            'Required Units',
            style:
                theme.textTheme.labelLarge
                    ?.copyWith(
              fontWeight:
                  FontWeight.w800,
              color:
                  colors.onErrorContainer,
            ),
          ),

          const SizedBox(
            height: 7,
          ),

          Container(
            width: double.infinity,
            padding:
                const EdgeInsets
                    .symmetric(
              horizontal: 10,
              vertical: 6,
            ),
            decoration:
                BoxDecoration(
              color:
                  colors.surface,
              borderRadius:
                  BorderRadius.circular(
                14,
              ),
              border:
                  Border.all(
                color:
                    colors.outlineVariant,
              ),
            ),
            child: Row(
              mainAxisAlignment:
                  MainAxisAlignment.center,
              children: [
                IconButton(
                  tooltip:
                      'Decrease required units',
                  onPressed:
                      creating ||
                              unitsRequired <=
                                  SosProvider
                                      .minimumUnits
                          ? null
                          : onDecrementUnits,
                  icon:
                      const Icon(
                    Icons.remove_rounded,
                  ),
                ),

                Container(
                  constraints:
                      const BoxConstraints(
                    minWidth: 54,
                  ),
                  alignment:
                      Alignment.center,
                  child: Text(
                    '$unitsRequired',
                    style:
                        theme
                            .textTheme
                            .headlineSmall
                            ?.copyWith(
                      fontWeight:
                          FontWeight.w900,
                    ),
                  ),
                ),

                IconButton(
                  tooltip:
                      'Increase required units',
                  onPressed:
                      creating ||
                              unitsRequired >=
                                  SosProvider
                                      .maximumUnits
                          ? null
                          : onIncrementUnits,
                  icon:
                      const Icon(
                    Icons.add_rounded,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(
            height: 6,
          ),

          Center(
            child: Text(
              'Select between ${SosProvider.minimumUnits} and ${SosProvider.maximumUnits} units.',
              style:
                  theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                color:
                    colors.onErrorContainer
                        .withValues(
                  alpha: 0.75,
                ),
              ),
            ),
          ),

          const SizedBox(
            height: 20,
          ),

          // ==========================================================
          // ACTIVATE BUTTON
          // ==========================================================

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed:
                  creating ||
                          !hasBloodGroups ||
                          selectedBloodGroupId ==
                              null ||
                          selectedBloodGroupId!
                              .trim()
                              .isEmpty
                      ? null
                      : onActivate,
              style:
                  FilledButton.styleFrom(
                backgroundColor:
                    colors.error,
                foregroundColor:
                    colors.onError,
              ),
              icon: creating
                  ? const SizedBox(
                      width: 20,
                      height: 20,
                      child:
                          CircularProgressIndicator(
                        strokeWidth: 2,
                      ),
                    )
                  : const Icon(
                      Icons.sos_rounded,
                    ),
              label: Text(
                creating
                    ? 'Activating SOS...'
                    : 'ACTIVATE SOS',
                style:
                    const TextStyle(
                  fontWeight:
                      FontWeight.w900,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ACTIVE SOS CARD
// ============================================================================

class _ActiveSosCard
    extends StatelessWidget {
  final EmergencySosModel sos;

  final String bloodGroupName;

  final String? locationAddress;

  final bool loading;

  final VoidCallback onCancel;

  final VoidCallback onComplete;

  const _ActiveSosCard({
    required this.sos,
    required this.bloodGroupName,
    required this.locationAddress,
    required this.loading,
    required this.onCancel,
    required this.onComplete,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final theme =
        Theme.of(context);

    final colors =
        theme.colorScheme;

    final normalizedAddress =
        locationAddress?.trim();

    final locationLabel =
        normalizedAddress != null &&
                normalizedAddress.isNotEmpty
            ? normalizedAddress
            : sos.hasLocation
                ? 'GPS location captured'
                : 'Location unavailable';

    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(18),
      decoration:
          BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(
          22,
        ),
        border: Border.all(
          color: colors.error
              .withValues(
            alpha: 0.35,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black
                .withValues(
              alpha: 0.05,
            ),
            blurRadius: 14,
            offset:
                const Offset(0, 5),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration:
                    BoxDecoration(
                  color:
                      colors.errorContainer,
                  shape:
                      BoxShape.circle,
                ),
                child: Icon(
                  Icons.warning_rounded,
                  color:
                      colors.error,
                ),
              ),
              const SizedBox(
                width: 11,
              ),
              Expanded(
                child: Column(
                  crossAxisAlignment:
                      CrossAxisAlignment.start,
                  children: [
                    Text(
                      'SOS Active',
                      style:
                          theme
                              .textTheme
                              .titleMedium
                              ?.copyWith(
                        fontWeight:
                            FontWeight.w900,
                      ),
                    ),
                    const SizedBox(
                      height: 2,
                    ),
                    Text(
                      _statusText(
                        sos.status,
                      ),
                      style:
                          theme
                              .textTheme
                              .bodySmall
                              ?.copyWith(
                        color: colors
                            .onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(
                width: 8,
              ),
              _StatusBadge(
                status:
                    sos.status,
              ),
            ],
          ),

          const SizedBox(
            height: 18,
          ),

          Row(
            children: [
              Expanded(
                child: _InfoTile(
                  icon:
                      Icons.bloodtype_rounded,
                  label:
                      'Blood Group',
                  value:
                      bloodGroupName
                              .trim()
                              .isNotEmpty
                          ? bloodGroupName
                          : 'Unknown',
                ),
              ),
              const SizedBox(
                width: 10,
              ),
              Expanded(
                child: _InfoTile(
                  icon:
                      Icons.water_drop_rounded,
                  label:
                      'Units',
                  value:
                      '${sos.unitsRequired}',
                ),
              ),
            ],
          ),

          const SizedBox(
            height: 10,
          ),

          _InfoTile(
            icon:
                Icons.location_on_rounded,
            label:
                'Emergency Location',
            value:
                locationLabel,
          ),

          if (sos.gpsAccuracy != null) ...[
            const SizedBox(
              height: 10,
            ),
            _InfoTile(
              icon:
                  Icons.gps_fixed_rounded,
              label:
                  'GPS Accuracy',
              value:
                  '${sos.gpsAccuracy!.toStringAsFixed(1)} m',
            ),
          ],

          if (sos.hasLocation) ...[
            const SizedBox(
              height: 10,
            ),
            Row(
              children: [
                Expanded(
                  child: _InfoTile(
                    icon:
                        Icons.explore_rounded,
                    label:
                        'Latitude',
                    value:
                        sos.latitude != null
                            ? sos.latitude!
                                .toStringAsFixed(
                                6,
                              )
                            : 'N/A',
                  ),
                ),
                const SizedBox(
                  width: 10,
                ),
                Expanded(
                  child: _InfoTile(
                    icon:
                        Icons.explore_rounded,
                    label:
                        'Longitude',
                    value:
                        sos.longitude != null
                            ? sos.longitude!
                                .toStringAsFixed(
                                6,
                              )
                            : 'N/A',
                  ),
                ),
              ],
            ),
          ],

          const SizedBox(
            height: 18,
          ),

          Row(
            children: [
              Expanded(
                child:
                    OutlinedButton(
                  onPressed:
                      loading
                          ? null
                          : onCancel,
                  child:
                      const Text(
                    'Cancel SOS',
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
                      loading
                          ? null
                          : onComplete,
                  child:
                      const Text(
                    'Complete',
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _statusText(
    String status,
  ) {
    switch (status.trim().toLowerCase()) {
      case 'pending':
        return 'Waiting for emergency response';

      case 'matched':
        return 'Emergency resource matched';

      case 'in_progress':
        return 'Emergency assistance in progress';

      case 'completed':
        return 'Emergency completed';

      case 'cancelled':
        return 'Emergency request cancelled';

      default:
        return 'Emergency request active';
    }
  }
}

// ============================================================================
// STATUS BADGE
// ============================================================================

class _StatusBadge
    extends StatelessWidget {
  final String status;

  const _StatusBadge({
    required this.status,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    final normalizedStatus =
        status.trim().toLowerCase();

    final isCompleted =
        normalizedStatus ==
            'completed';

    final isCancelled =
        normalizedStatus ==
            'cancelled';

    final backgroundColor =
        isCompleted
            ? colors.secondaryContainer
            : isCancelled
                ? colors
                    .surfaceContainerHighest
                : colors.errorContainer;

    final foregroundColor =
        isCompleted
            ? colors
                .onSecondaryContainer
            : isCancelled
                ? colors
                    .onSurfaceVariant
                : colors.onErrorContainer;

    return Container(
      padding:
          const EdgeInsets.symmetric(
        horizontal: 9,
        vertical: 6,
      ),
      decoration:
          BoxDecoration(
        color: backgroundColor,
        borderRadius:
            BorderRadius.circular(
          20,
        ),
      ),
      child: Text(
        status.toUpperCase(),
        style: TextStyle(
          color:
              foregroundColor,
          fontSize: 9,
          fontWeight:
              FontWeight.w900,
        ),
      ),
    );
  }
}

// ============================================================================
// INFO TILE
// ============================================================================

class _InfoTile
    extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(11),
      decoration:
          BoxDecoration(
        color: colors
            .surfaceContainerHighest
            .withValues(
          alpha: 0.45,
        ),
        borderRadius:
            BorderRadius.circular(
          13,
        ),
      ),
      child: Row(
        children: [
          Icon(
            icon,
            size: 19,
            color:
                colors.primary,
          ),
          const SizedBox(
            width: 8,
          ),
          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  label,
                  maxLines: 1,
                  overflow:
                      TextOverflow.ellipsis,
                  style: TextStyle(
                    color: colors
                        .onSurfaceVariant,
                    fontSize: 10,
                    fontWeight:
                        FontWeight.w600,
                  ),
                ),
                const SizedBox(
                  height: 2,
                ),
                Text(
                  value,
                  maxLines: 3,
                  overflow:
                      TextOverflow.ellipsis,
                  style:
                      const TextStyle(
                    fontSize: 12,
                    fontWeight:
                        FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// HISTORY HEADER
// ============================================================================

class _HistoryHeader
    extends StatelessWidget {
  const _HistoryHeader();

  @override
  Widget build(
    BuildContext context,
  ) {
    return Row(
      children: [
        Expanded(
          child: Text(
            'SOS History',
            style:
                Theme.of(context)
                    .textTheme
                    .titleLarge
                    ?.copyWith(
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// DETAIL ROW
// ============================================================================

class _DetailRow
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;

  const _DetailRow({
    required this.icon,
    required this.title,
    required this.value,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Padding(
      padding:
          const EdgeInsets.only(
        bottom: 12,
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
            width: 10,
          ),
          Text(
            '$title: ',
            style:
                const TextStyle(
              fontWeight:
                  FontWeight.w700,
            ),
          ),
          Expanded(
            child: Text(
              value,
            ),
          ),
        ],
      ),
    );
  }
}

// ============================================================================
// ERROR BANNER
// ============================================================================

class _ErrorBanner
    extends StatelessWidget {
  final String message;
  final VoidCallback onDismiss;

  const _ErrorBanner({
    required this.message,
    required this.onDismiss,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(13),
      decoration:
          BoxDecoration(
        color:
            colors.errorContainer,
        borderRadius:
            BorderRadius.circular(
          14,
        ),
      ),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Icon(
            Icons
                .error_outline_rounded,
            color: colors
                .onErrorContainer,
          ),
          const SizedBox(
            width: 9,
          ),
          Expanded(
            child: Text(
              message,
              style: TextStyle(
                color: colors
                    .onErrorContainer,
                fontSize: 12,
                fontWeight:
                    FontWeight.w600,
              ),
            ),
          ),
          IconButton(
            onPressed:
                onDismiss,
            padding:
                EdgeInsets.zero,
            constraints:
                const BoxConstraints(
              minWidth: 32,
              minHeight: 32,
            ),
            icon: Icon(
              Icons.close_rounded,
              color: colors
                  .onErrorContainer,
              size: 19,
            ),
          ),
        ],
      ),
    );
  }
}