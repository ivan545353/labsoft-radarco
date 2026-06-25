import 'package:flutter/material.dart';

/// Sello/píldora de estado unificado para toda la app.
///
/// Patrón estándar elegido (Material 3): contenedor redondeado con fondo
/// tintado + ícono + texto. Reemplaza las variantes sueltas de estados,
/// avisos y sellos de "confianza de foto" para que todas hablen el mismo
/// lenguaje visual.
///
/// Cumple accesibilidad: nunca comunica solo con color (siempre lleva ícono
/// y texto) y expone un `Semantics` legible por lectores de pantalla.
class SelloEstado extends StatelessWidget {
  final IconData icono;
  final String texto;
  final Color color;

  /// Tamaño tipográfico base. El ícono se dimensiona en relación a este valor.
  final double fontSize;

  const SelloEstado({
    super.key,
    required this.icono,
    required this.texto,
    required this.color,
    this.fontSize = 12,
  });

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: texto,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(20),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icono, size: fontSize + 4, color: color),
            const SizedBox(width: 5),
            Flexible(
              child: Text(
                texto,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: color,
                  fontWeight: FontWeight.w800,
                  fontSize: fontSize,
                  letterSpacing: 0.2,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
