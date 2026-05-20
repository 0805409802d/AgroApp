CREATE TABLE farmers (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE NOT NULL,
  name TEXT NOT NULL,
  whatsapp_number TEXT, -- opcional
  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE farmers ENABLE ROW LEVEL SECURITY;
CREATE POLICY "owner_only" ON farmers
  USING (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
  );

-- Índice para búsqueda rápida por nombre (autocomplete)
CREATE INDEX idx_farmers_name ON farmers (business_id, name);