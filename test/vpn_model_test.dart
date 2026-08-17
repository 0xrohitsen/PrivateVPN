import 'package:flutter_test/flutter_test.dart';
import 'package:privatecpn/models/installed_app.dart';
import 'package:privatecpn/models/vpn_config.dart';
import 'package:privatecpn/models/vpn_state.dart';

void main() {
  group('VpnConfig Model Tests', () {
    test('isValid returns true for complete config', () {
      const config = VpnConfig(
        serverName: 'VPS 1',
        serverEndpoint: '198.51.100.1:51820',
        serverPublicKey: 'dGVzdF9wdWJsaWNfa2V5XzEyMzQ1Njc4OTAxMjM0NTY=',
        clientAddress: '10.8.0.2/32',
        clientPrivateKey: 'dGVzdF9wcml2YXRlX2tleV8xMjM0NTY3ODkwMTIzNDU2',
        dns: '1.1.1.1',
      );
      expect(config.isValid, isTrue);
    });

    test('isValid returns false for missing fields', () {
      const config = VpnConfig(
        serverEndpoint: '',
        serverPublicKey: 'test',
      );
      expect(config.isValid, isFalse);
    });

    test('WgQuick serialization and deserialization roundtrip', () {
      const original = VpnConfig(
        serverName: 'Ubuntu VPS',
        serverEndpoint: '1.2.3.4:51820',
        serverPublicKey: 'serverPubKey123=',
        clientAddress: '10.8.0.2/32',
        clientPrivateKey: 'clientPrivKey123=',
        dns: '1.1.1.1',
      );

      final wgQuickStr = original.toWgQuick();
      expect(wgQuickStr, contains('PrivateKey = clientPrivKey123='));
      expect(wgQuickStr, contains('Endpoint = 1.2.3.4:51820'));

      final parsed = VpnConfig.fromWgQuick(wgQuickStr);
      expect(parsed.clientPrivateKey, original.clientPrivateKey);
      expect(parsed.serverPublicKey, original.serverPublicKey);
      expect(parsed.serverEndpoint, original.serverEndpoint);
      expect(parsed.clientAddress, original.clientAddress);
      expect(parsed.dns, original.dns);
    });

    test('JSON serialization roundtrip', () {
      const config = VpnConfig(
        serverName: 'VPS Tokyo',
        serverEndpoint: '192.0.2.1:51820',
        serverPublicKey: 'pubkey123',
        clientAddress: '10.8.0.5/32',
        clientPrivateKey: 'privkey123',
        dns: '8.8.8.8',
      );

      final jsonStr = config.toJson();
      final decoded = VpnConfig.fromJson(jsonStr);

      expect(decoded.serverName, config.serverName);
      expect(decoded.serverEndpoint, config.serverEndpoint);
      expect(decoded.serverPublicKey, config.serverPublicKey);
      expect(decoded.clientAddress, config.clientAddress);
      expect(decoded.clientPrivateKey, config.clientPrivateKey);
      expect(decoded.dns, config.dns);
    });
  });

  group('VpnStatus Extension Tests', () {
    test('Labels and boolean checks are correct', () {
      expect(VpnStatus.disconnected.label, 'OFFLINE');
      expect(VpnStatus.disconnected.isDisconnected, isTrue);
      expect(VpnStatus.disconnected.isConnected, isFalse);

      expect(VpnStatus.connecting.label, 'CONNECTING');
      expect(VpnStatus.connecting.isConnecting, isTrue);

      expect(VpnStatus.connected.label, 'CONNECTED');
      expect(VpnStatus.connected.isConnected, isTrue);

      expect(VpnStatus.error.label, 'CONNECTION FAILED');
      expect(VpnStatus.error.isError, isTrue);
    });
  });

  group('InstalledApp Model Tests', () {
    test('Correctly decodes map and properties', () {
      final app = InstalledApp.fromMap({
        'name': 'Chrome',
        'packageName': 'com.android.chrome',
        'icon': '',
        'isSystemApp': true,
      });

      expect(app.name, 'Chrome');
      expect(app.packageName, 'com.android.chrome');
      expect(app.isSystemApp, isTrue);
      expect(app.iconBytes, isNull);
    });
  });
}
