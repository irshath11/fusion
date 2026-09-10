# 12. AI Voice Reporting & Google Gemini AI Integration Feature

## Overview
The **AI Voice Reporting & Google Gemini AI Integration** feature introduces generative AI and interactive voice assistance into the enterprise field workforce platform. Field technicians and engineers can dictate field work notes using voice, which are automatically processed, phonetically corrected, and extracted into structured technical inspection reports using **Google Gemini AI** (`gemini-3.6-flash` / Gemini API) with automatic local heuristic fallback when offline.

---

## 1. Key Functionalities

### A. Google Gemini AI Engine (`AiReportService`)
1. **Phonetic Speech-to-Text Post-Processing & Engineering Term Cleansing (`cleanSpeechText`)**:
   - Field technicians often dictate in noisy industrial environments resulting in speech-to-text misrecognitions.
   - Cleans and corrects acoustic typos, phonetics, engineering acronyms, and units:
     - `"cap acid or"` ➔ `capacitor`
     - `"fifty u f"` ➔ `50uF`
     - `"d b box"` ➔ `DB Box`
     - `"m c b"` ➔ `MCB`
     - `"free on"` ➔ `freon`
     - `"see see tv"` ➔ `CCTV`
     - `"b m s"` ➔ `BMS`
     - `"comp res sir"` ➔ `compressor`
     - `"con den sir"` ➔ `condenser`
     - `"con tak ter"` ➔ `contactor`
     - `"ther mo stat"` ➔ `thermostat`
   - Strips conversational commentary and outputs clean, punctuated technical dictation.

2. **Automated Structured Field Extraction (`extractReportFields`)**:
   - Transforms unstructured field voice notes into structured JSON conforming to `AiExtractedReportData`:
     - **Defects Found (`defectsFound`)**: Initial faults, issues, and leaks observed *prior* to repair.
     - **Details of Work Done (`detailsOfWorkDone`)**: Step-by-step repair actions, cleaning, testing, or servicing performed.
     - **Call Type (`callType`)**: Classifies the call as `'Complaint'`, `'Breakdown'`, or `'Preventive'`.
     - **Priority (`priority`)**: Classifies urgency as `'Urgent'` or `'Normal'`.
     - **Suggested Services (`suggestedServices`)**: Categorizes matching services (e.g. `A/C`, `CCTV`, `Electrical`, `Plumbing`, `Fire Fighting`, `BMS`).
     - **Materials / Spare Parts Replaced (`materials`)**: Extracts list of physical components and units (e.g. `Run Capacitor - 50uF (1 pcs)`, `R410A Refrigerant (1.5 kg)`).

3. **Category-Targeted Voice Dictation**:
   - Supports targeted voice capture for specific sections (`targetCategory = 'all'`, `'defects'`, `'work'`, or `'materials'`).

4. **Zero-Connectivity Heuristic Rule Parser (`_parseHeuristically`)**:
   - When offline or operating without a cloud Gemini API key, automatically activates a deterministic heuristic rule parser.
   - Uses regex keyword matchers, defect dictionaries, action verbs (`replaced`, `cleaned`, `checked`, `fixed`), and quantity extractors to ensure 100% functionality in remote basements and offline job sites.

---

### B. Interactive AI Voice Report Assistant (`AiVoiceReportBottomSheet`)
1. **Interactive Modal Bottom Sheet UI**:
   - Displays a modern glassmorphic voice assistant interface with pulsing audio wave animations and status indicators.
   - Real-time listening indicator with microphone waveform visuals.

2. **Speech Recognition & Voice Synthesis**:
   - Integrated with `speech_to_text` for real-time dictation capture.
   - Integrated with `flutter_tts` for vocal confirmation, speaking back extracted summaries and status updates.

3. **Field Preview & One-Tap Population**:
   - Displays real-time chip previews of extracted services, materials, and categorized text.
   - Provides an **"Apply to Report"** action that populates the active form fields in `EmployeeReportGeneratorScreen`.

---

## 2. Technical Architecture & Data Models

### `AiExtractedReportData`
```dart
class AiExtractedReportData {
  final String defectsFound;
  final String detailsOfWorkDone;
  final String callType; // 'Complaint', 'Breakdown', 'Preventive'
  final String priority; // 'Urgent', 'Normal'
  final List<String> suggestedServices;
  final List<AiMaterialItem> materials;
  final bool isOfflineFallback;
}

class AiMaterialItem {
  final String material;
  final String qty;
}
```

### Prompt Engineering Architecture
```
System Prompt:
You are an expert field engineering service assistant for Fusion 360 app.
Analyze the user's raw voice/text notes about a field service job and extract JSON matching this exact schema:
{
  "defectsFound": "Detailed description of initial defects observed BEFORE repair",
  "detailsOfWorkDone": "Step-by-step technical repair actions performed",
  "callType": "One of: Complaint, Breakdown, Preventive",
  "priority": "One of: Urgent, Normal",
  "suggestedServices": ["A/C", "Electrical", ...],
  "materials": [ { "material": "...", "qty": "..." } ]
}
```

---

## 3. Source Files & Responsibilities

| File Path | Description |
| :--- | :--- |
| [`lib/core/services/ai_report_service.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/services/ai_report_service.dart) | Gemini AI integration service, speech cleansing, JSON extraction, and heuristic offline parser. |
| [`lib/core/widgets/ai_voice_report_bottom_sheet.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/lib/core/widgets/ai_voice_report_bottom_sheet.dart) | Interactive AI Voice Report assistant UI, speech-to-text listener, TTS audio output, and form auto-filler. |
| [`test/ai_report_service_test.dart`](file:///c:/Users/srirs/.gemini/antigravity-ide/scratch/attendance_app/test/ai_report_service_test.dart) | Unit test suite verifying Gemini payload formatting, speech cleansing, and heuristic extraction fallbacks. |
