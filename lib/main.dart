// main.dart
import 'package:flutter/material.dart';
import 'core/config/app_config.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'core/services/business_provider.dart';
import 'core/services/advance_provider.dart';
import 'core/services/cash_provider.dart';
import 'core/services/dashboard_provider.dart';
import 'core/services/local_db_service.dart';
import 'core/services/sync_service.dart';
import 'core/services/notification_service.dart';
import 'app.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es');
  // Credenciales cargadas desde AppConfig (ver lib/core/config/app_config.dart)

  await LocalDbService.initialize();
  await NotificationService.initialize();
  SyncService.initialize();

  await Supabase.initialize(
    url: AppConfig.supabaseUrl,
    anonKey: AppConfig.supabaseAnonKey,
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