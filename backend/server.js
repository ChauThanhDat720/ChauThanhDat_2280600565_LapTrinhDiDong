import http from 'node:http';
import { handler as healthHandler } from './src/handlers/health.js';
import { list as departmentsHandler } from './src/handlers/departments.js';
import { handler as doctorsHandler } from './src/handlers/doctors.js';
import { handler as appointmentsHandler } from './src/handlers/appointments.js';
import { handler as patientsHandler } from './src/handlers/patients.js';
import { handler as medicalRecordsHandler } from './src/handlers/medical_records.js';
import { handler as medicinesHandler } from './src/handlers/medicines.js';
import { handler as medicationRemindersHandler } from './src/handlers/medication_reminders.js';
import { handler as healthVitalsHandler } from './src/handlers/health_vitals.js';
import { handler as paymentsHandler } from './src/handlers/payments.js';
import { handler as familyHandler } from './src/handlers/family.js';
import { handler as teleconsultationsHandler } from './src/handlers/teleconsultations.js';
import { handler as vaccinationsHandler } from './src/handlers/vaccinations.js';

const PORT = process.env.PORT || 3000;

const sseClients = new Set();
export const broadcastRealtimeEvent = (category, payload) => {
  const message = 'data: ' + JSON.stringify({ category, payload, timestamp: new Date().toISOString() }) + '

';
  for (const client of sseClients) {
    try { client.write(message); } catch (_) { sseClients.delete(client); }
  }
};

const parseBody = (req) =>
  new Promise((resolve) => {
    let body = '';
    req.on('data', (chunk) => {
      body += chunk;
    });
    req.on('end', () => resolve(body));
  });

