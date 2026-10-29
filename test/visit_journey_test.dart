import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:smart_hospital/core/network/api_client.dart';
import 'package:smart_hospital/core/network/api_config.dart';
import 'package:smart_hospital/features/appointments/data/appointment_repository.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/appointments/domain/hospital_navigation.dart';
import 'package:smart_hospital/features/appointments/domain/visit_journey.dart';
import 'package:smart_hospital/features/appointments/presentation/digital_boarding_pass_screen.dart';

Appointment appointment({
  AppointmentStatus status = AppointmentStatus.checkedIn,
  VisitJourney? journey,
}) => Appointment(
  id: 'APT-DEMO',
  doctorId: 'dr-linh',
  doctorName: 'BS. Trần Thảo Linh',
  specialty: 'Tim mạch',
  department: 'Tim mạch',
  patientName: 'Bệnh nhân DEMO',
  date: DateTime(2030, 1, 2),
  time: '08:00',
  reason: 'DEMO',
  status: status,
  journey: journey,
  queueNumber: 1,
  checkedInAt: DateTime(2030, 1, 2),
);

void main() {
  test('Four steps do not claim lab results or medicine receipt from completed status alone', () {
    final prescribed = appointment(
      status: AppointmentStatus.completed,
      journey: const VisitJourney(stage: 'prescribed'),
    );
    final route = HospitalNavigationResolver.resolveRoute(prescribed);
    expect(route.steps[0].isDone, true);
    expect(route.steps[1].isDone, true);
    expect(route.steps[2].badge, 'KHÔNG CHỈ ĐỊNH');
    expect(route.steps[3].isDone, false);
    expect(route.steps[3].isCurrent, true);
    final labWaiting = HospitalNavigationResolver.resolveRoute(
      appointment(
        journey: const VisitJourney(
          stage: 'lab_reported',
          labOrder: 'CLS mẫu DEMO',
        ),
      ),
    );
    expect(labWaiting.steps[2].isDone, false);
    expect(labWaiting.steps[2].isCurrent, true);
    final finished = HospitalNavigationResolver.resolveRoute(
      appointment(
        status: AppointmentStatus.completed,
        journey: const VisitJourney(
          stage: 'finished',
          medicinesReceivedAt: '2030-01-02T02:00:00Z',
        ),
      ),
    );
    expect(finished.steps[3].isDone, true);
    expect(finished.steps[3].isCurrent, false);
  });

  test('Local check-in rejects pending/cancelled bookings and does not allocate twice', () async {
    LocalAppointmentRepository.resetForTest();
    const repository = LocalAppointmentRepository();
    AppointmentStore.instance.addAppointment(
      appointment(status: AppointmentStatus.pending),
    );
    await expectLater(
      repository.checkinAppointment('APT-DEMO'),
      throwsStateError,
    );
    AppointmentStore.instance.replaceAppointment(
      appointment(status: AppointmentStatus.cancelled),
    );
    await expectLater(
      repository.checkinAppointment('APT-DEMO'),
      throwsStateError,
    );
    AppointmentStore.instance.replaceAppointment(
      appointment(status: AppointmentStatus.confirmed),
    );
    final first = await repository.checkinAppointment('APT-DEMO');
    final retry = await repository.checkinAppointment('APT-DEMO');
    expect(first.status, AppointmentStatus.checkedIn);
    expect(retry.queueNumber, first.queueNumber);
    LocalAppointmentRepository.resetForTest();
  });

  testWidgets(
    'Patient pass refreshes doctor actions, reports labs and confirms medicine receipt on a narrow screen',
    (tester) async {
        await tester.binding.setSurfaceSize(const Size(360, 800));
      addTearDown(() => tester.binding.setSurfaceSize(null));
      var serverItem = <String, dynamic>{
        'id': 'APT-DEMO',
        'doctorId': 'dr-linh',
        'doctorName': 'BS. Trần Thảo Linh',
        'department': 'Tim mạch',
        'specialty': 'Tim mạch',
        'patientName': 'Bệnh nhân DEMO',
        'startTime': '2030-01-02T01:00:00.000Z',
        'reason': 'DEMO',
        'status': 'confirmed',
      };
      final actions = <String>[];
      final api = ApiClient(
        config: ApiConfig(baseUrl: 'http://localhost:3000'),
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/checkin')) {
            serverItem = {
              ...serverItem,
              'status': 'checked_in',
              'queueNumber': 1,
              'roomNumber': 'Phòng 204 - Tầng 2',
              'journey': {'stage': 'waiting', 'message': 'Đang chờ bác sĩ gọi'},
            };
          } else if (request.method == 'POST') {
            final action = jsonDecode(request.body)['action'] as String;
            actions.add(action);
            final journey = Map<String, dynamic>.from(
              serverItem['journey'] as Map,
            );
            if (action == 'report_lab') journey['stage'] = 'lab_reported';
            if (action == 'simulate_payment') {
              journey['paymentSimulatedAt'] = '2030-01-02T02:00:00Z';
            }
            if (action == 'receive_medicines') {
              journey['stage'] = 'finished';
              journey['medicinesReceivedAt'] = '2030-01-02T02:01:00Z';
            }
            serverItem = {...serverItem, 'journey': journey};
          }
          return http.Response(
            jsonEncode(serverItem),
            200,
            headers: {'content-type': 'application/json; charset=utf-8'},
          );
        }),
      );
      addTearDown(api.close);
      final repository = RemoteAppointmentRepository(api);
      await tester.pumpWidget(
        MaterialApp(
          home: DigitalBoardingPassScreen(
            appointment: Appointment.fromJson(serverItem),
            repository: repository,
          ),
        ),
      );
      await tester.pumpAndSettle();
      final checkin = find.text('Mô phỏng Quét Check-in Ngay');
      await tester.ensureVisible(checkin);
      await tester.tap(checkin);
      await tester.pumpAndSettle();
      expect(find.text('STT: 01'), findsOneWidget);
      expect(find.text('Mô phỏng Quét Check-in Ngay'), findsNothing);
      serverItem = {
        ...serverItem,
        'journey': {'stage': 'consulting', 'message': 'Mời số 1 vào phòng 204'},
      };
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(find.text('Mời số 1 vào phòng 204'), findsOneWidget);
      serverItem = {
        ...serverItem,
        'journey': {
          'stage': 'lab_ordered',
          'labOrder': 'CLS mẫu DEMO',
          'message': 'Đến phòng CLS',
        },
      };
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      final report = find.text('Tôi đã thực hiện cận lâm sàng');
      await tester.ensureVisible(report);
      await tester.tap(report);
      await tester.pumpAndSettle();
      expect(actions, contains('report_lab'));
      expect(find.text('CHỜ BÁC SĨ XEM'), findsOneWidget);
      serverItem = {
        ...serverItem,
        'status': 'completed',
        'diagnosis': 'Kết luận mẫu DEMO',
        'prescription': 'Đơn thuốc mẫu DEMO, không dùng điều trị',
        'journey': {
          'stage': 'prescribed',
          'message': 'Đã gửi đơn thuốc',
          'labOrder': 'CLS mẫu DEMO',
          'labResultNote': 'Bác sĩ đã xem mẫu DEMO',
        },
      };
      await tester.pump(const Duration(seconds: 5));
      await tester.pumpAndSettle();
      expect(
        find.text('Đơn thuốc mẫu DEMO, không dùng điều trị'),
        findsOneWidget,
      );
      final pay = find.text('Mô phỏng thanh toán (không chuyển tiền)');
      await tester.ensureVisible(pay);
      await tester.tap(pay);
      await tester.pumpAndSettle();
      final receipt = find.text('Xác nhận tôi đã nhận thuốc');
      await tester.ensureVisible(receipt);
      await tester.tap(receipt);
      await tester.pumpAndSettle();
      expect(
        actions,
        containsAllInOrder([
          'report_lab',
          'simulate_payment',
          'receive_medicines',
        ]),
      );
      expect(find.text('ĐÃ NHẬN THUỐC'), findsOneWidget);
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox());
    },
  );
}
