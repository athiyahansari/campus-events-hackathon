import 'dart:async';

import 'package:flutter/material.dart';

import '../../theme/app_theme.dart';
import 'root_shell.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen> with SingleTickerProviderStateMixin {
  Timer? _timer;
  late final AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..forward();

    _timer = Timer(const Duration(milliseconds: 1500), () {
      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        PageRouteBuilder(
          transitionDuration: const Duration(milliseconds: 350),
          pageBuilder: (_, animation, _) => FadeTransition(
            opacity: animation,
            child: const RootShell(),
          ),
        ),
      );
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final fade = CurvedAnimation(parent: _controller, curve: Curves.easeOut);

    return Scaffold(
      backgroundColor: AppBrand.navy,
      body: Center(
        child: FadeTransition(
          opacity: fade,
          child: ScaleTransition(
            scale: Tween<double>(begin: 0.85, end: 1).animate(fade),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(AppSpacing.xl),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(AppRadius.xl),
                  ),
                  child: const Icon(Icons.event_note, size: 56, color: AppBrand.accent),
                ),
                const SizedBox(height: AppSpacing.xl),
                const Text(
                  'UniEvents',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 30,
                    fontWeight: FontWeight.bold,
                    letterSpacing: 0.5,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Campus events, all in one place',
                  style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 14),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
