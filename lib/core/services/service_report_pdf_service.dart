import 'dart:typed_data';
import 'package:flutter/services.dart' show rootBundle;
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

class MaterialItemRow {
  final String material1;
  final String qty1;
  final String material2;
  final String qty2;

  MaterialItemRow({
    this.material1 = '',
    this.qty1 = '',
    this.material2 = '',
    this.qty2 = '',
  });

  Map<String, dynamic> toJson() => {
        'material1': material1,
        'qty1': qty1,
        'material2': material2,
        'qty2': qty2,
      };

  factory MaterialItemRow.fromJson(Map<String, dynamic> json) {
    return MaterialItemRow(
      material1: json['material1']?.toString() ?? '',
      qty1: json['qty1']?.toString() ?? '',
      material2: json['material2']?.toString() ?? '',
      qty2: json['qty2']?.toString() ?? '',
    );
  }
}

/// Data model holding all fields for Fusion Electro Mechanical Service Report
class ServiceReportData {
  // Report Header
  final String reportRefNumber;
  final DateTime reportDate;

  // Section 1: Property & Call Details
  final String propertyDetails;
  final String jobNo;
  final String contactName;
  final String contactNumber;
  final String location;
  final String appointmentTime;
  final String attendedTime;
  final String callBookingTime;
  final String callType; // 'Complaint', 'Breakdown', 'Preventive'

  // Section 2: Service Required & Priority
  final List<String> selectedServices; // e.g., ['A/C', 'Electrical', ...]
  final String otherServices;
  final String priority; // 'Urgent', 'Normal'

  // Section 3: Defects Found on Inspection
  final String defectsFound;

  // Section 4: Materials Used (5 rows, 4 columns: Material Used | Qty | Material Used | Qty)
  final List<MaterialItemRow> materialsTable;

  // Section 5: Details of Work Done
  final String detailsOfWorkDone;

  // Section 6: Client / Customer Remark
  final String clientRemark;

  // Section 7: Service Performance Report & Housekeeping
  final String performanceRating; // 'Satisfactory', 'Unsatisfactory'
  final String supervisorRemarks;
  final String housekeepingCompleted; // 'Yes', 'No'

  // Section 8: Signatures (4 in a row)
  final String technicianName;
  final String engineerName;
  final String supervisorName;
  final String customerName;

  final Uint8List? technicianSigBytes;
  final Uint8List? engineerSigBytes;
  final Uint8List? supervisorSigBytes;
  final Uint8List? customerSigBytes;

  ServiceReportData({
    required this.reportRefNumber,
    required this.reportDate,
    required this.propertyDetails,
    required this.jobNo,
    required this.contactName,
    required this.contactNumber,
    required this.location,
    required this.appointmentTime,
    required this.attendedTime,
    required this.callBookingTime,
    required this.callType,
    required this.selectedServices,
    required this.otherServices,
    required this.priority,
    required this.defectsFound,
    required this.materialsTable,
    required this.detailsOfWorkDone,
    required this.clientRemark,
    required this.performanceRating,
    required this.supervisorRemarks,
    required this.housekeepingCompleted,
    required this.technicianName,
    required this.engineerName,
    required this.supervisorName,
    required this.customerName,
    this.technicianSigBytes,
    this.engineerSigBytes,
    this.supervisorSigBytes,
    this.customerSigBytes,
  });

  Map<String, dynamic> toJson() => {
        'reportRefNumber': reportRefNumber,
        'reportDate': reportDate.toIso8601String(),
        'propertyDetails': propertyDetails,
        'jobNo': jobNo,
        'contactName': contactName,
        'contactNumber': contactNumber,
        'location': location,
        'appointmentTime': appointmentTime,
        'attendedTime': attendedTime,
        'callBookingTime': callBookingTime,
        'callType': callType,
        'selectedServices': selectedServices,
        'otherServices': otherServices,
        'priority': priority,
        'defectsFound': defectsFound,
        'materialsTable': materialsTable.map((e) => e.toJson()).toList(),
        'detailsOfWorkDone': detailsOfWorkDone,
        'clientRemark': clientRemark,
        'performanceRating': performanceRating,
        'supervisorRemarks': supervisorRemarks,
        'housekeepingCompleted': housekeepingCompleted,
        'technicianName': technicianName,
        'engineerName': engineerName,
        'supervisorName': supervisorName,
        'customerName': customerName,
      };

