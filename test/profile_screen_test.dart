import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/core/network/api_client.dart';
import 'package:smart_hospital/core/network/api_config.dart';
import 'package:smart_hospital/features/profile/data/patient_repository.dart';
import 'package:smart_hospital/features/profile/domain/patient_profile.dart';
import 'package:smart_hospital/features/profile/presentation/profile_screen.dart';

final patient = PatientProfile(
  patientId: 'BN-001',
  cognitoUserId: 'user',
  name: 'Nguyễn An',
  email: 'an@example.com',
  phone: '0900000000',
  dateOfBirth: '2000-01-01',
  gender: 'Nam',
  address: 'Hà Nội',
  emergencyContactName: 'Nguyễn Bình',
  emergencyContactPhone: '0911111111',
);

class FakeRepository implements PatientRepository {
  FakeRepository(this.value, {this.error});
  PatientProfile? value;
  Object? error;
  int gets = 0, updates = 0;
  Completer<PatientProfile?>? pending;
  @override
  Future<PatientProfile?> getMyProfile() {
    gets++;
    if (pending != null) return pending!.future;
    if (error != null) return Future.error(error!);
    return Future.value(value);
  }

  @override
  Future<PatientProfile> createMyProfile(PatientProfile p) async {
    value = p;
    return p;
  }

  @override
  Future<PatientProfile> updateMyProfile(PatientProfile p) async {
    updates++;
    value = p;
    return p;
  }
}

/// A remote repository double: it retains the production repository type while
/// overriding every operation that would otherwise make an HTTP request.
class FakeRemotePatientRepository extends RemotePatientRepository {
  FakeRemotePatientRepository(this.value)
    : super(ApiClient(config: ApiConfig(baseUrl: 'https://example.test')));

  PatientProfile? value;

  @override
  Future<PatientProfile?> getMyProfile() => Future.value(value);

  @override
  Future<PatientProfile> createMyProfile(PatientProfile profile) async {
    value = profile;
    return profile;
  }

  @override
  Future<PatientProfile> updateMyProfile(PatientProfile profile) async {
    value = profile;
    return profile;
  }
}

Widget app(PatientRepository r) =>
    MaterialApp(home: ProfileScreen(repository: r));
void main() {
  testWidgets('loading state', (t) async {
    final r = FakeRepository(null)..pending = Completer();
    await t.pumpWidget(app(r));
    expect(find.byType(CircularProgressIndicator), findsOneWidget);
    expect(find.text('Đang tải hồ sơ bệnh nhân...'), findsOneWidget);
  });
  testWidgets('success and emergency contact', (t) async {
    final r = FakeRepository(patient);
    await t.pumpWidget(app(r));
    await t.pump();
    expect(find.text('Nguyễn An'), findsOneWidget);
    await t.scrollUntilVisible(find.text('Nguyễn Bình'), 100);
    expect(find.text('Nguyễn Bình'), findsOneWidget);
    await t.scrollUntilVisible(find.text('0911111111'), 100);
    expect(find.text('0911111111'), findsOneWidget);
  });
  testWidgets('empty state', (t) async {
    final r = FakeRepository(null);
    await t.pumpWidget(app(r));
    await t.pump();
    expect(find.text('Bạn chưa hoàn thiện hồ sơ bệnh nhân.'), findsOneWidget);
  });
  testWidgets('error and retry', (t) async {
    final r = FakeRepository(null, error: StateError('x'));
    await t.pumpWidget(app(r));
    await t.pump();
    expect(find.text('Không thể tải hồ sơ bệnh nhân.'), findsOneWidget);
    r.error = null;
    r.value = patient;
    await t.tap(find.text('Thử lại'));
    await t.pumpAndSettle();
    expect(r.gets, 2);
    expect(find.text('Nguyễn An'), findsOneWidget);
  });
  testWidgets('local repository shows demo badge', (t) async {
    await t.pumpWidget(app(const LocalPatientRepository()));
    await t.pump();
    expect(find.text('Chế độ demo'), findsOneWidget);
  });
  testWidgets('remote repository does not show demo badge', (t) async {
    await t.pumpWidget(app(FakeRemotePatientRepository(patient)));
    await t.pump();
    expect(find.text('Chế độ demo'), findsNothing);
  });
  testWidgets('edit opens and update calls repository', (t) async {
    final r = FakeRepository(patient);
    await t.pumpWidget(app(r));
    await t.pump();
    await t.tap(find.byIcon(Icons.edit_outlined));
    await t.pumpAndSettle();
    expect(find.text('Lưu thay đổi'), findsOneWidget);
    await t.enterText(
      find.widgetWithText(TextFormField, 'Full name'),
      'Nguyễn Mới',
    );
    await t.scrollUntilVisible(
      find.text('Lưu thay đổi'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await t.tap(find.text('Lưu thay đổi'));
    await t.pumpAndSettle();
    expect(r.updates, 1);
    expect(find.text('Nguyễn Mới'), findsOneWidget);
  });
  testWidgets('invalid profile does not request an update', (t) async {
    final r = FakeRepository(patient);
    await t.pumpWidget(app(r));
    await t.pump();
    await t.tap(find.byIcon(Icons.edit_outlined));
    await t.pumpAndSettle();
    await t.enterText(find.widgetWithText(TextFormField, 'Full name'), '');
    await t.scrollUntilVisible(
      find.text('Lưu thay đổi'),
      100,
      scrollable: find.byType(Scrollable).last,
    );
    await t.tap(find.text('Lưu thay đổi'));
    await t.pump();
    expect(find.text('Name is required'), findsOneWidget);
    expect(r.updates, 0);
  });
}
