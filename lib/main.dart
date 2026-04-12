import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';

Future<void> main() async {
  // 1. Aseguramos que los engranajes de Flutter estén listos
  WidgetsFlutterBinding.ensureInitialized();

  // 2. Inicializamos la conexión al Backend (Supabase)
  await Supabase.initialize(
    url: 'https://vcktoxwnckelvyyedzmf.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZja3RveHduY2tlbHZ5eWVkem1mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4NDY4NDgsImV4cCI6MjA5MTQyMjg0OH0.GcXY6bx3nP_3Whij9kDZ17zLsmPLa7Nipbn24Iamg1s', // Reemplazá con tu Key
  );

  // 3. Arrancamos la aplicación delegando la vista a app.dart
  runApp(const RadarCiudadanoApp());
}
