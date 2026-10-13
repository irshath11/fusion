import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:attendance_app/features/reconciliation/domain/expense_bill_entity.dart';
import 'package:attendance_app/features/reconciliation/domain/statement_transaction_entity.dart';
import 'package:attendance_app/core/constants/app_theme.dart';

class ManualMatchDialog extends StatelessWidget {
  final StatementTransactionEntity statement;
  final List<ExpenseBillEntity> availableBills;
  final Function(String billId) onMatch;

  const ManualMatchDialog({
    super.key,
    required this.statement,
    required this.availableBills,
    required this.onMatch,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppTheme.currentColors;
    final df = DateFormat('yyyy-MM-dd');

    // Sort available bills: exact amount match first, then by date proximity
    final sortedBills = List<ExpenseBillEntity>.from(availableBills);
    sortedBills.sort((a, b) {
      final diffA = (a.amount - statement.amount).abs();
      final diffB = (b.amount - statement.amount).abs();
      if (diffA != diffB) {
        return diffA.compareTo(diffB);
      }
      final daysA = (a.billDate.difference(statement.transactionDate).inDays).abs();
      final daysB = (b.billDate.difference(statement.transactionDate).inDays).abs();
      return daysA.compareTo(daysB);
    });

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? palette.surfaceDark : Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 600, maxHeight: 680),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.purple.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.link_rounded, color: Colors.purple, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Match Statement Transaction',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Pair card statement line with employee submitted receipt',
                        style: TextStyle(fontSize: 12, color: isDark ? Colors.white60 : Colors.black54),
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

            // Statement Card Info
            Container(
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                color: palette.primaryLight.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: palette.primaryLight.withValues(alpha: 0.3)),
              ),
              child: Row(
                children: [
                  const Icon(Icons.credit_card_rounded, color: Colors.indigo, size: 28),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          statement.description,
                          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                        ),
                        const SizedBox(height: 3),
                        Text(
                          '${df.format(statement.transactionDate)} • Card *${statement.cardLast4}',
                          style: const TextStyle(fontSize: 12, color: Colors.grey),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    'AED ${statement.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.indigo),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 16),

            Text(
              'Select Matching Employee Bill (${sortedBills.length} Unmatched)',
              style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),

            Expanded(
              child: sortedBills.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.inventory_2_outlined, size: 40, color: isDark ? Colors.white24 : Colors.black26),
                          const SizedBox(height: 8),
                          const Text(
                            'No unmatched employee bills available.',
                            style: TextStyle(fontWeight: FontWeight.w600),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Add a new bill first using "Add Employee Bill".',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: sortedBills.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final bill = sortedBills[index];
                        final diff = (bill.amount - statement.amount).abs();
                        final isExact = diff < 0.01;

                        return Container(
                          padding: const EdgeInsets.all(12),
                          decoration: BoxDecoration(
                            color: isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey.withValues(alpha: 0.05),
                            borderRadius: BorderRadius.circular(12),
                            border: Border.all(
                              color: isExact ? Colors.green.withValues(alpha: 0.5) : Colors.grey.withValues(alpha: 0.2),
                              width: isExact ? 1.5 : 1.0,
                            ),
                          ),
                          child: Row(
                            children: [
                              CircleAvatar(
                                backgroundColor: isExact ? Colors.green.withValues(alpha: 0.15) : Colors.grey.withValues(alpha: 0.15),
                                child: Icon(
                                  isExact ? Icons.check_circle_rounded : Icons.receipt_rounded,
                                  color: isExact ? Colors.green : Colors.grey,
                                  size: 20,
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Expanded(
                                          child: Text(
                                            bill.vendorName,
                                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                          ),
                                        ),
                                        if (isExact)
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                            decoration: BoxDecoration(
                                              color: Colors.green.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: const Text(
                                              'EXACT MATCH',
                                              style: TextStyle(color: Colors.green, fontSize: 9, fontWeight: FontWeight.bold),
                                            ),
                                          ),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      '${bill.employeeName} • ${df.format(bill.billDate)} • ${bill.category}',
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                    if (bill.materialDescription.isNotEmpty)
                                      Text(
                                        bill.materialDescription,
                                        style: TextStyle(fontSize: 11, color: isDark ? Colors.white70 : Colors.black87),
                                        maxLines: 1,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 12),
                              Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    'AED ${bill.amount.toStringAsFixed(2)}',
                                    style: TextStyle(
                                      fontSize: 13,
                                      fontWeight: FontWeight.bold,
                                      color: isExact ? Colors.green : Colors.black87,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  ElevatedButton(
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: isExact ? Colors.green : palette.primaryLight,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                                      visualDensity: VisualDensity.compact,
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                                    ),
                                    onPressed: () {
                                      onMatch(bill.id);
                                      Navigator.pop(context);
                                    },
                                    child: const Text('Link', style: TextStyle(fontSize: 11)),
                                  ),
                                ],
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}
