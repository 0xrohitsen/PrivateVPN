import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/vpn_state.dart';
import '../providers/vpn_controller.dart';
import '../theme/app_theme.dart';
import '../widgets/pulse_connect_button.dart';
import '../widgets/stat_card.dart';
import 'per_app_vpn_filter_screen.dart';
import 'server_config_screen.dart';

class HomeScreen extends StatelessWidget {
  const HomeScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Consumer<VpnController>(
      builder: (context, controller, child) {
        final status = controller.status;
        final config = controller.config;
        final selectedCount = controller.selectedApps.length;

        return Scaffold(
          appBar: AppBar(
            title: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.asset(
                    'assets/images/shield_emblem.png',
                    width: 28,
                    height: 28,
                    fit: BoxFit.cover,
                  ),
                ),
                const SizedBox(width: 10),
                const Text(
                  'PrivateVPN',
                  style: TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: 0.5,
                  ),
                ),
              ],
            ),
            actions: [
              IconButton(
                icon: const Icon(Icons.settings_outlined, color: AppColors.textSecondary),
                tooltip: 'Server Settings',
                onPressed: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const ServerConfigScreen(),
                    ),
                  );
                },
              ),
            ],
          ),
          body: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  // Status Badge
                  StatusBadge(status: status),
                  const SizedBox(height: 32),

                  // Big Pulse Connect Button
                  PulseConnectButton(
                    status: status,
                    onTap: () {
                      if (status.isConnected) {
                        controller.disconnect();
                      } else if (status.isDisconnected || status.isError) {
                        controller.connect();
                      }
                    },
                  ),

                  const SizedBox(height: 16),
                  Text(
                    status.isConnected
                        ? 'TAP TO DISCONNECT'
                        : (status.isConnecting
                            ? 'ESTABLISHING TUNNEL...'
                            : 'TAP TO CONNECT'),
                    style: TextStyle(
                      color: status.isConnected
                          ? AppColors.connected
                          : AppColors.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.1,
                    ),
                  ),

                  // Error Box if any
                  if (status.isError && controller.errorMessage != null) ...[
                    const SizedBox(height: 20),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: AppColors.error.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: AppColors.error.withValues(alpha: 0.4)),
                      ),
                      child: Row(
                        children: [
                          const Icon(Icons.error_outline_rounded,
                              color: AppColors.error, size: 24),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Text(
                              controller.errorMessage!,
                              style: const TextStyle(
                                color: AppColors.textPrimary,
                                fontSize: 13,
                              ),
                            ),
                          ),
                          TextButton(
                            onPressed: controller.connect,
                            child: const Text('RETRY',
                                style: TextStyle(color: AppColors.error, fontWeight: FontWeight.bold)),
                          ),
                        ],
                      ),
                    ),
                  ],

                  const SizedBox(height: 32),

                  // 2x2 Stats Grid
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: 14,
                    crossAxisSpacing: 14,
                    childAspectRatio: 1.25,
                    children: [
                      // Server Info Card
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const ServerConfigScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: StatCard(
                          title: 'Server',
                          value: config.serverEndpoint.isNotEmpty
                              ? config.serverEndpoint
                              : 'Not configured',
                          icon: Icons.dns_rounded,
                          accentColor: AppColors.primary,
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                        ),
                      ),

                      // Public IP Card
                      StatCard(
                        title: 'Public VPN IP',
                        value: status.isConnected
                            ? (controller.publicIp ?? (controller.isResolvingIp ? 'Resolving...' : '—'))
                            : '—',
                        icon: Icons.public_rounded,
                        accentColor: AppColors.connected,
                        trailing: status.isConnected && !controller.isResolvingIp
                            ? InkWell(
                                onTap: () => controller.connect(), // or ip refresh
                                child: const Icon(
                                  Icons.refresh_rounded,
                                  color: AppColors.textMuted,
                                  size: 18,
                                ),
                              )
                            : null,
                      ),

                      // Duration Timer Card
                      StatCard(
                        title: 'Duration',
                        value: status.isConnected
                            ? controller.formatDuration(controller.connectedDuration)
                            : '—',
                        icon: Icons.timer_outlined,
                        accentColor: AppColors.connecting,
                      ),

                      // Per-App Routing Card
                      InkWell(
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(
                              builder: (_) => const PerAppVpnFilterScreen(),
                            ),
                          );
                        },
                        borderRadius: BorderRadius.circular(16),
                        child: StatCard(
                          title: 'Apps Routed',
                          value: selectedCount > 0
                              ? '$selectedCount ${selectedCount == 1 ? 'App' : 'Apps'}'
                              : 'All Traffic',
                          icon: Icons.apps_rounded,
                          accentColor: Colors.purpleAccent,
                          trailing: const Icon(
                            Icons.chevron_right_rounded,
                            color: AppColors.textMuted,
                            size: 18,
                          ),
                        ),
                      ),
                    ],
                  ),

                  const SizedBox(height: 28),

                  // Manage Per-App Routing button banner
                  InkWell(
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const PerAppVpnFilterScreen(),
                        ),
                      );
                    },
                    borderRadius: BorderRadius.circular(16),
                    child: Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceSubtle,
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: AppColors.surfaceBorder),
                      ),
                      child: Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.all(10),
                            decoration: BoxDecoration(
                              color: Colors.purpleAccent.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Icon(
                              Icons.tune_rounded,
                              color: Colors.purpleAccent,
                              size: 22,
                            ),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                const Text(
                                  'Per-App VPN Filter',
                                  style: TextStyle(
                                    color: AppColors.textPrimary,
                                    fontWeight: FontWeight.w700,
                                    fontSize: 14,
                                  ),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  selectedCount > 0
                                      ? '$selectedCount apps route via VPS • Others use normal ISP'
                                      : 'No filter active. All device apps use VPS.',
                                  style: const TextStyle(
                                    color: AppColors.textSecondary,
                                    fontSize: 12,
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const Icon(Icons.arrow_forward_ios_rounded,
                              size: 16, color: AppColors.textSecondary),
                        ],
                      ),
                    ),
                  ),

                  const SizedBox(height: 20),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
