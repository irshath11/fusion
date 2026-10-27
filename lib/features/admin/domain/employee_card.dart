class EmployeeCard {
  final String id;
  final String organizationId;
  final String employeeId;
  final String cardType;
  final String cardName;
  final String cardNumber;
  final DateTime? issueDate;
  final DateTime expiryDate;
  final String? documentUrl;
  final String? fileName;
  final String? notes;
  final DateTime? lastNotifiedAt;
  final bool isDeleted;
  final DateTime createdAt;
  final DateTime updatedAt;

  EmployeeCard({
    required this.id,
    required this.organizationId,
    required this.employeeId,
    required this.cardType,
    required this.cardName,
    required this.cardNumber,
    this.issueDate,
    required this.expiryDate,
    this.documentUrl,
    this.fileName,
    this.notes,
    this.lastNotifiedAt,
    this.isDeleted = false,
    DateTime? createdAt,
    DateTime? updatedAt,
  })  : createdAt = createdAt ?? DateTime.now(),
        updatedAt = updatedAt ?? DateTime.now();

  int get daysUntilExpiry {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final exp = DateTime(expiryDate.year, expiryDate.month, expiryDate.day);
    return exp.difference(today).inDays;
  }

  bool get isExpired => daysUntilExpiry < 0;
  bool get isCritical => daysUntilExpiry >= 0 && daysUntilExpiry <= 3;
  bool get isExpiringSoon => daysUntilExpiry >= 0 && daysUntilExpiry <= 30;
  bool get isValid => daysUntilExpiry > 3;

  String get statusLabel {
    if (isExpired) {
      final abs = daysUntilExpiry.abs();
      return 'Expired ${abs}d ago';
    } else if (daysUntilExpiry == 0) {
      return 'Expires Today!';
    } else if (isCritical) {
      return 'Expires in $daysUntilExpiry day${daysUntilExpiry == 1 ? '' : 's'}';
    } else if (isExpiringSoon) {
      return '$daysUntilExpiry days left';
    } else {
      return 'Valid ($daysUntilExpiry days left)';
    }
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'organization_id': organizationId,
        'employee_id': employeeId,
        'card_type': cardType,
        'card_name': cardName,
        'card_number': cardNumber,
        'issue_date': issueDate?.toIso8601String().split('T').first,
        'expiry_date': expiryDate.toIso8601String().split('T').first,
        'document_url': documentUrl,
        'file_name': fileName,
        'notes': notes,
        'last_notified_at': lastNotifiedAt?.toIso8601String(),
        'is_deleted': isDeleted,
        'created_at': createdAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory EmployeeCard.fromJson(Map<String, dynamic> json) => EmployeeCard(
        id: json['id']?.toString() ?? '',
        organizationId: json['organization_id']?.toString() ?? '',
        employeeId: json['employee_id']?.toString() ?? '',
        cardType: json['card_type']?.toString() ?? 'CUSTOM_PASS',
        cardName: json['card_name']?.toString() ?? 'Employee Card',
        cardNumber: json['card_number']?.toString() ?? '',
        issueDate: json['issue_date'] != null
            ? DateTime.tryParse(json['issue_date'].toString())
            : null,
        expiryDate: json['expiry_date'] != null
            ? DateTime.tryParse(json['expiry_date'].toString()) ??
                DateTime.now().add(const Duration(days: 365))
            : DateTime.now().add(const Duration(days: 365)),
        documentUrl: json['document_url']?.toString(),
        fileName: json['file_name']?.toString(),
        notes: json['notes']?.toString(),
        lastNotifiedAt: json['last_notified_at'] != null
            ? DateTime.tryParse(json['last_notified_at'].toString())
            : null,
        isDeleted: json['is_deleted'] == true,
        createdAt: json['created_at'] != null
            ? DateTime.tryParse(json['created_at'].toString())
            : null,
        updatedAt: json['updated_at'] != null
            ? DateTime.tryParse(json['updated_at'].toString())
            : null,
      );

  EmployeeCard copyWith({
    String? id,
    String? organizationId,
    String? employeeId,
    String? cardType,
    String? cardName,
    String? cardNumber,
    DateTime? issueDate,
    DateTime? expiryDate,
    String? documentUrl,
    String? fileName,
    String? notes,
    DateTime? lastNotifiedAt,
    bool? isDeleted,
    DateTime? createdAt,
    DateTime? updatedAt,
  }) {
    return EmployeeCard(
      id: id ?? this.id,
      organizationId: organizationId ?? this.organizationId,
      employeeId: employeeId ?? this.employeeId,
      cardType: cardType ?? this.cardType,
      cardName: cardName ?? this.cardName,
      cardNumber: cardNumber ?? this.cardNumber,
      issueDate: issueDate ?? this.issueDate,
      expiryDate: expiryDate ?? this.expiryDate,
      documentUrl: documentUrl ?? this.documentUrl,
      fileName: fileName ?? this.fileName,
      notes: notes ?? this.notes,
      lastNotifiedAt: lastNotifiedAt ?? this.lastNotifiedAt,
      isDeleted: isDeleted ?? this.isDeleted,
      createdAt: createdAt ?? this.createdAt,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }
}
