import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/features/reconciliation/domain/expense_bill_entity.dart';
import 'package:attendance_app/core/constants/app_theme.dart';

class BillPreviewDialog extends StatelessWidget {
  final ExpenseBillEntity bill;
  const BillPreviewDialog({super.key, required this.bill});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppTheme.currentColors;
    final df = DateFormat('yyyy-MM-dd');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? palette.surfaceDark : Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 520, maxHeight: 660),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                CircleAvatar(
                  backgroundColor: palette.primaryLight.withValues(alpha: 0.15),
                  child: Icon(Icons.receipt_rounded, color: palette.primaryLight, size: 20),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        bill.vendorName,
                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Invoice: ${bill.invoiceNumber.isNotEmpty ? bill.invoiceNumber : "N/A"} • ${df.format(bill.billDate)}',
                        style: const TextStyle(fontSize: 12, color: Colors.grey),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close_rounded),
                  onPressed: () => Navigator.pop(context),
                ),
              ],
            ),
            const Divider(height: 20),

            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Amount Card
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(
                        color: Colors.green.withValues(alpha: 0.1),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Total Bill Amount:', style: TextStyle(fontWeight: FontWeight.w600)),
                          Text(
                            'AED ${bill.amount.toStringAsFixed(2)}',
                            style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: Colors.green),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 16),

                    _infoRow('Purchased By', bill.employeeName, Icons.person_rounded),
                    _infoRow('Expense Category', bill.category, Icons.category_rounded),
                    _infoRow('Company Card', 'Card ending in *${bill.cardLast4}', Icons.credit_card_rounded),
                    _infoRow(
                      'Match Status',
                      bill.isMatched ? 'Matched to Bank Statement' : 'Unmatched (Pending Statement)',
                      bill.isMatched ? Icons.check_circle_rounded : Icons.pending_rounded,
                      color: bill.isMatched ? Colors.green : Colors.orange,
                    ),

                    if (bill.materialDescription.isNotEmpty) ...[
                      const SizedBox(height: 12),
                      const Text(
                        'Material Details / Purchased Items:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: Text(
                          bill.materialDescription,
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ],

                    if (bill.receiptImageBase64 != null) ...[
                      const SizedBox(height: 16),
                      const Text(
                        'Scanned Receipt / Photo:',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 8),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.memory(
                          base64Decode(bill.receiptImageBase64!),
                          fit: BoxFit.contain,
                          width: double.infinity,
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _infoRow(String label, String value, IconData icon, {Color? color}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: color ?? Colors.grey),
          const SizedBox(width: 8),
          Text('$label: ', style: const TextStyle(fontSize: 12, color: Colors.grey)),
          Expanded(
            child: Text(
              value,
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: color),
            ),
          ),
        ],
      ),
    );
  }
}