const server = http.createServer(async (req, res) => {
  // CORS headers
  res.setHeader('Access-Control-Allow-Origin', '*');
  res.setHeader('Access-Control-Allow-Methods', 'GET, POST, PATCH, PUT, DELETE, OPTIONS');
  res.setHeader('Access-Control-Allow-Headers', 'Content-Type, Authorization, Idempotency-Key');

  if (req.method === 'OPTIONS') {
    res.writeHead(204);
    res.end();
    return;
  }

  const url = new URL(req.url, `http://${req.headers.host}`);
  const pathname = url.pathname;
  const method = req.method;
  const rawBody = await parseBody(req);

  // Parse authorization claims for local dev testing
  const authHeader = req.headers['authorization'] || '';
  const token = authHeader.replace(/^Bearer\s+/i, '');
  const isDoctorRole = req.headers['x-role'] === 'doctor' || token.includes('doctor');
  const sub = token || (isDoctorRole ? 'dr-linh' : 'test-patient-sub-123');
  const role = isDoctorRole ? 'doctors' : 'patients';

  const event = {
    httpMethod: method,
    body: rawBody,
    path: pathname,
    pathParameters: {},
    queryStringParameters: Object.fromEntries(url.searchParams),
    headers: req.headers,
    requestContext: {
      http: { method },
      authorizer: {
        claims: {
          sub,
          doctorId: isDoctorRole ? sub : undefined,
          'cognito:groups': role,
          email: `${sub}@hospital.local`,
        },
      },
    },
  };

  let result;
    try {
    if (pathname === '/api/realtime/stream' && method === 'GET') {
      res.writeHead(200, {
        'Content-Type': 'text/event-stream',
        'Cache-Control': 'no-cache',
        'Connection': 'keep-alive',
        'Access-Control-Allow-Origin': '*',
      });
      res.write('data: ' + JSON.stringify({ category: 'connected', timestamp: new Date().toISOString() }) + '

');
      sseClients.add(res);
      req.on('close', () => sseClients.delete(res));
      return;
    } else if (pathname === '/api/realtime/broadcast' && method === 'POST') {
      let payload = {};
      try { payload = JSON.parse(rawBody || '{}'); } catch (_) {}
      broadcastRealtimeEvent(payload.category || 'system', payload.payload || payload);
      result = { statusCode: 200, body: JSON.stringify({ ok: true, activeClients: sseClients.size }) };
    } else if (pathname === '/health' && method === 'GET') {
      result = await healthHandler(event);
    } else if (pathname === '/departments' && method === 'GET') {
      result = await departmentsHandler(event);
    } else if (pathname === '/doctors/me/appointments') {
      result = await appointmentsHandler(event);
    } else if (pathname.match(/^\/doctors\/([^/]+)\/availability$/)) {
      const match = pathname.match(/^\/doctors\/([^/]+)\/availability$/);
      event.pathParameters = { doctorId: match[1] };
      result = await appointmentsHandler(event);
    } else if (pathname.match(/^\/doctors\/([^/]+)\/queue$/)) {
      const match = pathname.match(/^\/doctors\/([^/]+)\/queue$/);
      event.pathParameters = { doctorId: match[1] };
      result = await appointmentsHandler(event);
    } else if (pathname === '/doctors' || pathname.startsWith('/doctors/')) {
      const match = pathname.match(/^\/doctors\/(.+)$/);
      if (match) {
        event.pathParameters = { id: match[1] };
      }
      result = await doctorsHandler(event);
    } else if (pathname === '/appointments' || pathname.startsWith('/appointments/')) {
      const invoiceMatch = pathname.match(/^\/appointments\/([^/]+)\/invoice$/);
      if (invoiceMatch) {
        event.pathParameters = { appointmentId: invoiceMatch[1] };
        result = await paymentsHandler(event);
      } else {
        const statusMatch = pathname.match(/^\/appointments\/([^/]+)\/status$/);
        const cancelMatch = pathname.match(/^\/appointments\/([^/]+)\/cancel$/);
        const ratingMatch = pathname.match(/^\/appointments\/([^/]+)\/rating$/);
        const recordMatch = pathname.match(/^\/appointments\/([^/]+)\/medical-record$/);
        const checkinMatch = pathname.match(/^\/appointments\/([^/]+)\/checkin$/);
        const intakeMatch = pathname.match(/^\/appointments\/([^/]+)\/intake$/);
        const detailMatch = pathname.match(/^\/appointments\/([^/]+)$/);
        if (statusMatch) {
          event.pathParameters = { id: statusMatch[1], action: 'status' };
        } else if (cancelMatch) {
          event.pathParameters = { id: cancelMatch[1], action: 'cancel' };
        } else if (ratingMatch) {
          event.pathParameters = { id: ratingMatch[1], action: 'rating' };
        } else if (recordMatch) {
          event.pathParameters = { id: recordMatch[1], action: 'medical-record' };
        } else if (checkinMatch) {
          event.pathParameters = { id: checkinMatch[1], action: 'checkin' };
        } else if (intakeMatch) {
          event.pathParameters = { id: intakeMatch[1], action: 'intake' };
        } else if (detailMatch) {
          event.pathParameters = { id: detailMatch[1] };
        }
        result = await appointmentsHandler(event);
        if (method === 'POST' && pathname === '/appointments' && result && (result.statusCode === 201 || result.statusCode === 200)) {
          try {
            const created = JSON.parse(result.body);
            broadcastRealtimeEvent('appointment_created', {
              appointment: created,
              event: {
                type: 'appointmentCreated',
                appointmentId: created.id,
                doctorId: created.doctorId,
                doctorName: created.doctorName,
                patientName: created.patientName,
                queueNumber: created.queueNumber || 1,
                roomNumber: created.roomNumber || ('Phòng khám ' + (created.specialty || '')),
                status: created.status,
                note: 'Lịch khám lúc ' + created.time + ' ngày ' + created.date + ' (Lý do: ' + (created.reason || '') + ')',
                timestamp: new Date().toISOString(),
              },
            });
          } catch (_) {}
        }
      }
    } else if (pathname === '/invoices' || pathname.startsWith('/invoices/')) {
      const match = pathname.match(/^\/invoices\/([^/]+)$/);
      if (match) {
        event.pathParameters = { id: match[1] };
      }
      result = await paymentsHandler(event);
    } else if (pathname.startsWith('/payments/')) {
      result = await paymentsHandler(event);
    } else if (pathname === '/family/members' || pathname.startsWith('/family/members/')) {
      const defaultMatch = pathname.match(/^\/family\/members\/([^/]+)\/default$/);
      const idMatch = pathname.match(/^\/family\/members\/([^/]+)$/);
      if (defaultMatch) {
        event.pathParameters = { id: defaultMatch[1], action: 'default' };
      } else if (idMatch) {
        event.pathParameters = { id: idMatch[1] };
      }
      result = await familyHandler(event);
    } else if (pathname.startsWith('/records/') || pathname.startsWith('/medical-records/')) {
      const viewMatch = pathname.match(/^\/(?:records|medical-records)\/([^/]+)\/view$/);
      const labMatch = pathname.match(/^\/(?:records|medical-records)\/([^/]+)\/lab-results$/);
      const recordMatch = pathname.match(/^\/(?:records|medical-records)\/([^/]+)$/);
      if (labMatch) {
        event.pathParameters = { id: labMatch[1], action: 'lab-results' };
        event.path = `${pathname}`;
      } else if (viewMatch) {
        event.pathParameters = { id: viewMatch[1], action: 'view' };
        event.path = `${pathname}`;
      } else if (recordMatch) {
        event.pathParameters = { id: recordMatch[1] };
      }
      result = await medicalRecordsHandler(event);
    } else if (pathname === '/medicines' || pathname.startsWith('/medicines/')) {
      const catMatch = pathname.match(/^\/medicines\/categories$/);
      const lookupMatch = pathname.match(/^\/medicines\/lookup$/);
      const idMatch = pathname.match(/^\/medicines\/([^/]+)$/);
      if (catMatch) {
        event.path = '/medicines/categories';
      } else if (lookupMatch) {
        event.path = '/medicines/lookup';
      } else if (idMatch) {
        event.pathParameters = { id: idMatch[1] };
      }
      result = await medicinesHandler(event);
    } else if (pathname === '/patients/me') {
      result = await patientsHandler(event);
    } else if (pathname.match(/^\/patients\/([^/]+)\/vitals(\/latest)?$/)) {
      const match = pathname.match(/^\/patients\/([^/]+)\/vitals(\/latest)?$/);
      event.pathParameters = { patientId: match[1] };
      event.path = pathname;
      result = await healthVitalsHandler(event);
    } else if (pathname.startsWith('/vitals/')) {
      const match = pathname.match(/^\/vitals\/([^/]+)$/);
      if (match) {
        event.pathParameters = { id: match[1] };
      }
      result = await healthVitalsHandler(event);
    } else if (pathname === '/medication-reminders' || pathname.startsWith('/medication-reminders/')) {
      const todayMatch = pathname.match(/^\/medication-reminders\/today$/);
      const fromPrescriptionMatch = pathname.match(/^\/medication-reminders\/from-prescription$/);
      const doseMatch = pathname.match(/^\/medication-reminders\/doses\/([^/]+)$/);
      const toggleMatch = pathname.match(/^\/medication-reminders\/([^/]+)\/toggle$/);
      const idMatch = pathname.match(/^\/medication-reminders\/([^/]+)$/);
      if (todayMatch) {
        event.path = '/medication-reminders/today';
      } else if (fromPrescriptionMatch) {
        event.path = '/medication-reminders/from-prescription';
      } else if (doseMatch) {
        event.pathParameters = { id: doseMatch[1], action: 'dose' };
      } else if (toggleMatch) {
        event.pathParameters = { id: toggleMatch[1], action: 'toggle' };
      } else if (idMatch) {
        event.pathParameters = { id: idMatch[1] };
      }
      result = await medicationRemindersHandler(event);
    } else if (pathname === '/teleconsultations' || pathname.startsWith('/teleconsultations/')) {
      const apptMatch = pathname.match(/^\/teleconsultations\/appointment\/([^/]+)$/);
      const docMatch = pathname.match(/^\/teleconsultations\/doctor\/([^/]+)$/);
      const patMatch = pathname.match(/^\/teleconsultations\/patient\/([^/]+)$/);
      const msgMatch = pathname.match(/^\/teleconsultations\/sessions\/([^/]+)\/messages$/);
      const closeMatch = pathname.match(/^\/teleconsultations\/sessions\/([^/]+)\/close$/);
      const readMatch = pathname.match(/^\/teleconsultations\/sessions\/([^/]+)\/read$/);
      const sessionMatch = pathname.match(/^\/teleconsultations\/sessions\/([^/]+)$/);

      if (apptMatch) {
        event.pathParameters = { appointmentId: apptMatch[1] };
      } else if (docMatch) {
        event.pathParameters = { doctorId: docMatch[1] };
      } else if (patMatch) {
        event.pathParameters = { patientId: patMatch[1] };
      } else if (msgMatch) {
        event.pathParameters = { id: msgMatch[1], action: 'messages' };
      } else if (closeMatch) {
        event.pathParameters = { id: closeMatch[1], action: 'close' };
      } else if (readMatch) {
        event.pathParameters = { id: readMatch[1], action: 'read' };
      } else if (sessionMatch) {
        event.pathParameters = { id: sessionMatch[1] };
      }
      result = await teleconsultationsHandler(event);
    } else if (pathname === '/vaccinations' || pathname.startsWith('/vaccinations/')) {
      const protocolsMatch = pathname.match(/^\/vaccinations\/protocols$/);
      const upcomingMatch = pathname.match(/^\/vaccinations\/upcoming$/);
      const passportMatch = pathname.match(/^\/vaccinations\/passport\/([^/]+)$/);
      const idMatch = pathname.match(/^\/vaccinations\/([^/]+)$/);
      if (protocolsMatch) {
        event.path = '/vaccinations/protocols';
      } else if (upcomingMatch) {
        event.path = '/vaccinations/upcoming';
      } else if (passportMatch) {
        event.pathParameters = { code: passportMatch[1] };
        event.path = pathname;
      } else if (idMatch) {
        event.pathParameters = { id: idMatch[1] };
      }
      result = await vaccinationsHandler(event);
    } else {
      result = {
        statusCode: 404,
        headers: { 'content-type': 'application/json' },
        body: JSON.stringify({ message: `Không tìm thấy đường dẫn ${pathname}` }),
      };
    }
  } catch (err) {
    console.error('Lỗi xử lý request:', err);
    result = {
      statusCode: 500,
      headers: { 'content-type': 'application/json' },
      body: JSON.stringify({ message: 'Lỗi máy chủ nội bộ' }),
    };
  }

  res.writeHead(result.statusCode, result.headers || { 'content-type': 'application/json' });
  res.end(result.body);
});

server.listen(PORT, '0.0.0.0', () => {
  console.log(`======================================================`);
  console.log(` Smart Hospital Local Backend đang chạy tại:`);
  console.log(` - Local:            http://localhost:${PORT}`);
  console.log(` - Android Emulator: http://10.0.2.2:${PORT}`);
  console.log(` - Health check:     http://localhost:${PORT}/health`);
  console.log(`======================================================`);
});
