import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';
import '../../../database/local_database_service.dart';

class AdminEditAttendanceDialog extends StatefulWidget {
  final String employeeId;
  final String employeeName;
  final DateTime date;
  final DateTime? initialCheckIn;
  final DateTime? initialCheckOut;
  final double? initialOtHours;
  final String? initialRemarks;

  const AdminEditAttendanceDialog({
    super.key,
    required this.employeeId,
    required this.employeeName,
    required this.date,
    this.initialCheckIn,
    this.initialCheckOut,
    this.initialOtHours,
    this.initialRemarks,
  });

  static Future<bool?> show(
    BuildContext context, {
    required String employeeId,
    required String employeeName,
    required DateTime date,
    DateTime? initialCheckIn,
    DateTime? initialCheckOut,
    double? initialOtHours,
    String? initialRemarks,
  }) {
    return showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AdminEditAttendanceDialog(
        employeeId: employeeId,
        employeeName: employeeName,
        date: date,
        initialCheckIn: initialCheckIn,
        initialCheckOut: initialCheckOut,
        initialOtHours: initialOtHours,
        initialRemarks: initialRemarks,
      ),
    );
  }

  @override
  State<AdminEditAttendanceDialog> createState() =>
      _AdminEditAttendanceDialogState();
}

class _AdminEditAttendanceDialogState
    extends State<AdminEditAttendanceDialog> {
  late TimeOfDay _checkInTime;
  late TimeOfDay _checkOutTime;
  late TextEditingController _otController;
  late TextEditingController _remarksController;
  bool _isSaving = false;

  @override
  void initState() {
    super.initState();
    final defaultIn = widget.initialCheckIn ??
        DateTime(widget.date.year, widget.date.month, widget.date.day, 8, 0);
    final defaultOut = widget.initialCheckOut ??
        DateTime(widget.date.year, widget.date.month, widget.date.day, 17, 0);

    _checkInTime = TimeOfDay.fromDateTime(defaultIn);
    _checkOutTime = TimeOfDay.fromDateTime(defaultOut);

    _otController = TextEditingController(
      text: widget.initialOtHours != null
          ? widget.initialOtHours!.toStringAsFixed(1)
          : '0.0',
    );
    _remarksController = TextEditingController(
      text: widget.initialRemarks ?? '',
    );
  }

  @override
  void dispose() {
    _otController.dispose();
    _remarksController.dispose();
    super.dispose();
  }

  Future<void> _selectCheckInTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _checkInTime,
    );
    if (picked != null) {
      setState(() => _checkInTime = picked);
    }
  }

  Future<void> _selectCheckOutTime() async {
    final picked = await showTimePicker(
      context: context,
      initialTime: _checkOutTime,
    );
    if (picked != null) {
      setState(() => _checkOutTime = picked);
    }
  }

  void _incrementOt(double delta) {
    final currentStr = _otController.text.trim();
    final current = double.tryParse(currentStr) ?? 0.0;
    final updated = (current + delta).clamp(0.0, 24.0);
    setState(() {
      _otController.text = updated.toStringAsFixed(1);
    });
  }

  void _setOt(double val) {
    setState(() {
      _otController.text = val.toStringAsFixed(1);
    });
  }

  Future<void> _saveAndSync() async {
    final otValStr = _otController.text.trim();
    double parsedOt = 0.0;
    if (otValStr.isNotEmpty) {
      final p = double.tryParse(otValStr);
      if (p == null || p < 0 || p > 24) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Please enter a valid OT hour value (0 to 24)'),
            backgroundColor: AppColors.error,
          ),
        );
        return;
      }
      parsedOt = p;
    }

    final remarksStr = _remarksController.text.trim();

    final fullCheckIn = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      _checkInTime.hour,
      _checkInTime.minute,
    );

    final fullCheckOut = DateTime(
      widget.date.year,
      widget.date.month,
      widget.date.day,
      _checkOutTime.hour,
      _checkOutTime.minute,
    );

    if (fullCheckOut.isBefore(fullCheckIn)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Check-Out time cannot be earlier than Check-In time.'),
          backgroundColor: AppColors.error,
        ),
      );
      return;
    }

    setState(() => _isSaving = true);

    try {
      final db = LocalDatabaseService();
      final adminUser = db.currentUser;
      final adminName = adminUser?.fullName ?? 'Administrator';

      await db.updateOrAddAdminAttendanceOverride(
        employeeId: widget.employeeId,
        employeeName: widget.employeeName,
        date: widget.date,
        checkInTime: fullCheckIn,
        checkOutTime: fullCheckOut,
        manualOvertimeHours: parsedOt,
        remarks: remarksStr.isNotEmpty ? remarksStr : 'Shift adjusted by admin',
        adminName: adminName,
      );

      if (!mounted) return;
      Navigator.pop(context, true);
    } catch (e) {
      if (!mounted) return;
      setState(() => _isSaving = false);
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Error saving attendance override: $e'),
          backgroundColor: AppColors.error,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppTheme.currentColors;
    final primaryColor = palette.primaryFor(Theme.of(context).brightness);

    final formattedDateStr =
        DateFormat('EEEE, dd MMMM yyyy').format(widget.date);

    return AlertDialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? palette.surfaceDark : Colors.white,
      title: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: primaryColor.withValues(alpha: 0.12),
              shape: BoxShape.circle,
            ),
            child: Icon(Icons.edit_calendar_rounded, color: primaryColor),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Adjust Shift & OT',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                Text(
                  '${widget.employeeName} • $formattedDateStr',
                  style: TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.normal,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 8),

            // Time Pickers Row
            Row(
              children: [
                // Check-In Time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Check-In Time',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _isSaving ? null : _selectCheckInTime,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: isDark
                                    ? palette.cardBorderDark
                                    : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                            color: isDark
                                ? palette.surfaceDark
                                : Colors.grey.shade50,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _checkInTime.format(context),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Icon(Icons.access_time_rounded,
                                  size: 16, color: primaryColor),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 12),

                // Check-Out Time
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'Check-Out Time',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold),
                      ),
                      const SizedBox(height: 6),
                      InkWell(
                        onTap: _isSaving ? null : _selectCheckOutTime,
                        borderRadius: BorderRadius.circular(10),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            border: Border.all(
                                color: isDark
                                    ? palette.cardBorderDark
                                    : Colors.grey.shade300),
                            borderRadius: BorderRadius.circular(10),
                            color: isDark
                                ? palette.surfaceDark
                                : Colors.grey.shade50,
                          ),
                          child: Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                _checkOutTime.format(context),
                                style: const TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 13),
                              ),
                              Icon(Icons.access_time_rounded,
                                  size: 16, color: primaryColor),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),

            const SizedBox(height: 16),

            // Overtime (OT) Hours Adjustment Section with Add/Reduce (+/-)
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Overtime (OT) Hours Adjustment',
                  style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                ),
                Builder(
                  builder: (context) {
                    final otVal =
                        double.tryParse(_otController.text.trim()) ?? 0.0;
                    return Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                        color: otVal > 0
                            ? Colors.orange.withValues(alpha: 0.15)
                            : Colors.grey.withValues(alpha: 0.15),
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: otVal > 0
                                ? Colors.orange.shade400
                                : Colors.grey.shade400),
                      ),
                      child: Text(
                        '${otVal.toStringAsFixed(1)}h OT',
                        style: TextStyle(
                          fontSize: 10,
                          fontWeight: FontWeight.bold,
                          color: otVal > 0
                              ? Colors.orange.shade900
                              : Colors.grey.shade700,
                        ),
                      ),
                    );
                  },
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Add / Reduce Stepper Bar
            Row(
              children: [
                // Reduce Buttons (-1h, -0.5h)
                OutlinedButton(
                  onPressed: _isSaving ? null : () => _incrementOt(-1.0),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('-1.0h',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: _isSaving ? null : () => _incrementOt(-0.5),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: Colors.red.shade700,
                    side: BorderSide(color: Colors.red.shade300),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('-0.5h',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 8),

                // Numeric TextField
                Expanded(
                  child: TextField(
                    controller: _otController,
                    enabled: !_isSaving,
                    textAlign: TextAlign.center,
                    keyboardType:
                        const TextInputType.numberWithOptions(decimal: true),
                    onChanged: (_) => setState(() {}),
                    style: const TextStyle(
                        fontWeight: FontWeight.bold, fontSize: 14),
                    decoration: InputDecoration(
                      hintText: '0.0',
                      suffixText: 'hrs',
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 10),
                      border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(10)),
                    ),
                  ),
                ),
                const SizedBox(width: 8),

                // Add Buttons (+0.5h, +1.0h)
                OutlinedButton(
                  onPressed: _isSaving ? null : () => _incrementOt(0.5),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: Colors.green.shade800,
                    side: BorderSide(color: Colors.green.shade400),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('+0.5h',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
                const SizedBox(width: 4),
                OutlinedButton(
                  onPressed: _isSaving ? null : () => _incrementOt(1.0),
                  style: OutlinedButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 8, vertical: 8),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    foregroundColor: Colors.green.shade800,
                    side: BorderSide(color: Colors.green.shade400),
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(8)),
                  ),
                  child: const Text('+1.0h',
                      style:
                          TextStyle(fontSize: 11, fontWeight: FontWeight.bold)),
                ),
              ],
            ),
            const SizedBox(height: 8),

            // Quick Selection Preset Chips
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              child: Row(
                children: [
                  InkWell(
                    onTap: _isSaving ? null : () => _setOt(0.0),
                    borderRadius: BorderRadius.circular(6),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 8, vertical: 4),
                      decoration: BoxDecoration(
                        color: isDark
                            ? palette.surfaceDark
                            : Colors.grey.shade200,
                        borderRadius: BorderRadius.circular(6),
                        border: Border.all(
                            color: isDark
                                ? palette.cardBorderDark
                                : Colors.grey.shade300),
                      ),
                      child: Text('Clear / 0h',
                          style: TextStyle(
                              fontSize: 10,
                              fontWeight: FontWeight.bold,
                              color: isDark
                                  ? AppColors.textSecondaryDark
                                  : Colors.black87)),
                    ),
                  ),
                  const SizedBox(width: 6),
                  ...[1.0, 2.0, 2.5, 3.0, 4.0, 5.0].map((preset) => Padding(
                        padding: const EdgeInsets.only(right: 6.0),
                        child: InkWell(
                          onTap: _isSaving ? null : () => _setOt(preset),
                          borderRadius: BorderRadius.circular(6),
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 8, vertical: 4),
                            decoration: BoxDecoration(
                              color: primaryColor.withValues(alpha: 0.12),
                              borderRadius: BorderRadius.circular(6),
                              border: Border.all(
                                  color: primaryColor.withValues(alpha: 0.3)),
                            ),
                            child: Text('+${preset.toStringAsFixed(1)}h',
                                style: TextStyle(
                                    fontSize: 10,
                                    fontWeight: FontWeight.bold,
                                    color: primaryColor)),
                          ),
                        ),
                      )),
                ],
              ),
            ),
            const SizedBox(height: 16),

            // Remarks Input Field
            const Text(
              'Admin Remarks & Reason',
              style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 6),
            TextField(
              controller: _remarksController,
              enabled: !_isSaving,
              maxLines: 2,
              decoration: InputDecoration(
                hintText:
                    'Enter reason for adjustment (e.g. Approved site overtime by supervisor)',
                hintStyle: TextStyle(
                    fontSize: 12,
                    color: isDark
                        ? AppColors.textSecondaryDark
                        : AppColors.textSecondaryLight),
                prefixIcon: const Icon(Icons.note_alt_rounded, size: 18),
                isDense: true,
                border: OutlineInputBorder(
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          ],
        ),
      ),
      actionsPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      actions: [
        TextButton(
          onPressed: _isSaving ? null : () => Navigator.pop(context, false),
          child: const Text('Cancel'),
        ),
        ElevatedButton.icon(
          onPressed: _isSaving ? null : _saveAndSync,
          style: ElevatedButton.styleFrom(
            backgroundColor: primaryColor,
            foregroundColor: Colors.white,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
          ),
          icon: _isSaving
              ? const SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                      strokeWidth: 2, color: Colors.white),
                )
              : const Icon(Icons.cloud_upload_rounded, size: 18),
          label: Text(_isSaving ? 'Syncing...' : 'Save & Sync DB'),
        ),
      ],
    );
  }
}
