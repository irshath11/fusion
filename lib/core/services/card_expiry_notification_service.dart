import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:intl/intl.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:http/http.dart' as http;
import '../../database/local_database_service.dart';
import '../../features/admin/domain/employee_card.dart';
import '../../features/admin/domain/employee_entity.dart';

class CardExpiryNotificationService {
  static const String defaultAdminEmail = 'sr.irshath@gmail.com, nasuru@fusionmaint.com';
  static const String defaultAdminPhone = '+971586939371';
  static final DateFormat _dateFormat = DateFormat('dd MMM yyyy');

  /// Filter all active cards that are expiring within [days] days (or already expired)
  static List<EmployeeCard> getExpiringCardsWithinDays(
    List<EmployeeCard> cards, {
    int days = 3,
  }) {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);

    return cards.where((c) {
      if (c.isDeleted) return false;
      final exp = DateTime(c.expiryDate.year, c.expiryDate.month, c.expiryDate.day);
      final diff = exp.difference(today).inDays;
      return diff <= days;
    }).toList();
  }

  /// Format professional compliance WhatsApp reminder message
  static String generateWhatsAppMessage({
    required List<EmployeeCard> cards,
    required Map<String, EmployeeEntity> employeeMap,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('🚨 *URGENT COMPLIANCE NOTICE: CARD EXPIRATION (≤ 3 DAYS)*');
    buffer.writeln('════════════════════════════════════════');
    buffer.writeln('Attention: Compliance & Operations Control');
    buffer.writeln('The following *${cards.length} document(s)* require immediate renewal:');
    buffer.writeln('');

    for (int i = 0; i < cards.length; i++) {
      final card = cards[i];
      final emp = employeeMap[card.employeeId];
      final empName = emp?.name ?? 'Employee';
      final empCode = emp?.employeeCode ?? 'EMP';
      final dept = emp?.department ?? 'Operations';

      final daysRemaining = card.expiryDate.difference(DateTime.now()).inDays;
      final String urgencyText = daysRemaining < 0
          ? 'EXPIRED (${-daysRemaining}d ago)'
          : (daysRemaining == 0 ? 'EXPIRES TODAY!' : 'Expires in $daysRemaining day(s)');

      buffer.writeln('*${i + 1}. ${card.cardName.toUpperCase()}*');
      buffer.writeln('  👤 Employee: $empName ($empCode)');
      buffer.writeln('  🏢 Dept: $dept');
      buffer.writeln('  🔢 Card No: ${card.cardNumber}');
      buffer.writeln('  📅 Expiry: ${_dateFormat.format(card.expiryDate)}');
      buffer.writeln('  ⏳ Status: $urgencyText');
      if (i < cards.length - 1) buffer.writeln('────────────────────────────────────────');
    }

    buffer.writeln('');
    buffer.writeln('⚠️ *Action Required:*');
    buffer.writeln('Please coordinate with the HR/Admin desk to submit renewals or processing receipts to prevent gate/site access deactivation.');
    buffer.writeln('════════════════════════════════════════');
    buffer.writeln('_Fusion 360 Workforce Document Control_');

    return buffer.toString();
  }

  /// Format Email Subject line
  static String generateEmailSubject({required List<EmployeeCard> cards}) {
    if (cards.length == 1) {
      final card = cards.first;
      final daysRemaining = card.expiryDate.difference(DateTime.now()).inDays;
      final timing = daysRemaining <= 0 ? 'EXPIRED' : 'Expires in $daysRemaining Days';
      return '[URGENT] Document Expiry Alert: ${card.cardName} ($timing)';
    }
    return '[URGENT] Compliance Alert: ${cards.length} Document(s) Expiring Within 3 Days';
  }

  /// Format Plain Text Email Body
  static String generateEmailBody({
    required List<EmployeeCard> cards,
    required Map<String, EmployeeEntity> employeeMap,
  }) {
    final buffer = StringBuffer();
    buffer.writeln('Dear Administrator & HR Operations Team,');
    buffer.writeln('');
    buffer.writeln('This is an automated compliance notification from Fusion 360 Document Control.');
    buffer.writeln('The following employee credential(s) have reached the critical 3-day expiration threshold:');
    buffer.writeln('');

    for (int i = 0; i < cards.length; i++) {
      final card = cards[i];
      final emp = employeeMap[card.employeeId];
      final empName = emp?.name ?? 'Employee';
      final empCode = emp?.employeeCode ?? 'EMP';
      final dept = emp?.department ?? 'Operations';

      final daysRemaining = card.expiryDate.difference(DateTime.now()).inDays;
      final String urgency = daysRemaining < 0
          ? 'EXPIRED (${-daysRemaining}d ago)'
          : (daysRemaining == 0 ? 'EXPIRES TODAY' : '$daysRemaining days remaining');

      buffer.writeln('Document #${i + 1}: ${card.cardName}');
      buffer.writeln('• Employee: $empName ($empCode)');
      buffer.writeln('• Department: $dept');
      buffer.writeln('• Document Number: ${card.cardNumber}');
      buffer.writeln('• Expiry Date: ${_dateFormat.format(card.expiryDate)}');
      buffer.writeln('• Urgency: $urgency');
      buffer.writeln('');
    }

    buffer.writeln('ACTION REQUIRED:');
    buffer.writeln('Please initiate or verify the renewal procedure immediately to ensure uninterrupted site access and avoid regulatory penalties.');
    buffer.writeln('');
    buffer.writeln('Best regards,');
    buffer.writeln('Fusion 360 Workforce Compliance Desk');

    return buffer.toString();
  }

  /// Format High-End HTML Email for Resend / SendGrid / SMTP
  static String generateEmailHtml({
    required List<EmployeeCard> cards,
    required Map<String, EmployeeEntity> employeeMap,
  }) {
    final rowsBuffer = StringBuffer();

    for (final card in cards) {
      final emp = employeeMap[card.employeeId];
      final empName = emp?.name ?? 'Employee';
      final empCode = emp?.employeeCode ?? 'EMP';
      final dept = emp?.department ?? 'Operations';

      final daysRemaining = card.expiryDate.difference(DateTime.now()).inDays;
      final String statusBg = daysRemaining <= 0 ? '#ef4444' : (daysRemaining <= 1 ? '#f97316' : '#eab308');
      final String urgency = daysRemaining < 0
          ? 'Expired ${-daysRemaining}d ago'
          : (daysRemaining == 0 ? 'Expires Today' : '$daysRemaining days remaining');

      rowsBuffer.writeln('''
        <tr style="border-bottom: 1px solid #e2e8f0;">
          <td style="padding: 12px; font-weight: bold; color: #0f172a;">${card.cardName}</td>
          <td style="padding: 12px; font-family: monospace; font-size: 13px; color: #1e293b;">${card.cardNumber}</td>
          <td style="padding: 12px; color: #334155;">$empName <span style="color: #64748b; font-size: 11px;">($empCode &bull; $dept)</span></td>
          <td style="padding: 12px; color: #0f172a; font-weight: 600;">${_dateFormat.format(card.expiryDate)}</td>
          <td style="padding: 12px;">
            <span style="background: $statusBg; color: #ffffff; padding: 3px 8px; border-radius: 6px; font-size: 11px; font-weight: bold; text-transform: uppercase;">
              $urgency
            </span>
          </td>
        </tr>
      ''');
    }

    return '''
      <!DOCTYPE html>
      <html>
      <head>
        <meta charset="utf-8">
        <title>Urgent Card Expiry Alert</title>
      </head>
      <body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, Helvetica, Arial, sans-serif; background-color: #f8fafc; padding: 24px; margin: 0;">
        <div style="max-width: 650px; margin: 0 auto; background: #ffffff; border-radius: 14px; overflow: hidden; border: 1px solid #e2e8f0; box-shadow: 0 4px 12px rgba(0,0,0,0.06);">
          <!-- Header Banner -->
          <div style="background: linear-gradient(135deg, #0f172a 0%, #1e293b 100%); padding: 24px; color: #ffffff; text-align: left; border-bottom: 3px solid #ef4444;">
            <div style="font-size: 11px; text-transform: uppercase; letter-spacing: 1.5px; color: #38bdf8; font-weight: bold;">Fusion 360 &bull; Document Compliance</div>
            <h1 style="margin: 8px 0 4px; font-size: 20px; font-weight: 800; color: #ffffff;">Critical Expiry Notice: &le; 3 Days</h1>
            <p style="margin: 0; font-size: 13px; color: #94a3b8;">Automated alert for administration & compliance desk</p>
          </div>

          <!-- Body -->
          <div style="padding: 24px;">
            <p style="font-size: 14px; color: #334155; line-height: 1.5; margin-top: 0;">
              The following <strong>${cards.length} document(s)</strong> have reached the critical 3-day notification threshold and require urgent renewal or proof of processing.
            </p>

            <table style="width: 100%; border-collapse: collapse; text-align: left; font-size: 13px; margin: 16px 0;">
              <thead>
                <tr style="background: #f1f5f9; color: #475569; font-size: 11px; text-transform: uppercase; letter-spacing: 0.5px;">
                  <th style="padding: 10px 12px;">Document</th>
                  <th style="padding: 10px 12px;">Number</th>
                  <th style="padding: 10px 12px;">Employee</th>
                  <th style="padding: 10px 12px;">Expiry</th>
                  <th style="padding: 10px 12px;">Urgency</th>
                </tr>
              </thead>
              <tbody>
                ${rowsBuffer.toString()}
              </tbody>
            </table>

            <div style="background: #fff7ed; border-left: 4px solid #f97316; padding: 12px 16px; border-radius: 6px; margin: 20px 0;">
              <strong style="color: #9a3412; font-size: 13px;">Action Required:</strong>
              <p style="margin: 4px 0 0; font-size: 12px; color: #c2410c; line-height: 1.4;">
                Please arrange for the submission of renewed documents or in-process GDRFA/ICP renewal receipts immediately to avoid gate pass restrictions.
              </p>
            </div>
          </div>

          <!-- Footer -->
          <div style="background: #f8fafc; padding: 16px 24px; border-top: 1px solid #e2e8f0; font-size: 11px; color: #64748b; display: flex; justify-content: space-between;">
            <span>Target Recipients: sr.irshath@gmail.com, nasuru@fusionmaint.com</span>
            <span>Fusion 360 Document Control System</span>
          </div>
        </div>
      </body>
      </html>
    ''';
  }

  /// Launch WhatsApp with pre-filled message directly to [targetPhone]
  static Future<bool> launchWhatsAppClient({
    required List<EmployeeCard> cards,
    required Map<String, EmployeeEntity> employeeMap,
    String? targetPhone,
  }) async {
    final phone = (targetPhone ?? defaultAdminPhone).replaceAll(RegExp(r'[^0-9]'), '');
    final message = generateWhatsAppMessage(cards: cards, employeeMap: employeeMap);
    final encodedMsg = Uri.encodeComponent(message);

    final urlStr = phone.isNotEmpty
        ? 'https://wa.me/$phone?text=$encodedMsg'
        : 'https://wa.me/?text=$encodedMsg';

    final uri = Uri.parse(urlStr);
    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Launch native Email Client with pre-filled subject and body to [targetEmail]
  static Future<bool> launchEmailClient({
    required List<EmployeeCard> cards,
    required Map<String, EmployeeEntity> employeeMap,
    String? targetEmail,
  }) async {
    final email = targetEmail ?? defaultAdminEmail;
    final subject = generateEmailSubject(cards: cards);
    final body = generateEmailBody(cards: cards, employeeMap: employeeMap);

    final uri = Uri(
      scheme: 'mailto',
      path: email,
      queryParameters: {
        'subject': subject,
        'body': body,
      },
    );

    if (await canLaunchUrl(uri)) {
      return await launchUrl(uri, mode: LaunchMode.externalApplication);
    }
    return false;
  }

  /// Send automated background email via Resend Free Tier (3,000 free emails/month)
  static Future<bool> sendFreeResendEmail({
    required List<EmployeeCard> cards,
    required Map<String, EmployeeEntity> employeeMap,
    required String resendApiKey,
    String? targetEmail,
  }) async {
    try {
      final emailStr = targetEmail ?? defaultAdminEmail;
      final recipients = emailStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final subject = generateEmailSubject(cards: cards);
      final htmlContent = generateEmailHtml(cards: cards, employeeMap: employeeMap);

      final response = await http.post(
        Uri.parse('https://api.resend.com/emails'),
        headers: {
          'Authorization': 'Bearer $resendApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': 'Fusion Compliance <compliance@fusionmaint.org>',
          'to': recipients.isNotEmpty ? recipients : [defaultAdminEmail],
          'subject': subject,
          'html': htmlContent,
        }),
      );

      return response.statusCode == 200 || response.statusCode == 201;
    } catch (e) {
      debugPrint('Error sending Resend email: $e');
      return false;
    }
  }

  /// Send automated background WhatsApp message via CallMeBot Free API
  static Future<bool> sendFreeCallMeBotWhatsApp({
    required List<EmployeeCard> cards,
    required Map<String, EmployeeEntity> employeeMap,
    required String callMeBotApiKey,
    String? targetPhone,
  }) async {
    try {
      final phone = (targetPhone ?? defaultAdminPhone).replaceAll(RegExp(r'[^0-9]'), '');
      final message = generateWhatsAppMessage(cards: cards, employeeMap: employeeMap);
      final encodedMsg = Uri.encodeComponent(message);

      final url = 'https://api.callmebot.com/whatsapp.php?phone=$phone&text=$encodedMsg&apikey=$callMeBotApiKey';
      final response = await http.get(Uri.parse(url));

      return response.statusCode == 200;
    } catch (e) {
      debugPrint('Error sending CallMeBot WhatsApp: $e');
      return false;
    }
  }

  /// Test Resend API Key by pinging their account or sending a handshake test
  static Future<Map<String, dynamic>> testResendEmailConnection({
    required String resendApiKey,
    String? targetEmail,
  }) async {
    try {
      final emailStr = targetEmail ?? defaultAdminEmail;
      final recipients = emailStr.split(',').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      final response = await http.post(
        Uri.parse('https://api.resend.com/emails'),
        headers: {
          'Authorization': 'Bearer $resendApiKey',
          'Content-Type': 'application/json',
        },
        body: jsonEncode({
          'from': 'Fusion Compliance <compliance@fusionmaint.org>',
          'to': recipients.isNotEmpty ? recipients : [defaultAdminEmail],
          'subject': 'Fusion 360: Email Robot Test Connection',
          'html': '<h3>Connection Successful!</h3><p>Your automated 3-day card expiry background email robot is properly configured and operational via <strong>fusionmaint.org</strong>.</p>',
        }),
      );

      if (response.statusCode == 200 || response.statusCode == 201) {
        return {'success': true, 'message': 'Test email sent successfully to $emailStr!'};
      } else {
        final err = jsonDecode(response.body);
        return {'success': false, 'message': err['message'] ?? 'Failed to send test email (HTTP ${response.statusCode})'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Test CallMeBot WhatsApp connection
  static Future<Map<String, dynamic>> testCallMeBotConnection({
    required String callMeBotApiKey,
    String? targetPhone,
  }) async {
    try {
      final phone = (targetPhone ?? defaultAdminPhone).replaceAll(RegExp(r'[^0-9]'), '');
      final msg = Uri.encodeComponent('🤖 *Fusion 360 Robot Test*: Background automated WhatsApp alerts are connected and active!');
      final url = 'https://api.callmebot.com/whatsapp.php?phone=$phone&text=$msg&apikey=$callMeBotApiKey';
      final response = await http.get(Uri.parse(url));

      if (response.statusCode == 200) {
        return {'success': true, 'message': 'Test WhatsApp sent to +$phone!'};
      } else {
        return {'success': false, 'message': 'CallMeBot responded with HTTP ${response.statusCode}'};
      }
    } catch (e) {
      return {'success': false, 'message': 'Network error: $e'};
    }
  }

  /// Automated daily check: Runs silently in background on screen load or app startup
  static Future<Map<String, dynamic>> runAutomatedDailyCheck({
    required List<EmployeeCard> cards,
    required Map<String, EmployeeEntity> employeeMap,
  }) async {
    final localDb = LocalDatabaseService();
    if (!localDb.isAutoNotificationRobotEnabled()) {
      return {'triggered': false, 'reason': 'Automated robot is disabled'};
    }

    final todayStr = DateFormat('yyyy-MM-dd').format(DateTime.now());
    if (localDb.getLastRobotDispatchDate() == todayStr) {
      return {'triggered': false, 'reason': 'Already ran today ($todayStr)'};
    }

    final urgentCards = getExpiringCardsWithinDays(cards, days: 3);
    if (urgentCards.isEmpty) {
      return {'triggered': false, 'reason': 'No cards expiring in <= 3 days'};
    }

    final resendKey = localDb.getResendApiKey();
    final callMeBotKey = localDb.getCallMeBotApiKey();

    if ((resendKey == null || resendKey.isEmpty) && (callMeBotKey == null || callMeBotKey.isEmpty)) {
      return {'triggered': false, 'reason': 'No API keys configured'};
    }

    bool emailSuccess = false;
    bool waSuccess = false;

    if (resendKey != null && resendKey.isNotEmpty) {
      emailSuccess = await sendFreeResendEmail(
        cards: urgentCards,
        employeeMap: employeeMap,
        resendApiKey: resendKey,
      );
    }

    if (callMeBotKey != null && callMeBotKey.isNotEmpty) {
      waSuccess = await sendFreeCallMeBotWhatsApp(
        cards: urgentCards,
        employeeMap: employeeMap,
        callMeBotApiKey: callMeBotKey,
      );
    }

    if (emailSuccess || waSuccess) {
      await localDb.setLastRobotDispatchDate(todayStr);
      return {
        'triggered': true,
        'count': urgentCards.length,
        'emailSent': emailSuccess,
        'whatsappSent': waSuccess,
      };
    }

    return {'triggered': false, 'reason': 'Failed to dispatch via configured keys'};
  }
}

