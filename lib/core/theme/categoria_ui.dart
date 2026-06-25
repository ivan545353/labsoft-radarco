import 'package:flutter/material.dart';

/// Fuente única de verdad para el estilo visual (ícono + color) de cada
/// categoría de hecho. Centraliza lo que antes estaba duplicado pantalla
/// por pantalla, para mantener un lenguaje visual consistente.
///
/// Uso:
///   final ui = CategoriaUI.de('Bache', hecho.tipoHecho);
///   Icon(ui.icono, color: ui.color);
class CategoriaUI {
  final IconData icono;
  final Color color;

  const CategoriaUI({required this.icono, required this.color});

  /// Devuelve el estilo de una categoría. [tipoBackend] se usa solo como
  /// respaldo cuando la categoría no coincide con ninguna conocida.
  static CategoriaUI de(String categoria, String tipoBackend) {
    switch (categoria) {
      case 'Bache':
        return CategoriaUI(
          icono: Icons.terrain_rounded,
          color: Colors.red[500]!,
        );
      case 'Basura':
        return CategoriaUI(
          icono: Icons.delete_outline_rounded,
          color: Colors.brown[400]!,
        );
      case 'Luminaria':
        return CategoriaUI(
          icono: Icons.lightbulb_outline_rounded,
          color: Colors.amber[600]!,
        );
      case 'Agua / Caño':
        return CategoriaUI(
          icono: Icons.water_drop_outlined,
          color: Colors.blue[500]!,
        );
      case 'Accidente':
        return CategoriaUI(
          icono: Icons.car_crash_outlined,
          color: Colors.deepOrange[500]!,
        );
      case 'Obstrucción':
        return CategoriaUI(
          icono: Icons.block_flipped,
          color: Colors.orange[500]!,
        );
      case 'Inseguridad':
        return CategoriaUI(
          icono: Icons.security_outlined,
          color: Colors.purple[400]!,
        );
      default:
        return tipoBackend == 'alerta'
            ? CategoriaUI(
                icono: Icons.warning_rounded,
                color: Colors.orange[500]!,
              )
            : CategoriaUI(
                icono: Icons.report_problem_rounded,
                color: Colors.blueGrey[500]!,
              );
    }
  }
}
