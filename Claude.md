# CLAUDE.md — AgroApp v2

Este archivo es la fuente de verdad para el agente de IA que trabaja en este proyecto.
Léelo completo antes de escribir una sola línea de código o SQL.

---

## 1. Qué es AgroApp

App Flutter/Dart multi-tenant para comerciales agrícolas (cacao, café, maíz, etc.) en Ecuador y Latinoamérica.
Modelo de negocio: SaaS a $20/mes por negocio.
Backend: Supabase (PostgreSQL + Auth + RLS).
Deploy web: Vercel (`agro-app-ten.vercel.app`).

**Principio de diseño:** Cada dueño de negocio opera de forma 100% aislada de los demás.
El eje de aislamiento es `business_id` en todas las tablas. Nunca omitas este campo en queries ni policies.

---

## 2. Stack técnico

| Capa | Tecnología |
|---|---|
| Frontend | Flutter 3.x (Dart SDK >=3.0.0 <4.0.0) |
| Estado global | `provider` ^6.1.2 |
| Navegación | `go_router` ^13.2.0 |
| Backend | Supabase (`supabase_flutter` ^2.5.0) |
| Base de datos | PostgreSQL (Supabase) con RLS |
| Reportes | paquete `excel` ^4.0.2 + `share_plus` |
| WhatsApp | `url_launcher` |
| Variables de entorno | `flutter_dotenv` |
| UI | `google_fonts`, `intl` |

---

## 3. Estructura de carpetas

```
lib/
  core/           ← Temas, constantes, configuración Supabase
  features/
    auth/         ← Login, registro
    cash/         ← Sesiones de caja y movimientos
    dashboard/    ← Alertas, métricas, ranking
    history/      ← Historial de compras
    archive/      ← (NUEVO) Archivo de meses cerrados
    purchase/     ← Registrar nueva compra
    settings/     ← Configuración del negocio
    employees/    ← (NUEVO) Gestión de empleados / roles
  shared/         ← Widgets reutilizables, helpers, utils
```

---

## 4. Esquema de base de datos (estado actual)

### 4.1 Tablas existentes

```sql
-- businesses: un registro por negocio/usuario
businesses (
  id uuid PK,
  user_id uuid FK → auth.users,
  business_name text,
  owner_name text,
  whatsapp_number text,
  product_type text,        -- 'cacao', 'maiz', 'cafe', etc.
  weight_unit text,         -- 'quintales', 'libras'
  discount_type text,       -- 'porcentaje', 'libras'
  current_price numeric,
  is_active bool,
  subscription_expires_at timestamptz
)

-- farmers: agricultores/proveedores del negocio
farmers (
  id uuid PK,
  business_id uuid FK → businesses,
  name text,
  whatsapp_number text
)

-- purchases: cada compra registrada
purchases (
  id uuid PK,
  business_id uuid FK → businesses,
  farmer_id uuid FK → farmers,
  farmer_name text,
  gross_weight numeric,
  discount_type text,
  discount_value numeric,
  net_weight numeric,
  weight_unit text,
  price_per_unit numeric,
  subtotal numeric,
  advance_deducted numeric,
  total_paid numeric,
  status text,
  whatsapp_sent bool,
  created_at timestamptz DEFAULT now()
)

-- advances: adelantos/préstamos a agricultores
advances (
  id uuid PK,
  business_id uuid FK → businesses,
  farmer_id uuid FK → farmers,
  amount numeric,
  remaining numeric,
  status text,    -- 'active', 'fully_deducted', 'cancelled'
  notes text
)

-- cash_sessions: sesiones de caja del día
cash_sessions (
  id uuid PK,
  business_id uuid FK → businesses,
  opening_balance numeric,
  closing_balance numeric,
  total_purchases numeric,
  total_advances_given numeric,
  total_advances_deducted numeric,
  opened_at timestamptz,
  closed_at timestamptz,
  status text
)

-- cash_movements: movimientos individuales de caja
cash_movements (
  id uuid PK,
  session_id uuid FK → cash_sessions,
  business_id uuid FK → businesses,
  type text,   -- 'purchase', 'advance_given', 'advance_deducted', 'expense', 'deposit'
  amount numeric,
  note text,
  created_at timestamptz DEFAULT now()
)
```

### 4.2 Funciones RPC existentes

- `process_purchase_with_advance` — inserta compra y descuenta adelanto de forma atómica
- `get_dashboard_alerts` — alertas para el dashboard
- `get_farmer_ranking` — ranking de agricultores por volumen

