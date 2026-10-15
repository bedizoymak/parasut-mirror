import assert from 'node:assert/strict';

function roundCurrency(value) {
  if (!Number.isFinite(value)) throw new Error(`Invalid monetary value: ${value}`);
  const sign = value < 0 ? -1 : 1;
  const abs = Math.abs(value);
  return (sign * Math.round((abs + 1e-9) * 100)) / 100;
}

function calculateDocumentTotals(input) {
  const exchangeRate = input.currency === 'TRL' ? 1.0 : input.exchangeRate;
  const pass1 = input.lines.map((line, idx) => {
    const grossAmount = roundCurrency(line.quantity * line.unitPrice);
    const discType = line.discountType ?? 'percentage';
    const discVal = line.discountValue ?? 0;
    const lineDiscount = discType === 'percentage'
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
  const targetInvoiceDiscount = subtotalAfterLineDiscounts === 0 ? 0 :
    invDiscType === 'percentage'
      ? roundCurrency((subtotalAfterLineDiscounts * invDiscVal) / 100)
      : roundCurrency(Math.min(subtotalAfterLineDiscounts, invDiscVal));

  const shares = pass1.map((item) => {
    if (subtotalAfterLineDiscounts <= 0 || targetInvoiceDiscount <= 0) return 0;
    return roundCurrency((targetInvoiceDiscount * item.afterLineDiscount) / subtotalAfterLineDiscounts);
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

  const calculatedLines = pass1.map((item, idx) => {
    const { line, detailNo, grossAmount, lineDiscount, afterLineDiscount } = item;
    const invoiceDiscountShare = shares[idx];
    const totalDiscount = roundCurrency(lineDiscount + invoiceDiscountShare);
    const netBeforeTaxes = roundCurrency(afterLineDiscount - invoiceDiscountShare);
    const exType = line.exciseDutyType ?? 'percentage';
    const exVal = line.exciseDutyValue ?? 0;
    const exciseDuty = exVal <= 0 ? 0 : exType === 'percentage'
      ? roundCurrency((netBeforeTaxes * exVal) / 100)
      : roundCurrency(exVal);
    const vatBase = roundCurrency(netBeforeTaxes + exciseDuty);
    const vatRate = line.vatRate ?? 20;
    const vatAmount = roundCurrency((vatBase * vatRate) / 100);
    const vatWithholdingRate = line.vatWithholdingRate ?? 0;
    const vatWithholding = vatWithholdingRate > 0 ? roundCurrency((vatAmount * vatWithholdingRate) / 100) : 0;
    const commRate = line.communicationsTaxRate ?? 0;
    const communicationsTax = commRate > 0 ? roundCurrency((vatBase * commRate) / 100) : 0;
    const accRate = line.accommodationTaxRate ?? 0;
    const accommodationTax = line.accommodationTaxExempt || accRate <= 0 ? 0 : roundCurrency((netBeforeTaxes * accRate) / 100);
    const lineNetTotal = roundCurrency(vatBase + vatAmount + communicationsTax + accommodationTax - vatWithholding);
    return {
      detailNo, description: line.description, quantity: line.quantity, unitPrice: line.unitPrice,
      grossAmount, lineDiscount, invoiceDiscountShare, totalDiscount, netBeforeTaxes,
      exciseDuty, vatBase, vatRate, vatAmount, vatWithholdingRate, vatWithholding,
      communicationsTax, accommodationTax, lineNetTotal
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
    currency: input.currency, exchangeRate, grossTotal, totalLineDiscount, totalInvoiceDiscount,
    totalDiscount, netSubtotal, totalExciseDuty, totalVat, totalCommunicationsTax,
    totalAccommodationTax, totalVatWithholding, withholdingAmount, netTotal, netTotalInTrl,
    lines: calculatedLines
  };
}

console.log('Running Node.js Financial Engine Golden Test Suite...');
const gtv1 = calculateDocumentTotals({
  currency: 'TRL', exchangeRate: 1,
  lines: [
    { description: 'Bulut Sunucu Kurulumu', quantity: 5, unitPrice: 1250, vatRate: 20 },
    { description: 'Bakım Hizmeti', quantity: 2, unitPrice: 750, vatRate: 20 }
  ]
});
assert.equal(gtv1.grossTotal, 7750.00);
assert.equal(gtv1.totalVat, 1550.00);
assert.equal(gtv1.netTotal, 9300.00);

const gtv2 = calculateDocumentTotals({
  currency: 'TRL', exchangeRate: 1,
  invoiceDiscountType: 'amount', invoiceDiscountValue: 120.00,
  lines: [
    { description: 'Lisans Paketi', quantity: 10, unitPrice: 100, discountType: 'percentage', discountValue: 10, vatRate: 20 },
    { description: 'Eğitim Paketi', quantity: 1, unitPrice: 300, vatRate: 10 }
  ]
});
assert.equal(gtv2.totalDiscount, 220.00);
assert.equal(gtv2.totalVat, 189.00);
assert.equal(gtv2.netTotal, 1269.00);

const gtv3 = calculateDocumentTotals({
  currency: 'TRL', exchangeRate: 1,
  lines: [{ description: 'Güvenlik Hizmeti', quantity: 1, unitPrice: 50000, vatRate: 20, vatWithholdingRate: 90 }]
});
assert.equal(gtv3.totalVatWithholding, 9000.00);
assert.equal(gtv3.netTotal, 51000.00);

const gtv4 = calculateDocumentTotals({
  currency: 'TRL', exchangeRate: 1, withholdingRate: 20,
  lines: [{ description: 'SMM', quantity: 1, unitPrice: 25000, vatRate: 20, vatWithholdingRate: 50 }]
});
assert.equal(gtv4.withholdingAmount, 5000.00);
assert.equal(gtv4.netTotal, 22500.00);

const gtv5 = calculateDocumentTotals({
  currency: 'USD', exchangeRate: 34.25,
  lines: [{ description: 'SaaS', quantity: 1, unitPrice: 1000, vatRate: 20 }]
});
assert.equal(gtv5.netTotal, 1200.00);
assert.equal(gtv5.netTotalInTrl, 41100.00);

const gtv6 = calculateDocumentTotals({
  currency: 'TRL', exchangeRate: 1,
  lines: [{ description: 'Konaklama', quantity: 3, unitPrice: 4000, vatRate: 10, accommodationTaxRate: 2 }]
});
assert.equal(gtv6.totalAccommodationTax, 240.00);
assert.equal(gtv6.netTotal, 13440.00);

const gtvResidual = calculateDocumentTotals({
  currency: 'TRL', exchangeRate: 1,
  invoiceDiscountType: 'amount', invoiceDiscountValue: 10.00,
  lines: [
    { description: 'L1', quantity: 1, unitPrice: 100, vatRate: 20 },
    { description: 'L2', quantity: 1, unitPrice: 100, vatRate: 20 },
    { description: 'L3', quantity: 1, unitPrice: 100, vatRate: 20 }
  ]
});
assert.equal(gtvResidual.lines[0].invoiceDiscountShare, 3.33);
assert.equal(gtvResidual.lines[1].invoiceDiscountShare, 3.33);
assert.equal(gtvResidual.lines[2].invoiceDiscountShare, 3.34);
console.log('All Node.js Financial Engine Golden Tests PASSED (7/7).');
