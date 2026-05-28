import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:provider/provider.dart';
import 'core/services/business_provider.dart';
import 'features/auth/screens/login_screen.dart';
import 'features/dashboard/screens/dashboard_screen.dart';
import 'features/history/screens/history_screen.dart';
import 'features/purchase/screens/purchase_screen.dart';
import 'features/settings/screens/settings_screen.dart';
import 'features/cash/screens/cash_screen.dart';
import 'features/audit/screens/audit_timeline_screen.dart';
import 'features/archive/screens/archive_screen.dart';
import 'features/employees/screens/employees_screen.dart';
import 'features/alarms/screens/alarms_screen.dart';
import 'features/file_manager/screens/file_manager_screen.dart';
import 'features/file_manager/screens/contact_profile_screen.dart';

import 'core/globals.dart';

final _supabase = Supabase.instance.client;

final _router = GoRouter(
  navigatorKey: rootNavigatorKey,
  initialLocation: '/login',
  redirect: (context, state) {
    final session = _supabase.auth.currentSession;
    final isAuth = session != null;
    final isAuthRoute =
        state.matchedLocation == '/login' ||
        state.matchedLocation == '/register';

    if (!isAuth && !isAuthRoute) return '/login';
    if (isAuth && isAuthRoute) return '/dashboard';

    if (isAuth) {
      final role = context.read<BusinessProvider>().role;
      final protectedRoutes = [
        '/settings', '/cash', '/audit', '/employees', 
        '/archive', '/alarms', '/file_manager', '/contact_profile'
      ];
      if (protectedRoutes.any((r) => state.matchedLocation.startsWith(r))) {
        if (role != 'admin') return '/dashboard';
      }
    }
    return null;
  },
  routes: [
    GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
    GoRoute(path: '/dashboard', builder: (_, __) => const DashboardScreen()),
    GoRoute(path: '/purchase', builder: (_, __) => const PurchaseScreen()),
    GoRoute(path: '/history', builder: (_, __) => const HistoryScreen()),
    GoRoute(path: '/settings', builder: (_, __) => const SettingsScreen()),
    GoRoute(path: '/cash', builder: (_, __) => const CashScreen()),
    GoRoute(path: '/audit', builder: (_, __) => const AuditTimelineScreen()),
    GoRoute(path: '/archive', builder: (_, __) => const ArchiveScreen()),
    GoRoute(path: '/employees', builder: (_, __) => const EmployeesScreen()),
    GoRoute(path: '/alarms', builder: (_, __) => const AlarmsScreen()),
    GoRoute(path: '/file_manager', builder: (_, __) => const FileManagerScreen()),
    GoRoute(
      path: '/contact_profile',
      builder: (_, state) {
        final map = state.extra as Map<String, dynamic>?;
        final farmerId = map?['farmerId'] as String? ?? '';
        return ContactProfileScreen(farmerId: farmerId);
      },
    ),
  ],
);

class AgroApp extends StatelessWidget {
  const AgroApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp.router(
      title: 'AgroApp',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(
          seedColor: const Color(0xFF2E7D32), // verde agrícola
          brightness: Brightness.light,
        ),
        useMaterial3: true,
      ),
      routerConfig: _router,
    );
  }
}