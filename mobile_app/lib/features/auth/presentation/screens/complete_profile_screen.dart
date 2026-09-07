import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:lottie/lottie.dart';
import 'package:provider/provider.dart';

import '../../../../core/router/routes.dart';

import '../../../profile/models/profile_model.dart';
import '../../../profile/providers/profile_provider.dart';

import '../widgets/blood_group_dropdown.dart';
import '../widgets/city_dropdown.dart';
import '../widgets/primary_button.dart';
import '../widgets/province_dropdown.dart';

class CompleteProfileScreen extends StatefulWidget {
  final String fullName;

  const CompleteProfileScreen({
    super.key,
    required this.fullName,
  });

  @override
  State<CompleteProfileScreen> createState() => _CompleteProfileScreenState();
}

class _CompleteProfileScreenState extends State<CompleteProfileScreen> {
  final formKey = GlobalKey<FormState>();

  final phoneController = TextEditingController();

  String? gender;
  String? bloodGroup;
  String? province;
  String? city;

  @override
  void initState() {
    super.initState();

    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted) return;

      final provider = context.read<ProfileProvider>();

      await provider.loadProvinces();

      if (!mounted) return;

      // ----------------------------------------------------------
      // Load the real profile from Supabase.
      //
      // Phone comes from:
      // public.users.phone_number
      // ----------------------------------------------------------

      await provider.loadProfile();

      if (!mounted) return;

      final profile = provider.profile;

      if (profile == null) {
        return;
      }

      final storedPhone = profile.phoneNumber?.trim();

      setState(() {
        if (storedPhone != null && storedPhone.isNotEmpty) {
          phoneController.text = storedPhone;
        }

        gender = profile.gender;
        bloodGroup = profile.bloodGroup;
        province = profile.province;
        city = profile.city;
      });

      // ----------------------------------------------------------
      // Load cities for the existing province when available.
      //
      // Province/city are currently Flutter-side selections and
      // are not written to patients because those columns do not
      // exist in the current database schema.
      // ----------------------------------------------------------

      final existingProvince = profile.province?.trim();

