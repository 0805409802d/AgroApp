-- ============================================================
-- TABLAS: cash_sessions + cash_movements
-- Control de caja diaria.
-- cash_sessions: una apertura/cierre por día por negocio.
-- cash_movements: auditoría de cada movimiento dentro de la sesión.
-- ============================================================

-- ── Sesión de caja ────────────────────────────────────────────
CREATE TABLE IF NOT EXISTS cash_sessions (
  id                      UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id             UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  opening_balance         NUMERIC(12,2) NOT NULL DEFAULT 0,
  closing_balance         NUMERIC(12,2),                  -- se llena al cerrar
  total_purchases         NUMERIC(12,2) NOT NULL DEFAULT 0,
  total_advances_given    NUMERIC(12,2) NOT NULL DEFAULT 0, -- adelantos nuevos dados
  total_advances_deducted NUMERIC(12,2) NOT NULL DEFAULT 0, -- adelantos descontados en compras
  notes                   TEXT,
  opened_at               TIMESTAMPTZ NOT NULL DEFAULT NOW(),
  closed_at               TIMESTAMPTZ,
  status                  TEXT NOT NULL DEFAULT 'open'
                            CHECK (status IN ('open', 'closed'))
);

-- Índice para búsqueda rápida: sesión abierta hoy por negocio
CREATE INDEX IF NOT EXISTS idx_cash_sessions_business_status
  ON cash_sessions (business_id, status, opened_at);

-- ── Movimientos de caja ───────────────────────────────────────
CREATE TABLE IF NOT EXISTS cash_movements (
  id              UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  cash_session_id UUID NOT NULL REFERENCES cash_sessions(id) ON DELETE CASCADE,
  type            TEXT NOT NULL
                    CHECK (type IN ('purchase', 'advance_given', 'advance_deducted', 'expense', 'deposit')),
  amount          NUMERIC(12,2) NOT NULL,
  description     TEXT,
  created_at      TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Índice para listar movimientos de una sesión
CREATE INDEX IF NOT EXISTS idx_cash_movements_session
  ON cash_movements (cash_session_id, created_at);

-- ── Row Level Security ────────────────────────────────────────
ALTER TABLE cash_sessions ENABLE ROW LEVEL SECURITY;
CREATE POLICY "owner_only" ON cash_sessions
  USING (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
  );

ALTER TABLE cash_movements ENABLE ROW LEVEL SECURITY;
CREATE POLICY "owner_only" ON cash_movements
  USING (
    cash_session_id IN (
      SELECT cs.id FROM cash_sessions cs
      JOIN businesses b ON b.id = cs.business_id
      WHERE b.user_id = auth.uid()
    )
  );