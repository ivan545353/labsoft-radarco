import 'package:flutter/material.dart';
import '../models/comentario_model.dart';
import '../controllers/hechos_controller.dart';
import '../../../core/theme/app_colors.dart';

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

  void _enviarComentario() async {
    if (_comentarioController.text.trim().isEmpty) return;

    final exito = await widget.controller.publicarComentario(
      widget.hechoId,
      _comentarioController.text.trim(),
      respuestaAId: _respondiendoA?.id,
    );

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
      // Mantenemos el anclaje inferior y la altura correcta
      height: MediaQuery.of(context).size.height * 0.85,
      padding: EdgeInsets.only(
        bottom: MediaQuery.of(context).viewInsets.bottom,
      ),
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(30)),
      ),
      // MAGIA: El ScaffoldMessenger contenido ADENTRO del tamaño del Sheet
      child: ScaffoldMessenger(
        child: Scaffold(
          backgroundColor: Colors.transparent, // Para no arruinar tu diseño
          resizeToAvoidBottomInset:
              false, // Evita doble padding por el viewInsets
          body: Column(
            children: [
              const SizedBox(height: 12),
              Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
              const Padding(
                padding: EdgeInsets.all(20),
                child: Text(
                  'COMENTARIOS',
                  style: TextStyle(
                    fontWeight: FontWeight.bold,
                    letterSpacing: 1.2,
                  ),
                ),
              ),

              Expanded(
                child: _cargando
                    ? const Center(child: CircularProgressIndicator())
                    : _comentarios.isEmpty
                    ? const Center(child: Text('Sé el primero en comentar...'))
                    : ListView.builder(
                        padding: const EdgeInsets.symmetric(horizontal: 20),
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
                              const Divider(
                                height: 20,
                                color: Colors.transparent,
                              ),
                            ],
                          );
                        },
                      ),
              ),

              // CAJA DE ENTRADA INTELIGENTE
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: Colors.white,
                  border: Border(top: BorderSide(color: Colors.grey[200]!)),
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (_respondiendoA != null)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8.0, left: 4),
                        child: Row(
                          children: [
                            Text(
                              'Respondiendo a @${_respondiendoA!.nombreAutor}',
                              style: const TextStyle(
                                color: AppColors.azulPrimario,
                                fontWeight: FontWeight.bold,
                                fontSize: 12,
                              ),
                            ),
                            const Spacer(),
                            GestureDetector(
                              onTap: _cancelarRespuesta,
                              child: const Icon(
                                Icons.close,
                                size: 16,
                                color: Colors.grey,
                              ),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        Expanded(
                          child: TextField(
                            controller: _comentarioController,
                            focusNode: _focusNode,
                            decoration: InputDecoration(
                              hintText: _respondiendoA != null
                                  ? 'Escribe tu respuesta...'
                                  : 'Escribe un comentario...',
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(20),
                                borderSide: BorderSide.none,
                              ),
                              filled: true,
                              fillColor: Colors.grey[100],
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 16,
                                vertical: 10,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        Container(
                          decoration: const BoxDecoration(
                            color: AppColors.azulPrimario,
                            shape: BoxShape.circle,
                          ),
                          child: IconButton(
                            onPressed: _enviarComentario,
                            icon: const Icon(
                              Icons.send,
                              color: Colors.white,
                              size: 18,
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

// REDISEÑO RECURSIVO CON MODERACIÓN Y ELIMINACIÓN
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

  // --- ELIMINACIÓN CONTEXTUALMENTE SEGURA ---
  void _eliminarComentario(BuildContext modalContext) async {
    // Cerramos el menú modal de opciones usando su contexto específico para evitar el crash
    Navigator.pop(modalContext);

    final exito = await widget.controller.eliminarComentario(
      widget.comentario.id,
    );

    if (exito && mounted) {
      widget.onRefrescar();

      // Mostramos un SnackBar con margen seguro
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Comentario eliminado'),
          backgroundColor: AppColors.exito, // Verde
          behavior: SnackBarBehavior.floating,
          margin: EdgeInsets.only(
            bottom: 80,
            left: 20,
            right: 20,
          ), // Flota sobre la caja de texto
        ),
      );
    }
  }

  // --- MENÚ CONTEXTUAL DINÁMICO ---
  void _mostrarOpcionesModeracion(BuildContext parentContext) {
    showModalBottomSheet(
      context: parentContext,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (modalContext) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.comentario.esMio)
              ListTile(
                leading: const Icon(Icons.delete_outline, color: Colors.red),
                title: const Text(
                  'Eliminar comentario',
                  style: TextStyle(color: Colors.red),
                ),
                // Pasamos el contexto del modal para cerrarlo sin crashear la app
                onTap: () => _eliminarComentario(modalContext),
              )
            else ...[
              ListTile(
                leading: const Icon(
                  Icons.flag_outlined,
                  color: AppColors.problema, // Rojo
                ),
                title: const Text(
                  'Reportar comentario',
                  style: TextStyle(color: AppColors.problema), // Rojo
                ),
                onTap: () {
                  // Cerramos el menú
                  Navigator.pop(modalContext);

                  widget.controller.reportarComentario(
                    widget.comentario.id,
                    'Contenido inapropiado',
                  );

                  // SnackBar rojo flotando elegantemente
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text(
                        'Reporte enviado al equipo de moderación',
                        style: TextStyle(color: Colors.white),
                      ),
                      backgroundColor: AppColors.problema, // Rojo
                      behavior: SnackBarBehavior.floating,
                      margin: EdgeInsets.only(bottom: 80, left: 20, right: 20),
                    ),
                  );
                },
              ),
              ListTile(
                leading: const Icon(Icons.block, color: Colors.grey),
                title: const Text('Bloquear usuario'),
                onTap: () {
                  Navigator.pop(modalContext);
                },
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (widget.nivel > 0)
                Container(
                  width: 2,
                  margin: EdgeInsets.only(
                    left: (widget.nivel * 16.0),
                    right: 12,
                  ),
                  color: Colors.grey[200],
                ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      CircleAvatar(
                        radius: widget.nivel > 0 ? 14 : 18,
                        backgroundImage: widget.comentario.avatarAutor != null
                            ? NetworkImage(widget.comentario.avatarAutor!)
                            : null,
                        child: widget.comentario.avatarAutor == null
                            ? Icon(
                                Icons.person,
                                size: widget.nivel > 0 ? 14 : 18,
                              )
                            : null,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Text(
                                  widget.comentario.nombreAutor ?? 'Anónimo',
                                  style: const TextStyle(
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13,
                                    color: Colors.black87,
                                  ),
                                ),
                                if (_esAutorOriginal)
                                  Container(
                                    margin: const EdgeInsets.only(left: 6),
                                    padding: const EdgeInsets.symmetric(
                                      horizontal: 6,
                                      vertical: 2,
                                    ),
                                    decoration: BoxDecoration(
                                      color: AppColors.azulPrimario.withOpacity(
                                        0.1,
                                      ),
                                      borderRadius: BorderRadius.circular(4),
                                    ),
                                    child: const Text(
                                      'AUTOR',
                                      style: TextStyle(
                                        fontSize: 9,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.azulPrimario,
                                      ),
                                    ),
                                  ),
                                const Spacer(),
                                GestureDetector(
                                  onTap: () =>
                                      _mostrarOpcionesModeracion(context),
                                  child: const Icon(
                                    Icons.more_horiz,
                                    size: 16,
                                    color: Colors.grey,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              widget.comentario.contenido,
                              style: TextStyle(
                                fontSize: 14,
                                color: Colors.grey[800],
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.only(top: 8),
                              child: Row(
                                mainAxisAlignment:
                                    MainAxisAlignment.spaceBetween,
                                children: [
                                  if (widget.onResponder != null)
                                    GestureDetector(
                                      onTap: () => widget.onResponder!(
                                        widget.comentario,
                                      ),
                                      child: Text(
                                        'Responder',
                                        style: TextStyle(
                                          fontSize: 12,
                                          fontWeight: FontWeight.bold,
                                          color: Colors.grey[500],
                                        ),
                                      ),
                                    )
                                  else
                                    const SizedBox(),
                                  GestureDetector(
                                    onTap: _manejarLike,
                                    child: Row(
                                      children: [
                                        if (_conteoLikes > 0)
                                          Padding(
                                            padding: const EdgeInsets.only(
                                              right: 6,
                                            ),
                                            child: Text(
                                              '$_conteoLikes',
                                              style: TextStyle(
                                                fontSize: 12,
                                                fontWeight: FontWeight.bold,
                                                color: _dioLike
                                                    ? Colors.red
                                                    : Colors.grey[500],
                                              ),
                                            ),
                                          ),
                                        Icon(
                                          _dioLike
                                              ? Icons.favorite
                                              : Icons.favorite_border,
                                          size: 15,
                                          color: _dioLike
                                              ? Colors.red
                                              : Colors.grey[500],
                                        ),
                                      ],
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
        if (widget.comentario.respuestas.isNotEmpty)
          ...widget.comentario.respuestas.map(
            (hijo) => _ItemComentario(
              key: ValueKey(hijo.id),
              comentario: hijo,
              autorHechoId: widget.autorHechoId,
              nivel: widget.nivel + 1,
              controller: widget.controller,
              onResponder: widget.onResponder,
              onRefrescar: widget.onRefrescar,
            ),
          ),
      ],
    );
  }
}
