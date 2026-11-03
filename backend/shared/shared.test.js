import test from 'node:test';
import assert from 'node:assert/strict';
import { mkdtempSync, rmSync } from 'node:fs';
import { tmpdir } from 'node:os';
import { join } from 'node:path';
import { once } from 'node:events';
import { createSharedServer } from './server.js';

test('Check-in, doctor/patient journey, prescriptions and receipt persist without granting cross-patient access', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'hospital-journey-test-'));
  const dbPath = join(directory,'journey.db');
  let instance = await createSharedServer({dbPath,demo:true});
  let base;
  async function start() {
    instance.server.listen(0,'127.0.0.1'); await once(instance.server,'listening');
    base=`http://127.0.0.1:${instance.server.address().port}`;
  }
  async function stop() { instance.server.closeAllConnections(); await new Promise(r=>instance.server.close(r)); }
  await start();
  async function api(path,method='GET',token,body) {
    const response=await fetch(base+path,{method,headers:{'content-type':'application/json',...(token?{authorization:'Bearer '+token}:{})},body:body?JSON.stringify(body):undefined});
    return {status:response.status,body:await response.json()};
  }
  async function login(email,password) { const result=await api('/auth/login','POST',null,{email,password});assert.equal(result.status,200);return result.body.token; }
  try {
    const patient=await login('patient.an@hospital.com','Patient@123');
    const doctor=await login('doctor.linh@hospital.com','Doctor@123');
    const wrongDoctor=await login('doctor.duc@hospital.com','Doctor@123');
    await api('/auth/register','POST',null,{email:'other@example.com',name:'Demo khác',password:'Patient@123'});
    const other=await login('other@example.com','Patient@123');
    const date=new Date(Date.now()+7*86400000).toISOString().slice(0,10);
    const availability=await api('/doctors/dr-linh/availability?date='+date,'GET',patient);
    const create=async(index)=>{
      const result=await api('/appointments','POST',patient,{doctorId:'dr-linh',startTime:availability.body.slots[index].startTime,reason:'DEMO lộ trình',appointmentId:'journey-'+index});
      assert.equal(result.status,201); return result.body;
    };
    const first=await create(0), second=await create(1);
    const checkin=(id,token=patient)=>api('/appointments/'+id+'/checkin','POST',token);
    const journey=(action,body={},token=doctor,id=first.id)=>api('/appointments/'+id+'/journey','POST',token,{...body,action});
    assert.equal((await checkin(first.id)).status,409);
    assert.equal((await checkin(first.id,other)).status,404);
    await api('/appointments/'+first.id+'/status','PATCH',doctor,{status:'confirmed'});
    await api('/appointments/'+second.id+'/status','PATCH',doctor,{status:'confirmed'});
    assert.equal((await checkin(first.id,wrongDoctor)).status,404);
    const checked=await checkin(first.id);
    assert.equal(checked.status,200);assert.equal(checked.body.status,'checked_in');
    assert.equal(checked.body.queueNumber,1);assert.equal(checked.body.roomNumber,'Phòng 204 - Tầng 2');
    const retried=await checkin(first.id);assert.equal(retried.body.queueNumber,1);
    assert.equal((await checkin(second.id)).body.queueNumber,2);
    assert.equal((await journey('call',{},patient)).status,403);
    assert.equal((await journey('call',{},wrongDoctor)).status,404);
    assert.equal((await journey('prescribe',{diagnosis:'DEMO',prescription:'Thuốc DEMO'})).status,409);
    assert.equal((await journey('call')).body.journey.stage,'consulting');
    assert.equal((await journey('order_lab',{labOrder:'Chỉ định mẫu DEMO'})).body.journey.stage,'lab_ordered');
    assert.equal((await journey('prescribe',{diagnosis:'DEMO',prescription:'Thuốc DEMO'})).status,409);
    assert.equal((await journey('review_lab',{labResultNote:'DEMO'})).status,409);
    assert.equal((await journey('report_lab',{},patient)).body.journey.stage,'lab_reported');
    assert.equal((await journey('review_lab',{labResultNote:'Đã kiểm tra kết quả mẫu DEMO'})).body.journey.stage,'lab_completed');
    assert.equal((await journey('prescribe',{diagnosis:'DEMO',prescription:''})).status,400);
    assert.equal((await journey('prescribe',{diagnosis:'DEMO',prescription:'Thuốc mẫu DEMO'},patient)).status,403);
    const prescription=await journey('prescribe',{diagnosis:'Kết luận mẫu DEMO',prescription:'Đơn thuốc mẫu DEMO, không dùng điều trị',note:'Lời dặn mẫu DEMO'});
    assert.equal(prescription.status,200);assert.equal(prescription.body.status,'completed');
    const read=await api('/appointments/'+first.id,'GET',patient);
    assert.equal(read.body.prescription,'Đơn thuốc mẫu DEMO, không dùng điều trị');
    assert.equal(read.body.journey.stage,'prescribed');
    assert.equal(read.body.journey.medicinesReceivedAt,undefined);
    assert.equal((await journey('receive_medicines',{},patient)).status,409);
    assert.equal((await journey('simulate_payment',{},patient)).status,200);
    assert.equal((await journey('receive_medicines',{},patient)).body.journey.stage,'finished');
    const received=(await api('/appointments/'+first.id,'GET',doctor)).body.journey.medicinesReceivedAt;
    assert.ok(received);
    assert.equal((await journey('receive_medicines',{},patient)).body.journey.medicinesReceivedAt,received);
    // No-lab visit: doctor can prescribe immediately after calling the patient.
    await journey('call',{},doctor,second.id);
    assert.equal((await journey('prescribe',{diagnosis:'DEMO không CLS',prescription:'Đơn thuốc mẫu DEMO'},doctor,second.id)).status,200);
    const cancelled=await create(2);
    await api('/appointments/'+cancelled.id+'/status','PATCH',doctor,{status:'confirmed'});
    await checkin(cancelled.id);
    await api('/appointments/'+cancelled.id+'/status','PATCH',doctor,{status:'cancelled'});
    assert.equal((await checkin(cancelled.id)).status,409);
    await stop();instance=await createSharedServer({dbPath,demo:true});await start();
    const persisted=await api('/appointments/'+first.id,'GET',patient);
    assert.equal(persisted.body.journey.stage,'finished');
    assert.equal(persisted.body.journey.labResultNote,'Đã kiểm tra kết quả mẫu DEMO');
    assert.equal(persisted.body.journey.medicinesReceivedAt,received);
    assert.equal((await checkin(first.id)).body.queueNumber,1);
  } finally {await stop();rmSync(directory,{recursive:true,force:true});}
});

