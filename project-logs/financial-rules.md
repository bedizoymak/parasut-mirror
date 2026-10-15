# Paraşüt Mirror — Deterministic Financial Engineering Specification

**Status:** VERIFIED AGAINST OFFICIAL PARAŞÜT API V4 & USER GUIDES  
**Precision Standard:** Fixed-point Decimal (`NUMERIC(18,4)` intermediate / `NUMERIC(18,2)` currency settlement, `ROUND_HALF_UP` at defined line/tax boundaries).  
**Primary Sources:**
- [Paraşüt API v4 OpenAPI Specification](https://apidocs.parasut.com/)
- [Paraşüt KDV, Stopaj ve Tevkifat Hesaplama Rehberi](https://www.parasut.com/kdv-hesaplama-araci)
- [Paraşüt Ara Toplam İndirimi Rehberi](https://www.parasut.com/kullanim-kilavuzu/faturaya-ara-toplam-indirimi-eklemek)
- [Paraşüt Tevkifatlı Fatura Rehberi](https://www.parasut.com/kullanim-kilavuzu/tevkifatli-fatura-olusturmak)

---

## 1. Invoice & Offer Line-Level Calculation Engine (`sales_invoices`, `sales_offers`, `purchase_bills#detailed`)

For each line $i \in \{1, \dots, n\}$ with quantity $q_i \ge 0$ and unit price $p_i \ge 0$:

### 1.1 Gross Line Amount (Brüt Satır Tutarı)
$$G_i = \text{round}_2(q_i \times p_i)$$

### 1.2 Line-Level Discount (Satır İndirimi)
Line discount type $d^{\text{line}}_{i,\text{type}} \in \{\text{percentage}, \text{amount}\}$ with value $v^{\text{disc}}_i$:
$$D^{\text{line}}_i = \begin{cases} \text{round}_2\left(G_i \times \frac{v^{\text{disc}}_i}{100}\right) & \text{if percentage} \\ \text{round}_2(\min(G_i, v^{\text{disc}}_i)) & \text{if amount} \end{cases}$$
$$N^{\text{after\_line}}_i = G_i - D^{\text{line}}_i$$

### 1.3 Invoice-Level Subtotal Discount (Ara Toplam İndirimi — Proportional Distribution)
Per [Paraşüt Ara Toplam İndirimi Rehberi](https://www.parasut.com/kullanim-kilavuzu/faturaya-ara-toplam-indirimi-eklemek):
> *"Belirlediğiniz indirim miktarı, faturanızın KDV hariç ara toplam miktarına uygulanır; KDV miktarı, indirimli ara toplam değerine göre yeniden hesaplanır. Yapılan ara toplam indirimi, faturadaki satırlara miktarlarının oranına göre dağıtılarak uygulanır."*

Let $S_{\text{after\_line}} = \sum_{i=1}^n N^{\text{after\_line}}_i$. Given invoice discount $(d^{\text{inv}}_{\text{type}}, v^{\text{inv}})$:
$$D^{\text{inv}}_{\text{total}} = \begin{cases} \text{round}_2\left(S_{\text{after\_line}} \times \frac{v^{\text{inv}}}{100}\right) & \text{if percentage} \\ \text{round}_2(\min(S_{\text{after\_line}}, v^{\text{inv}})) & \text{if amount} \end{cases}$$
Each line receives a proportional share $D^{\text{inv}}_i$:
$$D^{\text{inv}}_i = \text{round}_2\left(D^{\text{inv}}_{\text{total}} \times \frac{N^{\text{after\_line}}_i}{S_{\text{after\_line}}}\right)$$
(with any 1-kuruş rounding residual allocated deterministically to the last non-zero line so $\sum_i D^{\text{inv}}_i = D^{\text{inv}}_{\text{total}}$).
Total discount on line $i$:
$$D_i = D^{\text{line}}_i + D^{\text{inv}}_i, \quad M^{\text{net}}_i = G_i - D_i$$

### 1.4 Special Excise Duty (ÖTV — Özel Tüketim Vergisi)
Excise duty applies to $M^{\text{net}}_i$ before VAT, and increases the VAT base (KDV Matrahı) on commercial invoices:
$$E_i = \begin{cases} \text{round}_2\left(M^{\text{net}}_i \times \frac{r^{\text{excise}}_i}{100}\right) & \text{if percentage} \\ \text{round}_2(v^{\text{excise}}_i) & \text{if amount} \end{cases}$$
$$B^{\text{vat}}_i = M^{\text{net}}_i + E_i$$

### 1.5 Value Added Tax (KDV — Katma Değer Vergisi)
Supported statutory Turkish VAT rates $r^{\text{vat}}_i \in \{0, 1, 10, 20\}$ (plus legacy $8, 18$ for historical documents):
$$V_i = \text{round}_2\left(B^{\text{vat}}_i \times \frac{r^{\text{vat}}_i}{100}\right)$$

### 1.6 Special Communications Tax (ÖİV) & Accommodation Tax (Konaklama Vergisi)
Calculated on $M^{\text{net}}_i$ (or $B^{\text{vat}}_i$ per tax type; in Paraşüt, Konaklama Vergisi default rate is $2\%$ on net service base $M^{\text{net}}_i$, and ÖİV is $r^{\text{comm}}_i\%$ on $B^{\text{vat}}_i$):
$$C_i = \text{round}_2\left(B^{\text{vat}}_i \times \frac{r^{\text{comm}}_i}{100}\right), \quad A_i = \begin{cases} 0 & \text{if exempt} \\ \text{round}_2\left(M^{\text{net}}_i \times \frac{r^{\text{acc}}_i}{100}\right) & \text{otherwise} \end{cases}$$

### 1.7 VAT Withholding (KDV Tevkifatı)
Per [Paraşüt Tevkifatlı Fatura Rehberi](https://www.parasut.com/kullanim-kilavuzu/tevkifatli-fatura-olusturmak), tevkifat rates are fractions $k/10 \in \{2/10, 3/10, 4/10, 5/10, 7/10, 9/10, 10/10\}$ (represented in API v4 as percentage $20, 30, 40, 50, 70, 90, 100$):
$$W^{\text{vat}}_i = \text{round}_2\left(V_i \times \frac{r^{\text{vat\_wh}}_i}{100}\right)$$

### 1.8 Income Tax Withholding (Stopaj — Serbest Meslek Makbuzu / Kira)
Applied at rate $r^{\text{wh}} \in \{0, 10, 15, 17, 20, 27, 35\}$ on the net subtotal after discount ($\sum_i M^{\text{net}}_i$):
$$W^{\text{stopaj}} = \text{round}_2\left(\left(\sum_{i=1}^n M^{\text{net}}_i\right) \times \frac{r^{\text{wh}}}{100}\right)$$

### 1.9 Document Totals & Net Payable (Genel Toplam)
- **Gross Subtotal (`gross_total` / Ara Toplam):** $G = \sum_{i=1}^n G_i$
- **Total Discount (`total_discount`):** $D = \sum_{i=1}^n D_i$
- **Net Subtotal (`net_subtotal` / KDV Matrahı Öncesi):** $M = G - D$
- **Total Excise Duty (`total_excise_duty`):** $E = \sum_{i=1}^n E_i$
- **Total VAT (`total_vat`):** $V = \sum_{i=1}^n V_i$
- **Total Communications Tax (`total_communications_tax`):** $C = \sum_{i=1}^n C_i$
- **Total Accommodation Tax (`total_accommodation_tax`):** $A = \sum_{i=1}^n A_i$
- **Total VAT Withholding (`total_vat_withholding`):** $W^{\text{vat}} = \sum_{i=1}^n W^{\text{vat}}_i$
- **Withholding / Stopaj (`withholding`):** $W^{\text{stopaj}}$
- **Grand Net Total (`net_total` / Genel Toplam):**
$$T_{\text{net}} = M + E + V + C + A - W^{\text{vat}} - W^{\text{stopaj}}$$
- **TRL Equivalent (`net_total_in_trl`):** For currency $c \in \{\text{TRL}, \text{USD}, \text{EUR}, \text{GBP}\}$ with exchange rate $fx > 0$ ($fx = 1.0000$ for `TRL`):
$$T_{\text{net, TRL}} = \text{round}_2(T_{\text{net}} \times fx)$$

---

## 2. Golden Test Vectors (Verified by Automated Test Suite)

| Vector ID | Scenario | Inputs | Expected Outputs |
| :--- | :--- | :--- | :--- |
| **GTV-001** | Standard Commercial Sales Invoice (20% KDV) | 2 lines: `(q=5, p=1250.00, vat=20%)`, `(q=2, p=750.00, vat=20%)` | `gross_total=7750.00`, `total_vat=1550.00`, `net_total=9300.00` |
| **GTV-002** | Combined Line Discount + Proportional Subtotal Discount | Line 1: `q=10, p=100.00, line_disc=10%, vat=20%` (`900.00`); Line 2: `q=1, p=300.00, vat=10%` (`300.00`); Invoice discount: `120.00 TL` (10% proportional: `90.00` on L1, `30.00` on L2) | `gross_total=1300.00`, `total_discount=220.00`, `L1_net=810.00 (VAT=162.00)`, `L2_net=270.00 (VAT=27.00)`, `total_vat=189.00`, `net_total=1269.00` |
| **GTV-003** | KDV Tevkifatlı Fatura (9/10 Security/Cleaning Service) | `q=1, p=50000.00, vat=20%, vat_withholding=90% (9/10)` | `gross_total=50000.00`, `total_vat=10000.00`, `total_vat_withholding=9000.00`, `net_total=51000.00` |
| **GTV-004** | Serbest Meslek Makbuzu (20% Stopaj + 20% KDV + 5/10 Tevkifat) | `q=1, p=25000.00, vat=20%, withholding_rate=20%, vat_withholding_rate=50%` | `gross_total=25000.00`, `withholding=5000.00`, `total_vat=5000.00`, `total_vat_withholding=2500.00`, `net_total=22500.00` |
| **GTV-005** | Multi-Currency USD Invoice + Partial Collection | `q=1, p=1000.00 USD, vat=20%, fx=34.2500` (`net_total=1200.00 USD`, `41100.00 TL`); Collection `500.00 USD` | `remaining=700.00 USD`, `payment_status='partially_paid'`, Account `+500.00 USD`, Contact receivable `700.00 USD` |
| **GTV-006** | Accommodation Tax (2% Konaklama Vergisi + 10% KDV) | Hotel stay `q=3, p=4000.00, vat=10%, acc_tax=2%` | `gross_total=12000.00`, `total_vat=1200.00`, `total_accommodation_tax=240.00`, `net_total=13440.00` |
| **GTV-007** | Monthly VAT Report Reconciliation | Sales VAT `1550.00 + 189.00 + (10000-9000) + (5000-2500) = 5239.00` vs Deductible Expense VAT `3200.00` | `net_calculated_vat=5239.00`, `deductible_vat=3200.00`, `net_payable_vat=2039.00` |
