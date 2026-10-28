import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:geolocator/geolocator.dart';
import 'package:latlong2/latlong.dart';

import '../../../core/theme/app_theme.dart';
import '../domain/patient_location.dart';
import '../services/location_service.dart';

class PatientLocationScreen extends StatefulWidget {
  const PatientLocationScreen({super.key});

  @override
  State<PatientLocationScreen> createState() => _PatientLocationScreenState();
}

class _PatientLocationScreenState extends State<PatientLocationScreen> {
  final LocationService _locationService = const LocationService();
  final MapController _mapController = MapController();

  PatientLocation? _location;
  bool _loading = false;
  bool _mapTileError = false;
  _LocationState _state = _LocationState.initial;
  bool _isLiveTracking = false;
  StreamSubscription<PatientLocation>? _locationSub;

  @override
  void dispose() {
    _locationSub?.cancel();
    super.dispose();
  }

  Future<void> _getCurrentLocation() async {
    if (_loading) return;

    setState(() {
      _loading = true;
      _mapTileError = false;
    });
    try {
      final serviceEnabled = await _locationService.isLocationServiceEnabled();
      if (!serviceEnabled) {
        if (mounted) setState(() => _state = _LocationState.serviceDisabled);
        return;
      }

      var permission = await _locationService.checkPermission();
      if (permission == LocationPermission.denied) {
        permission = await _locationService.requestPermission();
      }
      if (!mounted) return;

      if (permission == LocationPermission.deniedForever) {
        setState(() => _state = _LocationState.permissionDeniedForever);
        return;
      }
      if (permission == LocationPermission.denied) {
        setState(() => _state = _LocationState.permissionDenied);
        return;
      }

      final location = await _locationService.getCurrentLocation();
      if (!mounted) return;
      setState(() {
        _location = location;
        _state = _LocationState.ready;
      });
      _moveMap(LatLng(location.latitude, location.longitude));
    } catch (_) {
      if (mounted) setState(() => _state = _LocationState.error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _moveMap(LatLng center) {
    try {
      _mapController.move(center, 16.5);
    } catch (_) {}
  }

  Future<void> _toggleLiveTracking() async {
    if (_isLiveTracking) {
      await _locationSub?.cancel();
      _locationSub = null;
      setState(() => _isLiveTracking = false);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Đã dừng theo dõi vị trí trực tiếp')),
        );
      }
      return;
    }

    final serviceEnabled = await _locationService.isLocationServiceEnabled();
    if (!serviceEnabled) {
      if (mounted) setState(() => _state = _LocationState.serviceDisabled);
      return;
    }

    var permission = await _locationService.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await _locationService.requestPermission();
    }
    if (permission == LocationPermission.denied ||
        permission == LocationPermission.deniedForever) {
      if (mounted) {
        setState(() => _state = _LocationState.permissionDenied);
      }
      return;
    }

    setState(() {
      _isLiveTracking = true;
      _state = _LocationState.ready;
    });

    _locationSub = _locationService.getPositionStream().listen(
      (newLoc) {
        if (!mounted) return;
        setState(() {
          _location = newLoc;
        });
        _moveMap(LatLng(newLoc.latitude, newLoc.longitude));
      },
      onError: (e) {
        if (mounted) {
          setState(() => _isLiveTracking = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Lỗi live GPS: $e')),
          );
        }
      },
    );

    if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          backgroundColor: AppColors.success,
          content: Text('🟢 Đã kích hoạt Theo dõi Vị trí Thời gian Thực (Live GPS)'),
        ),
      );
    }
  }

  Future<void> _openLocationSettings() async {
    await _locationService.openLocationSettings();
  }

  Future<void> _openAppSettings() async {
    await _locationService.openAppSettings();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text(
        'Vị trí & Định vị Trực tiếp',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
      actions: [
        if (_location != null)
          IconButton(
            tooltip: _isLiveTracking ? 'Đang Live GPS' : 'Bật Live GPS',
            icon: Icon(
              _isLiveTracking
                  ? Icons.sensors_rounded
                  : Icons.sensors_off_rounded,
              color: _isLiveTracking ? Colors.redAccent : Colors.grey,
            ),
            onPressed: _toggleLiveTracking,
          ),
      ],
    ),
    body: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Center(
          child: ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 720),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _IntroCard(isLiveTracking: _isLiveTracking),
                const SizedBox(height: 20),
                if (_loading) const _LoadingContent() else _buildContent(),
                const SizedBox(height: 18),
                const Text(
                  'Vị trí chỉ được truy cập và phát trực tiếp khi bạn cho phép.',
                  textAlign: TextAlign.center,
                  style: TextStyle(color: AppColors.mutedText, fontSize: 12),
                ),
              ],
            ),
          ),
        ),
      ),
    ),
  );

  Widget _buildContent() {
    switch (_state) {
      case _LocationState.ready:
        return _LocationDetails(
          location: _location!,
          mapController: _mapController,
          isLiveTracking: _isLiveTracking,
          onToggleLive: _toggleLiveTracking,
          onRefresh: _getCurrentLocation,
          hasMapTileError: _mapTileError,
          onMapTileError: _handleMapTileError,
        );
      case _LocationState.serviceDisabled:
        return _LocationMessage(
          icon: Icons.location_off_rounded,
          title: 'Dịch vụ vị trí đang tắt.',
          description:
              'Hãy bật GPS hoặc dịch vụ vị trí trên thiết bị rồi thử lại.',
          actionLabel: 'Mở cài đặt vị trí',
          onAction: _openLocationSettings,
          secondaryActionLabel: 'Thử lại',
          onSecondaryAction: _getCurrentLocation,
        );
      case _LocationState.permissionDenied:
        return _LocationMessage(
          icon: Icons.location_disabled_rounded,
          title:
              'Ứng dụng cần quyền vị trí để định vị và cập nhật thời gian thực.',
          description:
              'Bạn có thể nhấn nút bên dưới để cấp quyền định vị.',
          actionLabel: 'Lấy vị trí hiện tại',
          onAction: _getCurrentLocation,
        );
      case _LocationState.permissionDeniedForever:
        return _LocationMessage(
          icon: Icons.no_accounts_rounded,
          title: 'Quyền vị trí đã bị từ chối vĩnh viễn trong Cài đặt.',
          description:
              'Sau khi cấp quyền trong Cài đặt, hãy quay lại ứng dụng.',
          actionLabel: 'Mở cài đặt ứng dụng',
          onAction: _openAppSettings,
          secondaryActionLabel: 'Cập nhật vị trí',
          onSecondaryAction: _getCurrentLocation,
        );
      case _LocationState.error:
        return _LocationMessage(
          icon: Icons.error_outline_rounded,
          title: 'Không thể xác định vị trí hiện tại.',
          description:
              'Vui lòng kiểm tra GPS và kết nối mạng rồi thử lại.',
          actionLabel: 'Thử lại',
          onAction: _getCurrentLocation,
        );
      case _LocationState.initial:
        return _LocationMessage(
          icon: Icons.location_on_outlined,
          title: 'Chưa bắt đầu định vị',
          description:
              'Nhấn nút bên dưới để xác định vị trí hoặc bật luồng định vị trực tiếp.',
          actionLabel: 'Bật định vị & Theo dõi Real-time',
          onAction: _toggleLiveTracking,
        );
    }
  }

  void _handleMapTileError() {
    if (!mounted || _mapTileError) return;
    setState(() => _mapTileError = true);
  }
}

