-- ============================================================
-- FUNCIÓN RPC: get_farmer_ranking
-- Devuelve el ranking de agricultores por volumen de compras.
-- Útil para la pantalla de historial o estadísticas futuras.
-- No usada en MVP v1, disponible para V2.
-- ============================================================

CREATE OR REPLACE FUNCTION get_farmer_ranking(p_business_id UUID)
RETURNS TABLE (
  farmer_name   TEXT,
  total_compras BIGINT,
  total_qq      NUMERIC,
  avg_merma     NUMERIC,
  total_pagado  NUMERIC
) AS $$
BEGIN
  RETURN QUERY
  SELECT
    p.farmer_name,
    COUNT(*)::BIGINT          AS total_compras,
    SUM(p.net_weight)         AS total_qq,
    AVG(p.discount_value)     AS avg_merma,
    SUM(p.total_paid)         AS total_pagado
  FROM purchases p
  WHERE p.business_id = p_business_id
    AND p.status = 'active'
  GROUP BY p.farmer_name
  ORDER BY total_qq DESC;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;
