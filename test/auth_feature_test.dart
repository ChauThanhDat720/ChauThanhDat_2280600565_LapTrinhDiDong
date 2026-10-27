import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/core/models/app_user.dart';
import 'package:smart_hospital/core/session/patient_session.dart';
import 'package:smart_hospital/features/auth/presentation/login_screen.dart';
import 'package:smart_hospital/features/auth/presentation/role_home.dart';
import 'package:smart_hospital/features/auth/repositories/auth_repository.dart';
import 'package:smart_hospital/features/doctors/presentation/doctor_dashboard_screen.dart';
import 'package:smart_hospital/features/home/presentation/home_screen.dart';
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
  });
}