class _IntroCard extends StatelessWidget {
  const _IntroCard({this.isLiveTracking = false});
  final bool isLiveTracking;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(20),
    decoration: BoxDecoration(
      gradient: LinearGradient(
        colors: isLiveTracking
            ? [const Color(0xFFE0F2FE), const Color(0xFFBAE6FD)]
            : [const Color(0xFFE4F4F5), const Color(0xFFCCECEE)],
        begin: Alignment.topLeft,
        end: Alignment.bottomRight,
      ),
      borderRadius: BorderRadius.circular(22),
      boxShadow: [
        BoxShadow(
          color: Colors.black.withOpacity(0.04),
          blurRadius: 10,
          offset: const Offset(0, 4),
        ),
      ],
    ),
    child: Column(
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              isLiveTracking ? Icons.radar_rounded : Icons.location_on_rounded,
              size: 44,
              color: isLiveTracking ? Colors.blueAccent : AppColors.primary,
            ),
            if (isLiveTracking) ...[
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.fiber_manual_record, color: Colors.white, size: 10),
                    SizedBox(width: 4),
                    Text(
                      'LIVE GPS',
                      style: TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w900,
                        fontSize: 11,
                        letterSpacing: 1.1,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 10),
        Text(
          isLiveTracking ? 'Đang Theo Dõi Vị Trí Trực Tiếp' : 'Định Vị Bệnh Nhân Thời Gian Thực',
          style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 6),
        Text(
          isLiveTracking
              ? 'Tọa độ GPS đang được đồng bộ liên tục khi bạn di chuyển trong khuôn viên hoặc đến bệnh viện.'
              : 'Hỗ trợ tìm đường, dẫn đường đến phòng khám và theo dõi vị trí người bệnh tức thì.',
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 13, height: 1.4),
        ),
      ],
    ),
  );
}

