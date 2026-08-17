import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/vpn_config.dart';

class ConfigStorage {
  static const _kServerName = 'vpn_server_name';
  static const _kServerEndpoint = 'vpn_server_endpoint';
  static const _kServerPublicKey = 'vpn_server_public_key';
  static const _kClientAddress = 'vpn_client_address';
  static const _kDns = 'vpn_dns';
  static const _kSelectedApps = 'vpn_selected_apps';
  static const _kClientPrivateKeySecKey = 'vpn_client_private_key';

  final FlutterSecureStorage _secureStorage = const FlutterSecureStorage();

  Future<VpnConfig> loadConfig() async {
    final prefs = await SharedPreferences.getInstance();
    final privateKey =
        await _secureStorage.read(key: _kClientPrivateKeySecKey) ?? '';

    return VpnConfig(
      serverName: prefs.getString(_kServerName) ?? 'Ubuntu VPS',
      serverEndpoint: prefs.getString(_kServerEndpoint) ?? '',
      serverPublicKey: prefs.getString(_kServerPublicKey) ?? '',
      clientAddress: prefs.getString(_kClientAddress) ?? '10.8.0.2/32',
      clientPrivateKey: privateKey,
      dns: prefs.getString(_kDns) ?? '1.1.1.1',
    );
  }

  Future<void> saveConfig(VpnConfig config) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kServerName, config.serverName);
    await prefs.setString(_kServerEndpoint, config.serverEndpoint);
    await prefs.setString(_kServerPublicKey, config.serverPublicKey);
    await prefs.setString(_kClientAddress, config.clientAddress);
    await prefs.setString(_kDns, config.dns);

    await _secureStorage.write(
      key: _kClientPrivateKeySecKey,
      value: config.clientPrivateKey,
    );
  }

  Future<Set<String>> loadSelectedApps() async {
    final prefs = await SharedPreferences.getInstance();
    final list = prefs.getStringList(_kSelectedApps);
    return list != null ? list.toSet() : <String>{};
  }

  Future<void> saveSelectedApps(Set<String> selectedApps) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_kSelectedApps, selectedApps.toList());
  }

  Future<void> clearAll() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_kServerName);
    await prefs.remove(_kServerEndpoint);
    await prefs.remove(_kServerPublicKey);
    await prefs.remove(_kClientAddress);
    await prefs.remove(_kDns);
    await prefs.remove(_kSelectedApps);
    await _secureStorage.delete(key: _kClientPrivateKeySecKey);
  }
}
