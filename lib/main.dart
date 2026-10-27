import 'package:flutter/material.dart';

import 'app.dart';
import 'core/config/aws_config.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    AwsConfig.settings.validate();
    runApp(const SmartHospitalApp());
  } catch (error) {
    runApp(
      MaterialApp(
        home: Scaffold(
          body: SafeArea(
            child: Padding(
              padding: const EdgeInsets.all(24),
              child: Text(
                'Cấu hình ứng dụng chưa hợp lệ.\n$error\nKiểm tra file config/aws.local.json và chạy lại.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}
