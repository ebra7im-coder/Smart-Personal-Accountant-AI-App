// Splash screen: brand, logo, Firebase readiness, onboarding + biometric gate.

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../app.dart';
import '../../services/security_service.dart';
import '../../utils/constants.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key, required this.biometricEnabled});

  final bool biometricEnabled;

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..forward();

  late final Animation<double> _fadeIn =
      CurvedAnimation(parent: _controller, curve: Curves.easeOutCubic);

  bool _routed = false;

  @override
  void initState() {
    super.initState();
    _bootstrap();
  }

  Future<void> _bootstrap() async {
    // Let the fade-in play for a beat.
    await Future<void>.delayed(const Duration(milliseconds: 1400));
    if (!mounted) return;

    final SharedPreferences prefs = await SharedPreferences.getInstance();
    final bool seenOnboarding =
        prefs.getBool(PrefKeys.onboardingSeen) ?? false;

    String next = AppRoutes.onboarding;
    if (seenOnboarding) {
      // Ask for biometrics first if the user enabled the lock.
      if (widget.biometricEnabled) {
        final bool ok = await SecurityService.authenticate('افتح المحاسب الذكي');
        if (!ok && mounted) {
          // Stay on splash; retry on tap.
          setState(() => _routed = false);
          return;
        }
      }
      try {
        next = FirebaseAuth.instance.currentUser != null
            ? AppRoutes.home
            : AppRoutes.login;
      } catch (_) {
        next = AppRoutes.login; // local-only mode
      }
    }

    if (mounted && !_routed) {
      _routed = true;
      Navigator.of(context).pushReplacementNamed(next);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.navy,
      body: GestureDetector(
        onTap: _routed ? null : _bootstrap,
        child: Container(
          decoration: const BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topRight,
              end: Alignment.bottomLeft,
              colors: <Color>[AppColors.navy, Color(0xFF0B1F3E)],
            ),
          ),
          child: Center(
            child: FadeTransition(
              opacity: _fadeIn,
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: <Widget>[
                  Container(
                    padding: const EdgeInsets.all(18),
                    decoration: BoxDecoration(
                      color: AppColors.white,
                      borderRadius: BorderRadius.circular(28),
                      boxShadow: <BoxShadow>[
                        BoxShadow(
                          color: AppColors.green.withOpacity(0.35),
                          blurRadius: 40,
                          spreadRadius: 4,
                        ),
                      ],
                    ),
                    child: Image.asset(
                      'assets/images/app_icon.png',
                      width: 96,
                      height: 96,
                      fit: BoxFit.contain,
                    ),
                  ),
                  const SizedBox(height: 24),
                  const Text(
                    'المحاسب الذكي',
                    style: TextStyle(
                      color: AppColors.white,
                      fontSize: 28,
                      fontWeight: FontWeight.w800,
                      fontFamily: 'Tajawal',
                    ),
                  ),
                  const SizedBox(height: 8),
                  Text(
                    'محاسبك الشخصي بالذكاء الاصطناعي 🤖',
                    style: TextStyle(
                      color: AppColors.white.withOpacity(0.8),
                      fontSize: 14,
                    ),
                  ),
                  const SizedBox(height: 48),
                  const SizedBox(
                    width: 28,
                    height: 28,
                    child: CircularProgressIndicator(
                      color: AppColors.green,
                      strokeWidth: 2.5,
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
