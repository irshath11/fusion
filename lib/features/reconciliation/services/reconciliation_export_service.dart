import 'dart:typed_data';
import 'package:intl/intl.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:attendance_app/features/reconciliation/domain/expense_bill_entity.dart';
import 'package:attendance_app/features/reconciliation/domain/statement_transaction_entity.dart';
import 'reconciliation_matching_service.dart';

class ReconciliationExportService {
  /// Generates CSV compatible with Google Sheets and Excel
  static String generateCsv({
    required String cycleMonth,
    required List<StatementTransactionEntity> transactions,
    required List<ExpenseBillEntity> bills,
    required String organizationName,
  }) {
    final summary = ReconciliationMatchingService.computeSummary(
      cycleMonth: cycleMonth,
      transactions: transactions,
      bills: bills,
    );
    final pairs = ReconciliationMatchingService.buildPairs(
      cycleMonth: cycleMonth,
      transactions: transactions,
      bills: bills,
    );

    final buffer = StringBuffer();
    final df = DateFormat('yyyy-MM-dd');

    // Header info
    buffer.writeln('"COMPANY:","${organizationName.replaceAll('"', '""')}"');
    buffer.writeln('"MONTHLY CREDIT CARD STATEMENT RECONCILIATION:","$cycleMonth"');
    buffer.writeln('"TOTAL STATEMENT AMOUNT:","${summary.totalStatementAmount.toStringAsFixed(2)}"');
    buffer.writeln('"TOTAL MATCHED BILLS:","${summary.matchedBillsAmount.toStringAsFixed(2)}"');
    buffer.writeln('"NET RECONCILIATION VARIANCE:","${summary.variance.toStringAsFixed(2)}"');
    buffer.writeln('"ZERO BALANCE STATUS:","${summary.isZeroBalance ? "BALANCED (ZERO VARIANCE)" : "DISCREPANCY DETECTED"}"');
    buffer.writeln('');

    // Table Columns
    buffer.writeln(
      '"Statement Date","Card #","Statement Merchant / Line","Statement Amount","Match Status","Bill Date","Employee","Vendor / Store","Invoice #","Category","Material Description","Bill Amount","Variance"',
    );

    for (final pair in pairs) {
      final s = pair.statement;
      final b = pair.bill;

      final sDate = df.format(s.transactionDate);
      final sCard = '****${s.cardLast4}';
      final sDesc = s.description.replaceAll('"', '""');
      final sAmt = s.amount.toStringAsFixed(2);
      final status = b != null ? (pair.isDiscrepancy ? 'Amount Mismatch' : 'Matched') : 'Missing Receipt';

      final bDate = b != null ? df.format(b.billDate) : '-';
      final bEmp = b != null ? b.employeeName.replaceAll('"', '""') : '-';
      final bVendor = b != null ? b.vendorName.replaceAll('"', '""') : '-';
      final bInv = b != null ? b.invoiceNumber.replaceAll('"', '""') : '-';
      final bCat = b != null ? b.category.replaceAll('"', '""') : '-';
      final bMat = b != null ? b.materialDescription.replaceAll('"', '""') : '-';
      final bAmt = b != null ? b.amount.toStringAsFixed(2) : '0.00';
      final variance = b != null ? (s.amount - b.amount).toStringAsFixed(2) : s.amount.toStringAsFixed(2);

      buffer.writeln(
        '"$sDate","$sCard","$sDesc","$sAmt","$status","$bDate","$bEmp","$bVendor","$bInv","$bCat","$bMat","$bAmt","$variance"',
      );
    }

    // Unmatched Bills section (receipts submitted with no statement charge yet)
    final unmatchedBills = bills.where((b) {
      final bMonth = '${b.billDate.year}-${b.billDate.month.toString().padLeft(2, '0')}';
      return bMonth == cycleMonth && !b.isMatched;
    }).toList();

    if (unmatchedBills.isNotEmpty) {
      buffer.writeln('');
      buffer.writeln('"--- UNCLAIMED EMPLOYEE RECEIPTS (NOT ON STATEMENT) ---"');
      buffer.writeln('"Receipt Date","Employee","Vendor","Invoice #","Category","Material Details","Bill Amount"');
      for (final ub in unmatchedBills) {
        buffer.writeln(
          '"${df.format(ub.billDate)}","${ub.employeeName.replaceAll('"', '""')}","${ub.vendorName.replaceAll('"', '""')}","${ub.invoiceNumber.replaceAll('"', '""')}","${ub.category}","${ub.materialDescription.replaceAll('"', '""')}","${ub.amount.toStringAsFixed(2)}"',
        );
      }
    }

    return buffer.toString();
  }

  /// Generates and shares a professional PDF reconciliation audit report
  static Future<void> sharePdfReport({
    required String cycleMonth,
    required List<StatementTransactionEntity> transactions,
    required List<ExpenseBillEntity> bills,
    required String organizationName,
  }) async {
    final pdfBytes = await _buildPdfBytes(
      cycleMonth: cycleMonth,
      transactions: transactions,
      bills: bills,
      organizationName: organizationName,
    );

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'reconciliation_report_$cycleMonth.pdf',
    );
  }

