import 'expense_bill_entity.dart';
import 'statement_transaction_entity.dart';

/// Summary metrics for a specific billing cycle month
class ReconciliationCycleSummary {
  final String cycleMonth;
  final double totalStatementAmount;
  final double totalBillsAmount;
  final double matchedStatementAmount;
  final double matchedBillsAmount;
  final int totalTransactionsCount;
  final int matchedTransactionsCount;
  final int totalBillsCount;
  final int matchedBillsCount;

  const ReconciliationCycleSummary({
    required this.cycleMonth,
    required this.totalStatementAmount,
    required this.totalBillsAmount,
    required this.matchedStatementAmount,
    required this.matchedBillsAmount,
    required this.totalTransactionsCount,
    required this.matchedTransactionsCount,
    required this.totalBillsCount,
    required this.matchedBillsCount,
  });

  /// Variance: Statement total minus matched bills amount.
  /// When zero, reconciliation is balanced!
  double get variance => totalStatementAmount - matchedBillsAmount;

  /// Whether the monthly credit card statement has achieved zero balance
  bool get isZeroBalance => totalStatementAmount > 0 && variance.abs() < 0.01;

  int get unmatchedTransactionsCount => totalTransactionsCount - matchedTransactionsCount;
  int get unmatchedBillsCount => totalBillsCount - matchedBillsCount;

  /// Percentage of statement dollars reconciled against employee bills
  double get reconciliationRate {
    if (totalStatementAmount <= 0) return 0.0;
    final rate = (matchedBillsAmount / totalStatementAmount) * 100.0;
    return rate.clamp(0.0, 100.0);
  }
}

/// Represents a matched or unmatched pair of statement transaction and employee bill
class ReconciliationMatchedPair {
  final StatementTransactionEntity statement;
  final ExpenseBillEntity? bill;
  final double? amountDifference;
  final bool isDiscrepancy;

  const ReconciliationMatchedPair({
    required this.statement,
    this.bill,
    this.amountDifference,
    this.isDiscrepancy = false,
  });
}
