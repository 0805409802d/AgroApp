-- ============================================================
-- Fix para la recursión infinita en las políticas de RLS de businesses
-- y restauración de permisos para el dueño (owner_all).
-- ============================================================

-- 1. Crear una función SECURITY DEFINER para romper la recursión.
-- Como corre con privilegios de administrador, no activa el RLS de employees.
CREATE OR REPLACE FUNCTION check_is_employee_for_business(p_business_id uuid, p_user_id uuid)
RETURNS boolean AS $$
BEGIN
  RETURN EXISTS (
    SELECT 1 
    FROM employees 
    WHERE business_id = p_business_id 
      AND user_id = p_user_id 
      AND is_active = true
  );
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Eliminar la política anterior con recursión de SELECT
DROP POLICY IF EXISTS "employees_can_read_own_business" ON businesses;

-- 3. Crear la nueva política de SELECT usando la función segura
CREATE POLICY "employees_can_read_own_business" ON businesses
  FOR SELECT
  USING (
    user_id = auth.uid()
    OR
    check_is_employee_for_business(id, auth.uid())
  );

-- 4. Re-crear la política para el dueño para ALL (SELECT, INSERT, UPDATE, DELETE)
-- El dueño debe poder hacer cualquier operación en su negocio.
DROP POLICY IF EXISTS "owner_only" ON businesses;
DROP POLICY IF EXISTS "owner_all" ON businesses;

CREATE POLICY "owner_all" ON businesses
  FOR ALL
  USING (user_id = auth.uid())
  WITH CHECK (user_id = auth.uid());
