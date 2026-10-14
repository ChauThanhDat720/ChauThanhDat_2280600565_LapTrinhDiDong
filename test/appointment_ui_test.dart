import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/features/appointments/data/appointment_repository.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/appointments/presentation/appointment_list_screen.dart';
import 'package:smart_hospital/features/appointments/presentation/appointment_success_screen.dart';
import 'package:smart_hospital/features/doctors/domain/doctor.dart';
import 'package:smart_hospital/features/doctors/presentation/doctor_screens.dart';

final _item = Appointment(
  id: 'APT-01',
  patientId: 'demo-patient',
  doctorId: 'dr-linh',
  doctorName: 'BS. Trần Thảo Linh',
  specialty: 'Tim mạch',
  department: 'Tim mạch',
  departmentId: 'cardiology',
  date: DateTime(2026, 11, 20),
  time: '09:00',
  reason: 'Tái khám',
  status: AppointmentStatus.pending,
);

class _FakeRepository implements AppointmentRepository {
  _FakeRepository({
    this.items = const [],
    this.error,
    this.wait,
    this.slots = const [],
    this.slotWait,
    this.createError,
    this.created,
  });
  List<Appointment> items;
  Object? error;
  Completer<List<Appointment>>? wait;
  List<AppointmentSlot> slots;
  Completer<List<AppointmentSlot>>? slotWait;
  Object? createError;
  Appointment? created;
  int reads = 0;
  int cancels = 0;
  int slotReads = 0;
  int creates = 0;
  DateTime? requestedDate;
  Appointment? createdInput;
  @override
  Future<List<Appointment>> getMyAppointments() {
    reads++;
    if (wait != null) return wait!.future;
    if (error != null) return Future.error(error!);
    return Future.value(items);
  }

  @override
  Future<List<Appointment>> getAppointments() => getMyAppointments();
  @override
  Future<Appointment?> getAppointmentById(String id) async =>
      items.where((x) => x.id == id).firstOrNull;
  @override
  Future<Appointment> cancelAppointment(String id, {String? reason}) async {
    cancels++;
    final result = _item.copyWith(
      status: AppointmentStatus.cancelled,
      cancelledAt: DateTime(2026),
    );
    items = [result];
    return result;
  }

  @override
  Future<Appointment> createAppointment(Appointment appointment) async {
    creates++;
    createdInput = appointment;
    if (createError != null) throw createError!;
    return created ?? appointment;
  }

  @override
  Future<List<AppointmentSlot>> getAvailableSlots(
    String doctorId,
    DateTime selectedDate,
  ) {
    slotReads++;
    requestedDate = selectedDate;
    return slotWait?.future ?? Future.value(slots);
  }
}

Widget _app(Widget child) => MaterialApp(home: child);
DateTime _fixedNow() => DateTime(2026, 11, 1, 9);
final _slots = [
  AppointmentSlot(
    startTime: DateTime(2026, 11, 2, 8),
    endTime: DateTime(2026, 11, 2, 8, 30),
    isAvailable: true,
  ),
  AppointmentSlot(
    startTime: DateTime(2026, 11, 2, 8, 30),
    endTime: DateTime(2026, 11, 2, 9),
    isAvailable: false,
  ),
  AppointmentSlot(
    startTime: DateTime(2026, 11, 2, 9),
    endTime: DateTime(2026, 11, 2, 9, 30),
    isAvailable: true,
  ),
];

Future<void> _pickTomorrow(WidgetTester t) async {
  await t.tap(find.text('Chọn ngày khám'));
  await t.pumpAndSettle();
  await t.tap(find.text('2'));
  await t.tap(find.text('Chọn'));
  await t.pump();
}

Future<void> _tapBookingButton(WidgetTester t) async {
  await t.scrollUntilVisible(
    find.text('Xác nhận đặt lịch'),
    120,
    scrollable: find.byType(Scrollable).last,
  );
  await t.tap(find.text('Xác nhận đặt lịch'));
}

