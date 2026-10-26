import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/core/theme/app_theme.dart';
import 'package:smart_hospital/features/appointments/data/appointment_repository.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/medical_records/presentation/doctor_rating_dialog.dart';

class _RatingTestRepo implements AppointmentRepository {
  Appointment? ratedAppointment;
  int? lastRating;
  String? lastNote;

  @override
  Future<Appointment> rateAppointment(
    String id, {
    required int rating,
    String? reviewNote,
  }) async {
    lastRating = rating;
    lastNote = reviewNote;
    ratedAppointment = Appointment(
      id: id,
      doctorId: 'DOC-01',
      doctorName: 'BS. Trần Thảo Linh',
      specialty: 'Tim mạch',
      department: 'Tim mạch',
      departmentId: 'cardio',
      date: DateTime.now(),
      time: '09:00',
      reason: 'Khám',
      status: AppointmentStatus.completed,
      rating: rating,
      reviewNote: reviewNote,
    );
    return ratedAppointment!;
  }

  @override
  Future<Appointment> cancelAppointment(String id, {String? reason}) => throw UnimplementedError();
  @override
  Future<Appointment> createAppointment(Appointment appointment) => throw UnimplementedError();
  @override
  Future<Appointment?> getAppointmentById(String id) => throw UnimplementedError();
  @override
  Future<List<Appointment>> getAppointments() => throw UnimplementedError();
  @override
  Future<List<AppointmentSlot>> getAvailableSlots(String doctorId, DateTime selectedDate) => throw UnimplementedError();
  @override
  Future<List<Appointment>> getDoctorAppointments({String? doctorId, DateTime? date}) => throw UnimplementedError();
  @override
  Future<List<Appointment>> getMyAppointments() => throw UnimplementedError();
  @override
  Future<Appointment> updateAppointmentStatus(String id, AppointmentStatus status, {String? note, String? diagnosis, String? prescription, DateTime? followUpDate}) => throw UnimplementedError();
  @override
  Future<Appointment> checkinAppointment(String id, {String? roomNumber}) => throw UnimplementedError();
}

void main() {
  testWidgets('DoctorRatingDialog submits doctor rating and feedback', (tester) async {
    final repo = _RatingTestRepo();
    final appointment = Appointment(
      id: 'APT-99',
      doctorId: 'DOC-01',
      doctorName: 'BS. Trần Thảo Linh',
      specialty: 'Tim mạch',
      department: 'Khoa Tim mạch',
      departmentId: 'cardio',
      date: DateTime.now(),
      time: '09:00',
      reason: 'Khám tim',
      status: AppointmentStatus.completed,
    );

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light,
        home: Scaffold(
          body: Builder(
            builder: (context) => ElevatedButton(
              onPressed: () => DoctorRatingDialog.show(
                context,
                appointment: appointment,
                repository: repo,
              ),
              child: const Text('Open Rating'),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('Open Rating'));
    await tester.pumpAndSettle();

    expect(find.text('Đánh giá buổi khám'), findsOneWidget);
    expect(find.text('BS. Trần Thảo Linh'), findsOneWidget);

    // Enter review text
    await tester.enterText(
      find.byType(TextField),
      'Bác sĩ rất ân cần, hướng dẫn chi tiết!',
    );
    await tester.pumpAndSettle();

    // Submit rating
    await tester.tap(find.text('Gửi đánh giá'));
    await tester.pumpAndSettle();

    expect(repo.lastRating, 5);
    expect(repo.lastNote, 'Bác sĩ rất ân cần, hướng dẫn chi tiết!');
  });
}
