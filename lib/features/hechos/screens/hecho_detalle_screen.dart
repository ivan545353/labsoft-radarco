import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../models/hecho_model.dart';
import '../../auth/screens/login_screen.dart';
import '../controllers/hechos_controller.dart';
import 'package:share_plus/share_plus.dart';

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
  bool _cargandoEstado = true;
  int _conteoSiguePasando = 0;
  int _conteoResuelto = 0;
  late String _estadoActual;

  final HechosController _hechosController = HechosController();

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
    if (diferencia.inDays > 0)
      return 'Hace ${diferencia.inDays} ${diferencia.inDays == 1 ? 'día' : 'días'}';
    if (diferencia.inHours > 0)
      return 'Hace ${diferencia.inHours} ${diferencia.inHours == 1 ? 'hora' : 'horas'}';
    if (diferencia.inMinutes > 0) return 'Hace ${diferencia.inMinutes} min';
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

  // --- RECUPERAR MEMORIA DE LA BASE DE DATOS ---
  Future<void> _sincronizarEstadoPrevio() async {
    // 1. REFRESCAR DATOS: Traemos la versión más reciente de este reporte desde la BD
    final hechoActualizado = await _hechosController.obtenerHechoPorId(
      widget.hecho.id,
    );

    if (hechoActualizado != null && mounted) {
      setState(() {
        _estadoActual = hechoActualizado
            .estado; // Ahora sí dirá "resuelto" si el trigger actuó
      });
    }

    // 2. CONTEO DE VOTOS: Cargamos el 1/3, 2/3 o 3/3 real
    final conteos = await _hechosController.obtenerConteoInteracciones(
      widget.hecho.id,
    );

    if (mounted) {
      setState(() {
        _conteoSiguePasando = conteos['sigue_pasando'] ?? 0;
        _conteoResuelto = conteos['ya_se_resolvio'] ?? 0;
      });
    }

    // 3. MEMORIA DEL USUARIO: Verificamos si este usuario ya votó para bloquear el botón
    final sesionActual = Supabase.instance.client.auth.currentUser;
    if (sesionActual == null) {
      if (mounted) setState(() => _cargandoEstado = false);
      return;
    }

    final interacciones = await _hechosController.cargarMisInteracciones(
      widget.hecho.id,
    );

    if (mounted) {
      setState(() {
        _dioLike = interacciones.contains('upvote');
        _votoSiguePasando = interacciones.contains('sigue_pasando');
        _votoResuelto = interacciones.contains('ya_se_resolvio');
        _cargandoEstado = false;
      });
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

  // --- LÓGICA DE UPVOTE (PRIORIDAD) ---
  Future<void> _manejarLike() async {
    if (_requiereLogin() || _cargandoEstado) return;

    final estadoAnterior = _dioLike;
    setState(() => _dioLike = !_dioLike); // Actualización optimista

    bool exito;
    if (estadoAnterior) {
      // Si ya tenía upvote, lo quitamos
      exito = await _hechosController.quitarInteraccion(
        widget.hecho.id,
        'upvote',
      );

      // NUEVO: Avisamos al usuario que perdió los puntos
      if (mounted && exito) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Prioridad retirada. (-5 pts)'),
            behavior: SnackBarBehavior.floating,
          ),
        );
      }
    } else {
      // Si no tenía, se lo damos
      exito = await _hechosController.enviarInteraccion(
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
      // Si falló internet o la BD, revertimos silenciosamente
      setState(() => _dioLike = estadoAnterior);
    }
  }

  // --- LÓGICA DE COMPARTIR ---
  void _manejarCompartir() {
    // Formateamos un mensaje atractivo para WhatsApp o Redes Sociales
    final String tipoHecho = widget.hecho.tipoHecho.toUpperCase();
    final String titulo = _obtenerEstilos()['titulo'];

    // Generamos un link a Google Maps usando las coordenadas
    final String urlMapa =
        'https://maps.google.com/?q=${widget.hecho.latitud},${widget.hecho.longitud}';

    final String mensaje =
        '🚨 $titulo en RadarCO\n\n'
        '📝 "${widget.hecho.descripcion}"\n\n'
        '📍 Ubicación exacta:\n$urlMapa\n\n'
        '¡Descarga la app de RadarCO y ayúdanos a solucionar esto juntos!';

    // Ejecuta el menú nativo del celular
    Share.share(mensaje, subject: 'Reporte ciudadano: $tipoHecho');
  }

  // --- LÓGICA PERMANENTE (VALIDACIONES) ---
  Future<void> _manejarVotoSiguePasando() async {
    // Bloqueado si ya votó o si el caso ya está resuelto
    if (_requiereLogin() || _cargandoEstado || _estadoActual == 'resuelto')
      return;
    if (_votoSiguePasando || _votoResuelto) return;

    // UI Optimista: Registra el voto y sube el contador instantáneamente
    setState(() {
      _votoSiguePasando = true;
      _conteoSiguePasando++;
    });

    final exito = await _hechosController.enviarInteraccion(
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
        // Revertimos si falla
        setState(() {
          _votoSiguePasando = false;
          _conteoSiguePasando--;
        });
      }
    }
  }

  Future<void> _manejarVotoResuelto() async {
    if (_requiereLogin() || _cargandoEstado || _estadoActual == 'resuelto')
      return;
    if (_votoResuelto || _votoSiguePasando) return;

    setState(() {
      _votoResuelto = true;
      _conteoResuelto++;
      // LA MAGIA: Si con este voto llegamos a 3, cambiamos toda la UI del detalle a verde
      if (_conteoResuelto >= 3) {
        _estadoActual = 'resuelto';
      }
    });

    final exito = await _hechosController.enviarInteraccion(
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
          _estadoActual = widget.hecho.estado; // Revertimos el estado maestro
        });
      }
    }
  }

  void _verPerfilAutor() {
    if (widget.hecho.ciudadanoId == null) return;

    // Dejamos el Navigator listo. Por ahora puedes crear un archivo temporal
    // o simplemente imprimir en consola para verificar que el ID llega bien.
    debugPrint(
      'Navegando al perfil del ciudadano: ${widget.hecho.ciudadanoId}',
    );

    /* Navigator.push(
      context, 
      MaterialPageRoute(
        builder: (context) => PerfilUsuarioScreen(idUsuario: widget.hecho.ciudadanoId!)
      )
    );
    */

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
              // Botón de Prioridad (Upvote) con estilo "Solid Selection"
              InkWell(
                onTap: _manejarLike,
                borderRadius: BorderRadius.circular(100),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 200),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  decoration: BoxDecoration(
                    // Activo: Fondo azul sólido | Inactivo: Fondo transparente
                    color: _dioLike
                        ? AppColors.azulPrimario
                        : Colors.transparent,
                    borderRadius: BorderRadius.circular(100),
                    border: Border.all(
                      // El borde azul se mantiene siempre visible para dar estructura
                      color: AppColors.azulPrimario,
                      width: 1.5,
                    ),
                  ),
                  child: Icon(
                    Icons.arrow_upward_rounded,
                    // Activo: Ícono blanco para contrastar | Inactivo: Ícono azul
                    color: _dioLike ? Colors.white : AppColors.azulPrimario,
                    size: 24,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: _manejarCompartir, // <--- Conectado aquí
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
              background:
                  widget.hecho.fotoUrl != null &&
                      widget.hecho.fotoUrl!.isNotEmpty
                  ? Image.network(
                      widget.hecho.fotoUrl!,
                      fit: BoxFit.cover,
                      width: double.infinity,
                      // 1. Efecto de carga mientras descarga la imagen
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
                      // 2. Protección anti-crash si la imagen se borra de Supabase
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
                  // 3. Fallback si el reporte no tiene URL guardada
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
                    // TÍTULO Y ESTADO
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

                    // TARJETA DEL USUARIO (REDISEÑO)
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
                            // Avatar con borde de nivel
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
                            // Botón de acción minimalista
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

                    // DESCRIPCIÓN COMPLETA (REDISEÑO)
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(20),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey.withOpacity(
                          0.04,
                        ), // Fondo muy sutil
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
                              height:
                                  1.6, // Mayor interlineado para mejor lectura
                            ),
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(
                      height: 32,
                    ), // Espaciado antes de la validación (eliminamos el Divider)
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
