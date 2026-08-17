import 'dart:async';
import 'package:flutter/foundation.dart';
import '../models/installed_app.dart';
import '../models/vpn_config.dart';
import '../models/vpn_state.dart';
import '../services/config_storage.dart';
import '../services/ip_resolver.dart';
import '../services/vpn_bridge.dart';

class VpnController extends ChangeNotifier {
  final VpnBridge _bridge = VpnBridge();
  final ConfigStorage _storage = ConfigStorage();

  VpnStatus _status = VpnStatus.disconnected;
  VpnStatus get status => _status;

  VpnConfig _config = const VpnConfig();
  VpnConfig get config => _config;

  Set<String> _selectedApps = {};
  Set<String> get selectedApps => _selectedApps;

  List<InstalledApp> _installedApps = [];
  List<InstalledApp> get installedApps => _installedApps;
  bool _isLoadingApps = false;
  bool get isLoadingApps => _isLoadingApps;

  String? _publicIp;
  String? get publicIp => _publicIp;

  bool _isResolvingIp = false;
  bool get isResolvingIp => _isResolvingIp;

  String? _errorMessage;
  String? get errorMessage => _errorMessage;

  Duration _connectedDuration = Duration.zero;
  Duration get connectedDuration => _connectedDuration;

  Timer? _durationTimer;
  StreamSubscription<String>? _stateSubscription;
  bool _isInitialized = false;
  bool get isInitialized => _isInitialized;

  VpnController() {
    _init();
  }

  Future<void> _init() async {
    _config = await _storage.loadConfig();
    _selectedApps = await _storage.loadSelectedApps();

    // Listen to native VPN state changes
    _stateSubscription = _bridge.vpnStateStream.listen(_onNativeStateChange);

    // Short delay so the GoBackend has time to initialize and probe the
    // existing tunnel state correctly after an app restart / kill & reopen.
    await Future.delayed(const Duration(milliseconds: 600));

    // Fetch initial state — this now correctly recovers "connected" if
    // WireGuard was already running before the app was reopened.
    final initialNativeState = await _bridge.getTunnelState();
    _handleStatusTransition(_mapStateStringToStatus(initialNativeState));

    _isInitialized = true;
    notifyListeners();

    // Load installed apps
    loadInstalledApps();
  }

  VpnStatus _mapStateStringToStatus(String state) {
    switch (state.toLowerCase()) {
      case 'connected':
      case 'up':
        return VpnStatus.connected;
      case 'connecting':
      case 'toggle':
        return VpnStatus.connecting;
      case 'disconnected':
      case 'down':
      default:
        return VpnStatus.disconnected;
    }
  }

  void _onNativeStateChange(String stateStr) {
    final newStatus = _mapStateStringToStatus(stateStr);
    _handleStatusTransition(newStatus);
  }

  void _handleStatusTransition(VpnStatus newStatus) {
    if (_status == newStatus && newStatus != VpnStatus.connected) return;

    _status = newStatus;
    if (newStatus == VpnStatus.connected) {
      _startTimer();
      _resolveIp();
      _errorMessage = null;
    } else {
      _stopTimer();
      if (newStatus == VpnStatus.disconnected) {
        _publicIp = null;
      }
    }
    notifyListeners();
  }

  void _startTimer() {
    _durationTimer?.cancel();
    _connectedDuration = Duration.zero;
    _durationTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      _connectedDuration += const Duration(seconds: 1);
      notifyListeners();
    });
  }

  void _stopTimer() {
    _durationTimer?.cancel();
    _durationTimer = null;
    _connectedDuration = Duration.zero;
  }

  Future<void> _resolveIp() async {
    _isResolvingIp = true;
    notifyListeners();
    try {
      final ip = await IpResolver.resolvePublicIp();
      if (_status == VpnStatus.connected) {
        _publicIp = ip ?? 'Unknown';
      }
    } finally {
      _isResolvingIp = false;
      notifyListeners();
    }
  }

  Future<void> loadInstalledApps() async {
    _isLoadingApps = true;
    notifyListeners();
    try {
      _installedApps = await _bridge.getInstalledApps();
    } finally {
      _isLoadingApps = false;
      notifyListeners();
    }
  }

  Future<void> toggleAppSelection(String packageName) async {
    if (_selectedApps.contains(packageName)) {
      _selectedApps.remove(packageName);
    } else {
      _selectedApps.add(packageName);
    }
    await _storage.saveSelectedApps(_selectedApps);
    notifyListeners();
  }

  Future<void> selectAllApps() async {
    _selectedApps = _installedApps.map((a) => a.packageName).toSet();
    await _storage.saveSelectedApps(_selectedApps);
    notifyListeners();
  }

  Future<void> deselectAllApps() async {
    _selectedApps.clear();
    await _storage.saveSelectedApps(_selectedApps);
    notifyListeners();
  }

  Future<void> updateConfig(VpnConfig newConfig) async {
    _config = newConfig;
    await _storage.saveConfig(newConfig);
    notifyListeners();
  }

  Future<void> generateNewKeys() async {
    final keys = await _bridge.generateKeyPair();
    if (keys.containsKey('privateKey') && keys['privateKey']!.isNotEmpty) {
      _config = _config.copyWith(
        clientPrivateKey: keys['privateKey'],
      );
      await _storage.saveConfig(_config);
      notifyListeners();
    }
  }

  Future<void> connect() async {
    if (!_config.isValid) {
      _status = VpnStatus.error;
      _errorMessage =
          'Incomplete configuration. Please fill in Server Endpoint, Server Public Key, and Client Private Key.';
      notifyListeners();
      return;
    }

    _status = VpnStatus.connecting;
    _errorMessage = null;
    notifyListeners();

    try {
      final isPrepared = await _bridge.prepareVpn();
      if (!isPrepared) {
        _status = VpnStatus.disconnected;
        _errorMessage = 'VPN permission was not granted.';
        notifyListeners();
        return;
      }

      await _bridge.startTunnel(
        config: _config,
        selectedApps: _selectedApps.toList(),
      );
    } catch (e) {
      _status = VpnStatus.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
      notifyListeners();
    }
  }

  Future<void> disconnect() async {
    _status = VpnStatus.connecting;
    notifyListeners();
    try {
      await _bridge.stopTunnel();
      _status = VpnStatus.disconnected;
      _errorMessage = null;
      _stopTimer();
      _publicIp = null;
    } catch (e) {
      _status = VpnStatus.error;
      _errorMessage = e.toString().replaceAll('Exception: ', '');
    } finally {
      notifyListeners();
    }
  }

  Future<void> reconnectWithUpdatedApps() async {
    if (_status == VpnStatus.connected) {
      await disconnect();
      await Future.delayed(const Duration(milliseconds: 300));
      await connect();
    }
  }

  String formatDuration(Duration d) {
    String twoDigits(int n) => n.toString().padLeft(2, '0');
    final hours = twoDigits(d.inHours);
    final minutes = twoDigits(d.inMinutes.remainder(60));
    final seconds = twoDigits(d.inSeconds.remainder(60));
    return '$hours:$minutes:$seconds';
  }

  @override
  void dispose() {
    _durationTimer?.cancel();
    _stateSubscription?.cancel();
    super.dispose();
  }
}
