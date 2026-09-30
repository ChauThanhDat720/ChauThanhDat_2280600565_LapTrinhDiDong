import 'package:flutter/material.dart';

import 'core/theme/app_theme.dart';
import 'features/auth/presentation/splash_screen.dart';

class SmartHospitalApp extends StatelessWidget {
  const SmartHospitalApp({super.key});

  @override
  Widget build(BuildContext context) => MaterialApp(
    title: 'Smart Hospital',
    debugShowCheckedModeBanner: false,
    theme: AppTheme.light,
    home: const SplashScreen(),
  );
}
