import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:google_generative_ai/google_generative_ai.dart';

class AiMaterialItem {
  final String material;
  final String qty;

  AiMaterialItem({required this.material, required this.qty});

  Map<String, dynamic> toJson() => {
        'material': material,
        'qty': qty,
      };

  factory AiMaterialItem.fromJson(Map<String, dynamic> json) {
    return AiMaterialItem(
      material: json['material']?.toString() ?? '',
      qty: json['qty']?.toString() ?? '1',
    );
  }
}

class AiExtractedReportData {
  final String defectsFound;
  final String detailsOfWorkDone;
  final String callType; // 'Complaint', 'Breakdown', 'Preventive'
  final String priority; // 'Urgent', 'Normal'
  final List<String> suggestedServices;
  final List<AiMaterialItem> materials;
  final bool isOfflineFallback;

  AiExtractedReportData({
    required this.defectsFound,
    required this.detailsOfWorkDone,
    required this.callType,
    required this.priority,
    required this.suggestedServices,
    required this.materials,
    this.isOfflineFallback = false,
  });

  factory AiExtractedReportData.fromJson(
    Map<String, dynamic> json, {
    bool isOffline = false,
  }) {
    final servicesRaw = json['suggestedServices'];
    final List<String> services = servicesRaw is List
        ? servicesRaw.map((e) => e.toString()).toList()
        : [];

    final materialsRaw = json['materials'];
    final List<AiMaterialItem> mats = [];
    if (materialsRaw is List) {
      for (final item in materialsRaw) {
        if (item is Map<String, dynamic>) {
          mats.add(AiMaterialItem.fromJson(item));
        } else if (item is Map) {
          mats.add(AiMaterialItem.fromJson(Map<String, dynamic>.from(item)));
        }
      }
    }

    return AiExtractedReportData(
      defectsFound: json['defectsFound']?.toString() ?? '',
      detailsOfWorkDone: json['detailsOfWorkDone']?.toString() ?? '',
      callType: json['callType']?.toString() ?? 'Complaint',
      priority: json['priority']?.toString() ?? 'Normal',
      suggestedServices: services,
      materials: mats,
      isOfflineFallback: isOffline,
    );
  }
}

class AiReportService {
  // Default system fallback API key can be set via const or environment
  static const String _defaultApiKey = String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Primary extraction method: tries Gemini AI first, falls back to heuristic rule engine.
  Future<AiExtractedReportData> extractReportFields(
    String rawText, {
    String? customApiKey,
  }) async {
    final text = rawText.trim();
    if (text.isEmpty) {
      return _emptyReport();
    }

    final apiKey = (customApiKey != null && customApiKey.isNotEmpty)
        ? customApiKey
        : _defaultApiKey;

    if (apiKey.isNotEmpty) {
      try {
        final result = await _extractWithGemini(text, apiKey);
        if (result != null) return result;
      } catch (e) {
        debugPrint('Gemini AI extraction fallback note: $e');
      }
    }

    // Fallback to local heuristic rule parser when offline or without API key
    return _parseHeuristically(text);
  }

  Future<AiExtractedReportData?> _extractWithGemini(
    String rawText,
    String apiKey,
  ) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    const systemPrompt = '''
You are an expert field engineering service assistant for Fusion 360 app.
Analyze the user's raw voice/text notes about a field service job and extract JSON formatted data matching this schema exactly:

{
  "defectsFound": "Detailed summary of inspection defects, issues, or faults observed",
  "detailsOfWorkDone": "Step-by-step technical details of actions taken and resolution achieved",
  "callType": "One of: Complaint, Breakdown, Preventive",
  "priority": "One of: Urgent, Normal",
  "suggestedServices": ["List of relevant services from: A/C, CCTV, Fire Fighting, Carpentry, BMS, Electrical, SMATV, Generator, Civil, Access Control, Plumbing, Intercom, Cleaning Service, Painting, Soft Services"],
  "materials": [
    { "material": "Material or part name", "qty": "Quantity with unit (e.g. 1 pcs, 2 meters)" }
  ]
}

Only return valid JSON with no markdown formatting.
''';

    final prompt = '$systemPrompt\n\nUser Notes:\n"$rawText"';
    final response = await model.generateContent([Content.text(prompt)]);
    final responseText = response.text;

