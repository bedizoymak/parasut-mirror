import {
  DocumentCalculationInput,
  DocumentCalculationResult,
  CalculatedLineResult,
  PaymentStatus,
} from '../contracts/types';

export function roundCurrency(value: number): number {
  if (!Number.isFinite(value)) {
    throw new Error(`Invalid monetary value: ${value}`);
  }
  const sign = value < 0 ? -1 : 1;
  const abs = Math.abs(value);
  return (sign * Math.round((abs + 1e-9) * 100)) / 100;
}

export function calculateDocumentTotals(
  input: DocumentCalculationInput
): DocumentCalculationResult {
  const exchangeRate = input.currency === 'TRL' ? 1.0 : input.exchangeRate;
  if (exchangeRate <= 0) {
    throw new Error('Exchange rate must be strictly positive.');
  }
  if (!input.lines || input.lines.length === 0) {
    throw new Error('At least one line item is required.');
  }

  const pass1 = input.lines.map((line, idx) => {
    if (line.quantity <= 0) throw new Error(`Line ${idx + 1}: quantity must be > 0`);
    if (line.unitPrice < 0) throw new Error(`Line ${idx + 1}: unitPrice cannot be negative`);
    const grossAmount = roundCurrency(line.quantity * line.unitPrice);
    const discType = line.discountType ?? 'percentage';
    const discVal = line.discountValue ?? 0;
    const lineDiscount =
      discType === 'percentage'
        ? roundCurrency((grossAmount * discVal) / 100)
        : roundCurrency(Math.min(grossAmount, discVal));
    const afterLineDiscount = roundCurrency(grossAmount - lineDiscount);
    return { line, detailNo: idx + 1, grossAmount, lineDiscount, afterLineDiscount };
  });

  const subtotalAfterLineDiscounts = roundCurrency(
    pass1.reduce((sum, item) => sum + item.afterLineDiscount, 0)
  );

  const invDiscType = input.invoiceDiscountType ?? 'percentage';
  const invDiscVal = input.invoiceDiscountValue ?? 0;
  const targetInvoiceDiscount =
    subtotalAfterLineDiscounts === 0
      ? 0
      : invDiscType === 'percentage'
      ? roundCurrency((subtotalAfterLineDiscounts * invDiscVal) / 100)
      : roundCurrency(Math.min(subtotalAfterLineDiscounts, invDiscVal));

  const shares = pass1.map((item) => {
    if (subtotalAfterLineDiscounts <= 0 || targetInvoiceDiscount <= 0) return 0;
    return roundCurrency(
      (targetInvoiceDiscount * item.afterLineDiscount) / subtotalAfterLineDiscounts
    );
  });

  if (targetInvoiceDiscount > 0) {
    const sumShares = roundCurrency(shares.reduce((a, b) => a + b, 0));
    const residual = roundCurrency(targetInvoiceDiscount - sumShares);
    if (residual !== 0) {
      for (let i = pass1.length - 1; i >= 0; i--) {
        if (pass1[i].afterLineDiscount > 0) {
          shares[i] = roundCurrency(shares[i] + residual);
          break;
        }
      }
    }
  }

  const calculatedLines: CalculatedLineResult[] = pass1.map((item, idx) => {
    const { line, detailNo, grossAmount, lineDiscount, afterLineDiscount } = item;
    const invoiceDiscountShare = shares[idx];
    const totalDiscount = roundCurrency(lineDiscount + invoiceDiscountShare);
    const netBeforeTaxes = roundCurrency(afterLineDiscount - invoiceDiscountShare);
    const exType = line.exciseDutyType ?? 'percentage';
    const exVal = line.exciseDutyValue ?? 0;
    const exciseDuty =
      exVal <= 0
        ? 0
        : exType === 'percentage'
        ? roundCurrency((netBeforeTaxes * exVal) / 100)
        : roundCurrency(exVal);
    const vatBase = roundCurrency(netBeforeTaxes + exciseDuty);
    const vatRate = line.vatRate ?? 20;
    const vatAmount = roundCurrency((vatBase * vatRate) / 100);
    const vatWithholdingRate = line.vatWithholdingRate ?? 0;
    const vatWithholding =
      vatWithholdingRate > 0 ? roundCurrency((vatAmount * vatWithholdingRate) / 100) : 0;
    const commRate = line.communicationsTaxRate ?? 0;
    const communicationsTax = commRate > 0 ? roundCurrency((vatBase * commRate) / 100) : 0;
    const accRate = line.accommodationTaxRate ?? 0;
    const accommodationTax =
      line.accommodationTaxExempt || accRate <= 0
        ? 0
        : roundCurrency((netBeforeTaxes * accRate) / 100);
    const lineNetTotal = roundCurrency(
      vatBase + vatAmount + communicationsTax + accommodationTax - vatWithholding
    );

    return {
      detailNo,
      description: line.description,
      quantity: line.quantity,
      unitPrice: line.unitPrice,
      grossAmount,
      lineDiscount,
      invoiceDiscountShare,
      totalDiscount,
      netBeforeTaxes,
      exciseDuty,
      vatBase,
      vatRate,
      vatAmount,
      vatWithholdingRate,
      vatWithholding,
      communicationsTax,
      accommodationTax,
      lineNetTotal,
    };
  });

  const grossTotal = roundCurrency(calculatedLines.reduce((s, l) => s + l.grossAmount, 0));
  const totalLineDiscount = roundCurrency(calculatedLines.reduce((s, l) => s + l.lineDiscount, 0));
  const totalInvoiceDiscount = roundCurrency(calculatedLines.reduce((s, l) => s + l.invoiceDiscountShare, 0));
  const totalDiscount = roundCurrency(totalLineDiscount + totalInvoiceDiscount);
  const netSubtotal = roundCurrency(grossTotal - totalDiscount);
  const totalExciseDuty = roundCurrency(calculatedLines.reduce((s, l) => s + l.exciseDuty, 0));
  const totalVat = roundCurrency(calculatedLines.reduce((s, l) => s + l.vatAmount, 0));
  const totalCommunicationsTax = roundCurrency(calculatedLines.reduce((s, l) => s + l.communicationsTax, 0));
  const totalAccommodationTax = roundCurrency(calculatedLines.reduce((s, l) => s + l.accommodationTax, 0));
  const totalVatWithholding = roundCurrency(calculatedLines.reduce((s, l) => s + l.vatWithholding, 0));
  const withholdingRate = input.withholdingRate ?? 0;
  const withholdingAmount = withholdingRate > 0 ? roundCurrency((netSubtotal * withholdingRate) / 100) : 0;
  const netTotal = roundCurrency(
    netSubtotal + totalExciseDuty + totalVat + totalCommunicationsTax + totalAccommodationTax - totalVatWithholding - withholdingAmount
  );
  const netTotalInTrl = roundCurrency(netTotal * exchangeRate);

  return {
    currency: input.currency,
    exchangeRate,
    grossTotal,
    totalLineDiscount,
    totalInvoiceDiscount,
    totalDiscount,
    netSubtotal,
    totalExciseDuty,
    totalVat,
    totalCommunicationsTax,
    totalAccommodationTax,
    totalVatWithholding,
    withholdingAmount,
    netTotal,
    netTotalInTrl,
    lines: calculatedLines,
  };
}

export function resolvePaymentStatus(
  netTotal: number,
  totalPaid: number,
  dueDate: string | undefined,
  referenceDateIso: string,
  cancelled = false
): PaymentStatus {
  if (cancelled) return 'cancelled';
  const remaining = roundCurrency(netTotal - totalPaid);
  if (remaining <= 0) return 'paid';
  if (totalPaid > 0 && remaining > 0) return 'partially_paid';
  if (dueDate && dueDate < referenceDateIso) return 'overdue';
  return 'unpaid';
}
