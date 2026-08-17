import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:privatecpn/main.dart';
import 'package:privatecpn/models/vpn_state.dart';
import 'package:privatecpn/widgets/stat_card.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  const MethodChannel methodChannel =
      MethodChannel('com.example.privatecpn/vpn_methods');
  const MethodChannel secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    FlutterSecureStorage.setMockInitialValues({});

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, (MethodCall methodCall) async {
      switch (methodCall.method) {
        case 'getTunnelState':
          return 'disconnected';
        case 'getInstalledApps':
          return <Map<String, dynamic>>[];
        case 'prepareVpn':
          return true;
        case 'startTunnel':
          return true;
        case 'stopTunnel':
          return true;
        case 'generateKeyPair':
          return {
            'privateKey': 'mockPrivKey=',
            'publicKey': 'mockPubKey=',
          };
        default:
          return null;
      }
    });

    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel,
            (MethodCall methodCall) async {
      return null;
    });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(methodChannel, null);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  testWidgets('StatCard renders title, value and icon',
      (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatCard(
            title: 'Server',
            value: '198.51.100.1:51820',
            icon: Icons.dns_rounded,
          ),
        ),
      ),
    );

    expect(find.text('SERVER'), findsOneWidget);
    expect(find.text('198.51.100.1:51820'), findsOneWidget);
    expect(find.byIcon(Icons.dns_rounded), findsOneWidget);
  });

  testWidgets('StatusBadge renders OFFLINE state', (WidgetTester tester) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: StatusBadge(status: VpnStatus.disconnected),
        ),
      ),
    );

    expect(find.text('OFFLINE'), findsOneWidget);
  });

  testWidgets('PrivateVpnApp boots and displays title',
      (WidgetTester tester) async {
    await tester.pumpWidget(const PrivateVpnApp());
    await tester.pumpAndSettle();

    expect(find.text('PrivateVPN'), findsOneWidget);
    expect(find.text('TAP TO CONNECT'), findsOneWidget);
    expect(find.text('OFFLINE'), findsOneWidget);
  });
}
