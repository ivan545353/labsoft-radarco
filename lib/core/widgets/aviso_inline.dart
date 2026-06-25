import 'package:flutter/material.dart';

/// Aviso inline unificado para mensajes informativos "ricos" (multilínea,
/// con título + detalle y acción opcional). Es el hermano de [SelloEstado]:
/// mismo lenguaje visual, pero para notas más extensas (sellos de confianza
/// de foto, sugerencias de IA, errores de formulario, etc.).
///
/// Decisiones de diseño:
/// - SIN borde de color: el borde+relleno es justo lo que hacía que estas
///   cajas parecieran botones (rechazado por el stakeholder). Acá usamos solo
///   un fondo tintado muy sutil + una franja de acento a la izquierda, de modo
///   que se lea claramente como "nota" y nunca como botón.
/// - Nunca comunica solo con color: siempre lleva ícono + texto.
/// - El único elemento accionable, si existe, es el botón explícito.
class AvisoInline extends StatelessWidget {
  final IconData icono;
  final Color color;
  final String titulo;
  final String? detalle;
  final String? accionTexto;
  final VoidCallback? onAccion;

  const AvisoInline({
    super.key,
    required this.icono,
    required this.color,
    required this.titulo,
    this.detalle,
    this.accionTexto,
    this.onAccion,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(14, 12, 12, 12),
      decoration: BoxDecoration(
        color: color.withOpacity(0.08),
        borderRadius: BorderRadius.circular(14),
        // Franja de acento sutil a la izquierda en vez de un borde completo.
        border: Border(left: BorderSide(color: color, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          MergeSemantics(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(icono, color: color, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        titulo,
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                          color: Colors.blueGrey[900],
                        ),
                      ),
                      if (detalle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          detalle!,
                          style: TextStyle(
                            fontSize: 12.5,
                            color: Colors.blueGrey[700],
                            height: 1.3,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ],
            ),
          ),
          if (accionTexto != null && onAccion != null) ...[
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: onAccion,
                style: ElevatedButton.styleFrom(
                  backgroundColor: color,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: Text(
                  accionTexto!,
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
