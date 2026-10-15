#!/usr/bin/env python3
import pathlib
import sqlite3
import sys
import time
import unittest
from decimal import Decimal

sys.path.insert(0, str(pathlib.Path(__file__).resolve().parent))
from financial_engine import calculate_document_totals

class TestParasutMirrorFinancialGolden(unittest.TestCase):
    def test_gtv_001_standard_commercial_invoice(self):
        res = calculate_document_totals({
            "currency": "TRL",
            "lines": [
                {"quantity": "5", "unit_price": "1250.00", "vat_rate": "20"},
                {"quantity": "2", "unit_price": "750.00", "vat_rate": "20"},
            ]
        })
        self.assertEqual(res["gross_total"], Decimal("7750.00"))
        self.assertEqual(res["total_vat"], Decimal("1550.00"))
        self.assertEqual(res["net_total"], Decimal("9300.00"))

    def test_gtv_002_proportional_subtotal_discount(self):
        res = calculate_document_totals({
            "currency": "TRL",
            "invoice_discount_type": "amount",
            "invoice_discount_value": "120.00",
            "lines": [
                {"quantity": "10", "unit_price": "100.00", "discount_type": "percentage", "discount_value": "10", "vat_rate": "20"},
                {"quantity": "1", "unit_price": "300.00", "vat_rate": "10"},
            ]
        })
        self.assertEqual(res["gross_total"], Decimal("1300.00"))
        self.assertEqual(res["total_discount"], Decimal("220.00"))
        self.assertEqual(res["total_vat"], Decimal("189.00"))
        self.assertEqual(res["net_total"], Decimal("1269.00"))

    def test_gtv_003_vat_withholding_9_10(self):
        res = calculate_document_totals({
            "currency": "TRL",
            "lines": [
                {"quantity": "1", "unit_price": "50000.00", "vat_rate": "20", "vat_withholding_rate": "90"}
            ]
        })
        self.assertEqual(res["total_vat"], Decimal("10000.00"))
        self.assertEqual(res["total_vat_withholding"], Decimal("9000.00"))
        self.assertEqual(res["net_total"], Decimal("51000.00"))

    def test_gtv_004_smm_stopaj_and_tevkifat(self):
        res = calculate_document_totals({
            "currency": "TRL",
            "withholding_rate": "20",
            "lines": [
                {"quantity": "1", "unit_price": "25000.00", "vat_rate": "20", "vat_withholding_rate": "50"}
            ]
        })
        self.assertEqual(res["withholding"], Decimal("5000.00"))
        self.assertEqual(res["total_vat"], Decimal("5000.00"))
        self.assertEqual(res["total_vat_withholding"], Decimal("2500.00"))
        self.assertEqual(res["net_total"], Decimal("22500.00"))

    def test_gtv_005_multi_currency_usd_conversion(self):
        res = calculate_document_totals({
            "currency": "USD",
            "exchange_rate": "34.2500",
            "lines": [
                {"quantity": "1", "unit_price": "1000.00", "vat_rate": "20"}
            ]
        })
        self.assertEqual(res["net_total"], Decimal("1200.00"))
        self.assertEqual(res["net_total_in_trl"], Decimal("41100.00"))

    def test_gtv_006_excise_comm_and_accommodation_tax(self):
        res = calculate_document_totals({
            "currency": "TRL",
            "lines": [
                {
                    "quantity": "3",
                    "unit_price": "4000.00",
                    "vat_rate": "10",
                    "accommodation_tax_rate": "2",
                }
            ]
        })
        self.assertEqual(res["total_vat"], Decimal("1200.00"))
        self.assertEqual(res["total_accommodation_tax"], Decimal("240.00"))
        self.assertEqual(res["net_total"], Decimal("13440.00"))


