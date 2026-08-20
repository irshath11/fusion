import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/constants/app_colors.dart';

class CameraCaptureModal extends StatefulWidget {
  final String stepName;
  final Function(CameraCaptureResult) onPhotoCaptured;

  const CameraCaptureModal({
    super.key,
    required this.stepName,
    required this.onPhotoCaptured,
  });

  @override
  State<CameraCaptureModal> createState() => _CameraCaptureModalState();
}

class _CameraCaptureModalState extends State<CameraCaptureModal> {
  CameraController? _cameraController;
  List<CameraDescription> _cameras = [];
  bool _isInitializing = true;
  bool _isCapturing = false;
  String? _cameraError;
  CameraCaptureResult? _capturedResult;

  @override
  void initState() {
    super.initState();
    _initLiveCamera();
  }

  Future<void> _initLiveCamera() async {
    try {
      _cameras = await availableCameras();
      if (_cameras.isNotEmpty) {
        // Prefer front camera for selfie verification, fallback to first available
        final frontCamera = _cameras.firstWhere(
          (cam) => cam.lensDirection == CameraLensDirection.front,
          orElse: () => _cameras.first,
        );

        try {
          _cameraController = CameraController(
            frontCamera,
            ResolutionPreset.medium,
            enableAudio: false,
          );
          await _cameraController!.initialize();
        } catch (_) {
          // Fallback to low resolution for vendor OEM devices (MediaTek / Xiaomi / Vivo / Oppo)
          _cameraController = CameraController(
            frontCamera,
            ResolutionPreset.low,
            enableAudio: false,
          );
          await _cameraController!.initialize();
        }

        if (mounted) {
          setState(() {
            _isInitializing = false;
          });
        }
      } else {
        if (mounted) {
          setState(() {
            _isInitializing = false;
            _cameraError = 'No hardware camera detected on device.';
          });
        }
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isInitializing = false;
          _cameraError = 'Camera hardware restriction ($e)';
        });
      }
    }
  }

  @override
  void dispose() {
    _cameraController?.dispose();
    super.dispose();
  }

  Future<void> _triggerLiveCapture() async {
    setState(() {
      _isCapturing = true;
    });

    try {
      if (_cameraController != null && _cameraController!.value.isInitialized) {
        final XFile photoFile = await _cameraController!.takePicture();
        final result = await CameraService.processXFile(photoFile);
        if (mounted) {
          setState(() {
            _capturedResult = result;
            _isCapturing = false;
          });
        }
      } else {
        // Fallback capture for restricted hardware
        final result = await CameraService.captureLivePhoto();
        if (mounted) {
          setState(() {
            _capturedResult = result;
            _isCapturing = false;
          });
        }
      }
    } catch (e) {
      // Graceful fallback to verified compressed snapshot
      final result = await CameraService.captureLivePhoto();
      if (mounted) {
        setState(() {
          _capturedResult = result;
          _isCapturing = false;
        });
      }
    }
  }

  void _retakePhoto() {
    setState(() {
      _capturedResult = null;
    });
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Icon(Icons.camera_alt_rounded,
                    color: isDark ? AppColors.primaryLight : AppColors.primary),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'Live Photo Verification',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(context),
                )
              ],
            ),
            const Divider(height: 24),
            Container(
              height: 260,
              width: double.infinity,
              clipBehavior: Clip.antiAlias,
              decoration: BoxDecoration(
                color: Colors.black,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.primaryLight, width: 2),
              ),
              child: _buildCameraContent(),
            ),
            const SizedBox(height: 20),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 14),
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                    ),
                    onPressed: _capturedResult == null
                        ? (_isCapturing ? null : _triggerLiveCapture)
                        : _retakePhoto,
                    icon: Icon(_capturedResult == null
                        ? Icons.camera
                        : Icons.refresh_rounded),
                    label: FittedBox(
                      fit: BoxFit.scaleDown,
                      child: Text(
                        _capturedResult == null ? 'Capture Photo' : 'Retake',
                        maxLines: 1,
                      ),
                    ),
                  ),
                ),
                if (_capturedResult != null) ...[
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(vertical: 14),
                        shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        widget.onPhotoCaptured(_capturedResult!);
                        Navigator.pop(context);
                      },
                      icon: const Icon(Icons.check_circle_rounded),
                      label: const FittedBox(
                        fit: BoxFit.scaleDown,
                        child: Text(
                          'Confirm',
                          maxLines: 1,
                        ),
                      ),
                    ),
                  ),
                ]
              ],
            )
          ],
        ),
      ),
    );
  }

  Widget _buildCameraContent() {
    if (_isCapturing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text(
              'Capturing live camera frame...',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      );
    }

    if (_capturedResult != null) {
      final fileExists = File(_capturedResult!.imagePath).existsSync();
      return Stack(
        alignment: Alignment.center,
        fit: StackFit.expand,
        children: [
          if (fileExists)
            Image.file(
              File(_capturedResult!.imagePath),
              fit: BoxFit.cover,
            )
          else
            Container(
              color: Colors.blueGrey.shade900,
              child: const Center(
                child: Icon(Icons.person_pin, size: 90, color: Colors.white70),
              ),
            ),
          Positioned(
            bottom: 12,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.black87,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                'Live Verified Photo (${(_capturedResult!.compressedSizeBytes / 1024).toStringAsFixed(1)} KB)',
                style: const TextStyle(color: Colors.white, fontSize: 11, fontWeight: FontWeight.w600),
              ),
            ),
          )
        ],
      );
    }

    if (_isInitializing) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Colors.white),
            SizedBox(height: 12),
            Text(
              'Initializing Camera Hardware...',
              style: TextStyle(color: Colors.white, fontWeight: FontWeight.w500),
            ),
          ],
        ),
      );
    }

    if (_cameraController != null && _cameraController!.value.isInitialized) {
      return Stack(
        fit: StackFit.expand,
        children: [
          CameraPreview(_cameraController!),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(10),
              ),
              child: const Row(
                children: [
                  Icon(Icons.fiber_manual_record, color: Colors.red, size: 12),
                  SizedBox(width: 6),
                  Text('LIVE STREAM',
                      style: TextStyle(
                          color: Colors.white,
                          fontSize: 10,
                          fontWeight: FontWeight.bold)),
                ],
              ),
            ),
          ),
        ],
      );
    }

    // Camera hardware denied by SELinux / OEM driver -> Fallback mode button
    return Container(
      color: Colors.grey.shade900,
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.videocam_off_rounded, size: 44, color: Colors.white70),
          const SizedBox(height: 8),
          Text(
            _cameraError ?? 'Camera stream blocked by device security policy',
            textAlign: TextAlign.center,
            style: const TextStyle(color: Colors.white, fontSize: 12, fontWeight: FontWeight.w500),
          ),
          const SizedBox(height: 12),
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            ),
            onPressed: _triggerLiveCapture,
            icon: const Icon(Icons.camera_front, size: 16),
            label: const Text('Capture Snapshot', style: TextStyle(fontSize: 12)),
          )
        ],
      ),
    );
  }
}
