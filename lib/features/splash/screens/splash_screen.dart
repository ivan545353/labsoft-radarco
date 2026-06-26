import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../../hechos/screens/mapa_principal_screen.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entrada;
  late final Animation<double> _logoFade;
  late final Animation<double> _logoScale;
  late final Animation<double> _textoFade;
  late final Animation<Offset> _textoSlide;

  late final AnimationController _pulso;

  @override
  void initState() {
    super.initState();

    _entrada = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1000),
    );
    _logoFade = CurvedAnimation(
      parent: _entrada,
      curve: const Interval(0.0, 0.55, curve: Curves.easeOut),
    );
    _logoScale = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _entrada,
        curve: const Interval(0.0, 0.7, curve: Curves.easeOutBack),
      ),
    );
    _textoFade = CurvedAnimation(
      parent: _entrada,
      curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
    );
    _textoSlide = Tween<Offset>(begin: const Offset(0, 0.4), end: Offset.zero)
        .animate(
          CurvedAnimation(
            parent: _entrada,
            curve: const Interval(0.45, 1.0, curve: Curves.easeOut),
          ),
        );

    _pulso = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    )..repeat();

    _entrada.forward();
    _irAlMapa();
  }

  Future<void> _irAlMapa() async {
    await Future.delayed(const Duration(milliseconds: 2000));
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 500),
        pageBuilder: (_, __, ___) => const MapaPrincipalScreen(),
        transitionsBuilder: (_, anim, __, child) =>
            FadeTransition(opacity: anim, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _entrada.dispose();
    _pulso.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Colors.white, Color(0xFFEAF2FB)],
          ),
        ),
        child: Stack(
          children: [
            // Glow radial sutil detrás del logo (guiño al radar)
            Center(
              child: Container(
                width: 360,
                height: 360,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: RadialGradient(
                    colors: [
                      AppColors.azulSuave.withOpacity(0.45),
                      AppColors.azulSuave.withOpacity(0.0),
                    ],
                  ),
                ),
              ),
            ),

            // Logo + tagline
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  FadeTransition(
                    opacity: _logoFade,
                    child: ScaleTransition(
                      scale: _logoScale,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 48),
                        child: Image.asset(
                          'assets/logo.png',
                          fit: BoxFit.contain,
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  SlideTransition(
                    position: _textoSlide,
                    child: FadeTransition(
                      opacity: _textoFade,
                      child: Text(
                        'Tu ciudad, en tiempo real',
                        style: TextStyle(
                          color: AppColors.azulPrimario.withOpacity(0.85),
                          fontSize: 15,
                          fontWeight: FontWeight.w600,
                          letterSpacing: 0.3,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),

            // Loader de tres puntos
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 56),
                child: AnimatedBuilder(
                  animation: _pulso,
                  builder: (context, _) => Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(3, (i) {
                      final t = (_pulso.value + i * 0.25) % 1.0;
                      final op = 0.25 + 0.75 * (1 - (2 * t - 1).abs());
                      return Container(
                        margin: const EdgeInsets.symmetric(horizontal: 4),
                        width: 8,
                        height: 8,
                        decoration: BoxDecoration(
                          color: AppColors.azulAcento.withOpacity(op),
                          shape: BoxShape.circle,
                        ),
                      );
                    }),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
