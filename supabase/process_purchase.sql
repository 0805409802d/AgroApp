-- ============================================================
-- FUNCIÓN RPC: process_purchase_with_advance
-- Llamada desde Flutter para registrar una compra de forma
-- atómica (todo en una sola transacción):
--   1. Inserta la compra en `purchases`.
--   2. Descuenta los adelantos seleccionados en `advances`.
--      Calcula correctamente si queda saldo o está liquidado.
--
-- NOTA: El trigger `trigger_purchase_cash` se ejecutará
-- automáticamente después del INSERT en purchases y registrará
-- los movimientos de caja.
-- ============================================================

CREATE OR REPLACE FUNCTION process_purchase_with_advance(
  -- Datos de la compra
  p_business_id     UUID,
  p_farmer_id       UUID,
  p_farmer_name     TEXT,
  p_gross_weight    NUMERIC(10,3),
  p_discount_type   TEXT,
  p_discount_value  NUMERIC(10,3),
  p_net_weight      NUMERIC(10,3),
  p_weight_unit     TEXT,
  p_price_per_unit  NUMERIC(10,2),
  p_subtotal        NUMERIC(10,2),
  p_advance_deducted NUMERIC(10,2),
  p_total_paid      NUMERIC(10,2),

  -- Opcionales
  p_farmer_whatsapp    TEXT      DEFAULT NULL,
  p_advance_ids        UUID[]    DEFAULT NULL,
  p_deduction_amounts  NUMERIC[] DEFAULT NULL
) RETURNS VOID AS $$
DECLARE
  i               INT;
  v_new_remaining NUMERIC(12,2);
  v_new_status    TEXT;
BEGIN
  -- ── 1. Insertar la compra ───────────────────────────────────
  INSERT INTO purchases (
    business_id, farmer_id, farmer_name, farmer_whatsapp,
    gross_weight, discount_type, discount_value, net_weight,
    weight_unit, price_per_unit, subtotal, advance_deducted,
    total_paid, status, whatsapp_sent
  ) VALUES (
    p_business_id, p_farmer_id, p_farmer_name, p_farmer_whatsapp,
    p_gross_weight, p_discount_type, p_discount_value, p_net_weight,
    p_weight_unit, p_price_per_unit, p_subtotal, p_advance_deducted,
    p_total_paid, 'active', false
  );

  -- ── 2. Descontar adelantos ──────────────────────────────────
  -- Solo si se enviaron IDs de adelantos seleccionados
  IF p_advance_ids IS NOT NULL AND array_length(p_advance_ids, 1) IS NOT NULL THEN
    FOR i IN 1..array_length(p_advance_ids, 1) LOOP

      -- Calcular el nuevo saldo restante ANTES de actualizar
      SELECT GREATEST(remaining - p_deduction_amounts[i], 0)
      INTO v_new_remaining
      FROM advances
      WHERE id = p_advance_ids[i]
        AND business_id = p_business_id;

      -- Determinar nuevo status basado en el saldo calculado
      v_new_status := CASE
        WHEN v_new_remaining <= 0 THEN 'fully_deducted'
        ELSE 'active'
      END;

      -- Actualizar el adelanto
      UPDATE advances
      SET
        remaining = v_new_remaining,
        status    = v_new_status
      WHERE id = p_advance_ids[i]
        AND business_id = p_business_id;

    END LOOP;
  END IF;

END;
$$ LANGUAGE plpgsql SECURITY DEFINER;