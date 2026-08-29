import 'package:flutter/material.dart';
import 'package:speech_to_text/speech_to_text.dart' as stt;
import '../constants/app_colors.dart';
import '../services/ai_report_service.dart';

class AiVoiceReportBottomSheet extends StatefulWidget {
  final Function(AiExtractedReportData data) onExtracted;

  const AiVoiceReportBottomSheet({
    super.key,
    required this.onExtracted,
  });

  @override
  State<AiVoiceReportBottomSheet> createState() =>
      _AiVoiceReportBottomSheetState();
}

class _AiVoiceReportBottomSheetState extends State<AiVoiceReportBottomSheet>
    with SingleTickerProviderStateMixin {
  final TextEditingController _notesController = TextEditingController();
  final TextEditingController _apiKeyController = TextEditingController();
  final AiReportService _aiService = AiReportService();
  final stt.SpeechToText _speech = stt.SpeechToText();

  bool _isListening = false;
  bool _speechAvailable = false;
  bool _isProcessing = false;
  bool _showApiKeyInput = false;

  late AnimationController _pulseController;
  late Animation<double> _pulseAnimation;

  final List<String> _samplePrompts = [
    'A/C Breakdown: Faulty capacitor & burnt wiring. Replaced 50uF capacitor and 2m wire. Running at 20C.',
    'Electrical Repair: Main DB breaker tripped. Found short circuit in line 3. Replaced 32A MCB.',
    'Plumbing Servicing: Water leak at main valve. Installed 1-inch gate valve and sealed joints.',
  ];

  @override
  void initState() {
    super.initState();
    _initSpeech();

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _pulseAnimation = Tween<double>(begin: 1.0, end: 1.25).animate(
      CurvedAnimation(parent: _pulseController, curve: Curves.easeInOut),
    );
  }

  @override
  void dispose() {
    _pulseController.dispose();
    _notesController.dispose();
    _apiKeyController.dispose();
    _speech.stop();
    super.dispose();
  }

  Future<void> _initSpeech() async {
    try {
      bool available = await _speech.initialize(
        onStatus: (status) {
          if (status == 'done' || status == 'notListening') {
            if (mounted) setState(() => _isListening = false);
          }
        },
        onError: (errorNotification) {
          if (mounted) setState(() => _isListening = false);
        },
      );
      if (mounted) {
        setState(() => _speechAvailable = available);
      }
    } catch (e) {
      if (mounted) setState(() => _speechAvailable = false);
    }
  }

  void _toggleListening() async {
    if (_isListening) {
      await _speech.stop();
      setState(() => _isListening = false);
    } else {
      if (!_speechAvailable) {
        await _initSpeech();
      }
      if (_speechAvailable) {
        setState(() => _isListening = true);
        await _speech.listen(
          onResult: (result) {
            if (mounted && result.recognizedWords.isNotEmpty) {
              setState(() {
                _notesController.text = result.recognizedWords;
                _notesController.selection = TextSelection.fromPosition(
                  TextPosition(offset: _notesController.text.length),
                );
              });
            }
          },
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Speech recognition not supported or permission denied.'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  Future<void> _processNotes() async {
    final text = _notesController.text.trim();
    if (text.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please speak or type job notes first.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() => _isProcessing = true);

    try {
      final data = await _aiService.extractReportFields(
        text,
        customApiKey: _apiKeyController.text.trim(),
      );

      if (mounted) {
        Navigator.pop(context);
        widget.onExtracted(data);
      }
    } catch (e) {
      if (mounted) {
        setState(() => _isProcessing = false);
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('AI extraction failed: $e'),
            backgroundColor: AppColors.error,
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bottomPadding = MediaQuery.of(context).viewInsets.bottom;
    final surfaceColor = isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final bgColor = isDark ? AppColors.backgroundDark : AppColors.backgroundLight;
    final textPrimary = isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary = isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor = isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;

    return Padding(
      padding: EdgeInsets.only(bottom: bottomPadding),
      child: Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header & Drag Handle
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: borderColor,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.auto_awesome,
                      color: Colors.white,
                      size: 24,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI Service Report Assistant',
                          style: TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: textPrimary,
                          ),
                        ),
                        Text(
                          'Dictate or type raw site notes to auto-fill fields',
                          style: TextStyle(
                            fontSize: 12,
                            color: textSecondary,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),

              const SizedBox(height: 20),

              // Voice Dictation Box
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: _isListening
                      ? AppColors.primary.withValues(alpha: 0.08)
                      : bgColor,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _isListening
                        ? AppColors.primary
                        : borderColor,
                    width: _isListening ? 1.5 : 1,
                  ),
                ),
                child: Column(
                  children: [
                    TextField(
                      controller: _notesController,
                      maxLines: 4,
                      style: TextStyle(color: textPrimary),
                      decoration: InputDecoration(
                        hintText:
                            'Speak or type work done (e.g. "Replaced A/C run capacitor 50uF, cleaned filter, tested cooling...")',
                        hintStyle: TextStyle(
                          fontSize: 13,
                          color: textSecondary,
                        ),
                        border: InputBorder.none,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                      children: [
                        Text(
                          _isListening
                              ? '🎙️ Listening... Speak now'
                              : (_notesController.text.isNotEmpty
                                  ? '${_notesController.text.split(' ').length} words'
                                  : 'Tap mic to speak'),
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: _isListening
                                ? FontWeight.bold
                                : FontWeight.normal,
                            color: _isListening
                                ? AppColors.primary
                                : textSecondary,
                          ),
                        ),
                        ScaleTransition(
                          scale: _isListening
                              ? _pulseAnimation
                              : const AlwaysStoppedAnimation(1.0),
                          child: InkWell(
                            onTap: _toggleListening,
                            borderRadius: BorderRadius.circular(30),
                            child: Container(
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: _isListening
                                    ? AppColors.primary
                                    : AppColors.secondary,
                                boxShadow: _isListening
                                    ? [
                                        BoxShadow(
                                          color: AppColors.primary
                                              .withValues(alpha: 0.4),
                                          blurRadius: 10,
                                          spreadRadius: 2,
                                        )
                                      ]
                                    : null,
                              ),
                              child: Icon(
                                _isListening ? Icons.mic : Icons.mic_none,
                                color: Colors.white,
                                size: 22,
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),

              const SizedBox(height: 16),

              // Sample Prompt Chips
              Text(
                'Quick Sample Notes:',
                style: TextStyle(
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  color: textSecondary,
                ),
              ),
              const SizedBox(height: 6),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: _samplePrompts.map((prompt) {
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ActionChip(
                        label: Text(
                          prompt.length > 32
                              ? '${prompt.substring(0, 32)}...'
                              : prompt,
                          style: TextStyle(fontSize: 11, color: textPrimary),
                        ),
                        backgroundColor: surfaceColor,
                        side: BorderSide(
                          color: AppColors.primary.withValues(alpha: 0.3),
                        ),
                        onPressed: () {
                          setState(() {
                            _notesController.text = prompt;
                          });
                        },
                      ),
                    );
                  }).toList(),
                ),
              ),

              const SizedBox(height: 12),

              // Collapsible API Key settings
              GestureDetector(
                onTap: () {
                  setState(() => _showApiKeyInput = !_showApiKeyInput);
                },
                child: Row(
                  children: [
                    Icon(
                      _showApiKeyInput
                          ? Icons.keyboard_arrow_up
                          : Icons.key_outlined,
                      size: 16,
                      color: textSecondary,
                    ),
                    const SizedBox(width: 4),
                    Text(
                      _showApiKeyInput
                          ? 'Hide Gemini API Settings'
                          : 'Custom Gemini API Key (Optional)',
                      style: TextStyle(
                        fontSize: 11,
                        color: textSecondary,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ],
                ),
              ),

              if (_showApiKeyInput) ...[
                const SizedBox(height: 8),
                TextField(
                  controller: _apiKeyController,
                  obscureText: true,
                  style: TextStyle(color: textPrimary),
                  decoration: InputDecoration(
                    labelText: 'Gemini API Key',
                    hintText: 'Enter custom API Key (or leave blank for default)',
                    hintStyle: TextStyle(fontSize: 11, color: textSecondary),
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                    contentPadding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                  ),
                ),
              ],

              const SizedBox(height: 20),

              // Action Buttons
              if (_isProcessing)
                Center(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Column(
                      children: const [
                        CircularProgressIndicator(),
                        SizedBox(height: 10),
                        Text(
                          'Processing notes with Gemini AI...',
                          style: TextStyle(
                            fontSize: 13,
                            color: AppColors.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                )
              else
                SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    onPressed: _processNotes,
                    style: ElevatedButton.styleFrom(
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      padding: EdgeInsets.zero,
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                    ),
                    child: Ink(
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          colors: [AppColors.primary, AppColors.primaryLight],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        ),
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: Container(
                        alignment: Alignment.center,
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: const [
                            Icon(Icons.auto_awesome, color: Colors.white, size: 20),
                            SizedBox(width: 8),
                            Text(
                              'Auto-Fill Report with AI',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: Colors.white,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),

              const SizedBox(height: 10),
            ],
          ),
        ),
      ),
    );
  }
}
