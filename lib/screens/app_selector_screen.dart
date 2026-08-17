import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../models/installed_app.dart';
import '../models/vpn_state.dart';
import '../providers/vpn_controller.dart';
import '../theme/app_theme.dart';

class AppSelectorScreen extends StatefulWidget {
  const AppSelectorScreen({super.key});

  @override
  State<AppSelectorScreen> createState() => _AppSelectorScreenState();
}

class _AppSelectorScreenState extends State<AppSelectorScreen> {
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

        final filteredApps = allApps.where((app) {
          if (_searchQuery.isEmpty) return true;
          final query = _searchQuery.toLowerCase();
          return app.name.toLowerCase().contains(query) ||
              app.packageName.toLowerCase().contains(query);
        }).toList();

        return Scaffold(
          appBar: AppBar(
            title: const Text('Per-App Routing'),
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
              // Search and Bulk actions header
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
                          '${selectedSet.length} selected for VPN',
                          style: const TextStyle(
                            color: AppColors.primary,
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
                                foregroundColor: AppColors.textSecondary,
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

              // Active VPN Notice Banner
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
                          'Changing VPN apps will reconnect the VPN tunnel.',
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
                              content: Text('Reconnecting VPN with new app rules...'),
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

              // Apps List
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
                    : filteredApps.isEmpty
                        ? Center(
                            child: Text(
                              _searchQuery.isNotEmpty
                                  ? 'No matching apps found'
                                  : 'No apps available',
                              style: const TextStyle(color: AppColors.textMuted),
                            ),
                          )
                        : ListView.separated(
                            padding: const EdgeInsets.symmetric(vertical: 8),
                            itemCount: filteredApps.length,
                            separatorBuilder: (context, index) => const Divider(
                              height: 1,
                              color: AppColors.surfaceBorder,
                              indent: 72,
                            ),
                            itemBuilder: (context, index) {
                              final app = filteredApps[index];
                              final isSelected =
                                  selectedSet.contains(app.packageName);

                              return _AppListItem(
                                app: app,
                                isSelected: isSelected,
                                onToggle: () {
                                  controller.toggleAppSelection(app.packageName);
                                },
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _AppListItem extends StatelessWidget {
  final InstalledApp app;
  final bool isSelected;
  final VoidCallback onToggle;

  const _AppListItem({
    required this.app,
    required this.isSelected,
    required this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    final iconBytes = app.iconBytes;

    return InkWell(
      onTap: onToggle,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
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

            // Route Badge / Checkbox
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: isSelected
                    ? AppColors.primary.withValues(alpha: 0.15)
                    : AppColors.surfaceSubtle,
                borderRadius: BorderRadius.circular(6),
                border: Border.all(
                  color: isSelected
                      ? AppColors.primary.withValues(alpha: 0.4)
                      : AppColors.surfaceBorder,
                ),
              ),
              child: Text(
                isSelected ? 'VPN' : 'DIRECT',
                style: TextStyle(
                  color: isSelected ? AppColors.primary : AppColors.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 0.5,
                ),
              ),
            ),

            const SizedBox(width: 8),

            Checkbox(
              value: isSelected,
              activeColor: AppColors.primary,
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