test('Phone booking → correct doctor → confirmation → restart persistence, with role isolation', async () => {
  const directory = mkdtempSync(join(tmpdir(), 'hospital-shared-test-'));
  const dbPath = join(directory, 'test.db');
  let server;
  async function start() {
    ({server} = await createSharedServer({dbPath, demo:true, origins:['http://localhost:8080']}));
    server.listen(0, '127.0.0.1');
    await once(server, 'listening');
    return `http://127.0.0.1:${server.address().port}`;
  }
  async function stop() { server.closeAllConnections(); await new Promise((r) => server.close(r)); }
  let base = await start();
  async function api(path, {method='GET', token, body, headers={}}={}) {
    const res = await fetch(base+path, {method, headers:{'content-type':'application/json',
      ...(token ? {authorization:'Bearer '+token} : {}), ...headers}, body:body ? JSON.stringify(body) : undefined});
    return {status:res.status, body:await res.json()};
  }
  async function login(email, password) {
    const result = await api('/auth/login', {method:'POST', body:{email,password}});
    assert.equal(result.status, 200, JSON.stringify(result.body)); return result.body;
  }
  try {
    assert.equal((await api('/appointments')).status, 401);
    assert.equal((await api('/appointments', {headers:{authorization:'Bearer doctor-dr-linh','x-role':'doctor'}})).status, 401);
    assert.equal((await api('/health', {headers:{origin:'https://untrusted.example'}})).status, 403);
    const page = await fetch(base+'/doctor'); assert.equal(page.status, 200); assert.match(await page.text(), /Tiếp nhận/);
    const patient = await login('patient.an@hospital.com','Patient@123');
    const doctor = await login('doctor.linh@hospital.com','Doctor@123');
    const otherDoctor = await login('doctor.duc@hospital.com','Doctor@123');
    assert.equal((await api('/auth/login',{method:'POST',body:{email:'doctor.linh@hospital.com',password:'wrong'}})).status,401);
    const registration = await api('/auth/register', {method:'POST',body:{name:'Bệnh nhân khác',email:'second@example.com',password:'Patient@123',role:'doctor',doctorId:'dr-linh'}});
    assert.equal(registration.status,201); assert.equal(registration.body.user.role,'patient');
    const second = await login('second@example.com','Patient@123');
    const date = new Date(Date.now()+7*86400000).toISOString().slice(0,10);
    const availability = await api('/doctors/dr-linh/availability?date='+date,{token:patient.token});
    assert.equal(availability.status,200);
    const slot = availability.body.slots.find((s)=>s.isAvailable);
    const booking = {doctorId:'dr-linh', startTime:slot.startTime, reason:'Lịch hẹn kiểm thử', patientName:'Tên giả mạo', status:'confirmed', appointmentId:'phone-retry-1'};
    const created = await api('/appointments',{method:'POST',token:patient.token,body:booking});
    assert.equal(created.status,201); assert.equal(created.body.status,'pending');
    assert.equal(created.body.patientName,'Nguyễn Văn An');
    assert.equal(created.body.startTime,slot.startTime);
    const id=created.body.id;
    const retry = await api('/appointments',{method:'POST',token:patient.token,body:booking});
    assert.equal(retry.body.id,id);
    const duplicate = await api('/appointments',{method:'POST',token:second.token,body:booking});
    assert.equal(duplicate.status,409);
    const own = await api('/doctors/me/appointments',{token:doctor.token});
    assert.equal(own.body.items.length,1); assert.equal(own.body.items[0].id,id);
    assert.equal((await api('/doctors/me/appointments',{token:otherDoctor.token})).body.items.length,0);
    assert.equal((await api('/appointments/'+id,{token:second.token})).status,404);
    assert.equal((await api('/doctors/me/appointments',{token:patient.token})).status,403);
    assert.equal((await api('/appointments/'+id+'/status',{method:'PATCH',token:patient.token,body:{status:'confirmed'}})).status,403);
    assert.equal((await api('/appointments/'+id+'/status',{method:'PATCH',token:otherDoctor.token,body:{status:'confirmed'}})).status,404);
    const confirmed = await api('/appointments/'+id+'/status',{method:'PATCH',token:doctor.token,body:{status:'confirmed',note:'Đã tiếp nhận'}});
    assert.equal(confirmed.status,200);
    assert.equal((await api('/appointments/'+id,{token:patient.token})).body.status,'confirmed');
    assert.equal((await api('/appointments/'+id+'/status',{method:'PATCH',token:doctor.token,body:{status:'confirmed'}})).status,409);
    await stop(); base=await start();
    const persisted = await api('/appointments/'+id,{token:patient.token});
    assert.equal(persisted.status,200); assert.equal(persisted.body.status,'confirmed');
    assert.equal(persisted.body.statusNote,'Đã tiếp nhận');
    assert.equal((await api('/appointments/'+id+'/cancel',{method:'PATCH',token:patient.token,body:{reason:'Đổi lịch'}})).status,200);
    const freed = await api('/doctors/dr-linh/availability?date='+date,{token:patient.token});
    assert.equal(freed.body.slots.find(s=>s.startTime===slot.startTime).isAvailable,true);
    const simultaneous = await Promise.all([
      api('/appointments',{method:'POST',token:patient.token,body:{...booking,appointmentId:'new-1'}}),
      api('/appointments',{method:'POST',token:second.token,body:{...booking,appointmentId:'new-2'}}),
    ]);
    assert.deepEqual(simultaneous.map(r=>r.status).sort(),[201,409]);
    await api('/auth/logout',{method:'POST',token:patient.token});
    assert.equal((await api('/auth/me',{token:patient.token})).status,401);
  } finally { await stop(); rmSync(directory,{recursive:true,force:true}); }
});
