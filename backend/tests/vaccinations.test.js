import test from 'node:test';
import assert from 'node:assert/strict';
import { handler } from '../src/handlers/vaccinations.js';
import * as repository from '../src/repositories/sqlite_vaccination_repository.js';

test('Digital Immunization & Vaccine Passport: Full Lifecycle Suite', async (t) => {
  await t.test('1. List vaccinations and retrieve seeded records', async () => {
    const event = {
      httpMethod: 'GET',
      path: '/vaccinations',
      queryStringParameters: {
        patientId: 'test-patient-sub-123',
      },
    };

    const res = await handler(event);
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.ok(body.vaccinations.length >= 4);
    assert.ok(body.vaccinations.some((v) => v.vaccineName.includes('Gardasil')));
    assert.ok(body.vaccinations.some((v) => v.vaccineName.includes('Engerix B')));
  });

  await t.test('2. Filter vaccinations by family member', async () => {
    const childEvent = {
      httpMethod: 'GET',
      path: '/vaccinations',
      queryStringParameters: {
        patientId: 'test-patient-sub-123',
        familyMemberId: 'fam-child',
      },
    };

    const res = await handler(childEvent);
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.equal(body.vaccinations.length, 1);
    assert.equal(body.vaccinations[0].patientName, 'Nguyễn Minh Khang');
    assert.ok(body.vaccinations[0].vaccineName.includes('6 trong 1'));
  });

  await t.test('3. Retrieve upcoming vaccine doses needing reminders', async () => {
    const event = {
      httpMethod: 'GET',
      path: '/vaccinations/upcoming',
      pathParameters: { id: 'upcoming' },
      queryStringParameters: {
        patientId: 'test-patient-sub-123',
      },
    };

    const res = await handler(event);
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.ok(Array.isArray(body.upcoming));
    // Seed has Gardasil dose 2 scheduled in ~7 days
    assert.ok(body.upcoming.length >= 1);
    const upcomingHpv = body.upcoming.find((v) => v.vaccineName.includes('Gardasil'));
    assert.ok(upcomingHpv);
    assert.ok(upcomingHpv.nextDoseDate);
  });

  await t.test('4. Fetch age-based official immunization protocols', async () => {
    const event = {
      httpMethod: 'GET',
      path: '/vaccinations/protocols',
      pathParameters: { id: 'protocols' },
    };

    const res = await handler(event);
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.ok(Array.isArray(body.protocols));
    assert.equal(body.protocols.length, 4);
    assert.ok(body.protocols.some((p) => p.ageGroup.includes('0 - 12')));
    assert.ok(body.protocols.some((p) => p.ageGroup.includes('13 - 49')));
  });

  await t.test('5. Verify digital vaccine passport certificate by certificate_code', async () => {
    const event = {
      httpMethod: 'GET',
      path: '/vaccinations/passport/VAC-2026-VN-98231',
      pathParameters: { code: 'VAC-2026-VN-98231' },
    };

    const res = await handler(event);
    assert.equal(res.statusCode, 200);
    const body = JSON.parse(res.body);
    assert.equal(body.valid, true);
    assert.equal(body.certificate.certificateCode, 'VAC-2026-VN-98231');
    assert.equal(body.certificate.patientName, 'Nguyễn Văn An');
    assert.ok(body.issuedBy.includes('Smart Hospital'));
  });

  await t.test('6. Create new vaccination dose record', async () => {
    const newVac = {
      patientId: 'test-patient-sub-123',
      familyMemberId: 'fam-self',
      patientName: 'Nguyễn Văn An',
      vaccineName: 'Prevenar 13 (Mỹ)',
      targetDisease: 'Phế cầu khuẩn & Viêm phổi',
      doseNumber: 1,
      totalDoses: 1,
      batchNumber: 'PFIZER-US9901',
      manufacturer: 'Pfizer (Mỹ)',
      administeredDate: '2026-10-26',
      facilityName: 'Bệnh viện Đa khoa Quốc tế Smart Hospital',
      doctorName: 'BS. Trần Thảo Linh',
      nurseName: 'ĐD. Lê Thị Hồng',
      reactionStatus: 'Bình thường, không sốt',
    };

    const event = {
      httpMethod: 'POST',
      path: '/vaccinations',
      body: JSON.stringify(newVac),
    };

    const res = await handler(event);
    assert.equal(res.statusCode, 201);
    const body = JSON.parse(res.body);
    assert.ok(body.id);
    assert.equal(body.vaccineName, 'Prevenar 13 (Mỹ)');
    assert.ok(body.certificateCode.startsWith('VAC-'));

    // Verify it is now in the list
    const retrieved = await repository.getVaccinationById(body.id);
    assert.equal(retrieved.id, body.id);
  });
});
