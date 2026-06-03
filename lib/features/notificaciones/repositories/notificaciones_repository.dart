import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/notificacion_model.dart';

class NotificacionesRepository {
  final SupabaseClient _supabase = Supabase.instance.client;

  Future<List<NotificacionModel>> obtenerNotificaciones(
    String ciudadanoId,
  ) async {
    try {
      final response = await _supabase
          .from('notificaciones')
          .select()
          .eq('ciudadano_id', ciudadanoId)
          .order('creado_en', ascending: false);

      return (response as List)
          .map((json) => NotificacionModel.fromJson(json))
          .toList();
    } catch (e) {
      throw Exception('Error al descargar notificaciones: $e');
    }
  }

  Future<void> marcarComoLeida(String notificacionId) async {
    try {
      await _supabase
          .from('notificaciones')
          .update({'leida': true})
          .eq('id', notificacionId);
    } catch (e) {
      throw Exception('Error al actualizar estado: $e');
    }
  }

  Future<void> marcarTodasComoLeidas(String ciudadanoId) async {
    try {
      await _supabase
          .from('notificaciones')
          .update({'leida': true})
          .eq('ciudadano_id', ciudadanoId)
          .eq('leida', false); // Solo actualiza las que no están leídas
    } catch (e) {
      throw Exception('Error al limpiar notificaciones: $e');
    }
  }

  Future<void> eliminarNotificacion(String notificacionId) async {
    try {
      await _supabase.from('notificaciones').delete().eq('id', notificacionId);
    } catch (e) {
      throw Exception('Error al eliminar notificación: $e');
    }
  }
}
