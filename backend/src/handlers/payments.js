import * as repository from '../repositories/sqlite_payment_repository.js';
import { patientIdFromEvent, requirePatientRole } from '../utils/auth.js';
import { error, handle, json, parseJsonBody } from '../utils/http.js';

export const handler = async (event) =>
  handle(async () => {
    const method = event.requestContext?.http?.method ?? event.httpMethod;
    const path = event.path || '';
    const invoiceId = event.pathParameters?.id;
    const appointmentId = event.pathParameters?.appointmentId;

    // 1. POST /payments/webhook (Nhận Webhook từ Ngân hàng / PayOS / SePay)
    if (method === 'POST' && path.includes('/payments/webhook')) {
      const body = parseJsonBody(event);
      // Support PayOS / SePay / Generic format
      const paymentData = {
        paymentRef: body.paymentRef || body.data?.description || body.description,
        description: body.description || body.data?.description || '',
        amount: body.amount ?? body.data?.amount ?? 0,
        transactionId: body.transactionId || body.data?.reference || body.reference,
        bankName: body.bankName || 'MBBank',
        orderCode: body.orderCode || body.data?.orderCode,
      };

      const result = await repository.processBankWebhook(paymentData);
      return json(result.success ? 200 : 400, result);
    }

    // 2. POST /payments/simulate (Giả lập thanh toán nhanh cho demo / test)
    if (method === 'POST' && path.includes('/payments/simulate')) {
      const body = parseJsonBody(event);
      const targetId = body?.invoiceId || invoiceId;
      if (!targetId) {
        return error(400, 'Thiếu invoiceId để giả lập thanh toán.');
      }
      const result = await repository.simulatePayment(targetId, {
        amount: body?.amount,
        transactionId: body?.transactionId,
      });
      return json(200, result);
    }

    // 3. GET /payments/reconciliation (Báo cáo đối soát doanh thu)
    if (method === 'GET' && path.includes('/payments/reconciliation')) {
      const report = await repository.getReconciliationReport();
      return json(200, report);
    }

    // 4. GET /appointments/:appointmentId/invoice (Lấy hoặc sinh hóa đơn theo lịch hẹn)
    if (method === 'GET' && appointmentId && path.includes('/invoice')) {
      const invoice = await repository.getInvoiceByAppointmentId(appointmentId);
      return invoice ? json(200, invoice) : error(404, 'Không tìm thấy hóa đơn cho lịch hẹn này.');
    }

    // 5. GET /invoices/:id (Lấy chi tiết hóa đơn theo ID)
    if (method === 'GET' && invoiceId) {
      const invoice = await repository.getInvoiceById(invoiceId);
      return invoice ? json(200, invoice) : error(404, 'Không tìm thấy hóa đơn.');
    }

    // 6. GET /invoices (Danh sách hóa đơn)
    if (method === 'GET') {
      const patientId = event.queryStringParameters?.patientId;
      const status = event.queryStringParameters?.status;
      const limit = Number(event.queryStringParameters?.limit || 50);
      const items = await repository.listInvoices({ patientId, status, limit });
      return json(200, { items });
    }

    // 7. POST /invoices (Tạo hóa đơn mới)
    if (method === 'POST') {
      const body = parseJsonBody(event);
      if (!body.appointment_id || !body.patient_id || !body.patient_name) {
        return error(400, 'Thiếu thông tin bắt buộc: appointment_id, patient_id, patient_name.');
      }
      const created = await repository.createInvoice(body);
      return json(201, created);
    }

    return error(405, 'Phương thức không được hỗ trợ.');
  });
