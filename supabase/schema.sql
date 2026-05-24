-- ============================================================
-- AgroApp — Schema completo para Supabase
-- Ejecutar en Supabase SQL Editor en este orden exacto.
-- 
-- IMPORTANTE: Si ya tienes tablas creadas, usa las secciones
-- individuales de cada archivo. Este es para instalación limpia.
-- ============================================================

-- ── PASO 1: Tabla businesses (ya existe, no recrear) ─────────
-- Ver: businesses.sql

-- ── PASO 2: Tabla farmers (ya existe, no recrear) ────────────
-- Ver: farmers.sql

-- ── PASO 3: Tabla purchases (ya existe, no recrear) ──────────
-- Ver: purchases.sql

-- ── PASO 4: Tabla advances ───────────────────────────────────
-- EJECUTAR: Advances.sql

-- ── PASO 5: Tablas cash_sessions + cash_movements ────────────
-- EJECUTAR: caja.sql

-- ── PASO 6: Trigger de caja automática por compra ────────────
-- EJECUTAR: cash.sql

-- ── PASO 7: Función RPC process_purchase_with_advance ────────
-- EJECUTAR: process_purchase.sql

-- ── PASO 8: Función RPC get_dashboard_alerts ─────────────────
-- EJECUTAR: alert.sql

-- ── PASO 9: Función helper updated_at (opcional) ─────────────
-- EJECUTAR: Autoupdte.sql

-- ── PASO 10: Función RPC get_farmer_ranking (V2) ─────────────
-- EJECUTAR: farmer.sql

-- ── Verificación rápida post-instalación ─────────────────────
-- Ejecuta esto para verificar que todo está bien:
--
-- SELECT table_name FROM information_schema.tables
-- WHERE table_schema = 'public'
-- ORDER BY table_name;
--
-- Resultado esperado:
--   businesses, farmers, purchases, advances,
--   cash_sessions, cash_movements
--
-- SELECT routine_name FROM information_schema.routines
-- WHERE routine_schema = 'public' AND routine_type = 'FUNCTION'
-- ORDER BY routine_name;
--
-- Resultado esperado:
--   get_dashboard_alerts, get_farmer_ranking,
--   handle_updated_at, process_purchase_with_advance,
--   update_cash_on_purchase

-- ── Activar primer cliente (ejecutar manualmente) ─────────────
-- UPDATE businesses
-- SET is_active = true,
--     subscription_expires_at = NOW() + INTERVAL '30 days'
-- WHERE id = 'UUID-DEL-NEGOCIO';
