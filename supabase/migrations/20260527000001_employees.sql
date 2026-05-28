CREATE TABLE IF NOT EXISTS employees (
  id          uuid PRIMARY KEY DEFAULT gen_random_uuid(),
  business_id uuid NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
  user_id     uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  name        text NOT NULL,
  role        text NOT NULL CHECK (role IN ('admin', 'operator')),
  is_active   bool NOT NULL DEFAULT true,
  created_at  timestamptz DEFAULT now(),
  UNIQUE(business_id, user_id)
);

-- RLS: solo el admin del negocio puede ver y gestionar sus empleados
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "employees_select" ON employees;
CREATE POLICY "employees_select" ON employees
  FOR SELECT USING (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
    OR user_id = auth.uid()
  );

DROP POLICY IF EXISTS "employees_insert" ON employees;
CREATE POLICY "employees_insert" ON employees
  FOR INSERT WITH CHECK (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "employees_update" ON employees;
CREATE POLICY "employees_update" ON employees
  FOR UPDATE USING (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
  );

DROP POLICY IF EXISTS "employees_delete" ON employees;
CREATE POLICY "employees_delete" ON employees
  FOR DELETE USING (
    business_id IN (
      SELECT id FROM businesses WHERE user_id = auth.uid()
    )
  );
