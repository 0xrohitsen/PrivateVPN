import 'package:flutter/material.dart';
import '../models/vpn_state.dart';
import '../theme/app_theme.dart';

class PulseConnectButton extends StatefulWidget {
  final VpnStatus status;
  final VoidCallback onTap;

  const PulseConnectButton({
    super.key,
    required this.status,
    required this.onTap,
  });

  @override
  State<PulseConnectButton> createState() => _PulseConnectButtonState();
}

class _PulseConnectButtonState extends State<PulseConnectButton>
    with SingleTickerProviderStateMixin {
  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  @override
  void initState() {
    super.initState();
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1800),
    );

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.15).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );

    if (widget.status.isConnected || widget.status.isConnecting) {
      _pulseController.repeat(reverse: true);
    }
  }

  @override
  void didUpdateWidget(covariant PulseConnectButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.status.isConnected || widget.status.isConnecting) {
      if (!_pulseController.isAnimating) {
        _pulseController.repeat(reverse: true);
      }
    } else {
      if (_pulseController.isAnimating) {
        _pulseController.stop();
        _pulseController.reset();
      }
    }
  }

  @override
  void dispose() {
    _pulseController.dispose();
    super.dispose();
  }

  Color _getMainColor() {
    switch (widget.status) {
      case VpnStatus.connected:
        return AppColors.connected;
      case VpnStatus.connecting:
        return AppColors.connecting;
      case VpnStatus.error:
        return AppColors.error;
      case VpnStatus.disconnected:
        return AppColors.primary;
    }
  }

  Color _getGlowColor() {
    switch (widget.status) {
      case VpnStatus.connected:
        return AppColors.connectedGlow;
      case VpnStatus.connecting:
        return AppColors.connectingGlow;
      case VpnStatus.error:
        return AppColors.errorGlow;
      case VpnStatus.disconnected:
        return AppColors.primaryGlow;
    }
  }

  @override
  Widget build(BuildContext context) {
    final mainColor = _getMainColor();
    final glowColor = _getGlowColor();

    return AnimatedBuilder(
      animation: _pulseAnimation,
      builder: (context, child) {
        final scale = (_pulseController.isAnimating) ? _pulseAnimation.value : 1.0;

        return Center(
          child: GestureDetector(
            onTap: widget.onTap,
            child: Stack(
              alignment: Alignment.center,
              children: [
                // Outer subtle glow
                Container(
                  width: 170 * scale,
                  height: 170 * scale,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: glowColor.withValues(alpha: 0.25),
                  ),
                ),
                // Mid glow ring
                Container(
                  width: 145,
                  height: 145,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: mainColor.withValues(alpha: 0.3),
                      width: 2,
                    ),
                  ),
                ),
                // Core Button
                Container(
                  width: 125,
                  height: 125,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [
                        AppColors.surfaceSubtle,
                        AppColors.surface,
                      ],
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: mainColor.withValues(alpha: widget.status.isConnected ? 0.4 : 0.2),
                        blurRadius: 20,
                        spreadRadius: 2,
                      ),
                    ],
                    border: Border.all(
                      color: mainColor,
                      width: 2.5,
                    ),
                  ),
                  child: Center(
                    child: widget.status.isConnecting
                        ? SizedBox(
                            width: 38,
                            height: 38,
                            child: CircularProgressIndicator(
                              strokeWidth: 3,
                              valueColor: AlwaysStoppedAnimation<Color>(mainColor),
                            ),
                          )
                        : Icon(
                            Icons.power_settings_new_rounded,
                            size: 52,
                            color: mainColor,
                          ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
