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
      qty: json['qty']?.toString() ?? '1 pcs',
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
  static const String _defaultApiKey =
      String.fromEnvironment('GEMINI_API_KEY', defaultValue: '');

  /// Cleans speech-to-text misrecognized terms, typos, and formatting using Gemini AI (or local phonetic dictionary).
  Future<String> cleanSpeechText(
    String rawSpeech, {
    String? customApiKey,
  }) async {
    final text = rawSpeech.trim();
    if (text.isEmpty) return text;

    final apiKey = (customApiKey != null && customApiKey.isNotEmpty)
        ? customApiKey
        : _defaultApiKey;

    if (apiKey.isNotEmpty) {
      try {
        final model = GenerativeModel(
          model: 'gemini-1.5-flash-latest',
          apiKey: apiKey,
        );
        const prompt = '''
You are a speech-to-text post-processing assistant for engineering and field service dictation.
Clean and correct misheard engineering terms, technical acronyms, numbers, and units in the raw dictation text.
Examples:
- "cap acid or" -> "capacitor"
- "fifty u f" -> "50uF"
- "d b box" -> "DB Box"
- "m c b" -> "MCB"
- "free on" -> "freon"
- "see see tv" -> "CCTV"
- "b m s" -> "BMS"

Only return the corrected dictation text with proper punctuation. Do not add conversational commentary.
''';
        final response =
            await model.generateContent([Content.text('$prompt\n\nRaw Text:\n"$text"')]);
        final cleaned = response.text?.trim();
        if (cleaned != null && cleaned.isNotEmpty) return cleaned;
      } catch (e) {
        debugPrint('Gemini speech clean note: $e');
      }
    }

    return _cleanLocally(text);
  }

  /// Primary extraction method with target category support ('all', 'defects', 'work', 'materials')
  Future<AiExtractedReportData> extractReportFields(
    String rawText, {
    String? customApiKey,
    String targetCategory = 'all',
  }) async {
    final text = await cleanSpeechText(rawText, customApiKey: customApiKey);
    if (text.isEmpty) {
      return _emptyReport();
    }

    final apiKey = (customApiKey != null && customApiKey.isNotEmpty)
        ? customApiKey
        : _defaultApiKey;

    if (apiKey.isNotEmpty) {
      try {
        final result =
            await _extractWithGemini(text, apiKey, targetCategory: targetCategory);
        if (result != null) return result;
      } catch (e) {
        debugPrint('Gemini AI extraction fallback note: $e');
      }
    }

    // Fallback to local heuristic rule parser when offline or without API key
    return _parseHeuristically(text, targetCategory: targetCategory);
  }

  Future<AiExtractedReportData?> _extractWithGemini(
    String rawText,
    String apiKey, {
    String targetCategory = 'all',
  }) async {
    final model = GenerativeModel(
      model: 'gemini-1.5-flash-latest',
      apiKey: apiKey,
      generationConfig: GenerationConfig(
        responseMimeType: 'application/json',
      ),
    );

    final systemPrompt = '''
You are an expert field engineering service assistant for Fusion 360 app.
Analyze the user's raw voice/text notes about a field service job and extract JSON matching this exact schema:

{
  "defectsFound": "Detailed description of initial defects, issues, faults, or leaks observed BEFORE repair",
  "detailsOfWorkDone": "Step-by-step technical repair actions, cleaning, testing, or servicing performed",
  "callType": "One of: Complaint, Breakdown, Preventive",
  "priority": "One of: Urgent, Normal",
  "suggestedServices": ["Relevant services from: A/C, CCTV, Fire Fighting, Carpentry, BMS, Electrical, SMATV, Generator, Civil, Access Control, Plumbing, Intercom, Cleaning Service, Painting, Soft Services"],
  "materials": [
    { "material": "Name of physical spare part or material replaced/used", "qty": "Quantity with unit (e.g. 1 pcs, 2 meters)" }
  ]
}

SPEECH CORRECTION & DISAMBIGUATION RULES:
1. Auto-correct misheard speech words (e.g. "cap acid or" -> "capacitor", "d b box" -> "DB Box", "fifty u f" -> "50uF").
2. "defectsFound": MUST ONLY contain initial fault/issue observations (e.g. "Run capacitor burnt, filter clogged, A/C not cooling"). Never put repair actions here.
3. "detailsOfWorkDone": MUST ONLY contain repair actions performed by technician (e.g. "Replaced run capacitor, cleaned air filter, tested cooling cycle"). Never put raw material lists here.
4. "materials": MUST ONLY contain physical spare parts/consumables replaced or used.
5. If target category is "$targetCategory": Focus primarily on extracting for $targetCategory while keeping fields strictly separated.
6. Only return valid JSON with no markdown syntax.
''';

    final prompt = '$systemPrompt\n\nUser Voice/Notes:\n"$rawText"';
    final response = await model.generateContent([Content.text(prompt)]);
    final responseText = response.text;

    if (responseText != null && responseText.isNotEmpty) {
      try {
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

  /// Offline heuristic rule parser with speech cleaning and clause classification
  AiExtractedReportData _parseHeuristically(
    String rawText, {
    String targetCategory = 'all',
  }) {
    final cleanedText = _cleanLocally(rawText);
    final textLower = cleanedText.toLowerCase();

    // Call Type detection
    String callType = 'Complaint';
    if (textLower.contains('breakdown') ||
        textLower.contains('failed') ||
        textLower.contains('burnt') ||
        textLower.contains('emergency')) {
      callType = 'Breakdown';
    } else if (textLower.contains('preventive') ||
        textLower.contains('routine') ||
        textLower.contains('servicing') ||
        textLower.contains('checkup')) {
      callType = 'Preventive';
    }

    // Priority detection
    String priority = 'Normal';
    if (textLower.contains('urgent') ||
        textLower.contains('critical') ||
        textLower.contains('asap') ||
        textLower.contains('emergency')) {
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

    final RegExp matWithQtyRegex = RegExp(
      r'([\w\s-]{3,35})\s*\(([^)]+)\)',
      caseSensitive: false,
    );
    for (final match in matWithQtyRegex.allMatches(cleanedText)) {
      final name = match.group(1)?.trim();
      final qty = match.group(2)?.trim();
      if (name != null && name.length > 2) {
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
      for (final match in actionRegex.allMatches(cleanedText)) {
        final matName = match.group(1)?.trim();
        if (matName != null && matName.length > 2) {
          materials.add(AiMaterialItem(
            material: _capitalizeWords(matName),
            qty: '1 pcs',
          ));
        }
      }
    }

    // Disambiguate Defects Found vs Details of Work Done
    final List<String> clauses = cleanedText
        .split(RegExp(r'[.\n;]+'))
        .map((s) => s.trim())
        .where((s) => s.isNotEmpty)
        .toList();

    final List<String> defectClauses = [];
    final List<String> workClauses = [];

    const defectKeywords = [
      'found', 'observed', 'issue', 'defect', 'damaged', 'broken',
      'leak', 'leaking', 'fault', 'tripped', 'burnt', 'failed',
      'noise', 'error', 'not working', 'high temp', 'low pressure', 'complaint'
    ];

    const workKeywords = [
      'replaced', 'repaired', 'fixed', 'cleaned', 'installed', 'tested',
      'checked', 'resolved', 'serviced', 'calibrated', 'tightened',
      'adjusted', 'refilled', 'welded', 'changed'
    ];

    for (final clause in clauses) {
      final cLower = clause.toLowerCase();
      final hasDefectKw = defectKeywords.any((kw) => cLower.contains(kw));
      final hasWorkKw = workKeywords.any((kw) => cLower.contains(kw));

      if (hasDefectKw && !hasWorkKw) {
        defectClauses.add(clause);
      } else if (hasWorkKw && !hasDefectKw) {
        workClauses.add(clause);
      } else if (hasWorkKw && hasDefectKw) {
        workClauses.add(clause);
      } else {
        if (cLower.startsWith('replaced') || cLower.startsWith('installed') || cLower.startsWith('cleaned')) {
          workClauses.add(clause);
        } else {
          defectClauses.add(clause);
        }
      }
    }

    String defectsText = defectClauses.isNotEmpty
        ? '${defectClauses.join('. ')}.'
        : (workClauses.isNotEmpty
            ? 'Inspection conducted for reported service call.'
            : cleanedText);

    String workDoneText = workClauses.isNotEmpty
        ? '${workClauses.join('. ')}.'
        : (defectClauses.isNotEmpty
            ? 'Inspected and verified on site.'
            : cleanedText);

    // Apply target category filter if specified
    if (targetCategory == 'defects') {
      workDoneText = '';
    } else if (targetCategory == 'work') {
      defectsText = '';
    } else if (targetCategory == 'materials') {
      defectsText = '';
      workDoneText = '';
    }

    return AiExtractedReportData(
      defectsFound: defectsText,
      detailsOfWorkDone: workDoneText,
      callType: callType,
      priority: priority,
      suggestedServices: services,
      materials: materials,
      isOfflineFallback: true,
    );
  }

  String _cleanLocally(String input) {
    String text = input;
    final map = {
      RegExp(r'\bcap\s*acid\s*or\b|\bcapaciter\b', caseSensitive: false): 'capacitor',
      RegExp(r'\bfifty\s*u\s*f\b|\b50\s*uf\b', caseSensitive: false): '50uF',
      RegExp(r'\bd\s*b\s*box\b|\bdbbox\b', caseSensitive: false): 'DB Box',
      RegExp(r'\bm\s*c\s*b\b', caseSensitive: false): 'MCB',
      RegExp(r'\bsee\s*see\s*t\s*v\b|\bc\s*c\s*t\s*v\b', caseSensitive: false): 'CCTV',
      RegExp(r'\bb\s*m\s*s\b', caseSensitive: false): 'BMS',
      RegExp(r'\bhair\s*con\b|\baircon\b', caseSensitive: false): 'A/C',
      RegExp(r'\bfree\s*on\b', caseSensitive: false): 'freon',
      RegExp(r'\bthree\s*phase\b', caseSensitive: false): '3-Phase',
    };
    map.forEach((pattern, replacement) {
      text = text.replaceAll(pattern, replacement);
    });
    return text;
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
