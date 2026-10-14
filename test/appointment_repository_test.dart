import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/features/appointments/data/appointment_repository.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';

DateTime get _tomorrow {
  final now = DateTime.now();
  return DateTime(now.year, now.month, now.day + 1);
}

Appointment _appointment({
  String id = '',
  String doctor = 'dr-linh',
  int hour = 8,
  int minute = 0,
  AppointmentStatus status = AppointmentStatus.pending,
}) => Appointment(
  id: id,
  patientId: 'demo-patient',
  doctorId: doctor,
  doctorName: 'BS. Trần Thảo Linh',
  specialty: 'Tim mạch',
  department: 'Tim mạch',
  departmentId: 'cardiology',
  date: _tomorrow,
  time:
      '${hour.toString().padLeft(2, '0')}:${minute.toString().padLeft(2, '0')}',
  reason: 'Tái khám định kỳ',
  status: status,
);

void main() {
  late LocalAppointmentRepository repository;
  setUp(() {
    LocalAppointmentRepository.resetForTest();
    repository = const LocalAppointmentRepository();
  });

  test(
    'TC01 available slots are returned for a doctor',
    () async => expect(
      (await repository.getAvailableSlots(
        'dr-linh',
        _tomorrow,
      )).where((s) => s.isAvailable),
      isNotEmpty,
    ),
  );
  test('TC02 pending slot is unavailable', () async {
    await repository.createAppointment(_appointment());
    expect(
      (await repository.getAvailableSlots(
        'dr-linh',
        _tomorrow,
      )).first.isAvailable,
      isFalse,
    );
  });
  test('TC03 confirmed slot is unavailable', () async {
    AppointmentStore.instance.addAppointment(
      _appointment(id: 'a', status: AppointmentStatus.confirmed),
    );
    expect(
      (await repository.getAvailableSlots(
        'dr-linh',
        _tomorrow,
      )).first.isAvailable,
      isFalse,
    );
  });
  test('TC04 cancelled slot is available again', () async {
    AppointmentStore.instance.addAppointment(
      _appointment(id: 'a', status: AppointmentStatus.cancelled),
    );
    expect(
      (await repository.getAvailableSlots(
        'dr-linh',
        _tomorrow,
      )).first.isAvailable,
      isTrue,
    );
  });
  test('TC05 past slots are unavailable', () async {
    final day = DateTime.now().subtract(const Duration(days: 1));
    expect(
      (await repository.getAvailableSlots(
        'dr-linh',
        day,
      )).every((s) => !s.isAvailable),
      isTrue,
    );
  });
  test('TC06 no slot crosses lunch or closing time', () async {
    final slots = await repository.getAvailableSlots('dr-linh', _tomorrow);
    expect(
      slots.any((s) => s.startTime.hour == 12 || s.endTime.hour == 12),
      isFalse,
    );
    expect(slots.last.endTime.hour, 17);
  });
  test('TC07 another doctor is not blocked', () async {
    await repository.createAppointment(_appointment());
    expect(
      (await repository.getAvailableSlots(
        'dr-duc',
        _tomorrow,
      )).first.isAvailable,
      isTrue,
    );
  });
  test('TC08 valid booking is saved', () async {
    final saved = await repository.createAppointment(_appointment());
    expect(saved.id, isNotEmpty);
  });
  test('TC09 duplicate booking is rejected', () async {
    await repository.createAppointment(_appointment());
    await expectLater(
      repository.createAppointment(_appointment()),
      throwsStateError,
    );
  });
  test(
    'TC10 invalid working time is rejected',
    () async => expectLater(
      repository.createAppointment(_appointment(hour: 12)),
      throwsStateError,
    ),
  );
  test(
    'TC11 missing doctor is rejected',
    () async => expectLater(
      repository.createAppointment(_appointment(doctor: 'none')),
      throwsStateError,
    ),
  );
  test('TC12 list reflects saved booking', () async {
    await repository.createAppointment(_appointment());
    expect(await repository.getMyAppointments(), hasLength(1));
  });
  test('TC13 concurrent duplicate requests create one booking', () async {
    final results = await Future.wait([
      repository
          .createAppointment(_appointment())
          .then((_) => true)
          .catchError((_) => false),
      repository
          .createAppointment(_appointment())
          .then((_) => true)
          .catchError((_) => false),
    ]);
    expect(results.where((r) => r), hasLength(1));
  });
  test('TC14 pending booking can be cancelled', () async {
    final item = await repository.createAppointment(_appointment());
    expect(
      (await repository.cancelAppointment(item.id)).status,
      AppointmentStatus.cancelled,
    );
  });
  test('TC15 confirmed booking can be cancelled', () async {
    AppointmentStore.instance.addAppointment(
      _appointment(id: 'a', status: AppointmentStatus.confirmed),
    );
    expect(
      (await repository.cancelAppointment('a')).status,
      AppointmentStatus.cancelled,
    );
  });
  test('TC16 completed booking cannot be cancelled', () async {
    AppointmentStore.instance.addAppointment(
      _appointment(id: 'a', status: AppointmentStatus.completed),
    );
    await expectLater(repository.cancelAppointment('a'), throwsStateError);
  });
  test('TC17 cancelled booking does not update again', () async {
    AppointmentStore.instance.addAppointment(
      _appointment(id: 'a', status: AppointmentStatus.cancelled),
    );
    await expectLater(repository.cancelAppointment('a'), throwsStateError);
  });
  test('TC18 cancellation releases a slot', () async {
    final item = await repository.createAppointment(_appointment());
    await repository.cancelAppointment(item.id);
    expect(
      (await repository.getAvailableSlots(
        'dr-linh',
        _tomorrow,
      )).first.isAvailable,
      isTrue,
    );
  });
}
