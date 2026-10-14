import 'package:flutter/material.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/utils/app_timezone.dart';
import '../../doctors/presentation/doctor_screens.dart';
import '../data/appointment_repository.dart';
import '../domain/appointment.dart';

class AppointmentListScreen extends StatefulWidget {
  const AppointmentListScreen({
    super.key,
    this.showAppBar = true,
    this.repository = const LocalAppointmentRepository(),
  });
  final bool showAppBar;
  final AppointmentRepository repository;
  @override
  State<AppointmentListScreen> createState() => _AppointmentListScreenState();
}

class _AppointmentListScreenState extends State<AppointmentListScreen> {
  List<Appointment>? _items;
  Object? _error;
  bool _loading = true;
  bool get _demo => widget.repository is LocalAppointmentRepository;
  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final value = await widget.repository.getMyAppointments();
      if (mounted) setState(() => _items = value);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = _body(context);
    return widget.showAppBar
        ? Scaffold(
            appBar: AppBar(title: const Text('Lịch khám của tôi')),
            body: body,
          )
        : body;
  }

  Widget _body(BuildContext context) {
    if (_loading) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(),
            SizedBox(height: 12),
            Text('Đang tải lịch khám...'),
          ],
        ),
      );
    }
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text('Không thể tải lịch khám.'),
            TextButton(onPressed: _load, child: const Text('Thử lại')),
          ],
        ),
      );
    }
    final items = _items!;
    if (items.isEmpty) {
      return Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.calendar_month_outlined,
              size: 64,
              color: AppColors.primary,
            ),
            const SizedBox(height: 16),
            const Text('Bạn chưa có lịch khám nào.'),
            const SizedBox(height: 16),
            ElevatedButton(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const DoctorListScreen()),
              ),
              child: const Text('Đặt lịch khám'),
            ),
          ],
        ),
      );
    }
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.all(20),
        itemCount: items.length + 1,
        separatorBuilder: (_, _) => const SizedBox(height: 12),
        itemBuilder: (context, index) {
          if (index == 0) {
            return Row(
              children: [
                if (_demo) const Chip(label: Text('Chế độ demo')),
                const Spacer(),
                Text('${items.length} lịch khám'),
              ],
            );
          }
          final appointment = items[index - 1];
          return _AppointmentCard(
            appointment: appointment,
            onTap: () async {
              await Navigator.of(context).push(
                MaterialPageRoute(
                  builder: (_) => AppointmentDetailScreen(
                    appointment: appointment,
                    repository: widget.repository,
                  ),
                ),
              );
              if (mounted) _load();
            },
          );
        },
      ),
    );
  }
}

class AppointmentDetailScreen extends StatefulWidget {
  const AppointmentDetailScreen({
    super.key,
    required this.appointment,
    required this.repository,
  });
  final Appointment appointment;
  final AppointmentRepository repository;
  @override
  State<AppointmentDetailScreen> createState() =>
      _AppointmentDetailScreenState();
}

class _AppointmentDetailScreenState extends State<AppointmentDetailScreen> {
  late Appointment _appointment = widget.appointment;
  bool _cancelling = false;
  bool get _canCancel =>
      _appointment.status == AppointmentStatus.pending ||
      _appointment.status == AppointmentStatus.confirmed;
  Future<void> _cancel() async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Hủy lịch khám'),
        content: const Text('Bạn có chắc chắn muốn hủy lịch khám này?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Quay lại'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Xác nhận hủy'),
          ),
        ],
      ),
    );
    if (ok != true || _cancelling) return;
    setState(() => _cancelling = true);
    try {
      final updated = await widget.repository.cancelAppointment(
        _appointment.id,
      );
      if (mounted) {
        setState(() => _appointment = updated);
        ScaffoldMessenger.of(context)
            .showSnackBar(const SnackBar(content: Text('Đã hủy lịch khám.')));
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Không thể hủy lịch khám.')),
        );
      }
    } finally {
      if (mounted) setState(() => _cancelling = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(title: const Text('Chi tiết lịch khám')),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        Text(
          'Mã lịch: ${_appointment.id}',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const SizedBox(height: 16),
        _line('Bác sĩ', _appointment.doctorName),
        _line('Khoa khám', _appointment.department),
        _line('Ngày khám', AppTimezone.date(_appointment.date)),
        _line(
          'Giờ khám',
          AppTimezone.range(_appointment.startTime, _appointment.endTime),
        ),
        _line('Lý do khám', _appointment.reason),
        _line('Trạng thái', _appointment.status.label),
        if (_appointment.createdAt != null)
          _line(
            'Tạo lúc',
            '${AppTimezone.date(_appointment.createdAt!)} ${AppTimezone.time(_appointment.createdAt!)}',
          ),
        if (_appointment.cancelledAt != null)
          _line(
            'Hủy lúc',
            '${AppTimezone.date(_appointment.cancelledAt!)} ${AppTimezone.time(_appointment.cancelledAt!)}',
          ),
        if (_appointment.cancellationReason?.isNotEmpty == true)
          _line('Lý do hủy', _appointment.cancellationReason!),
        const SizedBox(height: 24),
        if (_canCancel)
          ElevatedButton.icon(
            onPressed: _cancelling ? null : _cancel,
            icon: const Icon(Icons.cancel_outlined),
            label: Text(_cancelling ? 'Đang hủy...' : 'Hủy lịch khám'),
          ),
      ],
    ),
  );
  Widget _line(String title, String value) => Padding(
    padding: const EdgeInsets.only(bottom: 12),
    child: ListTile(
      contentPadding: EdgeInsets.zero,
      title: Text(title),
      subtitle: Text(value.isEmpty ? 'Chưa cập nhật' : value),
    ),
  );
}

class _AppointmentCard extends StatelessWidget {
  const _AppointmentCard({required this.appointment, required this.onTap});
  final Appointment appointment;
  final VoidCallback onTap;
  @override
  Widget build(BuildContext context) => Card(
    child: ListTile(
      onTap: onTap,
      title: Text(appointment.doctorName),
      subtitle: Text(
        '${appointment.department}\n${appointment.dateLabel} • ${appointment.time}\nMã lịch: ${appointment.id}',
      ),
      isThreeLine: true,
      trailing: Chip(label: Text(appointment.status.label)),
    ),
  );
}
