import 'dart:typed_data';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

/// Single item row in employee report task table
class ReportTaskEntry {
  final String description;
  final String durationOrQty;
  final String status;
  final String notes;

  ReportTaskEntry({
    required this.description,
    this.durationOrQty = '1.0 hr',
    this.status = 'Completed',
    this.notes = '--',
  });
}

/// Data container holding all fields required for employee custom report PDF
class EmployeeReportData {
  final String reportTitle;
  final String reportCategory;
  final String reportRefNumber;
  final DateTime reportDate;
  final String workOrderNumber;

  // Site & Client Info
  final String siteLocation;
  final String locationDetails;
  final String clientName;

  // Personnel Info
  final String technicianName;
  final String technicianCode;
  final String department;
  final String engineerName;
  final String supervisorName;
  final String customerName;
  final String customerTitle;

  // Tasks & Remarks
  final List<ReportTaskEntry> taskEntries;
  final String generalRemarks;

  // 4 Digital Signatures
  final Uint8List? technicianSigBytes;
  final Uint8List? engineerSigBytes;
  final Uint8List? supervisorSigBytes;
  final Uint8List? customerSigBytes;

  EmployeeReportData({
    required this.reportTitle,
    required this.reportCategory,
    required this.reportRefNumber,
    required this.reportDate,
    this.workOrderNumber = 'WO-1001',
    required this.siteLocation,
    this.locationDetails = 'Building 1, Main Area',
    required this.clientName,
    required this.technicianName,
    required this.technicianCode,
    required this.department,
    this.engineerName = 'Project Engineer',
    required this.supervisorName,
    this.customerName = 'Client Representative',
    this.customerTitle = 'Facility Manager',
    required this.taskEntries,
    required this.generalRemarks,
    this.technicianSigBytes,
    this.engineerSigBytes,
    this.supervisorSigBytes,
    this.customerSigBytes,
  });
}

class EmployeeReportPdfService {
  /// Loads company logo image from assets
  static Future<pw.MemoryImage?> _loadCompanyLogo() async {
    try {
      final bytes = await rootBundle.load('assets/images/company_logo.png');
      return pw.MemoryImage(bytes.buffer.asUint8List());
    } catch (e) {
      return null;
    }
  }

  /// Helper to convert signature Uint8List to pw.MemoryImage
  static pw.MemoryImage? _toMemoryImage(Uint8List? bytes) {
    if (bytes != null && bytes.isNotEmpty) {
      try {
        return pw.MemoryImage(bytes);
      } catch (e) {
        return null;
      }
    }
    return null;
  }

