// Stub for non-web platforms
Future<Map<String, dynamic>> jsBridgeCall(
    String method, Map<String, dynamic> args) async {
  return {'ok': false, 'error': 'not supported on this platform'};
}
