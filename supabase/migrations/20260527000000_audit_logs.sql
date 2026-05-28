-- 1. Create the audit_logs table
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    business_id UUID NOT NULL REFERENCES businesses(id) ON DELETE CASCADE,
    user_id UUID REFERENCES auth.users(id) ON DELETE SET NULL,
    action_type TEXT NOT NULL, -- 'INSERT', 'UPDATE', 'DELETE'
    entity_name TEXT NOT NULL, -- 'purchases', 'cash_sessions', 'businesses'
    entity_id UUID NOT NULL,
    previous_data JSONB,
    new_data JSONB,
    created_at TIMESTAMPTZ DEFAULT now()
);

-- RLS
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

DROP POLICY IF EXISTS "audit_logs_select_admin" ON audit_logs;
CREATE POLICY "audit_logs_select_admin" ON audit_logs
FOR SELECT USING (
    business_id IN (
        SELECT id FROM businesses WHERE user_id = auth.uid()
    )
);

-- 2. Create the Trigger Function
CREATE OR REPLACE FUNCTION log_audit_event()
RETURNS TRIGGER AS $$
DECLARE
    v_user_id UUID;
    v_business_id UUID;
    v_entity_id UUID;
    v_action TEXT;
    v_previous JSONB;
    v_new JSONB;
BEGIN
    v_user_id := auth.uid();
    v_action := TG_OP;

    -- Extract entity_id and business_id
    IF v_action = 'DELETE' THEN
        v_entity_id := OLD.id;
        v_business_id := OLD.business_id;
        v_previous := row_to_json(OLD)::JSONB;
        v_new := NULL;
    ELSIF v_action = 'UPDATE' THEN
        v_entity_id := NEW.id;
        -- businesses table might not have business_id (it is the id itself)
        IF TG_TABLE_NAME = 'businesses' THEN
            v_business_id := NEW.id;
        ELSE
            v_business_id := NEW.business_id;
        END IF;
        v_previous := row_to_json(OLD)::JSONB;
        v_new := row_to_json(NEW)::JSONB;
    ELSE -- INSERT
        v_entity_id := NEW.id;
        IF TG_TABLE_NAME = 'businesses' THEN
            v_business_id := NEW.id;
        ELSE
            v_business_id := NEW.business_id;
        END IF;
        v_previous := NULL;
        v_new := row_to_json(NEW)::JSONB;
    END IF;

    -- Insert into audit_logs only if business_id exists
    IF v_business_id IS NOT NULL THEN
        INSERT INTO audit_logs (
            business_id, user_id, action_type, entity_name, entity_id, previous_data, new_data
        ) VALUES (
            v_business_id, v_user_id, v_action, TG_TABLE_NAME::TEXT, v_entity_id, v_previous, v_new
        );
    END IF;

    IF v_action = 'DELETE' THEN
        RETURN OLD;
    ELSE
        RETURN NEW;
    END IF;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Attach Triggers to Important Tables
DROP TRIGGER IF EXISTS audit_purchases_trigger ON purchases;
CREATE TRIGGER audit_purchases_trigger
AFTER INSERT OR UPDATE OR DELETE ON purchases
FOR EACH ROW EXECUTE FUNCTION log_audit_event();

DROP TRIGGER IF EXISTS audit_cash_sessions_trigger ON cash_sessions;
CREATE TRIGGER audit_cash_sessions_trigger
AFTER INSERT OR UPDATE OR DELETE ON cash_sessions
FOR EACH ROW EXECUTE FUNCTION log_audit_event();

DROP TRIGGER IF EXISTS audit_farmers_trigger ON farmers;
CREATE TRIGGER audit_farmers_trigger
AFTER INSERT OR UPDATE OR DELETE ON farmers
FOR EACH ROW EXECUTE FUNCTION log_audit_event();

DROP TRIGGER IF EXISTS audit_businesses_trigger ON businesses;
CREATE TRIGGER audit_businesses_trigger
AFTER UPDATE ON businesses
FOR EACH ROW EXECUTE FUNCTION log_audit_event();
