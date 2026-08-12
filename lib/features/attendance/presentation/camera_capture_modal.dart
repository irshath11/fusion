import 'dart:io';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/services/camera_service.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/widgets/app_button.dart';
import '../../../core/widgets/animated_widgets.dart';

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
          _cameraController = CameraController(
            frontCamera,
            ResolutionPreset.low,
            enableAudio: false,
          );
          await _cameraController!.initialize();
        }

        if (mounted) {
          setState(() => _isInitializing = false);
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
    setState(() => _isCapturing = true);

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
        final result = await CameraService.captureLivePhoto();
        if (mounted) {
          setState(() {
            _capturedResult = result;
            _isCapturing = false;
          });
        }
      }
    } catch (e) {
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
    setState(() => _capturedResult = null);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return Dialog(
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 420),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Header Row
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppColors.primary.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.face_retouching_natural_rounded,
                        color: AppColors.primary, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'Selfie Verification',
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                            color: isDark
                                ? AppColors.textPrimaryDark
                                : AppColors.textPrimaryLight,
                          ),
                        ),
                        Text(
                          widget.stepName,
                          style: GoogleFonts.plusJakartaSans(
                            fontSize: 11.5,
                            fontWeight: FontWeight.w500,
                            color: isDark
                                ? AppColors.textTertiaryDark
                                : AppColors.textSecondaryLight,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, size: 20),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const SizedBox(height: 18),

              // Camera Viewfinder / Preview
              ClipRRect(
                borderRadius: BorderRadius.circular(20),
                child: Container(
                  height: 280,
                  width: double.infinity,
                  color: isDark ? const Color(0xFF0F1524) : Colors.black87,
                  child: Stack(
                    alignment: Alignment.center,
                    children: [
                      if (_capturedResult != null)
                        Image.file(
                          File(_capturedResult!.imagePath),
                          fit: BoxFit.cover,
                          width: double.infinity,
                          height: double.infinity,
                        )
                      else if (_isInitializing)
                        const Column(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            SizedBox(
                              width: 28,
                              height: 28,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: Colors.white),
                            ),
                            SizedBox(height: 12),
                            Text(
                              'Initializing camera sensor...',
                              style: TextStyle(
                                  color: Colors.white70, fontSize: 12),
                            ),
                          ],
                        )
                      else if (_cameraError != null)
                        Padding(
                          padding: const EdgeInsets.all(16.0),
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              const Icon(Icons.camera_alt_outlined,
                                  color: Colors.white60, size: 36),
                              const SizedBox(height: 8),
                              Text(
                                _cameraError!,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                    color: Colors.white70, fontSize: 12),
                              ),
                            ],
                          ),
                        )
                      else if (_cameraController != null &&
                          _cameraController!.value.isInitialized)
                        CameraPreview(_cameraController!)
                      else
                        const Icon(Icons.camera_alt_outlined,
                            color: Colors.white60, size: 48),

                      // Viewfinder Overlay Reticle
                      if (_capturedResult == null && !_isInitializing)
                        Container(
                          margin: const EdgeInsets.all(32),
                          decoration: BoxDecoration(
                            border: Border.all(
                              color: AppColors.primaryLight
                                  .withValues(alpha: 0.5),
                              width: 1.5,
                            ),
                            borderRadius: BorderRadius.circular(16),
                          ),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Actions
              if (_capturedResult == null)
                BouncingButton(
                  onTap: (_isInitializing || _isCapturing)
                      ? null
                      : _triggerLiveCapture,
                  child: Container(
                    height: 54,
                    width: double.infinity,
                    decoration: BoxDecoration(
                      gradient: AppColors.primaryGradient,
                      borderRadius: BorderRadius.circular(14),
                      boxShadow: [
                        BoxShadow(
                          color: AppColors.primary.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: _isCapturing
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                strokeWidth: 2.2,
                                color: Colors.white,
                              ),
                            )
                          : Row(
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Icon(Icons.camera_rounded,
                                    color: Colors.white, size: 18),
                                const SizedBox(width: 8),
                                Text(
                                  'Capture Live Photo',
                                  style: GoogleFonts.plusJakartaSans(
                                    color: Colors.white,
                                    fontWeight: FontWeight.w600,
                                    fontSize: 14.5,
                                  ),
                                ),
                              ],
                            ),
                    ),
                  ),
                )
              else
                Row(
                  children: [
                    Expanded(
                      child: AppButton(
                        text: 'Retake',
                        variant: AppButtonVariant.secondary,
                        height: 48,
                        icon: Icons.refresh_rounded,
                        onPressed: _retakePhoto,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      flex: 2,
                      child: AppButton(
                        text: 'Verify & Confirm',
                        variant: AppButtonVariant.success,
                        height: 48,
                        icon: Icons.check_rounded,
                        onPressed: () {
                          widget.onPhotoCaptured(_capturedResult!);
                          Navigator.pop(context);
                        },
                      ),
                    ),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}
