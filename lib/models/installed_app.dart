import 'dart:convert';
import 'dart:typed_data';

class InstalledApp {
  final String name;
  final String packageName;
  final String? iconBase64;
  final bool isSystemApp;

  InstalledApp({
    required this.name,
    required this.packageName,
    this.iconBase64,
    this.isSystemApp = false,
  });

  Uint8List? get iconBytes {
    if (iconBase64 == null || iconBase64!.isEmpty) return null;
    try {
      return base64Decode(iconBase64!);
    } catch (_) {
      return null;
    }
  }

  factory InstalledApp.fromMap(Map<dynamic, dynamic> map) {
    return InstalledApp(
      name: map['name'] as String? ?? 'Unknown App',
      packageName: map['packageName'] as String? ?? '',
      iconBase64: map['icon'] as String?,
      isSystemApp: map['isSystemApp'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'name': name,
      'packageName': packageName,
      'icon': iconBase64,
      'isSystemApp': isSystemApp,
    };
  }
}
