CREATE TABLE purchases (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id UUID REFERENCES businesses(id) ON DELETE CASCADE NOT NULL,
  farmer_id UUID REFERENCES farmers(id) ON DELETE SET NULL,
  farmer_name TEXT NOT NULL, -- guardamos el nombre directo por si se borra el farmer
  farmer_whatsapp TEXT,

  -- Pesaje
  gross_weight NUMERIC(10,3) NOT NULL,
  discount_type TEXT NOT NULL, -- 'porcentaje' | 'libras'
  discount_value NUMERIC(10,3) NOT NULL DEFAULT 0,
  net_weight NUMERIC(10,3) NOT NULL,
  weight_unit TEXT NOT NULL, -- 'quintales' | 'libras'

  -- Precio (guardamos el precio del momento, no el actual)
  price_per_unit NUMERIC(10,2) NOT NULL,

  -- Dinero
  subtotal NUMERIC(10,2) NOT NULL, -- net_weight * price_per_unit
  advance_deducted NUMERIC(10,2) NOT NULL DEFAULT 0,
  total_paid NUMERIC(10,2) NOT NULL, -- subtotal - advance_deducted

  -- Estado
  status TEXT NOT NULL DEFAULT 'active', -- 'active' | 'cancelled'
  whatsapp_sent BOOLEAN NOT NULL DEFAULT false,

  created_at TIMESTAMPTZ DEFAULT NOW()
);

ALTER TABLE purchases ENABLE ROW LEVEL SECURITY;
CREATE POLICY "owner_only" ON purchases
  USING (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
  );

-- Índices para filtros rápidos (historial por fecha, por agricultor)
CREATE INDEX idx_purchases_business_date ON purchases (business_id, created_at DESC);
CREATE INDEX idx_purchases_farmer ON purchases (business_id, farmer_name);