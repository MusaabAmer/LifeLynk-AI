import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../data/models/blood_inventory_model.dart';
import '../../data/models/organization_detail_model.dart';
import '../../data/repositories/blood_reservation_repository.dart';
import '../../data/repositories/organization_repository.dart';
import '../../../sos/data/repositories/sos_repository.dart';
import '../../../sos/services/emergency_location_service.dart';
import '../widgets/blood_inventory_grid.dart';
import '../widgets/contact_card.dart';
import '../widgets/organization_actions.dart';
import '../widgets/organization_header.dart';
import '../widgets/rating_card.dart';
import '../widgets/services_wrap.dart';

class OrganizationDetailScreen extends StatefulWidget {
  final String organizationId;

  const OrganizationDetailScreen({
    super.key,
    required this.organizationId,
  });

  @override
  State<OrganizationDetailScreen> createState() =>
      _OrganizationDetailScreenState();
}

class _OrganizationDetailScreenState
    extends State<OrganizationDetailScreen> {
  late final OrganizationRepository _repository;
  late final BloodReservationRepository _reservationRepository;
  late final SosRepository _sosRepository;
  late final EmergencyLocationService _locationService;

  OrganizationDetailModel? _organization;

  bool _isLoading = true;
  bool _isReserving = false;
  bool _isSendingEmergency = false;

  String? _errorMessage;

  void _debugAuthenticatedUser() {
    final user = Supabase.instance.client.auth.currentUser;

    debugPrint('========================================');
    debugPrint('AUTH USER ID: ${user?.id}');
    debugPrint('AUTH USER EMAIL: ${user?.email}');
    debugPrint('========================================');
  }

  @override
  void initState() {
    super.initState();

    _repository = OrganizationRepository();

    _reservationRepository = BloodReservationRepository();

    _sosRepository = SosRepository(
      supabase: Supabase.instance.client,
    );

    _locationService = EmergencyLocationService();

    _loadOrganizationDetails();
  }

  Future<void> _loadOrganizationDetails() async {
    if (mounted) {
      setState(() {
        _isLoading = true;
        _errorMessage = null;
      });
    }

    try {
      final organization =
          await _repository.fetchOrganizationDetails(
        widget.organizationId,
      );

      if (!mounted) return;

      if (organization == null) {
        setState(() {
          _isLoading = false;
          _errorMessage =
              'Organization details are unavailable.';
        });

        return;
      }

      setState(() {
        _organization = organization;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;

      setState(() {
        _isLoading = false;
        _errorMessage =
            'Unable to load organization details.';
      });

      debugPrint(
        'Organization detail error: $e',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Organization Details',
        ),
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(),
      );
    }

    if (_errorMessage != null) {
      return _buildErrorState();
    }

    final organization = _organization;

    if (organization == null) {
      return const Center(
        child: Text(
          'Organization details are unavailable.',
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _loadOrganizationDetails,
      child: SingleChildScrollView(
        physics:
            const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            OrganizationHeader(
              organization: organization,
            ),
            const SizedBox(height: 16),
            ContactCard(
              organization: organization,
            ),
            const SizedBox(height: 16),
            if (organization.reviewCount > 0) ...[
              RatingCard(
                rating: organization.rating,
                reviewCount:
                    organization.reviewCount,
              ),
              const SizedBox(height: 16),
            ],
            BloodInventoryGrid(
              inventory: organization.inventory,
            ),
            const SizedBox(height: 16),
            if (organization.services.isNotEmpty) ...[
              ServicesWrap(
                services: organization.services,
              ),
              const SizedBox(height: 16),
            ],
            OrganizationActions(
              canReserve: _canReserve,
              canCall: _hasPhone,
              canOpenDirections:
                  _hasCoordinates,
              isReserving: _isReserving,
              isEmergencyRequesting:
                  _isSendingEmergency,
              onReserve: _isReserving
                  ? null
                  : _onReserve,
              onEmergencyRequest:
                  _isSendingEmergency
                      ? null
                      : _onEmergencyRequest,
              onCall: _onCall,
              onDirections: _onDirections,
              onShare: _onShare,
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }

  Widget _buildErrorState() {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.error_outline,
              size: 56,
              color: Colors.grey.shade600,
            ),
            const SizedBox(height: 16),
            Text(
              _errorMessage ??
                  'Something went wrong.',
              textAlign: TextAlign.center,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium,
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed:
                  _loadOrganizationDetails,
              icon: const Icon(Icons.refresh),
              label:
                  const Text('Try Again'),
            ),
          ],
        ),
      ),
    );
  }

  bool get _hasPhone {
    final phone = _organization?.phone;

    return phone != null &&
        phone.trim().isNotEmpty;
  }

  bool get _hasCoordinates {
    final organization = _organization;

    if (organization == null) {
      return false;
    }

    final latitude = organization.latitude;
    final longitude = organization.longitude;

    return latitude != null &&
        longitude != null &&
        latitude != 0 &&
        longitude != 0;
  }

  bool get _canReserve {
    final organization = _organization;

    if (organization == null) {
      return false;
    }

    return organization.inventory.any(
      (item) => item.availableUnits > 0,
    );
  }

  // ============================================================
  // CALL
  // ============================================================

  Future<void> _onCall() async {
    final organization = _organization;

    if (organization == null) {
      return;
    }

    final phone = organization.phone?.trim();

    if (phone == null || phone.isEmpty) {
      _showMessage(
        'Phone number is not available.',
      );
      return;
    }

    final cleanedPhone = phone.replaceAll(
      RegExp(r'[^0-9+]'),
      '',
    );

    if (cleanedPhone.isEmpty) {
      _showMessage(
        'Invalid organization phone number.',
      );
      return;
    }

    final uri = Uri(
      scheme: 'tel',
      path: cleanedPhone,
    );

    try {
      final launched =
          await launchUrl(uri);

      if (!launched && mounted) {
        _showMessage(
          'Unable to open the phone dialer.',
        );
      }
    } catch (e) {
      debugPrint(
        'Call error: $e',
      );

      if (mounted) {
        _showMessage(
          'Unable to make the call.',
        );
      }
    }
  }

  // ============================================================
  // DIRECTIONS
  // ============================================================

  Future<void> _onDirections() async {
    final organization = _organization;

    if (organization == null) {
      return;
    }

    final latitude = organization.latitude;
    final longitude = organization.longitude;

    if (latitude == null ||
        longitude == null) {
      _showMessage(
        'Organization location is not available.',
      );
      return;
    }

    final uri = Uri.parse(
      'https://www.google.com/maps/dir/'
      '?api=1'
      '&destination=$latitude,$longitude',
    );

    try {
      final launched = await launchUrl(
        uri,
        mode:
            LaunchMode.externalApplication,
      );

      if (!launched && mounted) {
        _showMessage(
          'Unable to open OpenStreetMap.',
        );
      }
    } catch (e) {
      debugPrint(
        'Directions error: $e',
      );

      if (mounted) {
        _showMessage(
          'Unable to open directions.',
        );
      }
    }
  }

  // ============================================================
  // SHARE
  // ============================================================

  Future<void> _onShare() async {
    final organization = _organization;

    if (organization == null) {
      return;
    }

    final text = [
      organization.organizationName,
      if (organization.organizationType
          .trim()
          .isNotEmpty)
        organization.organizationType,
      if (organization.address
          .trim()
          .isNotEmpty)
        organization.address,
      if (organization.city
          .trim()
          .isNotEmpty)
        organization.city,
      if (organization.phone
              ?.trim()
              .isNotEmpty ??
          false)
        'Phone: ${organization.phone}',
    ].join('\n');

    final uri = Uri(
      scheme: 'sms',
      queryParameters: {
        'body': text,
      },
    );

    try {
      final launched =
          await launchUrl(uri);

      if (!launched && mounted) {
        _showMessage(
          'Unable to open sharing.',
        );
      }
    } catch (e) {
      debugPrint(
        'Share error: $e',
      );

      if (mounted) {
        _showMessage(
          'Unable to share organization.',
        );
      }
    }
  }

  // ============================================================
  // RESERVE BLOOD
  // ============================================================

  Future<void> _onReserve() async {
    final organization = _organization;

    if (organization == null) {
      return;
    }

    if (!_canReserve) {
      _showMessage(
        'No blood is currently available at this organization.',
      );
      return;
    }

    final result =
        await _showReservationDialog(
      organization,
    );

    if (result == null) {
      return;
    }

    final bloodGroupId =
        result['bloodGroupId'] as String;

    final units =
        result['units'] as int;

    final urgency =
        result['urgency'] as String;

    final requiredDate =
        result['requiredDate'] as DateTime;

    final notes =
        result['notes'] as String?;

    /*
     * Do a client-side validation before calling
     * the reservation repository.
     *
     * The backend remains authoritative.
     */
    if (!requiredDate.isAfter(
      DateTime.now(),
    )) {
      _showMessage(
        'Required date must be in the future.',
      );
      return;
    }

    if (mounted) {
      setState(() {
        _isReserving = true;
      });
    }

    try {
      _debugAuthenticatedUser();

      await _reservationRepository.reserveBlood(
        organizationId:
            organization.organizationId,
        bloodGroupId:
            bloodGroupId,
        unitsRequired:
            units,
        urgency:
            urgency,
        requiredDate:
            requiredDate,
        notes:
            notes,
      );

      if (!mounted) return;

      _showMessage(
        'Blood reservation request submitted successfully.',
      );

      /*
       * Refresh the organization inventory
       * using the real database state.
       */
      await _loadOrganizationDetails();
    } catch (e) {
      if (!mounted) return;

      final message = e
          .toString()
          .replaceFirst(
            'Exception: ',
            '',
          );

      _showMessage(message);
    } finally {
      if (mounted) {
        setState(() {
          _isReserving = false;
        });
      }
    }
  }

  Future<Map<String, dynamic>?>
      _showReservationDialog(
    OrganizationDetailModel organization,
  ) async {
    final availableInventory =
        organization.inventory
            .where(
              (item) =>
                  item.availableUnits > 0,
            )
            .toList();

    if (availableInventory.isEmpty) {
      return null;
    }

    return showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) {
        return _ReservationDialog(
          organization: organization,
          availableInventory:
              availableInventory,
        );
      },
    );
  }

  Future<bool> _showEmergencyConfirmation(
  OrganizationDetailModel organization,
) async {
  final result = await showDialog<bool>(
    context: context,
    builder: (dialogContext) {
      return AlertDialog(
        title: const Text('Send Emergency SOS?'),
        content: Text(
          'This will create an emergency blood request for '
          '${organization.organizationName}. '
          'Your current location will be shared with the emergency system.',
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(false);
            },
            child: const Text('Cancel'),
          ),
          FilledButton(
            onPressed: () {
              Navigator.of(dialogContext).pop(true);
            },
            child: const Text('Send SOS'),
          ),
        ],
      );
    },
  );

  return result ?? false;
}

  // ============================================================
  // EMERGENCY REQUEST
  // ============================================================

  Future<void> _onEmergencyRequest() async {
  final organization = _organization;

  if (organization == null) {
    return;
  }

  final user =
      Supabase.instance.client.auth.currentUser;

  if (user == null) {
    _showMessage(
      'Please sign in before sending an emergency request.',
    );
    return;
  }

  final confirmed =
      await _showEmergencyConfirmation(
    organization,
  );

  if (!confirmed) {
    return;
  }

  if (mounted) {
    setState(() {
      _isSendingEmergency = true;
    });
  }

  try {
    final activeSos =
        await _sosRepository.getActiveSos(
      user.id,
    );

    if (activeSos != null &&
        activeSos.isActive) {
      throw Exception(
        'You already have an active emergency SOS request.',
      );
    }

    final bloodGroupId =
        await _sosRepository.getUserBloodGroupId(
      user.id,
    );

    if (bloodGroupId == null ||
        bloodGroupId.trim().isEmpty) {
      throw Exception(
        'Please complete your blood group information before sending an emergency request.',
      );
    }

    final position =
        await _locationService.getCurrentLocation();

    final organizationName =
        organization.organizationName.trim();

    final city =
        organization.city.trim();

    final description = city.isEmpty
        ? 'Emergency blood request for $organizationName.'
        : 'Emergency blood request for $organizationName in $city.';

    await _sosRepository.createSos(
      userId: user.id,
      bloodGroupId: bloodGroupId,
      unitsRequired: 1,
      urgencyLevel: 'critical',
      description: description,
      latitude: position.latitude,
      longitude: position.longitude,
      gpsAccuracy: position.accuracy,
      locationTimestamp: position.timestamp,
    );

    if (!mounted) return;

    _showMessage(
      'Emergency SOS request has been sent successfully.',
    );
  } on EmergencyLocationException catch (e) {
    if (!mounted) return;

    _showMessage(e.message);
  } catch (e) {
    if (!mounted) return;

    final message = e
        .toString()
        .replaceFirst(
          'Exception: ',
          '',
        );

    _showMessage(message);
  } finally {
    if (mounted) {
      setState(() {
        _isSendingEmergency = false;
      });
    }
  }
}

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) return;

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }
}

