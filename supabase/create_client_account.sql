-- ============================================================
-- AgroApp — Script para crear cuentas de clientes (Admin)
-- ============================================================
-- INSTRUCCIONES:
-- 1. Ve al Panel de Supabase → Authentication → Users
-- 2. Haz click en "Add User" → "Create new user"
-- 3. Ingresa el email y contraseña del cliente → Click "Create User"
-- 4. Copia el UUID del usuario recién creado
-- 5. Reemplaza los valores en este script y ejecútalo en el SQL Editor
-- ============================================================

-- ── PASO ÚNICO: Crear negocio para el usuario ─────────────────
-- Reemplaza cada valor según el cliente:

INSERT INTO businesses (
  user_id,          -- UUID del usuario de Auth (copiado del paso 4)
  business_name,    -- Nombre del negocio del cliente
  owner_name,       -- Nombre del dueño
  product_type,     -- Producto principal: cacao | maiz | cafe | arroz | soya | otro
  is_active,        -- TRUE = activo, FALSE = bloqueado
  subscription_expires_at  -- Fecha de vencimiento de suscripción
)
VALUES (
  'REEMPLAZA-CON-UUID-DEL-USUARIO',   -- Ejemplo: 'a1b2c3d4-...'
  'Nombre del Negocio del Cliente',
  'Nombre del Dueño',
  'cacao',          -- Cambia según el producto
  true,             -- TRUE = activado desde el primer momento
  NOW() + INTERVAL '30 days'  -- Suscripción por 30 días (ajusta según plan)
);

-- ── Verificar que se creó correctamente ───────────────────────
-- Ejecuta esto después del INSERT para confirmar:
-- SELECT id, user_id, business_name, owner_name, is_active, subscription_expires_at
-- FROM businesses
-- WHERE user_id = 'REEMPLAZA-CON-UUID-DEL-USUARIO';


-- ============================================================
-- RENOVAR O MODIFICAR UNA SUSCRIPCIÓN EXISTENTE
-- ============================================================

-- Activar / renovar por N días:
-- UPDATE businesses
-- SET is_active = true,
--     subscription_expires_at = NOW() + INTERVAL '30 days'
-- WHERE user_id = 'UUID-DEL-USUARIO';

-- Desactivar (suspender) una cuenta:
-- UPDATE businesses
-- SET is_active = false
-- WHERE user_id = 'UUID-DEL-USUARIO';

-- Cambiar el plan de suscripción (ej: 3 meses):
-- UPDATE businesses
-- SET is_active = true,
--     subscription_expires_at = NOW() + INTERVAL '90 days'
-- WHERE user_id = 'UUID-DEL-USUARIO';


-- ============================================================
-- VER TODOS LOS CLIENTES Y SU ESTADO DE SUSCRIPCIÓN
-- ============================================================

-- SELECT 
--   b.id,
--   b.business_name,
--   b.owner_name,
--   b.product_type,
--   b.is_active,
--   b.subscription_expires_at,
--   b.current_price,
--   au.email
-- FROM businesses b
-- JOIN auth.users au ON au.id = b.user_id
-- ORDER BY b.created_at DESC;
