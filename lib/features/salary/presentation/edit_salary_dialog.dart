import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../../../database/local_database_service.dart';
import '../../admin/domain/employee_entity.dart';
import '../domain/employee_salary_config.dart';
import '../utils/salary_calculator.dart';

class EditSalaryDialog extends StatefulWidget {
  final EmployeeEntity? employee;
  final EmployeeSalaryConfig? existingConfig;
  final VoidCallback? onSaved;

  const EditSalaryDialog({
    super.key,
    this.employee,
    this.existingConfig,
    this.onSaved,
  });

  @override
  State<EditSalaryDialog> createState() => _EditSalaryDialogState();
}

class _EditSalaryDialogState extends State<EditSalaryDialog> {
  final _formKey = GlobalKey<FormState>();
  late TextEditingController _fixedSalaryController;
  late TextEditingController _variableSalaryController;
  late TextEditingController _customOtRateController;
  late TextEditingController _customMonthlyOtAmountController;

  EmployeeEntity? _selectedEmployee;
  double _fixedSalary = 0.0;
  double _variableSalary = 0.0;
  double? _customOtRate;
  double? _customMonthlyOtAmount;
  bool _useCustomOtRate = false;
  bool _useCustomMonthlyOt = false;
  bool _otIncludedInVariable = false;
  bool _paySundayIfMondayWorked = true;

  @override
  void initState() {
    super.initState();
    _selectedEmployee = widget.employee;

    final config = widget.existingConfig ??
        (widget.employee != null
            ? LocalDatabaseService().getEmployeeSalary(
                employeeCode: widget.employee!.employeeCode,
                employeeId: widget.employee!.id,
                employeeName: widget.employee!.name,
              )
            : null);

    _fixedSalary = config?.fixedSalary ?? 1200.0;
    _variableSalary = config?.variableSalary ?? 600.0;
    _customOtRate = config?.customOtHourlyRate;
    _useCustomOtRate = _customOtRate != null;
    _customMonthlyOtAmount = config?.customMonthlyOtAmount;
    _useCustomMonthlyOt = _customMonthlyOtAmount != null;
    _otIncludedInVariable = config?.otIncludedInVariable ?? false;
    _paySundayIfMondayWorked = config?.paySundayIfMondayWorked ?? true;

    _fixedSalaryController = TextEditingController(
      text: _fixedSalary > 0 ? _fixedSalary.toStringAsFixed(0) : '',
    );
    _variableSalaryController = TextEditingController(
      text: _variableSalary > 0 ? _variableSalary.toStringAsFixed(0) : '',
    );
    _customOtRateController = TextEditingController(
      text: _customOtRate != null ? _customOtRate!.toStringAsFixed(2) : '',
    );
    _customMonthlyOtAmountController = TextEditingController(
      text: _customMonthlyOtAmount != null ? _customMonthlyOtAmount!.toStringAsFixed(2) : '',
    );

    _fixedSalaryController.addListener(_updateCalculations);
    _variableSalaryController.addListener(_updateCalculations);
    _customOtRateController.addListener(_updateCalculations);
    _customMonthlyOtAmountController.addListener(_updateCalculations);
  }

  void _updateCalculations() {
    setState(() {
      _fixedSalary = double.tryParse(_fixedSalaryController.text.trim()) ?? 0.0;
      _variableSalary =
          double.tryParse(_variableSalaryController.text.trim()) ?? 0.0;
      if (_useCustomMonthlyOt && !_otIncludedInVariable) {
        _customMonthlyOtAmount =
            double.tryParse(_customMonthlyOtAmountController.text.trim());
      } else {
        _customMonthlyOtAmount = null;
      }
      if (_useCustomOtRate && !_otIncludedInVariable && !_useCustomMonthlyOt) {
        _customOtRate =
            double.tryParse(_customOtRateController.text.trim());
      } else {
        _customOtRate = null;
      }
    });
  }

  @override
  void dispose() {
    _fixedSalaryController.dispose();
    _variableSalaryController.dispose();
    _customOtRateController.dispose();
    _customMonthlyOtAmountController.dispose();
    super.dispose();
  }

