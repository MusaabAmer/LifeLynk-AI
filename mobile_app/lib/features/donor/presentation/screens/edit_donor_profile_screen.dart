import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:go_router/go_router.dart';

import '../../providers/donor_provider.dart';

class EditDonorProfileScreen extends StatefulWidget {
  const EditDonorProfileScreen({
    super.key,
  });

  @override
  State<EditDonorProfileScreen> createState() =>
      _EditDonorProfileScreenState();
}

class _EditDonorProfileScreenState
    extends State<EditDonorProfileScreen> {
  final _formKey = GlobalKey<FormState>();

  final _weightController = TextEditingController();

  DateTime? _dateOfBirth;
  DateTime? _lastDonationDate;

  String _availability = 'available';

  bool _initialized = false;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) {
      _initialize();
    });
  }

  // ============================================================
  // INITIALIZE
  // ============================================================

  Future<void> _initialize() async {
    if (!mounted) return;

    final provider = context.read<DonorProvider>();

    if (provider.donorProfile == null) {
      await provider.loadDonorProfile();
    }

    if (!mounted) return;

    final donor = provider.donorProfile;

    if (donor == null) {
      setState(() {
        _initialized = true;
      });
      return;
    }

    final normalizedAvailability =
        donor.availabilityStatus.trim().toLowerCase();

    setState(() {
      _dateOfBirth = donor.dateOfBirth;
      _lastDonationDate = donor.lastDonationDate;

      _availability = normalizedAvailability == 'unavailable'
          ? 'unavailable'
          : 'available';

      if (donor.weight != null) {
        _weightController.text =
            donor.weight!.toStringAsFixed(1);
      }

      _initialized = true;
    });
  }

  @override
  void dispose() {
    _weightController.dispose();
    super.dispose();
  }

  // ============================================================
  // DATE OF BIRTH
  // ============================================================

  Future<void> _pickDateOfBirth() async {
    final now = DateTime.now();

    final maximumDob = DateTime(
      now.year - 18,
      now.month,
      now.day,
    );

    final existingDate = _dateOfBirth;

    final initialDate =
        existingDate != null &&
                !existingDate.isAfter(maximumDob)
            ? existingDate
            : maximumDob;

    final selected = await showDatePicker(
      context: context,
      firstDate: DateTime(1900),
      lastDate: maximumDob,
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

    if (!mounted) return;

    if (selected != null) {
      setState(() {
        _dateOfBirth = selected;

        // A previous donation date cannot be before the
        // donor's date of birth.
        if (_lastDonationDate != null &&
            _lastDonationDate!.isBefore(selected)) {
          _lastDonationDate = null;
        }
      });
    }
  }

  // ============================================================
  // LAST DONATION DATE
  // ============================================================

  Future<void> _pickLastDonationDate() async {
    final now = DateTime.now();

    final minimumDate = _dateOfBirth != null
        ? DateTime(
            _dateOfBirth!.year,
            _dateOfBirth!.month,
            _dateOfBirth!.day,
          )
        : DateTime(1950);

    final existingDate = _lastDonationDate;

    DateTime initialDate;

    if (existingDate != null &&
        !existingDate.isBefore(minimumDate) &&
        !existingDate.isAfter(now)) {
      initialDate = existingDate;
    } else {
      initialDate = now;

      if (initialDate.isBefore(minimumDate)) {
        initialDate = minimumDate;
      }
    }

    final selected = await showDatePicker(
      context: context,
      firstDate: minimumDate,
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

    if (!mounted) return;

    if (selected != null) {
      setState(() {
        _lastDonationDate = selected;
      });
    }
  }

  // ============================================================
  // FORMAT DATE
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
  // SAVE
  // ============================================================

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }

    if (_dateOfBirth == null) {
      _showMessage(
        'Please select your date of birth.',
      );
      return;
    }

    final now = DateTime.now();

    final minimumAgeDate = DateTime(
      now.year - 18,
      now.month,
      now.day,
    );

    if (_dateOfBirth!.isAfter(minimumAgeDate)) {
      _showMessage(
        'You must be at least 18 years old to donate blood.',
      );
      return;
    }

    if (_lastDonationDate != null) {
      if (_lastDonationDate!.isAfter(now)) {
        _showMessage(
          'Last donation date cannot be in the future.',
        );
        return;
      }

      if (_lastDonationDate!.isBefore(_dateOfBirth!)) {
        _showMessage(
          'Last donation date cannot be before your date of birth.',
        );
        return;
      }
    }

    final weight = double.tryParse(
      _weightController.text.trim(),
    );

    if (weight == null || weight <= 0) {
      _showMessage(
        'Please enter a valid weight.',
      );
      return;
    }

    if (weight > 300) {
      _showMessage(
        'Please enter a realistic weight.',
      );
      return;
    }

    final provider = context.read<DonorProvider>();

    final success = await provider.updateDonorProfile(
      dateOfBirth: _dateOfBirth!,
      weight: weight,
      lastDonationDate: _lastDonationDate,
      availabilityStatus: _availability == 'unavailable'
          ? 'unavailable'
          : 'available',
    );

    if (!mounted) return;

    if (success) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          const SnackBar(
            content: Text(
              'Donor profile updated successfully.',
            ),
          ),
        );

      context.pop(true);
    } else {
      _showMessage(
        provider.error ??
            'Failed to update donor profile.',
      );
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

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colors = theme.colorScheme;

    return Scaffold(
      backgroundColor: colors.surface,

      // ========================================================
      // APP BAR
      // ========================================================

      appBar: AppBar(
        title: const Text(
          'Edit Donor Profile',
          style: TextStyle(
            fontWeight: FontWeight.w800,
          ),
        ),
        centerTitle: true,
      ),

      // ========================================================
      // BODY
      // ========================================================

      body: Consumer<DonorProvider>(
        builder: (
          context,
          provider,
          child,
        ) {
          // ----------------------------------------------------
          // INITIAL LOADING
          // ----------------------------------------------------

          if (!_initialized ||
              (provider.loading &&
                  provider.donorProfile == null)) {
            return const Center(
              child: CircularProgressIndicator(),
            );
          }

          // ----------------------------------------------------
          // NO DONOR PROFILE
          // ----------------------------------------------------

          if (provider.donorProfile == null) {
            return _NoDonorProfile(
              onBack: () {
                context.pop();
              },
            );
          }

          // ----------------------------------------------------
          // EDIT FORM
          // ----------------------------------------------------

          return SafeArea(
            child: SingleChildScrollView(
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
                            width: 70,
                            height: 70,
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
                          const SizedBox(height: 14),
                          Text(
                            'Update Donor Information',
                            textAlign: TextAlign.center,
                            style: theme
                                .textTheme
                                .headlineSmall
                                ?.copyWith(
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Keep your donor information accurate '
                            'and up to date.',
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
                      icon:
                          Icons.medical_information_outlined,
                      title: 'Donor Information',
                      subtitle:
                          'Update your donor-specific information',
                    ),

                    const SizedBox(height: 14),

                    _FormCard(
                      child: Column(
                        children: [
                          // ------------------------------------------
                          // DATE OF BIRTH
                          // ------------------------------------------

                          _DateField(
                            label: 'Date of Birth',
                            value:
                                _formatDate(_dateOfBirth),
                            icon:
                                Icons.calendar_month_outlined,
                            onTap: _pickDateOfBirth,
                          ),

                          const SizedBox(height: 16),

                          // ------------------------------------------
                          // WEIGHT
                          // ------------------------------------------

                          TextFormField(
                            controller:
                                _weightController,
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
                                  weight <= 0) {
                                return 'Enter a valid weight';
                              }

                              if (weight > 300) {
                                return 'Please enter a realistic weight';
                              }

                              return null;
                            },
                          ),

                          const SizedBox(height: 16),

                          // ------------------------------------------
                          // LAST DONATION
                          // ------------------------------------------

                          _DateField(
                            label:
                                'Last Blood Donation',
                            value:
                                _lastDonationDate ==
                                        null
                                    ? 'Not donated before / Select date'
                                    : _formatDate(
                                        _lastDonationDate,
                                      ),
                            icon:
                                Icons.bloodtype_outlined,
                            onTap:
                                _pickLastDonationDate,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // ==================================================
                    // AVAILABILITY
                    // ==================================================

                    const _SectionHeader(
                      icon:
                          Icons.volunteer_activism_outlined,
                      title: 'Donor Availability',
                      subtitle:
                          'Control whether patients can find you',
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
                            icon:
                                Icons.check_circle_outline,
                            onChanged: (value) {
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
                            icon:
                                Icons.pause_circle_outline,
                            onChanged: (value) {
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
                    // ELIGIBILITY INFORMATION
                    // ==================================================

                    Container(
                      padding:
                          const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: colors
                            .surfaceContainerHighest
                            .withValues(alpha: 0.55),
                        borderRadius:
                            BorderRadius.circular(18),
                      ),
                      child: Row(
                        crossAxisAlignment:
                            CrossAxisAlignment.start,
                        children: [
                          Icon(
                            Icons.info_outline_rounded,
                            color: colors.primary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              'Your eligibility status is managed '
                              'by the LifeLynk system and cannot '
                              'be changed manually.',
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
                    // SAVE
                    // ==================================================

                    SizedBox(
                      height: 54,
                      child: FilledButton.icon(
                        onPressed:
                            provider.loading
                                ? null
                                : _save,
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
                                Icons.save_outlined,
                              ),
                        label: Text(
                          provider.loading
                              ? 'Saving Changes...'
                              : 'Save Changes',
                          style:
                              const TextStyle(
                            fontWeight:
                                FontWeight.w700,
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // ==================================================
                    // CANCEL
                    // ==================================================

                    TextButton(
                      onPressed:
                          provider.loading
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
                            textAlign: TextAlign.center,
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
            ),
          );
        },
      ),
    );
  }
}

// ================================================================
// DATE FIELD
// ================================================================

class _DateField extends StatelessWidget {
  final String label;
  final String value;
  final IconData icon;
  final VoidCallback onTap;

  const _DateField({
    required this.label,
    required this.value,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return InkWell(
      borderRadius:
          BorderRadius.circular(16),
      onTap: onTap,
      child: InputDecorator(
        decoration: InputDecoration(
          labelText: label,
          prefixIcon: Icon(icon),
          suffixIcon: Icon(
            Icons.calendar_today_outlined,
            size: 19,
            color: colors.onSurfaceVariant,
          ),
        ),
        child: Text(
          value,
          style: Theme.of(context)
              .textTheme
              .bodyLarge
              ?.copyWith(
            color: value == 'Select date'
                ? colors.onSurfaceVariant
                : colors.onSurface,
          ),
        ),
      ),
    );
  }
}

// ================================================================
// SECTION HEADER
// ================================================================

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
      crossAxisAlignment:
          CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colors.primaryContainer,
            borderRadius:
                BorderRadius.circular(13),
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
                style: theme
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
                style: theme
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
    );
  }
}

// ================================================================
// FORM CARD
// ================================================================

class _FormCard extends StatelessWidget {
  final Widget child;

  const _FormCard({
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Container(
      padding:
          const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colors.surface,
        borderRadius:
            BorderRadius.circular(22),
        border: Border.all(
          color: colors.outlineVariant
              .withValues(alpha: 0.55),
        ),
        boxShadow: [
          BoxShadow(
            color:
                Colors.black.withValues(
              alpha: 0.035,
            ),
            blurRadius: 18,
            offset: const Offset(0, 7),
          ),
        ],
      ),
      child: child,
    );
  }
}

// ================================================================
// AVAILABILITY OPTION
// ================================================================

class _AvailabilityOption
    extends StatelessWidget {
  final String title;
  final String subtitle;
  final String value;
  final String groupValue;
  final IconData icon;
  final ValueChanged<String> onChanged;

  const _AvailabilityOption({
    required this.title,
    required this.subtitle,
    required this.value,
    required this.groupValue,
    required this.icon,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    final selected = value == groupValue;

    return InkWell(
      borderRadius:
          BorderRadius.circular(16),
      onTap: () {
        onChanged(value);
      },
      child: Container(
        padding:
            const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: selected
              ? colors.primaryContainer
                  .withValues(alpha: 0.45)
              : colors.surface,
          borderRadius:
              BorderRadius.circular(16),
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
                      fontWeight:
                          FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 3),
                  Text(
                    subtitle,
                    style: Theme.of(context)
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
            Icon(
              selected
                  ? Icons.radio_button_checked
                  : Icons.radio_button_off,
              color: selected
                  ? colors.primary
                  : colors.onSurfaceVariant,
            ),
          ],
        ),
      ),
    );
  }
}

// ================================================================
// NO DONOR PROFILE
// ================================================================

class _NoDonorProfile
    extends StatelessWidget {
  final VoidCallback onBack;

  const _NoDonorProfile({
    required this.onBack,
  });

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
            Icon(
              Icons
                  .volunteer_activism_outlined,
              size: 64,
              color: colors.primary,
            ),
            const SizedBox(height: 16),
            const Text(
              'Donor Profile Not Found',
              style: TextStyle(
                fontSize: 21,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'We could not find your donor profile.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 20),
            FilledButton(
              onPressed: onBack,
              child: const Text(
                'Go Back',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
