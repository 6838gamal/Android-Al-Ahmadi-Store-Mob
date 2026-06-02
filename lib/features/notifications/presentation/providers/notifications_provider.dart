import 'dart:async';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../../core/network/api_client.dart';

class NotificationsState {
  final List<Map<String, dynamic>> notifications;
  final int unreadCount;
  final bool isLoading;
  final String? error;

  const NotificationsState({
    this.notifications = const [],
    this.unreadCount = 0,
    this.isLoading = false,
    this.error,
  });

  NotificationsState copyWith({
    List<Map<String, dynamic>>? notifications,
    int? unreadCount,
    bool? isLoading,
    String? error,
  }) =>
      NotificationsState(
        notifications: notifications ?? this.notifications,
        unreadCount: unreadCount ?? this.unreadCount,
        isLoading: isLoading ?? this.isLoading,
        error: error,
      );
}

class NotificationsNotifier extends StateNotifier<NotificationsState> {
  final ApiClient _api;
  Timer? _pollTimer;

  NotificationsNotifier(this._api) : super(const NotificationsState());

  /// Start polling — call once on app init for authenticated users.
  void startPolling() {
    _pollTimer?.cancel();
    load(silent: true);
    _pollTimer = Timer.periodic(const Duration(seconds: 60), (_) {
      load(silent: true);
    });
  }

  void stopPolling() {
    _pollTimer?.cancel();
    _pollTimer = null;
  }

  Future<void> load({bool silent = false}) async {
    if (!silent) state = state.copyWith(isLoading: true, error: null);
    try {
      final res = await _api.get('/notifications/my');
      final list = List<Map<String, dynamic>>.from(res.data);
      final unread = list.where((n) => n['is_read'] == false).length;
      state = state.copyWith(
        notifications: list,
        unreadCount: unread,
        isLoading: false,
      );
    } catch (e) {
      if (!silent) {
        state = state.copyWith(isLoading: false, error: 'فشل تحميل الإشعارات');
      }
    }
  }

  Future<void> markRead(int notifId) async {
    try {
      await _api.post('/notifications/$notifId/read');
      final updated = state.notifications.map((n) {
        if (n['id'] == notifId) return {...n, 'is_read': true};
        return n;
      }).toList();
      final unread = updated.where((n) => n['is_read'] == false).length;
      state = state.copyWith(notifications: updated, unreadCount: unread);
    } catch (_) {}
  }

  Future<void> markAllRead() async {
    try {
      await _api.post('/notifications/read-all');
      final updated = state.notifications
          .map((n) => {...n, 'is_read': true})
          .toList();
      state = state.copyWith(notifications: updated, unreadCount: 0);
    } catch (_) {}
  }

  @override
  void dispose() {
    _pollTimer?.cancel();
    super.dispose();
  }
}

final notificationsProvider =
    StateNotifierProvider<NotificationsNotifier, NotificationsState>((ref) {
  return NotificationsNotifier(ref.read(apiClientProvider));
});
