import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:dio/dio.dart';

import 'firebase_js_bridge.dart'
    if (dart.library.html) 'firebase_js_bridge_web.dart';

class OtpResult {
  final bool ok;
  final String? error;
  final String? idToken;
  final String? phone;

  const OtpResult({required this.ok, this.error, this.idToken, this.phone});
}

/// Firebase phone auth service.
/// On Flutter Web, delegates to window.firebasePhoneAuth (defined in index.html)
/// via a JS bridge. On other platforms returns unsupported.
class FirebasePhoneService {
  bool _initialised = false;

  Future<OtpResult> init() async {
    if (!kIsWeb) return const OtpResult(ok: false, error: 'Web only');
    if (_initialised) return const OtpResult(ok: true);
    try {
      final dio = Dio(BaseOptions(connectTimeout: const Duration(seconds: 10)));
      final resp = await dio.get('/firebase-config');
      final config = Map<String, dynamic>.from(resp.data as Map);
      final res = await jsBridgeCall('init', config);
      if (res['ok'] == true) _initialised = true;
      return OtpResult(ok: res['ok'] == true, error: res['error'] as String?);
    } catch (e) {
      return OtpResult(ok: false, error: 'خطأ في تهيئة Firebase: $e');
    }
  }

  Future<OtpResult> sendOtp(String phoneNumber) async {
    if (!kIsWeb) return const OtpResult(ok: false, error: 'Web only');
    final i = await init();
    if (!i.ok) return i;
    final res = await jsBridgeCall('sendOtp', {'phone': phoneNumber});
    return OtpResult(ok: res['ok'] == true, error: res['error'] as String?);
  }

  Future<OtpResult> verifyOtp(String code) async {
    if (!kIsWeb) return const OtpResult(ok: false, error: 'Web only');
    final res = await jsBridgeCall('verifyOtp', {'code': code});
    return OtpResult(
      ok: res['ok'] == true,
      error: res['error'] as String?,
      idToken: res['idToken'] as String?,
      phone: res['phone'] as String?,
    );
  }
}

final firebasePhoneServiceProvider = Provider<FirebasePhoneService>((ref) {
  return FirebasePhoneService();
});