  /// Builds a high-fidelity PDF binary document for employee custom report
  static Future<Uint8List> buildReportPdfBytes(EmployeeReportData data) async {
    final pdf = pw.Document();
    final logoImage = await _loadCompanyLogo();

    final techSigImg = _toMemoryImage(data.technicianSigBytes);
    final engSigImg = _toMemoryImage(data.engineerSigBytes);
    final superSigImg = _toMemoryImage(data.supervisorSigBytes);
    final custSigImg = _toMemoryImage(data.customerSigBytes);

    final formattedDate = DateFormat('dd MMMM yyyy').format(data.reportDate);
    final printTimestamp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.all(24),
        header: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      height: 44,
                      child: pw.Image(logoImage),
                    )
                  else
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.Text(
                          'FUSION NEO BUILDING CONTRACTING - L.L.C',
                          style: pw.TextStyle(
                            fontSize: 12,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.indigo900,
                          ),
                        ),
                        pw.Text(
                          'فيوشن نيو لمقاولات البناء - ذ.م.م',
                          style: pw.TextStyle(
                            fontSize: 10,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.grey800,
                          ),
                        ),
                      ],
                    ),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Text(
                        'FUSION NEO BUILDING CONTRACTING L.L.C',
                        style: pw.TextStyle(fontSize: 8.5, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
                      ),
                      pw.Text(
                        'P.O. Box: 26271 | Tel: 02 - 6323795',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                      pw.Text(
                        'Abu Dhabi, United Arab Emirates',
                        style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 6),
              pw.Divider(thickness: 1.5, color: PdfColors.indigo900),
              pw.SizedBox(height: 6),
            ],
          );
        },
        footer: (pw.Context context) {
          return pw.Column(
            children: [
              pw.Divider(thickness: 0.5, color: PdfColors.grey400),
              pw.SizedBox(height: 4),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    'Fusion Neo Building Contracting L.L.C • Official Field Work Report',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                  ),
                  pw.Text(
                    'Generated on $printTimestamp • Page ${context.pageNumber} of ${context.pagesCount}',
                    style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey600),
                  ),
                ],
              ),
            ],
          );
        },
        build: (pw.Context context) {
          return [
            // Document Title Banner
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.symmetric(vertical: 7, horizontal: 10),
              decoration: pw.BoxDecoration(
                color: PdfColors.indigo900,
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(
                    data.reportTitle.toUpperCase(),
                    style: pw.TextStyle(
                      fontSize: 12,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.white,
                    ),
                  ),
                  pw.Text(
                    'REF: ${data.reportRefNumber}',
                    style: pw.TextStyle(
                      fontSize: 9,
                      fontWeight: pw.FontWeight.bold,
                      color: PdfColors.amber300,
                    ),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 10),

            // Personnel, Project & Site Metadata Grid Box
            pw.Container(
              padding: const pw.EdgeInsets.all(8),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300, width: 0.8),
              ),
              child: pw.Column(
                children: [
                  pw.Row(
                    crossAxisAlignment: pw.CrossAxisAlignment.start,
                    children: [
                      // Left Column: Personnel Information
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Technician:', '${data.technicianName} (${data.technicianCode})'),
                            pw.SizedBox(height: 3),
                            _buildInfoRow('Department:', data.department),
                            pw.SizedBox(height: 3),
                            _buildInfoRow('Site Engineer:', data.engineerName.isNotEmpty ? data.engineerName : 'N/A'),
                            pw.SizedBox(height: 3),
                            _buildInfoRow('Supervisor:', data.supervisorName.isNotEmpty ? data.supervisorName : 'N/A'),
                          ],
                        ),
                      ),
                      pw.SizedBox(width: 14),
                      // Right Column: Report & Site Location Info
                      pw.Expanded(
                        child: pw.Column(
                          crossAxisAlignment: pw.CrossAxisAlignment.start,
                          children: [
                            _buildInfoRow('Report Type:', data.reportCategory),
                            pw.SizedBox(height: 3),
                            _buildInfoRow('Report Date:', formattedDate),
                            pw.SizedBox(height: 3),
                            _buildInfoRow('Work Order #:', data.workOrderNumber.isNotEmpty ? data.workOrderNumber : 'N/A'),
                            pw.SizedBox(height: 3),
                            _buildInfoRow('Work Site:', data.siteLocation),
                          ],
                        ),
                      ),
                    ],
                  ),
                  pw.SizedBox(height: 4),
                  pw.Divider(thickness: 0.4, color: PdfColors.grey300),
                  pw.SizedBox(height: 3),
                  pw.Row(
                    children: [
                      pw.Expanded(
                        child: _buildInfoRow('Client Name:', data.clientName.isNotEmpty ? data.clientName : 'Internal'),
                      ),
                      pw.SizedBox(width: 14),
                      pw.Expanded(
                        child: _buildInfoRow('Customer Rep:', '${data.customerName} (${data.customerTitle})'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 12),

            // Section Header: Work Activities & Task Breakdown
            pw.Text(
              'WORK ACTIVITIES & TASK BREAKDOWN',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo900,
              ),
            ),
            pw.SizedBox(height: 5),

            // Tasks Table
            if (data.taskEntries.isNotEmpty)
              pw.TableHelper.fromTextArray(
                headers: ['#', 'Task / Activity Description', 'Duration / Qty', 'Status', 'Notes & Specific Details'],
                data: List.generate(data.taskEntries.length, (index) {
                  final item = data.taskEntries[index];
                  return [
                    '${index + 1}',
                    item.description,
                    item.durationOrQty,
                    item.status,
                    item.notes,
                  ];
                }),
                headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
                headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
                cellStyle: const pw.TextStyle(fontSize: 7.5),
                cellPadding: const pw.EdgeInsets.symmetric(horizontal: 5, vertical: 4),
                cellAlignment: pw.Alignment.centerLeft,
                columnWidths: {
                  0: const pw.FixedColumnWidth(20),
                  1: const pw.FlexColumnWidth(3.5),
                  2: const pw.FlexColumnWidth(1.2),
                  3: const pw.FlexColumnWidth(1.2),
                  4: const pw.FlexColumnWidth(2.5),
                },
              )
            else
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(10),
                decoration: pw.BoxDecoration(
                  border: pw.Border.all(color: PdfColors.grey300),
                  borderRadius: pw.BorderRadius.circular(4),
                ),
                child: pw.Text(
                  'No individual task items logged for this report.',
                  style: const pw.TextStyle(fontSize: 8.5, color: PdfColors.grey700),
                ),
              ),
            pw.SizedBox(height: 10),

            // General Remarks & Observations
            if (data.generalRemarks.trim().isNotEmpty) ...[
              pw.Text(
                'GENERAL REMARKS & FIELD OBSERVATIONS',
                style: pw.TextStyle(
                  fontSize: 10,
                  fontWeight: pw.FontWeight.bold,
                  color: PdfColors.indigo900,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Container(
                width: double.infinity,
                padding: const pw.EdgeInsets.all(8),
                decoration: pw.BoxDecoration(
                  color: PdfColors.blueGrey50,
                  borderRadius: pw.BorderRadius.circular(4),
                  border: pw.Border.all(color: PdfColors.blueGrey200, width: 0.8),
                ),
                child: pw.Text(
                  data.generalRemarks,
                  style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey900),
                ),
              ),
              pw.SizedBox(height: 12),
            ] else
              pw.SizedBox(height: 6),

            // 4-Role Verification & Signatures Section
            pw.Text(
              'AUTHORIZATION, SIGNATURES & OFFICIAL STAMP',
              style: pw.TextStyle(
                fontSize: 10,
                fontWeight: pw.FontWeight.bold,
                color: PdfColors.indigo900,
              ),
            ),
            pw.SizedBox(height: 6),

            // Row 1: Technician & Engineer Signatures
            pw.Row(
              children: [
                pw.Expanded(
                  child: _buildSignatureCard(
                    title: 'PREPARED BY (TECHNICIAN)',
                    name: data.technicianName.isNotEmpty ? data.technicianName : 'Technician',
                    subText: 'Code: ${data.technicianCode}',
                    dateStr: formattedDate,
                    sigImg: techSigImg,
                  ),
                ),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildSignatureCard(
                    title: 'REVIEWED BY (ENGINEER)',
                    name: data.engineerName.isNotEmpty ? data.engineerName : 'Site Engineer',
                    subText: 'Designation: Site Engineer',
                    dateStr: formattedDate,
                    sigImg: engSigImg,
                  ),
                ),
              ],
            ),
            pw.SizedBox(height: 8),

            // Row 2: Supervisor & Customer Signatures + Center Company Stamp Seal
            pw.Row(
              crossAxisAlignment: pw.CrossAxisAlignment.end,
              children: [
                pw.Expanded(
                  child: _buildSignatureCard(
                    title: 'VERIFIED BY (SUPERVISOR)',
                    name: data.supervisorName.isNotEmpty ? data.supervisorName : 'Site Supervisor',
                    subText: 'Status: Approved',
                    dateStr: formattedDate,
                    sigImg: superSigImg,
                  ),
                ),
                pw.SizedBox(width: 8),
                // Official Company Circular Stamp Seal
                _buildOfficialCompanyStamp(),
                pw.SizedBox(width: 8),
                pw.Expanded(
                  child: _buildSignatureCard(
                    title: 'ACCEPTED BY (CUSTOMER)',
                    name: data.customerName.isNotEmpty ? data.customerName : 'Customer Representative',
                    subText: 'Title: ${data.customerTitle}',
                    dateStr: formattedDate,
                    sigImg: custSigImg,
                  ),
                ),
              ],
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  /// Builds an individual signature card widget for the PDF
  static pw.Widget _buildSignatureCard({
    required String title,
    required String name,
    required String subText,
    required String dateStr,
    required pw.MemoryImage? sigImg,
  }) {
    return pw.Container(
      height: 75,
      padding: const pw.EdgeInsets.all(4),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.8),
        borderRadius: pw.BorderRadius.circular(5),
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        children: [
          pw.Text(
            title,
            style: pw.TextStyle(fontSize: 7, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
          ),
          if (sigImg != null)
            pw.Container(
              height: 30,
              child: pw.Image(sigImg, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              height: 30,
              alignment: pw.Alignment.center,
              child: pw.Text(
                '[ DIGITAL SIGNATURE PENDING ]',
                style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey500),
              ),
            ),
          pw.Column(
            children: [
              pw.Divider(thickness: 0.4, color: PdfColors.grey400),
              pw.Text(
                'Name: $name',
                style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
                maxLines: 1,
              ),
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                children: [
                  pw.Text(subText, style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
                  pw.Text('Date: $dateStr', style: const pw.TextStyle(fontSize: 6, color: PdfColors.grey700)),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Renders high-fidelity circular seal stamp replica matching official Fusion Neo Contracting seal
  static pw.Widget _buildOfficialCompanyStamp() {
    return pw.Container(
      width: 95,
      height: 95,
      padding: const pw.EdgeInsets.all(3),
      decoration: pw.BoxDecoration(
        shape: pw.BoxShape.circle,
        border: pw.Border.all(color: PdfColors.blue800, width: 2),
      ),
      child: pw.Container(
        decoration: pw.BoxDecoration(
          shape: pw.BoxShape.circle,
          border: pw.Border.all(color: PdfColors.blue800, width: 0.8),
        ),
        child: pw.Column(
          mainAxisAlignment: pw.MainAxisAlignment.center,
          crossAxisAlignment: pw.CrossAxisAlignment.center,
          children: [
            pw.Text(
              'فيوشن نيو لمقاولات البناء - ذ.م.م',
              style: pw.TextStyle(fontSize: 5.8, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
              textAlign: pw.TextAlign.center,
            ),
            pw.SizedBox(height: 1.5),
            pw.Container(
              padding: const pw.EdgeInsets.symmetric(horizontal: 3, vertical: 1.5),
              decoration: pw.BoxDecoration(
                border: pw.Border.all(color: PdfColors.blue800, width: 0.6),
                borderRadius: pw.BorderRadius.circular(2.5),
              ),
              child: pw.Column(
                children: [
                  pw.Text(
                    'P.O. Box: 26271',
                    style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  ),
                  pw.Text(
                    'Tel: 02 - 6323795',
                    style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  ),
                  pw.Text(
                    'Abu Dhabi U.A.E',
                    style: pw.TextStyle(fontSize: 5.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                  ),
                ],
              ),
            ),
            pw.SizedBox(height: 1.5),
            pw.Text(
              '★ Fusion Neo Building Contracting - L.L.C ★',
              style: pw.TextStyle(fontSize: 5.2, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
              textAlign: pw.TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }

  /// Triggers native sharing / downloading dialog for Employee Report PDF
  static Future<void> shareOrDownloadReportPdf(EmployeeReportData data) async {
    final pdfBytes = await buildReportPdfBytes(data);
    final safeTitle = data.reportTitle.replaceAll(RegExp(r'[^\w\s]+'), '_');
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: '${safeTitle}_${data.reportRefNumber}.pdf',
    );
  }
}

pw.Widget _buildInfoRow(String label, String value) {
  return pw.Row(
    children: [
      pw.SizedBox(
        width: 75,
        child: pw.Text(
          label,
          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
        ),
      ),
      pw.Expanded(
        child: pw.Text(
          value,
          style: pw.TextStyle(fontSize: 8, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
          maxLines: 1,
        ),
      ),
    ],
  );
}
