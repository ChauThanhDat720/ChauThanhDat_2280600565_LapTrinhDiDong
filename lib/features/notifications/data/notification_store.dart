import 'package:flutter/foundation.dart';

import '../domain/notification_item.dart';

class NotificationStore extends ChangeNotifier {
  NotificationStore._() {
    _initDefaults();
  }

  static final NotificationStore instance = NotificationStore._();

  final List<AppNotification> _items = [];

  List<AppNotification> get items => List.unmodifiable(_items);

  int get unreadCount => _items.where((item) => !item.isRead).length;

  void _initDefaults() {
    final now = DateTime.now();
    _items.addAll([
      AppNotification(
        id: 'notif-1',
        title: 'Bác sĩ đã xác nhận lịch khám',
        body: 'BS. Trần Thảo Linh đã xác nhận lịch khám Chuyên khoa Nội của bạn vào 08:30 sáng mai.',
        createdAt: now.subtract(const Duration(minutes: 35)),
        type: NotificationType.appointment,
        referenceId: 'APT-01',
      ),
      AppNotification(
        id: 'notif-2',
        title: 'Đã có kết quả khám & Đơn thuốc',
        body: 'Ca khám trước đó của bạn đã có chẩn đoán và đơn thuốc điện tử. Bấm để xem chi tiết.',
        createdAt: now.subtract(const Duration(hours: 3)),
        type: NotificationType.prescription,
        referenceId: 'APT-02',
      ),
      AppNotification(
        id: 'notif-3',
        title: 'Nhắc nhở uống thuốc',
        body: 'Đã đến giờ uống thuốc chiều theo hướng dẫn của bác sĩ điều trị.',
        createdAt: now.subtract(const Duration(hours: 6)),
        type: NotificationType.reminder,
      ),
      AppNotification(
        id: 'notif-4',
        title: 'Chào mừng bạn đến với Smart Hospital',
        body: 'Hồ sơ sức khỏe của bạn đã sẵn sàng. Bạn có thể đặt lịch khám chuyên khoa ngay hôm nay.',
        createdAt: now.subtract(const Duration(days: 1)),
        isRead: true,
        type: NotificationType.system,
      ),
    ]);
  }

  void markAsRead(String id) {
    final index = _items.indexWhere((item) => item.id == id);
    if (index != -1 && !_items[index].isRead) {
      _items[index] = _items[index].copyWith(isRead: true);
      notifyListeners();
    }
  }

  void markAllAsRead() {
    bool changed = false;
    for (int i = 0; i < _items.length; i++) {
      if (!_items[i].isRead) {
        _items[i] = _items[i].copyWith(isRead: true);
        changed = true;
      }
    }
    if (changed) notifyListeners();
  }

  void removeNotification(String id) {
    _items.removeWhere((item) => item.id == id);
    notifyListeners();
  }

  void addNotification({
    required String title,
    required String body,
    NotificationType type = NotificationType.system,
    String? referenceId,
  }) {
    _items.insert(
      0,
      AppNotification(
        id: 'notif-${DateTime.now().millisecondsSinceEpoch}',
        title: title,
        body: body,
        createdAt: DateTime.now(),
        type: type,
        referenceId: referenceId,
      ),
    );
    notifyListeners();
  }
}
