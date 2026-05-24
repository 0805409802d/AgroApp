-- ============================================================
-- TRIGGER: update_cash_on_purchase
-- Se dispara AFTER INSERT en purchases (status = 'active').
-- Busca la sesión de caja abierta hoy y:
--   1. Registra el movimiento de tipo 'purchase'.
--   2. Actualiza total_purchases en la sesión.
--   3. Si la compra tuvo adelanto descontado, también registra
--      un movimiento 'advance_deducted' y actualiza el total.
-- Si no hay sesión abierta, crea una automáticamente con saldo 0.
-- ============================================================

CREATE OR REPLACE FUNCTION update_cash_on_purchase()
RETURNS TRIGGER AS $$
DECLARE
  v_session_id UUID;
BEGIN
  -- Solo procesamos compras activas
  IF NEW.status <> 'active' THEN
    RETURN NEW;
  END IF;

  -- Buscar sesión de caja abierta HOY para este negocio
  SELECT id INTO v_session_id
  FROM cash_sessions
  WHERE business_id = NEW.business_id
    AND status = 'open'
    AND opened_at::date = CURRENT_DATE
  LIMIT 1;

  -- Si no existe, creamos una automáticamente con saldo 0
  -- (el comerciante podrá actualizar el saldo al abrir caja)
  IF v_session_id IS NULL THEN
    INSERT INTO cash_sessions (business_id, opening_balance)
    VALUES (NEW.business_id, 0)
    RETURNING id INTO v_session_id;
  END IF;

  -- Registrar movimiento de salida por la compra
  INSERT INTO cash_movements (cash_session_id, type, amount, description)
  VALUES (v_session_id, 'purchase', NEW.total_paid, 'Compra: ' || NEW.farmer_name);

  -- Actualizar el total de compras de la sesión
  UPDATE cash_sessions
  SET total_purchases = total_purchases + NEW.total_paid
  WHERE id = v_session_id;

  -- Si la compra tuvo descuento de adelanto, registrar ese movimiento por separado
  IF NEW.advance_deducted > 0 THEN
    INSERT INTO cash_movements (cash_session_id, type, amount, description)
    VALUES (
      v_session_id,
      'advance_deducted',
      NEW.advance_deducted,
      'Adelanto recuperado: ' || NEW.farmer_name
    );

    UPDATE cash_sessions
    SET total_advances_deducted = total_advances_deducted + NEW.advance_deducted
    WHERE id = v_session_id;
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Asociar el trigger a la tabla purchases
DROP TRIGGER IF EXISTS trigger_purchase_cash ON purchases;
CREATE TRIGGER trigger_purchase_cash
  AFTER INSERT ON purchases
  FOR EACH ROW
  WHEN (NEW.status = 'active')
  EXECUTE FUNCTION update_cash_on_purchase();