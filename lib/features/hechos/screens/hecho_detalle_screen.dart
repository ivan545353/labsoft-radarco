import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../models/hecho_model.dart';
import '../../auth/screens/login_screen.dart';
import '../controllers/hechos_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'comentarios_sheet.dart';

class HechoDetalleScreen extends StatefulWidget {
  final HechoModel hecho;
  final HechosController controller; // <--- NUEVO

  const HechoDetalleScreen({
    super.key,
    required this.hecho,
    required this.controller,
  }); // <--- ACTUALIZADO

  @override
  State<HechoDetalleScreen> createState() => _HechoDetalleScreenState();
}

class _HechoDetalleScreenState extends State<HechoDetalleScreen> {
  // VARIABLES DE ESTADO PARA LAS INTERACCIONES Y PROPIEDAD
  bool _dioLike = false;
  bool _votoSiguePasando = false;
  bool _votoResuelto = false;
  bool _cargandoEstado = true;

  // NUEVO: Bandera para saber si el usuario actual es el OP (Original Poster)
  bool _esMio = false;

  int _conteoSiguePasando = 0;
  int _conteoResuelto = 0;
  int _conteoUpvotes = 0;
  late String _estadoActual;

  @override
  void initState() {
    super.initState();
    _estadoActual = widget.hecho.estado;
    _sincronizarEstadoPrevio();
  }

  String _tiempoTranscurrido(DateTime fecha) {
    final diferencia = DateTime.now().difference(fecha);
    if (diferencia.inDays > 7) {
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    }
    if (diferencia.inDays > 0) {
      return 'Hace ${diferencia.inDays} ${diferencia.inDays == 1 ? 'día' : 'días'}';
    }
    if (diferencia.inHours > 0) {
      return 'Hace ${diferencia.inHours} ${diferencia.inHours == 1 ? 'hora' : 'horas'}';
    }
    if (diferencia.inMinutes > 0) return 'Hace ${diferencia.inMinutes} min';
    return 'Reportado justo ahora';
  }

  Map<String, dynamic> _obtenerEstilos() {
    switch (widget.hecho.tipoHecho) {
      case 'problema':
        return {'color': Colors.red, 'titulo': 'Problema Reportado'};
      case 'alerta':
        return {'color': Colors.orange, 'titulo': 'Alerta Comunitaria'};
      default:
        return {'color': Colors.blue, 'titulo': 'Reporte Comunitario'};
    }
  }

  int _calcularNivel(int? reputacion) {
    if (reputacion == null) return 1;
    return (reputacion / 50).floor() + 1;
  }

  // --- RECUPERAR MEMORIA Y VALIDAR ROL (OP vs COMUNIDAD) ---
  Future<void> _sincronizarEstadoPrevio() async {
    // 1. REFRESCAR DATOS
    final hechoActualizado = await widget.controller.obtenerHechoPorId(
      widget.hecho.id,
    );

    if (hechoActualizado != null && mounted) {
      setState(() {
        _estadoActual = hechoActualizado.estado;
      });
    }

    // 2. CONTEO DE VOTOS
    final conteos = await widget.controller.obtenerConteoInteracciones(
      widget.hecho.id,
    );

    if (mounted) {
      setState(() {
        _conteoSiguePasando = conteos['sigue_pasando'] ?? 0;
        _conteoResuelto = conteos['ya_se_resolvio'] ?? 0;
        _conteoUpvotes = conteos['upvote'] ?? 0;
      });
    }

    // 3. MEMORIA DEL USUARIO Y PROPIEDAD
    final sesionActual = Supabase.instance.client.auth.currentUser;
    if (sesionActual == null) {
      if (mounted) setState(() => _cargandoEstado = false);
      return;
    }

    try {
      // Traducimos el ID de autenticación al ID público de la tabla usuarios
      final usuarioData = await Supabase.instance.client
          .from('usuarios')
          .select('id')
          .eq('auth_id', sesionActual.id)
          .single();

      final ciudadanoIdReal = usuarioData['id'];

      // VALIDACIÓN ESTRATÉGICA: ¿Es mi propio reporte?
      final esPropietario = ciudadanoIdReal == widget.hecho.ciudadanoId;

      final interacciones = await widget.controller.cargarMisInteracciones(
        widget.hecho.id,
      );

      if (mounted) {
        setState(() {
          _esMio = esPropietario; // Guardamos el rol
          _dioLike = interacciones.contains('upvote');
          _votoSiguePasando = interacciones.contains('sigue_pasando');
          _votoResuelto = interacciones.contains('ya_se_resolvio');
          _cargandoEstado = false;
        });
      }
    } catch (e) {
      debugPrint('Error al verificar propiedad: $e');
      if (mounted) setState(() => _cargandoEstado = false);
    }
  }