  static Future<Uint8List> _buildPdfBytes({
    required String cycleMonth,
    required List<StatementTransactionEntity> transactions,
    required List<ExpenseBillEntity> bills,
    required String organizationName,
  }) async {
    final pdf = pw.Document();
    final df = DateFormat('dd/MM/yyyy');
    final summary = ReconciliationMatchingService.computeSummary(
      cycleMonth: cycleMonth,
      transactions: transactions,
      bills: bills,
    );
    final pairs = ReconciliationMatchingService.buildPairs(
      cycleMonth: cycleMonth,
      transactions: transactions,
      bills: bills,
    );

    pdf.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.all(24),
        header: (context) => pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Column(
                  crossAxisAlignment: pw.CrossAxisAlignment.start,
                  children: [
                    pw.Text(
                      organizationName.toUpperCase(),
                      style: pw.TextStyle(
                        fontSize: 14,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.indigo900,
                      ),
                    ),
                    pw.Text(
                      'CREDIT CARD & BILL RECONCILIATION AUDIT ($cycleMonth)',
                      style: pw.TextStyle(
                        fontSize: 11,
                        fontWeight: pw.FontWeight.bold,
                        color: PdfColors.grey800,
                      ),
                    ),
                  ],
                ),
                pw.Container(
                  padding: const pw.EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: pw.BoxDecoration(
                    color: summary.isZeroBalance ? PdfColors.green700 : PdfColors.amber800,
                    borderRadius: pw.BorderRadius.circular(6),
                  ),
                  child: pw.Text(
                    summary.isZeroBalance ? 'ZERO BALANCE RECONCILED' : 'VARIANCE DETECTED',
                    style: pw.TextStyle(
                      color: PdfColors.white,
                      fontWeight: pw.FontWeight.bold,
                      fontSize: 9,
                    ),
                  ),
                ),
              ],
            ),
            pw.Divider(color: PdfColors.grey400, thickness: 1, height: 14),
          ],
        ),
        build: (context) {
          return [
            // Executive Summary Metric Box
            pw.Container(
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                borderRadius: pw.BorderRadius.circular(6),
                border: pw.Border.all(color: PdfColors.grey300),
              ),
              child: pw.Row(
                mainAxisAlignment: pw.MainAxisAlignment.spaceAround,
                children: [
                  _pdfMetricItem('Total Statement Charges', 'AED ${summary.totalStatementAmount.toStringAsFixed(2)}'),
                  _pdfMetricItem('Matched Employee Bills', 'AED ${summary.matchedBillsAmount.toStringAsFixed(2)}'),
                  _pdfMetricItem(
                    'Reconciliation Variance',
                    'AED ${summary.variance.toStringAsFixed(2)}',
                    color: summary.isZeroBalance ? PdfColors.green700 : PdfColors.red700,
                  ),
                  _pdfMetricItem('Matched Transactions', '${summary.matchedTransactionsCount} of ${summary.totalTransactionsCount}'),
                  _pdfMetricItem('Match Rate', '${summary.reconciliationRate.toStringAsFixed(1)}%'),
                ],
              ),
            ),
            pw.SizedBox(height: 14),

            // Reconciliation Table
            pw.Text(
              'STATEMENT TRANSACTIONS & MATCHED BILLS',
              style: pw.TextStyle(fontSize: 10, fontWeight: pw.FontWeight.bold, color: PdfColors.indigo900),
            ),
            pw.SizedBox(height: 6),

            pw.TableHelper.fromTextArray(
              headers: [
                'Date',
                'Statement Line / Merchant',
                'Statement Amt',
                'Status',
                'Employee',
                'Vendor / Bill',
                'Material Purchased',
                'Bill Amt',
                'Diff',
              ],
              data: pairs.map((pair) {
                final s = pair.statement;
                final b = pair.bill;
                final statusStr = b != null
                    ? (pair.isDiscrepancy ? 'Mismatch' : 'Matched')
                    : 'Missing Receipt';

                return [
                  df.format(s.transactionDate),
                  s.description,
                  'AED ${s.amount.toStringAsFixed(2)}',
                  statusStr,
                  b?.employeeName ?? '-',
                  b != null ? '${b.vendorName} (${b.invoiceNumber.isNotEmpty ? b.invoiceNumber : "N/A"})' : '-',
                  b?.materialDescription.isNotEmpty == true ? b!.materialDescription : '-',
                  b != null ? 'AED ${b.amount.toStringAsFixed(2)}' : '-',
                  pair.amountDifference != null ? 'AED ${pair.amountDifference!.toStringAsFixed(2)}' : '-',
                ];
              }).toList(),
              headerStyle: pw.TextStyle(fontWeight: pw.FontWeight.bold, color: PdfColors.white, fontSize: 8),
              headerDecoration: const pw.BoxDecoration(color: PdfColors.indigo900),
              cellStyle: const pw.TextStyle(fontSize: 7.5),
              cellPadding: const pw.EdgeInsets.symmetric(horizontal: 4, vertical: 4),
              cellAlignment: pw.Alignment.centerLeft,
            ),
          ];
        },
      ),
    );

    return pdf.save();
  }

  static pw.Widget _pdfMetricItem(String label, String value, {PdfColor? color}) {
    return pw.Column(
      children: [
        pw.Text(label, style: const pw.TextStyle(fontSize: 8, color: PdfColors.grey700)),
        pw.SizedBox(height: 3),
        pw.Text(
          value,
          style: pw.TextStyle(
            fontSize: 10,
            fontWeight: pw.FontWeight.bold,
            color: color ?? PdfColors.indigo900,
          ),
        ),
      ],
    );
  }
}
