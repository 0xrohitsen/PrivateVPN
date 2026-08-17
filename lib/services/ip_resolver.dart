import 'dart:async';
import 'package:http/http.dart' as http;

class IpResolver {
  static const List<String> _endpoints = [
    'https://api.ipify.org',
    'https://icanhazip.com',
    'https://ifconfig.me/ip',
  ];

  static Future<String?> resolvePublicIp() async {
    for (final url in _endpoints) {
      try {
        final response = await http
            .get(Uri.parse(url))
            .timeout(const Duration(seconds: 4));
        if (response.statusCode == 200) {
          final ip = response.body.trim();
          if (ip.isNotEmpty && ip.length <= 45) {
            return ip;
          }
        }
      } catch (_) {
        // Try next endpoint
      }
    }
    return null;
  }
}
