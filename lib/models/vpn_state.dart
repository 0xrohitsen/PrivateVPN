enum VpnStatus {
  disconnected,
  connecting,
  connected,
  error,
}

extension VpnStatusExtension on VpnStatus {
  String get label {
    switch (this) {
      case VpnStatus.disconnected:
        return 'OFFLINE';
      case VpnStatus.connecting:
        return 'CONNECTING';
      case VpnStatus.connected:
        return 'CONNECTED';
      case VpnStatus.error:
        return 'CONNECTION FAILED';
    }
  }

  bool get isConnected => this == VpnStatus.connected;
  bool get isConnecting => this == VpnStatus.connecting;
  bool get isDisconnected => this == VpnStatus.disconnected;
  bool get isError => this == VpnStatus.error;
}
