import test from 'node:test';
import assert from 'node:assert/strict';
import {
  initAuthSchema,
  register,
  login,
  getMe,
  logout,
  getUserByToken,
} from '../src/handlers/auth.js';

test('Auth: Full Lifecycle Test Suite', async (t) => {
  await initAuthSchema();

  await t.test('1. Login with seeded demo doctor', async () => {
    const res = await login({ email: 'doctor.linh@hospital.com', password: 'Doctor@123' });
    assert.equal(res.statusCode, 200);
    const data = JSON.parse(res.body);
    assert.ok(data.token);
    assert.equal(data.user.email, 'doctor.linh@hospital.com');
    assert.equal(data.user.role, 'doctor');
    assert.equal(data.user.doctorId, 'dr-linh');

    // Test me
    const meRes = await getMe(data.token);
    assert.equal(meRes.statusCode, 200);
    const meData = JSON.parse(meRes.body);
    assert.equal(meData.user.fullName, data.user.fullName);
  });

  await t.test('2. Reject login with wrong password', async () => {
    const res = await login({ email: 'doctor.linh@hospital.com', password: 'WrongPassword' });
    assert.equal(res.statusCode, 401);
  });

  await t.test('3. Register new patient account and login', async () => {
    const testEmail = `patient_${Date.now()}@test.com`;
    const regRes = await register({
      name: 'Bệnh Nhân Mới',
      email: testEmail,
      password: 'MyPassword123',
      phone: '0987654321',
    });
    assert.equal(regRes.statusCode, 201);
    const regData = JSON.parse(regRes.body);
    assert.equal(regData.user.fullName, 'Bệnh Nhân Mới');
    assert.equal(regData.user.role, 'patient');

    // Login with new user
    const loginRes = await login({ email: testEmail, password: 'MyPassword123' });
    assert.equal(loginRes.statusCode, 200);
    const loginData = JSON.parse(loginRes.body);

    // Logout
    const logoutRes = await logout(loginData.token);
    assert.equal(logoutRes.statusCode, 200);

    // After logout, token is invalid
    const meAfter = await getMe(loginData.token);
    assert.equal(meAfter.statusCode, 401);
  });
});
