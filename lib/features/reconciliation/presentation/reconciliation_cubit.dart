import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import '../../../database/local_database_service.dart';
import '../domain/expense_bill_entity.dart';
import '../domain/statement_transaction_entity.dart';
import '../services/reconciliation_matching_service.dart';
import 'reconciliation_state.dart';

class ReconciliationCubit extends Cubit<ReconciliationState> {
  final LocalDatabaseService _db = LocalDatabaseService();

  ReconciliationCubit() : super(const ReconciliationInitial()) {
    final now = DateTime.now();
    final defaultMonth = DateFormat('yyyy-MM').format(now);
    loadCycle(defaultMonth);
  }

  void loadCycle(String cycleMonth, {String? feedback}) {
    final allTxs = _db.getStatementTransactions();
    final allBills = _db.getExpenseBills();

    final summary = ReconciliationMatchingService.computeSummary(
      cycleMonth: cycleMonth,
      transactions: allTxs,
      bills: allBills,
    );

    final pairs = ReconciliationMatchingService.buildPairs(
      cycleMonth: cycleMonth,
      transactions: allTxs,
      bills: allBills,
    );

    emit(
      ReconciliationLoaded(
        selectedCycleMonth: cycleMonth,
        transactions: allTxs.where((t) => t.cycleMonth == cycleMonth).toList(),
        bills: allBills,
        summary: summary,
        pairs: pairs,
        feedbackMessage: feedback,
      ),
    );
  }

  Future<void> changeMonth(String newMonth) async {
    loadCycle(newMonth);
  }

  Future<void> addExpenseBill(ExpenseBillEntity bill) async {
    await _db.saveExpenseBill(bill);
    final curState = state;
    if (curState is ReconciliationLoaded) {
      loadCycle(curState.selectedCycleMonth, feedback: 'Expense bill from ${bill.employeeName} added.');
    }
  }

  Future<void> deleteExpenseBill(String id) async {
    await _db.deleteExpenseBill(id);
    final curState = state;
    if (curState is ReconciliationLoaded) {
      loadCycle(curState.selectedCycleMonth, feedback: 'Expense bill removed.');
    }
  }

  Future<void> importStatementTransactions(List<StatementTransactionEntity> items) async {
    await _db.saveStatementTransactions(items);
    final curState = state;
    if (curState is ReconciliationLoaded) {
      loadCycle(curState.selectedCycleMonth, feedback: '${items.length} statement transactions imported.');
    }
  }

  Future<void> deleteStatementTransaction(String id) async {
    await _db.deleteStatementTransaction(id);
    final curState = state;
    if (curState is ReconciliationLoaded) {
      loadCycle(curState.selectedCycleMonth, feedback: 'Statement transaction removed.');
    }
  }

  Future<void> pairMatch(String statementId, String billId) async {
    await _db.pairMatch(statementId, billId);
    final curState = state;
    if (curState is ReconciliationLoaded) {
      loadCycle(curState.selectedCycleMonth, feedback: 'Transaction successfully matched with bill.');
    }
  }

  Future<void> unpairMatch(String statementId) async {
    await _db.unpairMatch(statementId);
    final curState = state;
    if (curState is ReconciliationLoaded) {
      loadCycle(curState.selectedCycleMonth, feedback: 'Match unlinked.');
    }
  }

  Future<void> triggerAutoMatch() async {
    final curState = state;
    if (curState is ReconciliationLoaded) {
      final matchedCount = await _db.autoMatchCycle(curState.selectedCycleMonth);
      loadCycle(
        curState.selectedCycleMonth,
        feedback: matchedCount > 0
            ? 'Smart match successfully paired $matchedCount bills!'
            : 'No new matching bills found for unmatched statement charges.',
      );
    }
  }

  Future<void> seedDemoData() async {
    final curState = state;
    final month = (curState is ReconciliationLoaded)
        ? curState.selectedCycleMonth
        : DateFormat('yyyy-MM').format(DateTime.now());

    await _db.seedReconciliationDemoData(month);
    loadCycle(month, feedback: 'Demo reconciliation data loaded for $month.');
  }

  Future<void> clearCycle() async {
    final curState = state;
    if (curState is ReconciliationLoaded) {
      await _db.clearCycleData(curState.selectedCycleMonth);
      loadCycle(curState.selectedCycleMonth, feedback: 'Cleared all bills & statement items for ${curState.selectedCycleMonth}.');
    }
  }
}
