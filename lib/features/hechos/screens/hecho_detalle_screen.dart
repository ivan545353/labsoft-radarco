import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../models/hecho_model.dart';
import '../../auth/screens/login_screen.dart';

class HechoDetalleScreen extends StatefulWidget {
  final HechoModel hecho;

  const HechoDetalleScreen({super.key, required this.hecho});

  @override
  State<HechoDetalleScreen> createState() => _HechoDetalleScreenState();
}

class _HechoDetalleScreenState extends State<HechoDetalleScreen> {
  // VARIABLES DE ESTADO PARA LAS INTERACCIONES
  bool _dioLike = false;
  bool _votoSiguePasando = false;
  bool _votoResuelto = false;

  String _tiempoTranscurrido(DateTime fecha) {
    final diferencia = DateTime.now().difference(fecha);
    if (diferencia.inDays > 0) return 'Reportado hace ${diferencia.inDays} d';
    if (diferencia.inHours > 0) return 'Reportado hace ${diferencia.inHours} h';
    if (diferencia.inMinutes > 0)
      return 'Reportado hace ${diferencia.inMinutes} min';
    return 'Reportado justo ahora';
  }

  Map<String, dynamic> _obtenerEstilos() {
    switch (widget.hecho.tipoHecho) {
      case 'problema':
        return {'color': Colors.red, 'titulo': 'Problema Reportado'};
      case 'alerta':
        return {'color': Colors.orange, 'titulo': 'Alerta Comunitaria'};
      case 'positivo':
        return {'color': Colors.green, 'titulo': 'Hecho Positivo'};
      default:
        return {'color': Colors.blue, 'titulo': 'Reporte Comunitario'};
    }
  }

  int _calcularNivel(int? reputacion) {
    if (reputacion == null) return 1;
    return (reputacion / 50).floor() + 1;
  }

  // --- LAZY LOGIN PARA INTERACCIONES ---
  // Retorna 'true' si el usuario NO está logueado y lo redirige.
  // Retorna 'false' si está logueado y puede continuar.
  bool _requiereLogin() {
    final sesionActual = Supabase.instance.client.auth.currentSession;
    if (sesionActual == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return true; // Aborta la acción actual
    }
    return false; // Permite que la acción continúe
  }