  double get _dailyFixedRate => _fixedSalary / 30.0;
  double get _dailyVariableRate => _variableSalary / 30.0;
  double get _dailyBaseRate => _dailyFixedRate + _dailyVariableRate;
  double get _hourlyOtRate {
    if (_otIncludedInVariable) return 0.0;
    return _customOtRate ?? (_fixedSalary > 0 ? _fixedSalary / 240.0 : 0.0);
  }
  double get _monthlyTotal => _fixedSalary + _variableSalary;

  void _saveSalary() {
    if (!_formKey.currentState!.validate()) return;

    final emp = _selectedEmployee;
    final empCode = emp?.employeeCode ??
        widget.existingConfig?.employeeCode ??
        '';
    final empId = emp?.id ?? widget.existingConfig?.employeeId;
    final empName = emp?.name ?? widget.existingConfig?.employeeName ?? '';
    final empDept = emp?.department ?? widget.existingConfig?.department ?? 'General';

    if (empCode.isEmpty && empName.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please select an employee first.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    final newConfig = EmployeeSalaryConfig(
      employeeCode: empCode,
      employeeId: empId,
      employeeName: empName,
      department: empDept,
      fixedSalary: _fixedSalary,
      variableSalary: _variableSalary,
      dailyDivisor: 30.0,
      standardDailyHours: 8.0,
      customOtHourlyRate: _useCustomOtRate && !_otIncludedInVariable && !_useCustomMonthlyOt ? _customOtRate : null,
      customMonthlyOtAmount: _useCustomMonthlyOt && !_otIncludedInVariable ? _customMonthlyOtAmount : null,
      otIncludedInVariable: _otIncludedInVariable,
      paySundayIfMondayWorked: _paySundayIfMondayWorked,
      updatedAt: DateTime.now(),
    );

    LocalDatabaseService().saveEmployeeSalary(newConfig, persist: true);

    widget.onSaved?.call();
    Navigator.of(context).pop();

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          'Salary updated for $empName (Fixed: AED ${_fixedSalary.toStringAsFixed(0)}, Var: AED ${_variableSalary.toStringAsFixed(0)})',
        ),
        backgroundColor: AppColors.success,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final allEmployees = LocalDatabaseService()
        .getEmployees()
        .where((e) => !SalaryCalculator.isExcludedOwner(
              name: e.name,
              code: e.employeeCode,
              email: e.email,
              id: e.id,
            ))
        .toList();

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? AppColors.surfaceDark : Colors.white,
      insetPadding: const EdgeInsets.symmetric(horizontal: 20, vertical: 24),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 520),
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _formKey,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                // Header
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Icon(
                        Icons.payments_rounded,
                        color: AppColors.primary,
                        size: 24,
                      ),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            widget.existingConfig != null || widget.employee != null
                                ? 'Edit Employee Salary'
                                : 'Configure Employee Salary',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: isDark ? Colors.white : AppColors.textPrimaryLight,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'Fixed, Variable (Allowance) & Overtime rates',
                            style: TextStyle(
                              fontSize: 12,
                              color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
                            ),
                          ),
                        ],
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () => Navigator.of(context).pop(),
                      visualDensity: VisualDensity.compact,
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // Employee Selector (if not preselected)
                if (widget.employee == null && widget.existingConfig == null) ...[
                  Text(
                    'Select Employee',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                      color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                    ),
                  ),
                  const SizedBox(height: 6),
                  DropdownButtonFormField<EmployeeEntity>(
                    initialValue: _selectedEmployee,
                    isExpanded: true,
                    decoration: InputDecoration(
                      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      prefixIcon: const Icon(Icons.person_outline_rounded, size: 20),
                    ),
                    hint: const Text('Choose an employee'),
                    items: allEmployees.map((e) {
                      return DropdownMenuItem<EmployeeEntity>(
                        value: e,
                        child: Text(
                          '${e.employeeCode} - ${e.name} (${e.department})',
                          overflow: TextOverflow.ellipsis,
                        ),
                      );
                    }).toList(),
                    onChanged: (val) {
                      if (val != null) {
                        setState(() {
                          _selectedEmployee = val;
                          final existing = LocalDatabaseService().getEmployeeSalary(
                            employeeCode: val.employeeCode,
                            employeeId: val.id,
                            employeeName: val.name,
                          );
                          if (existing != null) {
                            _fixedSalary = existing.fixedSalary;
                            _variableSalary = existing.variableSalary;
                            _customOtRate = existing.customOtHourlyRate;
                            _useCustomOtRate = _customOtRate != null;
                            _customMonthlyOtAmount = existing.customMonthlyOtAmount;
                            _useCustomMonthlyOt = _customMonthlyOtAmount != null;
                            _otIncludedInVariable = existing.otIncludedInVariable;
                            _paySundayIfMondayWorked = existing.paySundayIfMondayWorked;

                            _fixedSalaryController.text = _fixedSalary > 0 ? _fixedSalary.toStringAsFixed(0) : '';
                            _variableSalaryController.text = _variableSalary > 0 ? _variableSalary.toStringAsFixed(0) : '';
                            _customOtRateController.text = _customOtRate != null ? _customOtRate!.toStringAsFixed(2) : '';
                            _customMonthlyOtAmountController.text = _customMonthlyOtAmount != null ? _customMonthlyOtAmount!.toStringAsFixed(2) : '';
                          }
                        });
                      }
                    },
                    validator: (v) => v == null ? 'Please select an employee' : null,
                  ),
                  const SizedBox(height: 16),
                ] else ...[
                  // Preselected employee badge
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: isDark ? AppColors.surfaceDark : Colors.grey[100],
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isDark ? Colors.white12 : Colors.grey[300]!,
                      ),
                    ),
                    child: Row(
                      children: [
                        CircleAvatar(
                          radius: 20,
                          backgroundColor: AppColors.primary.withValues(alpha: 0.15),
                          child: Text(
                            (_selectedEmployee?.name ?? widget.existingConfig?.employeeName ?? 'E')
                                .substring(0, 1)
                                .toUpperCase(),
                            style: const TextStyle(
                              color: AppColors.primary,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                _selectedEmployee?.name ?? widget.existingConfig?.employeeName ?? '',
                                style: const TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 14,
                                ),
                              ),
                              const SizedBox(height: 2),
                              Text(
                                '${_selectedEmployee?.employeeCode ?? widget.existingConfig?.employeeCode ?? ''} • ${_selectedEmployee?.department ?? widget.existingConfig?.department ?? 'General'}',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 18),
                ],

                // Basic / Fixed Salary Input
                Text(
                  'Monthly Basic Salary (Fixed) (AED)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _fixedSalaryController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.attach_money_rounded, size: 20),
                    hintText: 'e.g. 1200',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Basic salary is required';
                    final n = double.tryParse(val.trim());
                    if (n == null || n < 0) return 'Enter a valid positive number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Variable Salary (Allowance) Input
                Text(
                  'Monthly Variable Salary / Allowance (AED)',
                  style: TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                  ),
                ),
                const SizedBox(height: 6),
                TextFormField(
                  controller: _variableSalaryController,
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  decoration: InputDecoration(
                    prefixIcon: const Icon(Icons.add_card_rounded, size: 20),
                    hintText: 'e.g. 1100',
                    contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                  ),
                  validator: (val) {
                    if (val == null || val.trim().isEmpty) return 'Variable salary is required';
                    final n = double.tryParse(val.trim());
                    if (n == null || n < 0) return 'Enter a valid positive number';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Button / Toggle: Fixed OT Included in Variable Salary (Zero OT)
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _otIncludedInVariable
                        ? AppColors.primary.withValues(alpha: isDark ? 0.2 : 0.08)
                        : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _otIncludedInVariable
                          ? AppColors.primary.withValues(alpha: 0.4)
                          : (isDark ? Colors.white12 : Colors.grey[300]!),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _otIncludedInVariable
                                      ? Icons.check_circle_rounded
                                      : Icons.remove_circle_outline_rounded,
                                  size: 16,
                                  color: _otIncludedInVariable
                                      ? AppColors.primary
                                      : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'OT Included in Variable (Zero OT)',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _otIncludedInVariable
                                        ? AppColors.primary
                                        : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'Fixed OT is already included in variable salary. Overtime will NOT be calculated (credited as AED 0.00).',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _otIncludedInVariable,
                        activeTrackColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() {
                            _otIncludedInVariable = val;
                            if (_otIncludedInVariable) {
                              _useCustomOtRate = false;
                              _customOtRate = null;
                              _useCustomMonthlyOt = false;
                              _customMonthlyOtAmount = null;
                            }
                            _updateCalculations();
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Manual Total OT Amount of the Month (Lump sum for the month)
                if (!_otIncludedInVariable) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: _useCustomMonthlyOt
                          ? Colors.teal.withValues(alpha: isDark ? 0.2 : 0.08)
                          : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[100]),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: _useCustomMonthlyOt
                            ? Colors.teal.withValues(alpha: 0.4)
                            : (isDark ? Colors.white12 : Colors.grey[300]!),
                      ),
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Icon(
                                        Icons.payments_outlined,
                                        size: 16,
                                        color: _useCustomMonthlyOt ? Colors.teal : Colors.grey,
                                      ),
                                      const SizedBox(width: 6),
                                      Text(
                                        'Manual Total OT Amount of the Month',
                                        style: TextStyle(
                                          fontSize: 13,
                                          fontWeight: FontWeight.bold,
                                          color: _useCustomMonthlyOt
                                              ? Colors.teal
                                              : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    'Set a custom fixed total OT amount for the month (AED) instead of calculating hourly.',
                                    style: TextStyle(
                                      fontSize: 11,
                                      color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: _useCustomMonthlyOt,
                              activeTrackColor: Colors.teal,
                              onChanged: (val) {
                                setState(() {
                                  _useCustomMonthlyOt = val;
                                  if (_useCustomMonthlyOt) {
                                    _useCustomOtRate = false;
                                    _customOtRate = null;
                                  }
                                  _updateCalculations();
                                });
                              },
                            ),
                          ],
                        ),
                        if (_useCustomMonthlyOt) ...[
                          const SizedBox(height: 10),
                          TextFormField(
                            controller: _customMonthlyOtAmountController,
                            keyboardType: const TextInputType.numberWithOptions(decimal: true),
                            decoration: InputDecoration(
                              prefixIcon: const Icon(Icons.attach_money_rounded, size: 20),
                              hintText: 'e.g. 500',
                              suffixText: 'AED / month',
                              contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                              border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              filled: true,
                              fillColor: isDark ? AppColors.surfaceDark : Colors.white,
                              helperText: 'This total amount will be credited as OT for the month.',
                            ),
                            validator: (val) {
                              if (_useCustomMonthlyOt && !_otIncludedInVariable) {
                                if (val == null || val.trim().isEmpty) {
                                  return 'Enter monthly OT amount or turn off toggle';
                                }
                                final n = double.tryParse(val.trim());
                                if (n == null || n < 0) {
                                  return 'Enter a valid positive number';
                                }
                              }
                              return null;
                            },
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),
                ],

                // Custom OT Hourly Rate Toggle (Optional override - only visible if OT is not zeroed and not fixed monthly)
                if (!_otIncludedInVariable && !_useCustomMonthlyOt) ...[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Custom Overtime Hourly Rate',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: isDark ? Colors.white70 : AppColors.textPrimaryLight,
                              ),
                            ),
                            Text(
                              'Standard OT is (Basic / 30) / 8 = Basic / 240 (${(_fixedSalary / 240.0).toStringAsFixed(2)} AED/h)',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _useCustomOtRate,
                        activeTrackColor: AppColors.primary,
                        onChanged: (val) {
                          setState(() {
                            _useCustomOtRate = val;
                            _updateCalculations();
                          });
                        },
                      ),
                    ],
                  ),
                  if (_useCustomOtRate) ...[
                    const SizedBox(height: 8),
                    TextFormField(
                      controller: _customOtRateController,
                      keyboardType: const TextInputType.numberWithOptions(decimal: true),
                      decoration: InputDecoration(
                        prefixIcon: const Icon(Icons.timelapse_rounded, size: 20),
                        hintText: 'e.g. 5.00',
                        suffixText: 'AED/h',
                        contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                    ),
                  ],
                  const SizedBox(height: 12),
                ],

                // Sunday Payable Rule Toggle: Pay Sunday If Worked on Monday
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: _paySundayIfMondayWorked
                        ? Colors.blue.withValues(alpha: isDark ? 0.2 : 0.08)
                        : (isDark ? Colors.white.withValues(alpha: 0.04) : Colors.grey[100]),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: _paySundayIfMondayWorked
                          ? Colors.blue.withValues(alpha: 0.4)
                          : (isDark ? Colors.white12 : Colors.grey[300]!),
                    ),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Icon(
                                  _paySundayIfMondayWorked
                                      ? Icons.event_available_rounded
                                      : Icons.event_busy_rounded,
                                  size: 16,
                                  color: _paySundayIfMondayWorked ? Colors.blue : Colors.grey,
                                ),
                                const SizedBox(width: 6),
                                Text(
                                  'Pay Sunday If Worked on Monday',
                                  style: TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: _paySundayIfMondayWorked
                                        ? Colors.blue
                                        : (isDark ? Colors.white70 : AppColors.textPrimaryLight),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Text(
                              'If employee worked on Monday, the preceding Sunday is credited as a paid day (Basic + Variable).',
                              style: TextStyle(
                                fontSize: 11,
                                color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
                              ),
                            ),
                          ],
                        ),
                      ),
                      Switch.adaptive(
                        value: _paySundayIfMondayWorked,
                        activeTrackColor: Colors.blue,
                        onChanged: (val) {
                          setState(() {
                            _paySundayIfMondayWorked = val;
                          });
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 12),

                // Clarification Callout
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.amber.withValues(alpha: isDark ? 0.12 : 0.08),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.amber.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    children: [
                      const Icon(Icons.lightbulb_outline_rounded, size: 16, color: Colors.amber),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          'OT rate is strictly calculated from Basic Salary only (Basic / 30 / 8). Variable allowance is excluded from OT rate calculation.',
                          style: TextStyle(
                            fontSize: 11,
                            color: isDark ? Colors.amber[200] : Colors.amber[900],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),

                // Live Calculations Card Preview
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.06),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: AppColors.primary.withValues(alpha: 0.2),
                    ),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(
                            _useCustomMonthlyOt && _customMonthlyOtAmount != null
                                ? 'Monthly Total (Basic + Var + OT)'
                                : 'Monthly Total (Basic + Var)',
                            style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                          ),
                          Text(
                            'AED ${(_monthlyTotal + (_useCustomMonthlyOt && _customMonthlyOtAmount != null ? _customMonthlyOtAmount! : 0.0)).toStringAsFixed(2)}',
                            style: const TextStyle(
                              fontWeight: FontWeight.bold,
                              fontSize: 15,
                              color: AppColors.primary,
                            ),
                          ),
                        ],
                      ),
                      const Divider(height: 16),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          _buildRateItem(
                            label: 'Daily Basic (B/30)',
                            value: 'AED ${_dailyFixedRate.toStringAsFixed(2)}',
                            isDark: isDark,
                          ),
                          _buildRateItem(
                            label: 'Daily Var (V/30)',
                            value: 'AED ${_dailyVariableRate.toStringAsFixed(2)}',
                            isDark: isDark,
                          ),
                          _buildRateItem(
                            label: 'Daily Base',
                            value: 'AED ${_dailyBaseRate.toStringAsFixed(2)}',
                            isDark: isDark,
                          ),
                          _buildRateItem(
                            label: _otIncludedInVariable
                                ? 'Monthly OT'
                                : (_useCustomMonthlyOt && _customMonthlyOtAmount != null
                                    ? 'Monthly OT (Manual)'
                                    : 'Hourly OT (Basic/240)'),
                            value: _otIncludedInVariable
                                ? 'AED 0.00'
                                : (_useCustomMonthlyOt && _customMonthlyOtAmount != null
                                    ? 'AED ${_customMonthlyOtAmount!.toStringAsFixed(2)}'
                                    : 'AED ${_hourlyOtRate.toStringAsFixed(2)}'),
                            isDark: isDark,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 24),

                // Action Buttons
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: _saveSalary,
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: const Text('Save Salary Details'),
                    ),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRateItem({
    required String label,
    required String value,
    required bool isDark,
  }) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          label,
          style: TextStyle(
            fontSize: 10,
            color: isDark ? Colors.grey[400] : AppColors.textSecondaryLight,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          value,
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}

