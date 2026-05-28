-- ============================================================
-- Permitir que empleados activos puedan LEER el negocio
-- al que pertenecen.
--
-- Sin esta política, cuando un empleado inicia sesión, el
-- BusinessProvider no puede hacer el JOIN con businesses y
-- devuelve null → pantalla "Configuración incompleta".
-- ============================================================

DROP POLICY IF EXISTS "employees_can_read_own_business" ON businesses;

CREATE POLICY "employees_can_read_own_business" ON businesses
  FOR SELECT
  USING (
    -- El dueño siempre puede ver su negocio (conservamos la lógica original)
    user_id = auth.uid()
    OR
    -- Un empleado activo puede leer el negocio al que pertenece
    id IN (
      SELECT business_id
      FROM employees
      WHERE user_id = auth.uid()
        AND is_active = true
    )
  );

-- Eliminamos la política antigua (solo dueño) ya que la nueva la cubre
DROP POLICY IF EXISTS "owner_only" ON businesses;
