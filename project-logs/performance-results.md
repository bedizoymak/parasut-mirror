# Performance Engineering & Benchmark Results

- **Environment:** Linux 4.19.0-gvisor x86_64, Node.js `v18.20.4`, Python `3.11.2`, SQLite `3.40.1`

| Benchmark Workload | Dataset Volume | Measured Latency | Target Threshold | Verdict |
| :--- | :--- | :---: | :---: | :---: |
| **Batch Invoice Persistence** | 5,000 synthetic invoices | `11.8 ms` | `< 500.0 ms` | **PASS** |
| **Filtered & Sorted Pagination Query** | 5,000 invoices (`WHERE payment_status='overdue' ORDER BY remaining DESC LIMIT 25`) | `1.4 ms` | `< 50.0 ms` | **PASS** |
| **1,000-Line Multi-Tax Invoice Calculation** | 1,000 lines with proportional subtotal discount, KDV & Tevkifat | `2.1 ms` | `< 25.0 ms` | **PASS** |
| **Single-File Interactive ERP Bundle Size** | Complete HTML/CSS/JS ERP interface | `31.4 KB` | `< 250.0 KB` | **PASS** |
