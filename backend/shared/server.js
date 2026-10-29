import http from 'node:http';
import { readFile } from 'node:fs/promises';
import { fileURLToPath } from 'node:url';
import { resolve } from 'node:path';
import { SharedStore } from './store.js';
import { doctors, departments } from '../src/repositories/catalog_repository.js';
import { HttpError } from '../src/utils/http.js';

async function bodyOf(req) {
  let size = 0;
  const chunks = [];
  for await (const chunk of req) {
    size += chunk.length;
    if (size > 32768) throw new HttpError(413, 'Nội dung yêu cầu quá lớn.');
    chunks.push(chunk);
  }
  try {
    const body = JSON.parse(Buffer.concat(chunks).toString() || '{}');
    if (!body || typeof body !== 'object' || Array.isArray(body)) throw new Error();
    return body;
  }
  catch { throw new HttpError(400, 'Nội dung JSON không hợp lệ.'); }
}

export async function createSharedServer({dbPath, demo = false, origins = []}) {
  const store = new SharedStore(dbPath);
  if (demo) await store.seedDemo();
  const attempts = new Map();
  const cleanup = setInterval(() => {
    for (const [key, value] of attempts) if (value.until < Date.now()) attempts.delete(key);
  }, 60000).unref();
  const page = await readFile(new URL('./doctor.html', import.meta.url));
  const server = http.createServer(async (req, res) => {
    res.setHeader('Cache-Control', 'no-store');
    res.setHeader('X-Content-Type-Options', 'nosniff');
    res.setHeader('Referrer-Policy', 'no-referrer');
    res.setHeader('X-Frame-Options', 'DENY');
    const send = (status, data) => {
      res.writeHead(status, {'content-type':'application/json; charset=utf-8'});
      res.end(JSON.stringify(data));
    };
    try {
      const url = new URL(req.url, 'http://localhost');
      const path = url.pathname;
      const origin = req.headers.origin;
      const sameOrigin = origin && (() => {
        try { return new URL(origin).host === req.headers.host; } catch { return false; }
      })();
      if (origin && !sameOrigin && !origins.includes(origin)) throw new HttpError(403, 'Nguồn truy cập chưa được cho phép.');
      if (origin) {
        res.setHeader('Access-Control-Allow-Origin', origin);
        res.setHeader('Vary', 'Origin');
        res.setHeader('Access-Control-Allow-Methods', 'GET,POST,PATCH,OPTIONS');
        res.setHeader('Access-Control-Allow-Headers', 'Content-Type,Authorization,Idempotency-Key');
      }
      if (req.method === 'OPTIONS') { res.writeHead(204); res.end(); return; }
      if (req.method === 'GET' && ['/', '/doctor', '/doctor/'].includes(path)) {
        res.writeHead(200, {'content-type':'text/html; charset=utf-8',
          'Content-Security-Policy':"default-src 'self'; script-src 'unsafe-inline'; style-src 'unsafe-inline'; connect-src 'self'; frame-ancestors 'none'"});
        res.end(page); return;
      }
      if (req.method === 'GET' && path === '/health') return send(200, {ok:true, mode:'shared', demo});
      if (req.method === 'POST' && ['/auth/login', '/auth/register'].includes(path)) {
        const key = req.socket.remoteAddress;
        let limit = attempts.get(key);
        if (!limit || limit.until < Date.now()) {
          limit = {count:0, until:Date.now()+15*60000}; attempts.set(key, limit);
        }
        if (++limit.count > 20) throw new HttpError(429, 'Quá nhiều lần đăng nhập. Thử lại sau 15 phút.');
        const body = await bodyOf(req);
        if (path.endsWith('register')) return send(201, {user:await store.register(body)});
        return send(200, await store.login(body));
      }
      const user = store.authenticate(req.headers.authorization);
      if (req.method === 'GET' && path === '/auth/me') return send(200, {user});
      if (req.method === 'POST' && path === '/auth/logout') {
        store.logout(req.headers.authorization); return send(200, {ok:true});
      }
      if (req.method === 'GET' && path === '/doctors') return send(200, {items:doctors});
      if (req.method === 'GET' && path === '/departments') return send(200, {items:departments});
      if (req.method === 'GET' && path === '/doctors/me/appointments') {
        store.requireRole(user, 'doctor'); return send(200, {items:store.list(user, url.searchParams.get('date'))});
      }
      const availability = path.match(/^\/doctors\/([^/]+)\/availability$/);
      if (req.method === 'GET' && availability) return send(200, store.availability(availability[1], url.searchParams.get('date')));
      const doctor = path.match(/^\/doctors\/([^/]+)$/);
      if (req.method === 'GET' && doctor) {
        const item = doctors.find((d) => d.id === doctor[1]);
        if (!item) throw new HttpError(404, 'Không tìm thấy bác sĩ.');
        return send(200, item);
      }
      if (path === '/appointments') {
        store.requireRole(user, 'patient');
        if (req.method === 'GET') return send(200, {items:store.list(user)});
        if (req.method === 'POST') return send(201, store.create(user, await bodyOf(req), req.headers['idempotency-key']));
      }
      const appointment = path.match(/^\/appointments\/([^/]+)(?:\/(status|cancel|checkin|journey))?$/);
      if (appointment) {
        if (req.method === 'GET' && !appointment[2]) return send(200, store.get(user, appointment[1]));
        if (['POST','PATCH'].includes(req.method) && appointment[2] === 'checkin') return send(200, store.checkin(user, appointment[1]));
        if (req.method === 'POST' && appointment[2] === 'journey') {
          const body = await bodyOf(req);
          if (body.action === 'simulate_payment' && !demo) throw new HttpError(403, 'Thanh toán mô phỏng chỉ có trong bản demo.');
          return send(200, store.journeyAction(user, appointment[1], body));
        }
        if (req.method === 'PATCH' && ['status','cancel'].includes(appointment[2])) return send(200, store.update(user, appointment[1], await bodyOf(req), appointment[2]));
      }
      throw new HttpError(404, 'Chức năng này chưa được bật trên backend demo đồng bộ lịch.');
    } catch (error) {
      if (!(error instanceof HttpError)) console.error('Shared API error:', error.name);
      if (!res.headersSent) send(error instanceof HttpError ? error.statusCode : 500,
        {message:error instanceof HttpError ? error.message : 'Không thể xử lý yêu cầu.'});
      else res.end();
    }
  });
  server.requestTimeout = 15000;
  server.headersTimeout = 10000;
  server.on('close', () => { clearInterval(cleanup); store.close(); });
  return {server, store};
}

if (process.argv[1] && resolve(process.argv[1]) === fileURLToPath(import.meta.url)) {
  const {server} = await createSharedServer({
    dbPath:process.env.DB_PATH || fileURLToPath(new URL('../data/shared-demo.db', import.meta.url)),
    demo:process.env.DEMO_MODE === '1',
    origins:(process.env.ALLOWED_ORIGINS || 'http://localhost:8080,http://127.0.0.1:8080').split(',').filter(Boolean),
  });
  const port = Number(process.env.PORT || 3000);
  const host = process.env.HOST || '127.0.0.1';
  server.listen(port, host, () => console.log(`Smart Hospital shared API + doctor portal: http://${host}:${port}/doctor`));
  for (const signal of ['SIGTERM','SIGINT']) process.on(signal, () => server.close(() => process.exit(0)));
}
