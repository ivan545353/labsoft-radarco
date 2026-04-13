import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/hecho_model.dart';

class HechosRepository {
  // Instanciamos la conexión a Supabase
  final SupabaseClient _supabase = Supabase.instance.client;

  // --- 1. GUARDAR UN NUEVO REPORTE ---
  Future<void> crearHecho(HechoModel hecho) async {
    try {
      // 1. Obtenemos el ID de autenticación actual
      final currentAuthId = _supabase.auth.currentUser!.id;

      // 2. Buscamos el ID real del ciudadano en nuestra tabla 'usuarios'
      final userResponse = await _supabase
          .from('usuarios')
          .select('id')
          .eq('auth_id', currentAuthId)
          .single(); // Ahora funcionará perfecto porque solo habrá 1 fila

      final String ciudadanoIdReal = userResponse['id'];

      // 3. Modificamos el JSON del hecho para inyectar el ID correcto
      final hechoJson = hecho.toJson();
      hechoJson['ciudadano_id'] = ciudadanoIdReal;

      // 4. Insertamos en la base de datos
      await _supabase.from('hechos').insert(hechoJson);
    } catch (e) {
      // Si algo falla, lanzamos el error para que la UI (el SnackBar rojo) lo muestre
      throw Exception('Error de base de datos: $e');
    }
  }

  // --- 2. DESCARGAR REPORTES PARA EL MAPA ---
  Future<List<HechoModel>> obtenerHechosActivos() async {
    try {
      final response = await _supabase
          .from('hechos')
          // .select('*, usuarios(nombre, avatar_url, reputacion)') <-- ESTO CAUSABA EL ERROR
          .select(
            '*',
          ) // Volvemos al select simple hasta que creemos la tabla usuarios
          .eq('estado', 'activo')
          .order('creado_en', ascending: false);

      return (response as List).map((json) {
        final map = Map<String, dynamic>.from(json);

        // Como quitamos el join, mapeamos los campos del autor como nulos directamente
        // El HechoModel y la Interfaz ya están preparados para manejar esto mágicamente.
        map['nombre_autor'] = null;
        map['avatar_autor'] = null;
        map['reputacion_autor'] = null;

        return HechoModel.fromJson(map);
      }).toList();
    } catch (e) {
      throw Exception('Error al obtener hechos: $e');
    }
  }

  // --- 3. (OPCIONAL/FUTURO) OBTENER REPORTES DE UN CIUDADANO ESPECÍFICO ---
  // Ideal para la pestaña "Perfil" o "Actividad"
  Future<List<HechoModel>> obtenerHechosPorCiudadano(String ciudadanoId) async {
    try {
      final response = await _supabase
          .from('hechos')
          .select()
          .eq('ciudadano_id', ciudadanoId)
          .order('creado_en', ascending: false); // Los más recientes primero

      final List<dynamic> datos = response;
      return datos
          .map((json) => HechoModel.fromJson(json as Map<String, dynamic>))
          .toList();
    } catch (e) {
      throw Exception('Error al descargar el historial del ciudadano: $e');
    }
  }
}
