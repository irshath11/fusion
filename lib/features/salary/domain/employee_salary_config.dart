/// Represents the fixed and variable salary configuration for an employee.
class EmployeeSalaryConfig {
  final String employeeCode;
  final String? employeeId;
  final String employeeName;
  final String department;
  final double fixedSalary;
  final double variableSalary;
  final double dailyDivisor; // Standard divisor for daily rate (defaults to 30.0)
  final double standardDailyHours; // Standard shift hours per day (defaults to 8.0)
  final double? customOtHourlyRate; // Optional custom OT hourly rate

  /// When set, this custom manual amount is credited as the total OT amount for the month (AED),
  /// overriding hourly OT calculation.
  final double? customMonthlyOtAmount;

  /// When true, OT is NOT calculated (or credited as 0.0),
  /// because fixed overtime is already included in the variable salary / allowance.
  final bool otIncludedInVariable;

  /// When true, if the employee worked on Monday, the preceding Sunday is credited as payable.
  final bool paySundayIfMondayWorked;

  final DateTime updatedAt;

  EmployeeSalaryConfig({
    required this.employeeCode,
    this.employeeId,
    required this.employeeName,
    this.department = 'General',
    required this.fixedSalary,
    required this.variableSalary,
    this.dailyDivisor = 30.0,
    this.standardDailyHours = 8.0,
    this.customOtHourlyRate,
    this.customMonthlyOtAmount,
    this.otIncludedInVariable = false,
    this.paySundayIfMondayWorked = true,
    DateTime? updatedAt,
  }) : updatedAt = updatedAt ?? DateTime.now();

  /// Basic Salary alias (Fixed salary component)
  double get basicSalary => fixedSalary;

  /// Monthly Base Total (Basic Fixed + Variable Allowance)
  double get monthlyBaseTotal => fixedSalary + variableSalary;

  /// Daily Fixed / Basic Salary Rate (Basic / 30)
  double get dailyFixedRate =>
      dailyDivisor > 0 ? fixedSalary / dailyDivisor : 0.0;

  /// Daily Variable Salary Rate (Variable / 30)
  double get dailyVariableRate =>
      dailyDivisor > 0 ? variableSalary / dailyDivisor : 0.0;

  /// Daily Combined Base Rate (Basic/30 + Variable/30)
  double get dailyBaseRate => dailyFixedRate + dailyVariableRate;

  /// Hourly Overtime Rate: Strictly calculated from Basic Salary ONLY (variable allowance is excluded).
  /// Formula: (Basic Salary / totalDaysOfCurrentMonth) / 8.
  /// If [otIncludedInVariable] is true, returns 0.0.
  /// Example (e.g. Shabi): Basic = 1200, Variable = 1100 (Total = 2300).
  /// In a 30-day month: (1200 / 30) / 8 = 40 / 8 = 5.00 AED/hr (NOT 2300 / 30 / 8).
  double computeHourlyOtRate({int totalDaysOfCurrentMonth = 30}) {
    if (otIncludedInVariable) return 0.0;
    if (customOtHourlyRate != null) return customOtHourlyRate!;
    if (totalDaysOfCurrentMonth <= 0 || standardDailyHours <= 0) return 0.0;
    return (basicSalary / totalDaysOfCurrentMonth) / standardDailyHours;
  }

  /// Standard OT hourly rate based on daily divisor (defaults to 30 days): (Basic Salary / 30) / 8
  double get otHourlyRate =>
      computeHourlyOtRate(totalDaysOfCurrentMonth: dailyDivisor > 0 ? dailyDivisor.round() : 30);

  /// True if a manual fixed total monthly OT amount is configured
  bool get hasCustomMonthlyOtAmount =>
      !otIncludedInVariable && customMonthlyOtAmount != null && customMonthlyOtAmount! >= 0;

