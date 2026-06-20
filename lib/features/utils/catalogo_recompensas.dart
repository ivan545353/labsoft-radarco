import 'package:flutter/material.dart';
import '../../core/theme/app_colors.dart';

class Recompensa {
  final String id;
  final String nombre;
  final int puntosRequeridos;
  final dynamic valorVisual;

  Recompensa({
    required this.id,
    required this.nombre,
    required this.puntosRequeridos,
    required this.valorVisual,
  });

  bool estaDesbloqueada(int reputacionUsuario) {
    return reputacionUsuario >= puntosRequeridos;
  }
}

class CatalogoRecompensas {
  // --- TEMAS DE COLOR ---
  static final List<Recompensa> temas = [
    Recompensa(
      id: 'azul_primario',
      nombre: 'Azul Cívico',
      puntosRequeridos: 0,
      valorVisual: AppColors.azulPrimario,
    ),
    Recompensa(
      id: 'verde_esmeralda',
      nombre: 'Esmeralda',
      puntosRequeridos: 50,
      valorVisual: const Color(0xFF10B981),
    ),
    Recompensa(
      id: 'naranja_alerta',
      nombre: 'Naranja Urbano',
      puntosRequeridos: 100,
      valorVisual: const Color(0xFFF59E0B),
    ),
    Recompensa(
      id: 'purpura_nocturno',
      nombre: 'Púrpura',
      puntosRequeridos: 250,
      valorVisual: const Color(0xFF8B5CF6),
    ),
    Recompensa(
      id: 'rosa_elite',
      nombre: 'Rosa Rubí',
      puntosRequeridos: 500,
      valorVisual: const Color(0xFFE11D48),
    ),
  ];

  // --- MARCOS DE AVATAR ---
  static final List<Recompensa> marcos = [
    Recompensa(
      id: 'ninguno',
      nombre: 'Sin marco',
      puntosRequeridos: 0,
      valorVisual: Colors.transparent,
    ),
    Recompensa(
      id: 'anillo_bronce',
      nombre: 'Bronce',
      puntosRequeridos: 50,
      valorVisual: const Color(0xFFCD7F32),
    ),
    Recompensa(
      id: 'anillo_plata',
      nombre: 'Plata',
      puntosRequeridos: 100,
      valorVisual: const Color(0xFF90A4AE),
    ),
    Recompensa(
      id: 'hexagono_oro',
      nombre: 'Oro',
      puntosRequeridos: 250,
      valorVisual: const Color(0xFFFFB300),
    ),
    Recompensa(
      id: 'neon_diamante',
      nombre: 'Diamante',
      puntosRequeridos: 500,
      valorVisual: const Color(0xFF00BCEB),
    ),
  ];

  // --- BANNERS (FONDOS GRADIENTES) ---
  static final List<Recompensa> banners = [
    Recompensa(
      id: 'clasico_azul',
      nombre: 'Clásico',
      puntosRequeridos: 0,
      valorVisual: [AppColors.azulPrimario, const Color(0xFF1E3A8A)],
    ),
    Recompensa(
      id: 'amanecer',
      nombre: 'Amanecer',
      puntosRequeridos: 100,
      valorVisual: [const Color(0xFFF59E0B), const Color(0xFFEF4444)],
    ),
    Recompensa(
      id: 'aurora',
      nombre: 'Aurora',
      puntosRequeridos: 250,
      valorVisual: [const Color(0xFF10B981), const Color(0xFF3B82F6)],
    ),
    Recompensa(
      id: 'noche_neon',
      nombre: 'Noche Neón',
      puntosRequeridos: 500,
      valorVisual: [const Color(0xFF8B5CF6), const Color(0xFF312E81)],
    ),
  ];

  // --- FUNCIONES DE AYUDA (Para renderizar fácil en la UI) ---
  static Color getColorTema(String id) =>
      temas.firstWhere((t) => t.id == id, orElse: () => temas[0]).valorVisual;
  static Color getColorMarco(String id) =>
      marcos.firstWhere((m) => m.id == id, orElse: () => marcos[0]).valorVisual;
  static List<Color> getGradienteBanner(String id) => banners
      .firstWhere((b) => b.id == id, orElse: () => banners[0])
      .valorVisual;
}
