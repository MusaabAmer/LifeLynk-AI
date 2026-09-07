import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';

import '../providers/splash_provider.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> {
  final SplashProvider provider = SplashProvider();

  @override
  void initState() {
    super.initState();
    navigate();
  }

  Future<void> navigate() async {
    await Future.delayed(
      const Duration(seconds: 5),
    );

    final completed =
        await provider.isOnboardingCompleted();

    if (!mounted) return;

    if (completed) {
      context.go('/login');
    } else {
      context.go('/onboarding');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,

      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 32,
            ),
            child: Image.asset(
              "assets/images/logo/lifelynk_logo.png",
              width: 320,
              height: 320,
              fit: BoxFit.contain,
            ),
          ),
        ),
      ),
    );
  }
}