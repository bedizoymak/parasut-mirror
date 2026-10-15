#!/usr/bin/env python3
from decimal import Decimal, ROUND_HALF_UP
from typing import Dict, Any

TWO_PLACES = Decimal("0.01")

def d_round(val: Any) -> Decimal:
    return Decimal(str(val)).quantize(TWO_PLACES, rounding=ROUND_HALF_UP)

def calculate_document_totals(payload: Dict[str, Any]) -> Dict[str, Any]:
    currency = payload.get("currency", "TRL")
    fx = Decimal("1.0000") if currency == "TRL" else Decimal(str(payload.get("exchange_rate", "1.0000")))
    if fx <= Decimal("0"):
        raise ValueError("exchange_rate must be positive")
    lines = payload.get("lines", [])
    if not lines:
        raise ValueError("At least one line item is required")

    pass1 = []
    for idx, line in enumerate(lines, start=1):
        qty = Decimal(str(line["quantity"]))
        price = Decimal(str(line["unit_price"]))
        gross = d_round(qty * price)
        disc_type = line.get("discount_type", "percentage")
        disc_val = Decimal(str(line.get("discount_value", "0")))
        line_disc = d_round(gross * disc_val / Decimal("100")) if disc_type == "percentage" else d_round(min(gross, disc_val))
        after_line = gross - line_disc
        pass1.append({"detail_no": idx, "raw": line, "gross": gross, "line_disc": line_disc, "after_line": after_line})

    subtotal_after_line = sum((x["after_line"] for x in pass1), Decimal("0.00"))
    inv_disc_type = payload.get("invoice_discount_type", "percentage")
    inv_disc_val = Decimal(str(payload.get("invoice_discount_value", "0")))
    if subtotal_after_line == Decimal("0.00"):
        target_inv_disc = Decimal("0.00")
    elif inv_disc_type == "percentage":
        target_inv_disc = d_round(subtotal_after_line * inv_disc_val / Decimal("100"))
    else:
        target_inv_disc = d_round(min(subtotal_after_line, inv_disc_val))

    shares = [
        Decimal("0.00") if (subtotal_after_line <= Decimal("0.00") or target_inv_disc <= Decimal("0.00"))
        else d_round(target_inv_disc * item["after_line"] / subtotal_after_line)
        for item in pass1
    ]
    if target_inv_disc > Decimal("0.00"):
        residual = target_inv_disc - sum(shares, Decimal("0.00"))
        if residual != Decimal("0.00"):
            for i in range(len(pass1) - 1, -1, -1):
                if pass1[i]["after_line"] > Decimal("0.00"):
                    shares[i] += residual
                    break

    out_lines = []
    for item, inv_share in zip(pass1, shares):
        raw = item["raw"]
        net_before_tax = item["after_line"] - inv_share
        ex_type = raw.get("excise_duty_type", "percentage")
        ex_val = Decimal(str(raw.get("excise_duty_value", "0")))
        excise = Decimal("0.00") if ex_val <= Decimal("0") else (
            d_round(net_before_tax * ex_val / Decimal("100")) if ex_type == "percentage" else d_round(ex_val)
        )
        vat_base = net_before_tax + excise
        vat_rate = Decimal(str(raw.get("vat_rate", "20")))
        vat_amount = d_round(vat_base * vat_rate / Decimal("100"))
        vat_wh_rate = Decimal(str(raw.get("vat_withholding_rate", "0")))
        vat_wh = d_round(vat_amount * vat_wh_rate / Decimal("100")) if vat_wh_rate > 0 else Decimal("0.00")
        comm_rate = Decimal(str(raw.get("communications_tax_rate", "0")))
        comm_tax = d_round(vat_base * comm_rate / Decimal("100")) if comm_rate > 0 else Decimal("0.00")
        acc_rate = Decimal(str(raw.get("accommodation_tax_rate", "0")))
        acc_exempt = bool(raw.get("accommodation_tax_exempt", False))
        acc_tax = Decimal("0.00") if (acc_exempt or acc_rate <= 0) else d_round(net_before_tax * acc_rate / Decimal("100"))
        line_net = vat_base + vat_amount + comm_tax + acc_tax - vat_wh
        out_lines.append({
            "detail_no": item["detail_no"],
            "gross_amount": item["gross"],
            "line_discount": item["line_disc"],
            "invoice_discount_share": inv_share,
            "total_discount": item["line_disc"] + inv_share,
            "net_before_taxes": net_before_tax,
            "excise_duty": excise,
            "vat_base": vat_base,
            "vat_amount": vat_amount,
            "vat_withholding": vat_wh,
            "communications_tax": comm_tax,
            "accommodation_tax": acc_tax,
            "line_net_total": line_net,
        })

    gross_total = sum((l["gross_amount"] for l in out_lines), Decimal("0.00"))
    total_line_disc = sum((l["line_discount"] for l in out_lines), Decimal("0.00"))
    total_inv_disc = sum((l["invoice_discount_share"] for l in out_lines), Decimal("0.00"))
    total_discount = total_line_disc + total_inv_disc
    net_subtotal = gross_total - total_discount
    total_excise = sum((l["excise_duty"] for l in out_lines), Decimal("0.00"))
    total_vat = sum((l["vat_amount"] for l in out_lines), Decimal("0.00"))
    total_comm = sum((l["communications_tax"] for l in out_lines), Decimal("0.00"))
    total_acc = sum((l["accommodation_tax"] for l in out_lines), Decimal("0.00"))
    total_vat_wh = sum((l["vat_withholding"] for l in out_lines), Decimal("0.00"))
    wh_rate = Decimal(str(payload.get("withholding_rate", "0")))
    withholding = d_round(net_subtotal * wh_rate / Decimal("100")) if wh_rate > 0 else Decimal("0.00")
    net_total = net_subtotal + total_excise + total_vat + total_comm + total_acc - total_vat_wh - withholding
    net_total_in_trl = d_round(net_total * fx)

    return {
        "currency": currency,
        "exchange_rate": fx,
        "gross_total": gross_total,
        "total_line_discount": total_line_disc,
        "total_invoice_discount": total_inv_disc,
        "total_discount": total_discount,
        "net_subtotal": net_subtotal,
        "total_excise_duty": total_excise,
        "total_vat": total_vat,
        "total_communications_tax": total_comm,
        "total_accommodation_tax": total_acc,
        "total_vat_withholding": total_vat_wh,
        "withholding": withholding,
        "net_total": net_total,
        "net_total_in_trl": net_total_in_trl,
        "lines": out_lines,
    }
