import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../models/vpn_config.dart';
import '../providers/vpn_controller.dart';
import '../theme/app_theme.dart';

class ServerConfigScreen extends StatefulWidget {
  const ServerConfigScreen({super.key});

  @override
  State<ServerConfigScreen> createState() => _ServerConfigScreenState();
}

class _ServerConfigScreenState extends State<ServerConfigScreen> {
  final _formKey = GlobalKey<FormState>();

  late TextEditingController _serverNameController;
  late TextEditingController _serverEndpointController;
  late TextEditingController _serverPublicKeyController;
  late TextEditingController _clientAddressController;
  late TextEditingController _clientPrivateKeyController;
  late TextEditingController _dnsController;

  bool _isObscurePrivateKey = true;

  @override
  void initState() {
    super.initState();
    final config = context.read<VpnController>().config;
    _serverNameController = TextEditingController(text: config.serverName);
    _serverEndpointController = TextEditingController(text: config.serverEndpoint);
    _serverPublicKeyController = TextEditingController(text: config.serverPublicKey);
    _clientAddressController = TextEditingController(text: config.clientAddress);
    _clientPrivateKeyController = TextEditingController(text: config.clientPrivateKey);
    _dnsController = TextEditingController(text: config.dns);
  }

  @override
  void dispose() {
    _serverNameController.dispose();
    _serverEndpointController.dispose();
    _serverPublicKeyController.dispose();
    _clientAddressController.dispose();
    _clientPrivateKeyController.dispose();
    _dnsController.dispose();
    super.dispose();
  }

