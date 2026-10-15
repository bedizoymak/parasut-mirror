-- ============================================================================
-- PARASUT MIRROR — GEMINI EDITION
-- Migration 002: Row-Level Security (RLS) & Deterministic Financial Triggers
-- ============================================================================

ALTER TABLE companies ENABLE ROW LEVEL SECURITY;
ALTER TABLE company_memberships ENABLE ROW LEVEL SECURITY;
ALTER TABLE item_categories ENABLE ROW LEVEL SECURITY;
ALTER TABLE tags ENABLE ROW LEVEL SECURITY;
ALTER TABLE contacts ENABLE ROW LEVEL SECURITY;
ALTER TABLE employees ENABLE ROW LEVEL SECURITY;
ALTER TABLE accounts ENABLE ROW LEVEL SECURITY;
ALTER TABLE products ENABLE ROW LEVEL SECURITY;
ALTER TABLE warehouses ENABLE ROW LEVEL SECURITY;
ALTER TABLE shipment_documents ENABLE ROW LEVEL SECURITY;
ALTER TABLE stock_movements ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_offers ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_invoices ENABLE ROW LEVEL SECURITY;
ALTER TABLE sales_invoice_details ENABLE ROW LEVEL SECURITY;
ALTER TABLE purchase_bills ENABLE ROW LEVEL SECURITY;
ALTER TABLE checks ENABLE ROW LEVEL SECURITY;
ALTER TABLE transactions ENABLE ROW LEVEL SECURITY;
ALTER TABLE audit_logs ENABLE ROW LEVEL SECURITY;

-- Helper function: verify current authenticated user belongs to company_id
CREATE OR REPLACE FUNCTION public.user_has_company_access(target_company_id UUID)
RETURNS BOOLEAN
LANGUAGE sql
SECURITY DEFINER
STABLE
AS $$
    SELECT EXISTS (
        SELECT 1
        FROM public.company_memberships cm
        WHERE cm.company_id = target_company_id
          AND cm.user_id = COALESCE(
              NULLIF(current_setting('request.jwt.claim.sub', true), '')::UUID,
              '00000000-0000-0000-0000-000000000000'::UUID
          )
    );
$$;

-- Tenant Isolation RLS Policies
CREATE POLICY tenant_isolation_contacts ON contacts
    FOR ALL USING (public.user_has_company_access(company_id))
    WITH CHECK (public.user_has_company_access(company_id));

CREATE POLICY tenant_isolation_sales_invoices ON sales_invoices
    FOR ALL USING (public.user_has_company_access(company_id))
    WITH CHECK (public.user_has_company_access(company_id));

CREATE POLICY tenant_isolation_purchase_bills ON purchase_bills
    FOR ALL USING (public.user_has_company_access(company_id))
    WITH CHECK (public.user_has_company_access(company_id));

CREATE POLICY tenant_isolation_accounts ON accounts
    FOR ALL USING (
        public.user_has_company_access(company_id) AND EXISTS (
            SELECT 1 FROM company_memberships cm
            WHERE cm.company_id = accounts.company_id
              AND cm.user_id = COALESCE(NULLIF(current_setting('request.jwt.claim.sub', true), '')::UUID, '00000000-0000-0000-0000-000000000000'::UUID)
              AND cm.can_view_cash = TRUE
        )
    );

CREATE POLICY tenant_isolation_products ON products
    FOR ALL USING (public.user_has_company_access(company_id))
    WITH CHECK (public.user_has_company_access(company_id));

CREATE POLICY tenant_isolation_transactions ON transactions
    FOR ALL USING (public.user_has_company_access(company_id))
    WITH CHECK (public.user_has_company_access(company_id));

-- Financial Consistency Trigger: Enforce remaining = net_total - total_paid and valid payment_status
CREATE OR REPLACE FUNCTION public.enforce_invoice_financial_invariants()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    IF NEW.total_paid < 0 THEN
        RAISE EXCEPTION 'total_paid cannot be negative';
    END IF;
    IF NEW.total_paid > NEW.net_total THEN
        RAISE EXCEPTION 'total_paid (%) cannot exceed net_total (%)', NEW.total_paid, NEW.net_total;
    END IF;

    NEW.remaining := ROUND(NEW.net_total - NEW.total_paid, 2);
    NEW.net_total_in_trl := ROUND(NEW.net_total * NEW.exchange_rate, 2);
    NEW.remaining_in_trl := ROUND(NEW.remaining * NEW.exchange_rate, 2);

    IF NEW.payment_status <> 'cancelled' THEN
        IF NEW.remaining = 0 THEN
            NEW.payment_status := 'paid';
        ELSIF NEW.total_paid > 0 AND NEW.remaining > 0 THEN
            NEW.payment_status := 'partially_paid';
        ELSIF NEW.due_date IS NOT NULL AND NEW.due_date < CURRENT_DATE THEN
            NEW.payment_status := 'overdue';
        ELSE
            NEW.payment_status := 'unpaid';
        END IF;
    END IF;

    NEW.updated_at := NOW();
    RETURN NEW;
END;
$$;

CREATE TRIGGER trg_sales_invoices_invariants
BEFORE INSERT OR UPDATE ON sales_invoices
FOR EACH ROW EXECUTE FUNCTION public.enforce_invoice_financial_invariants();

CREATE TRIGGER trg_purchase_bills_invariants
BEFORE INSERT OR UPDATE ON purchase_bills
FOR EACH ROW EXECUTE FUNCTION public.enforce_invoice_financial_invariants();