    if (responseText != null && responseText.isNotEmpty) {
      try {
        // Strip markdown code fences if present
        String cleanedJson = responseText.trim();
        if (cleanedJson.startsWith('```json')) {
          cleanedJson = cleanedJson.substring(7);
        }
        if (cleanedJson.startsWith('```')) {
          cleanedJson = cleanedJson.substring(3);
        }
        if (cleanedJson.endsWith('```')) {
          cleanedJson = cleanedJson.substring(0, cleanedJson.length - 3);
        }
        cleanedJson = cleanedJson.trim();

        final Map<String, dynamic> parsed = jsonDecode(cleanedJson);
        return AiExtractedReportData.fromJson(parsed, isOffline: false);
      } catch (e) {
        debugPrint('JSON parsing error in Gemini response: $e');
      }
    }
    return null;
  }

  /// Offline heuristic rule parser extracting structured data without internet/API key
  AiExtractedReportData _parseHeuristically(String rawText) {
    final textLower = rawText.toLowerCase();

    // Call Type detection
    String callType = 'Complaint';
    if (textLower.contains('breakdown') || textLower.contains('failed') || textLower.contains('burnt') || textLower.contains('emergency')) {
      callType = 'Breakdown';
    } else if (textLower.contains('preventive') || textLower.contains('routine') || textLower.contains('servicing') || textLower.contains('checkup')) {
      callType = 'Preventive';
    }

    // Priority detection
    String priority = 'Normal';
    if (textLower.contains('urgent') || textLower.contains('critical') || textLower.contains('asap') || textLower.contains('emergency')) {
      priority = 'Urgent';
    }

    // Suggested Services matching
    final List<String> services = [];
    final serviceKeywords = <String, List<String>>{
      'A/C': ['ac', 'aircon', 'chiller', 'compressor', 'cooling', 'hvac', 'refrigerant', 'freon', 'fan coil', 'thermostat'],
      'Electrical': ['electrical', 'wire', 'wiring', 'circuit', 'breaker', 'panel', 'switch', 'db box', 'cable', 'voltage', 'power'],
      'Plumbing': ['plumbing', 'pipe', 'leak', 'water', 'valve', 'drain', 'pump', 'faucet', 'sink'],
      'CCTV': ['cctv', 'camera', 'dvr', 'nvr', 'surveillance', 'video'],
      'BMS': ['bms', 'automation', 'building management', 'sensor'],
      'Access Control': ['access control', 'door lock', 'biometric', 'card reader', 'gate'],
      'Fire Fighting': ['fire', 'alarm', 'sprinkler', 'extinguisher', 'smoke detector'],
      'Generator': ['generator', 'diesel', 'genset', 'ats'],
      'Carpentry': ['door', 'lock', 'carpentry', 'hinge', 'cabinet', 'wood'],
      'Civil': ['civil', 'wall', 'tile', 'concrete', 'plaster'],
      'Painting': ['paint', 'painting', 'coating'],
      'Cleaning Service': ['clean', 'cleaning', 'dust', 'pantry'],
    };

    serviceKeywords.forEach((service, keywords) {
      if (keywords.any((kw) => textLower.contains(kw))) {
        services.add(service);
      }
    });

    if (services.isEmpty) {
      services.add('Electrical');
    }

    // Extract materials heuristically
    final List<AiMaterialItem> materials = [];

    // Look for parenthesized quantity patterns like "50uF Capacitor (1 pcs)" or "Air Filter (2 units)"
    final RegExp matWithQtyRegex = RegExp(
      r'([\w\s-]{3,35})\s*\(([^)]+)\)',
      caseSensitive: false,
    );
    for (final match in matWithQtyRegex.allMatches(rawText)) {
      final name = match.group(1)?.trim();
      final qty = match.group(2)?.trim();
      if (name != null && name.length > 2) {
        // Strip leading verb words like "replaced", "installed", "and" if present
        final cleanName = name
            .replaceAll(RegExp(r'^(?:and|replaced|installed|used|fixed|added|changed)\s+', caseSensitive: false), '')
            .trim();
        if (cleanName.length > 2) {
          materials.add(AiMaterialItem(
            material: _capitalizeWords(cleanName),
            qty: (qty != null && qty.isNotEmpty) ? qty : '1 pcs',
          ));
        }
      }
    }

    if (materials.isEmpty) {
      final RegExp actionRegex = RegExp(
        r'(?:replaced|used|installed|added|fixed|changed)\s+([a-zA-Z0-9\s-]{3,30})(?=[.,;\n]|$)',
        caseSensitive: false,
      );
      for (final match in actionRegex.allMatches(rawText)) {
        final matName = match.group(1)?.trim();
        if (matName != null && matName.length > 2) {
          materials.add(AiMaterialItem(
            material: _capitalizeWords(matName),
            qty: '1 pcs',
          ));
        }
      }
    }

    // Split text into defects and work done if sentences contain keywords
    String defects = rawText;
    String workDone = rawText;

    if (rawText.contains('.')) {
      final sentences = rawText.split('.').map((s) => s.trim()).where((s) => s.isNotEmpty).toList();
      final defectSentences = <String>[];
      final workSentences = <String>[];

      for (final sentence in sentences) {
        final sLower = sentence.toLowerCase();
        if (sLower.contains('found') || sLower.contains('issue') || sLower.contains('defect') || sLower.contains('damaged') || sLower.contains('broken') || sLower.contains('leak') || sLower.contains('fault')) {
          defectSentences.add(sentence);
        }
        if (sLower.contains('replaced') || sLower.contains('repaired') || sLower.contains('fixed') || sLower.contains('cleaned') || sLower.contains('installed') || sLower.contains('tested') || sLower.contains('checked') || sLower.contains('resolved')) {
          workSentences.add(sentence);
        }
      }

      if (defectSentences.isNotEmpty) {
        defects = '${defectSentences.join('. ')}.';
      }
      if (workSentences.isNotEmpty) {
        workDone = '${workSentences.join('. ')}.';
      }
    }

    return AiExtractedReportData(
      defectsFound: defects,
      detailsOfWorkDone: workDone,
      callType: callType,
      priority: priority,
      suggestedServices: services,
      materials: materials,
      isOfflineFallback: true,
    );
  }

  String _capitalizeWords(String str) {
    return str.split(' ').map((w) => w.isEmpty ? '' : '${w[0].toUpperCase()}${w.substring(1)}').join(' ');
  }

  AiExtractedReportData _emptyReport() {
    return AiExtractedReportData(
      defectsFound: '',
      detailsOfWorkDone: '',
      callType: 'Complaint',
      priority: 'Normal',
      suggestedServices: [],
      materials: [],
      isOfflineFallback: true,
    );
  }
}
