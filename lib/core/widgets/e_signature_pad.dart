import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import '../constants/app_colors.dart';

/// Class representing a individual drawn stroke on signature canvas
class SignatureStroke {
  final List<Offset> points;
  final Color color;
  final double strokeWidth;

  SignatureStroke({
    required this.points,
    this.color = Colors.black,
    this.strokeWidth = 3.0,
  });
}

/// CustomPainter that renders strokes on canvas
class _SignaturePainter extends CustomPainter {
  final List<SignatureStroke> strokes;
  final SignatureStroke? currentStroke;

  _SignaturePainter({
    required this.strokes,
    this.currentStroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    // Draw background guide line
    final gridPaint = Paint()
      ..color = Colors.grey.withValues(alpha: 0.2)
      ..strokeWidth = 1.0
      ..style = PaintingStyle.stroke;

    final dashWidth = 5.0;
    final dashSpace = 5.0;
    final startY = size.height * 0.75;
    double startX = 20.0;
    final endX = size.width - 20.0;

    while (startX < endX) {
      canvas.drawLine(
        Offset(startX, startY),
        Offset(startX + dashWidth, startY),
        gridPaint,
      );
      startX += dashWidth + dashSpace;
    }

    // Draw past strokes
    for (final stroke in strokes) {
      _drawStroke(canvas, stroke);
    }

    // Draw active stroke
    if (currentStroke != null) {
      _drawStroke(canvas, currentStroke!);
    }
  }

  void _drawStroke(Canvas canvas, SignatureStroke stroke) {
    if (stroke.points.isEmpty) return;

    final paint = Paint()
      ..color = stroke.color
      ..strokeWidth = stroke.strokeWidth
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..style = PaintingStyle.stroke;

    if (stroke.points.length == 1) {
      canvas.drawCircle(stroke.points.first, stroke.strokeWidth / 2, paint);
      return;
    }

    final path = Path();
    path.moveTo(stroke.points.first.dx, stroke.points.first.dy);

    for (int i = 1; i < stroke.points.length - 1; i++) {
      final p0 = stroke.points[i];
      final p1 = stroke.points[i + 1];
      final controlPoint = p0;
      final endPoint = Offset((p0.dx + p1.dx) / 2, (p0.dy + p1.dy) / 2);
      path.quadraticBezierTo(controlPoint.dx, controlPoint.dy, endPoint.dx, endPoint.dy);
    }

    if (stroke.points.length > 1) {
      path.lineTo(stroke.points.last.dx, stroke.points.last.dy);
    }

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant _SignaturePainter oldDelegate) => true;
}

/// Mobile Interactive Touch Signature Pad Widget
class ESignaturePad extends StatefulWidget {
  final double height;
  final Color strokeColor;
  final double strokeWidth;
  final ValueChanged<bool>? onSignatureChanged;

  const ESignaturePad({
    super.key,
    this.height = 220,
    this.strokeColor = const Color(0xFF0F172A),
    this.strokeWidth = 3.0,
    this.onSignatureChanged,
  });

  @override
  State<ESignaturePad> createState() => ESignaturePadState();
}

class ESignaturePadState extends State<ESignaturePad> {
  final List<SignatureStroke> _strokes = [];
  SignatureStroke? _currentStroke;
  final GlobalKey _repaintKey = GlobalKey();

  bool get hasSignature => _strokes.isNotEmpty;

  void clear() {
    setState(() {
      _strokes.clear();
      _currentStroke = null;
    });
    widget.onSignatureChanged?.call(false);
  }

  void undo() {
    if (_strokes.isNotEmpty) {
      setState(() {
        _strokes.removeLast();
      });
      widget.onSignatureChanged?.call(_strokes.isNotEmpty);
    }
  }

