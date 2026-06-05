// Web implementation — uses dart:js_util to call window.firebasePhoneAuth
import 'dart:async';
import 'dart:convert';
// ignore: avoid_web_libraries_in_flutter
import 'dart:js_util' as js_util;
// ignore: avoid_web_libraries_in_flutter
import 'dart:js' as js;

Future<Map<String, dynamic>> jsBridgeCall(
    String method, Map<String, dynamic> args) async {
  final argsJson = jsonEncode(args);
  final cbKey = '_fb_${method}_${DateTime.now().millisecondsSinceEpoch}';

  // Run the async JS call; result is stored in window[cbKey]
  js.context.callMethod('eval', ['''
(async () => {
  try {
    const args = $argsJson;
    let result;
    switch ("$method") {
      case "init":
        result = await window.firebasePhoneAuth.init(args);
        break;
      case "sendOtp":
        result = await window.firebasePhoneAuth.sendOtp(args.phone);
        break;
      case "verifyOtp":
        result = await window.firebasePhoneAuth.verifyOtp(args.code);
        break;
      default:
        result = {ok: false, error: "unknown method: $method"};
    }
    window["$cbKey"] = JSON.stringify(result);
  } catch(e) {
    window["$cbKey"] = JSON.stringify({ok: false, error: String(e)});
  }
})();
''']);

  // Poll until JS writes the result (max 60 s)
  for (int i = 0; i < 600; i++) {
    await Future.delayed(const Duration(milliseconds: 100));
    final raw = js_util.getProperty<Object?>(js.context, cbKey);
    if (raw != null) {
      js_util.setProperty(js.context, cbKey, null);
      try {
        return jsonDecode(raw.toString()) as Map<String, dynamic>;
      } catch (_) {
        return {'ok': false, 'error': 'JSON parse error'};
      }
    }
  }
  return {'ok': false, 'error': 'Firebase bridge timeout'};
}