  factory ServiceReportData.fromJson(Map<String, dynamic> json) {
    return ServiceReportData(
      reportRefNumber: json['reportRefNumber']?.toString() ?? '',
      reportDate: json['reportDate'] != null
          ? (DateTime.tryParse(json['reportDate'].toString()) ?? DateTime.now())
          : DateTime.now(),
      propertyDetails: json['propertyDetails']?.toString() ?? '',
      jobNo: json['jobNo']?.toString() ?? '',
      contactName: json['contactName']?.toString() ?? '',
      contactNumber: json['contactNumber']?.toString() ?? '',
      location: json['location']?.toString() ?? '',
      appointmentTime: json['appointmentTime']?.toString() ?? '',
      attendedTime: json['attendedTime']?.toString() ?? '',
      callBookingTime: json['callBookingTime']?.toString() ?? '',
      callType: json['callType']?.toString() ?? '',
      selectedServices: (json['selectedServices'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
      otherServices: json['otherServices']?.toString() ?? '',
      priority: json['priority']?.toString() ?? '',
      defectsFound: json['defectsFound']?.toString() ?? '',
      materialsTable: (json['materialsTable'] as List<dynamic>?)
              ?.map((e) => MaterialItemRow.fromJson(Map<String, dynamic>.from(e)))
              .toList() ??
          [],
      detailsOfWorkDone: json['detailsOfWorkDone']?.toString() ?? '',
      clientRemark: json['clientRemark']?.toString() ?? '',
      performanceRating: json['performanceRating']?.toString() ?? '',
      supervisorRemarks: json['supervisorRemarks']?.toString() ?? '',
      housekeepingCompleted: json['housekeepingCompleted']?.toString() ?? '',
      technicianName: json['technicianName']?.toString() ?? '',
      engineerName: json['engineerName']?.toString() ?? '',
      supervisorName: json['supervisorName']?.toString() ?? '',
      customerName: json['customerName']?.toString() ?? '',
    );
  }
}

class ServiceReportPdfService {
  /// Loads company logo image from assets if available
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
      } catch (_) {
        return null;
      }
    }
    return null;
  }

  /// Helper for check box rendering in PDF with crisp vector checkmark tick
  static pw.Widget _buildPdfCheckbox(String label, bool isChecked) {
    return pw.Row(
      mainAxisSize: pw.MainAxisSize.min,
      crossAxisAlignment: pw.CrossAxisAlignment.center,
      children: [
        pw.Container(
          width: 10,
          height: 10,
          alignment: pw.Alignment.center,
          decoration: pw.BoxDecoration(
            border: pw.Border.all(color: PdfColors.blue900, width: 0.8),
            color: isChecked ? PdfColors.blue900 : PdfColors.white,
            borderRadius: pw.BorderRadius.circular(1.5),
          ),
          child: isChecked
              ? pw.CustomPaint(
                  size: const PdfPoint(8, 8),
                  painter: (PdfGraphics canvas, PdfPoint size) {
                    canvas
                      ..setColor(PdfColors.white)
                      ..setLineWidth(1.3)
                      ..moveTo(1.2, 4.0)
                      ..lineTo(3.0, 1.8)
                      ..lineTo(6.8, 6.2)
                      ..strokePath();
                  },
                )
              : null,
        ),
        pw.SizedBox(width: 3),
        pw.Text(
          label,
          style: pw.TextStyle(
            fontSize: 7.5,
            fontWeight: isChecked ? pw.FontWeight.bold : pw.FontWeight.normal,
            color: PdfColors.grey900,
          ),
        ),
      ],
    );
  }

  /// Builds a full single-page PDF binary document for Fusion Electro Mechanical Service Report
  static Future<Uint8List> buildReportPdfBytes(ServiceReportData data) async {
    final pdf = pw.Document();
    final logoImage = await _loadCompanyLogo();

    final techSigImg = _toMemoryImage(data.technicianSigBytes);
    final engSigImg = _toMemoryImage(data.engineerSigBytes);
    final superSigImg = _toMemoryImage(data.supervisorSigBytes);
    final custSigImg = _toMemoryImage(data.customerSigBytes);

    final formattedDate = DateFormat('dd MMMM yyyy').format(data.reportDate);
    final printTimestamp = DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now());

    final availableServicesList = [
      'A/C',
      'CCTV',
      'Fire Fighting',
      'Carpentry',
      'BMS',
      'Electrical',
      'SMATV',
      'Generator',
      'Civil',
      'Access Control',
      'Plumbing',
      'Intercom',
      'Cleaning Service',
      'Painting',
      'Soft Services',
    ];

    pdf.addPage(
      pw.Page(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.symmetric(horizontal: 18, vertical: 16),
        build: (pw.Context context) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              // ================= Header Section =================
              pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                crossAxisAlignment: pw.CrossAxisAlignment.start,
                children: [
                  if (logoImage != null)
                    pw.Container(
                      height: 44,
                      margin: const pw.EdgeInsets.only(right: 8),
                      child: pw.Image(logoImage),
                    ),
                  pw.Expanded(
                    child: pw.Column(
                      crossAxisAlignment: pw.CrossAxisAlignment.start,
                      children: [
                        pw.FittedBox(
                          fit: pw.BoxFit.scaleDown,
                          alignment: pw.Alignment.centerLeft,
                          child: pw.Text(
                            'FUSION ELECTRO MECHANICAL',
                            style: pw.TextStyle(
                              fontSize: 8.5,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                        ),
                        pw.FittedBox(
                          fit: pw.BoxFit.scaleDown,
                          alignment: pw.Alignment.centerLeft,
                          child: pw.Text(
                            'MAINTENANCE L.L.C',
                            style: pw.TextStyle(
                              fontSize: 8,
                              fontWeight: pw.FontWeight.bold,
                              color: PdfColors.blue900,
                            ),
                          ),
                        ),
                        pw.SizedBox(height: 2),
                        pw.Text(
                          'P.O. Box: 2671, Abu Dhabi, UAE',
                          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                        ),
                        pw.Text(
                          'Tel: +971-2-632 3795  |  Fax: +971-2-632 7510',
                          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                        ),
                        pw.Text(
                          'E-mail: post@fusionmaint.com  |  Web: www.fusionmaint.com',
                          style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                        ),
                      ],
                    ),
                  ),
                  pw.SizedBox(width: 8),
                  pw.Column(
                    crossAxisAlignment: pw.CrossAxisAlignment.end,
                    children: [
                      pw.Container(
                        padding: const pw.EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                        decoration: pw.BoxDecoration(
                          color: PdfColors.blue900,
                          borderRadius: pw.BorderRadius.circular(3),
                        ),
                        child: pw.Text(
                          'SERVICE REPORT',
                          style: pw.TextStyle(
                            fontSize: 9.5,
                            fontWeight: pw.FontWeight.bold,
                            color: PdfColors.white,
                          ),
                        ),
                      ),
                      pw.SizedBox(height: 2),
                      pw.Text(
                        'REF: ${data.reportRefNumber}',
                        style: pw.TextStyle(
                          fontSize: 7.5,
                          fontWeight: pw.FontWeight.bold,
                          color: PdfColors.amber900,
                        ),
                      ),
                      pw.Text(
                        'Date: $formattedDate',
                        style: const pw.TextStyle(fontSize: 7, color: PdfColors.grey700),
                      ),
                    ],
                  ),
                ],
              ),
              pw.SizedBox(height: 4),
              pw.Divider(thickness: 1.2, color: PdfColors.blue900),
              pw.SizedBox(height: 5),

              // ================= 1st Section: Property & Call Details =================
              _buildSectionHeader('1. PROPERTY & CALL DETAILS'),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: pw.BoxDecoration(
                  color: PdfColors.grey100,
                  borderRadius: pw.BorderRadius.circular(3),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
                ),
                child: pw.Column(
                  children: [
                    pw.Row(
                      children: [
                        pw.Expanded(child: _buildLabelValue('Property Details:', data.propertyDetails)),
                        pw.SizedBox(width: 8),
                        pw.Expanded(child: _buildLabelValue('Job No:', data.jobNo)),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    pw.Row(
                      children: [
                        pw.Expanded(child: _buildLabelValue('Contact Name:', data.contactName)),
                        pw.SizedBox(width: 8),
                        pw.Expanded(child: _buildLabelValue('Contact Number:', data.contactNumber)),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    pw.Row(
                      children: [
                        pw.Expanded(child: _buildLabelValue('Location:', data.location)),
                        pw.SizedBox(width: 8),
                        pw.Expanded(child: _buildLabelValue('Appointment Time:', data.appointmentTime)),
                      ],
                    ),
                    pw.SizedBox(height: 3),
                    pw.Row(
                      children: [
                        pw.Expanded(child: _buildLabelValue('Attended Time:', data.attendedTime)),
                        pw.SizedBox(width: 8),
                        pw.Expanded(child: _buildLabelValue('Call Booking Time:', data.callBookingTime)),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Divider(thickness: 0.3, color: PdfColors.grey300),
                    pw.SizedBox(height: 3),
                    pw.Row(
                      children: [
                        pw.Text(
                          'Call Type: ',
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                        ),
                        pw.SizedBox(width: 12),
                        _buildPdfCheckbox('Complaint', data.callType == 'Complaint'),
                        pw.SizedBox(width: 16),
                        _buildPdfCheckbox('Breakdown', data.callType == 'Breakdown'),
                        pw.SizedBox(width: 16),
                        _buildPdfCheckbox('Preventive', data.callType == 'Preventive'),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              // ================= 2nd Section: Service Required & Priority =================
              _buildSectionHeader('2. SERVICE REQUIRED & PRIORITY'),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(3),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Wrap(
                      spacing: 10,
                      runSpacing: 5,
                      children: availableServicesList.map((service) {
                        final isSelected = data.selectedServices.contains(service);
                        return pw.SizedBox(
                          width: 96,
                          child: _buildPdfCheckbox(service, isSelected),
                        );
                      }).toList(),
                    ),
                    if (data.otherServices.trim().isNotEmpty) ...[
                      pw.SizedBox(height: 4),
                      pw.Row(
                        children: [
                          pw.Text(
                            'Others (Please Specify): ',
                            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey800),
                          ),
                          pw.Expanded(
                            child: pw.Text(
                              data.otherServices,
                              style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                            ),
                          ),
                        ],
                      ),
                    ],
                    pw.SizedBox(height: 4),
                    pw.Divider(thickness: 0.3, color: PdfColors.grey300),
                    pw.SizedBox(height: 3),
                    pw.Row(
                      children: [
                        pw.Text(
                          'Priority: ',
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                        ),
                        pw.SizedBox(width: 12),
                        _buildPdfCheckbox('Urgent', data.priority == 'Urgent'),
                        pw.SizedBox(width: 18),
                        _buildPdfCheckbox('Normal', data.priority == 'Normal'),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 6),

              // ================= 3rd Section: Defects Found on Inspection =================
              _buildSectionHeader('3. DEFECTS FOUND ON INSPECTION'),
              _buildTextBox(data.defectsFound, height: 28),
              pw.SizedBox(height: 6),

              // ================= 4th Section: Material Used Table =================
              _buildSectionHeader('4. MATERIAL USED'),
              pw.Table(
                border: pw.TableBorder.all(color: PdfColors.grey400, width: 0.6),
                columnWidths: const {
                  0: pw.FlexColumnWidth(3.0),
                  1: pw.FlexColumnWidth(1.0),
                  2: pw.FlexColumnWidth(3.0),
                  3: pw.FlexColumnWidth(1.0),
                },
                children: [
                  pw.TableRow(
                    decoration: const pw.BoxDecoration(color: PdfColors.blue900),
                    children: [
                      _buildTableCell('Material Used', isHeader: true),
                      _buildTableCell('Qty', isHeader: true),
                      _buildTableCell('Material Used', isHeader: true),
                      _buildTableCell('Qty', isHeader: true),
                    ],
                  ),
                  ...List.generate(5, (index) {
                    final item = index < data.materialsTable.length
                        ? data.materialsTable[index]
                        : MaterialItemRow();
                    return pw.TableRow(
                      decoration: pw.BoxDecoration(
                        color: index % 2 == 0 ? PdfColors.white : PdfColors.grey100,
                      ),
                      children: [
                        _buildTableCell(item.material1),
                        _buildTableCell(item.qty1, alignCenter: true),
                        _buildTableCell(item.material2),
                        _buildTableCell(item.qty2, alignCenter: true),
                      ],
                    );
                  }),
                ],
              ),
              pw.SizedBox(height: 6),

              // ================= 5th Section: Details of Work Done =================
              _buildSectionHeader('5. DETAILS OF WORK DONE'),
              _buildTextBox(data.detailsOfWorkDone, height: 38),
              pw.SizedBox(height: 6),

              // ================= 6th Section: Client/Customer Remark =================
              _buildSectionHeader('6. CLIENT/CUSTOMER REMARK'),
              _buildTextBox(data.clientRemark, height: 28),
              pw.SizedBox(height: 6),

              // ================= 7th Section: Service Performance Report =================
              _buildSectionHeader('7. SERVICE PERFORMANCE REPORT'),
              pw.Container(
                padding: const pw.EdgeInsets.symmetric(horizontal: 6, vertical: 5),
                decoration: pw.BoxDecoration(
                  borderRadius: pw.BorderRadius.circular(3),
                  border: pw.Border.all(color: PdfColors.grey300, width: 0.6),
                ),
                child: pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Row(
                      children: [
                        pw.Text(
                          'Service Performance Report: ',
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                        ),
                        pw.SizedBox(width: 12),
                        _buildPdfCheckbox('Satisfactory', data.performanceRating == 'Satisfactory'),
                        pw.SizedBox(width: 16),
                        _buildPdfCheckbox('Unsatisfactory', data.performanceRating == 'Unsatisfactory'),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Text(
                          "Supervisor's Remarks: ",
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                        ),
                        pw.Expanded(
                          child: pw.Text(
                            data.supervisorRemarks,
                            style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey900),
                          ),
                        ),
                      ],
                    ),
                    pw.SizedBox(height: 4),
                    pw.Row(
                      children: [
                        pw.Text(
                          'Housekeeping Completed: ',
                          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
                        ),
                        pw.SizedBox(width: 12),
                        _buildPdfCheckbox('Yes', data.housekeepingCompleted == 'Yes'),
                        pw.SizedBox(width: 18),
                        _buildPdfCheckbox('No', data.housekeepingCompleted == 'No'),
                      ],
                    ),
                  ],
                ),
              ),
              pw.SizedBox(height: 7),

              // ================= 8th Section: Four Signatures in a Row =================
              _buildSectionHeader('8. AUTHORIZATIONS & SIGNATURES'),
              pw.Row(
                children: [
                  pw.Expanded(
                    child: _buildSignatureCard(
                      roleTitle: 'TECHNICIAN',
                      name: data.technicianName,
                      sigImg: techSigImg,
                      dateStr: formattedDate,
                    ),
                  ),
                  pw.SizedBox(width: 5),
                  pw.Expanded(
                    child: _buildSignatureCard(
                      roleTitle: 'ENGINEER',
                      name: data.engineerName,
                      sigImg: engSigImg,
                      dateStr: formattedDate,
                    ),
                  ),
                  pw.SizedBox(width: 5),
                  pw.Expanded(
                    child: _buildSignatureCard(
                      roleTitle: 'SUPERVISOR',
                      name: data.supervisorName,
                      sigImg: superSigImg,
                      dateStr: formattedDate,
                    ),
                  ),
                  pw.SizedBox(width: 5),
                  pw.Expanded(
                    child: _buildSignatureCard(
                      roleTitle: 'CLIENT / CUSTOMER',
                      name: data.customerName,
                      sigImg: custSigImg,
                      dateStr: formattedDate,
                    ),
                  ),
                ],
              ),

              pw.Spacer(),

              // ================= Footer =================
              pw.Column(
                children: [
                  pw.Divider(thickness: 0.5, color: PdfColors.grey400),
                  pw.SizedBox(height: 2),
                  pw.Row(
                    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
                    children: [
                      pw.Text(
                        'Fusion Electro Mechanical Maintenance L.L.C  |  P.O. Box: 2671, Abu Dhabi, UAE  |  Tel: +971-2-632 3795',
                        style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
                      ),
                      pw.Text(
                        'Generated on $printTimestamp  |  Official Service Report',
                        style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey600),
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

    return pdf.save();
  }

  static pw.Widget _buildSectionHeader(String title) {
    return pw.Container(
      width: double.infinity,
      margin: const pw.EdgeInsets.only(bottom: 2, top: 2),
      padding: const pw.EdgeInsets.symmetric(vertical: 2.5, horizontal: 5),
      color: PdfColors.blue900,
      child: pw.Text(
        title,
        style: pw.TextStyle(
          fontSize: 8,
          fontWeight: pw.FontWeight.bold,
          color: PdfColors.white,
        ),
      ),
    );
  }

  static pw.Widget _buildLabelValue(String label, String value) {
    return pw.Row(
      crossAxisAlignment: pw.CrossAxisAlignment.start,
      children: [
        pw.Text(
          '$label ',
          style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.grey700),
        ),
        pw.Expanded(
          child: pw.Text(
            value.isNotEmpty ? value : '--',
            style: pw.TextStyle(fontSize: 7.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            maxLines: 1,
          ),
        ),
      ],
    );
  }

  static pw.Widget _buildTableCell(String text, {bool isHeader = false, bool alignCenter = false}) {
    final displayText = text.trim().isNotEmpty ? text.trim() : ' ';
    return pw.Container(
      height: 15,
      padding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 2),
      alignment: alignCenter ? pw.Alignment.center : pw.Alignment.centerLeft,
      child: pw.Text(
        displayText,
        style: pw.TextStyle(
          fontSize: isHeader ? 7.5 : 7,
          fontWeight: isHeader ? pw.FontWeight.bold : pw.FontWeight.normal,
          color: isHeader ? PdfColors.white : PdfColors.grey900,
        ),
        textAlign: alignCenter ? pw.TextAlign.center : pw.TextAlign.left,
        maxLines: 1,
      ),
    );
  }

  static pw.Widget _buildTextBox(String text, {double? height}) {
    return pw.Container(
      width: double.infinity,
      height: height,
      padding: const pw.EdgeInsets.all(5),
      decoration: pw.BoxDecoration(
        color: PdfColors.grey50,
        borderRadius: pw.BorderRadius.circular(2),
        border: pw.Border.all(color: PdfColors.grey300, width: 0.5),
      ),
      child: pw.Text(
        text,
        style: const pw.TextStyle(fontSize: 7.5, color: PdfColors.grey900),
      ),
    );
  }

  static pw.Widget _buildSignatureCard({
    required String roleTitle,
    required String name,
    required pw.MemoryImage? sigImg,
    required String dateStr,
  }) {
    return pw.Container(
      height: 75,
      padding: const pw.EdgeInsets.all(3.5),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey400, width: 0.6),
        borderRadius: pw.BorderRadius.circular(3),
      ),
      child: pw.Column(
        mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
        crossAxisAlignment: pw.CrossAxisAlignment.center,
        children: [
          pw.Text(
            roleTitle,
            style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold, color: PdfColors.blue900),
            textAlign: pw.TextAlign.center,
          ),
          if (sigImg != null)
            pw.Container(
              height: 34,
              child: pw.Image(sigImg, fit: pw.BoxFit.contain),
            )
          else
            pw.Container(
              height: 34,
              alignment: pw.Alignment.center,
              child: pw.Text(
                '[ Signature ]',
                style: const pw.TextStyle(fontSize: 6.5, color: PdfColors.grey500),
              ),
            ),
          pw.Column(
            children: [
              pw.Divider(thickness: 0.3, color: PdfColors.grey400),
              pw.Text(
                name,
                style: pw.TextStyle(fontSize: 6.5, fontWeight: pw.FontWeight.bold),
                maxLines: 1,
                textAlign: pw.TextAlign.center,
              ),
              pw.Text(
                dateStr,
                style: const pw.TextStyle(fontSize: 5.5, color: PdfColors.grey700),
                textAlign: pw.TextAlign.center,
              ),
            ],
          ),
        ],
      ),
    );
  }

  /// Triggers native sharing / downloading dialog for Service Report PDF
  static Future<void> shareOrDownloadReportPdf(ServiceReportData data) async {
    final pdfBytes = await buildReportPdfBytes(data);
    final safeRef = data.reportRefNumber.replaceAll(RegExp(r'[^\w\s]+'), '_');
    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Service_Report_${safeRef}.pdf',
    );
  }
}
