import 'package:flutter/material.dart';
import 'core/theme/app_colors.dart';
import 'features/auth/screens/auth_gate.dart';

class RadarCiudadanoApp extends StatelessWidget {
  const RadarCiudadanoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RadarCO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        scaffoldBackgroundColor: AppColors.fondoGeneral,
        colorScheme: ColorScheme.fromSeed(
          seedColor: AppColors.azulPrimario,
          primary: AppColors.azulPrimario,
          secondary: AppColors.azulAcento,
          error: AppColors.problema,
          surface: AppColors.superficieBlanca,
        ),
        useMaterial3: true,
      ),
      home: const AuthGate(),
    );
  }
}
