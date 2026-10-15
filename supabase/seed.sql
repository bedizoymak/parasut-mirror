-- ============================================================================
-- PARASUT MIRROR — GEMINI EDITION
-- Synthetic Non-Production Seed Fixtures (Zero Production Data)
-- ============================================================================

INSERT INTO companies (id, parasut_company_no, name, tax_office, tax_number, city, district, address, phone, email, base_currency, e_document_active)
VALUES (
    '11111111-1111-4111-8111-111111111111',
    115042,
    'Boğaziçi Dijital Mühendislik ve Teknoloji A.Ş. (Sentetik Test Firması)',
    'Zincirlikuyu',
    '1780945210',
    'İstanbul',
    'Şişli',
    'Esentepe Mah. Büyükdere Cad. No: 185 K: 12',
    '+90 212 345 67 89',
    'finans@bogazicidijital.example.com',
    'TRL',
    TRUE
) ON CONFLICT DO NOTHING;
