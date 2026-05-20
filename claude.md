CLAUDE.md
markdown# AgroApp — Claude Code Context

## Proyecto
App móvil (Flutter + Supabase) para comerciantes agrícolas en Ecuador.
Permite registrar compras de productos agrícolas (cacao, maíz, café, etc.),
calcular peso neto con descuentos por merma, y enviar recibos por WhatsApp.

## Stack
- **Frontend:** Flutter 3.x (Dart)
- **Backend/DB:** Supabase (PostgreSQL + Auth + RLS)
- **State:** Provider (ChangeNotifier)
- **Router:** go_router
- **Clave:** offline-first en mente (zonas rurales sin señal estable)

## Estructura de carpetas
lib/
├── main.dart                  # Inicializa Supabase + Provider
├── app.dart                   # MaterialApp.router + GoRouter + redirección auth
├── core/
│   ├── constants/
│   │   ├── app_colors.dart
│   │   └── app_strings.dart
│   ├── services/
│   │   ├── supabase_service.dart   # getter global: final supabase = ...
│   │   └── business_provider.dart  # ChangeNotifier: carga y actualiza el negocio
│   └── utils/
│       ├── whatsapp_helper.dart    # buildReceiptMessage + sendReceipt
│       └── excel_helper.dart       # exportPurchases → Share.shareXFiles
├── features/
│   ├── auth/screens/          # login_screen.dart, register_screen.dart
│   ├── dashboard/screens/     # dashboard_screen.dart
│   ├── purchase/screens/      # purchase_screen.dart
│   ├── history/screens/       # history_screen.dart
│   └── settings/screens/      # settings_screen.dart
└── shared/
├── models/                # business_model.dart, farmer_model.dart, purchase_model.dart
└── widgets/               # loading_widget.dart

## Base de datos Supabase

### Tablas
| Tabla | Descripción |
|---|---|
| `businesses` | Un registro por comerciante. Tiene `is_active` (tú lo activas manualmente) |
| `farmers` | Clientes/agricultores del negocio. `whatsapp_number` es opcional |
| `purchases` | Cada compra. Guarda `price_per_unit` del momento, no el actual |

### Campos críticos en `purchases`
- `status`: `'active'` | `'cancelled'` — NUNCA se borra, solo se marca
- `whatsapp_sent`: bool — si se envió el recibo
- `discount_type`: `'porcentaje'` | `'libras'`
- `price_per_unit`: precio del día en el momento de la compra

### RLS
Todas las tablas tienen Row Level Security.
Política: cada usuario solo ve registros de su propio `business_id`.

## Rutas (go_router)
| Ruta | Pantalla |
|---|---|
| `/login` | LoginScreen |
| `/register` | RegisterScreen |
| `/dashboard` | DashboardScreen — pantalla principal |
| `/purchase` | PurchaseScreen — calculadora de compra |
| `/history` | HistoryScreen — historial con filtros |
| `/settings` | SettingsScreen — config + export Excel |

La redirección en `app.dart` lleva a `/dashboard` si hay sesión activa,
o a `/login` si no hay sesión.

## BusinessProvider
- Se carga una sola vez al entrar al Dashboard con `loadBusiness()`
- Se accede en cualquier pantalla con `context.read<BusinessProvider>().business`
- `updatePrice(double)` actualiza el precio en Supabase y localmente sin recargar

## Lógica de negocio

### Cálculo de compra (purchase_screen.dart)
net_weight = gross_weight - descuento
si porcentaje: gross * (1 - pct/100)
si libras:     gross - lbs
subtotal   = net_weight × price_per_unit
total_paid = subtotal - advance_deducted

### Recibo WhatsApp (whatsapp_helper.dart)
Formato predefinido con emoji. Se abre wa.me con el texto pre-escrito.
Si el agricultor no tiene WhatsApp, se guarda igual con `whatsapp_sent: false`.

### Export Excel (excel_helper.dart)
- Usa el package `excel`
- Columnas: fecha, hora, agricultor, whatsapp, peso bruto, descuento,
  peso neto, precio/unidad, adelanto, total pagado, estado, wa_enviado
- Fila de totales al final (solo compras activas)
- Se comparte con `share_plus` (funciona en Android e iOS)
- Períodos disponibles: hoy, últimos 7 días, este mes, mes anterior

## Activación de cuentas (modelo manual MVP)
1. Comerciante se registra → `is_active = false`
2. Tú recibes notificación (puedes ver en Supabase Dashboard)
3. Cobras por transferencia
4. Ejecutas en Supabase SQL Editor:
```sql
UPDATE businesses
SET is_active = true,
    subscription_expires_at = NOW() + INTERVAL '30 days'
WHERE id = 'uuid-del-negocio';
```
5. El comerciante entra y ya puede usar la app

## Convenciones de código
- Todos los widgets grandes se dividen en métodos `_buildXxx()`
- Los helpers de UI (cards, inputs) van al final de cada archivo
- No usar `BuildContext` después de `await` sin verificar `mounted`
- Números monetarios: siempre `toStringAsFixed(2)`
- Pesos: `toStringAsFixed(3)` para precisión en báscula

## Dependencias clave (pubspec.yaml)
```yaml
supabase_flutter: ^2.5.0
go_router: ^13.2.0
provider: ^6.1.2
flutter_dotenv: ^5.1.0
url_launcher: ^6.2.6
excel: ^4.0.2
path_provider: ^2.1.3
share_plus: ^9.0.0
intl: ^0.19.0
google_fonts: ^6.2.1
```

## Variables de entorno (.env — NO subir a git)
SUPABASE_URL=https://tuproyecto.supabase.co
SUPABASE_ANON_KEY=tu_anon_key

## TODOs para V2
- [ ] Sistema de adelantos/préstamos como módulo independiente
- [ ] Multi-usuario por negocio (roles: admin / empleado)
- [ ] Suscripción automatizada (Stripe o pago móvil Ecuador)
- [ ] Modo offline real con sqflite + sync queue
- [ ] Notificaciones push cuando el precio del día cambia
- [ ] Estadísticas mensuales por agricultor

Checklist final ✅
✅ Base de datos (Supabase)
✅ Estructura Flutter + pubspec.yaml
✅ Auth — Login y Registro
✅ Dashboard (Pantalla 1)
✅ Calculadora de compra (Pantalla 2)
✅ Historial (Pantalla 3)
✅ Configuración + Export Excel (Pantalla 4)
✅ WhatsApp helper
✅ Excel helper
✅ BusinessProvider
✅ CLAUDE.md para Claude Code