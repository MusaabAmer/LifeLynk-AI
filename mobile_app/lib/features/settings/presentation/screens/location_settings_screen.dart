import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';

class LocationSettingsScreen extends StatefulWidget {
  const LocationSettingsScreen({super.key});

  @override
  State<LocationSettingsScreen> createState() =>
      _LocationSettingsScreenState();
}

class _LocationSettingsScreenState
    extends State<LocationSettingsScreen>
    with WidgetsBindingObserver {
  bool _isLoading = true;
  bool _locationEnabled = false;

  LocationPermission _permission =
      LocationPermission.denied;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addObserver(this);

    _loadLocationStatus();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // ============================================================
  // APP LIFECYCLE
  // ============================================================

  @override
  void didChangeAppLifecycleState(
    AppLifecycleState state,
  ) {
    if (state == AppLifecycleState.resumed) {
      _loadLocationStatus();
    }
  }

  // ============================================================
  // LOAD LOCATION STATUS
  // ============================================================

  Future<void> _loadLocationStatus() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      final serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      final permission =
          await Geolocator.checkPermission();

      if (!mounted) return;

      setState(() {
        _locationEnabled = serviceEnabled;
        _permission = permission;
        _isLoading = false;
      });
    } catch (_) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });
    }
  }

  // ============================================================
  // REQUEST LOCATION PERMISSION
  // ============================================================

  Future<void> _requestLocationPermission() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
      });
    }

    try {
      var serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!serviceEnabled) {
        if (!mounted) return;

        setState(() {
          _locationEnabled = false;
          _isLoading = false;
        });

        await _showLocationServiceDialog();
        return;
      }

      var permission =
          await Geolocator.checkPermission();

      if (permission == LocationPermission.denied) {
        permission =
            await Geolocator.requestPermission();
      }

      serviceEnabled =
          await Geolocator.isLocationServiceEnabled();

      if (!mounted) return;

      setState(() {
        _permission = permission;
        _locationEnabled = serviceEnabled;
        _isLoading = false;
      });

      if (permission == LocationPermission.deniedForever) {
        await _showPermissionDialog(
          permanentlyDenied: true,
        );
      } else if (permission == LocationPermission.denied) {
        await _showPermissionDialog(
          permanentlyDenied: false,
        );
      }
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to access location: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // OPEN DEVICE LOCATION SETTINGS
  // ============================================================

  Future<void> _openLocationSettings() async {
    await Geolocator.openLocationSettings();
  }

  // ============================================================
  // LOCATION SERVICE DIALOG
  // ============================================================

  Future<void> _showLocationServiceDialog() async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text(
            'Location is turned off',
          ),
          content: const Text(
            'LifeLynk AI needs location access to '
            'provide nearby blood banks, hospitals, '
            'donors, and emergency location services.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);
                await _openLocationSettings();
              },
              child: const Text(
                'Open Settings',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // PERMISSION DIALOG
  // ============================================================

  Future<void> _showPermissionDialog({
    required bool permanentlyDenied,
  }) async {
    await showDialog<void>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: Text(
            permanentlyDenied
                ? 'Location permission blocked'
                : 'Location permission required',
          ),
          content: Text(
            permanentlyDenied
                ? 'Location permission has been permanently '
                    'denied. Please enable it from the LifeLynk AI '
                    'app settings.'
                : 'Please allow LifeLynk AI to access your '
                    'location so nearby emergency resources '
                    'can be displayed.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.pop(context);
              },
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () async {
                Navigator.pop(context);

                await Geolocator.openAppSettings();
              },
              child: const Text(
                'App Settings',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // STATUS
  // ============================================================

  bool get _permissionGranted {
    return _permission ==
            LocationPermission.always ||
        _permission ==
            LocationPermission.whileInUse;
  }

  String get _statusText {
    if (!_locationEnabled) {
      return 'Location services are turned off';
    }

    switch (_permission) {
      case LocationPermission.always:
        return 'Location access is always allowed';

      case LocationPermission.whileInUse:
        return 'Location access is allowed while using the app';

      case LocationPermission.denied:
        return 'Location permission has not been granted';

      case LocationPermission.deniedForever:
        return 'Location permission is permanently denied';

      case LocationPermission.unableToDetermine:
        return 'Location permission status is unavailable';
    }
  }

  IconData get _statusIcon {
    if (!_locationEnabled) {
      return Icons.location_off_rounded;
    }

    switch (_permission) {
      case LocationPermission.always:
        return Icons.location_on_rounded;

      case LocationPermission.whileInUse:
        return Icons.location_on_outlined;

      case LocationPermission.denied:
      case LocationPermission.deniedForever:
      case LocationPermission.unableToDetermine:
        return Icons.location_disabled_rounded;
    }
  }

  // ============================================================
  // GET CURRENT POSITION
  // ============================================================

  Future<void> _testCurrentLocation() async {
    try {
      if (!_locationEnabled) {
        await _showLocationServiceDialog();
        return;
      }

      if (!_permissionGranted) {
        await _requestLocationPermission();
        return;
      }

      setState(() {
        _isLoading = true;
      });

      final position =
          await Geolocator.getCurrentPosition(
        locationSettings:
            const LocationSettings(
          accuracy: LocationAccuracy.high,
        ),
      );

      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Location: ${position.latitude.toStringAsFixed(6)}, '
            '${position.longitude.toStringAsFixed(6)}',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
      });

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            'Unable to get current location: $e',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    final locationReady =
        _permissionGranted &&
        _locationEnabled;

    return Scaffold(
      backgroundColor: colors.surface,

      appBar: AppBar(
        title: const Text(
          'Location',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),

      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 460,
            ),
            child: SingleChildScrollView(
              padding: const EdgeInsets.fromLTRB(
                24,
                20,
                24,
                32,
              ),
              child: Column(
                crossAxisAlignment:
                    CrossAxisAlignment.stretch,
                children: [
                  // ==================================================
                  // HEADER
                  // ==================================================

                  Container(
                    padding:
                        const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: colors.primaryContainer
                          .withValues(alpha: 0.35),
                      borderRadius:
                          BorderRadius.circular(28),
                      border: Border.all(
                        color:
                            colors.outlineVariant,
                      ),
                    ),
                    child: Column(
                      children: [
                        Container(
                          width: 76,
                          height: 76,
                          decoration:
                              BoxDecoration(
                            color:
                                colors.primaryContainer,
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.location_on_rounded,
                            size: 40,
                            color:
                                colors.primary,
                          ),
                        ),

                        const SizedBox(height: 18),

                        Text(
                          'Location Services',
                          textAlign:
                              TextAlign.center,
                          style: theme
                              .textTheme
                              .headlineSmall
                              ?.copyWith(
                            fontWeight:
                                FontWeight.w800,
                          ),
                        ),

                        const SizedBox(height: 8),

                        Text(
                          'Manage location access used by '
                          'LifeLynk AI to find nearby emergency '
                          'resources and improve your response.',
                          textAlign:
                              TextAlign.center,
                          style: theme
                              .textTheme
                              .bodyMedium
                              ?.copyWith(
                            color: colors
                                .onSurfaceVariant,
                            height: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // STATUS
                  // ==================================================

                  Container(
                    padding:
                        const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: colors.surface,
                      borderRadius:
                          BorderRadius.circular(20),
                      border: Border.all(
                        color:
                            colors.outlineVariant,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration:
                              BoxDecoration(
                            color: locationReady
                                ? Colors.green
                                    .withValues(
                                    alpha: 0.10,
                                  )
                                : colors
                                    .surfaceContainerHighest,
                            borderRadius:
                                BorderRadius.circular(
                              14,
                            ),
                          ),
                          child: Icon(
                            _statusIcon,
                            color: locationReady
                                ? Colors.green
                                : colors.primary,
                          ),
                        ),

                        const SizedBox(width: 14),

                        Expanded(
                          child: Column(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Location Status',
                                style: theme
                                    .textTheme
                                    .titleMedium
                                    ?.copyWith(
                                  fontWeight:
                                      FontWeight.w700,
                                ),
                              ),
                              const SizedBox(height: 4),
                              Text(
                                _statusText,
                                style: theme
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

                        if (!_isLoading)
                          Icon(
                            locationReady
                                ? Icons
                                    .check_circle_rounded
                                : Icons
                                    .error_outline_rounded,
                            color: locationReady
                                ? Colors.green
                                : colors.error,
                          ),
                      ],
                    ),
                  ),

                  const SizedBox(height: 24),

                  // ==================================================
                  // ENABLE
                  // ==================================================

                  if (!_isLoading && !locationReady)
                    FilledButton.icon(
                      onPressed:
                          _requestLocationPermission,
                      icon: const Icon(
                        Icons.location_on_rounded,
                      ),
                      label: const Text(
                        'Enable Location',
                      ),
                      style:
                          FilledButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(
                          54,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                        ),
                      ),
                    ),

                  if (!_isLoading && !locationReady)
                    const SizedBox(height: 12),

                  // ==================================================
                  // TEST CURRENT LOCATION
                  // ==================================================

                  if (!_isLoading && locationReady)
                    OutlinedButton.icon(
                      onPressed:
                          _testCurrentLocation,
                      icon: const Icon(
                        Icons.my_location_rounded,
                      ),
                      label: const Text(
                        'Test Current Location',
                      ),
                      style:
                          OutlinedButton.styleFrom(
                        minimumSize:
                            const Size.fromHeight(
                          54,
                        ),
                        shape:
                            RoundedRectangleBorder(
                          borderRadius:
                              BorderRadius.circular(
                            16,
                          ),
                        ),
                      ),
                    ),

                  if (!_isLoading && locationReady)
                    const SizedBox(height: 12),

                  // ==================================================
                  // DEVICE SETTINGS
                  // ==================================================

                  OutlinedButton.icon(
                    onPressed: _isLoading
                        ? null
                        : _openLocationSettings,
                    icon: const Icon(
                      Icons.settings_outlined,
                    ),
                    label: const Text(
                      'Open Device Location Settings',
                    ),
                    style:
                        OutlinedButton.styleFrom(
                      minimumSize:
                          const Size.fromHeight(
                        54,
                      ),
                      shape:
                          RoundedRectangleBorder(
                        borderRadius:
                            BorderRadius.circular(
                          16,
                        ),
                      ),
                    ),
                  ),

                  const SizedBox(height: 28),

                  // ==================================================
                  // WHY LOCATION
                  // ==================================================

                  Text(
                    'Why LifeLynk AI uses your location',
                    style: theme
                        .textTheme
                        .titleMedium
                        ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
                  ),

                  const SizedBox(height: 12),

                  const _LocationFeature(
                    icon:
                        Icons.local_hospital_outlined,
                    title: 'Nearby hospitals',
                    description:
                        'Find hospitals close to your emergency location.',
                  ),

                  const _LocationFeature(
                    icon:
                        Icons.bloodtype_outlined,
                    title: 'Nearby blood banks',
                    description:
                        'Locate blood banks and available resources nearby.',
                  ),

                  const _LocationFeature(
                    icon:
                        Icons.volunteer_activism_outlined,
                    title: 'Nearby donors',
                    description:
                        'Help identify available donors in your area.',
                  ),

                  const _LocationFeature(
                    icon:
                        Icons.sos_rounded,
                    title: 'Emergency SOS',
                    description:
                        'Share your approximate location during emergency requests.',
                  ),

                  const SizedBox(height: 16),

                  // ==================================================
                  // PRIVACY
                  // ==================================================

                  Container(
                    padding:
                        const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: colors
                          .surfaceContainerHighest,
                      borderRadius:
                          BorderRadius.circular(18),
                    ),
                    child: Row(
                      crossAxisAlignment:
                          CrossAxisAlignment.start,
                      children: [
                        Icon(
                          Icons
                              .privacy_tip_outlined,
                          size: 20,
                          color:
                              colors.primary,
                        ),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            'Your location is used to provide '
                            'location-based emergency features. '
                            'You can manage location permissions '
                            'at any time from your device settings.',
                            style: theme
                                .textTheme
                                .bodySmall
                                ?.copyWith(
                              color: colors
                                  .onSurfaceVariant,
                              height: 1.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// LOCATION FEATURE
// ============================================================================

class _LocationFeature extends StatelessWidget {
  final IconData icon;
  final String title;
  final String description;

  const _LocationFeature({
    required this.icon,
    required this.title,
    required this.description,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Padding(
      padding:
          const EdgeInsets.only(bottom: 12),
      child: Row(
        crossAxisAlignment:
            CrossAxisAlignment.start,
        children: [
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: colors.primaryContainer,
              borderRadius:
                  BorderRadius.circular(12),
            ),
            child: Icon(
              icon,
              size: 21,
              color:
                  colors.onPrimaryContainer,
            ),
          ),

          const SizedBox(width: 12),

          Expanded(
            child: Column(
              crossAxisAlignment:
                  CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: theme
                      .textTheme
                      .titleSmall
                      ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  description,
                  style: theme
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                    color: colors
                        .onSurfaceVariant,
                    height: 1.4,
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