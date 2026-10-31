import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../core/realtime/hospital_realtime_service.dart';
import '../../../core/session/patient_session.dart';
import '../../../core/theme/app_theme.dart';
import '../../location/domain/patient_location.dart';
import '../../location/services/location_service.dart';

class EmergencySosScreen extends StatefulWidget {
  const EmergencySosScreen({super.key});

  @override
  State<EmergencySosScreen> createState() => _EmergencySosScreenState();
}

class _EmergencySosScreenState extends State<EmergencySosScreen>
    with SingleTickerProviderStateMixin {
  final LocationService _locationService = const LocationService();
  final MapController _mapController = MapController();

  PatientLocation? _location;
  bool _gettingLocation = true;
  bool _sosDispatched = false;
  int _countdown = 3;
  Timer? _countdownTimer;
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 700),
    )..repeat(reverse: true);
    _pulseAnimation = Tween<double>(begin: 0.95, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    _fetchLocation();
    _startCountdown();
  }

  @override
  void dispose() {
    _countdownTimer?.cancel();
    _pulseController.dispose();
    super.dispose();
  }

  void _startCountdown() {
    _countdownTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) return;
      if (_countdown > 1) {
        setState(() => _countdown--);
      } else {
        timer.cancel();
        _dispatchEmergencySos();
      }
    });
  }

  Future<void> _fetchLocation() async {
    try {
      final loc = await _locationService.getCurrentLocation();
      if (mounted) {
        setState(() {
          _location = loc;
          _gettingLocation = false;
        });
        _mapController.move(LatLng(loc.latitude, loc.longitude), 16.5);
      }
    } catch (_) {
      if (mounted) {
        setState(() => _gettingLocation = false);
      }
    }
  }

  void _dispatchEmergencySos() {
    if (_sosDispatched) return;
    setState(() {
      _sosDispatched = true;
      _countdown = 0;
    });

    final patientName = PatientSession.instance.activePatientName;
    final lat = _location?.latitude ?? 10.7769;
    final lng = _location?.longitude ?? 106.7009;

    // Phát tín hiệu thời gian thực lên toàn hệ thống bệnh viện
    HospitalRealtimeService.instance.notifyQueueCalled(
      appointmentId: 'SOS-${DateTime.now().millisecondsSinceEpoch}',
      doctorId: 'dr-linh',
      doctorName: 'BS. Trực Cấp cứu 115',
      patientName: '$patientName [🚨 CẤP CỨU SOS]',
      queueNumber: 0,
      roomNumber: 'KHOA CẤP CỨU & XE CỨU THƯƠNG',
      note: 'Vị trí vệ tinh: $lat, $lng - Yêu cầu điều phối cứu thương ngay lập tức!',
    );

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        backgroundColor: Colors.red,
        content: Text(
          '🚨 ĐÃ PHÁT TÍN HIỆU CẤP CỨU SOS ĐẾN BỆNH VIỆN & TRUNG TÂM CẤP CỨU!',
          style: TextStyle(fontWeight: FontWeight.bold),
        ),
      ),
    );
  }

  Future<void> _callHotline(String phone) async {
    final uri = Uri.parse('tel:$phone');
    if (await canLaunchUrl(uri)) {
      await launchUrl(uri);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        backgroundColor: const Color(0xFF1E293B),
        foregroundColor: Colors.white,
        title: const Text('Báo Động Cấp Cứu Y Tế (SOS)', style: TextStyle(fontWeight: FontWeight.w900)),
        centerTitle: true,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          children: [
            // Big SOS Pulse Button
            const SizedBox(height: 10),
            Center(
              child: ScaleTransition(
                scale: _pulseAnimation,
                child: Container(
                  width: 170,
                  height: 170,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: const RadialGradient(
                      colors: [Color(0xFFEF4444), Color(0xFFB91C1C)],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: Colors.red.withOpacity(0.55),
                        blurRadius: 28,
                        spreadRadius: 6,
                      ),
                    ],
                  ),
                  child: Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.emergency_rounded, size: 52, color: Colors.white),
                        const SizedBox(height: 4),
                        const Text(
                          'SOS 115',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, fontSize: 24),
                        ),
                        if (!_sosDispatched && _countdown > 0)
                          Text('Tự gửi sau: ${_countdown}s', style: const TextStyle(color: Colors.white70, fontSize: 11)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            const SizedBox(height: 24),

            // Status Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              decoration: BoxDecoration(
                color: _sosDispatched ? const Color(0xFF7F1D1D) : const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: _sosDispatched ? Colors.redAccent : Colors.white24),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Icon(_sosDispatched ? Icons.check_circle_rounded : Icons.radar_rounded, color: Colors.redAccent, size: 20),
                  const SizedBox(width: 8),
                  Text(
                    _sosDispatched
                        ? 'TÍN HIỆU CẤP CỨU ĐÃ ĐƯỢC KÍCH HOẠT'
                        : 'ĐANG CHUẨN BỊ PHÁT TÍN HIỆU...',
                    style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 13),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 18),

            // Location Box
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: const Color(0xFF1E293B),
                borderRadius: BorderRadius.circular(18),
                border: Border.all(color: Colors.white12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(Icons.my_location_rounded, color: Colors.cyanAccent, size: 20),
                      SizedBox(width: 8),
                      Text(
                        'Tọa độ cấp cứu khẩn cấp',
                        style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold, fontSize: 15),
                      ),
                    ],
                  ),
                  const SizedBox(height: 10),
                  if (_gettingLocation)
                    const Center(child: Padding(padding: EdgeInsets.all(12), child: CircularProgressIndicator(color: Colors.cyanAccent)))
                  else if (_location != null) ...[
                    Text('• Vĩ độ: ${_location!.latitude.toStringAsFixed(6)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text('• Kinh độ: ${_location!.longitude.toStringAsFixed(6)}', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    Text('• Bán kính chính xác: ±${_location!.accuracy.toStringAsFixed(1)} m', style: const TextStyle(color: Colors.white70, fontSize: 13)),
                    const SizedBox(height: 12),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: SizedBox(
                        height: 160,
                        child: FlutterMap(
                          mapController: _mapController,
                          options: MapOptions(
                            initialCenter: LatLng(_location!.latitude, _location!.longitude),
                            initialZoom: 16.0,
                          ),
                          children: [
                            TileLayer(
                              urlTemplate: 'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                              userAgentPackageName: 'com.example.flutter_demo',
                            ),
                            MarkerLayer(
                              markers: [
                                Marker(
                                  point: LatLng(_location!.latitude, _location!.longitude),
                                  width: 44,
                                  height: 44,
                                  child: const Icon(Icons.emergency_rounded, color: Colors.red, size: 40),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  ] else
                    const Text('Không lấy được GPS. Đang gửi địa chỉ mặc định của bệnh viện.', style: TextStyle(color: Colors.redAccent)),
                ],
              ),
            ),
            const SizedBox(height: 20),

            // Call Buttons
            Row(
              children: [
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: Colors.red,
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _callHotline('115'),
                    icon: const Icon(Icons.phone_in_talk_rounded),
                    label: const Text('Gọi Cấp Cứu 115', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton.icon(
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFF0284C7),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                    ),
                    onPressed: () => _callHotline('19008888'),
                    icon: const Icon(Icons.local_hospital_rounded),
                    label: const Text('Hotline Bệnh viện', style: TextStyle(fontWeight: FontWeight.bold)),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