// ============================================================
// RESERVATION DIALOG
// ============================================================

class _ReservationDialog extends StatefulWidget {
  final OrganizationDetailModel organization;

  final List<BloodInventoryModel> availableInventory;

  const _ReservationDialog({
    required this.organization,
    required this.availableInventory,
  });

  @override
  State<_ReservationDialog> createState() =>
      _ReservationDialogState();
}

class _ReservationDialogState
    extends State<_ReservationDialog> {
  late String selectedBloodGroupId;

  int selectedUnits = 1;

  String selectedUrgency = 'HIGH';

  late DateTime selectedDate;

  /*
   * IMPORTANT:
   *
   * The controller belongs to the dialog itself.
   * It is therefore disposed only when this dialog
   * State is actually disposed.
   *
   * This prevents:
   *
   * "A TextEditingController was used after being disposed."
   */
  final TextEditingController notesController =
      TextEditingController();

  @override
  void initState() {
    super.initState();

    selectedBloodGroupId =
        widget.availableInventory.first.bloodGroupId;

    final now = DateTime.now();

    selectedDate = DateTime(
      now.year,
      now.month,
      now.day + 1,
      12,
    );
  }

  @override
  void dispose() {
    notesController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selectedInventory =
        widget.availableInventory.firstWhere(
      (item) =>
          item.bloodGroupId ==
          selectedBloodGroupId,
      orElse: () =>
          widget.availableInventory.first,
    );

    final maxUnits =
        selectedInventory.availableUnits;

    /*
     * Do not mutate selectedUnits during build().
     *
     * Instead, calculate the value that should be
     * displayed by the dropdown.
     */
    final effectiveSelectedUnits =
        selectedUnits > maxUnits
            ? maxUnits
            : selectedUnits;

    return AlertDialog(
      title: const Text(
        'Reserve Blood',
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment:
              CrossAxisAlignment.stretch,
          children: [
            Text(
              widget.organization
                  .organizationName,
              style: Theme.of(context)
                  .textTheme
                  .titleSmall,
            ),

            const SizedBox(
              height: 16,
            ),

            // --------------------------------------------------
            // BLOOD GROUP
            // --------------------------------------------------

            DropdownButtonFormField<String>(
              initialValue:
                  selectedBloodGroupId,
              decoration:
                  const InputDecoration(
                labelText:
                    'Blood Group',
                border:
                    OutlineInputBorder(),
              ),
              items: widget
                  .availableInventory
                  .map(
                    (item) {
                      return DropdownMenuItem<
                          String>(
                        value:
                            item.bloodGroupId,
                        child: Text(
                          '${item.bloodGroupCode} '
                          '(${item.availableUnits} available)',
                        ),
                      );
                    },
                  )
                  .toList(),
              onChanged: (value) {
                if (value == null ||
                    !mounted) {
                  return;
                }

                setState(() {
                  selectedBloodGroupId =
                      value;
                  selectedUnits = 1;
                });
              },
            ),

            const SizedBox(
              height: 14,
            ),

            // --------------------------------------------------
            // UNITS
            // --------------------------------------------------

            DropdownButtonFormField<int>(
              initialValue:
                  effectiveSelectedUnits,
              decoration:
                  const InputDecoration(
                labelText:
                    'Units Required',
                border:
                    OutlineInputBorder(),
              ),
              items: List.generate(
                maxUnits > 20
                    ? 20
                    : maxUnits,
                (index) {
                  final units =
                      index + 1;

                  return DropdownMenuItem<
                      int>(
                    value: units,
                    child: Text(
                      '$units unit'
                      '${units == 1 ? '' : 's'}',
                    ),
                  );
                },
              ),
              onChanged: (value) {
                if (value == null ||
                    !mounted) {
                  return;
                }

                setState(() {
                  selectedUnits =
                      value;
                });
              },
            ),

            const SizedBox(
              height: 14,
            ),

            // --------------------------------------------------
            // URGENCY
            // --------------------------------------------------

            DropdownButtonFormField<String>(
              initialValue:
                  selectedUrgency,
              decoration:
                  const InputDecoration(
                labelText:
                    'Urgency',
                border:
                    OutlineInputBorder(),
              ),
              items: const [
                DropdownMenuItem(
                  value: 'LOW',
                  child:
                      Text('Low'),
                ),
                DropdownMenuItem(
                  value: 'MEDIUM',
                  child:
                      Text('Medium'),
                ),
                DropdownMenuItem(
                  value: 'HIGH',
                  child:
                      Text('High'),
                ),
                DropdownMenuItem(
                  value: 'CRITICAL',
                  child:
                      Text('Critical'),
                ),
              ],
              onChanged: (value) {
                if (value == null ||
                    !mounted) {
                  return;
                }

                setState(() {
                  selectedUrgency =
                      value;
                });
              },
            ),

            const SizedBox(
              height: 14,
            ),

            // --------------------------------------------------
            // REQUIRED DATE
            // --------------------------------------------------

            ListTile(
              contentPadding:
                  EdgeInsets.zero,
              leading:
                  const Icon(
                Icons.calendar_today,
              ),
              title: const Text(
                'Required Date',
              ),
              subtitle: Text(
                _formatDate(
                  selectedDate,
                ),
              ),
              trailing:
                  const Icon(
                Icons.chevron_right,
              ),
              onTap:
                  _selectDate,
            ),

            const SizedBox(
              height: 8,
            ),

            // --------------------------------------------------
            // NOTES
            // --------------------------------------------------

            TextField(
              controller:
                  notesController,
              maxLines: 3,
              maxLength: 500,
              decoration:
                  const InputDecoration(
                labelText:
                    'Notes',
                hintText:
                    'Additional information',
                border:
                    OutlineInputBorder(),
              ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(
              context,
            ).pop();
          },
          child:
              const Text('Cancel'),
        ),
        FilledButton(
          onPressed: _submit,
          child:
              const Text('Reserve'),
        ),
      ],
    );
  }

  // ============================================================
  // DATE PICKER
  // ============================================================

  Future<void> _selectDate() async {
    final today =
        DateTime.now();

    final tomorrow =
        DateTime(
      today.year,
      today.month,
      today.day + 1,
    );

    final date =
        await showDatePicker(
      context: context,
      firstDate:
          tomorrow,
      lastDate:
          DateTime(
        today.year,
        today.month,
        today.day + 365,
      ),
      initialDate:
          selectedDate,
    );

    if (date == null ||
        !mounted) {
      return;
    }

    setState(() {
      selectedDate =
          DateTime(
        date.year,
        date.month,
        date.day,
        12,
      );
    });
  }

  // ============================================================
  // SUBMIT RESERVATION
  // ============================================================

  void _submit() {
    if (!mounted) {
      return;
    }

    final notes =
        notesController.text.trim();

    Navigator.of(context).pop({
      'bloodGroupId':
          selectedBloodGroupId,
      'units':
          selectedUnits,
      'urgency':
          selectedUrgency,
      'requiredDate':
          selectedDate,
      'notes':
          notes.isEmpty
              ? null
              : notes,
    });
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(
    DateTime date,
  ) {
    final day =
        date.day.toString().padLeft(
              2,
              '0',
            );

    final month =
        date.month.toString().padLeft(
              2,
              '0',
            );

    return '$day/$month/${date.year}';
  }
}

