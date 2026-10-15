# Observable Network & API v4 Contract Analysis

## 1. JSON:API Envelope & Compound Document Pattern
Paraşüt API v4 ([`https://apidocs.parasut.com/`](https://apidocs.parasut.com/)) strictly follows the JSON:API (`application/vnd.api+json`) specification:
- **Primary Data (`data`)**: Contains `{ id, type, attributes, relationships }`.
- **Compound Includes (`included`)**: Avoids N+1 HTTP waterfalls on detail views by embedding related `contacts`, `sales_invoice_details`, `products`, `payments`, `transactions`, `item_categories`, and `tags` in a single round-trip via `?include=contact,details.product,payments.transaction`.
- **Pagination (`meta`)**: Returns `{ current_page, total_pages, total_count }` using `page[number]` and `page[size]` (default 15, max 25).

## 2. Asynchronous Job Pattern (`trackable_jobs`)
Formalization endpoints (`POST /e_invoices`, `POST /e_archives`, `POST /e_smms`) and PDF rendering do not block HTTP workers. Instead:
1. Submission returns HTTP `201/202` with `data.type = "trackable_jobs"` and `attributes.status` in `("pending", "running", "done", "error")`.
2. Clients poll `GET /v4/{company_id}/trackable_jobs/{id}` (TTL 15 minutes).
3. Once `status == "done"`, querying the invoice with `?include=active_e_document` reveals the assigned e-Document ID and temporary signed PDF URL (TTL 1 hour, returning HTTP `204 No Content` until PDF generation finishes).

## 3. Payment & Ledger Transaction Coupling
In Paraşüt API v4, recording a collection on a sales invoice (`POST /sales_invoices/{id}/payments`) creates two linked entities:
- A `payments` allocation record linking the invoice and amount.
- A financial `transactions` record (`debit_transaction` on the target Cash/Bank account and credit on the Contact ledger).
Deleting a payment requires resolving `?include=payments.transaction` and calling `DELETE /v4/{company_id}/transactions/{transaction_id}`, which atomically restores the invoice's `remaining` balance and reverses the account balance.