---

## 5. Roadmap v2 — Funcionalidades a implementar

Orden de prioridad: de mayor a menor impacto comercial.

### PRIORIDAD 1 — Sistema de roles (Admin / Operador)

**Objetivo:** Permitir al dueño agregar empleados que solo puedan registrar compras,
sin ver ganancias, precios totales ni exportar reportes. Esto es el argumento de venta #1.

#### 5.1.1 Nueva tabla `employees`

```sql
CREATE TABLE employees (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  role        text NOT NULL CHECK (role IN ('admin', 'operator')),
  is_active   bool NOT NULL DEFAULT true,
  created_at  timestamptz DEFAULT now(),
  UNIQUE(business_id, user_id)
);

-- RLS: solo el admin del negocio puede ver y gestionar sus empleados
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

CREATE POLICY "employees_select" ON employees
  FOR SELECT USING (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
    OR user_id = auth.uid()
  );

CREATE POLICY "employees_insert" ON employees
  FOR INSERT WITH CHECK (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "employees_update" ON employees
  FOR UPDATE USING (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
  );

CREATE POLICY "employees_delete" ON employees
  FOR DELETE USING (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
  );
```

#### 5.1.2 Lógica de roles en Flutter

Crear `lib/core/services/auth_service.dart` con función `getUserRole()`:

```dart
Future<String> getUserRole(String userId, String businessId) async {
  // Primero verifica si es el dueño del negocio
  final business = await supabase
    .from('businesses')
    .select('id')
    .eq('user_id', userId)
    .eq('id', businessId)
    .maybeSingle();
  if (business != null) return 'admin';

  // Si no, busca en employees
  final employee = await supabase
    .from('employees')
    .select('role')
    .eq('user_id', userId)
    .eq('business_id', businessId)
    .eq('is_active', true)
    .maybeSingle();
  return employee?['role'] ?? 'operator';
}
```

#### 5.1.3 Guards de navegación en go_router

En `lib/core/router/app_router.dart`, agregar un `redirect` que compruebe el rol
antes de permitir acceso a rutas protegidas:

```dart
redirect: (context, state) {
  final role = context.read<AuthProvider>().role;
  final protectedRoutes = ['/settings/prices', '/cash', '/reports', '/employees'];
  if (protectedRoutes.any((r) => state.matchedLocation.startsWith(r))) {
    if (role != 'admin') return '/home'; // redirige al mostrador
  }
  return null;
},
```

#### 5.1.4 Pantallas afectadas por rol

| Pantalla | Admin | Operador |
|---|---|---|
| Mostrador / nueva compra | ✅ | ✅ |
| Historial completo | ✅ | Solo sus registros |
| Adelantos | ✅ | Consultar solamente |
| Dashboard con ganancias | ✅ | ❌ oculto |
| Panel de precios | ✅ | ❌ oculto |
| Caja / reportes | ✅ | ❌ oculto |
| Exportar Excel | ✅ | ❌ oculto |
| Gestión de empleados | ✅ | ❌ oculto |

---

### PRIORIDAD 2 — Corrección de bug: Exportación Excel (zonas horarias)

**Problema:** El filtro de fechas falla porque Flutter usa hora local y Supabase almacena en UTC.

**Fix en el servicio de reportes** (donde se construye la query):

```dart
DateTime _toUtcDayStart(DateTime localDate) {
  return DateTime(localDate.year, localDate.month, localDate.day)
      .toUtc();
}

DateTime _toUtcDayEnd(DateTime localDate) {
  return DateTime(localDate.year, localDate.month, localDate.day, 23, 59, 59)
      .toUtc();
}

// Uso en la query:
final start = _toUtcDayStart(selectedDate);
final end   = _toUtcDayEnd(selectedDate);

final data = await supabase
  .from('purchases')
  .select()
  .eq('business_id', businessId)
  .gte('created_at', start.toIso8601String())
  .lte('created_at', end.toIso8601String());
```

---

### PRIORIDAD 3 — Corrección de bug: Duplicidad de agricultores

**Problema:** Si el mismo nombre existe con distinto teléfono, no crea uno nuevo.

**Fix en el servicio de farmers:**

