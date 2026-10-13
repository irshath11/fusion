import 'package:equatable/equatable.dart';
import '../domain/expense_bill_entity.dart';
import '../domain/statement_transaction_entity.dart';
import '../domain/reconciliation_models.dart';

abstract class ReconciliationState extends Equatable {
  const ReconciliationState();

  @override
  List<Object?> get props => [];
}

class ReconciliationInitial extends ReconciliationState {
  const ReconciliationInitial();
}

class ReconciliationLoading extends ReconciliationState {
  const ReconciliationLoading();
}

class ReconciliationLoaded extends ReconciliationState {
  final String selectedCycleMonth;
  final List<StatementTransactionEntity> transactions;
  final List<ExpenseBillEntity> bills;
  final ReconciliationCycleSummary summary;
  final List<ReconciliationMatchedPair> pairs;
  final String? feedbackMessage;
  final bool isScanning;

  const ReconciliationLoaded({
    required this.selectedCycleMonth,
    required this.transactions,
    required this.bills,
    required this.summary,
    required this.pairs,
    this.feedbackMessage,
    this.isScanning = false,
  });

  ReconciliationLoaded copyWith({
    String? selectedCycleMonth,
    List<StatementTransactionEntity>? transactions,
    List<ExpenseBillEntity>? bills,
    ReconciliationCycleSummary? summary,
    List<ReconciliationMatchedPair>? pairs,
    String? feedbackMessage,
    bool clearFeedback = false,
    bool? isScanning,
  }) {
    return ReconciliationLoaded(
      selectedCycleMonth: selectedCycleMonth ?? this.selectedCycleMonth,
      transactions: transactions ?? this.transactions,
      bills: bills ?? this.bills,
      summary: summary ?? this.summary,
      pairs: pairs ?? this.pairs,
      feedbackMessage: clearFeedback ? null : (feedbackMessage ?? this.feedbackMessage),
      isScanning: isScanning ?? this.isScanning,
    );
  }

  @override
  List<Object?> get props => [
        selectedCycleMonth,
        transactions,
        bills,
        summary,
        pairs,
        feedbackMessage,
        isScanning,
      ];
}

class ReconciliationError extends ReconciliationState {
  final String message;
  const ReconciliationError(this.message);

  @override
  List<Object?> get props => [message];
}
