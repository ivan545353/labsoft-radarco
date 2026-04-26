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

  // Carga los datos del ciudadano desde la tabla pública 'usuarios'
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
}
