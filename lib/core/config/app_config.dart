// lib/core/config/app_config.dart
//
// Centraliza la configuración de credenciales para la app.
// NOTA: La clave 'anon' de Supabase es pública por diseño.
// La seguridad real de los datos está garantizada por las
// políticas RLS (Row Level Security) configuradas en Supabase.
// NUNCA coloques aquí la clave 'service_role'.

class AppConfig {
  static const String supabaseUrl =
      'https://zugbsfrxvgcvtwjhhelw.supabase.co';

  static const String supabaseAnonKey =
      'sb_publishable_sW5NK2WA0SwEExb7Ho4DmQ_2QdQjGw5';
}
