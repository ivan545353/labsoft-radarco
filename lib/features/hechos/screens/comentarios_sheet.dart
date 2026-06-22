import 'package:flutter/material.dart';
import '../models/comentario_model.dart';
import '../controllers/hechos_controller.dart';
import '../../../core/theme/app_colors.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../usuarios/screens/perfil_usuario_screen.dart';
import '../../auth/controllers/auth_controller.dart';
import '../../auth/controllers/usuario_controller.dart';

// Formato de fecha/hora localizado es-AR sin dependencias externas.
// Ej.: "12 jun 2026, 14:30". Usa hora local del dispositivo.
const List<String> _mesesEsAr = [
  'ene',
  'feb',
  'mar',
  'abr',
  'may',
  'jun',
  'jul',
  'ago',
  'sep',
  'oct',
  'nov',
  'dic',
];

String _formatearFechaHora(DateTime fecha) {
  final f = fecha.toLocal();
  final hh = f.hour.toString().padLeft(2, '0');
  final mm = f.minute.toString().padLeft(2, '0');
  return '${f.day} ${_mesesEsAr[f.month - 1]} ${f.year}, $hh:$mm';
}

class ComentariosSheet extends StatefulWidget {
  final String hechoId;
  final String autorHechoId;
  final HechosController controller;

  const ComentariosSheet({
    super.key,
    required this.hechoId,
    required this.autorHechoId,
    required this.controller,
  });

  @override
  State<ComentariosSheet> createState() => _ComentariosSheetState();
}

class _ComentariosSheetState extends State<ComentariosSheet> {
  final TextEditingController _comentarioController = TextEditingController();
  final FocusNode _focusNode = FocusNode();

  List<ComentarioModel> _comentarios = [];
  bool _cargando = true;
  ComentarioModel? _respondiendoA;
  File? _fotoEvidencia;
  bool _subiendoFoto = false;

  @override
  void initState() {
    super.initState();
    _cargarComentarios();
  }

