export type CurrencyCode = 'TRL' | 'USD' | 'EUR' | 'GBP';
export type DiscountType = 'percentage' | 'amount';
export type InvoiceItemType = 'invoice' | 'estimate' | 'refund' | 'export';
export type PaymentStatus = 'unpaid' | 'overdue' | 'partially_paid' | 'paid' | 'cancelled';
export type ExpenseType = 'purchase_bill_basic' | 'purchase_bill_detailed' | 'salary' | 'tax' | 'bank_fee' | 'refund';
export type EDocumentType = 'none' | 'e_invoice' | 'e_archive' | 'e_smm';
export type EDocumentStatus = 'not_sent' | 'pending' | 'running' | 'done' | 'error';

export interface InvoiceLineInput {
  id?: string;
  productId?: string;
  description: string;
  quantity: number;
  unitPrice: number;
  discountType?: DiscountType;
  discountValue?: number;
  exciseDutyType?: DiscountType;
  exciseDutyValue?: number;
  vatRate: number;
  vatWithholdingRate?: number;
  communicationsTaxRate?: number;
  accommodationTaxRate?: number;
  accommodationTaxExempt?: boolean;
}

export interface CalculatedLineResult {
  detailNo: number;
  description: string;
  quantity: number;
  unitPrice: number;
  grossAmount: number;
  lineDiscount: number;
  invoiceDiscountShare: number;
  totalDiscount: number;
  netBeforeTaxes: number;
  exciseDuty: number;
  vatBase: number;
  vatRate: number;
  vatAmount: number;
  vatWithholdingRate: number;
  vatWithholding: number;
  communicationsTax: number;
  accommodationTax: number;
  lineNetTotal: number;
}

export interface DocumentCalculationInput {
  currency: CurrencyCode;
  exchangeRate: number;
  withholdingRate?: number;
  invoiceDiscountType?: DiscountType;
  invoiceDiscountValue?: number;
  lines: InvoiceLineInput[];
}

export interface DocumentCalculationResult {
  currency: CurrencyCode;
  exchangeRate: number;
  grossTotal: number;
  totalLineDiscount: number;
  totalInvoiceDiscount: number;
  totalDiscount: number;
  netSubtotal: number;
  totalExciseDuty: number;
  totalVat: number;
  totalCommunicationsTax: number;
  totalAccommodationTax: number;
  totalVatWithholding: number;
  withholdingAmount: number;
  netTotal: number;
  netTotalInTrl: number;
  lines: CalculatedLineResult[];
}
