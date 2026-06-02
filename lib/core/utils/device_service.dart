import 'package:shared_preferences/shared_preferences.dart';
import 'package:uuid/uuid.dart';

/// Generates a persistent pseudo-device fingerprint stored in SharedPreferences.
/// Used for anti-fraud checks in the referral system.
class DeviceService {
  static const _key = 'device_fingerprint_v1';
  static const _uuid = Uuid();

  static Future<String> getFingerprint() async {
    final prefs = await SharedPreferences.getInstance();
    var fp = prefs.getString(_key);
    if (fp == null) {
      fp = _uuid.v4();
      await prefs.setString(_key, fp);
    }
    return fp;
  }
}