  bool _requiereLogin() {
    final sesionActual = Supabase.instance.client.auth.currentSession;
    if (sesionActual == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return true;
    }
    return false;
  }

  // --- ACCIONES EXCLUSIVAS DEL CREADOR (OP) ---

  // 1. Cerrar caso instantáneamente con 1 clic
  Future<void> _cerrarCasoOP() async {
    if (_cargandoEstado) return;
    setState(() => _cargandoEstado = true);

    try {
      await Supabase.instance.client
          .from('hechos')
          .update({'estado': 'resuelto'})
          .eq('id', widget.hecho.id);

      setState(() {
        _estadoActual = 'resuelto';
        _cargandoEstado = false;
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Solución confirmada! Gracias por avisar (+10 pts)'),
            backgroundColor: AppColors.exito,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      widget.controller.cargarHechos(); // Refresca el mapa de fondo
    } catch (e) {
      setState(() => _cargandoEstado = false);
      debugPrint('Error al cerrar caso directo: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No se pudo actualizar el estado.'),
            backgroundColor: AppColors.problema,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // 2. Eliminar mi reporte físicamente
  Future<void> _eliminarMiReporte() async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('¿Eliminar reporte?'),
        content: const Text(
          'Esta acción retirará el pin del mapa de forma permanente.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancelar', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, true),
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.problema,
            ),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar != true) return;

    setState(() => _cargandoEstado = true);
    try {
      await Supabase.instance.client
          .from('hechos')
          .delete()
          .eq('id', widget.hecho.id);

      if (mounted) {
        Navigator.pop(context); // Volvemos al feed/mapa
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reporte eliminado correctamente.'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
      widget.controller.cargarHechos();
    } catch (e) {
      setState(() => _cargandoEstado = false);
      debugPrint('Error al eliminar reporte: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al eliminar. Intenta nuevamente.'),
            backgroundColor: AppColors.problema,
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }
  }

  // --- ACCIONES DE LA COMUNIDAD ---

  Future<void> _manejarLike() async {
    if (_requiereLogin() || _cargandoEstado) return;

    final estadoAnterior = _dioLike;
    setState(() {
      _dioLike = !_dioLike;
      if (_dioLike) {
        _conteoUpvotes++;
      } else {
        _conteoUpvotes--;
      }
    });

    bool exito;
    if (estadoAnterior) {
      exito = await widget.controller.quitarInteraccion(
        widget.hecho.id,
        'upvote',
      );
      if (mounted && exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prioridad retirada. (-5 pts)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      exito = await widget.controller.enviarInteraccion(
        widget.hecho.id,
        'upvote',
      );
      if (mounted && exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('¡Prioridad aumentada! (+5 pts)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    }

    if (mounted && !exito) {
      setState(() => _dioLike = estadoAnterior);
    }
  }

  void _manejarCompartir() {
    final String tipoHecho = widget.hecho.tipoHecho.toUpperCase();
    final String titulo = _obtenerEstilos()['titulo'];
    final String urlMapa =
        'https://maps.google.com/?q=${widget.hecho.latitud},${widget.hecho.longitud}';

    final String mensaje =
        '🚨 $titulo en RadarCO\n\n'
        '📝 "${widget.hecho.descripcion}"\n\n'
        '📍 Ubicación exacta:\n$urlMapa\n\n'
        '¡Descarga la app de RadarCO y ayúdanos a solucionar esto juntos!';

    Share.share(mensaje, subject: 'Reporte ciudadano: $tipoHecho');
  }

  Future<void> _manejarVotoSiguePasando() async {
    if (_requiereLogin() || _cargandoEstado || _estadoActual == 'resuelto') {
      return;
    }
    if (_votoSiguePasando || _votoResuelto) return;

    setState(() {
      _votoSiguePasando = true;
      _conteoSiguePasando++;
    });

    final exito = await widget.controller.enviarInteraccion(
      widget.hecho.id,
      'sigue_pasando',
    );

    if (mounted) {
      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Confirmación registrada. (+5 pts)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _votoSiguePasando = false;
          _conteoSiguePasando--;
        });
      }
    }
  }

  Future<void> _manejarVotoResuelto() async {
    if (_requiereLogin() || _cargandoEstado || _estadoActual == 'resuelto') {
      return;
    }
    if (_votoResuelto || _votoSiguePasando) return;

    setState(() {
      _votoResuelto = true;
      _conteoResuelto++;
      if (_conteoResuelto >= 3) {
        _estadoActual = 'resuelto';
      }
    });

    final exito = await widget.controller.enviarInteraccion(
      widget.hecho.id,
      'ya_se_resolvio',
    );

    if (mounted) {
      if (exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Voto registrado. (+5 pts)'),
            backgroundColor: AppColors.exito,
            behavior: SnackBarBehavior.floating,
          ),
        );
      } else {
        setState(() {
          _votoResuelto = false;
          _conteoResuelto--;
          _estadoActual = widget.hecho.estado;
        });
      }
    }
  }

  void _verPerfilAutor() {
    if (widget.hecho.ciudadanoId == null) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'El perfil de ${widget.hecho.nombreAutor} estará disponible pronto.',
        ),
        duration: const Duration(seconds: 1),
      ),
    );
  }

  void _manejarComentario() {
    if (_requiereLogin()) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ComentariosSheet(
        hechoId: widget.hecho.id,
        autorHechoId: widget.hecho.ciudadanoId,
        controller: widget.controller,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final estilos = _obtenerEstilos();

    return Scaffold(
      backgroundColor: Colors.white,
      // --- BARRA INFERIOR DE ACCIONES ADAPTATIVA ---
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16.0),
          child: Row(
            children: [
              // Si es MIO -> Mostramos botón de ELIMINAR en vez de Upvote
              if (_esMio)
                Tooltip(
                  message: 'Eliminar mi reporte',
                  child: InkWell(
                    onTap: _eliminarMiReporte,
                    borderRadius: BorderRadius.circular(100),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 12,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.red[50],
                        borderRadius: BorderRadius.circular(100),
                        border: Border.all(color: Colors.red[200]!, width: 1.5),
                      ),
                      child: Icon(
                        Icons.delete_outline_rounded,
                        color: Colors.red[700],
                        size: 20,
                      ),
                    ),
                  ),
                )
              // Si es COMUNIDAD -> Mostramos el Upvote normal
              else
                InkWell(
                  onTap: _manejarLike,
                  borderRadius: BorderRadius.circular(100),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 16,
                      vertical: 12,
                    ),
                    decoration: BoxDecoration(
                      color: _dioLike
                          ? AppColors.azulPrimario
                          : Colors.grey[100],
                      borderRadius: BorderRadius.circular(100),
                      border: Border.all(
                        color: _dioLike
                            ? AppColors.azulPrimario
                            : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.arrow_upward_rounded,
                          color: _dioLike ? Colors.white : Colors.blueGrey[600],
                          size: 20,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '$_conteoUpvotes',
                          style: TextStyle(
                            color: _dioLike
                                ? Colors.white
                                : Colors.blueGrey[800],
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _manejarCompartir,
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
                  onPressed: _manejarComentario,
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
              background:
                  widget.hecho.fotoUrl != null &&
                      widget.hecho.fotoUrl!.isNotEmpty
                  ? Image.network(
                      widget.hecho.fotoUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      loadingBuilder: (context, child, loadingProgress) {
                        if (loadingProgress == null) return child;
                        return Container(
                          color: AppColors.azulPrimario,
                          child: const Center(
                            child: CircularProgressIndicator(
                              color: Colors.white54,
                            ),
                          ),
                        );
                      },
                      errorBuilder: (context, error, stackTrace) {
                        return Container(
                          color: AppColors.azulPrimario,
                          child: const Center(
                            child: Column(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.broken_image_outlined,
                                  size: 60,
                                  color: Colors.white24,
                                ),
                                SizedBox(height: 8),
                                Text(
                                  'Error al cargar imagen',
                                  style: TextStyle(
                                    color: Colors.white54,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    )
                  : Container(
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
                              style: TextStyle(
                                color: Colors.white54,
                                fontSize: 12,
                              ),
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
                    const SizedBox(height: 16),
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
                            color: _estadoActual == 'activo'
                                ? Colors.blue[100]
                                : Colors.green[100],
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            children: [
                              Icon(
                                Icons.circle,
                                size: 8,
                                color: _estadoActual == 'activo'
                                    ? Colors.blue[700]
                                    : Colors.green[700],
                              ),
                              const SizedBox(width: 6),
                              Text(
                                _estadoActual.toUpperCase(),
                                style: TextStyle(
                                  color: _estadoActual == 'activo'
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
                    InkWell(
                      onTap: _verPerfilAutor,
                      borderRadius: BorderRadius.circular(16),
                      child: Container(
                        padding: const EdgeInsets.all(16),
                        decoration: BoxDecoration(
                          color: Colors.white,
                          borderRadius: BorderRadius.circular(16),
                          border: Border.all(color: Colors.grey[200]!),
                          boxShadow: [
                            BoxShadow(
                              color: Colors.black.withOpacity(0.02),
                              blurRadius: 10,
                              offset: const Offset(0, 4),
                            ),
                          ],
                        ),
                        child: Row(
                          children: [
                            Container(
                              padding: const EdgeInsets.all(2),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                  color: AppColors.azulPrimario.withOpacity(
                                    0.5,
                                  ),
                                  width: 2,
                                ),
                              ),
                              child: CircleAvatar(
                                radius: 22,
                                backgroundColor: Colors.grey[100],
                                backgroundImage:
                                    widget.hecho.avatarAutor != null &&
                                        widget.hecho.avatarAutor!.isNotEmpty
                                    ? NetworkImage(widget.hecho.avatarAutor!)
                                    : null,
                                child:
                                    widget.hecho.avatarAutor == null ||
                                        widget.hecho.avatarAutor!.isEmpty
                                    ? const Icon(
                                        Icons.person,
                                        color: AppColors.azulPrimario,
                                      )
                                    : null,
                              ),
                            ),
                            const SizedBox(width: 16),
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Text(
                                        widget.hecho.nombreAutor ?? 'Ciudadano',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          fontSize: 15,
                                          color: Color(0xFF1D1E20),
                                        ),
                                      ),
                                      const SizedBox(width: 4),
                                      const Icon(
                                        Icons.verified,
                                        size: 14,
                                        color: AppColors.azulPrimario,
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    'Nivel ${_calcularNivel(widget.hecho.reputacionAutor)} • ${widget.hecho.reputacionAutor ?? 0} pts',
                                    style: TextStyle(
                                      color: Colors.grey[600],
                                      fontSize: 12,
                                      fontWeight: FontWeight.w500,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 12,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                color: AppColors.azulPrimario.withOpacity(0.05),
                                borderRadius: BorderRadius.circular(20),
                              ),
                              child: const Text(
                                'Ver perfil',
                                style: TextStyle(
                                  color: AppColors.azulPrimario,
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SizedBox(height: 24),

                    // DESCRIPCIÓN COMPLETA
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(0.04),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(
                          color: Colors.blueGrey.withOpacity(0.08),
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Row(
                            children: [
                              Icon(
                                Icons.subject_rounded,
                                size: 18,
                                color: Colors.blueGrey[400],
                              ),
                              const SizedBox(width: 8),
                              Text(
                                'DETALLES DEL REPORTE',
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.bold,
                                  color: Colors.blueGrey[400],
                                  letterSpacing: 1.0,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 12),
                          Text(
                            widget.hecho.descripcion ??
                                'Sin descripción detallada.',
                            style: TextStyle(
                              fontSize: 15,
                              color: Colors.blueGrey[900],
                              height: 1.6,
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 32),

                    // --- ZONA CONDICIONAL: GESTIÓN (OP) vs VALIDACIÓN COMUNITARIA ---
                    Text(
                      _esMio
                          ? 'GESTIÓN DE MI REPORTE'
                          : 'VALIDACIÓN COMUNITARIA',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: Colors.blueGrey[400],
                        letterSpacing: 1.0,
                      ),
                    ),
                    const SizedBox(height: 16),

                    // Botón: Sigue Pasando (SOLO COMUNIDAD)
                    if (!_esMio) ...[
                      Opacity(
                        opacity: _votoResuelto ? 0.4 : 1.0,
                        child: InkWell(
                          onTap: _manejarVotoSiguePasando,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
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
                                        _conteoSiguePasando == 1
                                            ? '1 vecino confirmó esto'
                                            : '$_conteoSiguePasando vecinos confirmaron esto',
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
                    ],

                    // Botón: Marcar como Resuelto (CONDICIONAL ROL)
                    if (_esMio)
                      // UI INSTANTÁNEA PARA EL CREADOR (OP)
                      InkWell(
                        onTap: _estadoActual == 'resuelto'
                            ? null
                            : _cerrarCasoOP,
                        borderRadius: BorderRadius.circular(20),
                        child: Container(
                          padding: const EdgeInsets.all(16),
                          decoration: BoxDecoration(
                            color: _estadoActual == 'resuelto'
                                ? Colors.blueGrey[400]
                                : AppColors.exito, // Verde brillante
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
                                child: const Icon(
                                  Icons.verified_rounded,
                                  color: Colors.white,
                                ),
                              ),
                              const SizedBox(width: 16),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      _estadoActual == 'resuelto'
                                          ? 'Caso cerrado por ti'
                                          : 'Marcar como Solucionado',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                        color: Colors.white,
                                        fontSize: 15,
                                      ),
                                    ),
                                    Text(
                                      _estadoActual == 'resuelto'
                                          ? 'Gracias por mantener limpia la ciudad'
                                          : 'Cerrar reporte instantáneamente',
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
                      )
                    else
                      // UI POR CONSENSO PARA LA COMUNIDAD
                      Opacity(
                        opacity: _votoSiguePasando ? 0.4 : 1.0,
                        child: InkWell(
                          onTap: _manejarVotoResuelto,
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
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        _estadoActual == 'resuelto'
                                            ? 'Problema solucionado'
                                            : _votoResuelto
                                            ? 'Voto de resolución enviado'
                                            : 'Marcar como Resuelto',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.bold,
                                          color: Colors.white,
                                          fontSize: 15,
                                        ),
                                      ),
                                      Text(
                                        _estadoActual == 'resuelto'
                                            ? 'La comunidad verificó la solución'
                                            : '$_conteoResuelto/3 votos comunitarios',
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
