import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/installed_app.dart';
import '../models/vpn_state.dart';
import '../providers/vpn_controller.dart';
import '../theme/app_theme.dart';

class PerAppVpnFilterScreen extends StatefulWidget {
  const PerAppVpnFilterScreen({super.key});

  @override
  State<PerAppVpnFilterScreen> createState() => _PerAppVpnFilterScreenState();
}

class _PerAppVpnFilterScreenState extends State<PerAppVpnFilterScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<VpnController>(
      builder: (context, controller, child) {
        final allApps = controller.installedApps;
        final selectedSet = controller.selectedApps;
        final isVpnConnected = controller.status.isConnected;

        // Filter by search query
        final searchedApps = allApps.where((app) {
          if (_searchQuery.isEmpty) return true;
          final query = _searchQuery.toLowerCase();
          return app.name.toLowerCase().contains(query) ||
              app.packageName.toLowerCase().contains(query);
        }).toList();

        // Separate: Selected apps first, then unselected apps
        final selectedApps = searchedApps
            .where((app) => selectedSet.contains(app.packageName))
            .toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        final unselectedApps = searchedApps
            .where((app) => !selectedSet.contains(app.packageName))
            .toList()
          ..sort((a, b) => a.name.toLowerCase().compareTo(b.name.toLowerCase()));

        final totalSelected = selectedSet.length;

        return Scaffold(
          appBar: AppBar(
            title: const Text('Per-App VPN Filter'),
            actions: [
              IconButton(
                icon: const Icon(Icons.refresh_rounded),
                tooltip: 'Reload Apps',
                onPressed: controller.loadInstalledApps,
              ),
            ],
          ),
          body: Column(
            children: [
              // Search & Bulk Action Header
              Container(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                color: AppColors.background,
                child: Column(
                  children: [
                    TextField(
                      controller: _searchController,
                      onChanged: (val) {
                        setState(() {
                          _searchQuery = val;
                        });
                      },
                      decoration: InputDecoration(
                        hintText: 'Search installed apps...',
                        prefixIcon: const Icon(Icons.search_rounded,
                            color: AppColors.textMuted),
                        suffixIcon: _searchQuery.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear_rounded, size: 18),
                                onPressed: () {
                                  _searchController.clear();
                                  setState(() {
                                    _searchQuery = '';
                                  });
                                },
                              )
                            : null,
                        contentPadding: const EdgeInsets.symmetric(
                            vertical: 12, horizontal: 16),
                      ),
                    ),
                    const SizedBox(height: 10),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          totalSelected > 0
                              ? '$totalSelected Selected for VPN'
                              : 'No filter (All apps use VPN)',
                          style: TextStyle(
                            color: totalSelected > 0
                                ? Colors.purpleAccent
                                : AppColors.textMuted,
                            fontWeight: FontWeight.w700,
                            fontSize: 13,
                          ),
                        ),
                        Row(
                          children: [
                            TextButton.icon(
                              icon: const Icon(Icons.select_all_rounded, size: 16),
                              label: const Text('Select All',
                                  style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: controller.selectAllApps,
                            ),
                            const SizedBox(width: 4),
                            TextButton.icon(
                              icon: const Icon(Icons.clear_all_rounded, size: 16),
                              label: const Text('Clear',
                                  style: TextStyle(fontSize: 12)),
                              style: TextButton.styleFrom(
                                foregroundColor: AppColors.textSecondary,
                                padding: const EdgeInsets.symmetric(horizontal: 8),
                              ),
                              onPressed: controller.deselectAllApps,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              // Active VPN Reconnect Banner
              if (isVpnConnected)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  color: AppColors.connecting.withValues(alpha: 0.15),
                  child: Row(
                    children: [
                      const Icon(Icons.info_outline_rounded,
                          color: AppColors.connecting, size: 18),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Text(
                          'Updating app filter will reconnect active VPN tunnel.',
                          style: TextStyle(
                            color: AppColors.textPrimary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                      TextButton(
                        onPressed: () {
                          controller.reconnectWithUpdatedApps();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Applying updated app filter to VPN...'),
                              duration: Duration(seconds: 2),
                            ),
                          );
                        },
                        child: const Text(
                          'APPLY',
                          style: TextStyle(
                            color: AppColors.connecting,
                            fontWeight: FontWeight.bold,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

              const Divider(height: 1, color: AppColors.surfaceBorder),

              // Apps List (Selected first, then Unselected)
              Expanded(
                child: controller.isLoadingApps
                    ? const Center(
                        child: Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            CircularProgressIndicator(strokeWidth: 3),
                            SizedBox(height: 16),
                            Text(
                              'Scanning installed apps...',
                              style: TextStyle(color: AppColors.textSecondary),
                            ),
                          ],
                        ),
                      )
                    : (selectedApps.isEmpty && unselectedApps.isEmpty)
                        ? Center(
                            child: Text(
                              _searchQuery.isNotEmpty
                                  ? 'No matching apps found'
                                  : 'No apps available',
                              style: const TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : CustomScrollView(
                            slivers: [
                              // 1. Selected Apps Section
                              if (selectedApps.isNotEmpty) ...[
                                SliverToBoxAdapter(
                                  child: _buildSectionHeader(
                                    title: 'SELECTED APPS (${selectedApps.length})',
                                    color: Colors.purpleAccent,
                                    icon: Icons.check_circle_rounded,
                                  ),
                                ),
                                SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final app = selectedApps[index];
                                      return _AppFilterItem(
                                        app: app,
                                        isSelected: true,
                                        onToggle: () {
                                          controller.toggleAppSelection(app.packageName);
                                        },
                                      );
                                    },
                                    childCount: selectedApps.length,
                                  ),
                                ),
                              ],

                              // 2. Unselected Apps Section
                              if (unselectedApps.isNotEmpty) ...[
                                SliverToBoxAdapter(
                                  child: _buildSectionHeader(
                                    title: 'UNSELECTED APPS (${unselectedApps.length})',
                                    color: AppColors.textMuted,
                                    icon: Icons.radio_button_unchecked_rounded,
                                  ),
                                ),
                                SliverList(
                                  delegate: SliverChildBuilderDelegate(
                                    (context, index) {
                                      final app = unselectedApps[index];
                                      return _AppFilterItem(
                                        app: app,
                                        isSelected: false,
                                        onToggle: () {
                                          controller.toggleAppSelection(app.packageName);
                                        },
                                      );
                                    },
                                    childCount: unselectedApps.length,
                                  ),
                                ),
                              ],
                            ],
                          ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildSectionHeader({
    required String title,
    required Color color,
    required IconData icon,
  }) {
    return Container(
      padding: const EdgeInsets.fromLTRB(16, 14, 16, 6),
      color: AppColors.background,
      child: Row(
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 8),
          Text(
            title,
            style: TextStyle(
              color: color,
              fontSize: 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.8,
            ),
          ),
        ],
      ),
    );
  }
}

class _AppFilterItem extends StatelessWidget {
  final InstalledApp app;
  final bool isSelected;
  final VoidCallback onToggle;

  const _AppFilterItem({
    required this.app,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final iconBytes = app.iconBytes;

    return InkWell(
      onTap: onToggle,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        decoration: const BoxDecoration(
          border: Border(
            bottom: BorderSide(color: AppColors.surfaceBorder, width: 0.5),
          ),
        ),
        child: Row(
          children: [
            // App Icon
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: Container(
                width: 44,
                height: 44,
                color: AppColors.surfaceSubtle,
                child: iconBytes != null
                    ? Image.memory(
                        iconBytes,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.android, color: AppColors.textMuted),
                      )
                    : const Icon(Icons.android, color: AppColors.textMuted),
              ),
            ),
            const SizedBox(width: 14),

            // App Name & Package
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    app.name,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    app.packageName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppColors.textMuted,
                      fontSize: 12,
                      fontFamily: 'monospace',
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(width: 8),

            // Badge
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? Colors.purpleAccent.withValues(alpha: 0.18)
                    : AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? Colors.purpleAccent.withValues(alpha: 0.5)
                      : AppColors.surfaceBorder,
                ),
              ),
              child: Text(
                isSelected ? 'VPN' : 'DIRECT',
                style: TextStyle(
                  color: isSelected ? Colors.purpleAccent : AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(width: 8),

            // Checkbox
            Checkbox(
              value: isSelected,
              activeColor: Colors.purpleAccent,
              checkColor: AppColors.background,
              side: const BorderSide(color: AppColors.surfaceBorder, width: 1.5),
              onChanged: (_) => onToggle(),
            ),
          ],
        ),
      ),
    );
  }
}