  Map<String, dynamic> toJson() => {
        'employeeCode': employeeCode,
        'employee_code': employeeCode,
        'employeeId': employeeId,
        'employee_id': employeeId,
        'employeeName': employeeName,
        'employee_name': employeeName,
        'department': department,
        'fixedSalary': fixedSalary,
        'fixed_salary': fixedSalary,
        'variableSalary': variableSalary,
        'variable_salary': variableSalary,
        'dailyDivisor': dailyDivisor,
        'daily_divisor': dailyDivisor,
        'standardDailyHours': standardDailyHours,
        'standard_daily_hours': standardDailyHours,
        'customOtHourlyRate': customOtHourlyRate,
        'custom_ot_hourly_rate': customOtHourlyRate,
        'customMonthlyOtAmount': customMonthlyOtAmount,
        'custom_monthly_ot_amount': customMonthlyOtAmount,
        'otIncludedInVariable': otIncludedInVariable,
        'ot_included_in_variable': otIncludedInVariable,
        'paySundayIfMondayWorked': paySundayIfMondayWorked,
        'pay_sunday_if_monday_worked': paySundayIfMondayWorked,
        'updatedAt': updatedAt.toIso8601String(),
        'updated_at': updatedAt.toIso8601String(),
      };

  factory EmployeeSalaryConfig.fromJson(Map<String, dynamic> json) =>
      EmployeeSalaryConfig(
        employeeCode: (json['employeeCode'] ?? json['employee_code'] ?? '').toString().trim(),
        employeeId: (json['employeeId'] ?? json['employee_id'])?.toString(),
        employeeName: (json['employeeName'] ?? json['employee_name'] ?? '').toString().trim(),
        department: (json['department'] ?? 'General').toString().trim(),
        fixedSalary: (json['fixedSalary'] ?? json['fixed_salary'] as num?)?.toDouble() ?? 0.0,
        variableSalary: (json['variableSalary'] ?? json['variable_salary'] as num?)?.toDouble() ?? 0.0,
        dailyDivisor: (json['dailyDivisor'] ?? json['daily_divisor'] as num?)?.toDouble() ?? 30.0,
        standardDailyHours: (json['standardDailyHours'] ?? json['standard_daily_hours'] as num?)?.toDouble() ?? 8.0,
        customOtHourlyRate: (json['customOtHourlyRate'] ?? json['custom_ot_hourly_rate'] as num?)?.toDouble(),
        customMonthlyOtAmount: (json['customMonthlyOtAmount'] ?? json['custom_monthly_ot_amount'] as num?)?.toDouble(),
        otIncludedInVariable: (json['otIncludedInVariable'] ?? json['ot_included_in_variable']) as bool? ?? false,
        paySundayIfMondayWorked: (json['paySundayIfMondayWorked'] ?? json['pay_sunday_if_monday_worked']) as bool? ?? true,
        updatedAt: json['updatedAt'] != null || json['updated_at'] != null
            ? DateTime.tryParse((json['updatedAt'] ?? json['updated_at']).toString()) ?? DateTime.now()
            : DateTime.now(),
      );

  EmployeeSalaryConfig copyWith({
    String? employeeCode,
    String? employeeId,
    String? employeeName,
    String? department,
    double? fixedSalary,
    double? variableSalary,
    double? dailyDivisor,
    double? standardDailyHours,
    double? customOtHourlyRate,
    bool clearCustomOtHourlyRate = false,
    double? customMonthlyOtAmount,
    bool clearCustomMonthlyOtAmount = false,
    bool? otIncludedInVariable,
    bool? paySundayIfMondayWorked,
    DateTime? updatedAt,
  }) {
    return EmployeeSalaryConfig(
      employeeCode: employeeCode ?? this.employeeCode,
      employeeId: employeeId ?? this.employeeId,
      employeeName: employeeName ?? this.employeeName,
      department: department ?? this.department,
      fixedSalary: fixedSalary ?? this.fixedSalary,
      variableSalary: variableSalary ?? this.variableSalary,
      dailyDivisor: dailyDivisor ?? this.dailyDivisor,
      standardDailyHours: standardDailyHours ?? this.standardDailyHours,
      customOtHourlyRate: clearCustomOtHourlyRate
          ? null
          : (customOtHourlyRate ?? this.customOtHourlyRate),
      customMonthlyOtAmount: clearCustomMonthlyOtAmount
          ? null
          : (customMonthlyOtAmount ?? this.customMonthlyOtAmount),
      otIncludedInVariable: otIncludedInVariable ?? this.otIncludedInVariable,
      paySundayIfMondayWorked: paySundayIfMondayWorked ?? this.paySundayIfMondayWorked,
      updatedAt: updatedAt ?? DateTime.now(),
    );
  }
}

