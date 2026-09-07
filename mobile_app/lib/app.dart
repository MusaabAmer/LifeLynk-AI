import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'core/router/app_router.dart';
import 'core/providers/theme_provider.dart';

class LifeLynkApp extends StatelessWidget {
  const LifeLynkApp({super.key});

  @override
  Widget build(BuildContext context) {
    final themeProvider = context.watch<ThemeProvider>();

    return MaterialApp.router(
      title: 'LifeLynk AI',
      debugShowCheckedModeBanner: false,

      // ============================================================
      // THEMES
      // ============================================================

      theme: AppTheme.lightTheme,

      darkTheme: AppTheme.darkTheme,

      themeMode: themeProvider.themeMode,

      // ============================================================
      // ROUTER
      // ============================================================

      routerConfig: AppRouter.router,
    );
  }
}