class _LoadingContent extends StatelessWidget {
  const _LoadingContent();

  @override
  Widget build(BuildContext context) => const Padding(
    padding: EdgeInsets.symmetric(vertical: 48),
    child: Column(
      children: [
        CircularProgressIndicator(),
        SizedBox(height: 14),
        Text(
          'Đang kết nối tín hiệu GPS vệ tinh...',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _LocationDetails extends StatelessWidget {
  const _LocationDetails({
    required this.location,
    required this.mapController,
    required this.isLiveTracking,
    required this.onToggleLive,
    required this.onRefresh,
    required this.hasMapTileError,
    required this.onMapTileError,
  });

  final PatientLocation location;
  final MapController mapController;
  final bool isLiveTracking;
  final VoidCallback onToggleLive;
  final Future<void> Function() onRefresh;
  final bool hasMapTileError;
  final VoidCallback onMapTileError;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(18),
            border: Border.all(
              color: isLiveTracking ? AppColors.primary : AppColors.border,
              width: isLiveTracking ? 1.5 : 1.0,
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.04),
                blurRadius: 10,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Tọa độ thời gian thực',
                    style: TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                  ),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                    decoration: BoxDecoration(
                      color: isLiveTracking
                          ? Colors.green.withOpacity(0.12)
                          : Colors.grey.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(20),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.circle,
                          size: 9,
                          color: isLiveTracking ? Colors.green : Colors.grey,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          isLiveTracking ? 'Real-time Live' : 'Snapshot',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                            color: isLiveTracking ? Colors.green[800] : Colors.grey[700],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 14),
              _LocationValue(
                label: 'Vĩ độ (Latitude)',
                value: location.latitude.toStringAsFixed(6),
              ),
              _LocationValue(
                label: 'Kinh độ (Longitude)',
                value: location.longitude.toStringAsFixed(6),
              ),
              _LocationValue(
                label: 'Bán kính chính xác',
                value: '± ${location.accuracy.toStringAsFixed(1)} m',
              ),
              _LocationValue(
                label: 'Thời điểm nhận tín hiệu',
                value: _formatTimestamp(location.timestamp),
              ),
            ],
          ),
        ),
        const SizedBox(height: 16),
        ClipRRect(
          borderRadius: BorderRadius.circular(16),
          child: SizedBox(
            height: 280,
            child: Stack(
              children: [
                FlutterMap(
                  mapController: mapController,
                  options: MapOptions(
                    initialCenter: LatLng(location.latitude, location.longitude),
                    initialZoom: 16.5,
                  ),
                  children: [
                    TileLayer(
                      urlTemplate:
                          'https://{s}.tile.openstreetmap.org/{z}/{x}/{y}.png',
                      userAgentPackageName: 'com.example.flutter_demo',
                      errorTileCallback: (_, error, stackTrace) =>
                          onMapTileError(),
                    ),
                    MarkerLayer(
                      markers: [
                        Marker(
                          point: LatLng(location.latitude, location.longitude),
                          width: 52,
                          height: 52,
                          child: Stack(
                            alignment: Alignment.center,
                            children: [
                              if (isLiveTracking)
                                Container(
                                  width: 48,
                                  height: 48,
                                  decoration: BoxDecoration(
                                    shape: BoxShape.circle,
                                    color: Colors.redAccent.withOpacity(0.25),
                                  ),
                                ),
                              const Icon(
                                Icons.location_on_rounded,
                                color: Colors.redAccent,
                                size: 44,
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                    RichAttributionWidget(
                      attributions: const [
                        TextSourceAttribution('OpenStreetMap contributors'),
                      ],
                    ),
                  ],
                ),
                if (hasMapTileError)
                  Positioned(
                    top: 12,
                    left: 12,
                    right: 12,
                    child: Material(
                      color: Colors.white.withOpacity(0.94),
                      borderRadius: BorderRadius.circular(12),
                      child: const Padding(
                        padding: EdgeInsets.all(12),
                        child: Row(
                          children: [
                            Icon(
                              Icons.wifi_off_rounded,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Không tải được nền bản đồ. Kiểm tra Internet để xem bản đồ chi tiết.',
                                style: TextStyle(fontSize: 12, height: 1.3),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                style: FilledButton.styleFrom(
                  backgroundColor: isLiveTracking ? Colors.redAccent : AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                ),
                onPressed: onToggleLive,
                icon: Icon(isLiveTracking ? Icons.stop_rounded : Icons.play_arrow_rounded),
                label: Text(
                  isLiveTracking ? 'Dừng Live Tracking' : 'Bật Live GPS Trực tiếp',
                  style: const TextStyle(fontWeight: FontWeight.bold),
                ),
              ),
            ),
            const SizedBox(width: 12),
            IconButton.filledTonal(
              onPressed: onRefresh,
              icon: const Icon(Icons.refresh_rounded),
              tooltip: 'Lấy vị trí 1 lần',
            ),
          ],
        ),
      ],
    );
  }

  String _formatTimestamp(DateTime time) {
    final h = time.hour.toString().padLeft(2, '0');
    final m = time.minute.toString().padLeft(2, '0');
    final s = time.second.toString().padLeft(2, '0');
    final d = time.day.toString().padLeft(2, '0');
    final mo = time.month.toString().padLeft(2, '0');
    return '$h:$m:$s ngày $d/$mo/${time.year}';
  }
}

class _LocationValue extends StatelessWidget {
  const _LocationValue({required this.label, required this.value});
  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(vertical: 5),
    child: Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(
          label,
          style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
        ),
        Text(
          value,
          style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
        ),
      ],
    ),
  );
}

class _LocationMessage extends StatelessWidget {
  const _LocationMessage({
    required this.icon,
    required this.title,
    required this.description,
    required this.actionLabel,
    required this.onAction,
    this.secondaryActionLabel,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String actionLabel;
  final Future<void> Function() onAction;
  final String? secondaryActionLabel;
  final Future<void> Function()? onSecondaryAction;

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(24),
    decoration: BoxDecoration(
      color: Colors.white,
      borderRadius: BorderRadius.circular(18),
      border: Border.all(color: AppColors.border),
    ),
    child: Column(
      children: [
        Icon(icon, size: 48, color: AppColors.primary),
        const SizedBox(height: 14),
        Text(
          title,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800),
        ),
        const SizedBox(height: 8),
        Text(
          description,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.mutedText, fontSize: 13),
        ),
        const SizedBox(height: 20),
        FilledButton.icon(
          onPressed: onAction,
          icon: const Icon(Icons.my_location_rounded),
          label: Text(actionLabel),
        ),
        if (secondaryActionLabel != null && onSecondaryAction != null) ...[
          const SizedBox(height: 10),
          TextButton(
            onPressed: onSecondaryAction,
            child: Text(secondaryActionLabel!),
          ),
        ],
      ],
    ),
  );
}

enum _LocationState {
  initial,
  ready,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  error,
}
