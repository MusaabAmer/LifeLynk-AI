import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'package:lifelynk_ai/core/router/routes.dart';
import 'package:lifelynk_ai/core/services/supabase_service.dart';

import '../../providers/donor_provider.dart';

class BecomeDonorScreen extends StatefulWidget {
  const BecomeDonorScreen({super.key});

  @override
  State<BecomeDonorScreen> createState() => _BecomeDonorScreenState();
}

class _BecomeDonorScreenState extends State<BecomeDonorScreen> {
  final _formKey = GlobalKey<FormState>();
  final _weightController = TextEditingController();

  DateTime? _dateOfBirth;
  DateTime? _lastDonationDate;

  String _availability = 'available';

  List<Map<String, dynamic>> _provinces = [];
  List<Map<String, dynamic>> _cities = [];

  String? _selectedProvinceId;
  String? _selectedCityId;

  bool _loadingProvinces = true;
  bool _loadingCities = false;

  int _cityLoadRequestId = 0;

  @override
  void initState() {
    super.initState();
    _loadProvinces();
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  // ============================================================
  // LOAD REAL PROVINCES
  // ============================================================

  Future<void> _loadProvinces() async {
    if (!mounted) return;

    setState(() {
      _loadingProvinces = true;
    });

    try {
      final rows = await SupabaseService.client
          .from('provinces')
          .select('id, name, code')
          .order('name');

      if (!mounted) return;

      final loadedProvinces = rows
          .map(
            (row) => Map<String, dynamic>.from(row),
          )
          .where(
            (province) =>
                province['id'] != null &&
                province['name'] != null &&
                province['id'].toString().trim().isNotEmpty &&
                province['name'].toString().trim().isNotEmpty,
          )
          .toList();

      setState(() {
        _provinces = loadedProvinces;
        _loadingProvinces = false;
      });
    } catch (error) {
      if (!mounted) return;

      setState(() {
        _loadingProvinces = false;
      });

      _showMessage(
        'Unable to load provinces: ${_cleanError(error)}',
      );
    }
  }

  // ============================================================
  // LOAD REAL CITIES
  // ============================================================

  Future<void> _loadCities(String provinceId) async {
    final normalizedProvinceId = provinceId.trim();

    if (normalizedProvinceId.isEmpty || !mounted) {
      return;
    }

    final requestId = ++_cityLoadRequestId;

    setState(() {
      _loadingCities = true;
      _cities = [];
      _selectedCityId = null;
    });

    try {
      final rows = await SupabaseService.client
          .from('cities')
          .select('id, name, code, province_id')
          .eq('province_id', normalizedProvinceId)
          .order('name');

      if (!mounted || requestId != _cityLoadRequestId) {
        return;
      }

      final loadedCities = rows
          .map(
            (row) => Map<String, dynamic>.from(row),
          )
          .where(
            (city) =>
                city['id'] != null &&
                city['name'] != null &&
                city['id'].toString().trim().isNotEmpty &&
                city['name'].toString().trim().isNotEmpty,
          )
          .toList();

      setState(() {
        _cities = loadedCities;
        _loadingCities = false;
      });
    } catch (error) {
      if (!mounted || requestId != _cityLoadRequestId) {
        return;
      }

      setState(() {
        _loadingCities = false;
      });

      _showMessage(
        'Unable to load cities: ${_cleanError(error)}',
      );
    }
  }

  // ============================================================
  // GET AUTHORITATIVE PROFILE PHONE
  //
  // public.users.phone_number is the source of truth.
  // ============================================================

  Future<String?> _getProfilePhoneNumber() async {
    final user = Supabase.instance.client.auth.currentUser;

    if (user == null) {
      return null;
    }

    final rows = await SupabaseService.client
        .from('users')
        .select('phone_number')
        .eq('id', user.id)
        .limit(1);

    if (rows.isEmpty) {
      return null;
    }

    final row = Map<String, dynamic>.from(rows.first);
    final phone = row['phone_number'];

    if (phone == null) {
      return null;
    }

    final normalized = phone.toString().trim();

    return normalized.isEmpty ? null : normalized;
  }

  // ============================================================
  // REQUIRE PROFILE PHONE
  // ============================================================

  Future<bool> _ensureProfilePhone() async {
    try {
      final phoneNumber = await _getProfilePhoneNumber();

      if (phoneNumber != null) {
        return true;
      }

      if (!mounted) {
        return false;
      }

      final shouldAddPhone = await showDialog<bool>(
        context: context,
        barrierDismissible: false,
        builder: (dialogContext) {
          final theme = Theme.of(dialogContext);
          final colors = theme.colorScheme;

          return AlertDialog(
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(24),
            ),
            icon: Icon(
              Icons.phone_outlined,
              size: 42,
              color: colors.primary,
            ),
            title: const Text(
              'Phone Number Required',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontWeight: FontWeight.w800,
              ),
            ),
            content: const Text(
              'A phone number is required before you can '
              'register as a blood donor. Add your phone '
              'number to your LifeLynk profile first.',
              textAlign: TextAlign.center,
            ),
            actionsAlignment: MainAxisAlignment.center,
            actions: [
              TextButton(
                onPressed: () {
                  Navigator.of(dialogContext).pop(false);
                },
                child: const Text('Cancel'),
              ),
              FilledButton.icon(
                onPressed: () {
                  Navigator.of(dialogContext).pop(true);
                },
                icon: const Icon(
                  Icons.edit_outlined,
                ),
                label: const Text(
                  'Add Phone Number',
                ),
              ),
            ],
          );
        },
      );

      if (!mounted || shouldAddPhone != true) {
        return false;
      }

      await context.push(
        Routes.personalInformation,
      );

      if (!mounted) {
        return false;
      }

      final updatedPhone = await _getProfilePhoneNumber();

      if (updatedPhone == null) {
        _showMessage(
          'Please add your phone number before becoming a donor.',
        );
        return false;
      }

      return true;
    } catch (error) {
      if (!mounted) {
        return false;
      }

      _showMessage(
        'Unable to verify your profile phone number: '
        '${_cleanError(error)}',
      );

      return false;
    }
  }

  // ============================================================
  // DATE OF BIRTH
  // ============================================================

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();

    final maximumDate = DateTime(
      now.year - 18,
      now.month,
      now.day,
    );

    var initialDate = _dateOfBirth ?? maximumDate;

    if (initialDate.isAfter(maximumDate)) {
      initialDate = maximumDate;
    }

    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: maximumDate,
      initialDate: initialDate,
      builder: (
        context,
        child,
      ) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    setState(() {
      _dateOfBirth = selected;

      if (_lastDonationDate != null &&
          !_lastDonationDate!.isAfter(selected)) {
        _lastDonationDate = null;
      }
    });
  }

  // ============================================================
  // LAST DONATION DATE
  // ============================================================

  Future<void> _pickLastDonationDate() async {
    final now = DateTime.now();

    var firstDate = DateTime(1950);

    if (_dateOfBirth != null) {
      final dayAfterBirth =
          _dateOfBirth!.add(const Duration(days: 1));

      if (dayAfterBirth.isBefore(now) ||
          dayAfterBirth.isAtSameMomentAs(now)) {
        firstDate = dayAfterBirth;
      }
    }

    var initialDate = _lastDonationDate ?? now;

    if (initialDate.isBefore(firstDate)) {
      initialDate = firstDate;
    }

    if (initialDate.isAfter(now)) {
      initialDate = now;
    }

    final selected = await showDatePicker(
      context: context,
      firstDate: firstDate,
      lastDate: now,
      initialDate: initialDate,
      builder: (
        context,
        child,
      ) {
        return Theme(
          data: Theme.of(context).copyWith(
            datePickerTheme: DatePickerThemeData(
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            ),
          ),
          child: child!,
        );
      },
    );

    if (!mounted || selected == null) {
      return;
    }

    if (_dateOfBirth != null &&
        !selected.isAfter(_dateOfBirth!)) {
      _showMessage(
        'Last donation date must be after your date of birth.',
      );
      return;
    }

    setState(() {
      _lastDonationDate = selected;
    });
  }

  // ============================================================
  // DATE FORMAT
  // ============================================================

  String _formatDate(DateTime? date) {
    if (date == null) {
      return 'Select date';
    }

    return '${date.day.toString().padLeft(2, '0')}/'
        '${date.month.toString().padLeft(2, '0')}/'
        '${date.year}';
  }

  // ============================================================
  // SUBMIT
  // ============================================================

  Future<void> _submit() async {
    if (!mounted) {
      return;
    }

    final provider = context.read<DonorProvider>();

    if (provider.loading) {
      return;
    }

    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dateOfBirth == null) {
      _showMessage(
        'Please select your date of birth.',
      );
      return;
    }

    if (_selectedProvinceId == null ||
        _selectedProvinceId!.trim().isEmpty) {
      _showMessage(
        'Please select your province.',
      );
      return;
    }

    if (_selectedCityId == null ||
        _selectedCityId!.trim().isEmpty) {
      _showMessage(
        'Please select your city.',
      );
      return;
    }

    final now = DateTime.now();

    // ==========================================================
    // AGE VALIDATION
    // ==========================================================

    final age = now.year -
        _dateOfBirth!.year -
        ((now.month < _dateOfBirth!.month ||
                (now.month == _dateOfBirth!.month &&
                    now.day < _dateOfBirth!.day))
            ? 1
            : 0);

    if (age < 18) {
      _showMessage(
        'You must be at least 18 years old to donate blood.',
      );
      return;
    }

    if (!_dateOfBirth!.isBefore(now)) {
      _showMessage(
        'Date of birth must be in the past.',
      );
      return;
    }

    // ==========================================================
    // LAST DONATION VALIDATION
    // ==========================================================

    if (_lastDonationDate != null) {
      if (_lastDonationDate!.isAfter(now)) {
        _showMessage(
          'Last donation date cannot be in the future.',
        );
        return;
      }

      if (!_lastDonationDate!.isAfter(_dateOfBirth!)) {
        _showMessage(
          'Last donation date must be after your date of birth.',
        );
        return;
      }
    }

    // ==========================================================
    // WEIGHT VALIDATION
    // ==========================================================

    final weight = double.tryParse(
      _weightController.text.trim(),
    );

    if (weight == null ||
        weight <= 0 ||
        weight > 300) {
      _showMessage(
        'Please enter a valid weight between 1 and 300 kg.',
      );
      return;
    }

    // ==========================================================
    // PHONE VALIDATION
    // ==========================================================

    final hasPhone = await _ensureProfilePhone();

    if (!mounted || !hasPhone) {
      return;
    }

    // ==========================================================
    // CREATE REAL DONOR PROFILE
    // ==========================================================

    final success = await provider.becomeDonor(
      cityId: _selectedCityId!,
      dateOfBirth: _dateOfBirth!,
      weight: weight,
      lastDonationDate: _lastDonationDate,
      availabilityStatus: _normalizeAvailability(
        _availability,
      ),
    );

    if (!mounted) {
      return;
    }

    if (success) {
      _showMessage(
        'You are now registered as a blood donor.',
      );

      context.pop(true);
      return;
    }

    _showMessage(
      provider.error ??
          'Failed to create donor profile.',
    );
  }

  // ============================================================
  // NORMALIZE AVAILABILITY
  // ============================================================

  String _normalizeAvailability(String value) {
    final normalized = value.trim().toLowerCase();

    return normalized == 'unavailable'
        ? 'unavailable'
        : 'available';
  }

  // ============================================================
  // MESSAGE
  // ============================================================

  void _showMessage(String message) {
    if (!mounted) {
      return;
    }

    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message),
        ),
      );
  }

  // ============================================================
  // ERROR
  // ============================================================

  String _cleanError(Object error) {
    var message = error.toString().trim();

    if (message.startsWith('Exception: ')) {
      message = message
          .substring('Exception: '.length)
          .trim();
    }

    return message.isEmpty
        ? 'Something went wrong.'
        : message;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,
      appBar: AppBar(
        title: const Text(
          'Become a Donor',
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
              maxWidth: 520,
            ),
            child: Consumer<DonorProvider>(
              builder: (
                context,
                provider,
                child,
              ) {
                return SingleChildScrollView(
                  physics: const ClampingScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(
                    20,
                    12,
                    20,
                    30,
                  ),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment:
                          CrossAxisAlignment.stretch,
                      children: [
                        // ==================================================
                        // HEADER
                        // ==================================================

                        Container(
                          padding: const EdgeInsets.all(22),
                          decoration: BoxDecoration(
                            color: colors.errorContainer,
                            borderRadius:
                                BorderRadius.circular(24),
                          ),
                          child: Column(
                            children: [
                              Container(
                                width: 72,
                                height: 72,
                                decoration: BoxDecoration(
                                  color: colors.error,
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  Icons.bloodtype_rounded,
                                  size: 40,
                                  color: colors.onError,
                                ),
                              ),
                              const SizedBox(height: 16),
                              Text(
                                'Become a Blood Donor',
                                textAlign: TextAlign.center,
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
                                'Complete your donor information '
                                'to join the LifeLynk donor network.',
                                textAlign: TextAlign.center,
                                style: theme
                                    .textTheme
                                    .bodyMedium
                                    ?.copyWith(
                                  color:
                                      colors.onErrorContainer,
                                  height: 1.5,
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ==================================================
                        // DONOR INFORMATION
                        // ==================================================

                        const _SectionHeader(
                          icon: Icons.person_outline_rounded,
                          title: 'Donor Information',
                          subtitle:
                              'Only donor-specific information is required',
                        ),

                        const SizedBox(height: 14),

                        _FormCard(
                          child: Column(
                            children: [
                              // ==================================================
                              // DATE OF BIRTH
                              // ==================================================

                              InkWell(
                                borderRadius:
                                    BorderRadius.circular(16),
                                onTap: provider.loading
                                    ? null
                                    : _pickDateOfBirth,
                                child: InputDecorator(
                                  decoration:
                                      const InputDecoration(
                                    labelText: 'Date of Birth',
                                    prefixIcon: Icon(
                                      Icons
                                          .calendar_month_outlined,
                                    ),
                                  ),
                                  child: Text(
                                    _formatDate(
                                      _dateOfBirth,
                                    ),
                                  ),
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ==================================================
                              // WEIGHT
                              // ==================================================

                              TextFormField(
                                controller:
                                    _weightController,
                                enabled: !provider.loading,
                                keyboardType:
                                    const TextInputType
                                        .numberWithOptions(
                                  decimal: true,
                                ),
                                decoration:
                                    const InputDecoration(
                                  labelText: 'Weight (kg)',
                                  hintText:
                                      'Enter your weight',
                                  prefixIcon: Icon(
                                    Icons
                                        .monitor_weight_outlined,
                                  ),
                                ),
                                validator: (value) {
                                  if (value == null ||
                                      value.trim().isEmpty) {
                                    return 'Weight is required';
                                  }

                                  final weight =
                                      double.tryParse(
                                    value.trim(),
                                  );

                                  if (weight == null ||
                                      weight <= 0 ||
                                      weight > 300) {
                                    return 'Enter a valid weight between 1 and 300 kg';
                                  }

                                  return null;
                                },
                              ),

                              const SizedBox(height: 16),

                              // ==================================================
                              // PROVINCE
                              // ==================================================

                              Material(
                                type: MaterialType.transparency,
                                child:
                                    DropdownButtonFormField<
                                        String>(
                                  initialValue:
                                      _selectedProvinceId,
                                  isExpanded: true,
                                  decoration:
                                      const InputDecoration(
                                    labelText: 'Province',
                                    prefixIcon: Icon(
                                      Icons
                                          .location_on_outlined,
                                    ),
                                  ),
                                  items: _provinces
                                      .map(
                                    (province) {
                                      final id = province['id']
                                          ?.toString()
                                          .trim();

                                      final name = province['name']
                                          ?.toString()
                                          .trim();

                                      if (id == null ||
                                          id.isEmpty ||
                                          name == null ||
                                          name.isEmpty) {
                                        return null;
                                      }

                                      return DropdownMenuItem<
                                          String>(
                                        value: id,
                                        child: Text(
                                          name,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  )
                                      .whereType<
                                          DropdownMenuItem<
                                              String>>()
                                      .toList(),
                                  onChanged:
                                      _loadingProvinces ||
                                              provider.loading
                                          ? null
                                          : (value) async {
                                              if (value == null) {
                                                return;
                                              }

                                              setState(() {
                                                _selectedProvinceId =
                                                    value;
                                                _selectedCityId =
                                                    null;
                                                _cities = [];
                                              });

                                              await _loadCities(
                                                value,
                                              );
                                            },
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'Province is required';
                                    }

                                    return null;
                                  },
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ==================================================
                              // CITY
                              // ==================================================

                              Material(
                                type: MaterialType.transparency,
                                child:
                                    DropdownButtonFormField<
                                        String>(
                                  initialValue:
                                      _selectedCityId,
                                  isExpanded: true,
                                  decoration: InputDecoration(
                                    labelText: 'City',
                                    prefixIcon:
                                        const Icon(
                                      Icons
                                          .location_city_outlined,
                                    ),
                                    suffixIcon:
                                        _loadingCities
                                            ? const Padding(
                                                padding:
                                                    EdgeInsets.all(
                                                  12,
                                                ),
                                                child: SizedBox(
                                                  width: 18,
                                                  height: 18,
                                                  child:
                                                      CircularProgressIndicator(
                                                    strokeWidth:
                                                        2,
                                                  ),
                                                ),
                                              )
                                            : null,
                                  ),
                                  items: _cities
                                      .map(
                                    (city) {
                                      final id = city['id']
                                          ?.toString()
                                          .trim();

                                      final name = city['name']
                                          ?.toString()
                                          .trim();

                                      if (id == null ||
                                          id.isEmpty ||
                                          name == null ||
                                          name.isEmpty) {
                                        return null;
                                      }

                                      return DropdownMenuItem<
                                          String>(
                                        value: id,
                                        child: Text(
                                          name,
                                          overflow:
                                              TextOverflow.ellipsis,
                                        ),
                                      );
                                    },
                                  )
                                      .whereType<
                                          DropdownMenuItem<
                                              String>>()
                                      .toList(),
                                  onChanged:
                                      _selectedProvinceId ==
                                                  null ||
                                              _loadingCities ||
                                              provider.loading
                                          ? null
                                          : (value) {
                                              if (value == null) {
                                                return;
                                              }

                                              setState(() {
                                                _selectedCityId =
                                                    value;
                                              });
                                            },
                                  validator: (value) {
                                    if (value == null ||
                                        value.trim().isEmpty) {
                                      return 'City is required';
                                    }

                                    return null;
                                  },
                                ),
                              ),

                              const SizedBox(height: 16),

                              // ==================================================
                              // LAST DONATION
                              // ==================================================

                              InkWell(
                                borderRadius:
                                    BorderRadius.circular(16),
                                onTap: provider.loading
                                    ? null
                                    : _pickLastDonationDate,
                                child: InputDecorator(
                                  decoration:
                                      const InputDecoration(
                                    labelText:
                                        'Last Blood Donation',
                                    prefixIcon: Icon(
                                      Icons
                                          .bloodtype_outlined,
                                    ),
                                  ),
                                  child: Text(
                                    _lastDonationDate == null
                                        ? 'Not donated before / Select date'
                                        : _formatDate(
                                            _lastDonationDate,
                                          ),
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ==================================================
                        // AVAILABILITY
                        // ==================================================

                        const _SectionHeader(
                          icon: Icons
                              .volunteer_activism_outlined,
                          title: 'Donor Availability',
                          subtitle:
                              'Let patients know if you can donate',
                        ),

                        const SizedBox(height: 14),

                        _FormCard(
                          child: Column(
                            children: [
                              _AvailabilityOption(
                                title: 'Available',
                                subtitle:
                                    'I am currently available to donate blood',
                                value: 'available',
                                groupValue: _availability,
                                icon: Icons
                                    .check_circle_outline,
                                enabled: !provider.loading,
                                onChanged: (value) {
                                  if (value == null) return;

                                  setState(() {
                                    _availability = value;
                                  });
                                },
                              ),

                              const SizedBox(height: 10),

                              _AvailabilityOption(
                                title: 'Unavailable',
                                subtitle:
                                    'I am currently not available to donate',
                                value: 'unavailable',
                                groupValue: _availability,
                                icon: Icons
                                    .pause_circle_outline,
                                enabled: !provider.loading,
                                onChanged: (value) {
                                  if (value == null) return;

                                  setState(() {
                                    _availability = value;
                                  });
                                },
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 24),

                        // ==================================================
                        // INFORMATION
                        // ==================================================

                        Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: colors
                                .surfaceContainerHighest
                                .withValues(
                              alpha: 0.55,
                            ),
                            borderRadius:
                                BorderRadius.circular(18),
                          ),
                          child: Row(
                            crossAxisAlignment:
                                CrossAxisAlignment.start,
                            children: [
                              Icon(
                                Icons
                                    .info_outline_rounded,
                                color: colors.primary,
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Text(
                                  'Your existing blood group, gender and '
                                  'phone information are taken from your '
                                  'LifeLynk profile. If your phone number is '
                                  'missing, you will be asked to add it before '
                                  'donor registration. Province and city are '
                                  'selected from the real LifeLynk location database.',
                                  style: theme
                                      .textTheme
                                      .bodySmall
                                      ?.copyWith(
                                    height: 1.5,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),

                        const SizedBox(height: 30),

                        // ==================================================
                        // SUBMIT
                        // ==================================================

                        SizedBox(
                          height: 54,
                          child: FilledButton.icon(
                            onPressed: provider.loading
                                ? null
                                : _submit,
                            icon: provider.loading
                                ? const SizedBox(
                                    width: 20,
                                    height: 20,
                                    child:
                                        CircularProgressIndicator(
                                      strokeWidth: 2,
                                    ),
                                  )
                                : const Icon(
                                    Icons
                                        .volunteer_activism_rounded,
                                  ),
                            label: Text(
                              provider.loading
                                  ? 'Creating Donor Profile...'
                                  : 'Become a Donor',
                              style: const TextStyle(
                                fontWeight:
                                    FontWeight.w700,
                              ),
                            ),
                          ),
                        ),

                        const SizedBox(height: 14),

                        // ==================================================
                        // CANCEL
                        // ==================================================

                        TextButton(
                          onPressed: provider.loading
                              ? null
                              : () {
                                  context.pop();
                                },
                          child: const Text(
                            'Cancel',
                          ),
                        ),

                        const SizedBox(height: 12),

                        // ==================================================
                        // PRIVACY
                        // ==================================================

                        Row(
                          mainAxisAlignment:
                              MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.lock_outline_rounded,
                              size: 15,
                              color:
                                  colors.onSurfaceVariant,
                            ),
                            const SizedBox(width: 6),
                            Flexible(
                              child: Text(
                                'Your donor information is securely protected',
                                textAlign:
                                    TextAlign.center,
                                style: theme
                                    .textTheme
                                    .bodySmall
                                    ?.copyWith(
                                  color: colors
                                      .onSurfaceVariant,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// SECTION HEADER
// ============================================================================

class _SectionHeader extends StatelessWidget {
  final IconData icon;
  final String title;
  final String subtitle;

  const _SectionHeader({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: colors.onPrimaryContainer,
            size: 21,
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
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 3),
              Text(
                subtitle,
                style: theme.textTheme.bodySmall?.copyWith(
                  color: colors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

// ============================================================================
// FORM CARD
// ============================================================================

class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant.withValues(
            alpha: 0.55,
          ),
        ),
      ),
      child: child,
    );
  }
}

// ============================================================================
// AVAILABILITY OPTION
// ============================================================================

class _AvailabilityOption extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final IconData icon;

  ///
  /// The callback is deliberately non-nullable so it can always be
  /// passed to RadioGroup. The `enabled` flag controls whether the
  /// option can actually be changed.
  final ValueChanged<String?> onChanged;

  final bool enabled;

  const _AvailabilityOption({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.icon,
    required this.onChanged,
    this.enabled = true,
  });

  @override
  Widget build(BuildContext context) {
    final colors = Theme.of(context).colorScheme;

    final selected = value == groupValue;

    void handleChanged(String? selectedValue) {
      if (!enabled || selectedValue == null) {
        return;
      }

      onChanged(selectedValue);
    }

    return AbsorbPointer(
      absorbing: !enabled,
      child: Opacity(
        opacity: enabled ? 1.0 : 0.55,
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: enabled
              ? () {
                  onChanged(value);
                }
              : null,
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: selected
                  ? colors.primaryContainer.withValues(
                      alpha: 0.45,
                    )
                  : colors.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: selected
                    ? colors.primary
                    : colors.outlineVariant,
              ),
            ),
            child: Row(
              children: [
                Icon(
                  icon,
                  color: selected
                      ? colors.primary
                      : colors.onSurfaceVariant,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.start,
                    children: [
                      Text(
                        title,
                        style: const TextStyle(
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 3),
                      Text(
                        subtitle,
                        style: Theme.of(context)
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
                RadioGroup<String>(
                  groupValue: groupValue,
                  onChanged: handleChanged,
                  child: Radio<String>(
                    value: value,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

