import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:smart_hospital/core/config/aws_config.dart';
import 'package:smart_hospital/core/models/app_user.dart';
import 'package:smart_hospital/core/network/api_client.dart';
import 'package:smart_hospital/core/network/api_config.dart';
import 'package:smart_hospital/core/repositories/hospital_repositories.dart';
import 'package:smart_hospital/features/appointments/data/appointment_repository.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/auth/repositories/shared_auth_repository.dart';
import 'package:smart_hospital/features/profile/data/patient_repository.dart';
import 'package:smart_hospital/features/teleconsultation/data/teleconsultation_repository.dart';

http.Response jsonResponse(String body, int status) => http.Response(
  body,
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test(
    'Shared mode requires HTTPS except explicitly enabled local HTTP demo',
    () {
      AwsSettings settings(String url, {bool insecure = false}) => AwsSettings(
        mode: 'shared',
        region: '',
        userPoolId: '',
        appClientId: '',
        apiBaseUrl: url,
        allowInsecureHttp: insecure,
      );
      expect(
        settings('https://hospital.example.com').validate,
        returnsNormally,
      );
      expect(settings('http://127.0.0.1:3000').validate, throwsStateError);
      expect(
        settings('http://127.0.0.1:3000', insecure: true).validate,
        returnsNormally,
      );
      expect(
        settings('https://user:password@hospital.example.com').validate,
        throwsStateError,
      );
      final repos = HospitalRepositories(
        apiConfig: ApiConfig(baseUrl: 'http://localhost:3000'),
        useRemote: true,
        sharedAppointmentsOnly: true,
      );
      expect(repos.appointments, isA<RemoteAppointmentRepository>());
      expect(repos.patients, isA<LocalPatientRepository>());
      expect(repos.teleconsultations, isA<LocalTeleconsultationRepository>());
    },
  );

  test(
    'Shared auth restores server role, sends token and revokes it on logout',
    () async {
      const user = {
        'id': 'user-1',
        'email': 'doctor.linh@hospital.com',
        'fullName': 'BS. Trần Thảo Linh',
        'role': 'doctor',
        'doctorId': 'dr-linh',
        'department': 'Tim mạch',
        'phoneNumber': '',
      };
      late SharedAuthRepository auth;
      final config = ApiConfig(baseUrl: 'http://localhost:3000');
      final api = ApiClient(
        config: config,
        accessTokenProvider: () => auth.accessToken(),
        httpClient: MockClient((request) async {
          if (request.url.path == '/auth/login') {
            expect(jsonDecode(request.body)['password'], 'Doctor@123');
            return jsonResponse(
              jsonEncode({'token': 'opaque-session', 'user': user}),
              200,
            );
          }
          expect(request.headers['authorization'], 'Bearer opaque-session');
          return jsonResponse(jsonEncode({'user': user}), 200);
        }),
      );
      addTearDown(api.close);
      auth = SharedAuthRepository(config: config, client: api);
      expect(
        (await auth.signIn('doctor.linh@hospital.com', 'Doctor@123'))?.role,
        UserRole.doctor,
      );
      expect(await auth.accessToken(), 'opaque-session');
      expect((await auth.restoreSession())?.doctorId, 'dr-linh');
      await auth.signOut();
      expect(await auth.accessToken(), isNull);
      expect(await auth.restoreSession(), isNull);
      expect(
        (await SharedPreferences.getInstance()).getKeys().any(
          (k) => k.contains('password'),
        ),
        isFalse,
      );
    },
  );

  test(
    'Remote booking contract preserves Vietnam time and confirmed status',
    () async {
      final payload = {
        'id': 'APT-1',
        'doctorId': 'dr-linh',
        'patientId': 'user-1',
        'patientName': 'Nguyễn Văn An',
        'startTime': '2030-01-02T01:30:00.000Z',
        'endTime': '2030-01-02T02:00:00.000Z',
        'status': 'pending',
        'reason': 'Khám định kỳ',
      };
      final api = ApiClient(
        config: ApiConfig(baseUrl: 'http://localhost:3000'),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('availability')) {
            return jsonResponse(
              jsonEncode({
                'slots': [
                  {
                    'startTime': payload['startTime'],
                    'endTime': payload['endTime'],
                    'isAvailable': true,
                  },
                ],
              }),
              200,
            );
          }
          if (request.method == 'POST') {
            expect(jsonDecode(request.body)['startTime'], payload['startTime']);
            return jsonResponse(jsonEncode(payload), 201);
          }
          return jsonResponse(
            jsonEncode({
              'items': [
                {...payload, 'status': 'confirmed'},
              ],
            }),
            200,
          );
        }),
      );
      addTearDown(api.close);
      final repository = RemoteAppointmentRepository(api);
      final slots = await repository.getAvailableSlots(
        'dr-linh',
        DateTime(2030, 1, 2),
      );
      expect(slots.single.startTime.hour, 8);
      final created = await repository.createAppointment(
        Appointment(
          id: 'phone-request-1',
          doctorId: 'dr-linh',
          doctorName: 'BS. Linh',
          specialty: 'Tim mạch',
          department: 'Tim mạch',
          date: DateTime(2030, 1, 2),
          time: '08:30',
          reason: 'Khám định kỳ',
        ),
      );
      expect(created.time, '08:30');
      expect(created.status, AppointmentStatus.pending);
      expect(
        (await repository.getMyAppointments()).single.status,
        AppointmentStatus.confirmed,
      );
    },
  );
}
