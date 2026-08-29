import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart' show rootBundle, NetworkAssetBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

class WorkPhotoReportData {
  final String reportRefNumber;
  final DateTime reportDate;
  final String workTitle;
  final String location;
  final String employeeName;
  final String remarks;
  final List<String> photos; // Base64, local file path, or Network URL image strings

  WorkPhotoReportData({
    required this.reportRefNumber,
    required this.reportDate,
    required this.workTitle,
    required this.location,
    required this.employeeName,
    required this.remarks,
    required this.photos,
  });

  Map<String, dynamic> toJson() => {
        'reportRefNumber': reportRefNumber,
        'reportDate': reportDate.toIso8601String(),
        'workTitle': workTitle,
        'location': location,
        'employeeName': employeeName,
        'remarks': remarks,
        'photos': photos,
      };

  factory WorkPhotoReportData.fromJson(Map<String, dynamic> json) {
    return WorkPhotoReportData(
      reportRefNumber: json['reportRefNumber']?.toString() ?? '',
      reportDate: json['reportDate'] != null
          ? (DateTime.tryParse(json['reportDate'].toString()) ?? DateTime.now())
          : DateTime.now(),
      workTitle: json['workTitle']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? '',
      remarks: json['remarks']?.toString() ?? '',
      photos: (json['photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );
  }
}

class WorkPhotoReportPdfService {
  /// Generates PDF bytes asynchronously
  static Future<Uint8List> buildPdfBytesAsync(WorkPhotoReportData data) async {
    return buildPdfBytes(data);
  }

  static Future<Uint8List> buildPdfBytes(WorkPhotoReportData data) async {
    final pdf = pw.Document();

    // Load company logo if available
    pw.MemoryImage? logoImage;
    try {
      final logoBytes = await rootBundle.load('assets/images/fusion_logo.png');
      logoImage = pw.MemoryImage(logoBytes.buffer.asUint8List());
    } catch (_) {}

    final formattedDate = DateFormat('dd MMM yyyy').format(data.reportDate);
    final printTimestamp =
        DateFormat('dd/MM/yyyy HH:mm').format(DateTime.now());

    // Decode photos (base64, local file path, or network URLs)
    final photoMemoryImages = <pw.MemoryImage>[];
    for (final photoStr in data.photos) {
      if (photoStr.trim().isEmpty) continue;
      try {
        if (photoStr.startsWith('http://') || photoStr.startsWith('https://')) {
          final uri = Uri.parse(photoStr);
          final bundle = NetworkAssetBundle(uri);
          final byteData = await bundle.load(photoStr);
          final bytes = byteData.buffer.asUint8List();
          photoMemoryImages.add(pw.MemoryImage(bytes));
        } else if (File(photoStr).existsSync()) {
          final fileBytes = await File(photoStr).readAsBytes();
          photoMemoryImages.add(pw.MemoryImage(fileBytes));
        } else {
          final cleanB64 =
              photoStr.contains(',') ? photoStr.split(',').last : photoStr;
          final bytes = base64Decode(cleanB64.trim());
          photoMemoryImages.add(pw.MemoryImage(bytes));
        }
      } catch (e) {
        debugPrint('Error decoding image for PDF: $e');
      }
    }

    // Chunk photos (4 per page)
    final chunks = <List<pw.MemoryImage>>[];
    if (photoMemoryImages.isEmpty) {
      chunks.add([]);
    } else {
      for (var i = 0; i < photoMemoryImages.length; i += 4) {
        chunks.add(
          photoMemoryImages.sublist(
            i,
            i + 4 > photoMemoryImages.length ? photoMemoryImages.length : i + 4,
          ),
        );
      }
    }

    for (var pageIdx = 0; pageIdx < chunks.length; pageIdx++) {
      final pagePhotos = chunks[pageIdx];
      pdf.addPage(
        pw.Page(
          pageFormat: PdfPageFormat.a4,
          margin: const pw.EdgeInsets.symmetric(horizontal: 20, vertical: 18),
          build: (pw.Context context) {
            return pw.Column(
              crossAxisAlignment: pw.CrossAxisAlignment.start,
              children: [
                // Header
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    if (logoImage != null)
                      pw.Container(height: 38, child: pw.Image(logoImage))
                    else
                      pw.Text(
                        'FUSION',
                        style: pw.TextStyle(
                          fontSize: 16,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.blue900,
                        ),
                      ),
                    pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.end,
                      children: [
                        pw.Text(
                          'WORK PHOTOS & SITE EVIDENCE REPORT',
                          style: pw.TextStyle(
                            fontSize: 11,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.blue900,
                          ),
                        ),
                        if (data.reportRefNumber.isNotEmpty) ...[
                          pw.SizedBox(height: 2),
                          pw.Text(
                            'Report Ref: #${data.reportRefNumber}',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.grey800,
                            ),
                          ),
                        ],
                      ],
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),
                pw.Divider(thickness: 1.2, color: PdfColors.blue900),
                pw.SizedBox(height: 6),

                // Report Details Box (shown on page 1)
                if (pageIdx == 0) ...[
                  pw.Container(
                    padding: const pw.EdgeInsets.all(10),
                    decoration: pw.BoxDecoration(
                      color: PdfColors.blue50,
                      borderRadius: pw.BorderRadius.circular(6),
                      border:
                          pw.Border.all(color: PdfColors.blue200, width: 0.8),
                    ),
                    child: pw.Column(
                      children: [
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: _buildInfoItem(
                                'Work Title',
                                data.workTitle.isNotEmpty
                                    ? data.workTitle
                                    : 'Site Work Execution',
                              ),
                            ),
                            pw.SizedBox(width: 10),
                            pw.Expanded(
                              child: _buildInfoItem(
                                'Date',
                                formattedDate,
                              ),
                            ),
                          ],
                        ),
                        pw.SizedBox(height: 6),
                        pw.Row(
                          children: [
                            pw.Expanded(
                              child: _buildInfoItem(
                                'Location',
                                data.location.isNotEmpty
                                    ? data.location
                                    : 'On Site',
                              ),
                            ),
                            pw.SizedBox(width: 10),
                            pw.Expanded(
                              child: _buildInfoItem(
                                'Technician / Employee',
                                data.employeeName.isNotEmpty
                                    ? data.employeeName
                                    : 'Fusion Technical Staff',
                              ),
                            ),
                          ],
                        ),
                        if (data.remarks.isNotEmpty) ...[
                          pw.SizedBox(height: 6),
                          _buildInfoItem(
                              'Work Details / Remarks', data.remarks),
                        ],
                      ],
                    ),
                  ),
                  pw.SizedBox(height: 12),
                ],

                // Photos Grid header for this page
                pw.Row(
                  mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                  children: [
                    pw.Text(
                      'Site Evidence Photos (${pageIdx * 4 + 1} - ${pageIdx * 4 + pagePhotos.length} of ${photoMemoryImages.length})',
                      style: pw.TextStyle(
                        fontSize: 9,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.blue900,
                      ),
                    ),
                    pw.Text(
                      'Total Attached: ${photoMemoryImages.length}',
                      style: const pw.TextStyle(
                          fontSize: 8, color: PdfColors.grey700),
                    ),
                  ],
                ),
                pw.SizedBox(height: 6),

                // Photo Grid (2x2 layout per page)
                if (pagePhotos.isNotEmpty)
                  pw.GridView(
                    crossAxisCount: 2,
                    childAspectRatio: 1.25,
                    crossAxisSpacing: 10,
                    mainAxisSpacing: 10,
                    children: List.generate(pagePhotos.length, (i) {
                      final photoIndex = pageIdx * 4 + i + 1;
                      return pw.Container(
                        decoration: pw.BoxDecoration(
                          border: pw.Border.all(
                              color: PdfColors.grey400, width: 0.8),
                          borderRadius: pw.BorderRadius.circular(4),
                        ),
                        padding: const pw.EdgeInsets.all(4),
                        child: pw.Column(
                          children: [
                            pw.Expanded(
                              child:
                                  pw.Image(pagePhotos[i], fit: pw.BoxFit.cover),
                            ),
                            pw.SizedBox(height: 3),
                            pw.Text(
                              'Photo #$photoIndex',
                              style: pw.TextStyle(
                                fontSize: 8,
                                fontWeight: pw.FontWeight.bold,
                                color: PdfColors.blue900,
                              ),
                            ),
                          ],
                        ),
                      );
                    }),
                  )
                else
                  pw.Container(
                    height: 180,
                    alignment: pw.Alignment.center,
                    decoration: pw.BoxDecoration(
                      border: pw.Border.all(color: PdfColors.grey300),
                      borderRadius: pw.BorderRadius.circular(6),
                    ),
                    child: pw.Text(
                      'No site photos attached to this report.',
                      style: const pw.TextStyle(
                          fontSize: 10, color: PdfColors.grey600),
                    ),
                  ),

                pw.Spacer(),

                // Footer
                pw.Column(
                  children: [
                    pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                    pw.SizedBox(height: 2),
                    pw.Row(
                      mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                      children: [
                        pw.Text(
                          'Fusion Electro Mechanical Maintenance L.L.C  |  Site Work Evidence',
                          style: const pw.TextStyle(
                              fontSize: 6.5, color: PdfColors.grey600),
                        ),
                        pw.Text(
                          'Page ${pageIdx + 1} of ${chunks.length}  |  Generated $printTimestamp',
                          style: const pw.TextStyle(
                              fontSize: 6.5, color: PdfColors.grey600),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            );
          },
        ),
      );
    }

    return pdf.save();
  }

  static pw.Widget _buildInfoItem(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$label: ',
          style: pw.TextStyle(
            fontSize: 8,
            fontWeight: pw.FontWeight.bold,
            color: PdfColors.grey800,
          ),
        ),
        pw.Expanded(
          child: pw.Text(
            value,
            style: pw.TextStyle(
              fontSize: 8,
              fontWeight: pw.FontWeight.bold,
              color: PdfColors.blue900,
            ),
            maxLines: 2,
          ),
        ),
      ],
    );
  }
}