  void _saveConfig() {
    if (_formKey.currentState?.validate() ?? false) {
      final updated = VpnConfig(
        serverName: _serverNameController.text.trim(),
        serverEndpoint: _serverEndpointController.text.trim(),
        serverPublicKey: _serverPublicKeyController.text.trim(),
        clientAddress: _clientAddressController.text.trim(),
        clientPrivateKey: _clientPrivateKeyController.text.trim(),
        dns: _dnsController.text.trim(),
      );

      context.read<VpnController>().updateConfig(updated);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Configuration saved successfully'),
          backgroundColor: AppColors.connected,
          duration: Duration(seconds: 2),
        ),
      );
      Navigator.of(context).pop();
    }
  }

  void _showImportExportModal() {
    final controller = context.read<VpnController>();
    final importExportTextController = TextEditingController(
      text: controller.config.toWgQuick(),
    );

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.surface,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: EdgeInsets.only(
            top: 20,
            left: 20,
            right: 20,
            bottom: MediaQuery.of(ctx).viewInsets.bottom + 20,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'WireGuard .conf Raw Text',
                    style: TextStyle(
                      color: AppColors.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: AppColors.textMuted),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'Paste your WireGuard configuration file content below to import, or copy it.',
                style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: importExportTextController,
                maxLines: 8,
                style: const TextStyle(
                  fontFamily: 'monospace',
                  fontSize: 12,
                  color: AppColors.textPrimary,
                ),
                decoration: const InputDecoration(
                  hintText: '[Interface]\nPrivateKey = ...\nAddress = ...',
                ),
              ),
              const SizedBox(height: 16),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      icon: const Icon(Icons.copy_rounded, size: 16),
                      label: const Text('Copy .conf'),
                      style: OutlinedButton.styleFrom(
                        foregroundColor: AppColors.primary,
                        side: const BorderSide(color: AppColors.primary),
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        Clipboard.setData(ClipboardData(
                            text: importExportTextController.text));
                        ScaffoldMessenger.of(context).showSnackBar(
                          const SnackBar(
                            content: Text('Configuration copied to clipboard'),
                            duration: Duration(seconds: 2),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      icon: const Icon(Icons.download_rounded, size: 16),
                      label: const Text('Import'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: AppColors.background,
                        padding: const EdgeInsets.symmetric(vertical: 12),
                      ),
                      onPressed: () {
                        try {
                          final parsed = VpnConfig.fromWgQuick(
                              importExportTextController.text);
                          setState(() {
                            if (parsed.clientPrivateKey.isNotEmpty) {
                              _clientPrivateKeyController.text =
                                  parsed.clientPrivateKey;
                            }
                            if (parsed.clientAddress.isNotEmpty) {
                              _clientAddressController.text = parsed.clientAddress;
                            }
                            if (parsed.dns.isNotEmpty) {
                              _dnsController.text = parsed.dns;
                            }
                            if (parsed.serverPublicKey.isNotEmpty) {
                              _serverPublicKeyController.text =
                                  parsed.serverPublicKey;
                            }
                            if (parsed.serverEndpoint.isNotEmpty) {
                              _serverEndpointController.text =
                                  parsed.serverEndpoint;
                            }
                          });
                          Navigator.of(ctx).pop();
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('Configuration imported successfully'),
                              backgroundColor: AppColors.connected,
                            ),
                          );
                        } catch (e) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                              content: Text('Failed to parse config: $e'),
                              backgroundColor: AppColors.error,
                            ),
                          );
                        }
                      },
                    ),
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Server Configuration'),
        actions: [
          IconButton(
            icon: const Icon(Icons.code_rounded),
            tooltip: 'Raw Config Import/Export',
            onPressed: _showImportExportModal,
          ),
        ],
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Info banner
                Container(
                  padding: const EdgeInsets.all(14),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceSubtle,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: const Row(
                    children: [
                      Icon(Icons.lock_clock_rounded,
                          color: AppColors.primary, size: 22),
                      SizedBox(width: 12),
                      Expanded(
                        child: Text(
                          'Your private key is stored securely in Android Keystore / encrypted storage and never leaves your device.',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),

                const SizedBox(height: 24),
                const Text(
                  'SERVER SETTINGS',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),

                // Server Name
                TextFormField(
                  controller: _serverNameController,
                  decoration: const InputDecoration(
                    labelText: 'Server Name / Label',
                    hintText: 'e.g. My Ubuntu VPS',
                    prefixIcon: Icon(Icons.label_outline_rounded,
                        color: AppColors.textMuted),
                  ),
                ),
                const SizedBox(height: 14),

                // Server Endpoint (IP:Port)
                TextFormField(
                  controller: _serverEndpointController,
                  decoration: const InputDecoration(
                    labelText: 'Server Endpoint (IP:Port)',
                    hintText: 'e.g. 198.51.100.1:51820',
                    prefixIcon:
                        Icon(Icons.dns_rounded, color: AppColors.textMuted),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Server endpoint is required';
                    }
                    if (!val.contains(':')) {
                      return 'Specify port, e.g. 198.51.100.1:51820';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Server Public Key
                TextFormField(
                  controller: _serverPublicKeyController,
                  decoration: const InputDecoration(
                    labelText: 'Server Public Key',
                    hintText: 'Base64 WireGuard public key',
                    prefixIcon: Icon(Icons.vpn_key_rounded,
                        color: AppColors.textMuted),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Server public key is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 28),
                const Text(
                  'CLIENT SETTINGS',
                  style: TextStyle(
                    color: AppColors.textMuted,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 12),

                // Client VPN Address
                TextFormField(
                  controller: _clientAddressController,
                  decoration: const InputDecoration(
                    labelText: 'Client VPN IP Address',
                    hintText: 'e.g. 10.8.0.2/32',
                    prefixIcon: Icon(Icons.alt_route_rounded,
                        color: AppColors.textMuted),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Client address is required';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 14),

                // Client Private Key
                TextFormField(
                  controller: _clientPrivateKeyController,
                  obscureText: _isObscurePrivateKey,
                  decoration: InputDecoration(
                    labelText: 'Client Private Key',
                    hintText: 'Base64 WireGuard private key',
                    prefixIcon: const Icon(Icons.key_rounded,
                        color: AppColors.textMuted),
                    suffixIcon: IconButton(
                      icon: Icon(
                        _isObscurePrivateKey
                            ? Icons.visibility_off_rounded
                            : Icons.visibility_rounded,
                        color: AppColors.textMuted,
                      ),
                      onPressed: () {
                        setState(() {
                          _isObscurePrivateKey = !_isObscurePrivateKey;
                        });
                      },
                    ),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) {
                      return 'Client private key is required';
                    }
                    return null;
                  },
                ),

                const SizedBox(height: 8),

                // Generate Keypair Button
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    icon: const Icon(Icons.auto_fix_high_rounded, size: 16),
                    label: const Text('Generate New Client Keypair',
                        style: TextStyle(fontSize: 12)),
                    style: TextButton.styleFrom(
                      foregroundColor: AppColors.primary,
                    ),
                    onPressed: () async {
                      final messenger = ScaffoldMessenger.of(context);
                      final controller = context.read<VpnController>();
                      await controller.generateNewKeys();
                      if (!mounted) return;
                      setState(() {
                        _clientPrivateKeyController.text =
                            controller.config.clientPrivateKey;
                      });
                      messenger.showSnackBar(
                        const SnackBar(
                          content: Text(
                              'Generated new client keypair. Remember to add the client public key to your VPS wg0.conf!'),
                          duration: Duration(seconds: 3),
                        ),
                      );
                    },

                  ),
                ),

                const SizedBox(height: 8),

                // DNS
                TextFormField(
                  controller: _dnsController,
                  decoration: const InputDecoration(
                    labelText: 'DNS Server',
                    hintText: 'e.g. 1.1.1.1 or 8.8.8.8',
                    prefixIcon:
                        Icon(Icons.language_rounded, color: AppColors.textMuted),
                  ),
                ),

                const SizedBox(height: 32),

                // Save Button
                SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton.icon(
                    icon: const Icon(Icons.save_rounded),
                    label: const Text(
                      'SAVE CONFIGURATION',
                      style: TextStyle(
                        fontWeight: FontWeight.w700,
                        letterSpacing: 1.0,
                      ),
                    ),
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: AppColors.background,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                    ),
                    onPressed: _saveConfig,
                  ),
                ),

                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
