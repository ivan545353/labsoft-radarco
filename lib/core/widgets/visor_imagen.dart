import 'package:flutter/material.dart';

/// Abre una imagen a pantalla completa con zoom (pellizco + doble-tap).
Future<void> abrirVisorImagen(BuildContext context, String url) {
  return Navigator.of(context).push(
    PageRouteBuilder(
      opaque: false,
      barrierColor: Colors.black,
      pageBuilder: (_, __, ___) => VisorImagenScreen(url: url),
      transitionsBuilder: (_, anim, __, child) =>
          FadeTransition(opacity: anim, child: child),
    ),
  );
}

class VisorImagenScreen extends StatefulWidget {
  final String url;
  const VisorImagenScreen({super.key, required this.url});

  @override
  State<VisorImagenScreen> createState() => _VisorImagenScreenState();
}

class _VisorImagenScreenState extends State<VisorImagenScreen> {
  final TransformationController _control = TransformationController();
  TapDownDetails? _doubleTapDetails;

  @override
  void dispose() {
    _control.dispose();
    super.dispose();
  }

  void _onDoubleTap() {
    final yaConZoom = _control.value.getMaxScaleOnAxis() > 1.05;
    if (yaConZoom) {
      _control.value = Matrix4.identity();
      return;
    }
    final pos = _doubleTapDetails?.localPosition;
    if (pos == null) return;
    const escala = 2.8;
    _control.value = Matrix4.identity()
      ..translate(-pos.dx * (escala - 1), -pos.dy * (escala - 1))
      ..scale(escala);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Stack(
        children: [
          GestureDetector(
            onTap: () => Navigator.of(context).maybePop(),
            onDoubleTapDown: (d) => _doubleTapDetails = d,
            onDoubleTap: _onDoubleTap,
            child: InteractiveViewer(
              transformationController: _control,
              panEnabled: true,
              minScale: 1,
              maxScale: 5,
              child: SizedBox.expand(
                child: Image.network(
                  widget.url,
                  fit: BoxFit.contain,
                  loadingBuilder: (context, child, progress) {
                    if (progress == null) return child;
                    return const Center(
                      child: CircularProgressIndicator(color: Colors.white),
                    );
                  },
                  errorBuilder: (_, __, ___) => const Center(
                    child: Icon(
                      Icons.broken_image_rounded,
                      color: Colors.white54,
                      size: 48,
                    ),
                  ),
                ),
              ),
            ),
          ),
          Positioned(
            top: MediaQuery.of(context).padding.top + 8,
            right: 8,
            child: IconButton(
              icon: const Icon(
                Icons.close_rounded,
                color: Colors.white,
                size: 30,
              ),
              onPressed: () => Navigator.of(context).maybePop(),
            ),
          ),
        ],
      ),
    );
  }
}
