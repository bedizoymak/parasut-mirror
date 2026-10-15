-- ============================================================================
-- PARASUT MIRROR — GEMINI EDITION
-- Migration 001: Canonical ERP Data Model (PostgreSQL / Supabase)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "pgcrypto";

-- 1. TENANTS / COMPANIES
CREATE TABLE IF NOT EXISTS companies (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    parasut_company_no INTEGER UNIQUE NOT NULL,
    name VARCHAR(255) NOT NULL,
    tax_office VARCHAR(128),
    tax_number VARCHAR(20) NOT NULL,
    city VARCHAR(100),
    district VARCHAR(100),
    address TEXT,
    phone VARCHAR(40),
    email VARCHAR(255),
    base_currency VARCHAR(3) NOT NULL DEFAULT 'TRL' CHECK (base_currency IN ('TRL', 'USD', 'EUR', 'GBP')),
    e_document_active BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. COMPANY MEMBERSHIPS & RBAC
CREATE TABLE IF NOT EXISTS company_memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    user_id UUID NOT NULL,
    email VARCHAR(255) NOT NULL,
    role VARCHAR(32) NOT NULL CHECK (role IN ('owner', 'admin', 'accountant', 'sales', 'viewer')),
    can_view_cash BOOLEAN NOT NULL DEFAULT TRUE,
    can_manage_invoices BOOLEAN NOT NULL DEFAULT TRUE,
    can_manage_expenses BOOLEAN NOT NULL DEFAULT TRUE,
    can_manage_inventory BOOLEAN NOT NULL DEFAULT TRUE,
    can_manage_settings BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, user_id)
);

-- 3. ITEM CATEGORIES (Hierarchical tree for Sales, Expenses, Contacts, Products)
CREATE TABLE IF NOT EXISTS item_categories (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    parent_id UUID REFERENCES item_categories(id) ON DELETE SET NULL,
    name VARCHAR(150) NOT NULL,
    category_type VARCHAR(32) NOT NULL CHECK (category_type IN ('sales_invoice', 'expenditure', 'contact', 'product', 'employee')),
    color VARCHAR(16) NOT NULL DEFAULT '#3b82f6',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_item_categories_company_type ON item_categories(company_id, category_type);

-- 4. TAGS
CREATE TABLE IF NOT EXISTS tags (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name VARCHAR(100) NOT NULL,
    color VARCHAR(16) NOT NULL DEFAULT '#10b981',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, name)
);

-- 5. CONTACTS (Customers & Suppliers / Cari Hesaplar)
CREATE TABLE IF NOT EXISTS contacts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    category_id UUID REFERENCES item_categories(id) ON DELETE SET NULL,
    name VARCHAR(255) NOT NULL,
    short_name VARCHAR(120),
    contact_type VARCHAR(16) NOT NULL DEFAULT 'company' CHECK (contact_type IN ('company', 'person')),
    account_type VARCHAR(16) NOT NULL DEFAULT 'customer' CHECK (account_type IN ('customer', 'supplier', 'both')),
    tax_office VARCHAR(120),
    tax_number VARCHAR(20),
    is_e_invoice_user BOOLEAN NOT NULL DEFAULT FALSE,
    email VARCHAR(255),
    phone VARCHAR(40),
    city VARCHAR(100),
    district VARCHAR(100),
    address TEXT,
    iban VARCHAR(42),
    is_abroad BOOLEAN NOT NULL DEFAULT FALSE,
    archived BOOLEAN NOT NULL DEFAULT FALSE,
    opening_balance_trl NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    balance_trl NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    balance_usd NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    balance_eur NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    balance_gbp NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_contacts_company_account_type ON contacts(company_id, account_type, archived);
CREATE INDEX IF NOT EXISTS idx_contacts_tax_number ON contacts(company_id, tax_number);

