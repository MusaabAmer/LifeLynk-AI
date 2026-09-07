import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:latlong2/latlong.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/routes.dart';

import '../../providers/dashboard_provider.dart';

import '../widgets/dashboard_appbar.dart';
import '../widgets/quick_action_card.dart';
import '../widgets/section_title.dart';
import '../widgets/reservation_card.dart';
import '../widgets/notification_card.dart';
import '../widgets/dashboard_loading.dart';
import '../widgets/empty_state.dart';

import '../../../notifications/presentation/providers/notification_provider.dart';

import '../../../sos/services/emergency_location_service.dart';
import '../../../sos/presentation/widgets/emergency_map.dart';
import '../../../sos/presentation/providers/sos_provider.dart';

class HomeScreen extends StatefulWidget {
  final VoidCallback onSearchBlood;
  final VoidCallback onCreateSos;
  final VoidCallback onProfileTap;

  const HomeScreen({
    super.key,
    required this.onSearchBlood,
    required this.onCreateSos,
    required this.onProfileTap,
  });

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  // ============================================================
  // SERVICES
  // ============================================================

  final EmergencyLocationService _locationService =
      EmergencyLocationService();

  // ============================================================
  // LOCATION STATE
  // ============================================================

  LatLng? _currentLocation;

  bool _isLoadingLocation = true;

  String? _locationError;

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

