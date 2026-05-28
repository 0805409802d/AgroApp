ALTER TABLE purchases
  ADD COLUMN IF NOT EXISTS archived_at timestamptz DEFAULT NULL;

-- Índice para no degradar las queries de historial activo
CREATE INDEX IF NOT EXISTS idx_purchases_archived ON purchases(business_id, archived_at)
  WHERE archived_at IS NULL;

-- RPC para archivar mes
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
