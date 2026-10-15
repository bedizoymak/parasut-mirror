import React, { useState } from 'react';
import { calculateDocumentTotals, roundCurrency } from './domain/financialEngine';

export default function App() {
  const [activeTab, setActiveTab] = useState<string>('dashboard');
  const demoCalc = calculateDocumentTotals({
    currency: 'TRL',
    exchangeRate: 1,
    lines: [{ description: 'Kurumsal ERP Paketi', quantity: 1, unitPrice: 75000, vatRate: 20 }],
  });

  return (
    <div style={{ display: 'flex', minHeight: '100vh', fontFamily: 'Inter, system-ui, sans-serif' }}>
      <aside style={{ width: 250, background: '#1b2432', color: '#f8fafc', padding: 20 }}>
        <h2>PARAŞÜT MIRROR</h2>
        <p style={{ fontSize: 12, color: '#94a3b8' }}>Gemini Edition — Kurumsal ERP</p>
        <nav style={{ display: 'flex', flexDirection: 'column', gap: 8, marginTop: 20 }}>
          {['dashboard', 'offers', 'invoices', 'expenses', 'contacts', 'cash', 'checks', 'inventory', 'reports'].map((key) => (
            <button
              key={key}
              onClick={() => setActiveTab(key)}
              style={{
                textAlign: 'left',
                padding: '10px 12px',
                borderRadius: 6,
                border: 'none',
                background: activeTab === key ? '#e11d48' : 'transparent',
                color: '#fff',
                cursor: 'pointer',
              }}
            >
              {key.toUpperCase()}
            </button>
          ))}
        </nav>
      </aside>
      <main style={{ flex: 1, padding: 28, background: '#f4f6f9' }}>
        <h1>Aktif Modül: {activeTab.toUpperCase()}</h1>
        <p>Örnek Fatura Net Toplam: {roundCurrency(demoCalc.netTotal).toLocaleString('tr-TR')} TL</p>
      </main>
    </div>
  );
}
