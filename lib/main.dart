import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'features/hechos/services/cola_reportes_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  await Supabase.initialize(
    url: 'https://vcktoxwnckelvyyedzmf.supabase.co',
    anonKey:
        'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZja3RveHduY2tlbHZ5eWVkem1mIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NzU4NDY4NDgsImV4cCI6MjA5MTQyMjg0OH0.GcXY6bx3nP_3Whij9kDZ17zLsmPLa7Nipbn24Iamg1s',
  );

  // Fase 5: base local para reportes offline.
  await ColaReportesService.init();

  runApp(const RadarCiudadanoApp());
}
