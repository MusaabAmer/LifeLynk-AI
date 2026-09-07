import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:provider/provider.dart';

import '../../../../core/constants/app_colors.dart';
import '../../../../core/router/routes.dart';
import '../../../../core/providers/theme_provider.dart';
import '../widgets/settings_action_card.dart';

class SettingsScreen extends StatelessWidget {
  const SettingsScreen({
    super.key,
  });

  // ============================================================
  // APPEARANCE
  // ============================================================

  void _showAppearanceDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('Appearance'),
          content: Consumer<ThemeProvider>(
            builder: (context, provider, _) {
              return RadioGroup<ThemeMode>(
                groupValue: provider.themeMode,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }

                  provider.setThemeMode(value);
                  Navigator.of(dialogContext).pop();
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.system,
                      title: const Text('System default'),
                      secondary: const Icon(
                        Icons.brightness_auto_outlined,
                      ),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.light,
                      title: const Text('Light'),
                      secondary: const Icon(
                        Icons.light_mode_outlined,
                      ),
                    ),
                    RadioListTile<ThemeMode>(
                      value: ThemeMode.dark,
                      title: const Text('Dark'),
                      secondary: const Icon(
                        Icons.dark_mode_outlined,
                      ),
                    ),
                  ],
                ),
              );
            },
          ),
        );
      },
    );
  }

  // ============================================================
  // ABOUT
  // ============================================================

  void _showAboutDialog(BuildContext context) {
    showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
          title: const Text('LifeLynk AI'),
          content: const Text(
            'LifeLynk AI is a digital blood infrastructure and '
            'emergency response platform designed to connect '
            'patients, donors, hospitals, blood banks and '
            'healthcare authorities.',
          ),
          actions: [
            TextButton(
              onPressed: () {
                Navigator.of(dialogContext).pop();
              },
              child: const Text('Close'),
            ),
          ],
        );
      },
    );
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
      appBar: AppBar(
        title: const Text('Settings'),
        backgroundColor: colorScheme.surface,
        foregroundColor: colorScheme.onSurface,
        elevation: 0,
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.fromLTRB(
            20,
            12,
            20,
            32,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // ==================================================
              // ACCOUNT
              // ==================================================

              Text(
                'Account',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 12),

              SettingsActionCard(
                icon: Icons.person_outline,
                title: 'Personal Information',
                subtitle:
                    'View and update your name and phone number',
                onTap: () {
                  context.push(Routes.personalInformation);
                },
              ),

              const SizedBox(height: 12),

              SettingsActionCard(
                icon: Icons.lock_outline,
                title: 'Password & Security',
                subtitle:
                    'Manage your password and account security',
                onTap: () {
                  context.push(Routes.changePassword);
                },
              ),

              const SizedBox(height: 28),

              // ==================================================
              // PREFERENCES
              // ==================================================

              Text(
                'Preferences',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 12),

              SettingsActionCard(
                icon: Icons.notifications_none_outlined,
                title: 'Notifications',
                subtitle:
                    'Manage your LifeLynk AI notifications',
                onTap: () {
                  context.push(Routes.notifications);
                },
              ),

              const SizedBox(height: 12),

              SettingsActionCard(
                icon: Icons.palette_outlined,
                title: 'Appearance',
                subtitle: 'Choose your preferred theme',
                onTap: () {
                  _showAppearanceDialog(context);
                },
              ),

              const SizedBox(height: 12),

              SettingsActionCard(
                icon: Icons.location_on_outlined,
                title: 'Location',
                subtitle:
                    'Manage location and emergency map settings',
                onTap: () {
                  context.push(Routes.locationSettings);
                },
              ),

              const SizedBox(height: 28),

              // ==================================================
              // ABOUT
              // ==================================================

              Text(
                'About',
                style: theme.textTheme.titleMedium?.copyWith(
                  fontWeight: FontWeight.w700,
                  color: colorScheme.onSurface,
                ),
              ),

              const SizedBox(height: 12),

              SettingsActionCard(
                icon: Icons.info_outline,
                title: 'About LifeLynk AI',
                subtitle:
                    'Learn more about the LifeLynk AI platform',
                onTap: () {
                  _showAboutDialog(context);
                },
              ),

              const SizedBox(height: 12),

              SettingsActionCard(
                icon: Icons.phone_android_outlined,
                title: 'App Version',
                subtitle: 'LifeLynk AI • Version 1.0.0',
                showArrow: false,
                onTap: () {},
              ),

              const SizedBox(height: 28),

              // ==================================================
              // SECURITY MESSAGE
              // ==================================================

              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(
                    alpha: 0.06,
                  ),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(
                      Icons.security_outlined,
                      size: 21,
                      color: AppColors.primary,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        'LifeLynk AI uses your account information '
                        'to provide personalized healthcare, blood '
                        'availability and emergency response services.',
                        style: theme.textTheme.bodySmall?.copyWith(
                          height: 1.45,
                          color: colorScheme.onSurfaceVariant,
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
    );
  }
}