class TestDatabasePersistenceRLSAndLedger(unittest.TestCase):
    def setUp(self):
        self.conn = sqlite3.connect(":memory:")
        self.conn.execute("PRAGMA foreign_keys = ON;")
        self.conn.executescript('''
            CREATE TABLE companies (id TEXT PRIMARY KEY, name TEXT NOT NULL);
            CREATE TABLE company_memberships (
                company_id TEXT NOT NULL REFERENCES companies(id),
                user_id TEXT NOT NULL,
                role TEXT NOT NULL,
                can_view_cash INTEGER NOT NULL DEFAULT 1,
                PRIMARY KEY (company_id, user_id)
            );
            CREATE TABLE contacts (
                id TEXT PRIMARY KEY,
                company_id TEXT NOT NULL REFERENCES companies(id),
                name TEXT NOT NULL,
                account_type TEXT NOT NULL,
                balance_trl REAL NOT NULL DEFAULT 0.0
            );
            CREATE TABLE accounts (
                id TEXT PRIMARY KEY,
                company_id TEXT NOT NULL REFERENCES companies(id),
                name TEXT NOT NULL,
                account_type TEXT NOT NULL,
                currency TEXT NOT NULL DEFAULT 'TRL',
                balance REAL NOT NULL DEFAULT 0.0
            );
            CREATE TABLE sales_invoices (
                id TEXT PRIMARY KEY,
                company_id TEXT NOT NULL REFERENCES companies(id),
                contact_id TEXT NOT NULL REFERENCES contacts(id),
                net_total REAL NOT NULL,
                total_paid REAL NOT NULL DEFAULT 0.0,
                remaining REAL NOT NULL,
                payment_status TEXT NOT NULL,
                idempotency_key TEXT UNIQUE
            );
            CREATE TRIGGER trg_invoice_overpayment_guard
            BEFORE UPDATE ON sales_invoices
            WHEN NEW.total_paid > NEW.net_total OR NEW.total_paid < 0
            BEGIN
                SELECT RAISE(ABORT, 'Invalid payment allocation amount');
            END;
        ''')
        self.conn.execute("INSERT INTO companies VALUES ('comp-1', 'Boğaziçi Dijital A.Ş.'), ('comp-2', 'Başka Firma Ltd.')")
        self.conn.execute("INSERT INTO company_memberships VALUES ('comp-1', 'user-1', 'owner', 1), ('comp-1', 'user-sales', 'sales', 0), ('comp-2', 'user-2', 'owner', 1)")
        self.conn.execute("INSERT INTO contacts VALUES ('cnt-1', 'comp-1', 'Marmara Lojistik A.Ş.', 'customer', 0.0), ('cnt-2', 'comp-2', 'Gizli Müşteri', 'customer', 50000.0)")
        self.conn.execute("INSERT INTO accounts VALUES ('acc-1', 'comp-1', 'Merkez TL Kasa', 'cash', 'TRL', 100000.0), ('acc-2', 'comp-1', 'Garanti BBVA Ticari TL', 'bank', 'TRL', 250000.0)")

    def tearDown(self):
        self.conn.close()

    def test_tenant_isolation_and_rbac_enforcement(self):
        rows = self.conn.execute('''
            SELECT c.id, c.name FROM contacts c
            JOIN company_memberships cm ON cm.company_id = c.company_id
            WHERE cm.user_id = 'user-1'
        ''').fetchall()
        self.assertEqual(len(rows), 1)
        self.assertEqual(rows[0][0], "cnt-1")

        cash_rows = self.conn.execute('''
            SELECT a.id FROM accounts a
            JOIN company_memberships cm ON cm.company_id = a.company_id
            WHERE cm.user_id = 'user-sales' AND cm.can_view_cash = 1
        ''').fetchall()
        self.assertEqual(len(cash_rows), 0)

    def test_double_entry_collection_and_overpayment_guard(self):
        self.conn.execute("INSERT INTO sales_invoices VALUES ('inv-1', 'comp-1', 'cnt-1', 9300.0, 0.0, 9300.0, 'unpaid', 'idem-001')")
        self.conn.execute("UPDATE contacts SET balance_trl = balance_trl + 9300.0 WHERE id = 'cnt-1'")
        with self.assertRaises(sqlite3.IntegrityError):
            self.conn.execute("INSERT INTO sales_invoices VALUES ('inv-dup', 'comp-1', 'cnt-1', 9300.0, 0.0, 9300.0, 'unpaid', 'idem-001')")
        self.conn.execute("UPDATE sales_invoices SET total_paid = 4300.0, remaining = 5000.0, payment_status = 'partially_paid' WHERE id = 'inv-1'")
        with self.assertRaises(sqlite3.IntegrityError):
            self.conn.execute("UPDATE sales_invoices SET total_paid = 10000.0 WHERE id = 'inv-1'")

    def test_performance_benchmark_5000_invoices(self):
        t0 = time.perf_counter()
        batch = [
            (f"inv-perf-{i}", "comp-1", "cnt-1", 1200.0 + (i % 500), 200.0, 1000.0 + (i % 500), "partially_paid" if i % 2 == 0 else "overdue", f"idem-perf-{i}")
            for i in range(5000)
        ]
        self.conn.executemany("INSERT INTO sales_invoices VALUES (?, ?, ?, ?, ?, ?, ?, ?)", batch)
        insert_ms = (time.perf_counter() - t0) * 1000.0

        t1 = time.perf_counter()
        page = self.conn.execute('''
            SELECT id, net_total, remaining, payment_status
            FROM sales_invoices
            WHERE company_id = 'comp-1' AND payment_status = 'overdue'
            ORDER BY remaining DESC
            LIMIT 25 OFFSET 0
        ''').fetchall()
        query_ms = (time.perf_counter() - t1) * 1000.0
        self.assertEqual(len(page), 25)
        self.assertLess(insert_ms, 500.0)
        self.assertLess(query_ms, 50.0)

if __name__ == "__main__":
    unittest.main(verbosity=2)
