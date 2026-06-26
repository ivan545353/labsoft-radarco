import 'package:flutter/material.dart';
import 'core/theme/app_colors.dart';
// Apuntamos directo al mapa
import 'features/hechos/screens/mapa_principal_screen.dart';
import 'features/splash/screens/splash_screen.dart';

class RadarCiudadanoApp extends StatelessWidget {
  const RadarCiudadanoApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'RadarCO',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        fontFamily: 'Nunito',
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
      // ¡El mapa es la pantalla por defecto para todo el mundo!
      // Arranca en el splash, que luego transiciona al mapa.
      home: const SplashScreen(),
    );
  }
}