  @override
  void dispose() {
    _comentarioController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  Future<void> _cargarComentarios() async {
    final listaPlana = await widget.controller.obtenerComentarios(
      widget.hechoId,
    );
    final padres = listaPlana.where((c) => c.respuestaAId == null).toList();

    for (var padre in padres) {
      padre.respuestas = listaPlana
          .where((c) => c.respuestaAId == padre.id)
          .toList();
      for (var hijo in padre.respuestas) {
        hijo.respuestas = listaPlana
            .where((c) => c.respuestaAId == hijo.id)
            .toList();
      }
    }

    if (mounted) {
      setState(() {
        _comentarios = padres;
        _cargando = false;
      });
    }
  }

  void _iniciarRespuesta(ComentarioModel comentario) {
    setState(() {
      _respondiendoA = comentario;
    });
    _focusNode.requestFocus();
  }

  void _cancelarRespuesta() {
    setState(() {
      _respondiendoA = null;
    });
    _comentarioController.clear();
    _focusNode.unfocus();
  }

  Future<void> _elegirFotoEvidencia() async {
    final fuente = await showModalBottomSheet<ImageSource>(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(
                Icons.camera_alt_rounded,
                color: AppColors.azulPrimario,
              ),
              title: const Text('Tomar foto'),
              onTap: () => Navigator.pop(ctx, ImageSource.camera),
            ),
            ListTile(
              leading: const Icon(
                Icons.photo_library_rounded,
                color: AppColors.azulPrimario,
              ),
              title: const Text('Elegir de la galería'),
              onTap: () => Navigator.pop(ctx, ImageSource.gallery),
            ),
          ],
        ),
      ),
    );
    if (fuente == null) return;

    final pickedFile = await ImagePicker().pickImage(
      source: fuente,
      imageQuality: 70,
      maxWidth: 1200,
    );
    if (pickedFile != null && mounted) {
      setState(() => _fotoEvidencia = File(pickedFile.path));
    }
  }

  Future<String?> _subirFotoEvidencia(File archivo) async {
    try {
      final uid = Supabase.instance.client.auth.currentUser?.id ?? 'anon';
      final ruta =
          'comentarios/${DateTime.now().millisecondsSinceEpoch}_$uid.jpg';
      final storage = Supabase.instance.client.storage.from('fotos_hechos');
      await storage.upload(ruta, archivo);
      return storage.getPublicUrl(ruta);
    } catch (e) {
      return null;
    }
  }

  void _enviarComentario() async {
    final texto = _comentarioController.text.trim();
    if (texto.isEmpty && _fotoEvidencia == null) return;

    setState(() => _subiendoFoto = true);

    String? fotoUrl;
    if (_fotoEvidencia != null) {
      fotoUrl = await _subirFotoEvidencia(_fotoEvidencia!);
      if (fotoUrl == null) {
        if (mounted) setState(() => _subiendoFoto = false);
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('No se pudo subir la foto. Intentá de nuevo.'),
              backgroundColor: AppColors.problema,
              behavior: SnackBarBehavior.floating,
            ),
          );
        }
        return;
      }
    }

    final exito = await widget.controller.publicarComentario(
      widget.hechoId,
      texto.isEmpty ? 'Agregó evidencia' : texto,
      respuestaAId: _respondiendoA?.id,
      fotoUrl: fotoUrl,
    );

    if (!mounted) return;
    setState(() {
      _subiendoFoto = false;
      _fotoEvidencia = null;
    });

    if (exito) {
      _cancelarRespuesta();
      _cargarComentarios();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo enviar el comentario.'),
          backgroundColor: AppColors.problema,
          behavior: SnackBarBehavior.floating,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent,
          resizeToAvoidBottomInset: false,
          body: Column(
            children: [
              // --- CABECERA ---
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 16,
                ),
                child: Row(
                  children: [
                    Text(
                      'Comunidad',
                      style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w900,
                        color: Colors.blueGrey[900],
                      ),
                    ),
                    const Spacer(),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.blueGrey[50],
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Text(
                        _cargando ? '...' : '${_comentarios.length} hilos',
                        style: TextStyle(
                          color: Colors.blueGrey[700],
                          fontWeight: FontWeight.bold,
                          fontSize: 12,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: Colors.grey[200]),

              // --- LISTA DE COMENTARIOS ---
              Expanded(
                child: _cargando
                    ? const Center(
                        child: CircularProgressIndicator(
                          color: AppColors.azulPrimario,
                        ),
                      )
                    : _comentarios.isEmpty
                    ? Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            Icon(
                              Icons.forum_rounded,
                              size: 60,
                              color: Colors.blueGrey[100],
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Sin comentarios aún',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 16,
                                color: Colors.blueGrey[800],
                              ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Sé el primero en aportar información.',
                              style: TextStyle(
                                color: Colors.blueGrey[400],
                                fontSize: 14,
                              ),
                            ),
                          ],
                        ),
                      )
                    : ListView.builder(
                        padding: const EdgeInsets.only(
                          left: 20,
                          right: 20,
                          top: 16,
                          bottom: 24,
                        ),
                        itemCount: _comentarios.length,
                        itemBuilder: (context, i) {
                          return Column(
                            children: [
                              _ItemComentario(
                                comentario: _comentarios[i],
                                autorHechoId: widget.autorHechoId,
                                controller: widget.controller,
                                onResponder: _iniciarRespuesta,
                                onRefrescar: _cargarComentarios,
                              ),
                              if (i < _comentarios.length - 1)
                                Padding(
                                  padding: const EdgeInsets.symmetric(
                                    vertical: 8.0,
                                  ),
                                  child: Divider(
                                    color: Colors.grey[100],
                                    thickness: 1,
                                  ),
                                ),
                            ],
                          );
                        },
                      ),
              ),

              // --- CAJA DE ENTRADA INTELIGENTE FLOTANTE ---
              Container(
                padding: EdgeInsets.fromLTRB(
                  20,
                  16,
                  20,
                  16 +
                      MediaQuery.of(
                        context,
                      ).padding.bottom, // <- El truco maestro
                ),
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
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Smart Chip de "Respondiendo a..."
                    if (_respondiendoA != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 12.0),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.azulPrimario.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(100),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                Icons.reply_rounded,
                                size: 14,
                                color: AppColors.azulPrimario,
                              ),
                              const SizedBox(width: 6),
                              Text(
                                'Respondiendo a @${_respondiendoA!.nombreAutor}',
                                style: const TextStyle(
                                  color: AppColors.azulPrimario,
                                  fontWeight: FontWeight.w800,
                                  fontSize: 12,
                                ),
                              ),
                              const SizedBox(width: 8),
                              GestureDetector(
                                onTap: _cancelarRespuesta,
                                child: Container(
                                  padding: const EdgeInsets.all(2),
                                  decoration: BoxDecoration(
                                    color: AppColors.azulPrimario.withOpacity(
                                      0.2,
                                    ),
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close,
                                    size: 12,
                                    color: AppColors.azulPrimario,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),

                    // Input Text y Botón Enviar
                    // Preview de la foto-evidencia seleccionada (HU4.3)
                    if (_fotoEvidencia != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 10),
                        child: Stack(
                          children: [
                            ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Image.file(
                                _fotoEvidencia!,
                                height: 80,
                                width: 80,
                                fit: BoxFit.cover,
                              ),
                            ),
                            Positioned(
                              top: 2,
                              right: 2,
                              child: GestureDetector(
                                onTap: () =>
                                    setState(() => _fotoEvidencia = null),
                                child: Container(
                                  decoration: const BoxDecoration(
                                    color: Colors.black54,
                                    shape: BoxShape.circle,
                                  ),
                                  child: const Icon(
                                    Icons.close_rounded,
                                    color: Colors.white,
                                    size: 18,
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),

                    // Input Text y Botón Enviar
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.end,
                      children: [
                        // Botón adjuntar foto-evidencia
                        GestureDetector(
                          onTap: _subiendoFoto ? null : _elegirFotoEvidencia,
                          child: Container(
                            height: 48,
                            width: 48,
                            margin: const EdgeInsets.only(right: 8),
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              shape: BoxShape.circle,
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: Icon(
                              Icons.add_a_photo_rounded,
                              color: Colors.blueGrey[400],
                              size: 20,
                            ),
                          ),
                        ),
                        Expanded(
                          child: Container(
                            decoration: BoxDecoration(
                              color: Colors.grey[100],
                              borderRadius: BorderRadius.circular(24),
                              border: Border.all(color: Colors.grey[200]!),
                            ),
                            child: TextField(
                              controller: _comentarioController,
                              focusNode: _focusNode,
                              maxLines: 4,
                              minLines: 1,
                              style: const TextStyle(fontSize: 15),
                              decoration: InputDecoration(
                                hintText: _respondiendoA != null
                                    ? 'Escribe tu respuesta...'
                                    : 'Aporta a la comunidad...',
                                hintStyle: TextStyle(
                                  color: Colors.grey[500],
                                  fontSize: 14,
                                ),
                                border: InputBorder.none,
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 14,
                                ),
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        GestureDetector(
                          onTap: _enviarComentario,
                          child: Container(
                            height: 48,
                            width: 48,
                            decoration: BoxDecoration(
                              color: AppColors.azulPrimario,
                              shape: BoxShape.circle,
                              boxShadow: [
                                BoxShadow(
                                  color: AppColors.azulPrimario.withOpacity(
                                    0.3,
                                  ),
                                  blurRadius: 10,
                                  offset: const Offset(0, 4),
                                ),
                              ],
                            ),
                            child: const Icon(
                              Icons.send_rounded,
                              color: Colors.white,
                              size: 20,
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ============================================================================
// REDISEÑO PREMIUM DEL COMENTARIO (Threading)
// ============================================================================
class _ItemComentario extends StatefulWidget {
  final ComentarioModel comentario;
  final String autorHechoId;
  final int nivel;
  final ValueChanged<ComentarioModel>? onResponder;
  final VoidCallback onRefrescar;
  final HechosController controller;

  const _ItemComentario({
    super.key,
    required this.comentario,
    required this.autorHechoId,
    required this.controller,
    required this.onRefrescar,
    this.nivel = 0,
    this.onResponder,
  });

  @override
  State<_ItemComentario> createState() => _ItemComentarioState();
}

class _ItemComentarioState extends State<_ItemComentario> {
  late bool _dioLike;
  late int _conteoLikes;

  bool get _esAutorOriginal =>
      widget.comentario.ciudadanoId == widget.autorHechoId;

  @override
  void initState() {
    super.initState();
    _dioLike = widget.comentario.dioLike;
    _conteoLikes = widget.comentario.conteoLikes;
  }

  void _manejarLike() async {
    final estadoAnterior = _dioLike;
    setState(() {
      _dioLike = !_dioLike;
      _dioLike ? _conteoLikes++ : _conteoLikes--;
    });

    final exito = await widget.controller.alternarLikeComentario(
      widget.comentario.id,
      _dioLike,
    );
    if (!exito && mounted) {
      setState(() {
        _dioLike = estadoAnterior;
        estadoAnterior ? _conteoLikes++ : _conteoLikes--;
      });
    }
  }

  void _eliminarComentario(BuildContext modalContext) async {
    Navigator.pop(modalContext); // cierra el menú de opciones

    final confirmado = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Eliminar comentario'),
        content: const Text(
          '¿Seguro que querés eliminar tu comentario? Esta acción no se puede deshacer.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: Text(
              'Cancelar',
              style: TextStyle(color: Colors.blueGrey[600]),
            ),
          ),
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.red, fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );

    if (confirmado != true) return; // canceló: no borramos nada

    final exito = await widget.controller.eliminarComentario(
      widget.comentario.id,
    );

    if (!mounted) return;
    if (exito) {
      widget.onRefrescar();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comentario eliminado'),
          backgroundColor: AppColors.exito,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 100, left: 20, right: 20),
        ),
      );
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo eliminar el comentario.'),
          backgroundColor: AppColors.problema,
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(bottom: 100, left: 20, right: 20),
        ),
      );
    }
  }

  void _verPerfilComentarista() {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PerfilUsuarioScreen(
          authController: AuthController(),
          usuarioController: UsuarioController(),
          hechosController: widget.controller,
          esPerfilPropio: false,
          usuarioIdVisualizado: widget.comentario.ciudadanoId,
        ),
      ),
    );
  }

  void _mostrarOpcionesModeracion(BuildContext parentContext) {
    showModalBottomSheet(
      context: parentContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (modalContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 12.0),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const SizedBox(height: 16),
              if (widget.comentario.esMio)
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.red[50],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.delete_outline,
                      color: Colors.red,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Eliminar mi comentario',
                    style: TextStyle(
                      color: Colors.red,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () => _eliminarComentario(modalContext),
                )
              else ...[
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.orange[50],
                      shape: BoxShape.circle,
                    ),
                    child: Icon(
                      Icons.flag_outlined,
                      color: Colors.orange[800],
                      size: 20,
                    ),
                  ),
                  title: Text(
                    'Reportar como inapropiado',
                    style: TextStyle(
                      color: Colors.orange[800],
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  onTap: () {
                    Navigator.pop(modalContext);
                    widget.controller.reportarComentario(
                      widget.comentario.id,
                      'Contenido inapropiado',
                    );
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(
                        content: const Text(
                          'Reporte enviado a moderación',
                          style: TextStyle(color: Colors.white),
                        ),
                        backgroundColor: Colors.orange[800],
                        behavior: SnackBarBehavior.floating,
                        margin: const EdgeInsets.only(
                          bottom: 100,
                          left: 20,
                          right: 20,
                        ),
                      ),
                    );
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.grey[100],
                      shape: BoxShape.circle,
                    ),
                    child: const Icon(
                      Icons.block,
                      color: Colors.grey,
                      size: 20,
                    ),
                  ),
                  title: const Text(
                    'Bloquear usuario',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  onTap: () => Navigator.pop(modalContext),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // Escala del hilo (threading)
    final double paddingIndent = widget.nivel > 0 ? 32.0 : 0.0;
    final double avatarSize = widget.nivel > 0 ? 14.0 : 20.0;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: EdgeInsets.only(left: paddingIndent, top: 8, bottom: 8),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Avatar
              GestureDetector(
                onTap: _verPerfilComentarista,
                child: CircleAvatar(
                  radius: avatarSize,
                  backgroundColor: Colors.blueGrey[50],
                  backgroundImage: widget.comentario.avatarAutor != null
                      ? NetworkImage(widget.comentario.avatarAutor!)
                      : null,
                  child: widget.comentario.avatarAutor == null
                      ? Icon(
                          Icons.person,
                          size: avatarSize,
                          color: Colors.blueGrey[300],
                        )
                      : null,
                ),
              ),
              const SizedBox(width: 12),

              // Contenido
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Nombre y Badge Autor
                    Row(
                      children: [
                        Text(
                          widget.comentario.nombreAutor ?? 'Anónimo',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: widget.nivel > 0 ? 13 : 14,
                            color: Colors.blueGrey[900],
                          ),
                        ),
                        if (_esAutorOriginal)
                          Container(
                            margin: const EdgeInsets.only(left: 8),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 6,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: AppColors.azulPrimario,
                              borderRadius: BorderRadius.circular(4),
                            ),
                            child: const Text(
                              'AUTOR',
                              style: TextStyle(
                                fontSize: 9,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                        const Spacer(),
                        GestureDetector(
                          onTap: () => _mostrarOpcionesModeracion(context),
                          child: Icon(
                            Icons.more_horiz,
                            size: 16,
                            color: Colors.blueGrey[300],
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      _formatearFechaHora(widget.comentario.creadoEn),
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.blueGrey[400],
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                    const SizedBox(height: 4),

                    // Texto del Comentario
                    Text(
                      widget.comentario.contenido,
                      style: TextStyle(
                        fontSize: widget.nivel > 0 ? 14 : 15,
                        color: Colors.blueGrey[800],
                        height: 1.3,
                      ),
                    ),

                    // Foto de evidencia adjunta (HU4.3)
                    if (widget.comentario.fotoUrl != null &&
                        widget.comentario.fotoUrl!.isNotEmpty) ...[
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(14),
                        child: Image.network(
                          widget.comentario.fotoUrl!,
                          width: double.infinity,
                          height: 160,
                          fit: BoxFit.cover,
                          cacheWidth: 600,
                          loadingBuilder: (context, child, progress) {
                            if (progress == null) return child;
                            return Container(
                              height: 160,
                              color: Colors.grey[100],
                              child: const Center(
                                child: CircularProgressIndicator(
                                  strokeWidth: 2,
                                ),
                              ),
                            );
                          },
                          errorBuilder: (context, error, stack) => Container(
                            height: 160,
                            color: Colors.grey[100],
                            child: const Center(
                              child: Icon(
                                Icons.broken_image_rounded,
                                color: Colors.grey,
                              ),
                            ),
                          ),
                        ),
                      ),
                    ],

                    const SizedBox(height: 8),

                    // Acciones (Responder, Like)
                    Row(
                      children: [
                        if (widget.onResponder != null)
                          GestureDetector(
                            onTap: () => widget.onResponder!(widget.comentario),
                            child: Text(
                              'Responder',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.bold,
                                color: Colors.blueGrey[400],
                              ),
                            ),
                          ),
                        const Spacer(),
                        GestureDetector(
                          onTap: _manejarLike,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 10,
                              vertical: 4,
                            ),
                            decoration: BoxDecoration(
                              color: _dioLike
                                  ? Colors.red[50]
                                  : Colors.grey[50],
                              borderRadius: BorderRadius.circular(100),
                            ),
                            child: Row(
                              children: [
                                Icon(
                                  _dioLike
                                      ? Icons.favorite_rounded
                                      : Icons.favorite_border_rounded,
                                  size: 14,
                                  color: _dioLike
                                      ? Colors.red[500]
                                      : Colors.blueGrey[300],
                                ),
                                if (_conteoLikes > 0) ...[
                                  const SizedBox(width: 4),
                                  Text(
                                    '$_conteoLikes',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold,
                                      color: _dioLike
                                          ? Colors.red[600]
                                          : Colors.blueGrey[500],
                                    ),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),

        // Comentarios anidados (Recursividad controlada)
        if (widget.comentario.respuestas.isNotEmpty)
          ...widget.comentario.respuestas.map(
            (hijo) => _ItemComentario(
              key: ValueKey(hijo.id),
              comentario: hijo,
              autorHechoId: widget.autorHechoId,
              nivel: widget.nivel + 1, // Aumentamos la sangría visual
              controller: widget.controller,
              onResponder: widget.onResponder,
              onRefrescar: widget.onRefrescar,
            ),
          ),
      ],
    );
  }
}
