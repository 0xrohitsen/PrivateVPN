import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import '../theme/app_theme.dart';

class QrScannerScreen extends StatefulWidget {
  const QrScannerScreen({super.key});

  @override
  State<QrScannerScreen> createState() => _QrScannerScreenState();
}

class _QrScannerScreenState extends State<QrScannerScreen> {
  final MobileScannerController _cameraController = MobileScannerController(
    detectionSpeed: DetectionSpeed.normal,
    facing: CameraFacing.back,
    torchEnabled: false,
  );

  final ImagePicker _picker = ImagePicker();
  bool _isProcessing = false;

  @override
  void dispose() {
    _cameraController.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_isProcessing) return;
    for (final barcode in capture.barcodes) {
      final rawValue = barcode.rawValue;
      if (rawValue != null && rawValue.trim().isNotEmpty) {
        setState(() {
          _isProcessing = true;
        });
        Navigator.of(context).pop(rawValue.trim());
        break;
      }
    }
  }

  Future<void> _pickFromGallery() async {
    try {
      final XFile? file = await _picker.pickImage(source: ImageSource.gallery);
      if (file == null) return;

      setState(() {
        _isProcessing = true;
      });

      final BarcodeCapture? result = await _cameraController.analyzeImage(file.path);
      if (result != null && result.barcodes.isNotEmpty) {
        for (final barcode in result.barcodes) {
          final rawValue = barcode.rawValue;
          if (rawValue != null && rawValue.trim().isNotEmpty) {
            if (mounted) {
              Navigator.of(context).pop(rawValue.trim());
            }
            return;
          }
        }
      }

      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No WireGuard QR code found in selected image.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isProcessing = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to analyze image: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Scan WireGuard QR'),
        backgroundColor: Colors.black,
        actions: [
          IconButton(
            icon: const Icon(Icons.photo_library_rounded, color: Colors.purpleAccent),
            tooltip: 'Import from Gallery',
            onPressed: _pickFromGallery,
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _cameraController,
              builder: (context, state, child) {
                switch (state.torchState) {
                  case TorchState.on:
                    return const Icon(Icons.flash_on_rounded, color: Colors.amber);
                  case TorchState.off:
                  default:
                    return const Icon(Icons.flash_off_rounded, color: Colors.grey);
                }
              },
            ),
            tooltip: 'Toggle Flashlight',
            onPressed: () => _cameraController.toggleTorch(),
          ),
          IconButton(
            icon: ValueListenableBuilder(
              valueListenable: _cameraController,
              builder: (context, state, child) {
                switch (state.cameraDirection) {
                  case CameraFacing.front:
                    return const Icon(Icons.camera_front_rounded);
                  case CameraFacing.back:
                  default:
                    return const Icon(Icons.camera_rear_rounded);
                }
              },
            ),
            tooltip: 'Switch Camera',
            onPressed: () => _cameraController.switchCamera(),
          ),
        ],
      ),
      body: Stack(
        children: [
          MobileScanner(
            controller: _cameraController,
            onDetect: _onDetect,
            errorBuilder: (context, error) {
              return Center(
                child: Padding(
                  padding: const EdgeInsets.all(24.0),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.no_photography_rounded, size: 64, color: AppColors.error),
                      const SizedBox(height: 16),
                      Text(
                        'Camera error: ${error.errorCode}',
                        style: const TextStyle(color: Colors.white, fontSize: 16),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Please grant Camera permissions or choose a QR screenshot from your gallery.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppColors.textMuted, fontSize: 13),
                      ),
                      const SizedBox(height: 20),
                      ElevatedButton.icon(
                        icon: const Icon(Icons.photo_library_rounded),
                        label: const Text('Choose from Gallery'),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: Colors.purpleAccent,
                          foregroundColor: Colors.white,
                        ),
                        onPressed: _pickFromGallery,
                      ),
                    ],
                  ),
                ),
              );
            },
          ),

          // Custom Scanner Overlay Box
          Center(
            child: Container(
              width: 260,
              height: 260,
              decoration: BoxDecoration(
                border: Border.all(color: Colors.purpleAccent, width: 2.5),
                borderRadius: BorderRadius.circular(20),
                boxShadow: [
                  BoxShadow(
                    color: Colors.purpleAccent.withValues(alpha: 0.2),
                    blurRadius: 20,
                    spreadRadius: 4,
                  ),
                ],
              ),
            ),
          ),

          // Bottom Action Bar (Gallery button + instructions)
          Positioned(
            bottom: 30,
            left: 20,
            right: 20,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                InkWell(
                  onTap: _pickFromGallery,
                  borderRadius: BorderRadius.circular(30),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                    decoration: BoxDecoration(
                      color: Colors.purpleAccent.withValues(alpha: 0.9),
                      borderRadius: BorderRadius.circular(30),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.purpleAccent.withValues(alpha: 0.4),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: const Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.photo_library_rounded, color: Colors.white, size: 20),
                        SizedBox(width: 8),
                        Text(
                          'Upload QR from Gallery / Photos',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 14,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.75),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.surfaceBorder),
                  ),
                  child: const Text(
                    'Point camera at QR code or pick an image from gallery',
                    textAlign: TextAlign.center,
                    style: TextStyle(color: Colors.white70, fontSize: 12),
                  ),
                ),
              ],
            ),
          ),

          if (_isProcessing)
            Container(
              color: Colors.black.withValues(alpha: 0.6),
              child: const Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    CircularProgressIndicator(color: Colors.purpleAccent),
                    SizedBox(height: 16),
                    Text(
                      'Analyzing QR Code...',
                      style: TextStyle(color: Colors.white, fontWeight: FontWeight.bold),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
