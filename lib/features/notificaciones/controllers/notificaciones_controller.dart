import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notificacion_model.dart';
import '../repositories/notificaciones_repository.dart';

class NotificacionesController extends ChangeNotifier {
  final NotificacionesRepository _repository = NotificacionesRepository();

  List<NotificacionModel> _notificaciones = [];
  List<NotificacionModel> get notificaciones => _notificaciones;

  bool _estaCargando = false;
  bool get estaCargando => _estaCargando;

  String? _mensajeError;
  String? get mensajeError => _mensajeError;

  int get conteoNoLeidas => _notificaciones.where((n) => !n.leida).length;

  // --- NUEVO: Control visual del ícono en el Dock ---
  bool _mostrarPuntoEnDock = false;
  bool get mostrarPuntoEnDock => _mostrarPuntoEnDock;

  void limpiarPuntoDelDock() {
    if (_mostrarPuntoEnDock) {
      _mostrarPuntoEnDock = false;
      notifyListeners();
    }
  }

  Future<void> cargarNotificaciones() async {
    _estaCargando = true;
    _mensajeError = null;
    notifyListeners();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final userData = await Supabase.instance.client
          .from('usuarios')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      _notificaciones = await _repository.obtenerNotificaciones(userData['id']);

      // Si hay notificaciones no leídas, encendemos el punto del Dock
      if (conteoNoLeidas > 0) {
        _mostrarPuntoEnDock = true;
      }
    } catch (e) {
      _mensajeError = e.toString();
    } finally {
      _estaCargando = false;
      notifyListeners();
    }
  }

  Future<void> marcarComoLeida(String id) async {
    // Actualización optimista (UI primero)
    final index = _notificaciones.indexWhere((n) => n.id == id);
    if (index != -1 && !_notificaciones[index].leida) {
      _notificaciones[index].leida = true;
      notifyListeners();

      try {
        await _repository.marcarComoLeida(id);
      } catch (e) {
        // Si falla, revertimos
        _notificaciones[index].leida = false;
        notifyListeners();
      }
    }
  }

  Future<void> marcarTodasComoLeidas() async {
    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) return;

      final userData = await Supabase.instance.client
          .from('usuarios')
          .select('id')
          .eq('auth_id', user.id)
          .single();

      // UI primero
      for (var n in _notificaciones) {
        n.leida = true;
      }
      notifyListeners();

      await _repository.marcarTodasComoLeidas(userData['id']);
    } catch (e) {
      // Manejo de error silencioso o recargar
      cargarNotificaciones();
    }
  }

  Future<void> eliminarNotificacion(String id) async {
    final notificacionEliminada = _notificaciones.firstWhere((n) => n.id == id);
    _notificaciones.removeWhere((n) => n.id == id);
    notifyListeners();

    try {
      await _repository.eliminarNotificacion(id);
    } catch (e) {
      _notificaciones.add(notificacionEliminada);
      _notificaciones.sort((a, b) => b.creadoEn.compareTo(a.creadoEn));
      notifyListeners();
    }
  }
}
