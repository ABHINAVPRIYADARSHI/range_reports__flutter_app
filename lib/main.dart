import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'app.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'providers/report_provider.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Initialize Supabase - replace with your project values
  await Supabase.initialize(
    url: 'https://xmhrtfahafxzerbbwxni.supabase.co',
    anonKey: 'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InhtaHJ0ZmFoYWZ4emVyYmJ3eG5pIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI3NTcwMTYsImV4cCI6MjA3ODMzMzAxNn0.IEDUEzsBeUiuag9mkEsiRP2fUnGxH8W_DzNjg_kz5JY',
    // Optionally set localStoragePrefix for web if you want isolation
    // localStoragePrefix: 'range_reporting_',
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(create: (_) => ThemeProvider()),
        ChangeNotifierProvider(create: (_) => AuthProvider()),
        ChangeNotifierProvider(create: (_) => ReportProvider()),
      ],
      child: const MyApp(),
    ),
  );
}
