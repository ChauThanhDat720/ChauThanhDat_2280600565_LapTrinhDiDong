import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/aws_config.dart';
import 'core/realtime/hospital_realtime_service.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    AwsConfig.settings.validate();
    HospitalRealtimeService.instance.connect();
    runApp(const SmartHospitalApp());
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Cấu hình ứng dụng chưa hợp lệ.\n$error\nKiểm tra BACKEND_MODE và API_BASE_URL trong file cấu hình và chạy lại.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