void main() {
  testWidgets('TC01 BookingScreen opens and shows doctor', (t) async {
    await t.pumpWidget(
      _app(
        BookAppointmentScreen(
          doctor: doctors.first,
          repository: _FakeRepository(),
        ),
      ),
    );
    expect(find.text('Đặt lịch khám'), findsOneWidget);
    expect(find.text('BS. Trần Thảo Linh'), findsOneWidget);
  });
  testWidgets('TC03 DatePicker loads slots for selected date', (t) async {
    final r = _FakeRepository(slots: _slots);
    await t.pumpWidget(
      _app(
        BookAppointmentScreen(
          doctor: doctors.first,
          repository: r,
          nowProvider: _fixedNow,
        ),
      ),
    );
    await _pickTomorrow(t);
    expect(find.text('02/11/2026'), findsOneWidget);
    expect(r.requestedDate, DateTime(2026, 11, 2));
    expect(r.slotReads, 1);
  });
  testWidgets('TC05 loading slots hides old choices then shows result', (
    t,
  ) async {
    final wait = Completer<List<AppointmentSlot>>();
    final r = _FakeRepository(slotWait: wait);
    await t.pumpWidget(
      _app(
        BookAppointmentScreen(
          doctor: doctors.first,
          repository: r,
          nowProvider: _fixedNow,
        ),
      ),
    );
    await _pickTomorrow(t);
    expect(find.text('Đang tải giờ khám...'), findsOneWidget);
    expect(find.text('08:00 - 08:30'), findsNothing);
    wait.complete(_slots);
    await t.pumpAndSettle();
    expect(find.text('08:00 - 08:30'), findsOneWidget);
  });
  testWidgets(
    'TC06 and TC07 slots render and unavailable slot stays disabled',
    (t) async {
      final r = _FakeRepository(slots: _slots);
      await t.pumpWidget(
        _app(
          BookAppointmentScreen(
            doctor: doctors.first,
            repository: r,
            nowProvider: _fixedNow,
          ),
        ),
      );
      await _pickTomorrow(t);
      await t.pumpAndSettle();
      expect(find.text('08:30 - 09:00'), findsOneWidget);
      await t.tap(find.text('08:30 - 09:00'));
      await t.tap(find.text('09:00 - 09:30'));
      await t.enterText(find.byType(TextFormField), 'Tái khám');
      await _tapBookingButton(t);
      await t.pump();
      expect(find.text('Giờ: 09:00'), findsOneWidget);
      expect(r.creates, 0);
    },
  );
  testWidgets('TC08 form booking opens success screen once', (t) async {
    final result = _item.copyWith();
    final r = _FakeRepository(slots: _slots, created: result);
    await t.pumpWidget(
      _app(
        BookAppointmentScreen(
          doctor: doctors.first,
          repository: r,
          nowProvider: _fixedNow,
        ),
      ),
    );
    await _pickTomorrow(t);
    await t.pumpAndSettle();
    await t.tap(find.text('09:00 - 09:30'));
    await t.enterText(find.byType(TextFormField), 'Tái khám');
    await _tapBookingButton(t);
    await t.pumpAndSettle();
    await t.tap(find.text('Xác nhận'));
    await t.pumpAndSettle();
    expect(r.creates, 1);
    expect(r.createdInput!.doctorId, 'dr-linh');
    expect(r.createdInput!.patientId, isEmpty);
    expect(find.text('Đặt lịch khám thành công!'), findsOneWidget);
    expect(find.text('APT-01'), findsOneWidget);
  });
  testWidgets('TC09 conflict reloads slots and does not open success', (
    t,
  ) async {
    final r = _FakeRepository(
      slots: _slots,
      createError: StateError('Khung giờ này đã được đặt.'),
    );
    await t.pumpWidget(
      _app(
        BookAppointmentScreen(
          doctor: doctors.first,
          repository: r,
          nowProvider: _fixedNow,
        ),
      ),
    );
    await _pickTomorrow(t);
    await t.pumpAndSettle();
    await t.tap(find.text('09:00 - 09:30'));
    await t.enterText(find.byType(TextFormField), 'Tái khám');
    await _tapBookingButton(t);
    await t.pumpAndSettle();
    await t.tap(find.text('Xác nhận'));
    await t.pumpAndSettle();
    expect(
      find.text('Khung giờ này không còn khả dụng. Vui lòng chọn giờ khác.'),
      findsOneWidget,
    );
    expect(find.text('Đặt lịch khám thành công!'), findsNothing);
    expect(r.slotReads, 2);
  });
  testWidgets('TC09 validation does not create without date, time or reason', (
    t,
  ) async {
    final r = _FakeRepository(slots: _slots);
    await t.pumpWidget(
      _app(
        BookAppointmentScreen(
          doctor: doctors.first,
          repository: r,
          nowProvider: _fixedNow,
        ),
      ),
    );
    await _tapBookingButton(t);
    await t.pump();
    expect(r.creates, 0);
    await _pickTomorrow(t);
    await t.pumpAndSettle();
    await _tapBookingButton(t);
    await t.pump();
    expect(r.creates, 0);
  });
  testWidgets('TC10 list loading state', (t) async {
    final r = _FakeRepository(wait: Completer());
    await t.pumpWidget(_app(AppointmentListScreen(repository: r)));
    expect(find.text('Đang tải lịch khám...'), findsOneWidget);
  });
  testWidgets('TC11 list success state', (t) async {
    await t.pumpWidget(
      _app(AppointmentListScreen(repository: _FakeRepository(items: [_item]))),
    );
    await t.pumpAndSettle();
    expect(find.text('1 lịch khám'), findsOneWidget);
    expect(find.text('BS. Trần Thảo Linh'), findsOneWidget);
  });
  testWidgets('TC12 list empty state', (t) async {
    await t.pumpWidget(
      _app(AppointmentListScreen(repository: _FakeRepository())),
    );
    await t.pump();
    expect(find.text('Bạn chưa có lịch khám nào.'), findsOneWidget);
  });
  testWidgets('TC13 and TC14 list error and retry', (t) async {
    final r = _FakeRepository(error: StateError('offline'));
    await t.pumpWidget(_app(AppointmentListScreen(repository: r)));
    await t.pump();
    expect(find.text('Không thể tải lịch khám.'), findsOneWidget);
    r.error = null;
    r.items = [_item];
    await t.tap(find.text('Thử lại'));
    await t.pump();
    expect(r.reads, 2);
  });
  testWidgets('TC15 detail displays appointment', (t) async {
    await t.pumpWidget(
      _app(
        AppointmentDetailScreen(
          appointment: _item,
          repository: _FakeRepository(items: [_item]),
        ),
      ),
    );
    expect(find.text('Mã lịch: APT-01'), findsOneWidget);
    expect(find.text('Tái khám'), findsOneWidget);
  });
  testWidgets('TC16 cancellation updates detail', (t) async {
    final r = _FakeRepository(items: [_item]);
    await t.pumpWidget(
      _app(AppointmentDetailScreen(appointment: _item, repository: r)),
    );
    await t.scrollUntilVisible(
      find.text('Hủy lịch khám'),
      100,
      scrollable: find.byType(Scrollable),
    );
    await t.tap(find.text('Hủy lịch khám'));
    await t.pumpAndSettle();
    await t.tap(find.text('Xác nhận hủy'));
    await t.pumpAndSettle();
    expect(r.cancels, 1);
    expect(find.text('Đã hủy'), findsOneWidget);
  });
  testWidgets('TC17 completed appointment has no cancel action', (t) async {
    await t.pumpWidget(
      _app(
        AppointmentDetailScreen(
          appointment: _item.copyWith(status: AppointmentStatus.completed),
          repository: _FakeRepository(),
        ),
      ),
    );
    expect(find.text('Hủy lịch khám'), findsNothing);
  });
  testWidgets('TC08 success screen displays created appointment', (t) async {
    await t.pumpWidget(
      _app(
        AppointmentSuccessScreen(
          appointment: _item,
          repository: _FakeRepository(),
        ),
      ),
    );
    expect(find.text('Đặt lịch khám thành công!'), findsOneWidget);
    expect(find.text('APT-01'), findsOneWidget);
  });
}