      _initializeDashboard();
    });
  }

  // ============================================================
  // INITIALIZE DASHBOARD
  // ============================================================

  Future<void> _initializeDashboard() async {
    if (!mounted) {
      return;
    }

    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) {
      await _loadCurrentLocation();
      return;
    }

    final dashboard =
        context.read<DashboardProvider>();

    await Future.wait([
      dashboard.loadDashboard(user.id),
      _loadCurrentLocation(),
    ]);
  }

  // ============================================================
  // LOAD CURRENT GPS LOCATION
  // ============================================================

  Future<void> _loadCurrentLocation() async {
    if (!mounted) {
      return;
    }

    setState(() {
      _isLoadingLocation = true;
      _locationError = null;
    });

    try {
      final position =
          await _locationService.getCurrentLocation();

      if (!mounted) {
        return;
      }

      setState(() {
        _currentLocation = LatLng(
          position.latitude,
          position.longitude,
        );

        _isLoadingLocation = false;
        _locationError = null;
      });
    } on EmergencyLocationException catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingLocation = false;
        _locationError = error.message;
      });
    } catch (error) {
      if (!mounted) {
        return;
      }

      setState(() {
        _isLoadingLocation = false;
        _locationError =
            'Unable to determine your current location.';
      });

      debugPrint(
        'HomeScreen location error: $error',
      );
    }
  }

  // ============================================================
  // OPEN FULL EMERGENCY MAP
  // ============================================================

  void _openFullEmergencyMap() {
    final location = _currentLocation;

    if (location == null) {
      _showLocationMessage();
      return;
    }

    final sosProvider =
        context.read<SosProvider>();

    context.push(
      Routes.emergencyMap,
      extra: {
        // Real GPS location.
        'initialLocation': location,

        // Real resources supplied by SosProvider.
        //
        // SosProvider
        //      ↓
        // NearbyResourceService
        //      ↓
        // Supabase
        //
        // Includes:
        // - hospitals
        // - blood banks
        // - donors
        'resources': sosProvider.nearbyResources,
      },
    );
  }

  // ============================================================
  // LOCATION MESSAGE
  // ============================================================

  void _showLocationMessage() {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        const SnackBar(
          content: Text(
            'Your current location is unavailable.',
          ),
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final dashboard =
        context.watch<DashboardProvider>();

    final sosProvider =
        context.watch<SosProvider>();

    final notificationProvider =
        context.watch<NotificationProvider>();

    return Scaffold(
      appBar: DashboardAppBar(
        userName: dashboard.userName.isEmpty
            ? 'User'
            : dashboard.userName,
        profileImage: dashboard.profileImage,
        onProfileTap: widget.onProfileTap,
      ),
      body: _buildBody(
        dashboard,
        sosProvider,
        notificationProvider,
      ),
    );
  }

  // ============================================================
  // BODY
  // ============================================================

  Widget _buildBody(
    DashboardProvider dashboard,
    SosProvider sosProvider,
    NotificationProvider notificationProvider,
  ) {
    if (dashboard.isLoading) {
      return const DashboardLoading();
    }

    if (dashboard.errorMessage != null) {
      return _buildErrorState(
        dashboard,
      );
    }

    return RefreshIndicator(
      color: AppColors.primary,
      onRefresh: _refreshDashboard,
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(
          20,
          8,
          20,
          30,
        ),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.start,
          children: [
            _buildGreeting(
              dashboard,
            ),

            const SizedBox(height: 20),

            _buildHealthOverview(
              dashboard,
            ),

            const SizedBox(height: 22),

            _buildEmergencyCard(),

            const SizedBox(height: 26),

            _buildDashboardMap(
              sosProvider,
            ),

            const SizedBox(height: 28),

            const SectionTitle(
              title: 'Quick Actions',
            ),

            const SizedBox(height: 12),

            _buildQuickActions(),

            const SizedBox(height: 28),

            const SectionTitle(
              title: 'Recent Reservation',
            ),

            const SizedBox(height: 12),

            _buildReservation(
              dashboard,
            ),

            const SizedBox(height: 28),

            // ==================================================
            // NOTIFICATIONS
            // ==================================================

            SectionTitle(
              title: 'Latest Notifications',
              badgeCount:
                  notificationProvider.unreadCount,
              onSeeAll: () {
                context.push(
                  Routes.notifications,
                );
              },
            ),

            const SizedBox(height: 12),

            _buildNotifications(
              notificationProvider,
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // REFRESH DASHBOARD
  // ============================================================

  Future<void> _refreshDashboard() async {
    final user =
        Supabase.instance.client.auth.currentUser;

    if (user == null) {
      await _loadCurrentLocation();
      return;
    }

    if (!mounted) {
      return;
    }

    final dashboard =
        context.read<DashboardProvider>();

    final notifications =
        context.read<NotificationProvider>();

    await Future.wait([
      dashboard.refreshDashboard(
        user.id,
      ),
      notifications.refreshNotifications(),
      _loadCurrentLocation(),
    ]);
  }

  // ============================================================
  // DASHBOARD MAP
  // ============================================================

  Widget _buildDashboardMap(
    SosProvider sosProvider,
  ) {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        _buildMapSectionHeader(),

        const SizedBox(height: 12),

        if (_isLoadingLocation)
          _buildMapLoadingState()
        else if (_currentLocation == null)
          _buildMapLocationError()
        else
          EmergencyMap(
            currentLocation:
                _currentLocation!,
            resources:
                sosProvider.nearbyResources,
            height: 360,
            showMyLocationButton: true,
          ),
      ],
    );
  }

  // ============================================================
  // MAP HEADER
  // ============================================================

  Widget _buildMapSectionHeader() {
    return LayoutBuilder(
      builder: (context, constraints) {
        final width = constraints.maxWidth;

        if (width < 390) {
          return Column(
            crossAxisAlignment:
                CrossAxisAlignment.start,
            children: [
              const SectionTitle(
                title: 'Nearby Blood Resources',
              ),

              const SizedBox(height: 4),

              Align(
                alignment:
                    Alignment.centerRight,
                child: TextButton.icon(
                  onPressed:
                      _currentLocation == null
                          ? null
                          : _openFullEmergencyMap,
                  icon: const Icon(
                    Icons.map_rounded,
                    size: 18,
                  ),
                  label: const Text(
                    'View Map',
                  ),
                ),
              ),
            ],
          );
        }

        return Row(
          crossAxisAlignment:
              CrossAxisAlignment.center,
          children: [
            Expanded(
              child: Text(
                'Nearby Blood Resources',
                maxLines: 1,
                overflow:
                    TextOverflow.ellipsis,
                style: Theme.of(context)
                    .textTheme
                    .titleMedium
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
              ),
            ),

            const SizedBox(width: 4),

            TextButton.icon(
              onPressed:
                  _currentLocation == null
                      ? null
                      : _openFullEmergencyMap,
              icon: const Icon(
                Icons.map_rounded,
                size: 18,
              ),
              label: const Text(
                'View Map',
              ),
            ),
          ],
        );
      },
    );
  }

  // ============================================================
  // MAP LOADING STATE
  // ============================================================

  Widget _buildMapLoadingState() {
    return Container(
      height: 360,
      width: double.infinity,
      clipBehavior:
          Clip.antiAlias,
      decoration: BoxDecoration(
        color: Theme.of(context)
            .colorScheme
            .surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(24),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            const SizedBox(
              width: 28,
              height: 28,
              child:
                  CircularProgressIndicator(
                strokeWidth: 3,
              ),
            ),

            const SizedBox(height: 14),

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 24,
              ),
              child: Text(
                'Getting your location...',
                textAlign:
                    TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w600,
                    ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ============================================================
  // MAP LOCATION ERROR
  // ============================================================

  Widget _buildMapLocationError() {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      height: 360,
      width: double.infinity,
      clipBehavior:
          Clip.antiAlias,
      decoration: BoxDecoration(
        color:
            colors.surfaceContainerHighest,
        borderRadius:
            BorderRadius.circular(24),
      ),
      child: Center(
        child: SingleChildScrollView(
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
                  size: 28,
                ),
              ),

              const SizedBox(height: 14),

              Text(
                'Location unavailable',
                textAlign:
                    TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .titleSmall
                    ?.copyWith(
                      fontWeight:
                          FontWeight.w800,
                    ),
              ),

              const SizedBox(height: 7),

              Padding(
                padding:
                    const EdgeInsets.symmetric(
                  horizontal: 8,
                ),
                child: Text(
                  _locationError ??
                      'Unable to determine your current location.',
                  textAlign:
                      TextAlign.center,
                  style: Theme.of(context)
                      .textTheme
                      .bodySmall
                      ?.copyWith(
                        color:
                            colors.onSurfaceVariant,
                        height: 1.4,
                      ),
                ),
              ),

              const SizedBox(height: 16),

              FilledButton.icon(
                onPressed:
                    _loadCurrentLocation,
                icon: const Icon(
                  Icons.my_location_rounded,
                  size: 18,
                ),
                label: const Text(
                  'Try Again',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ============================================================
  // GREETING
  // ============================================================

  Widget _buildGreeting(
    DashboardProvider dashboard,
  ) {
    final name =
        dashboard.userName.isEmpty
            ? 'there'
            : dashboard.userName;

    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Text(
          'Welcome back, $name 👋',
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .headlineSmall
              ?.copyWith(
                fontWeight:
                    FontWeight.w800,
                letterSpacing: -0.5,
              ),
        ),

        const SizedBox(height: 6),

        Text(
          'Let’s make a difference together.',
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style: Theme.of(context)
              .textTheme
              .bodyMedium
              ?.copyWith(
                color:
                    Colors.grey.shade600,
              ),
        ),
      ],
    )
        .animate()
        .fadeIn(
          duration: 450.ms,
        )
        .slideY(
          begin: 0.15,
          end: 0,
        );
  }

  // ============================================================
  // HEALTH OVERVIEW
  // ============================================================

  Widget _buildHealthOverview(
    DashboardProvider dashboard,
  ) {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _ModernStatCard(
            icon:
                Icons.bloodtype_rounded,
            title:
                'Blood Group',
            value:
                dashboard.bloodGroup.isEmpty
                    ? '-'
                    : dashboard.bloodGroup,
            subtitle:
                'Your blood type',
            iconColor:
                AppColors.primary,
          )
              .animate()
              .fadeIn(
                delay: 100.ms,
              )
              .slideX(
                begin: -0.08,
              ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: _ModernStatCard(
            icon:
                Icons.favorite_rounded,
            title:
                'Donor Status',
            value:
                dashboard.donorAvailable
                    ? 'Available'
                    : 'Unavailable',
            subtitle:
                dashboard.donorAvailable
                    ? 'Ready to help'
                    : 'Not available',
            iconColor:
                AppColors.success,
          )
              .animate()
              .fadeIn(
                delay: 150.ms,
              )
              .slideX(
                begin: 0.08,
              ),
        ),
      ],
    );
  }

  // ============================================================
  // EMERGENCY CARD
  // ============================================================

  Widget _buildEmergencyCard() {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(22),
      clipBehavior:
          Clip.antiAlias,
      decoration: BoxDecoration(
        borderRadius:
            BorderRadius.circular(24),
        gradient:
            LinearGradient(
          begin:
              Alignment.topLeft,
          end:
              Alignment.bottomRight,
          colors: [
            AppColors.primary,
            AppColors.primary
                .withAlpha(210),
          ],
        ),
        boxShadow: [
          BoxShadow(
            color: AppColors.primary
                .withAlpha(55),
            blurRadius: 20,
            offset:
                const Offset(0, 10),
          ),
        ],
      ),
      child: LayoutBuilder(
        builder: (
          context,
          constraints,
        ) {
          final isNarrow =
              constraints.maxWidth < 360;

          if (isNarrow) {
            return _buildNarrowEmergencyCard();
          }

          return _buildWideEmergencyCard();
        },
      ),
    )
        .animate()
        .fadeIn(
          delay: 200.ms,
        )
        .slideY(
          begin: 0.08,
        );
  }

  // ============================================================
  // WIDE EMERGENCY CARD
  // ============================================================

  Widget _buildWideEmergencyCard() {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.center,
      children: [
        _buildEmergencyIcon(),

        const SizedBox(width: 16),

        Expanded(
          child:
              _buildEmergencyText(),
        ),

        const SizedBox(width: 8),

        _buildSosButton(),
      ],
    );
  }

  // ============================================================
  // NARROW EMERGENCY CARD
  // ============================================================

  Widget _buildNarrowEmergencyCard() {
    return Column(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            _buildEmergencyIcon(),

            const SizedBox(width: 14),

            Expanded(
              child:
                  _buildEmergencyText(),
            ),
          ],
        ),

        const SizedBox(height: 18),

        Align(
          alignment:
              Alignment.centerRight,
          child:
              _buildSosButton(),
        ),
      ],
    );
  }

  // ============================================================
  // EMERGENCY ICON
  // ============================================================

  Widget _buildEmergencyIcon() {
    return Container(
      width: 58,
      height: 58,
      decoration:
          BoxDecoration(
        color:
            Colors.white.withAlpha(28),
        shape:
            BoxShape.circle,
      ),
      child: const Icon(
        Icons.emergency_rounded,
        color:
            Colors.white,
        size: 30,
      ),
    );
  }

  // ============================================================
  // EMERGENCY TEXT
  // ============================================================

  Widget _buildEmergencyText() {
    return Column(
      mainAxisSize:
          MainAxisSize.min,
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        const Text(
          'Need Blood Urgently?',
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style: TextStyle(
            color:
                Colors.white,
            fontSize: 18,
            fontWeight:
                FontWeight.w800,
          ),
        ),

        const SizedBox(height: 5),

        Text(
          'Send an emergency blood request.',
          maxLines: 2,
          overflow:
              TextOverflow.ellipsis,
          style: TextStyle(
            color:
                Colors.white.withAlpha(220),
            fontSize: 13,
          ),
        ),
      ],
    );
  }

  // ============================================================
  // SOS BUTTON
  // ============================================================

  Widget _buildSosButton() {
    return Material(
      color:
          Colors.white,
      borderRadius:
          BorderRadius.circular(14),
      child: InkWell(
        borderRadius:
            BorderRadius.circular(14),
        onTap:
            widget.onCreateSos,
        child: const Padding(
          padding:
              EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 11,
          ),
          child: Text(
            'SOS',
            style: TextStyle(
              color:
                  AppColors.primary,
              fontWeight:
                  FontWeight.w800,
            ),
          ),
        ),
      ),
    );
  }

  // ============================================================
  // QUICK ACTIONS
  // ============================================================

  Widget _buildQuickActions() {
    return Row(
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Expanded(
          child: QuickActionCard(
            icon:
                Icons.search_rounded,
            title:
                'Search Blood',
            color:
                AppColors.info,
            onTap:
                widget.onSearchBlood,
          )
              .animate()
              .fadeIn(
                delay: 250.ms,
              )
              .slideY(
                begin: 0.1,
              ),
        ),

        const SizedBox(width: 12),

        Expanded(
          child: QuickActionCard(
            icon:
                Icons.volunteer_activism_rounded,
            title:
                'Donate Blood',
            color:
                AppColors.primary,
            onTap: () {
              final dashboard =
                  context.read<
                      DashboardProvider>();

              if (dashboard.donorAvailable) {
                context.push(
                  Routes.donorProfile,
                );
              } else {
                context.push(
                  Routes.becomeDonor,
                );
              }
            },
          )
              .animate()
              .fadeIn(
                delay: 300.ms,
              )
              .slideY(
                begin: 0.1,
              ),
        ),
      ],
    );
  }

  // ============================================================
  // RESERVATION
  // ============================================================

  Widget _buildReservation(
    DashboardProvider dashboard,
  ) {
    final reservation =
        dashboard.latestReservation;

    if (reservation == null) {
      return _buildEmptyContainer(
        child: const EmptyState(
          animation:
              'assets/animations/empty_requests.json',
          message:
              'No blood reservations yet',
        ),
      );
    }

    final organizationName =
        reservation['organization_name']
                ?.toString()
                .trim() ??
            '';

    final hospitalName =
        reservation['hospital_name']
                ?.toString()
                .trim() ??
            '';

    final displayOrganization =
        hospitalName.isNotEmpty
            ? hospitalName
            : organizationName.isNotEmpty
                ? organizationName
                : 'Blood organization';

    final bloodGroup =
        reservation['blood_group']
                ?.toString()
                .trim() ??
            '';

    final status =
        reservation['status']
                ?.toString()
                .trim() ??
            '';

    return ReservationCard(
      bloodGroup:
          bloodGroup.isEmpty
              ? '-'
              : bloodGroup,
      hospitalName:
          displayOrganization,
      status:
          status.isEmpty
              ? 'Pending'
              : status,
      onTap: () {},
    )
        .animate()
        .fadeIn(
          delay: 350.ms,
        )
        .slideY(
          begin: 0.08,
        );
  }

  // ============================================================
  // NOTIFICATIONS
  // ============================================================

  Widget _buildNotifications(
    NotificationProvider provider,
  ) {
    if (provider.loading &&
        provider.notifications.isEmpty) {
      return _buildEmptyContainer(
        child: const Padding(
          padding:
              EdgeInsets.all(20),
          child: Center(
            child:
                CircularProgressIndicator(),
          ),
        ),
      );
    }

    if (provider.notifications.isEmpty) {
      return _buildEmptyContainer(
        child: const EmptyState(
          animation:
              'assets/animations/no_notifications.json',
          message:
              'No notifications available',
        ),
      );
    }

    final latestNotifications =
        provider.notifications
            .take(5)
            .toList();

    return Column(
      children:
          latestNotifications.map(
        (notification) {
          return Padding(
            padding:
                const EdgeInsets.only(
              bottom: 10,
            ),
            child: NotificationCard(
              title:
                  notification.title,
              message:
                  notification.message,
              time:
                  notification.createdAt
                      .toString(),
              onTap: () async {
                if (!notification.isRead) {
                  await provider.markAsRead(
                    notification.id,
                  );
                }
              },
            ),
          );
        },
      ).toList(),
    );
  }

  // ============================================================
  // EMPTY CONTAINER
  // ============================================================

  Widget _buildEmptyContainer({
    required Widget child,
  }) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(12),
      decoration:
          BoxDecoration(
        color:
            Theme.of(context)
                .cardColor,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color:
              Colors.grey.withAlpha(25),
        ),
      ),
      child: child,
    );
  }

  // ============================================================
  // ERROR STATE
  // ============================================================

  Widget _buildErrorState(
    DashboardProvider dashboard,
  ) {
    return Center(
      child: SingleChildScrollView(
        padding:
            const EdgeInsets.all(30),
        child: Column(
          mainAxisAlignment:
              MainAxisAlignment.center,
          children: [
            Container(
              width: 80,
              height: 80,
              decoration:
                  BoxDecoration(
                color: AppColors.primary
                    .withAlpha(15),
                shape:
                    BoxShape.circle,
              ),
              child: const Icon(
                Icons.cloud_off_rounded,
                size: 38,
                color:
                    AppColors.primary,
              ),
            ),

            const SizedBox(height: 20),

            Text(
              'Something went wrong',
              textAlign:
                  TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleLarge
                  ?.copyWith(
                    fontWeight:
                        FontWeight.w700,
                  ),
            ),

            const SizedBox(height: 8),

            Padding(
              padding:
                  const EdgeInsets.symmetric(
                horizontal: 10,
              ),
              child: Text(
                dashboard.errorMessage ??
                    'Unable to load dashboard.',
                textAlign:
                    TextAlign.center,
                style: Theme.of(context)
                    .textTheme
                    .bodyMedium
                    ?.copyWith(
                      color:
                          Colors.grey.shade600,
                    ),
              ),
            ),

            const SizedBox(height: 22),

            FilledButton.icon(
              onPressed: () async {
                final user =
                    Supabase.instance.client
                        .auth
                        .currentUser;

                if (user == null ||
                    !mounted) {
                  return;
                }

                final dashboard =
                    context.read<
                        DashboardProvider>();

                final notifications =
                    context.read<
                        NotificationProvider>();

                await Future.wait([
                  dashboard.loadDashboard(
                    user.id,
                  ),
                  notifications
                      .refreshNotifications(),
                  _loadCurrentLocation(),
                ]);
              },
              icon: const Icon(
                Icons.refresh_rounded,
              ),
              label: const Text(
                'Try Again',
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ============================================================================
// MODERN STAT CARD
// ============================================================================

class _ModernStatCard
    extends StatelessWidget {
  final IconData icon;
  final String title;
  final String value;
  final String subtitle;
  final Color iconColor;

  const _ModernStatCard({
    required this.icon,
    required this.title,
    required this.value,
    required this.subtitle,
    required this.iconColor,
  });

  @override
  Widget build(
    BuildContext context,
  ) {
    return Container(
      width: double.infinity,
      padding:
          const EdgeInsets.all(16),
      decoration:
          BoxDecoration(
        color:
            Theme.of(context).cardColor,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color:
              Colors.grey.withAlpha(25),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withAlpha(5),
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
                      iconColor.withAlpha(
                    18,
                  ),
                  borderRadius:
                      BorderRadius.circular(
                    13,
                  ),
                ),
                child: Icon(
                  icon,
                  color:
                      iconColor,
                  size: 22,
                ),
              ),

              const Spacer(),

              Icon(
                Icons
                    .arrow_forward_ios_rounded,
                size: 13,
                color:
                    Colors.grey.shade400,
              ),
            ],
          ),

          const SizedBox(height: 14),

          Text(
            title,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color:
                      Colors.grey.shade600,
                  fontWeight:
                      FontWeight.w500,
                ),
          ),

          const SizedBox(height: 4),

          Text(
            value,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .titleMedium
                ?.copyWith(
                  fontWeight:
                      FontWeight.w800,
                ),
          ),

          const SizedBox(height: 3),

          Text(
            subtitle,
            maxLines: 1,
            overflow:
                TextOverflow.ellipsis,
            style: Theme.of(context)
                .textTheme
                .bodySmall
                ?.copyWith(
                  color:
                      Colors.grey.shade500,
                  fontSize: 11,
                ),
          ),
        ],
      ),
    );
  }
}