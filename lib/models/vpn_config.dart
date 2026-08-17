import 'dart:convert';

class VpnConfig {
  final String serverName;
  final String serverEndpoint; // IP:Port e.g. 198.51.100.1:51820
  final String serverPublicKey;
  final String clientAddress; // e.g. 10.8.0.2/32
  final String clientPrivateKey;
  final String dns;

  const VpnConfig({
    this.serverName = 'Ubuntu VPS',
    this.serverEndpoint = '',
    this.serverPublicKey = '',
    this.clientAddress = '10.8.0.2/32',
    this.clientPrivateKey = '',
    this.dns = '1.1.1.1',
  });

  bool get isValid =>
      serverEndpoint.trim().isNotEmpty &&
      serverPublicKey.trim().isNotEmpty &&
      clientPrivateKey.trim().isNotEmpty &&
      clientAddress.trim().isNotEmpty;

  VpnConfig copyWith({
    String? serverName,
    String? serverEndpoint,
    String? serverPublicKey,
    String? clientAddress,
    String? clientPrivateKey,
    String? dns,
  }) {
    return VpnConfig(
      serverName: serverName ?? this.serverName,
      serverEndpoint: serverEndpoint ?? this.serverEndpoint,
      serverPublicKey: serverPublicKey ?? this.serverPublicKey,
      clientAddress: clientAddress ?? this.clientAddress,
      clientPrivateKey: clientPrivateKey ?? this.clientPrivateKey,
      dns: dns ?? this.dns,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'serverName': serverName,
      'serverEndpoint': serverEndpoint,
      'serverPublicKey': serverPublicKey,
      'clientAddress': clientAddress,
      'clientPrivateKey': clientPrivateKey,
      'dns': dns,
    };
  }

  factory VpnConfig.fromMap(Map<String, dynamic> map) {
    return VpnConfig(
      serverName: map['serverName'] as String? ?? 'Ubuntu VPS',
      serverEndpoint: map['serverEndpoint'] as String? ?? '',
      serverPublicKey: map['serverPublicKey'] as String? ?? '',
      clientAddress: map['clientAddress'] as String? ?? '10.8.0.2/32',
      clientPrivateKey: map['clientPrivateKey'] as String? ?? '',
      dns: map['dns'] as String? ?? '1.1.1.1',
    );
  }

  String toJson() => json.encode(toMap());

  factory VpnConfig.fromJson(String source) =>
      VpnConfig.fromMap(json.decode(source) as Map<String, dynamic>);

  /// Exports standard wg-quick config string
  String toWgQuick() {
    return '''[Interface]
PrivateKey = $clientPrivateKey
Address = $clientAddress
DNS = $dns

[Peer]
PublicKey = $serverPublicKey
Endpoint = $serverEndpoint
AllowedIPs = 0.0.0.0/0, ::/0
PersistentKeepalive = 25
''';
  }

  /// Parses standard wg-quick config string
  factory VpnConfig.fromWgQuick(String conf) {
    String privateKey = '';
    String address = '10.8.0.2/32';
    String dns = '1.1.1.1';
    String publicKey = '';
    String endpoint = '';

    final lines = conf.split(RegExp(r'\r?\n'));
    for (final line in lines) {
      final trimmed = line.trim();
      if (trimmed.startsWith('#') || !trimmed.contains('=')) continue;

      final parts = trimmed.split('=');
      final key = parts[0].trim().toLowerCase();
      final value = parts.sublist(1).join('=').trim();

      switch (key) {
        case 'privatekey':
          privateKey = value;
          break;
        case 'address':
          address = value;
          break;
        case 'dns':
          dns = value;
          break;
        case 'publickey':
          publicKey = value;
          break;
        case 'endpoint':
          endpoint = value;
          break;
      }
    }

    return VpnConfig(
      clientPrivateKey: privateKey,
      clientAddress: address,
      dns: dns,
      serverPublicKey: publicKey,
      serverEndpoint: endpoint,
    );
  }
}
