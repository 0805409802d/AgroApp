# Contexto del Proyecto "AgroApp"

Este documento sirve como base de conocimiento para la IA sobre la arquitectura, base de datos, estructura de frontend y funcionalidades pendientes o errores conocidos del proyecto. Su objetivo es mantener un contexto claro para futuras conversaciones e iteraciones de código.

## 🛠️ Tecnologías y Stack

* **Frontend:** Flutter (Dart SDK >=3.0.0 <4.0.0)
* **Backend:** Supabase (PostgreSQL, Authentication)
* **Gestión de Estado:** `provider`
* **Enrutamiento:** `go_router`
* **Otras librerías clave:** `excel` (reportes), `url_launcher` (WhatsApp), `flutter_dotenv` (variables de entorno), `intl`, `google_fonts`, `share_plus`.

## 📂 Estructura del Proyecto (Frontend - Flutter)

El código de Flutter está organizado principalmente dentro de la carpeta `lib/`:
* `lib/core/`: Configuraciones centrales, temas y constantes de la aplicación.
* `lib/features/`: Módulos de la aplicación divididos por funcionalidad:
  * `auth/`: Autenticación y registro.
  * `cash/`: Control de caja diaria (sesiones y movimientos).
  * `dashboard/`: Pantalla principal con alertas y métricas.
  * `history/`: Historial de compras registradas.
  * `purchase/`: Lógica para procesar y registrar una nueva compra de productos.
  * `settings/`: Configuración del negocio (precio, unidad, tipo de producto).
* `lib/shared/`: Widgets reutilizables, utilidades y helpers comunes para toda la app.

## 🗄️ Esquema de Base de Datos (Supabase / PostgreSQL)

Todas las tablas cuentan con **Row Level Security (RLS)** activado, asegurando que cada dueño de negocio (`user_id` vinculado a `auth.users`) solo pueda ver e interactuar con su propia información.

### 1. `businesses` (Negocios)
Almacena la configuración principal del usuario/negocio.
* Campos: `id`, `user_id`, `business_name`, `owner_name`, `whatsapp_number`, `product_type` (cacao, maiz, etc.), `weight_unit` (quintales, libras), `discount_type` (porcentaje, libras), `current_price`, `is_active`, `subscription_expires_at`.

### 2. `farmers` (Agricultores / Clientes)
Personas a las que el negocio les compra el producto.
* Campos: `id`, `business_id`, `name`, `whatsapp_number`.

### 3. `purchases` (Compras / Transacciones)
El registro principal de cada compra de producto.
* Campos: `id`, `business_id`, `farmer_id`, `farmer_name`, `gross_weight` (peso bruto), `discount_type`, `discount_value`, `net_weight` (peso neto), `weight_unit`, `price_per_unit`, `subtotal`, `advance_deducted` (dinero descontado por adelantos), `total_paid` (total pagado), `status`, `whatsapp_sent`.

### 4. `advances` (Adelantos / Préstamos)
Dinero adelantado a los agricultores que luego es descontado en las compras.
* Campos: `id`, `business_id`, `farmer_id`, `amount` (monto total), `remaining` (saldo pendiente), `status` (active, fully_deducted, cancelled), `notes`.

### 5. `cash_sessions` & `cash_movements` (Caja)
Control financiero del dinero físico/digital durante el día.
* **`cash_sessions`**: `id`, `business_id`, `opening_balance`, `closing_balance`, `total_purchases`, `total_advances_given`, `total_advances_deducted`, `opened_at`, `closed_at`, `status`.
* **`cash_movements`**: Movimientos individuales asociados a una sesión (`purchase`, `advance_given`, `advance_deducted`, `expense`, `deposit`).

### ⚙️ Funciones RPC y Triggers Importantes
* **`process_purchase_with_advance`**: RPC (Remote Procedure Call) que procesa de manera atómica una compra. Inserta en `purchases` y calcula/descuenta automáticamente el saldo de la tabla `advances`.
* **Triggers de caja**: Actualizan automáticamente los movimientos de caja (`cash_movements`) cuando se realiza una compra.
* **Funciones analíticas**: `get_dashboard_alerts`, `get_farmer_ranking`.

---

## 🚨 Errores Conocidos y Mejoras Pendientes (Roadmap)

Basado en las pruebas y el archivo `Improvements.md`, los siguientes puntos requieren atención o desarrollo:

### Errores (Bugs)
1. **Exportación a Excel / Reportes fallida:**
   * **Problema:** Al intentar descargar reportes de hoy o cálculos, el sistema devuelve *"No hay compras en este periodo"* y falla, incluso cuando existen compras de prueba guardadas.
   * **Causa posible:** Lógica defectuosa en el filtrado de fechas (zonas horarias de Supabase vs Flutter) o en el formato en el que se envían los datos al paquete `excel`.
2. **Duplicidad y Creación de Contactos (`farmers`):**
   * **Problema:** Si se crea un historial para un agricultor con el mismo nombre pero diferente número de teléfono, el sistema no crea un nuevo agricultor, sobrescribiendo o asumiendo que es el mismo.
   * **Solución requerida:** Modificar la lógica de búsqueda/creación de agricultores para que considere la combinación única de `name` + `whatsapp_number`.

### Sistemas Incompletos / Nuevas Features
3. **Archivado / Limpieza de Historial de Compras:**
   * **Problema actual:** La lista del historial de compras crecerá infinitamente en el frontend.
   * **Solución requerida:** Crear una sección de "Archivo" o "Cierre de Mes". Las compras de meses pasados deben poder moverse a otra pantalla donde el dueño decida conservarlas archivadas o eliminarlas masivamente. Se debe añadir un botón en el NavBar para acceder a esta nueva pantalla.
4. **Sistema Inteligente de Rebajas / Descuentos Automatizados:**
   * **Requisito:** El sistema debe "aprender" de los patrones de rebaja de cada agricultor.
   * **Regla de negocio 1:** Si se le aplica exactamente la misma rebaja (ej. 5 lbs) a un agricultor 5 veces consecutivas, el sistema debe autocompletar este descuento en el futuro.
   * **Regla de negocio 2:** Si las rebajas varían (ej. a veces 5 lbs, a veces 10 lbs), a partir de la 3ra vez de variación, en lugar de autocompletar, debe mostrar una "lista rápida" sugerida debajo de los campos de texto con los valores más frecuentes para que el dueño seleccione rápidamente.
   * **Impacto técnico:** Se requerirá análisis del historial del agricultor (`purchases`) al seleccionar su nombre para inferir el patrón y actualizar la UI dinámicamente.

## 📝 Notas para el Desarrollador (IA)
* **Estética:** Al desarrollar nuevas pantallas (como la de Archivados), mantener altos estándares visuales (colores armoniosos, micro-interacciones, diseño premium).
* **Supabase:** Antes de ejecutar modificaciones a tablas, verificar las `policies` (RLS) para no romper la seguridad multi-tenant (donde `business_id` es clave).
* **Consistencia:** Mantener el uso de `provider` para el estado global y `go_router` para la nueva navegación.
