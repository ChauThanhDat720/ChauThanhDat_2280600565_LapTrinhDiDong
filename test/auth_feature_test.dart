import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:smart_hospital/core/models/app_user.dart';
import 'package:smart_hospital/core/session/patient_session.dart';
import 'package:smart_hospital/features/auth/presentation/login_screen.dart';
import 'package:smart_hospital/features/auth/presentation/role_home.dart';
import 'package:smart_hospital/features/auth/repositories/auth_repository.dart';
import 'package:smart_hospital/features/auth/repositories/auth_repository_provider.dart';
import 'package:smart_hospital/features/doctors/presentation/doctor_dashboard_screen.dart';
import 'package:smart_hospital/features/home/presentation/home_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    await PatientSession.instance.clear();
  });

  group('Authentication Domain & Repository Tests', () {
    test('LocalAuthRepository signIn correctly determines patient role', () async {
      const repo = LocalAuthRepository();
      final user = await repo.signIn('patient.an@hospital.com', '123456');

      expect(user, isNotNull);
      expect(user!.role, UserRole.patient);
      expect(user.email, 'patient.an@hospital.com');
      expect(user.fullName, 'patient.an');
      expect(PatientSession.instance.isLoggedIn, isTrue);
    });

    test('LocalAuthRepository signIn honors custom demoName', () async {
      const repo = LocalAuthRepository();
      final user = await repo.signIn(
        'patient.an@hospital.com',
        '123456',
        demoName: 'Nguyễn Văn An',
      );

      expect(user, isNotNull);
      expect(user!.fullName, 'Nguyễn Văn An');
    });

    test('LocalAuthRepository signIn correctly determines doctor role', () async {
      const repo = LocalAuthRepository();
      final user = await repo.signIn('doctor.linh@hospital.com', '123456');

      expect(user, isNotNull);
      expect(user!.role, UserRole.doctor);
      expect(user.email, 'doctor.linh@hospital.com');
    });

    test('LocalAuthRepository signIn correctly determines admin role', () async {
      const repo = LocalAuthRepository();
      final user = await repo.signIn('admin@hospital.com', '123456');

      expect(user, isNotNull);
      expect(user!.role, UserRole.admin);
    });

    test('LocalAuthRepository session restore and signOut lifecycle', () async {
      const repo = LocalAuthRepository();
      await repo.signIn('test.user@hospital.com', '123456');

      final restored = await repo.restoreSession();
      expect(restored, isNotNull);
      expect(restored!.email, 'test.user@hospital.com');

      await repo.signOut();
      final empty = await repo.restoreSession();
      expect(empty, isNull);
      expect(PatientSession.instance.isLoggedIn, isFalse);
    });

    test('LocalAuthRepository signUp creates local patient session', () async {
      const repo = LocalAuthRepository();
      final outcome = await repo.signUp(
        name: 'Trần Thị Mai',
        email: 'mai.tran@hospital.com',
        password: 'password123',
        phone: '0901234567',
      );

      expect(outcome.needsConfirmation, isFalse);
      expect(PatientSession.instance.name, 'Trần Thị Mai');
      expect(PatientSession.instance.email, 'mai.tran@hospital.com');
      expect(PatientSession.instance.phone, '0901234567');
    });
  });

  group('Login Email Validator Tests', () {
    test('emailValidator rejects empty or null strings', () {
      expect(emailValidator(null), 'Please enter your email');
      expect(emailValidator(''), 'Please enter your email');
      expect(emailValidator('   '), 'Please enter your email');
    });

    test('emailValidator rejects invalid email formats', () {
      expect(emailValidator('plainaddress'), 'Enter a valid email address');
      expect(emailValidator('@missingusername.com'), 'Enter a valid email address');
      expect(emailValidator('username@.com'), 'Enter a valid email address');
      expect(emailValidator('username@domain'), 'Enter a valid email address');
    });

    test('emailValidator accepts valid email addresses', () {
      expect(emailValidator('patient@hospital.com'), isNull);
      expect(emailValidator('doctor.linh@hospital.vn'), isNull);
      expect(emailValidator('user.name+tag@sub.example.com'), isNull);
    });
  });

  group('Role Home Routing Tests', () {
    test('homeForRole routes to correct screen based on UserRole', () {
      final patientWidget = homeForRole(UserRole.patient);
      expect(patientWidget, isA<PatientHomeScreen>());

      final doctorWidget = homeForRole(UserRole.doctor);
      expect(doctorWidget, isA<DoctorHomeScreen>());

      final adminWidget = homeForRole(UserRole.admin);
      expect(adminWidget, isA<AdminDashboardScreen>());

      final unknownWidget = homeForRole(UserRole.unknown);
      expect(unknownWidget, isA<AccessDeniedScreen>());
    });
  });

  group('LoginScreen UI Widget Tests', () {
    testWidgets('Renders LoginScreen and switches between Patient and Doctor tabs', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Verify default state is Patient mode
      expect(find.text('Smart Hospital'), findsOneWidget);
      expect(find.text('Bệnh nhân'), findsOneWidget);
      expect(find.text('Bác sĩ / Y tế'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
      expect(find.text('Create patient account'), findsOneWidget);

      // Tap on Doctor tab
      await tester.tap(find.text('Bác sĩ / Y tế'));
      await tester.pumpAndSettle();

      // Verify Doctor mode is active
      expect(find.text('Hệ thống Y tế Bác sĩ'), findsOneWidget);
      expect(find.text('Cổng Bác sĩ & Bệnh án Điện tử (EMR/HIS)'), findsOneWidget);
      expect(find.text('Đăng nhập Bàn khám Bác sĩ'), findsOneWidget);
      expect(find.text('doctor.linh@hospital.com'), findsOneWidget);

      // Tap back to Patient tab
      await tester.tap(find.text('Bệnh nhân'));
      await tester.pumpAndSettle();

      expect(find.text('Smart Hospital'), findsOneWidget);
      expect(find.text('Sign in'), findsOneWidget);
    });

    testWidgets('Validates empty email and password inputs', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      // Tap Sign in without filling email or password
      await tester.tap(find.text('Sign in'));
      await tester.pumpAndSettle();

      expect(find.text('Please enter your email'), findsOneWidget);
      expect(find.text('Password must have at least 6 characters'), findsOneWidget);
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

    testWidgets('Quick demo button logs in as Patient and navigates to PatientHomeScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      if (authRepository.isDemo) {
        expect(find.text('Bệnh nhân Demo'), findsOneWidget);
        await tester.tap(find.text('Bệnh nhân Demo'));
        await tester.pumpAndSettle();

        // Should navigate to PatientHomeScreen
        expect(find.byType(PatientHomeScreen), findsOneWidget);
        expect(PatientSession.instance.isLoggedIn, isTrue);
      }
    });

    testWidgets('Quick demo button logs in as Doctor and navigates to DoctorDashboardScreen', (tester) async {
      tester.view.physicalSize = const Size(800, 1200);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(() => tester.view.resetPhysicalSize());

      await tester.pumpWidget(
        const MaterialApp(
          home: LoginScreen(),
        ),
      );
      await tester.pumpAndSettle();

      if (authRepository.isDemo) {
        expect(find.text('BS. Linh Demo'), findsOneWidget);
        await tester.tap(find.text('BS. Linh Demo'));
        await tester.pumpAndSettle();

        // Should navigate to DoctorDashboardScreen
        expect(find.byType(DoctorDashboardScreen), findsOneWidget);
        expect(PatientSession.instance.isLoggedIn, isTrue);
      }
    });
  });
}