```dart
Future<String> findOrCreateFarmer({
  required String businessId,
  required String name,
  required String whatsappNumber,
}) async {
  // Busca por nombre + teléfono juntos
  final existing = await supabase
    .from('farmers')
    .select('id')
    .eq('business_id', businessId)
    .eq('name', name.trim())
    .eq('whatsapp_number', whatsappNumber.trim())
    .maybeSingle();

  if (existing != null) return existing['id'] as String;

  // Si no existe esa combinación exacta, crea nuevo
  final created = await supabase
    .from('farmers')
    .insert({
      'business_id': businessId,
      'name': name.trim(),
      'whatsapp_number': whatsappNumber.trim(),
    })
    .select('id')
    .single();
  return created['id'] as String;
}
```

---

### PRIORIDAD 4 — Sistema de archivo de compras (cierre de mes)

**Objetivo:** Evitar que el historial crezca infinitamente. El dueño puede "cerrar el mes"
y archivar las compras anteriores en una pantalla separada.

#### Migración necesaria

```sql
ALTER TABLE purchases
  ADD COLUMN archived_at timestamptz DEFAULT NULL;

-- Índice para no degradar las queries de historial activo
CREATE INDEX idx_purchases_archived ON purchases(business_id, archived_at)
  WHERE archived_at IS NULL;
```

#### RPC para archivar mes

```sql
CREATE OR REPLACE FUNCTION archive_purchases_before(
  p_business_id uuid,
  p_before_date date
) RETURNS integer AS $$
DECLARE
  affected integer;
BEGIN
  UPDATE purchases
  SET archived_at = now()
  WHERE business_id = p_business_id
    AND archived_at IS NULL
    AND created_at < p_before_date::timestamptz;
  GET DIAGNOSTICS affected = ROW_COUNT;
  RETURN affected;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
```

#### En Flutter — queries diferenciadas

```dart
// Historial activo (pantalla normal)
.from('purchases').select().eq('business_id', id).isFilter('archived_at', null)

// Archivo (pantalla de meses pasados)
.from('purchases').select().eq('business_id', id).not('archived_at', 'is', null)
```

#### Pantalla `ArchiveScreen`

- Accesible desde el navbar solo para Admin
- Lista de meses archivados agrupados
- Botón "Cerrar mes actual" con confirmación
- Opción de eliminar permanentemente un mes archivado (con doble confirmación)

---

### PRIORIDAD 5 — Sistema inteligente de descuentos automáticos

**Objetivo:** La app aprende el patrón de rebaja de cada agricultor.

#### Lógica de análisis (Flutter/Dart)

```dart
class DiscountSuggestion {
  final double? autoFill;         // si hay patrón consistente, sugerir directo
  final List<double> quickPicks;  // si hay variación, lista de opciones frecuentes
}

Future<DiscountSuggestion> analyzeDiscountPattern(
  String farmerId, String businessId
) async {
  final history = await supabase
    .from('purchases')
    .select('discount_value, discount_type')
    .eq('farmer_id', farmerId)
    .eq('business_id', businessId)
    .order('created_at', ascending: false)
    .limit(10);

  if (history.isEmpty) return DiscountSuggestion(autoFill: null, quickPicks: []);

  final values = history.map((r) => r['discount_value'] as double).toList();

  // Regla 1: 5 últimas iguales → autocompletar
  if (values.length >= 5 && values.take(5).toSet().length == 1) {
    return DiscountSuggestion(autoFill: values.first, quickPicks: []);
  }

  // Regla 2: variación en 3+ valores → mostrar quick picks
  final freq = <double, int>{};
  for (final v in values) freq[v] = (freq[v] ?? 0) + 1;
  if (freq.length >= 3) {
    final sorted = freq.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    return DiscountSuggestion(
      autoFill: null,
      quickPicks: sorted.take(4).map((e) => e.key).toList(),
    );
  }

  return DiscountSuggestion(autoFill: null, quickPicks: []);
}
```

#### UI en la pantalla de compra

```dart
// Cuando se selecciona un agricultor, analizar en background
onFarmerSelected: (farmer) async {
  final suggestion = await analyzeDiscountPattern(farmer.id, businessId);
  if (suggestion.autoFill != null) {
    discountController.text = suggestion.autoFill.toString();
  } else if (suggestion.quickPicks.isNotEmpty) {
    setState(() => _quickPicks = suggestion.quickPicks);
  }
},

// Widget de quick picks debajo del campo de descuento
if (_quickPicks.isNotEmpty)
  Wrap(
    spacing: 8,
    children: _quickPicks.map((v) =>
      ActionChip(
        label: Text('$v ${business.weightUnit}'),
        onPressed: () => discountController.text = v.toString(),
      )
    ).toList(),
  ),
```

