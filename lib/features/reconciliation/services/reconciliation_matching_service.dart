import '../domain/expense_bill_entity.dart';
import '../domain/statement_transaction_entity.dart';
import '../domain/reconciliation_models.dart';

class ReconciliationMatchingService {
  /// Computes the complete zero-balance reconciliation summary for a given cycle
  static ReconciliationCycleSummary computeSummary({
    required String cycleMonth,
    required List<StatementTransactionEntity> transactions,
    required List<ExpenseBillEntity> bills,
  }) {
    final cycleTransactions = transactions.where((t) => t.cycleMonth == cycleMonth).toList();
    final cycleBills = bills.where((b) {
      final billMonth = '${b.billDate.year}-${b.billDate.month.toString().padLeft(2, '0')}';
      return billMonth == cycleMonth;
    }).toList();

    double totalStatement = 0.0;
    double matchedStatement = 0.0;
    int matchedTxCount = 0;

    for (final tx in cycleTransactions) {
      totalStatement += tx.amount;
      if (tx.isMatched) {
        matchedStatement += tx.amount;
        matchedTxCount++;
      }
    }

    double totalBills = 0.0;
    double matchedBills = 0.0;
    int matchedBillCount = 0;

    for (final bill in cycleBills) {
      totalBills += bill.amount;
      if (bill.isMatched) {
        matchedBills += bill.amount;
        matchedBillCount++;
      }
    }

    return ReconciliationCycleSummary(
      cycleMonth: cycleMonth,
      totalStatementAmount: totalStatement,
      totalBillsAmount: totalBills,
      matchedStatementAmount: matchedStatement,
      matchedBillsAmount: matchedBills,
      totalTransactionsCount: cycleTransactions.length,
      matchedTransactionsCount: matchedTxCount,
      totalBillsCount: cycleBills.length,
      matchedBillsCount: matchedBillCount,
    );
  }

  /// Automatically pairs statement transactions with employee bills
  /// Returns updated copies of [transactions] and [bills] with matched IDs.
  static ({
    List<StatementTransactionEntity> updatedTransactions,
    List<ExpenseBillEntity> updatedBills,
    int newlyMatchedCount,
  }) autoMatch({
    required String cycleMonth,
    required List<StatementTransactionEntity> transactions,
    required List<ExpenseBillEntity> bills,
  }) {
    final List<StatementTransactionEntity> txList = transactions.map((t) => t.copyWith()).toList();
    final List<ExpenseBillEntity> billList = bills.map((b) => b.copyWith()).toList();

    int matchedCount = 0;

    // Filter available (unmatched) in this cycle
    final availableTxs = txList.where((t) => t.cycleMonth == cycleMonth && !t.isMatched).toList();
    final availableBills = billList.where((b) {
      final bMonth = '${b.billDate.year}-${b.billDate.month.toString().padLeft(2, '0')}';
      return bMonth == cycleMonth && !b.isMatched;
    }).toList();

    for (final tx in availableTxs) {
      // Find candidate bills matching amount within 0.01
      final candidates = availableBills.where((b) {
        return (b.amount - tx.amount).abs() < 0.01;
      }).toList();

      if (candidates.isEmpty) continue;

      ExpenseBillEntity? bestMatch;
      double bestConfidence = 0.0;

      if (candidates.length == 1) {
        // Single candidate with identical amount
        bestMatch = candidates.first;
        final dayDiff = (bestMatch.billDate.difference(tx.transactionDate).inDays).abs();
        bestConfidence = dayDiff <= 3 ? 1.0 : (dayDiff <= 7 ? 0.9 : 0.8);
      } else {
        // Multiple candidates: score based on date proximity and merchant name fuzzy match
        double highestScore = -1.0;
        final txDescUpper = tx.description.toUpperCase();

        for (final cand in candidates) {
          double score = 0.0;
          final dayDiff = (cand.billDate.difference(tx.transactionDate).inDays).abs();
          if (dayDiff <= 1) score += 50;
          else if (dayDiff <= 4) score += 30;
          else if (dayDiff <= 7) score += 10;

          final vendorUpper = cand.vendorName.toUpperCase();
          if (txDescUpper.contains(vendorUpper) || vendorUpper.contains(txDescUpper)) {
            score += 50;
          } else {
            final words = vendorUpper.split(' ').where((w) => w.length > 2);
            for (final w in words) {
              if (txDescUpper.contains(w)) {
                score += 20;
                break;
              }
            }
          }

          if (score > highestScore) {
            highestScore = score;
            bestMatch = cand;
            bestConfidence = score >= 70 ? 0.95 : 0.85;
          }
        }
      }

      if (bestMatch != null) {
        final txIdx = txList.indexWhere((t) => t.id == tx.id);
        final billIdx = billList.indexWhere((b) => b.id == bestMatch!.id);

        if (txIdx >= 0 && billIdx >= 0) {
          txList[txIdx] = txList[txIdx].copyWith(
            matchedBillId: bestMatch.id,
            matchConfidence: bestConfidence,
            matchNotes: 'Auto-matched by amount & date',
          );
          billList[billIdx] = billList[billIdx].copyWith(
            matchedStatementId: tx.id,
          );

          // Remove from available candidates so it won't be reused
          availableBills.removeWhere((b) => b.id == bestMatch!.id);
          matchedCount++;
        }
      }
    }

    return (
      updatedTransactions: txList,
      updatedBills: billList,
      newlyMatchedCount: matchedCount,
    );
  }

  /// Builds paired list of statement transactions and their matched bills (or unmatched)
  static List<ReconciliationMatchedPair> buildPairs({
    required String cycleMonth,
    required List<StatementTransactionEntity> transactions,
    required List<ExpenseBillEntity> bills,
  }) {
    final cycleTxs = transactions.where((t) => t.cycleMonth == cycleMonth).toList();
    final List<ReconciliationMatchedPair> pairs = [];

    for (final tx in cycleTxs) {
      if (tx.isMatched) {
        final matchedBill = bills.cast<ExpenseBillEntity?>().firstWhere(
              (b) => b?.id == tx.matchedBillId,
              orElse: () => null,
            );
        final diff = matchedBill != null ? (tx.amount - matchedBill.amount) : 0.0;
        pairs.add(
          ReconciliationMatchedPair(
            statement: tx,
            bill: matchedBill,
            amountDifference: diff,
            isDiscrepancy: diff.abs() > 0.01,
          ),
        );
      } else {
        // Unmatched statement transaction -> missing employee bill!
        pairs.add(
          ReconciliationMatchedPair(
            statement: tx,
            bill: null,
            amountDifference: tx.amount,
            isDiscrepancy: true,
          ),
        );
      }
    }

    return pairs;
  }
}
