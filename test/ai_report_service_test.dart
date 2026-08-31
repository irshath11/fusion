import 'package:flutter_test/flutter_test.dart';
import 'package:attendance_app/core/services/ai_report_service.dart';

void main() {
  group('AiReportService Unit Tests', () {
    final aiService = AiReportService();

    test('Parses AC breakdown and materials correctly in offline heuristic mode', () async {
      const rawText =
          'Attended AC breakdown call. Found burnt 50uF capacitor and clogged filter. Replaced 50uF Capacitor (1 pcs) and Air Filter (1 pcs). Cleaned coils and tested.';

      final result = await aiService.extractReportFields(rawText);

      expect(result.isOfflineFallback, isTrue);
      expect(result.callType, 'Breakdown');
      expect(result.suggestedServices, contains('A/C'));
      expect(result.materials.length, greaterThanOrEqualTo(1));

      final firstMat = result.materials.first;
      expect(firstMat.material, contains('Capacitor'));
    });

    test('Parses electrical urgent call correctly', () async {
      const rawText =
          'Urgent electrical issue. Main DB breaker tripped. Replaced 32A MCB breaker (1 set) and re-routed wiring.';

      final result = await aiService.extractReportFields(rawText);

      expect(result.priority, 'Urgent');
      expect(result.suggestedServices, contains('Electrical'));
    });

    test('Handles empty text gracefully', () async {
      final result = await aiService.extractReportFields('');
      expect(result.defectsFound, isEmpty);
      expect(result.detailsOfWorkDone, isEmpty);
      expect(result.materials, isEmpty);
    });
  });
}
