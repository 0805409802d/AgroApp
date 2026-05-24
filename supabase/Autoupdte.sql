-- ============================================================
-- TRIGGER: updated_at (genérico)
-- Actualiza automáticamente el campo `updated_at` en cualquier
-- tabla que lo tenga, cada vez que se hace un UPDATE.
--
-- USO: Para añadirlo a una tabla nueva:
--   CREATE TRIGGER set_updated_at
--     BEFORE UPDATE ON <tabla>
--     FOR EACH ROW EXECUTE FUNCTION handle_updated_at();
-- ============================================================

CREATE OR REPLACE FUNCTION handle_updated_at()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- ── Aplicar a businesses (si se añade updated_at) ────────────
ALTER TABLE businesses ADD COLUMN IF NOT EXISTS updated_at TIMESTAMPTZ DEFAULT NOW();
DROP TRIGGER IF EXISTS set_updated_at ON businesses;
CREATE TRIGGER set_updated_at
  BEFORE UPDATE ON businesses
  FOR EACH ROW EXECUTE FUNCTION handle_updated_at();