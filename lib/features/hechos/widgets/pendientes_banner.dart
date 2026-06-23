import 'dart:io';
import 'package:flutter/material.dart';
import '../../../core/theme/app_colors.dart';
import '../models/reporte_pendiente.dart';
import '../services/sincronizacion_service.dart';

/// Banner compacto del feed: aparece solo si hay reportes offline en cola.
/// Toca -> hoja con la lista y acciones de reintentar/descartar.
class PendientesBanner extends StatelessWidget {
  const PendientesBanner({super.key});

  @override
  Widget build(BuildContext context) {
    final servicio = SincronizacionService.instancia;
    return ListenableBuilder(
      listenable: servicio,
      builder: (context, _) {
        final cola = servicio.enCola;
        if (cola.isEmpty) return const SizedBox.shrink();

        final pendientes = cola.where((r) => r.estado == 'pendiente').length;
        final retenidos = cola.where((r) => r.estado == 'retenido').length;
        final hayProblema = retenidos > 0;
        final Color base = hayProblema ? Colors.orange : AppColors.azulPrimario;

        String texto;
        if (servicio.sincronizando) {
          texto = 'Publicando reportes guardados…';
        } else if (hayProblema && pendientes > 0) {
          texto = '$pendientes sin publicar · $retenidos con problema';
        } else if (hayProblema) {
          texto = retenidos == 1
              ? '1 reporte con problema'
              : '$retenidos reportes con problema';
        } else {
          texto = pendientes == 1
              ? '1 reporte sin publicar'
              : '$pendientes reportes sin publicar';
        }

        return Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 12),
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => _abrirLista(context, servicio),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
              decoration: BoxDecoration(
                color: base.withOpacity(0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: base.withOpacity(0.3)),
              ),
              child: Row(
                children: [
                  if (servicio.sincronizando)
                    SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2.2,
                        color: base,
                      ),
                    )
                  else
                    Icon(
                      hayProblema
                          ? Icons.error_outline_rounded
                          : Icons.cloud_off_rounded,
                      size: 20,
                      color: base,
                    ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      texto,
                      style: TextStyle(
                        fontSize: 13.5,
                        fontWeight: FontWeight.w700,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, size: 20, color: base),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  void _abrirLista(BuildContext context, SincronizacionService servicio) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) => ListenableBuilder(
        listenable: servicio,
        builder: (ctx, _) {
          final cola = servicio.enCola;
          return SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 20),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Center(
                    child: Container(
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                        color: Colors.grey[300],
                        borderRadius: BorderRadius.circular(10),
                      ),
                    ),
                  ),
                  const SizedBox(height: 18),
                  Text(
                    'Reportes sin publicar',
                    style: TextStyle(
                      fontSize: 19,
                      fontWeight: FontWeight.w900,
                      color: Colors.blueGrey[900],
                    ),
                  ),
                  const SizedBox(height: 14),
                  if (cola.isEmpty)
                    Padding(
                      padding: const EdgeInsets.symmetric(vertical: 24),
                      child: Center(
                        child: Text(
                          'No hay reportes pendientes.',
                          style: TextStyle(color: Colors.blueGrey[400]),
                        ),
                      ),
                    )
                  else
                    Flexible(
                      child: ListView.separated(
                        shrinkWrap: true,
                        itemCount: cola.length,
                        separatorBuilder: (_, __) => const Divider(height: 20),
                        itemBuilder: (_, i) => _itemReporte(servicio, cola[i]),
                      ),
                    ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _itemReporte(SincronizacionService servicio, ReportePendiente r) {
    final retenido = r.estado == 'retenido';
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: Image.file(
            File(r.imagenPath),
            width: 48,
            height: 48,
            fit: BoxFit.cover,
            errorBuilder: (_, __, ___) => Container(
              width: 48,
              height: 48,
              color: Colors.grey[200],
              child: const Icon(
                Icons.image_not_supported_outlined,
                size: 20,
                color: Colors.grey,
              ),
            ),
          ),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                r.categoriaNombre,
                style: TextStyle(
                  fontWeight: FontWeight.w800,
                  fontSize: 14,
                  color: Colors.blueGrey[900],
                ),
              ),
              const SizedBox(height: 2),
              Text(
                retenido
                    ? (r.motivoRetencion ?? 'Quedó retenido.')
                    : 'Esperando conexión…',
                style: TextStyle(
                  fontSize: 12,
                  height: 1.3,
                  color: retenido ? Colors.orange[800] : Colors.blueGrey[500],
                ),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  GestureDetector(
                    onTap: () => servicio.reintentar(r),
                    child: const Text(
                      'Reintentar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: AppColors.azulPrimario,
                      ),
                    ),
                  ),
                  const SizedBox(width: 16),
                  GestureDetector(
                    onTap: () => servicio.descartar(r),
                    child: Text(
                      'Descartar',
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[400],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}
