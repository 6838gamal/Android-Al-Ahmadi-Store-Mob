import 'dart:async';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../network/api_client.dart';

enum ServerStatus { checking, online, offline }

class ServerHealthState {
  final ServerStatus status;
  final int retryCount;
  final DateTime? lastChecked;

  const ServerHealthState({
    this.status = ServerStatus.checking,
    this.retryCount = 0,
    this.lastChecked,
  });

  ServerHealthState copyWith({
    ServerStatus? status,
    int? retryCount,
    DateTime? lastChecked,
  }) =>
      ServerHealthState(
        status: status ?? this.status,
        retryCount: retryCount ?? this.retryCount,
        lastChecked: lastChecked ?? this.lastChecked,
      );

  bool get isOnline => status == ServerStatus.online;
  bool get isOffline => status == ServerStatus.offline;
  bool get isChecking => status == ServerStatus.checking;
}

class ServerHealthNotifier extends StateNotifier<ServerHealthState> {
  final Ref _ref;
  Timer? _pollingTimer;
  bool _disposed = false;

  static const Duration _pollInterval = Duration(seconds: 30);
  static const Duration _offlineRetryInterval = Duration(seconds: 8);

  ServerHealthNotifier(this._ref) : super(const ServerHealthState());

  void startMonitoring() {
    _check();
    _scheduleNext();
  }

  void _scheduleNext() {
    _pollingTimer?.cancel();
    final interval =
        state.isOffline ? _offlineRetryInterval : _pollInterval;
    _pollingTimer = Timer(interval, () {
      if (!_disposed) {
        _check();
        _scheduleNext();
      }
    });
  }

  Future<void> _check() async {
    if (_disposed) return;
    final wasOffline = state.isOffline;
    if (wasOffline) {
      state = state.copyWith(
        status: ServerStatus.checking,
        retryCount: state.retryCount + 1,
      );
    }
    try {
      final api = _ref.read(apiClientProvider);
      await api.get('/health', queryParameters: {});
      if (!_disposed) {
        state = state.copyWith(
          status: ServerStatus.online,
          retryCount: 0,
          lastChecked: DateTime.now(),
        );
        if (wasOffline) _scheduleNext();
      }
    } catch (_) {
      if (!_disposed) {
        state = state.copyWith(
          status: ServerStatus.offline,
          lastChecked: DateTime.now(),
        );
        _scheduleNext();
      }
    }
  }

  Future<void> retryNow() async {
    _pollingTimer?.cancel();
    state = state.copyWith(status: ServerStatus.checking, retryCount: 0);
    await _check();
    if (!_disposed && !state.isOnline) _scheduleNext();
  }

  @override
  void dispose() {
    _disposed = true;
    _pollingTimer?.cancel();
    super.dispose();
  }
}

final serverHealthProvider =
    StateNotifierProvider<ServerHealthNotifier, ServerHealthState>((ref) {
  final notifier = ServerHealthNotifier(ref);
  notifier.startMonitoring();
  return notifier;
});
