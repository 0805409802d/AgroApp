CREATE TABLE businesses (
  id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  user_id UUID REFERENCES auth.users(id) ON DELETE CASCADE NOT NULL,
  business_name TEXT NOT NULL,
  owner_name TEXT,
  whatsapp_number TEXT,
  product_type TEXT NOT NULL DEFAULT 'cacao', -- cacao, maiz, cafe, arroz, etc.
  weight_unit TEXT NOT NULL DEFAULT 'quintales', -- quintales | libras
  discount_type TEXT NOT NULL DEFAULT 'porcentaje', -- porcentaje | libras
  current_price NUMERIC(10,2) NOT NULL DEFAULT 0.00,
  is_active BOOLEAN NOT NULL DEFAULT false, -- tú lo activas manualmente
  subscription_expires_at TIMESTAMPTZ,
  created_at TIMESTAMPTZ DEFAULT NOW()
);

-- Seguridad: cada comerciante solo ve su negocio
ALTER TABLE businesses ENABLE ROW LEVEL SECURITY;
CREATE POLICY "owner_only" ON businesses
  USING (user_id = auth.uid());