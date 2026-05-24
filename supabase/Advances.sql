-- ============================================================
-- TABLA: advances
-- Adelantos (préstamos) dados a agricultores.
-- El campo `remaining` se reduce automáticamente al procesar
-- una compra con descuento de adelanto.
-- ============================================================

CREATE TABLE IF NOT EXISTS advances (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  farmer_id   UUID NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
  amount      NUMERIC(12,2) NOT NULL CHECK (amount > 0),
  remaining   NUMERIC(12,2) NOT NULL CHECK (remaining >= 0),
  status      TEXT NOT NULL DEFAULT 'active'
                CHECK (status IN ('active', 'fully_deducted', 'cancelled')),
  notes       TEXT,
  created_at  TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índice para búsqueda rápida de adelantos pendientes por agricultor
CREATE INDEX IF NOT EXISTS idx_advances_farmer_status
  ON advances (business_id, farmer_id, status);

-- ── Row Level Security ────────────────────────────────────────
ALTER TABLE advances ENABLE ROW LEVEL SECURITY;

-- Solo el dueño del negocio puede ver/modificar sus adelantos
CREATE POLICY "owner_only" ON advances
  USING (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
  );