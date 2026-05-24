-- ============================================================
-- FUNCIÓN RPC: get_dashboard_alerts
-- Retorna una lista de alertas para el dashboard del comerciante.
-- Devuelve TABLE en lugar de JSONB para que Flutter pueda
-- mapear directamente la respuesta como List<Map>.
--
-- Alertas implementadas:
--   1. Agricultores sin compras en los últimos 3 días
--   2. Compras recientes sin recibo de WhatsApp
--   3. Precio actual vs promedio semanal (subida o bajada)
--   4. Total de adelantos pendientes por descontar
-- ============================================================

CREATE OR REPLACE FUNCTION get_dashboard_alerts(p_business_id UUID)
RETURNS TABLE (
  type    TEXT,
  message TEXT,
  icon    TEXT,
  color   TEXT,
  action  TEXT
) AS $$
BEGIN

  -- ── Alerta 1: Agricultores inactivos (sin compras en 3 días) ──
  RETURN QUERY
  SELECT
    'inactive_farmer'::TEXT                                    AS type,
    'Sin compras hace 3+ días: ' || f.name                    AS message,
    'person_off'::TEXT                                         AS icon,
    '#FF9800'::TEXT                                            AS color,
    '/history'::TEXT                                           AS action
  FROM farmers f
  WHERE f.business_id = p_business_id
    AND NOT EXISTS (
      SELECT 1 FROM purchases p
      WHERE p.farmer_id  = f.id
        AND p.business_id = p_business_id
        AND p.status      = 'active'
        AND p.created_at >= NOW() - INTERVAL '3 days'
    )
  LIMIT 3;

  -- ── Alerta 2: Compras sin recibo de WhatsApp (últimos 7 días) ─
  RETURN QUERY
  SELECT
    'pending_whatsapp'::TEXT                                   AS type,
    COUNT(*)::TEXT || ' compra(s) sin recibo de WhatsApp'     AS message,
    'message'::TEXT                                            AS icon,
    '#2196F3'::TEXT                                            AS color,
    '/history'::TEXT                                           AS action
  FROM purchases
  WHERE business_id  = p_business_id
    AND status        = 'active'
    AND whatsapp_sent = false
    AND created_at   >= NOW() - INTERVAL '7 days'
  HAVING COUNT(*) > 0;

  -- ── Alerta 3: Variación de precio vs promedio semanal ─────────
  RETURN QUERY
  WITH precio AS (
    SELECT
      b.current_price                          AS precio_actual,
      AVG(p.price_per_unit)                    AS promedio_semanal
    FROM businesses b
    LEFT JOIN purchases p
      ON  p.business_id = b.id
      AND p.status      = 'active'
      AND p.created_at >= NOW() - INTERVAL '7 days'
    WHERE b.id = p_business_id
    GROUP BY b.current_price
  )
  SELECT
    CASE
      WHEN precio_actual < promedio_semanal * 0.95 THEN 'price_drop'
      ELSE 'price_rise'
    END::TEXT                                                  AS type,
    CASE
      WHEN precio_actual < promedio_semanal * 0.95
        THEN 'Precio actual ($' || precio_actual::TEXT || ') bajo el promedio semanal ($' || ROUND(promedio_semanal,2)::TEXT || ')'
      ELSE 'Precio actual ($' || precio_actual::TEXT || ') sobre el promedio semanal. ¡Oportunidad!'
    END::TEXT                                                  AS message,
    CASE
      WHEN precio_actual < promedio_semanal * 0.95 THEN 'trending_down'
      ELSE 'trending_up'
    END::TEXT                                                  AS icon,
    CASE
      WHEN precio_actual < promedio_semanal * 0.95 THEN '#F44336'
      ELSE '#4CAF50'
    END::TEXT                                                  AS color,
    '/settings'::TEXT                                          AS action
  FROM precio
  WHERE promedio_semanal IS NOT NULL
    AND (
      precio_actual < promedio_semanal * 0.95 OR
      precio_actual > promedio_semanal * 1.05
    );

  -- ── Alerta 4: Total de adelantos pendientes ───────────────────
  RETURN QUERY
  SELECT
    'pending_advances'::TEXT                                   AS type,
    '$' || SUM(remaining)::TEXT || ' en adelantos por descontar' AS message,
    'account_balance_wallet'::TEXT                             AS icon,
    '#9C27B0'::TEXT                                            AS color,
    '/history'::TEXT                                           AS action
  FROM advances
  WHERE business_id = p_business_id
    AND status       = 'active'
    AND remaining    > 0
  HAVING SUM(remaining) > 0;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;