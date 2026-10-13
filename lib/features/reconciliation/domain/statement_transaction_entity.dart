/// Represents a single line transaction parsed from the Credit Card / Bank statement.
class StatementTransactionEntity {
  final String id;
  final String cycleMonth; // e.g., '2026-10' (YYYY-MM)
  final DateTime transactionDate;
  final String description; // Merchant name / description on the statement
  final double amount;
  final String cardLast4;
  final String? matchedBillId;
  final double? matchConfidence; // 1.0 = exact amount & date, 0.8 = fuzzy
  final String? matchNotes;
  final DateTime createdAt;

  const StatementTransactionEntity({
    required this.id,
    required this.cycleMonth,
    required this.transactionDate,
    required this.description,
    required this.amount,
    this.cardLast4 = '4129',
    this.matchedBillId,
    this.matchConfidence,
    this.matchNotes,
    required this.createdAt,
  });

  bool get isMatched => matchedBillId != null && matchedBillId!.isNotEmpty;

  StatementTransactionEntity copyWith({
    String? id,
    String? cycleMonth,
    DateTime? transactionDate,
    String? description,
    double? amount,
    String? cardLast4,
    String? matchedBillId,
    double? matchConfidence,
    String? matchNotes,
    bool clearMatch = false,
    DateTime? createdAt,
  }) {
    return StatementTransactionEntity(
      id: id ?? this.id,
      cycleMonth: cycleMonth ?? this.cycleMonth,
      transactionDate: transactionDate ?? this.transactionDate,
      description: description ?? this.description,
      amount: amount ?? this.amount,
      cardLast4: cardLast4 ?? this.cardLast4,
      matchedBillId: clearMatch ? null : (matchedBillId ?? this.matchedBillId),
      matchConfidence: clearMatch ? null : (matchConfidence ?? this.matchConfidence),
      matchNotes: clearMatch ? null : (matchNotes ?? this.matchNotes),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'cycleMonth': cycleMonth,
        'transactionDate': transactionDate.toIso8601String(),
        'description': description,
        'amount': amount,
        'cardLast4': cardLast4,
        'matchedBillId': matchedBillId,
        'matchConfidence': matchConfidence,
        'matchNotes': matchNotes,
        'createdAt': createdAt.toIso8601String(),
      };

  factory StatementTransactionEntity.fromJson(Map<String, dynamic> json) {
    return StatementTransactionEntity(
      id: json['id']?.toString() ?? '',
      cycleMonth: json['cycleMonth']?.toString() ?? '',
      transactionDate: json['transactionDate'] != null
          ? DateTime.tryParse(json['transactionDate'].toString()) ?? DateTime.now()
          : DateTime.now(),
      description: json['description']?.toString() ?? '',
      amount: (json['amount'] is num)
          ? (json['amount'] as num).toDouble()
          : (double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0),
      cardLast4: json['cardLast4']?.toString() ?? '4129',
      matchedBillId: json['matchedBillId']?.toString(),
      matchConfidence: (json['matchConfidence'] is num)
          ? (json['matchConfidence'] as num).toDouble()
          : (double.tryParse(json['matchConfidence']?.toString() ?? '')),
      matchNotes: json['matchNotes']?.toString(),
      createdAt: json['createdAt'] != null
          ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }
}
