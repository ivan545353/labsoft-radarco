import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme/app_colors.dart';
import '../../../core/theme/categoria_ui.dart';
import '../../../core/widgets/sello_estado.dart';
import '../../../core/widgets/aviso_inline.dart';
import '../models/hecho_model.dart';
import '../../auth/screens/login_screen.dart';
import '../controllers/hechos_controller.dart';
import 'package:share_plus/share_plus.dart';
import 'comentarios_sheet.dart';
import '../../usuarios/screens/perfil_usuario_screen.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/controllers/usuario_controller.dart';
import '../../../core/widgets/visor_imagen.dart';

class HechoDetalleScreen extends StatefulWidget {
  final HechoModel hecho;
  final HechosController controller;

  const HechoDetalleScreen({
    super.key,
    required this.hecho,
    required this.controller,
  });

  @override
  State<HechoDetalleScreen> createState() => _HechoDetalleScreenState();
}

class _HechoDetalleScreenState extends State<HechoDetalleScreen> {
  bool _dioLike = false;
  bool _votoSiguePasando = false;
  bool _votoResuelto = false;
  bool _cargandoEstado = true;
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

  Future<void> _sincronizarEstadoPrevio() async {
    final hechoActualizado = await widget.controller.obtenerHechoPorId(
      widget.hecho.id,
    );
    if (hechoActualizado != null && mounted) {
      setState(() => _estadoActual = hechoActualizado.estado);
    }

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

    final sesionActual = Supabase.instance.client.auth.currentUser;
    if (sesionActual == null) {
      if (mounted) setState(() => _cargandoEstado = false);
      return;
    }

    try {
      final usuarioData = await Supabase.instance.client
          .from('usuarios')
          .select('id')
          .eq('auth_id', sesionActual.id)
          .single();

      final ciudadanoIdReal = usuarioData['id'];
      final esPropietario = ciudadanoIdReal == widget.hecho.ciudadanoId;
      final interacciones = await widget.controller.cargarMisInteracciones(
        widget.hecho.id,
      );

      if (mounted) {
        setState(() {
          _esMio = esPropietario;
          _dioLike = interacciones.contains('upvote');
          _votoSiguePasando = interacciones.contains('sigue_pasando');
          _votoResuelto = interacciones.contains('ya_se_resolvio');
          _cargandoEstado = false;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _cargandoEstado = false);
    }
  }

  bool _requiereLogin() {
    if (Supabase.instance.client.auth.currentSession == null) {
      Navigator.push(
        context,
        MaterialPageRoute(builder: (context) => const LoginScreen()),
      );
      return true;
    }
    return false;
  }

  // Ahora el OP no "cierra" el caso, solo le avisa a todos de inmediato
  Future<void> _marcarComoPosiblementeResueltoOP() async {
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
            content: Text('Gracias por avisar a la comunidad.'),
            backgroundColor: AppColors.exito,
          ),
        );
      }
      widget.controller.cargarHechos();
    } catch (e) {
      setState(() => _cargandoEstado = false);
    }
  }

  Future<void> _manejarLike() async {
    if (_requiereLogin() || _cargandoEstado) return;
    final estadoAnterior = _dioLike;
    setState(() {
      _dioLike = !_dioLike;
      _dioLike ? _conteoUpvotes++ : _conteoUpvotes--;
    });
    bool exito = estadoAnterior
        ? await widget.controller.quitarInteraccion(widget.hecho.id, 'upvote')
        : await widget.controller.enviarInteraccion(widget.hecho.id, 'upvote');
    if (mounted && !exito) setState(() => _dioLike = estadoAnterior);
  }

  void _manejarCompartir() {
    final desc = widget.hecho.descripcion ?? '';
    final matchCat = RegExp(r'^\[(.*?)\]\s*-\s*').firstMatch(desc);
    final categoria = matchCat?.group(1)?.trim() ?? 'Reporte';
    final texto = desc.replaceFirst(RegExp(r'^\[.*?\]\s*-\s*'), '').trim();

    final estado = widget.hecho.estado == 'resuelto'
        ? '✅ Resuelto'
        : '🟠 Activo';

    final partes = <String>[
      '🚨 RadarCO · $categoria ($estado)',
      if (widget.hecho.direccion != null && widget.hecho.direccion!.isNotEmpty)
        '📍 ${widget.hecho.direccion}',
      if (texto.isNotEmpty) '"$texto"',
      if (widget.hecho.fotoUrl != null && widget.hecho.fotoUrl!.isNotEmpty)
        widget.hecho.fotoUrl!,
      '\nMirá lo que pasa en tu ciudad con RadarCO.',
    ];

    Share.share(partes.join('\n'), subject: 'RadarCO · $categoria');
  }

  Future<void> _manejarVotoSiguePasando() async {
    if (_requiereLogin() ||
        _cargandoEstado ||
        _estadoActual == 'resuelto' ||
        _votoSiguePasando ||
        _votoResuelto)
      return;
    setState(() {
      _votoSiguePasando = true;
      _conteoSiguePasando++;
    });
    final exito = await widget.controller.enviarInteraccion(
      widget.hecho.id,
      'sigue_pasando',
    );
    if (mounted && !exito) {
      setState(() {
        _votoSiguePasando = false;
        _conteoSiguePasando--;
      });
    }
  }

  Future<void> _manejarVotoResuelto() async {
    if (_requiereLogin() ||
        _cargandoEstado ||
        _estadoActual == 'resuelto' ||
        _votoResuelto ||
        _votoSiguePasando)
      return;
    setState(() {
      _votoResuelto = true;
      _conteoResuelto++;
      if (_conteoResuelto >= 3) _estadoActual = 'resuelto';
    });
    final exito = await widget.controller.enviarInteraccion(
      widget.hecho.id,
      'ya_se_resolvio',
    );
    if (mounted && !exito) {
      setState(() {
        _votoResuelto = false;
        _conteoResuelto--;
        _estadoActual = widget.hecho.estado;
      });
    }
  }

  void _manejarComentario() {
    if (_requiereLogin()) return;
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (context) => ComentariosSheet(
        hechoId: widget.hecho.id,
        autorHechoId: widget.hecho.ciudadanoId ?? '',
        controller: widget.controller,
      ),
    );
  }

  // --- CAPA 5: Reportar este hecho para moderación ---
  void _manejarReporte() {
    if (_requiereLogin()) return;

    const motivos = [
      'No corresponde a la ubicación',
      'Información falsa o engañosa',
      'Contenido inapropiado',
      'Spam o duplicado',
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (sheetContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
              child: Text(
                '¿Por qué reportás este hecho?',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.blueGrey[900],
                ),
              ),
            ),
            ...motivos.map(
              (motivo) => ListTile(
                leading: Icon(Icons.flag_outlined, color: Colors.blueGrey[400]),
                title: Text(motivo),
                onTap: () async {
                  Navigator.pop(sheetContext);
                  final exito = await widget.controller.reportarHecho(
                    widget.hecho.id,
                    motivo,
                  );
                  if (!mounted) return;
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        exito
                            ? 'Gracias. Un moderador revisará este reporte.'
                            : 'No pudimos enviar el reporte. Intentá de nuevo.',
                      ),
                      backgroundColor: exito
                          ? AppColors.exito
                          : AppColors.problema,
                      behavior: SnackBarBehavior.floating,
                    ),
                  );
                },
              ),
            ),
            const SizedBox(height: 8),
          ],
        ),
      ),
    );
  }

  Map<String, String> _parsearDescripcion() {
    String descRaw = widget.hecho.descripcion ?? 'Sin descripción';
    final match = RegExp(r'^\[(.*?)\] - (.*)$').firstMatch(descRaw);

    if (match != null) {
      return {
        'categoria': match.group(1) ?? 'Reporte',
        'descripcion': match.group(2) ?? '',
      };
    }

    String catFallback = widget.hecho.tipoHecho == 'problema'
        ? 'Problema'
        : 'Alerta';
    return {'categoria': catFallback, 'descripcion': descRaw};
  }

  String _tiempoTranscurrido(DateTime fecha) {
    final diferencia = DateTime.now().difference(fecha);
    if (diferencia.inDays > 7)
      return '${fecha.day}/${fecha.month}/${fecha.year}';
    if (diferencia.inDays > 0)
      return 'Hace ${diferencia.inDays} ${diferencia.inDays == 1 ? 'día' : 'días'}';
    if (diferencia.inHours > 0)
      return 'Hace ${diferencia.inHours} ${diferencia.inHours == 1 ? 'hora' : 'horas'}';
    if (diferencia.inMinutes > 0) return 'Hace ${diferencia.inMinutes} min';
    return 'Justo ahora';
  }

  int _calcularNivel(int? reputacion) {
    if (reputacion == null) return 1;
    return (reputacion / 50).floor() + 1;
  }

  void _verPerfilAutor() {
    if (widget.hecho.ciudadanoId == null) return;
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PerfilUsuarioScreen(
          authController: AuthController(),
          usuarioController: UsuarioController(),
          hechosController: widget.controller,
          esPerfilPropio: false,
          usuarioIdVisualizado: widget.hecho.ciudadanoId,
        ),
      ),
    );
  }

  Widget _buildSeccionLabel(String texto, IconData icono) {
    return Row(
      children: [
        Icon(icono, size: 18, color: Colors.blueGrey[400]),
        const SizedBox(width: 8),
        Text(
          texto.toUpperCase(),
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w800,
            color: Colors.blueGrey[400],
            letterSpacing: 1.2,
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final parseado = _parsearDescripcion();
    final categoriaNombre = parseado['categoria']!;
    final descripcionLimpia = parseado['descripcion']!;
    final estilosUI = CategoriaUI.de(categoriaNombre, widget.hecho.tipoHecho);
    final colorPrincipal = estilosUI.color;

    return Scaffold(
      backgroundColor: Colors.grey[50],

      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: Colors.white,
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(0.05),
              blurRadius: 20,
              offset: const Offset(0, -5),
            ),
          ],
        ),
        child: SafeArea(
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: 20.0,
              vertical: 16.0,
            ),
            child: Row(
              children: [
                InkWell(
                  onTap: _esMio ? null : _manejarLike,
                  borderRadius: BorderRadius.circular(16),
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                      horizontal: 20,
                      vertical: 14,
                    ),
                    decoration: BoxDecoration(
                      color: _dioLike
                          ? AppColors.azulPrimario
                          : Colors.blueGrey[50],
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Row(
                      children: [
                        Icon(
                          Icons.arrow_upward_rounded,
                          color: _dioLike ? Colors.white : Colors.blueGrey[700],
                          size: 22,
                        ),
                        const SizedBox(width: 8),
                        Text(
                          '$_conteoUpvotes',
                          style: TextStyle(
                            color: _dioLike
                                ? Colors.white
                                : Colors.blueGrey[900],
                            fontSize: 16,
                            fontWeight: FontWeight.w900,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: InkWell(
                    onTap: _manejarComentario,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey[50],
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.chat_bubble_outline_rounded,
                            color: Colors.blueGrey[700],
                            size: 20,
                          ),
                          const SizedBox(width: 8),
                          Text(
                            'Comentar',
                            style: TextStyle(
                              color: Colors.blueGrey[900],
                              fontSize: 15,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Semantics(
                  button: true,
                  label: 'Compartir',
                  child: InkWell(
                    onTap: _manejarCompartir,
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        border: Border.all(
                          color: Colors.blueGrey[100]!,
                          width: 1.5,
                        ),
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Icon(
                        Icons.ios_share_rounded,
                        color: Colors.blueGrey[700],
                        size: 20,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),

      body: CustomScrollView(
        slivers: [
          SliverAppBar(
            expandedHeight: 320.0,
            pinned: true,
            backgroundColor: colorPrincipal,
            iconTheme: const IconThemeData(color: Colors.white),
            elevation: 0,
            actions: [
              if (!_esMio)
                IconButton(
                  tooltip: 'Reportar',
                  icon: const Icon(Icons.flag_outlined, color: Colors.white),
                  onPressed: _manejarReporte,
                ),
            ],
            flexibleSpace: FlexibleSpaceBar(
              background:
                  widget.hecho.fotoUrl != null &&
                      widget.hecho.fotoUrl!.isNotEmpty
                  ? Stack(
                      fit: StackFit.expand,
                      children: [
                        GestureDetector(
                          onTap: () =>
                              abrirVisorImagen(context, widget.hecho.fotoUrl!),
                          child: Image.network(
                            widget.hecho.fotoUrl!,
                            fit: BoxFit.cover,
                          ),
                        ),
                        IgnorePointer(
                          child: Container(
                            decoration: BoxDecoration(
                              gradient: LinearGradient(
                                begin: Alignment.topCenter,
                                end: Alignment.bottomCenter,
                                colors: [
                                  Colors.black.withOpacity(0.6),
                                  Colors.transparent,
                                  Colors.black.withOpacity(0.4),
                                ],
                                stops: const [0.0, 0.3, 1.0],
                              ),
                            ),
                          ),
                        ),
                      ],
                    )
                  : Container(
                      color: colorPrincipal,
                      child: const Center(
                        child: Icon(
                          Icons.add_a_photo_outlined,
                          size: 60,
                          color: Colors.white30,
                        ),
                      ),
                    ),
            ),
          ),

          SliverToBoxAdapter(
            child: Container(
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
              ),
              transform: Matrix4.translationValues(0.0, -32.0, 0.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(24, 48, 24, 24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // SELLO DE TRANSPARENCIA (Capa 2 · confianza de la foto)
                        if (widget.hecho.origenFoto != null) ...[
                          const SizedBox(height: 14),
                          if (widget.hecho.origenFoto == 'en_vivo')
                            const AvisoInline(
                              icono: Icons.verified_rounded,
                              color: AppColors.exito,
                              titulo: 'Foto tomada en el lugar',
                              detalle:
                                  'Capturada en vivo desde la app. Máxima confianza.',
                            )
                          else
                            AvisoInline(
                              icono: Icons.gpp_maybe_rounded,
                              color: Colors.orange[700]!,
                              titulo:
                                  'Foto cargada · no verificada en el lugar',
                              detalle:
                                  'Reporte a distancia. Su confianza depende de la validación de la comunidad.',
                            ),
                        ],
                        const SizedBox(height: 20),
                        Row(
                          children: [
                            SelloEstado(
                              icono: estilosUI.icono,
                              texto: categoriaNombre.toUpperCase(),
                              color: colorPrincipal,
                            ),
                            const Spacer(),
                            Text(
                              _tiempoTranscurrido(widget.hecho.creadoEn),
                              style: TextStyle(
                                color: Colors.blueGrey[600],
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),

                        const SizedBox(height: 16),

                        Text(
                          descripcionLimpia,
                          style: TextStyle(
                            fontSize: 22,
                            fontWeight: FontWeight.w800,
                            color: Colors.blueGrey[900],
                            height: 1.3,
                          ),
                        ),

                        if (widget.hecho.direccion != null &&
                            widget.hecho.direccion!.isNotEmpty) ...[
                          const SizedBox(height: 10),
                          Row(
                            children: [
                              const Icon(
                                Icons.place_outlined,
                                size: 18,
                                color: AppColors.azulPrimario,
                              ),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  widget.hecho.direccion!,
                                  style: TextStyle(
                                    fontSize: 14,
                                    color: Colors.blueGrey[600],
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ],
                        const SizedBox(height: 20),

                        // Estado Visual Rápido Relativo
                        if (_estadoActual == 'resuelto')
                          const AvisoInline(
                            icono: Icons.verified_user_rounded,
                            color: AppColors.exito,
                            titulo: 'Posiblemente Solucionado',
                            detalle:
                                'El autor o la comunidad indican que este problema ya habría sido reparado.',
                          ),
                      ],
                    ),
                  ),

                  Divider(color: Colors.grey[100], thickness: 8, height: 8),

                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          _esMio
                              ? 'Gestión de tu reporte'
                              : 'Aporta a la comunidad',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.w900,
                            color: Colors.blueGrey[900],
                          ),
                        ),
                        const SizedBox(height: 16),

                        if (!_esMio) ...[
                          Semantics(
                            button: true,
                            child: GestureDetector(
                              onTap: _estadoActual == 'resuelto'
                                  ? null
                                  : _manejarVotoSiguePasando,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: _votoSiguePasando
                                      ? Colors.red[50]
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _votoSiguePasando
                                        ? Colors.red[300]!
                                        : Colors.grey[200]!,
                                    width: 2,
                                  ),
                                  boxShadow: _votoSiguePasando
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.03,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _votoSiguePasando
                                            ? Colors.red[400]
                                            : Colors.grey[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.warning_rounded,
                                        color: _votoSiguePasando
                                            ? Colors.white
                                            : Colors.blueGrey[400],
                                      ),
                                    ),
                                    const SizedBox(width: 16),
                                    Expanded(
                                      child: Column(
                                        crossAxisAlignment:
                                            CrossAxisAlignment.start,
                                        children: [
                                          Text(
                                            'El problema persiste',
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.blueGrey[900],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            '$_conteoSiguePasando vecinos lo confirmaron',
                                            style: TextStyle(
                                              color: Colors.blueGrey[600],
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_votoSiguePasando)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.red,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(height: 16),

                          Semantics(
                            button: true,
                            child: GestureDetector(
                              onTap: _manejarVotoResuelto,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color:
                                      _votoResuelto ||
                                          _estadoActual == 'resuelto'
                                      ? Colors.green[50]
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color:
                                        _votoResuelto ||
                                            _estadoActual == 'resuelto'
                                        ? Colors.green[400]!
                                        : Colors.grey[200]!,
                                    width: 2,
                                  ),
                                  boxShadow:
                                      _votoResuelto ||
                                          _estadoActual == 'resuelto'
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.03,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color:
                                            _votoResuelto ||
                                                _estadoActual == 'resuelto'
                                            ? AppColors.exito
                                            : Colors.grey[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.how_to_reg_rounded,
                                        color:
                                            _votoResuelto ||
                                                _estadoActual == 'resuelto'
                                            ? Colors.white
                                            : Colors.blueGrey[400],
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
                                                ? 'Posiblemente Solucionado'
                                                : (_votoResuelto
                                                      ? 'Aportaste a la resolución'
                                                      : '¿Crees que ya se resolvió?'),
                                            style: TextStyle(
                                              fontWeight: FontWeight.bold,
                                              fontSize: 16,
                                              color: Colors.blueGrey[900],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _estadoActual == 'resuelto'
                                                ? 'El autor o 3 vecinos indicaron que esto se arregló'
                                                : '$_conteoResuelto usuarios creen que se arregló',
                                            style: TextStyle(
                                              color: Colors.blueGrey[600],
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_votoResuelto ||
                                        _estadoActual == 'resuelto')
                                      const Icon(
                                        Icons.check_circle,
                                        color: AppColors.exito,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ] else ...[
                          // BOTÓN CERRAR OP MODIFICADO A "CONFIRMACIÓN"
                          Semantics(
                            button: true,
                            child: GestureDetector(
                              onTap: _estadoActual == 'resuelto'
                                  ? null
                                  : _marcarComoPosiblementeResueltoOP,
                              child: AnimatedContainer(
                                duration: const Duration(milliseconds: 200),
                                padding: const EdgeInsets.all(20),
                                decoration: BoxDecoration(
                                  color: _estadoActual == 'resuelto'
                                      ? Colors.green[50]
                                      : Colors.white,
                                  borderRadius: BorderRadius.circular(20),
                                  border: Border.all(
                                    color: _estadoActual == 'resuelto'
                                        ? Colors.green[300]!
                                        : Colors.grey[200]!,
                                    width: 2,
                                  ),
                                  boxShadow: _estadoActual == 'resuelto'
                                      ? []
                                      : [
                                          BoxShadow(
                                            color: Colors.black.withOpacity(
                                              0.03,
                                            ),
                                            blurRadius: 10,
                                            offset: const Offset(0, 4),
                                          ),
                                        ],
                                ),
                                child: Row(
                                  children: [
                                    Container(
                                      padding: const EdgeInsets.all(12),
                                      decoration: BoxDecoration(
                                        color: _estadoActual == 'resuelto'
                                            ? AppColors.exito
                                            : Colors.grey[100],
                                        shape: BoxShape.circle,
                                      ),
                                      child: Icon(
                                        Icons.how_to_reg_rounded,
                                        color: _estadoActual == 'resuelto'
                                            ? Colors.white
                                            : Colors.blueGrey[400],
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
                                                ? 'Confirmaste la reparación'
                                                : '¿Se solucionó el problema?',
                                            style: TextStyle(
                                              fontWeight: FontWeight.w900,
                                              fontSize: 16,
                                              color: Colors.blueGrey[900],
                                            ),
                                          ),
                                          const SizedBox(height: 4),
                                          Text(
                                            _estadoActual == 'resuelto'
                                                ? 'Tu confirmación ayuda a mantener el mapa actualizado'
                                                : 'Indica a los vecinos si ya repararon esto',
                                            style: TextStyle(
                                              color: Colors.blueGrey[600],
                                              fontSize: 13,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ),
                                    if (_estadoActual == 'resuelto')
                                      const Icon(
                                        Icons.check_circle,
                                        color: AppColors.exito,
                                      ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                        ],
                      ],
                    ),
                  ),

                  Divider(color: Colors.grey[100], thickness: 8, height: 8),

                  Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Reportado por',
                          style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w800,
                            color: Colors.blueGrey[800],
                          ),
                        ),
                        const SizedBox(height: 16),
                        Semantics(
                          button: true,
                          label: 'Ver perfil del autor',
                          child: GestureDetector(
                            onTap: _verPerfilAutor,
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 24,
                                  backgroundColor: Colors.blueGrey[50],
                                  backgroundImage:
                                      widget.hecho.avatarAutor != null
                                      ? NetworkImage(widget.hecho.avatarAutor!)
                                      : null,
                                  child: widget.hecho.avatarAutor == null
                                      ? Icon(
                                          Icons.person,
                                          color: Colors.blueGrey[300],
                                        )
                                      : null,
                                ),
                                const SizedBox(width: 16),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        widget.hecho.nombreAutor ?? 'Ciudadano',
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                        ),
                                      ),
                                      Text(
                                        'Nivel ${_calcularNivel(widget.hecho.reputacionAutor)}',
                                        style: TextStyle(
                                          color: Colors.blueGrey[600],
                                          fontSize: 13,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                        const SizedBox(height: 40),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
