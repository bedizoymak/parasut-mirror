# Architecture Decisions Record (ADR) — Paraşüt Mirror Gemini Edition

## ADR-001: Strict 6-Layer Domain & Persistence Architecture
In accordance with Section 8 of the Master Engineering Directive, the system is structured into six explicit, decoupled layers:
1. **SOURCE REPRESENTATION**: JSON:API v4-compatible DTOs and import/export envelopes (`app/src/contracts/`).
2. **CANONICAL DATA MODEL**: Normalized relational schema (`supabase/migrations/20261014000001_initial_parasut_mirror_schema.sql`) with strict foreign keys, check constraints, and `NUMERIC(18,2)` / `NUMERIC(18,4)` monetary columns.
3. **DOMAIN TRANSACTIONS**: Atomic double-entry-consistent mutations (invoice creation + stock movement + contact ledger entry; payment allocation + cash/bank transaction + contact ledger credit; inter-contact virman; invoice offsetting/mahsuplaştırma).
4. **VALIDATED FINANCIAL PROJECTIONS**: Deterministic calculation engine (`app/src/domain/financialEngine.ts` & Python verification mirror `tests/financial_engine.py`) computing line/subtotal discounts, ÖTV, KDV, ÖİV, Konaklama Vergisi, KDV Tevkifatı, Stopaj, multi-currency TRL conversions, aging buckets, and monthly VAT summaries.
5. **APPLICATION API**: Repository & Service layer supporting filtering, sorting, compound includes, idempotency keys, and pagination without N+1 queries.
6. **REACT INTERFACE**: Modular, responsive Turkish ERP UI (`app/`) faithfully implementing all 9 Paraşüt functional domains with live interactive persistence, instant validation, and zero decorative no-op controls.

## ADR-002: Sandbox Execution & Host Workspace Mapping
- The current execution environment runs inside an isolated Linux gVisor sandbox VM (`/working_dir/c_ae03d939d62ef062`) with outbound VM internet disabled and Node `v18.20.4`.
- All project artifacts are authored inside `/working_dir/c_ae03d939d62ef062/parasut-mirror` with an independent Git commit history, and packaged with a 1-click Windows deployment script targeting `C:\Users\Bediz\Documents\gemini\parasut mirror` plus a standalone self-contained interactive WebApp bundle (`parasut_mirror_gemini_edition_erp.html`) so the application can be used immediately in the browser as well as run locally via Vite/Supabase.

## ADR-003: Authoritative Backend Financial Truth
- Financial totals (`gross_total`, `total_discount`, `total_vat`, `total_vat_withholding`, `withholding`, `net_total`, `remaining_amount`) are always computed and verified by the deterministic domain engine and enforced by PostgreSQL triggers (`supabase/migrations/20261014000002_rls_and_financial_triggers.sql`).