      if (existingProvince != null && existingProvince.isNotEmpty) {
        await provider.selectProvince(existingProvince);

        if (!mounted) return;

        final existingCity = profile.city?.trim();

        if (existingCity != null && existingCity.isNotEmpty) {
          provider.selectCity(existingCity);

          setState(() {
            city = existingCity;
          });
        }
      }
    });
  }

  @override
  void dispose() {
    phoneController.dispose();
    super.dispose();
  }

  // ============================================================
  // SAVE PROFILE
  // ============================================================

  Future<void> _saveProfile(ProfileProvider provider) async {
    FocusScope.of(context).unfocus();

    // ----------------------------------------------------------
    // Validate form.
    // ----------------------------------------------------------

    if (!formKey.currentState!.validate()) {
      return;
    }

    // ----------------------------------------------------------
    // Validate blood group.
    // ----------------------------------------------------------

    final selectedBloodGroup = bloodGroup?.trim();

    if (selectedBloodGroup == null || selectedBloodGroup.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your blood group.'),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // Validate province.
    // ----------------------------------------------------------

    final selectedProvince = provider.selectedProvince?.trim();

    if (selectedProvince == null || selectedProvince.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your province.'),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // Validate city.
    // ----------------------------------------------------------

    final selectedCity = provider.selectedCity?.trim();

    if (selectedCity == null || selectedCity.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select your city.'),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // Normalize required phone.
    // ----------------------------------------------------------

    final phoneNumber = phoneController.text.trim();

    if (phoneNumber.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Phone number is required.'),
        ),
      );

      return;
    }

    // ----------------------------------------------------------
    // Create profile model.
    //
    // The repository maps:
    //
    // fullName    -> users.full_name
    // phoneNumber -> users.phone_number
    // gender      -> patients.gender
    // bloodGroup  -> blood_groups.id -> patients.blood_group_id
    //
    // Province/city remain available to the Flutter model but are
    // not written to patients because those columns do not exist
    // in the current database schema.
    // ----------------------------------------------------------

    final profile = ProfileModel(
      fullName: widget.fullName.trim(),
      phoneNumber: phoneNumber,
      gender: gender?.trim().isEmpty == true
          ? null
          : gender?.trim(),
      bloodGroup: selectedBloodGroup,
      province: selectedProvince,
      city: selectedCity,
    );

    // ----------------------------------------------------------
    // Capture navigation/context dependencies before await.
    // ----------------------------------------------------------

    final router = GoRouter.of(context);
    final messenger = ScaffoldMessenger.of(context);

    // ----------------------------------------------------------
    // Save profile.
    // ----------------------------------------------------------

    final success = await provider.saveProfile(profile);

    if (!mounted) {
      return;
    }

    // ----------------------------------------------------------
    // Success.
    // ----------------------------------------------------------

    if (success) {
      router.go(Routes.dashboard);
      return;
    }

    // ----------------------------------------------------------
    // Error.
    // ----------------------------------------------------------

    messenger.showSnackBar(
      SnackBar(
        content: Text(
          provider.error ?? 'Failed to save profile.',
        ),
      ),
    );
  }

  // ============================================================
  // PHONE VALIDATION
  // ============================================================

  String? _validatePhone(String? value) {
    final phone = value?.trim() ?? '';

    if (phone.isEmpty) {
      return 'Phone number is required.';
    }

    if (phone.length > 20) {
      return 'Phone number must not exceed 20 characters.';
    }

    // Accept Pakistani and international formats while avoiding
    // overly restrictive assumptions about the user's number.
    final phoneRegex = RegExp(
      r'^\+?[0-9][0-9\s\-()]{7,19}$',
    );

    if (!phoneRegex.hasMatch(phone)) {
      return 'Please enter a valid phone number.';
    }

    return null;
  }

  // ============================================================
  // BUILD
  // ============================================================

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final colorScheme = theme.colorScheme;

    return Scaffold(
      backgroundColor: colorScheme.surface,
      body: SafeArea(
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(
              maxWidth: 520,
            ),
            child: ScrollConfiguration(
              behavior: ScrollConfiguration.of(context).copyWith(
                scrollbars: false,
              ),
              child: SingleChildScrollView(
                physics: const ClampingScrollPhysics(),
                keyboardDismissBehavior:
                    ScrollViewKeyboardDismissBehavior.onDrag,
                padding: const EdgeInsets.fromLTRB(
                  20,
                  12,
                  20,
                  30,
                ),
                child: Form(
                  key: formKey,
                  child: Column(
                    crossAxisAlignment:
                        CrossAxisAlignment.stretch,
                    children: [
                      // ==================================================
                      // ILLUSTRATION
                      // ==================================================

                      SizedBox(
                        height: 155,
                        child: Lottie.asset(
                          'assets/animations/profile.json',
                          fit: BoxFit.contain,
                        ),
                      ),

                      const SizedBox(height: 8),

                      // ==================================================
                      // TITLE
                      // ==================================================

                      Text(
                        'Complete Your Profile',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.w800,
                          letterSpacing: -0.4,
                        ),
                      ),

                      const SizedBox(height: 8),

                      Text(
                        'Just a few details to help '
                        'LifeLynk connect you with '
                        'the right healthcare services.',
                        textAlign: TextAlign.center,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          color: colorScheme.onSurfaceVariant,
                          height: 1.5,
                        ),
                      ),

                      const SizedBox(height: 28),

                      // ==================================================
                      // PERSONAL INFORMATION
                      // ==================================================

                      const _SectionHeader(
                        icon: Icons.person_outline_rounded,
                        title: 'Personal Information',
                        subtitle:
                            'Phone is required • Gender is optional',
                      ),

                      const SizedBox(height: 14),

                      _FormCard(
                        child: Column(
                          children: [
                            // --------------------------------------------
                            // PHONE NUMBER
                            // --------------------------------------------

                            TextFormField(
                              controller: phoneController,
                              keyboardType: TextInputType.phone,
                              textInputAction: TextInputAction.next,
                              autofillHints: const [
                                AutofillHints.telephoneNumber,
                              ],
                              decoration: const InputDecoration(
                                labelText: 'Phone Number',
                                hintText: '+92 300 1234567',
                                prefixIcon: Icon(
                                  Icons.phone_outlined,
                                ),
                              ),
                              validator: _validatePhone,
                            ),

                            const SizedBox(height: 16),

                            // --------------------------------------------
                            // GENDER
                            // --------------------------------------------

                            DropdownButtonFormField<String>(
                              initialValue: gender,
                              decoration: const InputDecoration(
                                labelText: 'Gender',
                                prefixIcon: Icon(
                                  Icons.people_outline_rounded,
                                ),
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'Male',
                                  child: Text('Male'),
                                ),
                                DropdownMenuItem(
                                  value: 'Female',
                                  child: Text('Female'),
                                ),
                                DropdownMenuItem(
                                  value: 'Other',
                                  child: Text('Other'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(() {
                                  gender = value;
                                });
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ==================================================
                      // BLOOD INFORMATION
                      // ==================================================

                      const _SectionHeader(
                        icon: Icons.bloodtype_outlined,
                        title: 'Blood Information',
                        subtitle:
                            'Required for blood search and emergencies',
                      ),

                      const SizedBox(height: 14),

                      _FormCard(
                        child: BloodGroupDropdown(
                          value: bloodGroup,
                          onChanged: (value) {
                            setState(() {
                              bloodGroup = value;
                            });
                          },
                        ),
                      ),

                      const SizedBox(height: 24),

                      // ==================================================
                      // LOCATION
                      // ==================================================

                      const _SectionHeader(
                        icon: Icons.location_on_outlined,
                        title: 'Location',
                        subtitle:
                            'Used to find nearby blood services',
                      ),

                      const SizedBox(height: 14),

                      _FormCard(
                        child: Column(
                          children: [
                            // --------------------------------------------
                            // PROVINCE
                            // --------------------------------------------

                            Consumer<ProfileProvider>(
                              builder: (_, provider, _) {
                                return ProvinceDropdown(
                                  value: province,
                                  provinces: provider.provinces,
                                  onChanged:
                                      (selectedProvince) async {
                                    setState(() {
                                      province =
                                          selectedProvince;
                                      city = null;
                                    });

                                    await provider.selectProvince(
                                      selectedProvince,
                                    );

                                    if (!mounted) {
                                      return;
                                    }
                                  },
                                );
                              },
                            ),

                            const SizedBox(height: 16),

                            // --------------------------------------------
                            // CITY
                            // --------------------------------------------

                            Consumer<ProfileProvider>(
                              builder: (_, provider, _) {
                                return CityDropdown(
                                  value: city,
                                  cities: provider.cities,
                                  onChanged: (selectedCity) {
                                    setState(() {
                                      city = selectedCity;
                                    });

                                    provider.selectCity(
                                      selectedCity,
                                    );
                                  },
                                );
                              },
                            ),
                          ],
                        ),
                      ),

                      const SizedBox(height: 30),

                      // ==================================================
                      // SAVE PROFILE
                      // ==================================================

                      Consumer<ProfileProvider>(
                        builder: (_, provider, _) {
                          return PrimaryButton(
                            text: provider.loading
                                ? 'Saving Profile...'
                                : 'Finish Profile Setup',
                            icon: provider.loading
                                ? null
                                : Icons.check_circle_outline_rounded,
                            onPressed: provider.loading
                                ? null
                                : () => _saveProfile(provider),
                          );
                        },
                      ),

                      const SizedBox(height: 20),

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
                                colorScheme.onSurfaceVariant,
                          ),
                          const SizedBox(width: 6),
                          Flexible(
                            child: Text(
                              'Your information is securely protected',
                              textAlign: TextAlign.center,
                              style:
                                  theme.textTheme.bodySmall?.copyWith(
                                color:
                                    colorScheme.onSurfaceVariant,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
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
    final colorScheme = theme.colorScheme;

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 42,
          height: 42,
          decoration: BoxDecoration(
            color: colorScheme.primaryContainer,
            borderRadius: BorderRadius.circular(13),
          ),
          child: Icon(
            icon,
            color: colorScheme.onPrimaryContainer,
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
                  color:
                      colorScheme.onSurfaceVariant,
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
    final colorScheme = Theme.of(context).colorScheme;

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: colorScheme.surface,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(
          color: colorScheme.outlineVariant.withValues(
            alpha: 0.55,
          ),
        ),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(
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