  // --- LÓGICAS DE INTERACCIÓN ---
  void _manejarLike() {
    if (_requiereLogin()) return; // Intercepción de seguridad

    setState(() => _dioLike = !_dioLike);
    if (_dioLike) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Gracias por apoyar este reporte!'),
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  void _manejarVotoSiguePasando() {
    if (_requiereLogin()) return; // Intercepción de seguridad
    if (_votoSiguePasando || _votoResuelto) return;

    setState(() => _votoSiguePasando = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Confirmación registrada. Ayudas a mantener el mapa actualizado.',
        ),
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _manejarVotoResuelto() {
    if (_requiereLogin()) return; // Intercepción de seguridad
    if (_votoResuelto || _votoSiguePasando) return;

    setState(() => _votoResuelto = true);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Voto registrado (1/3 necesarios para marcar como resuelto).',
        ),
        backgroundColor: AppColors.exito,
        behavior: SnackBarBehavior.floating,
      ),
    );
  }

  void _manejarComentario() {
    if (_requiereLogin()) return; // Intercepción de seguridad
    // TODO: Abrir panel de comentarios
  }

  @override
  Widget build(BuildContext context) {
    final estilos = _obtenerEstilos();

    return Scaffold(
      backgroundColor: Colors.white,
      // BARRA INFERIOR DE ACCIONES
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Botón de Upvote animado por estado
              IconButton(
                onPressed: _manejarLike,
                icon: Icon(
                  _dioLike ? Icons.favorite : Icons.favorite_border,
                  color: _dioLike ? Colors.redAccent : Colors.grey[400],
                  size: 28,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  // El botón de compartir NO requiere login porque queremos viralidad (HU10.1)
                  onPressed: () {},
                  icon: const Icon(Icons.share, size: 18),
                  label: const Text('Compartir'),
                  style: OutlinedButton.styleFrom(
                    foregroundColor: AppColors.azulPrimario,
                    side: const BorderSide(color: AppColors.azulPrimario),
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: _manejarComentario, // Protegido por login
                  icon: const Icon(
                    Icons.add_comment,
                    size: 18,
                    color: Colors.white,
                  ),
                  label: const Text(
                    'Comentar',
                    style: TextStyle(color: Colors.white),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.azulPrimario,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(100),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: CustomScrollView(
        slivers: [
          // IMAGEN DE CABECERA
          SliverAppBar(
            expandedHeight: 250.0,
            pinned: true,
            backgroundColor: AppColors.azulPrimario,
            iconTheme: const IconThemeData(color: Colors.white),
            flexibleSpace: FlexibleSpaceBar(
              background: Container(
                color: AppColors.azulPrimario,
                child: const Center(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Icon(
                        Icons.add_a_photo_outlined,
                        size: 60,
                        color: Colors.white24,
                      ),
                      SizedBox(height: 8),
                      Text(
                        'Foto ciudadana pendiente',
                        style: TextStyle(color: Colors.white54, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),

          // CUERPO DEL DETALLE
          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
              ),
              transform: Matrix4.translationValues(0.0, -30.0, 0.0),
              child: Padding(
                padding: const EdgeInsets.all(24.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // TÍTULO Y ESTADO
                    Text(
                      estilos['titulo'],
                      style: TextStyle(
                        fontSize: 24,
                        fontWeight: FontWeight.w900,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                    const SizedBox(height: 12),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: widget.hecho.estado == 'activo'
                                ? Colors.blue[100]
                                : Colors.green[100],
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: widget.hecho.estado == 'activo'
                                    ? Colors.blue[700]
                                    : Colors.green[700],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                widget.hecho.estado.toUpperCase(),
                                style: TextStyle(
                                  color: widget.hecho.estado == 'activo'
                                      ? Colors.blue[700]
                                      : Colors.green[700],
                                  fontWeight: FontWeight.bold,
                                  fontSize: 10,
                                ),
                              ),
                            ],
                          ),
                        ),
                        const SizedBox(width: 12),
                        Text(
                          _tiempoTranscurrido(widget.hecho.creadoEn),
                          style: TextStyle(
                            color: Colors.blueGrey[400],
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ),

                    const SizedBox(height: 24),

                    // TARJETA DEL USUARIO
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: const Color(0xFFF4F7FB),
                        borderRadius: BorderRadius.circular(100),
                      ),
                      child: Row(
                        children: [
                          CircleAvatar(
                            radius: 20,
                            backgroundColor: Colors.grey[300],
                            backgroundImage:
                                widget.hecho.avatarAutor != null &&
                                    widget.hecho.avatarAutor!.isNotEmpty
                                ? NetworkImage(widget.hecho.avatarAutor!)
                                : null,
                            child:
                                widget.hecho.avatarAutor == null ||
                                    widget.hecho.avatarAutor!.isEmpty
                                ? const Icon(Icons.person, color: Colors.white)
                                : null,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  widget.hecho.nombreAutor ??
                                      'Ciudadano Anónimo',
                                  style: TextStyle(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.blueGrey[900],
                                    fontSize: 14,
                                  ),
                                ),
                                Text(
                                  'Reputación: ${widget.hecho.reputacionAutor ?? 0} pts • Nivel ${_calcularNivel(widget.hecho.reputacionAutor)}',
                                  style: TextStyle(
                                    color: Colors.blueGrey[500],
                                    fontSize: 11,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          Container(
                            padding: const EdgeInsets.all(8),
                            decoration: const BoxDecoration(
                              color: Colors.white,
                              shape: BoxShape.circle,
                            ),
                            child: const Icon(
                              Icons.person_search_outlined,
                              size: 18,
                              color: AppColors.azulPrimario,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 24),

                    // DESCRIPCIÓN COMPLETA
                    Text(
                      widget.hecho.descripcion ?? 'Sin descripción detallada.',
                      style: TextStyle(
                        fontSize: 16,
                        color: Colors.blueGrey[800],
                        height: 1.5,
                      ),
                    ),

                    const SizedBox(height: 24),
                    const Divider(),
                    const SizedBox(height: 16),

                    // SECCIÓN: VALIDACIÓN COMUNITARIA
                    Text(
                      'VALIDACIÓN COMUNITARIA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[400],
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Botón: Sigue Pasando
                    Opacity(
                      opacity: _votoResuelto ? 0.4 : 1.0,
                      child: InkWell(
                        onTap: _manejarVotoSiguePasando, // Protegido por login
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _votoSiguePasando
                                ? Colors.red[50]
                                : Colors.transparent,
                            border: Border.all(
                              color: _votoSiguePasando
                                  ? Colors.red[200]!
                                  : Colors.red[100]!,
                            ),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: _votoSiguePasando
                                      ? Colors.red[400]
                                      : Colors.red[50],
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _votoSiguePasando
                                      ? Icons.check
                                      : Icons.warning_amber_rounded,
                                  color: _votoSiguePasando
                                      ? Colors.white
                                      : Colors.red[400],
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _votoSiguePasando
                                          ? 'Confirmaste este reporte'
                                          : 'Sigue pasando',
                                      style: TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.blueGrey[900],
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      '14 vecinos confirmaron esto hoy',
                                      style: TextStyle(
                                        color: Colors.blueGrey[500],
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 12),

                    // Botón: Marcar como Resuelto
                    Opacity(
                      opacity: _votoSiguePasando ? 0.4 : 1.0,
                      child: InkWell(
                        onTap: _manejarVotoResuelto, // Protegido por login
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _votoResuelto
                                ? Colors.green[700]
                                : const Color(0xFF0A5C36),
                            borderRadius: BorderRadius.circular(20),
                          ),
                          child: Row(
                            children: [
                              Container(
                                padding: const EdgeInsets.all(10),
                                decoration: BoxDecoration(
                                  color: Colors.white.withOpacity(0.2),
                                  shape: BoxShape.circle,
                                ),
                                child: Icon(
                                  _votoResuelto
                                      ? Icons.check
                                      : Icons.check_circle_outline,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _votoResuelto
                                          ? 'Voto de resolución enviado'
                                          : 'Marcar como Resuelto',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      _votoResuelto
                                          ? 'Esperando confirmación comunitaria'
                                          : '¿Se arregló desde tu última visita?',
                                      style: const TextStyle(
                                        color: Colors.white70,
                                        fontSize: 12,
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                              const Icon(
                                Icons.celebration,
                                color: Colors.white70,
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),

                    const SizedBox(height: 40),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
