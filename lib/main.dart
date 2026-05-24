// main.dart
import 'package:flutter/material.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/business_provider.dart';
import 'core/services/advance_provider.dart';
import 'core/services/cash_provider.dart';
import 'core/services/dashboard_provider.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  await dotenv.load(fileName: '.env');

  await Supabase.initialize(
    url: dotenv.env['SUPABASE_URL']!,
    anonKey: dotenv.env['SUPABASE_ANON_KEY']!,
  );

  runApp(
    MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => BusinessProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => AdvanceProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => CashProvider()
        ),
        ChangeNotifierProvider(
          create: (_) => DashboardProvider()
        ),
      ],
      child: const AgroApp(),
    ),
  );
}