-- 6. EMPLOYEES (Çalışanlar)
CREATE TABLE IF NOT EXISTS employees (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    category_id UUID REFERENCES item_categories(id) ON DELETE SET NULL,
    name VARCHAR(200) NOT NULL,
    tckn VARCHAR(11),
    email VARCHAR(255),
    iban VARCHAR(42),
    department VARCHAR(100),
    monthly_net_salary NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    balance_trl NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. CASH & BANK ACCOUNTS (Kasa ve Bankalar)
CREATE TABLE IF NOT EXISTS accounts (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name VARCHAR(200) NOT NULL,
    account_type VARCHAR(24) NOT NULL CHECK (account_type IN ('cash', 'bank', 'sys_check_portfolio')),
    currency VARCHAR(3) NOT NULL DEFAULT 'TRL' CHECK (currency IN ('TRL', 'USD', 'EUR', 'GBP')),
    bank_name VARCHAR(120),
    bank_branch VARCHAR(120),
    account_no VARCHAR(64),
    iban VARCHAR(42),
    balance NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_accounts_company_type ON accounts(company_id, account_type, archived);

-- 8. PRODUCTS & SERVICES (Hizmet ve Ürünler)
CREATE TABLE IF NOT EXISTS products (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    category_id UUID REFERENCES item_categories(id) ON DELETE SET NULL,
    code VARCHAR(64) NOT NULL,
    barcode VARCHAR(64),
    gtip VARCHAR(32),
    name VARCHAR(255) NOT NULL,
    unit VARCHAR(32) NOT NULL DEFAULT 'Adet',
    vat_rate NUMERIC(5,2) NOT NULL DEFAULT 20.00 CHECK (vat_rate IN (0, 1, 8, 10, 18, 20)),
    sales_excise_duty NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
    sales_excise_duty_type VARCHAR(16) NOT NULL DEFAULT 'percentage' CHECK (sales_excise_duty_type IN ('percentage', 'amount')),
    purchase_excise_duty NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
    purchase_excise_duty_type VARCHAR(16) NOT NULL DEFAULT 'percentage' CHECK (purchase_excise_duty_type IN ('percentage', 'amount')),
    communications_tax_rate NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    accommodation_tax_rate NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    list_price NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
    currency VARCHAR(3) NOT NULL DEFAULT 'TRL' CHECK (currency IN ('TRL', 'USD', 'EUR', 'GBP')),
    buying_price NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
    buying_currency VARCHAR(3) NOT NULL DEFAULT 'TRL' CHECK (buying_currency IN ('TRL', 'USD', 'EUR', 'GBP')),
    inventory_tracking BOOLEAN NOT NULL DEFAULT TRUE,
    initial_stock_count NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
    critical_stock_count NUMERIC(18,4) NOT NULL DEFAULT 5.0000,
    current_stock_count NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
    archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE (company_id, code)
);
CREATE INDEX IF NOT EXISTS idx_products_company_code ON products(company_id, code);

-- 9. WAREHOUSES & INVENTORY LEVELS (Depolar & Stok Hareketleri)
CREATE TABLE IF NOT EXISTS warehouses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    name VARCHAR(150) NOT NULL,
    city VARCHAR(100),
    district VARCHAR(100),
    address TEXT,
    is_abroad BOOLEAN NOT NULL DEFAULT FALSE,
    archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS shipment_documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL REFERENCES contacts(id),
    warehouse_id UUID NOT NULL REFERENCES warehouses(id),
    document_no VARCHAR(64) NOT NULL,
    direction VARCHAR(16) NOT NULL CHECK (direction IN ('inflow', 'outflow')),
    issue_date DATE NOT NULL,
    dispatch_date DATE NOT NULL,
    description TEXT,
    invoiced BOOLEAN NOT NULL DEFAULT FALSE,
    linked_invoice_id UUID,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

CREATE TABLE IF NOT EXISTS stock_movements (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    warehouse_id UUID NOT NULL REFERENCES warehouses(id),
    product_id UUID NOT NULL REFERENCES products(id),
    shipment_document_id UUID REFERENCES shipment_documents(id) ON DELETE CASCADE,
    source_document_type VARCHAR(32) NOT NULL CHECK (source_document_type IN ('opening', 'sales_invoice', 'purchase_bill', 'shipment', 'transfer', 'manual_adjustment')),
    source_document_id UUID,
    direction VARCHAR(16) NOT NULL CHECK (direction IN ('inflow', 'outflow')),
    quantity NUMERIC(18,4) NOT NULL CHECK (quantity > 0),
    movement_date DATE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_stock_movements_product ON stock_movements(company_id, product_id, movement_date);

-- 10. SALES OFFERS (Teklifler)
CREATE TABLE IF NOT EXISTS sales_offers (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL REFERENCES contacts(id),
    offer_no VARCHAR(64) NOT NULL,
    description VARCHAR(255) NOT NULL,
    issue_date DATE NOT NULL,
    due_date DATE,
    currency VARCHAR(3) NOT NULL DEFAULT 'TRL' CHECK (currency IN ('TRL', 'USD', 'EUR', 'GBP')),
    exchange_rate NUMERIC(18,4) NOT NULL DEFAULT 1.0000 CHECK (exchange_rate > 0),
    status VARCHAR(24) NOT NULL DEFAULT 'waiting' CHECK (status IN ('waiting', 'accepted', 'rejected')),
    invoice_status VARCHAR(24) NOT NULL DEFAULT 'not_invoiced' CHECK (invoice_status IN ('not_invoiced', 'invoiced')),
    withholding_rate NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    invoice_discount_type VARCHAR(16) NOT NULL DEFAULT 'percentage' CHECK (invoice_discount_type IN ('percentage', 'amount')),
    invoice_discount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    gross_total NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    total_discount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    total_vat NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    net_total NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    archived BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 11. SALES INVOICES (Satış Faturaları, Proforma, İade, İhracat)
CREATE TABLE IF NOT EXISTS sales_invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL REFERENCES contacts(id),
    category_id UUID REFERENCES item_categories(id) ON DELETE SET NULL,
    sales_offer_id UUID REFERENCES sales_offers(id) ON DELETE SET NULL,
    invoice_no VARCHAR(64),
    item_type VARCHAR(24) NOT NULL DEFAULT 'invoice' CHECK (item_type IN ('invoice', 'estimate', 'refund', 'export')),
    description VARCHAR(255) NOT NULL,
    issue_date DATE NOT NULL,
    due_date DATE,
    currency VARCHAR(3) NOT NULL DEFAULT 'TRL' CHECK (currency IN ('TRL', 'USD', 'EUR', 'GBP')),
    exchange_rate NUMERIC(18,4) NOT NULL DEFAULT 1.0000 CHECK (exchange_rate > 0),
    withholding_rate NUMERIC(5,2) NOT NULL DEFAULT 0.00 CHECK (withholding_rate >= 0 AND withholding_rate <= 100),
    vat_withholding_rate NUMERIC(5,2) NOT NULL DEFAULT 0.00 CHECK (vat_withholding_rate >= 0 AND vat_withholding_rate <= 100),
    invoice_discount_type VARCHAR(16) NOT NULL DEFAULT 'percentage' CHECK (invoice_discount_type IN ('percentage', 'amount')),
    invoice_discount NUMERIC(18,2) NOT NULL DEFAULT 0.00 CHECK (invoice_discount >= 0),
    gross_total NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    total_discount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    total_invoice_discount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    total_excise_duty NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    total_communications_tax NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    total_accommodation_tax NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    total_vat NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    total_vat_withholding NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    withholding NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    net_total NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    net_total_in_trl NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    total_paid NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    remaining NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    remaining_in_trl NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    payment_status VARCHAR(24) NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'overdue', 'partially_paid', 'paid', 'cancelled')),
    e_document_type VARCHAR(24) CHECK (e_document_type IN ('none', 'e_invoice', 'e_archive', 'e_smm')),
    e_document_status VARCHAR(24) DEFAULT 'not_sent' CHECK (e_document_status IN ('not_sent', 'pending', 'running', 'done', 'error')),
    e_document_number VARCHAR(64),
    shipment_included BOOLEAN NOT NULL DEFAULT FALSE,
    archived BOOLEAN NOT NULL DEFAULT FALSE,
    idempotency_key VARCHAR(128) UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_sales_invoices_company_dates ON sales_invoices(company_id, issue_date DESC, due_date ASC);
CREATE INDEX IF NOT EXISTS idx_sales_invoices_contact ON sales_invoices(company_id, contact_id, payment_status);

CREATE TABLE IF NOT EXISTS sales_invoice_details (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    sales_invoice_id UUID NOT NULL REFERENCES sales_invoices(id) ON DELETE CASCADE,
    product_id UUID REFERENCES products(id),
    warehouse_id UUID REFERENCES warehouses(id),
    detail_no INTEGER NOT NULL DEFAULT 1,
    description VARCHAR(255) NOT NULL,
    quantity NUMERIC(18,4) NOT NULL CHECK (quantity > 0),
    unit_price NUMERIC(18,4) NOT NULL CHECK (unit_price >= 0),
    discount_type VARCHAR(16) NOT NULL DEFAULT 'percentage' CHECK (discount_type IN ('percentage', 'amount')),
    discount_value NUMERIC(18,4) NOT NULL DEFAULT 0.0000 CHECK (discount_value >= 0),
    discount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    invoice_discount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    excise_duty_type VARCHAR(16) NOT NULL DEFAULT 'percentage' CHECK (excise_duty_type IN ('percentage', 'amount')),
    excise_duty_value NUMERIC(18,4) NOT NULL DEFAULT 0.0000,
    excise_duty NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    vat_rate NUMERIC(5,2) NOT NULL DEFAULT 20.00,
    vat_amount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    vat_withholding_rate NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    vat_withholding NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    communications_tax_rate NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    communications_tax NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    accommodation_tax_rate NUMERIC(5,2) NOT NULL DEFAULT 0.00,
    accommodation_tax NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    net_total_without_invoice_discount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    net_total NUMERIC(18,2) NOT NULL DEFAULT 0.00
);
CREATE INDEX IF NOT EXISTS idx_sales_invoice_details_invoice ON sales_invoice_details(sales_invoice_id);

-- 12. PURCHASE BILLS & EXPENSES (Giderler: Hızlı Fiş, Detaylı Fatura, Maaş, Vergi, Banka Gideri)
CREATE TABLE IF NOT EXISTS purchase_bills (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    supplier_id UUID REFERENCES contacts(id),
    employee_id UUID REFERENCES employees(id),
    category_id UUID REFERENCES item_categories(id) ON DELETE SET NULL,
    bill_no VARCHAR(64),
    item_type VARCHAR(24) NOT NULL CHECK (item_type IN ('purchase_bill_basic', 'purchase_bill_detailed', 'salary', 'tax', 'bank_fee', 'refund')),
    payer_type VARCHAR(24) NOT NULL DEFAULT 'company' CHECK (payer_type IN ('company', 'employee_out_of_pocket')),
    description VARCHAR(255) NOT NULL,
    issue_date DATE NOT NULL,
    due_date DATE,
    currency VARCHAR(3) NOT NULL DEFAULT 'TRL' CHECK (currency IN ('TRL', 'USD', 'EUR', 'GBP')),
    exchange_rate NUMERIC(18,4) NOT NULL DEFAULT 1.0000 CHECK (exchange_rate > 0),
    gross_total NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    total_discount NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    total_vat NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    total_vat_withholding NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    withholding NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    net_total NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    net_total_in_trl NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    total_paid NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    remaining NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    remaining_in_trl NUMERIC(18,2) NOT NULL DEFAULT 0.00,
    payment_status VARCHAR(24) NOT NULL DEFAULT 'unpaid' CHECK (payment_status IN ('unpaid', 'overdue', 'partially_paid', 'paid', 'cancelled')),
    archived BOOLEAN NOT NULL DEFAULT FALSE,
    idempotency_key VARCHAR(128) UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_purchase_bills_company_dates ON purchase_bills(company_id, issue_date DESC, due_date ASC);

-- 13. CHECKS & PROMISSORY NOTES (Çek ve Senetler)
CREATE TABLE IF NOT EXISTS checks (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    contact_id UUID NOT NULL REFERENCES contacts(id),
    endorsed_to_contact_id UUID REFERENCES contacts(id),
    account_id UUID REFERENCES accounts(id),
    direction VARCHAR(16) NOT NULL CHECK (direction IN ('received', 'issued')),
    check_no VARCHAR(64) NOT NULL,
    bank_name VARCHAR(120) NOT NULL,
    drawer_name VARCHAR(200) NOT NULL,
    issue_date DATE NOT NULL,
    due_date DATE NOT NULL,
    currency VARCHAR(3) NOT NULL DEFAULT 'TRL' CHECK (currency IN ('TRL', 'USD', 'EUR', 'GBP')),
    amount NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    status VARCHAR(24) NOT NULL DEFAULT 'in_portfolio' CHECK (status IN ('in_portfolio', 'collected', 'endorsed', 'paid', 'bounced', 'returned')),
    description TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 14. FINANCIAL TRANSACTIONS & PAYMENTS (Kasa/Banka & Cari Hesap Hareketleri)
CREATE TABLE IF NOT EXISTS transactions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    date DATE NOT NULL,
    transaction_type VARCHAR(32) NOT NULL CHECK (transaction_type IN (
        'invoice_collection', 'bill_payment', 'contact_collection', 'contact_payment',
        'account_inflow', 'account_outflow', 'account_transfer', 'balance_fix',
        'contact_virman', 'invoice_offset', 'check_collection', 'check_payment'
    )),
    debit_account_id UUID REFERENCES accounts(id),
    credit_account_id UUID REFERENCES accounts(id),
    contact_id UUID REFERENCES contacts(id),
    counterparty_contact_id UUID REFERENCES contacts(id),
    sales_invoice_id UUID REFERENCES sales_invoices(id),
    purchase_bill_id UUID REFERENCES purchase_bills(id),
    check_id UUID REFERENCES checks(id),
    currency VARCHAR(3) NOT NULL DEFAULT 'TRL' CHECK (currency IN ('TRL', 'USD', 'EUR', 'GBP')),
    exchange_rate NUMERIC(18,4) NOT NULL DEFAULT 1.0000 CHECK (exchange_rate > 0),
    amount NUMERIC(18,2) NOT NULL CHECK (amount > 0),
    amount_in_trl NUMERIC(18,2) NOT NULL CHECK (amount_in_trl > 0),
    description VARCHAR(255) NOT NULL,
    idempotency_key VARCHAR(128) UNIQUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
CREATE INDEX IF NOT EXISTS idx_transactions_company_date ON transactions(company_id, date DESC);
CREATE INDEX IF NOT EXISTS idx_transactions_contact ON transactions(company_id, contact_id);

-- 15. APPEND-ONLY AUDIT LOG
CREATE TABLE IF NOT EXISTS audit_logs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    company_id UUID NOT NULL REFERENCES companies(id) ON DELETE CASCADE,
    actor_user_id UUID,
    entity_type VARCHAR(64) NOT NULL,
    entity_id UUID NOT NULL,
    action VARCHAR(32) NOT NULL CHECK (action IN ('CREATE', 'UPDATE', 'CANCEL', 'RECOVER', 'PAYMENT', 'TRANSFER', 'RECONCILE')),
    before_state JSONB,
    after_state JSONB,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);
