/// Represents an employee's expense bill/receipt for material purchase
/// using the company credit card.
class ExpenseBillEntity {
  final String id;
  final String employeeId;
  final String employeeName;
  final String vendorName;
  final String invoiceNumber;
  final double amount;
  final DateTime billDate;
  final String cardLast4;
  final String category; // e.g., 'Material Purchase', 'Tools & Hardware', 'Site Consumables', 'Travel/Fuel', 'Other'
  final String materialDescription;
  final String? workSiteId;
  final String? workSiteName;
  final String? receiptImageBase64;
  final String? matchedStatementId;
  final DateTime createdAt;

  const ExpenseBillEntity({
    required this.id,
    required this.employeeId,
    required this.employeeName,
    required this.vendorName,
    this.invoiceNumber = '',
    required this.amount,
    required this.billDate,
    this.cardLast4 = '4129',
    this.category = 'Material Purchase',
    this.materialDescription = '',
    this.workSiteId,
    this.workSiteName,
    this.receiptImageBase64,
    this.matchedStatementId,
    required this.createdAt,
  });

  bool get isMatched => matchedStatementId != null && matchedStatementId!.isNotEmpty;

  ExpenseBillEntity copyWith({
    String? id,
    String? employeeId,
    String? employeeName,
    String? vendorName,
    String? invoiceNumber,
    double? amount,
    DateTime? billDate,
    String? cardLast4,
    String? category,
    String? materialDescription,
    String? workSiteId,
    String? workSiteName,
    String? receiptImageBase64,
    String? matchedStatementId,
    bool clearMatch = false,
    DateTime? createdAt,
  }) {
    return ExpenseBillEntity(
      id: id ?? this.id,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      vendorName: vendorName ?? this.vendorName,
      invoiceNumber: invoiceNumber ?? this.invoiceNumber,
      amount: amount ?? this.amount,
      billDate: billDate ?? this.billDate,
      cardLast4: cardLast4 ?? this.cardLast4,
      category: category ?? this.category,
      materialDescription: materialDescription ?? this.materialDescription,
      workSiteId: workSiteId ?? this.workSiteId,
      workSiteName: workSiteName ?? this.workSiteName,
      receiptImageBase64: receiptImageBase64 ?? this.receiptImageBase64,
      matchedStatementId: clearMatch ? null : (matchedStatementId ?? this.matchedStatementId),
      createdAt: createdAt ?? this.createdAt,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'employeeId': employeeId,
        'employeeName': employeeName,
        'vendorName': vendorName,
        'invoiceNumber': invoiceNumber,
        'amount': amount,
        'billDate': billDate.toIso8601String(),
        'cardLast4': cardLast4,
        'category': category,
        'materialDescription': materialDescription,
        'workSiteId': workSiteId,
        'workSiteName': workSiteName,
        'receiptImageBase64': receiptImageBase64,
        'matchedStatementId': matchedStatementId,
        'createdAt': createdAt.toIso8601String(),
      };

  factory ExpenseBillEntity.fromJson(Map<String, dynamic> json) {
    return ExpenseBillEntity(
      id: json['id']?.toString() ?? '',
      employeeId: json['employeeId']?.toString() ?? '',
      employeeName: json['employeeName']?.toString() ?? '',
      vendorName: json['vendorName']?.toString() ?? '',
      invoiceNumber: json['invoiceNumber']?.toString() ?? '',
      amount: (json['amount'] is num) ? (json['amount'] as num).toDouble() : (double.tryParse(json['amount']?.toString() ?? '0') ?? 0.0),
      billDate: json['billDate'] != null ? DateTime.tryParse(json['billDate'].toString()) ?? DateTime.now() : DateTime.now(),
      cardLast4: json['cardLast4']?.toString() ?? '4129',
      category: json['category']?.toString() ?? 'Material Purchase',
      materialDescription: json['materialDescription']?.toString() ?? '',
      workSiteId: json['workSiteId']?.toString(),
      workSiteName: json['workSiteName']?.toString(),
      receiptImageBase64: json['receiptImageBase64']?.toString(),
      matchedStatementId: json['matchedStatementId']?.toString(),
      createdAt: json['createdAt'] != null ? DateTime.tryParse(json['createdAt'].toString()) ?? DateTime.now() : DateTime.now(),
    );
  }
}
