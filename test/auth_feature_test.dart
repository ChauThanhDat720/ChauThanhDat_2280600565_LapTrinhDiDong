import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/core/models/app_user.dart';
import 'package:smart_hospital/core/session/patient_session.dart';
import 'package:smart_hospital/features/appointments/data/appointment_repository.dart';
import 'package:smart_hospital/features/appointments/domain/appointment.dart';
import 'package:smart_hospital/features/appointments/presentation/appointment_list_screen.dart';
import 'package:smart_hospital/features/appointments/presentation/digital_boarding_pass_screen.dart';
import 'package:smart_hospital/features/auth/presentation/login_screen.dart';
import 'package:smart_hospital/features/auth/presentation/role_home.dart';
import 'package:smart_hospital/features/auth/repositories/auth_repository.dart';
import 'package:smart_hospital/features/doctors/presentation/doctor_dashboard_screen.dart';
import 'package:smart_hospital/features/family/data/family_repository.dart';
import 'package:smart_hospital/features/home/presentation/home_screen.dart';
import 'package:smart_hospital/features/medical_records/presentation/lab_results_detail_screen.dart';
import 'package:smart_hospital/features/payments/data/payment_repository.dart';
import 'package:smart_hospital/features/payments/domain/invoice.dart';
import 'package:smart_hospital/features/reminders/data/medication_reminder_repository.dart';
import 'package:smart_hospital/features/teleconsultation/presentation/post_care_chat_screen.dart';
import 'package:smart_hospital/features/vaccination/data/vaccination_repository.dart';
import 'package:smart_hospital/features/vitals/data/health_vitals_repository.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PatientSession.instance.clear();
  });

  group('Authentication Domain & Repository Tests', () {
    test('Doctor accounts sign in with correct credentials', () async {
      const repo = LocalAuthRepository();

      // Test Doctor Linh
      final drLinh = await repo.signIn('doctor.linh@hospital.com', 'Doctor@123');
      expect(drLinh, isNotNull);
      expect(drLinh!.role, UserRole.doctor);
      expect(drLinh.doctorId, 'dr-linh');
      expect(drLinh.fullName, 'BS. Trần Thảo Linh');
      expect(drLinh.department, 'Khoa Tim mạch');

      // Test Doctor Duc
      final drDuc = await repo.signIn('doctor.duc@hospital.com', '123456');
      expect(drDuc, isNotNull);
      expect(drDuc!.doctorId, 'dr-duc');
      expect(drDuc.fullName, 'BS. Nguyễn Đức Minh');
      expect(drDuc.department, 'Khoa Nhi');

      // Test Doctor Tuan
      final drTuan = await repo.signIn('doctor.tuan@hospital.com', 'Doctor@123');
      expect(drTuan, isNotNull);
      expect(drTuan!.doctorId, 'dr-tuan');
      expect(drTuan.fullName, 'BS. Lê Anh Tuấn');
      expect(drTuan.department, 'Khoa Nội tổng quát');
    });

    test('Doctor login rejects wrong password', () async {
      const repo = LocalAuthRepository();
      expect(
        () => repo.signIn('doctor.linh@hospital.com', 'wrongpassword'),
        throwsA(isA<AuthRepositoryException>()),
      );
    });

    test('Admin account signs in with correct credentials', () async {
      const repo = LocalAuthRepository();
      final admin = await repo.signIn('admin@hospital.com', 'Admin@123');
      expect(admin, isNotNull);
      expect(admin!.role, UserRole.admin);
      expect(admin.fullName, 'Quản trị viên Hệ thống');
    });

    test('Patient registration, persistence, and login lifecycle', () async {
      const repo = LocalAuthRepository();

      // Register new patient
      final outcome = await repo.signUp(
        name: 'Nguyễn Thị Hoa',
        email: 'hoa.nguyen@gmail.com',
        password: 'hoaPassword2026',
        phone: '0988776655',
        dateOfBirth: '20/10/1992',
        gender: 'Nữ',
        address: 'Quận 3, TP.HCM',
      );
      expect(outcome.needsConfirmation, isFalse);

      // Sign in with new credentials
      final patient = await repo.signIn('hoa.nguyen@gmail.com', 'hoaPassword2026');
      expect(patient, isNotNull);
      expect(patient!.role, UserRole.patient);
      expect(patient.fullName, 'Nguyễn Thị Hoa');
      expect(patient.email, 'hoa.nguyen@gmail.com');
      expect(PatientSession.instance.isLoggedIn, isTrue);
      expect(PatientSession.instance.name, 'Nguyễn Thị Hoa');

      // Reject wrong password
      expect(
        () => repo.signIn('hoa.nguyen@gmail.com', 'wrongpassword'),
        throwsA(isA<AuthRepositoryException>()),
      );

      // Reject duplicate registration
      expect(
        () => repo.signUp(
          name: 'Nguyễn Thị Hoa',
          email: 'hoa.nguyen@gmail.com',
          password: 'anotherPassword',
        ),
        throwsA(isA<AuthRepositoryException>()),
      );
    });

    test('Registration rejects hospital staff email collision', () async {
      const repo = LocalAuthRepository();
      expect(
        () => repo.signUp(
          name: 'Fake Doctor',
          email: 'doctor.linh@hospital.com',
          password: 'password123',
        ),
        throwsA(isA<AuthRepositoryException>()),
      );
    });

    test('Unregistered email sign in is rejected', () async {
      const repo = LocalAuthRepository();
      expect(
        () => repo.signIn('unknown.user@example.com', '123456'),
        throwsA(isA<AuthRepositoryException>()),
      );
    });

    test('Session restore and signOut lifecycle', () async {
      const repo = LocalAuthRepository();
      await repo.signIn('doctor.mai@hospital.com', 'Doctor@123');

      final restored = await repo.restoreSession();
      expect(restored, isNotNull);
      expect(restored!.email, 'doctor.mai@hospital.com');
      expect(restored.fullName, 'BS. Bùi Thanh Mai');
      expect(restored.role, UserRole.doctor);

      await repo.signOut();
      final empty = await repo.restoreSession();
      expect(empty, isNull);
      expect(PatientSession.instance.isLoggedIn, isFalse);
    });
  });

  group('Login Email Validator Tests', () {
    test('emailValidator rejects empty or null strings', () {
      expect(emailValidator(null), 'Vui lòng nhập địa chỉ email');
      expect(emailValidator(''), 'Vui lòng nhập địa chỉ email');
      expect(emailValidator('   '), 'Vui lòng nhập địa chỉ email');
    });

    test('emailValidator rejects invalid email formats', () {
      expect(emailValidator('plainaddress'), 'Địa chỉ email không đúng định dạng');
      expect(emailValidator('@missingusername.com'), 'Địa chỉ email không đúng định dạng');
      expect(emailValidator('username@.com'), 'Địa chỉ email không đúng định dạng');
      expect(emailValidator('username@domain'), 'Địa chỉ email không đúng định dạng');
    });

    test('emailValidator accepts valid email addresses', () {
      expect(emailValidator('patient@hospital.com'), isNull);
      expect(emailValidator('doctor.linh@hospital.vn'), isNull);
      expect(emailValidator('user.name+tag@sub.example.com'), isNull);
    });
  });

  group('Role Home Routing Tests', () {
    test('homeForRole routes doctor to dashboard with doctor details', () {
      const doctorUser = AppUser(
        id: 'dr-duc',
        fullName: 'BS. Nguyễn Đức Minh',
        email: 'doctor.duc@hospital.com',
        role: UserRole.doctor,
        doctorId: 'dr-duc',
        department: 'Khoa Nhi',
      );
      final doctorWidget = homeForRole(UserRole.doctor, user: doctorUser);
      expect(doctorWidget, isA<DoctorDashboardScreen>());
      final dashboard = doctorWidget as DoctorDashboardScreen;
      expect(dashboard.doctorId, 'dr-duc');
      expect(dashboard.doctorName, 'BS. Nguyễn Đức Minh');
      expect(dashboard.department, 'Khoa Nhi');
    });

    test('homeForRole routes patient to PatientHomeScreen', () {
      final patientWidget = homeForRole(UserRole.patient);
      expect(patientWidget, isA<PatientHomeScreen>());
    });
  });

  group('LoginScreen UI Widget Tests', () {
    testWidgets('Renders real LoginScreen without demo buttons and switches tabs', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify clean UI without demo buttons
      expect(find.text('BS. Linh Demo'), findsNothing);
      expect(find.text('Bệnh nhân Demo'), findsNothing);
      expect(find.text('Smart Hospital'), findsOneWidget);
      expect(find.text('Bệnh nhân'), findsOneWidget);
      expect(find.text('Bác sĩ / Y tế'), findsOneWidget);
      expect(find.text('Ghi nhớ tài khoản'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
      expect(find.text('Đăng ký tài khoản Bệnh nhân'), findsOneWidget);

      // Tap on Doctor tab
      await tester.tap(find.text('Bác sĩ / Y tế'));
      await tester.pumpAndSettle();

      // Verify Doctor mode is active without forced credentials
      expect(find.text('Hệ thống Y tế Bác sĩ'), findsOneWidget);
      expect(find.text('Cổng Bác sĩ & Bệnh án Điện tử (EMR/HIS)'), findsOneWidget);
      expect(find.text('Đăng nhập Bàn khám Bác sĩ'), findsOneWidget);

      // Tap back to Patient tab
      await tester.tap(find.text('Bệnh nhân'));
      await tester.pumpAndSettle();

      expect(find.text('Smart Hospital'), findsOneWidget);
      expect(find.text('Đăng nhập'), findsOneWidget);
    });

    testWidgets('Remember me checkbox can be toggled', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final rememberMeFinder = find.text('Ghi nhớ tài khoản');
      expect(rememberMeFinder, findsOneWidget);

      await tester.tap(rememberMeFinder);
      await tester.pumpAndSettle();

      // Checkbox is checked
      final checkbox = tester.widget<Checkbox>(find.byType(Checkbox));
      expect(checkbox.value, isTrue);
    });

    testWidgets('Toggles password obscure state', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      final toggleButton = find.byIcon(Icons.visibility_off_outlined);
      expect(toggleButton, findsOneWidget);

      await tester.tap(toggleButton);
      await tester.pumpAndSettle();

      expect(find.byIcon(Icons.visibility_outlined), findsOneWidget);
    });

    testWidgets('Doctor logs in with real credentials and navigates to DoctorDashboardScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Switch to Doctor tab
      await tester.tap(find.text('Bác sĩ / Y tế'));
      await tester.pumpAndSettle();

      // Enter Doctor Linh credentials
      await tester.enterText(find.byType(TextFormField).at(0), 'doctor.linh@hospital.com');
      await tester.enterText(find.byType(TextFormField).at(1), 'Doctor@123');

      // Tap Sign In
      await tester.tap(find.text('Đăng nhập Bàn khám Bác sĩ'));
      await tester.pumpAndSettle();

      // Should navigate to DoctorDashboardScreen
      expect(find.byType(DoctorDashboardScreen), findsOneWidget);
      expect(PatientSession.instance.isLoggedIn, isTrue);
      expect(PatientSession.instance.role, 'doctor');
    });

    testWidgets('Login with Remember Me persists email in SharedPreferences', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Enter credentials
      await tester.enterText(find.byType(TextFormField).at(0), 'patient.an@hospital.com');
      await tester.enterText(find.byType(TextFormField).at(1), '123456');

      // Check Remember Me
      await tester.tap(find.text('Ghi nhớ tài khoản'));
      await tester.pumpAndSettle();

      // Sign In
      await tester.tap(find.text('Đăng nhập'));
      await tester.pumpAndSettle();

      // Verify saved in SharedPreferences
      final prefs = await SharedPreferences.getInstance();
      expect(prefs.getBool('auth_remember_me'), isTrue);
      expect(prefs.getString('auth_remembered_email'), 'patient.an@hospital.com');
    });

    test('Newly registered patient starts with zero pre-existing data across all stores', () async {
      const authRepo = LocalAuthRepository();
      await authRepo.signUp(
        name: 'Phạm Minh Khôi',
        email: 'khoi.newuser@gmail.com',
        password: 'Password@123',
        phone: '0977889900',
      );

      expect(PatientSession.instance.isDemoAccount, isFalse);

      // 1. Appointments should be empty
      const apptRepo = LocalAppointmentRepository();
      expect(await apptRepo.getMyAppointments(), isEmpty);

      // 2. Medication reminders and today's doses should be empty
      final reminderRepo = LocalMedicationReminderRepository();
      expect(await reminderRepo.getReminders(), isEmpty);
      expect(await reminderRepo.getTodayDoses(), isEmpty);

      // 3. Health vitals should be empty
      final vitalsRepo = LocalHealthVitalsRepository();
      expect(await vitalsRepo.getVitalsHistory(), isEmpty);
      expect((await vitalsRepo.getVitalsSummary()).totalRecords, 0);

      // 4. Invoices should be empty
      final paymentRepo = LocalPaymentRepository();
      expect(await paymentRepo.getInvoices(), isEmpty);

      // 5. Family members and vaccinations should be empty
      final familyRepo = LocalFamilyRepository();
      expect(await familyRepo.getMembers(), isEmpty);
      expect(await const LocalVaccinationRepository().getVaccinations(), isEmpty);
    });

    testWidgets('Unpaid completed appointment gates prescription and post-care chat until paid', (tester) async {
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      LocalPaymentRepository.resetForTest();
      AppointmentStore.instance.clearForTest();

      final apt = Appointment(
        id: 'APT-GATE-01',
        patientId: 'demo-patient',
        patientName: 'Nguyễn Văn An',
        doctorId: 'dr-linh',
        doctorName: 'BS. Trần Thảo Linh',
        department: 'Khoa Tim mạch',
        specialty: 'Tim mạch',
        date: DateTime.now(),
        time: '09:00',
        reason: 'Tức ngực',
        status: AppointmentStatus.completed,
        diagnosis: 'Cơn đau thắt ngực ổn định',
        prescription: '1. Concor 2.5mg - 1 viên/ngày',
      );
      AppointmentStore.instance.addAppointment(apt);

      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentDetailScreen(
            appointment: apt,
            repository: const LocalAppointmentRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      // While unpaid: prescription text is hidden and locked message is shown
      expect(
        find.text('Đơn thuốc điện tử & Nhắc uống thuốc đang khóa'),
        findsOneWidget,
      );
      expect(find.text('1. Concor 2.5mg - 1 viên/ngày'), findsNothing);
      expect(
        find.text('Thanh toán viện phí để mở khóa tư vấn'),
        findsOneWidget,
      );

      // PostCareChatScreen with requirePayment: true shows lock screen while unpaid
      await tester.pumpWidget(
        const MaterialApp(
          home: PostCareChatScreen(
            appointmentId: 'APT-GATE-01',
            requirePayment: true,
          ),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.text('Chưa hoàn tất thanh toán viện phí'), findsOneWidget);

      // Now simulate payment of the stage invoices (Stage 1 Booking & Stage 3 Pharmacy)
      final paymentRepo = LocalPaymentRepository();
      final stages = await paymentRepo.getStageInvoicesForAppointment('APT-GATE-01');
      for (final stageInv in stages) {
        if (!stageInv.isPaid) {
          await paymentRepo.simulatePayment(stageInv.id);
        }
      }

      // Re-open AppointmentDetailScreen after payment -> unlocked!
      await tester.pumpWidget(
        MaterialApp(
          home: AppointmentDetailScreen(
            appointment: apt,
            repository: const LocalAppointmentRepository(),
          ),
        ),
      );
      await tester.pumpAndSettle();

      expect(find.text('1. Concor 2.5mg - 1 viên/ngày'), findsOneWidget);
      expect(find.text('Tạo lịch nhắc uống thuốc từ toa này'), findsOneWidget);
      expect(find.text('Nhắn tin với BS. Trần Thảo Linh'), findsOneWidget);
    });

    testWidgets(
      '3-Stage Hospital Payment Flow: Stage 1 (Check-in QR), Stage 2 (Lab CLS-QR), Stage 3 (Pharmacy PHARM-QR)',
      (tester) async {
        tester.view.physicalSize = const Size(800, 1400);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(() => tester.view.resetPhysicalSize());

        LocalPaymentRepository.resetForTest();
        AppointmentStore.instance.clearForTest();

        final paymentRepo = LocalPaymentRepository();
        const apptRepo = LocalAppointmentRepository();

        // 1. Patient books an appointment -> Stage 1 (Booking Fee 150.000đ) is unpaid
        final bookedApt = Appointment(
          id: 'APT-STAGE-01',
          patientId: 'demo-patient',
          patientName: 'Nguyễn Văn An',
          doctorId: 'dr-linh',
          doctorName: 'BS. Trần Thảo Linh',
          department: 'Khoa Tim mạch',
          specialty: 'Tim mạch',
          date: DateTime.now(),
          time: '08:30',
          reason: 'Khám tim mạch định kỳ',
          status: AppointmentStatus.confirmed,
        );
        AppointmentStore.instance.addAppointment(bookedApt);

        final bookingInv = await paymentRepo.getOrCreateBookingInvoice(
          bookedApt.id,
        );
        expect(bookingInv.stage, PaymentStage.booking);
        expect(bookingInv.patientPayable, 150000);
        expect(bookingInv.isPaid, isFalse);

        // DigitalBoardingPassScreen locks CHECKIN QR until Stage 1 is paid
        await tester.pumpWidget(
          MaterialApp(
            home: DigitalBoardingPassScreen(
              appointment: bookedApt,
              repository: apptRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.textContaining('CHƯA CẤP MÃ QR CHECK-IN'), findsOneWidget);
        expect(find.text('CHECKIN:APT-STAGE-01'), findsNothing);

        // Pay Stage 1 -> CHECKIN QR unlocked!
        await paymentRepo.simulatePayment(bookingInv.id);
        await tester.pumpWidget(
          MaterialApp(
            home: DigitalBoardingPassScreen(
              key: UniqueKey(),
              appointment: bookedApt,
              repository: apptRepo,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('CHECKIN:APT-STAGE-01'), findsOneWidget);

        // 2. Doctor orders Lab Tests -> Stage 2 (Lab Fee) created & unpaid
        final labInv = await paymentRepo.createOrUpdateLabInvoice(
          bookedApt.id,
          const ['Tổng phân tích tế bào máu (CBC)', 'Điện tâm đồ (ECG)'],
        );
        expect(labInv.stage, PaymentStage.lab);
        expect(labInv.isPaid, isFalse);
        expect(labInv.qrServiceCode, 'CLS-QR:APT-STAGE-01');

        // LabResultsDetailScreen with requirePayment: true is locked until Stage 2 is paid
        await tester.pumpWidget(
          MaterialApp(
            home: LabResultsDetailScreen(
              key: UniqueKey(),
              appointment: bookedApt,
              requirePayment: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.text('Đợt 2: Chưa thanh toán Phí Xét nghiệm & CLS'),
          findsOneWidget,
        );

        // Pay Stage 2 -> CLS-QR & Lab Results unlocked!
        await paymentRepo.simulatePayment(labInv.id);
        await tester.pumpWidget(
          MaterialApp(
            home: LabResultsDetailScreen(
              key: UniqueKey(),
              appointment: bookedApt,
              requirePayment: true,
            ),
          ),
        );
        await tester.pumpAndSettle();
        expect(
          find.textContaining('CLS-QR:APT-STAGE-01'),
          findsOneWidget,
        );

        // 3. Doctor completes exam & writes prescription -> Stage 3 (Pharmacy Fee) created
        await apptRepo.updateAppointmentStatus(
          bookedApt.id,
          AppointmentStatus.completed,
          diagnosis: 'Tăng huyết áp độ 1',
          prescription: '1. Concor 2.5mg - 1 viên/ngày',
        );
        final pharmInv = await paymentRepo.getOrCreatePharmacyInvoice(
          bookedApt.id,
        );
        expect(pharmInv, isNotNull);
        expect(pharmInv!.stage, PaymentStage.pharmacy);
        expect(pharmInv.isPaid, isFalse);
        expect(pharmInv.qrServiceCode, 'PHARM-QR:APT-STAGE-01');

        await paymentRepo.simulatePayment(pharmInv.id);
        expect(
          await paymentRepo.isStagePaid(bookedApt.id, PaymentStage.pharmacy),
          isTrue,
        );
      },
    );
  });
}
