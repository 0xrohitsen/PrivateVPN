import 'dart:async';
import 'package:flutter/services.dart';
import '../models/installed_app.dart';
import '../models/vpn_config.dart';

class VpnBridge {
  static const MethodChannel _methodChannel =
      MethodChannel('com.example.privatecpn/vpn_methods');
  static const EventChannel _eventChannel =
      EventChannel('com.example.privatecpn/vpn_events');

  Stream<String>? _vpnStateStream;

  Stream<String> get vpnStateStream {
    _vpnStateStream ??= _eventChannel
        .receiveBroadcastStream()
        .map((event) => event.toString());
    return _vpnStateStream!;
  }

  Future<bool> prepareVpn() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('prepareVpn');
      return result ?? false;
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('prepareVpn error: ${e.message}');
      return false;
    }
  }

  Future<bool> startTunnel({
    required VpnConfig config,
    required List<String> selectedApps,
  }) async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('startTunnel', {
        'config': config.toMap(),
        'selectedApps': selectedApps,
      });
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Failed to start VPN tunnel');
    }
  }

  Future<bool> stopTunnel() async {
    try {
      final result = await _methodChannel.invokeMethod<bool>('stopTunnel');
      return result ?? false;
    } on PlatformException catch (e) {
      throw Exception(e.message ?? 'Failed to stop VPN tunnel');
    }
  }

  Future<String> getTunnelState() async {
    try {
      final result =
          await _methodChannel.invokeMethod<String>('getTunnelState');
      return result ?? 'disconnected';
    } catch (_) {
      return 'disconnected';
    }
  }

  Future<List<InstalledApp>> getInstalledApps() async {
    try {
      final result = await _methodChannel
          .invokeListMethod<Map<dynamic, dynamic>>('getInstalledApps');
      if (result == null) return [];
      return result.map((m) => InstalledApp.fromMap(m)).toList();
    } on PlatformException catch (e) {
      // ignore: avoid_print
      print('getInstalledApps error: ${e.message}');
      return [];
    }
  }

  Future<Map<String, String>> generateKeyPair() async {
    try {
      final result = await _methodChannel
          .invokeMapMethod<String, String>('generateKeyPair');
      return result ?? {};
    } catch (e) {
      // ignore: avoid_print
      print('generateKeyPair error: $e');
      return {};
    }
  }
}
