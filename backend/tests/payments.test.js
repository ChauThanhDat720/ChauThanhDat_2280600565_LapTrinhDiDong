import test from 'node:test';
import assert from 'node:assert/strict';
import * as repo from '../src/repositories/sqlite_payment_repository.js';
import { handler } from '../src/handlers/payments.js';

test('Hospital Payments: Create Invoice with MB Bank details & VietQR URL', async () => {
  const invoice = await repo.createInvoice({
    appointment_id: 'test-apt-001',
    patient_id: 'test-pt-001',
    patient_name: 'Nguyễn Văn Test',
    doctor_name: 'BS. Trần Thảo Linh',
    department: 'Tim mạch',
    examination_fee: 150000,
    medicine_fee: 50000,
    discount_amount: 0,
  });

  assert.ok(invoice.id);
  assert.equal(invoice.total_amount, 200000);
  assert.equal(invoice.payment_status, 'unpaid');
  assert.equal(invoice.bank_name, 'MBBank');
  assert.equal(invoice.bank_account_number, '0355157761');
  assert.equal(invoice.bank_account_name, 'CHAU THANH DAT');
  assert.ok(invoice.payment_ref.startsWith('VP'));
  assert.ok(invoice.viet_qr_url.includes('970422-0355157761'));
  assert.ok(invoice.viet_qr_url.includes('CHAU%20THANH%20DAT'));
});

test('Hospital Payments: Get or Auto-create Invoice for Appointment', async () => {
  const invoice = await repo.getInvoiceByAppointmentId('apt-auto-102');
  assert.ok(invoice);
  assert.equal(invoice.appointment_id, 'apt-auto-102');
  assert.equal(invoice.examination_fee, 150000);
  assert.equal(invoice.bank_account_number, '0355157761');
});

test('Hospital Payments: Process Bank Webhook with matching Payment Ref', async () => {
  const invoice = await repo.createInvoice({
    appointment_id: 'test-webhook-apt',
    patient_id: 'test-pt-002',
    patient_name: 'Trần Thị B',
    examination_fee: 150000,
    total_amount: 150000,
  });

  // Gửi webhook từ ngân hàng
  const webhookResult = await repo.processBankWebhook({
    paymentRef: invoice.payment_ref,
    amount: 150000,
    transactionId: 'MB-FT2610258888',
    bankName: 'MBBank',
  });

  assert.equal(webhookResult.success, true);
  assert.equal(webhookResult.invoice.payment_status, 'paid');
  assert.equal(webhookResult.invoice.paid_amount, 150000);
  assert.equal(webhookResult.invoice.bank_transaction_id, 'MB-FT2610258888');
  assert.ok(webhookResult.invoice.e_invoice_lookup_code.startsWith('EINV-'));
  assert.ok(webhookResult.invoice.paid_at);
});

test('Hospital Payments: Reject Webhook when Amount is insufficient', async () => {
  const invoice = await repo.createInvoice({
    appointment_id: 'test-underpay-apt',
    patient_id: 'test-pt-003',
    patient_name: 'Lê Văn C',
    examination_fee: 150000,
    total_amount: 150000,
  });

  // Chuyển thiếu tiền (10.000đ thay vì 150.000đ)
  const webhookResult = await repo.processBankWebhook({
    paymentRef: invoice.payment_ref,
    amount: 10000,
    transactionId: 'MB-FT2610259999',
  });

  assert.equal(webhookResult.success, false);
  assert.equal(webhookResult.code, 'UNDERPAID');
});

test('Hospital Payments: Instant Sandbox Simulation', async () => {
  const invoice = await repo.createInvoice({
    appointment_id: 'test-sim-apt',
    patient_id: 'test-pt-004',
    patient_name: 'Phạm Thị D',
    examination_fee: 150000,
    total_amount: 150000,
  });

  const simResult = await repo.simulatePayment(invoice.id);
  assert.equal(simResult.success, true);
  assert.equal(simResult.invoice.payment_status, 'paid');
});

test('Hospital Payments: Daily Reconciliation Report is Balanced', async () => {
  const report = await repo.getReconciliationReport();
  assert.ok(report);
  assert.equal(report.reconciliationStatus, 'BALANCED');
  assert.equal(report.discrepancyVnd, 0);
  assert.ok(report.totalInvoices >= 1);
  assert.ok(report.paidInvoices >= 1);
  assert.ok(report.totalRevenueVnd >= 150000);
  assert.equal(report.bankAccount.bankAccountNumber, '0355157761');
});

test('Hospital Payments: HTTP Handler GET /payments/reconciliation & POST /payments/simulate', async () => {
  // Test HTTP Handler reconciliation
  const recRes = await handler({
    httpMethod: 'GET',
    path: '/payments/reconciliation',
  });
  assert.equal(recRes.statusCode, 200);
  const recData = JSON.parse(recRes.body);
  assert.equal(recData.discrepancyVnd, 0);

  // Create invoice via HTTP
  const createRes = await handler({
    httpMethod: 'POST',
    path: '/invoices',
    body: JSON.stringify({
      appointment_id: 'http-apt-01',
      patient_id: 'test-pt-http',
      patient_name: 'Bệnh nhân HTTP',
      examination_fee: 150000,
    }),
  });
  assert.equal(createRes.statusCode, 201);
  const createdInv = JSON.parse(createRes.body);

  // Simulate via HTTP
  const simRes = await handler({
    httpMethod: 'POST',
    path: '/payments/simulate',
    body: JSON.stringify({ invoiceId: createdInv.id }),
  });
  assert.equal(simRes.statusCode, 200);
  const simData = JSON.parse(simRes.body);
  assert.equal(simData.success, true);
  assert.equal(simData.invoice.payment_status, 'paid');
});
