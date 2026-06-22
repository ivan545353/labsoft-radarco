import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../repositories/auth_repository.dart';
import '../models/usuario_model.dart';

class UsuarioController extends ChangeNotifier {
  final AuthRepository _repository = AuthRepository();

  UsuarioModel? _perfilActual;
  UsuarioModel? get perfilActual => _perfilActual;

  bool _estaCargando = false;
  bool get estaCargando => _estaCargando;

  String? _mensajeError;
  String? get mensajeError => _mensajeError;

  Future<void> cargarPerfil() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) return;

    _estaCargando = true;
    notifyListeners();

    try {
      _perfilActual = await _repository.obtenerPerfilUsuario(user.id);
    } catch (e) {
      debugPrint('Error al cargar perfil: $e');
    } finally {
      _estaCargando = false;
      notifyListeners();
    }
  }

  // 🔥 ACTUALIZADO: Recibe los campos visuales
  Future<bool> actualizarPerfil({
    required String alias,
    required String avatarUrl,
    required String marcoEquipado,
    required String bannerEquipado,
    required String colorTema,
  }) async {
    _estaCargando = true;
    _mensajeError = null;
    notifyListeners();

    try {
      final user = Supabase.instance.client.auth.currentUser;
      if (user == null) throw Exception("Sesión no encontrada");

      // Actualizamos en la base de datos con los nuevos campos
      await Supabase.instance.client
          .from('usuarios')
          .update({
            'alias': alias,
            'avatar_url': avatarUrl,
            'marco_equipado': marcoEquipado,
            'banner_equipado': bannerEquipado,
            'color_tema': colorTema,
            'actualizado_en': DateTime.now().toIso8601String(),
          })
          .eq('auth_id', user.id);

      await cargarPerfil();
      return true;
    } catch (e) {
      _mensajeError = 'Error al guardar: $e';
      _estaCargando = false;
      notifyListeners();
      return false;
    }
  }

  Future<UsuarioModel?> obtenerPerfilPublico(String usuarioId) {
    return _repository.obtenerPerfilPorId(usuarioId);
  }
}
