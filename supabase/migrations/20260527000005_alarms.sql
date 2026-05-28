-- ============================================================
-- Tabla de Alarmas
-- ============================================================

CREATE TABLE IF NOT EXISTS alarms (
  id uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  event_name text NOT NULL,
  description text,
  event_time timestamptz NOT NULL,
  is_active boolean DEFAULT true,
  created_at timestamptz DEFAULT now()
);

-- Solo el administrador/dueño del negocio puede ver y modificar las alarmas
ALTER TABLE alarms ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "owner_all" ON alarms;
CREATE POLICY "owner_all" ON alarms
  FOR ALL
  USING (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
  )
  WITH CHECK (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
  );
