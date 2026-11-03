import test from 'node:test';
import assert from 'node:assert/strict';
import * as repo from '../src/repositories/sqlite_family_repository.js';
import { handler } from '../src/handlers/family.js';

test('Family Members: List members and auto-seed default profiles', async () => {
  const members = await repo.listMembers('pt-family-test');
  assert.ok(Array.isArray(members));
  assert.ok(members.length >= 3);

  const self = members.find((m) => m.relationship === 'self');
  const mother = members.find((m) => m.relationship === 'mother');
  const child = members.find((m) => m.relationship === 'child');

  assert.ok(self, 'Phải có hồ sơ chính của Bản thân');
  assert.equal(self.is_default, 1);
  assert.ok(mother, 'Phải có hồ sơ Mẹ');
  assert.ok(mother.bhyt_code.startsWith('GD479'));
  assert.ok(child, 'Phải có hồ sơ Con trai');
});

test('Family Members: Create new family member (Father)', async () => {
  const created = await repo.createMember({
    primary_patient_id: 'pt-family-test',
    full_name: 'Nguyễn Văn Ba',
    relationship: 'father',
    date_of_birth: '1962-02-20',
    gender: 'Nam',
    phone: '0933112233',
    bhyt_code: 'HT2791122334455',
    blood_type: 'B+',
    medical_history: 'Tiền sử tai biến nhẹ năm 2021',
  });

  assert.ok(created.id);
  assert.equal(created.full_name, 'Nguyễn Văn Ba');
  assert.equal(created.relationship, 'father');
  assert.equal(created.blood_type, 'B+');
  assert.equal(created.bhyt_code, 'HT2791122334455');
});

test('Family Members: Update member information', async () => {
  const members = await repo.listMembers('pt-family-test');
  const child = members.find((m) => m.relationship === 'child');

  const updated = await repo.updateMember(child.id, {
    medical_history: 'Đã hết dị ứng thuốc, sức khỏe tốt',
  });

  assert.equal(updated.medical_history, 'Đã hết dị ứng thuốc, sức khỏe tốt');
});

test('Family Members: Set default active member', async () => {
  const members = await repo.listMembers('pt-family-test');
  const mother = members.find((m) => m.relationship === 'mother');

  const updated = await repo.setDefaultMember('pt-family-test', mother.id);
  assert.equal(updated.is_default, 1);

  // Check that other members are no longer default
  const refreshedList = await repo.listMembers('pt-family-test');
  const otherMember = refreshedList.find((m) => m.id !== mother.id);
  assert.equal(otherMember.is_default, 0);
});

test('Family Members: Prevent deleting self profile but allow deleting others', async () => {
  const members = await repo.listMembers('pt-family-test');
  const self = members.find((m) => m.relationship === 'self');

  // Attempting to delete self should reject
  await assert.rejects(async () => {
    await repo.deleteMember(self.id);
  }, /Không thể xóa/);

  // Creating a temporary member to delete
  const temp = await repo.createMember({
    primary_patient_id: 'pt-family-test',
    full_name: 'Người thân tạm',
    relationship: 'other',
  });

  const deleteResult = await repo.deleteMember(temp.id);
  assert.equal(deleteResult, true);
});

test('Family Members: HTTP Handler API endpoints', async () => {
  // Test GET /family/members
  const listRes = await handler({
    httpMethod: 'GET',
    path: '/family/members',
    requestContext: {
      authorizer: { claims: { sub: 'http-family-pt', 'cognito:groups': 'patients' } },
    },
  });
  assert.equal(listRes.statusCode, 200);
  const listData = JSON.parse(listRes.body);
  assert.ok(listData.items.length >= 3);

  // Test POST /family/members
  const createRes = await handler({
    httpMethod: 'POST',
    path: '/family/members',
    body: JSON.stringify({
      full_name: 'Lê Thị Thu (Vợ)',
      relationship: 'spouse',
      date_of_birth: '1994-11-25',
      gender: 'Nữ',
      bhyt_code: 'DN4798889991122',
    }),
    requestContext: {
      authorizer: { claims: { sub: 'http-family-pt', 'cognito:groups': 'patients' } },
    },
  });
  assert.equal(createRes.statusCode, 201);
  const createdMember = JSON.parse(createRes.body);
  assert.equal(createdMember.full_name, 'Lê Thị Thu (Vợ)');
  assert.equal(createdMember.relationship, 'spouse');
});
