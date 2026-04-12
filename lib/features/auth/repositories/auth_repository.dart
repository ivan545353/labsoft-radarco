import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/usuario_model.dart';

class AuthRepository {
  // Instanciamos el cliente de Supabase (Nuestra conexión a la BD)
  final SupabaseClient _supabase = Supabase.instance.client;

  // 1. Iniciar Sesión Tradicional
  Future<void> iniciarSesion(String email, String password) async {
    await _supabase.auth.signInWithPassword(email: email, password: password);
  }

  Future<bool> existeAlias(String aliasBuscado) async {
    try {
      // Hacemos una consulta rápida a nuestra tabla 'usuarios'
      // maybeSingle() devuelve un registro si lo encuentra, o null si no existe.
      final response = await _supabase
          .from('usuarios')
          .select('alias')
          .eq('alias', aliasBuscado)
          .maybeSingle();

      // Si la respuesta NO es nula, significa que el alias ya está tomado
      return response != null;
    } catch (e) {
      // Si hay un error de red, por seguridad asumimos que no pudimos verificarlo
      // El constraint UNIQUE de SQL que ejecutaste nos protegerá como última barrera
      return false;
    }
  }

  // 2. Registrar Usuario y crear su perfil en la tabla pública
  Future<void> registrarUsuario({
    required String email,
    required String password,
    required String alias,
  }) async {
    // A. Registramos la credencial en el sistema interno de Auth
    final AuthResponse response = await _supabase.auth.signUp(
      email: email,
      password: password,
    );

    final String? authId = response.user?.id;

    if (authId != null) {
      // B. Si el registro fue exitoso, creamos su perfil en nuestra tabla 'usuarios'
      // Por defecto, todo el que se registra desde la app es 'ciudadano'
      final nuevoUsuario = UsuarioModel(
        id: '', // Se genera en la BD
        authId: authId,
        rol: 'ciudadano',
        alias: alias,
        creadoEn: DateTime.now(), // Se sobreescribe en la BD
      );

      await _supabase.from('usuarios').insert(nuevoUsuario.toJson());
    }
  }

  // 3. Ingreso Anónimo
  Future<void> iniciarSesionAnonima() async {
    await _supabase.auth.signInAnonymously();
  }

  // 4. Cerrar Sesión
  Future<void> cerrarSesion() async {
    await _supabase.auth.signOut();
  }

  // 5. Obtener el perfil completo del usuario actual desde nuestra tabla
  Future<UsuarioModel?> obtenerPerfilUsuario(String authId) async {
    try {
      final response = await _supabase
          .from('usuarios')
          .select()
          .eq('auth_id', authId)
          .single(); // Esperamos un solo registro

      return UsuarioModel.fromJson(response);
    } catch (e) {
      // Si entra como anónimo, no tendrá perfil en la tabla 'usuarios'
      return null;
    }
  }

  Future<void> enviarCorreoRecuperacion(String email) async {
    await _supabase.auth.resetPasswordForEmail(email);
  }

  // --- NUEVO: Inicio de Sesión / Registro con Google ---
  Future<bool> iniciarSesionConGoogle() async {
    // Supabase se encarga de abrir el navegador y gestionar el OAuth
    return await _supabase.auth.signInWithOAuth(OAuthProvider.google);
  }
}
