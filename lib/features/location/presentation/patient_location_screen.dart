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

  PatientLocation? _location;
  bool _loading = false;
  bool _mapTileError = false;
  _LocationState _state = _LocationState.initial;

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
    } catch (_) {
      if (mounted) setState(() => _state = _LocationState.error);
    } finally {
      if (mounted) setState(() => _loading = false);
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
        'Vị trí của tôi',
        style: TextStyle(fontWeight: FontWeight.w800),
      ),
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
                _IntroCard(),
                const SizedBox(height: 20),
                if (_loading) const _LoadingContent() else _buildContent(),
                const SizedBox(height: 18),
                const Text(
                  'Vị trí chỉ được truy cập khi bạn cho phép.',
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
              'Ứng dụng cần quyền vị trí để xác định vị trí hiện tại của bạn.',
          description:
              'Bạn có thể nhấn nút bên dưới để yêu cầu quyền một lần nữa.',
          actionLabel: 'Lấy vị trí hiện tại',
          onAction: _getCurrentLocation,
        );
      case _LocationState.permissionDeniedForever:
        return _LocationMessage(
          icon: Icons.no_accounts_rounded,
          title: 'Quyền vị trí đã bị từ chối vĩnh viễn. Vui lòng cấp quyền trong Cài đặt.',
          description:
              'Sau khi cấp quyền, hãy quay lại ứng dụng và cập nhật vị trí.',
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
              'Vui lòng kiểm tra GPS và kết nối của thiết bị rồi thử lại.',
          actionLabel: 'Thử lại',
          onAction: _getCurrentLocation,
        );
      case _LocationState.initial:
        return _LocationMessage(
          icon: Icons.location_on_outlined,
          title: 'Chưa xác định vị trí',
          description:
              'Bạn chủ động chọn lấy vị trí hiện tại khi cần hỗ trợ định vị.',
          actionLabel: 'Lấy vị trí hiện tại',
          onAction: _getCurrentLocation,
        );
    }
  }

  void _handleMapTileError() {
    if (!mounted || _mapTileError) return;
    setState(() => _mapTileError = true);
  }
}

class _IntroCard extends StatelessWidget {
  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(22),
    decoration: BoxDecoration(
      color: const Color(0xFFE4F4F5),
      borderRadius: BorderRadius.circular(22),
    ),
    child: const Column(
      children: [
        Icon(Icons.location_on_rounded, size: 54, color: AppColors.primary),
        SizedBox(height: 12),
        Text(
          'Định vị bệnh nhân',
          style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800),
        ),
        SizedBox(height: 8),
        Text(
          'Xem vị trí hiện tại của bạn để hỗ trợ các chức năng định vị của Smart Hospital.',
          textAlign: TextAlign.center,
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
          'Đang xác định vị trí...',
          style: TextStyle(fontWeight: FontWeight.w700),
        ),
      ],
    ),
  );
}

class _LocationDetails extends StatelessWidget {
  const _LocationDetails({
    required this.location,
    required this.onRefresh,
    required this.hasMapTileError,
    required this.onMapTileError,
  });

  final PatientLocation location;
  final Future<void> Function() onRefresh;
  final bool hasMapTileError;
  final VoidCallback onMapTileError;

  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.stretch,
    children: [
      Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Vị trí hiện tại',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
            ),
            const SizedBox(height: 16),
            _LocationValue(
              label: 'Vĩ độ',
              value: location.latitude.toStringAsFixed(6),
            ),
            _LocationValue(
              label: 'Kinh độ',
              value: location.longitude.toStringAsFixed(6),
            ),
            _LocationValue(
              label: 'Độ chính xác',
              value: '${location.accuracy.toStringAsFixed(1)} m',
            ),
            _LocationValue(
              label: 'Cập nhật lúc',
              value: _formatTimestamp(location.timestamp),
            ),
          ],
        ),
      ),
      const SizedBox(height: 14),
      ClipRRect(
        borderRadius: BorderRadius.circular(16),
        child: SizedBox(
          height: 260,
          child: Stack(
            children: [
              FlutterMap(
                options: MapOptions(
                  initialCenter: LatLng(location.latitude, location.longitude),
                  initialZoom: 16,
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
                        width: 48,
                        height: 48,
                        child: const Icon(
                          Icons.location_on_rounded,
                          color: Colors.redAccent,
                          size: 44,
                        ),
                      ),
                    ],
                  ),
                  RichAttributionWidget(
                    attributions: [
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
                    color: Colors.white.withValues(alpha: 0.94),
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
                              'Không tải được nền bản đồ. Hãy kiểm tra Internet rồi cập nhật vị trí.',
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
      FilledButton.icon(
        onPressed: onRefresh,
        icon: const Icon(Icons.refresh_rounded),
        label: const Text('Cập nhật vị trí'),
      ),
    ],
  );
}

class _LocationValue extends StatelessWidget {
  const _LocationValue({required this.label, required this.value});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: Row(
      children: [
        Expanded(
          child: Text(
            label,
            style: const TextStyle(color: AppColors.mutedText),
          ),
        ),
        Text(value, style: const TextStyle(fontWeight: FontWeight.w700)),
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
  Widget build(BuildContext context) => Column(
    children: [
      Icon(icon, size: 76, color: AppColors.primary),
      const SizedBox(height: 16),
      Text(
        title,
        textAlign: TextAlign.center,
        style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800),
      ),
      const SizedBox(height: 8),
      Text(
        description,
        textAlign: TextAlign.center,
        style: const TextStyle(color: AppColors.mutedText, height: 1.4),
      ),
      const SizedBox(height: 24),
      FilledButton.icon(
        onPressed: onAction,
        icon: const Icon(Icons.my_location_rounded),
        label: Text(actionLabel),
      ),
      if (secondaryActionLabel != null && onSecondaryAction != null) ...[
        const SizedBox(height: 8),
        OutlinedButton(
          onPressed: onSecondaryAction,
          child: Text(secondaryActionLabel!),
        ),
      ],
    ],
  );
}

String _formatTimestamp(DateTime timestamp) {
  String value(int number) => number.toString().padLeft(2, '0');
  return '${value(timestamp.hour)}:${value(timestamp.minute)} - '
      '${value(timestamp.day)}/${value(timestamp.month)}/${timestamp.year}';
}

enum _LocationState {
  initial,
  serviceDisabled,
  permissionDenied,
  permissionDeniedForever,
  ready,
  error,
}