---

### PRIORIDAD 6 — Panel de precios (admin only)

Pantalla dedicada `PricesPanelScreen` accesible solo para Admin:

- Lista todos los productos/tipos configurados
- Toque en el precio → edición inline (TextField)
- Guardar actualiza `businesses.current_price` vía Supabase
- Cambio reflejado en la pantalla de compra en tiempo real (usar `StreamBuilder` o `Realtime`)
- Sin confirmación extra — el cambio es inmediato pero con feedback visual (snackbar)

---

### PRIORIDAD 7 — Módulo de empleados (gestión desde la app)

Pantalla `EmployeesScreen` (solo Admin):

- Lista de empleados activos con nombre, rol y estado
- Botón "Agregar empleado": el dueño ingresa el correo del futuro empleado
  → se envía invitación de Supabase Auth (`supabase.auth.admin.inviteUserByEmail`)
  → al aceptar la invitación, el empleado queda registrado en `employees`
- Toggle para activar/desactivar empleado (sin borrar historial)
- El empleado ve solo sus propias compras del día en el historial

> **Nota:** La invitación por correo requiere configurar el template en Supabase Auth.
> En el email, incluir el nombre del negocio para contextualizar al empleado.

---

## 6. Reglas de desarrollo — seguir siempre

### Seguridad / RLS
- **Nunca** hacer queries sin filtrar por `business_id`. Sin excepción.
- Antes de crear cualquier tabla nueva, escribir las políticas RLS correspondientes.
- Las funciones `SECURITY DEFINER` solo para RPCs que necesitan permisos elevados.
  Siempre validar `business_id` dentro de la función.

### Zonas horarias
- Toda la lógica de fechas en UTC al hablar con Supabase.
- Mostrar fechas en pantalla convertidas al timezone local del dispositivo usando `intl`.

### Estado y navegación
- Usar `provider` para estado global (user, business, role).
- Usar `go_router` para toda la navegación. No usar `Navigator.push` directamente.
- Los guards de rol van en el `redirect` del router, no dispersos en pantallas.

### Estética
- Mantener el tema verde oscuro (`#1B5E20`) que ya existe.
- Nuevas pantallas deben seguir el mismo sistema de colores y tipografía existente.
- Micro-interacciones: animaciones de entrada sutiles (FadeTransition, SlideTransition).
- Diseño "premium rural": claro, legible, rápido. Nada innecesario.

### Migraciones de base de datos
- Todo cambio de esquema va en un archivo `supabase/migrations/YYYYMMDDHHMMSS_descripcion.sql`.
- Nunca modificar tablas existentes sin una migration versionada.
- Probar la migration en staging/local antes de producción.

### Manejo de errores
- Las operaciones de Supabase siempre dentro de `try/catch`.
- Mostrar mensajes de error en español al usuario. Nada de stack traces en UI.
- En operaciones críticas (registrar compra, cerrar caja), implementar retry con backoff.

---

## 7. Errores conocidos pendientes

| # | Bug | Causa | Fix |
|---|---|---|---|
| 1 | Exportación Excel dice "no hay compras" | Filtro de fechas no convierte a UTC | Ver sección 5.2 |
| 2 | Mismo agricultor con distinto teléfono no se crea | Búsqueda solo por nombre | Ver sección 5.3 |

---

## 8. Cómo ejecutar el proyecto

```bash
# Instalar dependencias
flutter pub get

# Copiar variables de entorno
cp .env.example .env
# Editar .env con tus credenciales de Supabase

# Correr en Chrome (desarrollo web)
flutter run -d chrome

# Build para Vercel
flutter build web --release
# El output queda en build/web/
```

---

## 9. Variables de entorno requeridas (.env)

```
SUPABASE_URL=secret
SUPABASE_ANON_KEY=secret
```

---

## 10. Checklist antes de hacer PR / deploy

- [ ] ¿La nueva tabla tiene RLS activado y policies correctas?
- [ ] ¿Las queries filtran por `business_id`?
- [ ] ¿Las fechas se convierten a UTC antes de enviar a Supabase?
- [ ] ¿El acceso a la funcionalidad respeta el rol (admin/operator)?
- [ ] ¿Existe la migration SQL correspondiente?
- [ ] ¿Los errores de Supabase se muestran en español al usuario?
- [ ] ¿La pantalla nueva sigue el sistema de diseño existente?