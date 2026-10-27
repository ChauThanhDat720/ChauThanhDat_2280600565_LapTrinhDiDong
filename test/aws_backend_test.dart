import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_hospital/core/config/aws_config.dart';
import 'package:smart_hospital/core/network/api_client.dart';
import 'package:smart_hospital/core/network/api_config.dart';
import 'package:smart_hospital/core/network/api_exception.dart';
import 'package:smart_hospital/core/repositories/hospital_repositories.dart';
import 'package:smart_hospital/features/appointments/data/appointment_repository.dart';
import 'package:smart_hospital/features/family/data/family_repository.dart';
import 'package:smart_hospital/features/family/domain/family_member.dart';
import 'package:smart_hospital/features/profile/data/patient_repository.dart';
import 'package:smart_hospital/features/profile/domain/patient_profile.dart';
import 'package:smart_hospital/features/teleconsultation/data/teleconsultation_repository.dart';
import 'package:smart_hospital/features/teleconsultation/domain/teleconsultation.dart';
import 'package:smart_hospital/features/clinical_intake/data/clinical_intake_repository.dart';

void main() {
  const settings = AwsSettings(
    mode: 'aws',
    region: 'ap-southeast-1',
    userPoolId: 'ap-southeast-1_Example',
    appClientId: '123example',
    apiBaseUrl: 'https://api.example.com/v1',
  );

  test(
    'AWS settings require a complete matching Cognito and HTTPS configuration',
    () {
      expect(settings.validate, returnsNormally);
      expect(
        () => const AwsSettings(
          mode: 'aws',
          region: '',
          userPoolId: '',
          appClientId: '',
          apiBaseUrl: '',
        ).validate(),
        throwsStateError,
      );
      expect(
        () => const AwsSettings(
          mode: 'aws',
          region: 'ap-southeast-1',
          userPoolId: 'us-east-1_Example',
          appClientId: 'x',
          apiBaseUrl: 'https://api.example.com',
        ).validate(),
        throwsStateError,
      );
      expect(
        () => const AwsSettings(
          mode: 'aws',
          region: 'ap-southeast-1',
          userPoolId: 'ap-southeast-1_x',
          appClientId: 'x',
          apiBaseUrl: 'http://api.example.com',
        ).validate(),
        throwsStateError,
      );
    },
  );

  test(
    'API config rejects unsupported schemes, credentials, and incomplete URLs',
    () {
      for (final url in [
        'file:///tmp/test',
        'https:',
        'https://user:password@example.com',
        'https://api.example.com?token=x',
      ]) {
        expect(ApiConfig(baseUrl: url).isConfigured, isFalse);
      }
      expect(ApiConfig(baseUrl: 'http://localhost:3000').isConfigured, isTrue);
    },
  );

  test('Repository factory only selects AWS when explicitly enabled', () {
    final config = ApiConfig(baseUrl: settings.apiBaseUrl);
    expect(
      HospitalRepositories(apiConfig: config).appointments,
      isA<LocalAppointmentRepository>(),
    );
    final remote = HospitalRepositories(
      apiConfig: config,
      useRemote: true,
      accessTokenProvider: () async => 'id-token',
    );
    expect(remote.appointments, isA<RemoteAppointmentRepository>());
    expect(remote.family, isA<RemoteFamilyRepository>());
    expect(remote.teleconsultations, isA<RemoteTeleconsultationRepository>());
    expect(remote.clinicalIntake, isA<RemoteClinicalIntakeRepository>());
    expect(
      () => HospitalRepositories(
        apiConfig: ApiConfig(baseUrl: ''),
        useRemote: true,
      ),
      throwsStateError,
    );
  });

  test('API requests preserve the stage path and fetch the current ID token for each request', () async {
    var fetches = 0;
    final requests = <http.Request>[];
    final api = ApiClient(
      config: ApiConfig(baseUrl: settings.apiBaseUrl),
      accessTokenProvider: () async => 'id-token-${++fetches}',
      httpClient: MockClient((request) async {
        requests.add(request);
        return http.Response('{}', 200);
      }),
    );
    addTearDown(api.close);
    await api.get('/patients/me');
    await api.get('/family/members');
    expect(requests[0].url.path, '/v1/patients/me');
    expect(requests[0].headers['authorization'], 'Bearer id-token-1');
    expect(requests[1].headers['authorization'], 'Bearer id-token-2');
  });

  test('Family remote errors propagate instead of reporting a successful local save', () async {
    final api = ApiClient(
      config: ApiConfig(baseUrl: settings.apiBaseUrl),
      httpClient: MockClient(
        (_) async => http.Response('{"message":"Server unavailable"}', 503),
      ),
    );
    addTearDown(api.close);
    final repository = RemoteFamilyRepository(api);
    await expectLater(
      repository.updateMember(
        const FamilyMember(
          id: 'member',
          primaryPatientId: 'p',
          fullName: 'Test',
        ),
      ),
      throwsA(isA<ApiException>().having((e) => e.statusCode, 'status', 503)),
    );
  });

  test(
    'Patient profile handles 404 and translates birthday between UI and API',
    () async {
      var saved = false;
      final api = ApiClient(
        config: ApiConfig(baseUrl: settings.apiBaseUrl),
        httpClient: MockClient((request) async {
          if (request.method == 'GET' && !saved) {
            return http.Response('{"message":"Not found"}', 404);
          }
          final body = jsonDecode(request.body) as Map<String, dynamic>;
          expect(body['dateOfBirth'], '1990-02-12');
          saved = true;
          return http.Response(jsonEncode(body), 200);
        }),
      );
      addTearDown(api.close);
      final repository = RemotePatientRepository(api);
      expect(await repository.getMyProfile(), isNull);
      final profile = await repository.createMyProfile(
        const PatientProfile(
          name: 'Test',
          email: 'a@example.com',
          phone: '0901234567',
          dateOfBirth: '12/02/1990',
          gender: 'Nam',
          address: 'HCM',
        ),
      );
      expect(profile.dateOfBirth, '12/02/1990');
    },
  );

  test('Photo is uploaded to S3 without forwarding the Cognito JWT or storing base64 in the message', () async {
    final api = ApiClient(
      config: ApiConfig(baseUrl: settings.apiBaseUrl),
      accessTokenProvider: () async => 'cognito-id-token',
      httpClient: MockClient((request) async {
        if (request.url.host == 'bucket.s3.amazonaws.com') {
          expect(request.method, 'PUT');
          expect(request.headers['authorization'], isNull);
          expect(request.bodyBytes, [1, 2, 3]);
          return http.Response('', 200);
        }
        expect(request.headers['authorization'], 'Bearer cognito-id-token');
        final body = jsonDecode(request.body) as Map<String, dynamic>;
        if (request.url.path.endsWith('/attachments')) {
          expect(body, {'contentType': 'image/png', 'size': 3});
          return http.Response(
            jsonEncode({
              'uploadUrl':
                  'https://bucket.s3.amazonaws.com/photo?signature=example',
              'objectKey': 'consultations/session/user/photo',
              'headers': {'Content-Type': 'image/png'},
            }),
            200,
          );
        }
        expect(body['imageKey'], 'consultations/session/user/photo');
        expect(body.containsKey('imageUrl'), isFalse);
        return http.Response(
          jsonEncode({
            'id': 'm',
            'sessionId': 'session',
            'senderType': 'patient',
            'senderId': 'u',
            'senderName': 'Test',
            'message': 'Ảnh',
            'created_at': DateTime.now().toUtc().toIso8601String(),
          }),
          201,
          headers: {'content-type': 'application/json; charset=utf-8'},
        );
      }),
    );
    addTearDown(api.close);
    final repository = RemoteTeleconsultationRepository(api);
    final message = await repository.sendMessage(
      'session',
      senderType: MessageSenderType.patient,
      senderId: 'u',
      senderName: 'Test',
      message: 'Ảnh',
      imageUrl: 'data:image/png;base64,AQID',
    );
    expect(message.id, 'm');
  });
}