  /// Exports signature drawing to PNG bytes
  Future<Uint8List?> exportPngBytes() async {
    if (_strokes.isEmpty) return null;

    try {
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(recorder);
      const size = Size(400, 200);

      // White background for PNG signature rendering
      final bgPaint = Paint()..color = Colors.transparent;
      canvas.drawRect(Rect.fromLTWH(0, 0, size.width, size.height), bgPaint);

      // Scaled strokes
      final painter = _SignaturePainter(strokes: _strokes);
      painter.paint(canvas, size);

      final picture = recorder.endRecording();
      final img = await picture.toImage(size.width.toInt(), size.height.toInt());
      final byteData = await img.toByteData(format: ui.ImageByteFormat.png);
      return byteData?.buffer.asUint8List();
    } catch (e) {
      debugPrint('Error exporting signature bytes: $e');
      return null;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      key: _repaintKey,
      height: widget.height,
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.grey.shade300, width: 1.5),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 8,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(12),
        child: Stack(
          children: [
            GestureDetector(
              onPanStart: (details) {
                setState(() {
                  _currentStroke = SignatureStroke(
                    points: [details.localPosition],
                    color: widget.strokeColor,
                    strokeWidth: widget.strokeWidth,
                  );
                });
              },
              onPanUpdate: (details) {
                if (_currentStroke != null) {
                  setState(() {
                    _currentStroke!.points.add(details.localPosition);
                  });
                }
              },
              onPanEnd: (details) {
                if (_currentStroke != null && _currentStroke!.points.isNotEmpty) {
                  setState(() {
                    _strokes.add(_currentStroke!);
                    _currentStroke = null;
                  });
                  widget.onSignatureChanged?.call(true);
                }
              },
              child: RepaintBoundary(
                child: CustomPaint(
                  painter: _SignaturePainter(
                    strokes: _strokes,
                    currentStroke: _currentStroke,
                  ),
                  size: Size.infinite,
                ),
              ),
            ),
            Positioned(
              right: 12,
              bottom: 12,
              child: Text(
                'Sign inside the line',
                style: TextStyle(
                  fontSize: 11,
                  fontStyle: FontStyle.italic,
                  color: Colors.grey.shade500,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Dialog containing ESignaturePad for full-screen signature modal
class ESignatureDialog extends StatefulWidget {
  const ESignatureDialog({super.key});

  @override
  State<ESignatureDialog> createState() => _ESignatureDialogState();
}

class _ESignatureDialogState extends State<ESignatureDialog> {
  final GlobalKey<ESignaturePadState> _padKey = GlobalKey();
  bool _hasSignature = false;

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;

    return AlertDialog(
      backgroundColor: isDark ? const Color(0xFF1E293B) : Colors.white,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      contentPadding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.draw_rounded, color: primaryColor, size: 22),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Draw E-Signature',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.bold,
                    color: isDark ? Colors.white : AppColors.textPrimaryLight,
                  ),
                ),
                Text(
                  'Use your finger or stylus to sign below',
                  style: TextStyle(
                    fontSize: 12,
                    color: isDark ? Colors.white70 : Colors.grey.shade600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SizedBox(
        width: MediaQuery.of(context).size.width * 0.85,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ESignaturePad(
              key: _padKey,
              height: 220,
              onSignatureChanged: (hasSig) {
                setState(() {
                  _hasSignature = hasSig;
                });
              },
            ),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                TextButton.icon(
                  onPressed: () => _padKey.currentState?.undo(),
                  icon: Icon(Icons.undo_rounded, size: 16, color: isDark ? Colors.white70 : Colors.grey.shade700),
                  label: Text('Undo', style: TextStyle(color: isDark ? Colors.white70 : Colors.grey.shade700)),
                  style: TextButton.styleFrom(foregroundColor: isDark ? Colors.white70 : Colors.grey.shade700),
                ),
                TextButton.icon(
                  onPressed: () => _padKey.currentState?.clear(),
                  icon: const Icon(Icons.delete_outline_rounded, size: 16, color: Colors.redAccent),
                  label: const Text('Clear', style: TextStyle(color: Colors.redAccent)),
                  style: TextButton.styleFrom(foregroundColor: Colors.redAccent),
                ),
              ],
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        OutlinedButton(
          onPressed: () => Navigator.pop(context, null),
          style: OutlinedButton.styleFrom(
            foregroundColor: isDark ? Colors.white70 : Colors.grey.shade800,
            side: BorderSide(color: isDark ? Colors.white30 : Colors.grey.shade400),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
          ),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _hasSignature
              ? () async {
                  final bytes = await _padKey.currentState?.exportPngBytes();
                  if (context.mounted) {
                    Navigator.pop(context, bytes);
                  }
                }
              : null,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 10),
          ),
          icon: const Icon(Icons.check_circle_outline_rounded, size: 18),
          label: const Text('Save Signature'),
        ),
      ],
    );
  }
}

/// Interactive Preview Box used inside forms to display drawn signature or trigger signature modal
class ESignaturePreviewBox extends StatelessWidget {
  final Uint8List? signatureBytes;
  final VoidCallback onTapSign;
  final VoidCallback? onClear;
  final String label;

  const ESignaturePreviewBox({
    super.key,
    required this.signatureBytes,
    required this.onTapSign,
    this.onClear,
    this.label = 'Employee Digital Signature',
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = isDark ? AppColors.primaryLight : AppColors.primary;
    final hasSig = signatureBytes != null && signatureBytes!.isNotEmpty;

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            Expanded(
              child: Text(
                label,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: isDark ? Colors.white70 : const Color(0xFF334155),
                ),
              ),
            ),
            if (hasSig && onClear != null) ...[
              const SizedBox(width: 6),
              GestureDetector(
                onTap: onClear,
                child: Text(
                  'Change',
                  style: TextStyle(
                    fontSize: 11,
                    fontWeight: FontWeight.bold,
                    color: primaryColor,
                  ),
                ),
              ),
            ],
          ],
        ),
        const SizedBox(height: 6),
        InkWell(
          onTap: onTapSign,
          borderRadius: BorderRadius.circular(12),
          child: Container(
            height: 115,
            width: double.infinity,
            decoration: BoxDecoration(
              color: hasSig
                  ? (isDark ? const Color(0xFF1E293B) : Colors.white)
                  : (isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC)),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: hasSig ? primaryColor : (isDark ? Colors.white24 : Colors.grey.shade300),
                width: hasSig ? 1.8 : 1.2,
              ),
              boxShadow: hasSig
                  ? [
                      BoxShadow(
                        color: primaryColor.withValues(alpha: 0.12),
                        blurRadius: 8,
                        offset: const Offset(0, 2),
                      ),
                    ]
                  : null,
            ),
            child: hasSig
                ? ClipRRect(
                    borderRadius: BorderRadius.circular(10),
                    child: Stack(
                      children: [
                        Center(
                          child: Padding(
                            padding: const EdgeInsets.all(8.0),
                            child: Image.memory(
                              signatureBytes!,
                              fit: BoxFit.contain,
                            ),
                          ),
                        ),
                        Positioned(
                          right: 8,
                          top: 8,
                          child: Container(
                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: AppColors.success.withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.check_circle, size: 12, color: AppColors.success),
                                SizedBox(width: 4),
                                Text(
                                  'Signed',
                                  style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: AppColors.success,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ],
                    ),
                  )
                : Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          padding: const EdgeInsets.all(8),
                          decoration: BoxDecoration(
                            color: primaryColor.withValues(alpha: 0.1),
                            shape: BoxShape.circle,
                          ),
                          child: Icon(
                            Icons.draw_rounded,
                            color: primaryColor,
                            size: 20,
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          'Tap to add E-Signature',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            color: primaryColor,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          'Touch screen to sign',
                          textAlign: TextAlign.center,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                            fontSize: 10,
                            color: isDark ? Colors.white54 : Colors.grey.shade500,
                          ),
                        ),
                      ],
                    ),
                  ),
          ),
        ),
      ],
    );
  }
}
