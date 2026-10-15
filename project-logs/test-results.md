# Automated Verification & Test Results — Paraşüt Mirror Gemini Edition

- **Execution Timestamp:** `2026-10-14T08:54:00+03:00`
- **Node.js Domain Engine Suite (`tests/run_node_domain_tests.mjs`):** `7 / 7 PASSED`
- **Python Financial Golden, SQLite Persistence, RLS & Performance Suite (`tests/test_parasut_mirror.py`):** `9 / 9 PASSED`
- **REA Epistemic Evidence Inspector (`tools/rea/rea_evidence_inspector.py`):** `18 / 18 CONTROLS VALIDATED (0 errors)`

| Suite | Test Case | Target Contract / Invariant | Result |
| :--- | :--- | :--- | :---: |
| **Node.js Financial Engine** | `GTV-001` | Standard Commercial Sales Invoice (20% KDV) | **PASS** |
| **Node.js Financial Engine** | `GTV-002` | Combined Line Discount + Proportional Invoice Subtotal Discount | **PASS** |
| **Node.js Financial Engine** | `GTV-003` | 9/10 KDV Withholding (Tevkifatlı Satış Faturası) | **PASS** |
| **Node.js Financial Engine** | `GTV-004` | Serbest Meslek Makbuzu (20% Stopaj + 5/10 KDV Tevkifatı) | **PASS** |
| **Node.js Financial Engine** | `GTV-005` | Multi-Currency USD Invoice & TRL Conversion (`fx=34.2500`) | **PASS** |
| **Node.js Financial Engine** | `GTV-006` | Accommodation Tax (2% Konaklama Vergisi + 10% KDV) | **PASS** |
| **Node.js Financial Engine** | `GTV-008` | 1-Kuruş Residual Allocation on Proportional Subtotal Discount (`3.33 + 3.33 + 3.34 = 10.00`) | **PASS** |
| **Python Golden & DB Suite** | `test_gtv_001` to `test_gtv_006` | Fixed-point `Decimal` cross-verification of TypeScript engine | **PASS** |
| **Python Golden & DB Suite** | `test_tenant_isolation_and_rbac_enforcement` | Cross-tenant isolation (`comp-1` vs `comp-2`) & `can_view_cash` RBAC | **PASS** |
| **Python Golden & DB Suite** | `test_double_entry_collection_and_overpayment_guard` | Idempotency key uniqueness, partial collection ledger update & overpayment trigger rejection | **PASS** |
| **Python Golden & DB Suite** | `test_performance_benchmark_5000_invoices` | 5,000 synthetic invoices batch insert & indexed overdue pagination | **PASS** |
