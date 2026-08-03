import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../core/constants/app_colors.dart';
import '../../core/constants/app_constants.dart';
import '../../shared/providers/theme_provider.dart';

class SettingsScreen extends ConsumerStatefulWidget {
  const SettingsScreen({super.key});

  @override
  ConsumerState<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends ConsumerState<SettingsScreen> {
  String _selectedLanguage = 'English';
  bool _pushNotifications = true;
  bool _emergencyAlerts = true;

  @override
  Widget build(BuildContext context) {
    final themeMode = ref.watch(themeProvider);
    final isDark = themeMode == ThemeMode.dark;

    return Scaffold(
      appBar: AppBar(
        title: const Text('App Settings'),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('PREFERENCES', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: Icon(isDark ? Icons.dark_mode : Icons.light_mode, color: AppColors.primary),
                  title: const Text('Dark Mode'),
                  subtitle: Text(isDark ? 'Dark theme active' : 'Light theme active'),
                  value: isDark,
                  onChanged: (val) {
                    ref.read(themeProvider.notifier).toggleTheme(val);
                  },
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.language, color: AppColors.secondary),
                  title: const Text('Language'),
                  subtitle: Text(_selectedLanguage),
                  trailing: const Icon(Icons.chevron_right),
                  onTap: () {
                    showDialog(
                      context: context,
                      builder: (ctx) => SimpleDialog(
                        title: const Text('Select Language'),
                        children: [
                          SimpleDialogOption(
                            onPressed: () {
                              setState(() => _selectedLanguage = 'English');
                              Navigator.pop(ctx);
                            },
                            child: const Text('English (Default)'),
                          ),
                          SimpleDialogOption(
                            onPressed: () {
                              setState(() => _selectedLanguage = 'Urdu (اردو)');
                              Navigator.pop(ctx);
                            },
                            child: const Text('Urdu (اردو)'),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('NOTIFICATIONS', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Card(
            child: Column(
              children: [
                SwitchListTile(
                  secondary: const Icon(Icons.notifications_active, color: AppColors.primary),
                  title: const Text('Push Notifications'),
                  value: _pushNotifications,
                  onChanged: (val) => setState(() => _pushNotifications = val),
                ),
                const Divider(height: 1),
                SwitchListTile(
                  secondary: const Icon(Icons.warning_amber, color: AppColors.warning),
                  title: const Text('Emergency Stock Alerts'),
                  value: _emergencyAlerts,
                  onChanged: (val) => setState(() => _emergencyAlerts = val),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          const Padding(
            padding: EdgeInsets.only(left: 4, bottom: 8),
            child: Text('SUPPORT & LEGAL', style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold, color: Colors.grey)),
          ),
          Card(
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.privacy_tip_outlined, color: AppColors.primary),
                  title: const Text('Privacy Policy'),
                  onTap: () => _showDialog('Privacy Policy', 'LifeLynk AI respects user data and complies with medical data standards.'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.description_outlined, color: AppColors.secondary),
                  title: const Text('Terms & Conditions'),
                  onTap: () => _showDialog('Terms & Conditions', 'By using LifeLynk AI, you agree to our emergency blood network terms.'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.help_outline, color: AppColors.success),
                  title: const Text('Help & Support'),
                  onTap: () => _showDialog('Help & Support', 'For technical assistance or urgent queries, contact support@lifelynk.ai'),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.info_outline, color: Colors.grey),
                  title: const Text('About LifeLynk AI'),
                  subtitle: const Text('Version ${AppConstants.appVersion}'),
                  onTap: () => _showDialog('About LifeLynk AI', 'LifeLynk AI v${AppConstants.appVersion}\nBuilt for Hackathon 2026.'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  void _showDialog(String title, String message) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: Text(message),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Close')),
        ],
      ),
    );
  }
}
