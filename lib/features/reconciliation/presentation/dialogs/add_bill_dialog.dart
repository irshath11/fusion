import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:attendance_app/database/local_database_service.dart';
import 'package:attendance_app/features/reconciliation/domain/expense_bill_entity.dart';
import 'package:attendance_app/core/constants/app_theme.dart';

class AddBillDialog extends StatefulWidget {
  final String? initialCycleMonth;
  const AddBillDialog({super.key, this.initialCycleMonth});

  @override
  State<AddBillDialog> createState() => _AddBillDialogState();
}

class _AddBillDialogState extends State<AddBillDialog> {
  final _formKey = GlobalKey<FormState>();
  final _vendorController = TextEditingController();
  final _invoiceController = TextEditingController();
  final _amountController = TextEditingController();
  final _cardLast4Controller = TextEditingController(text: '4129');
  final _materialController = TextEditingController();

  DateTime _selectedDate = DateTime.now();
  String? _selectedEmployeeId;
  String _selectedEmployeeName = '';
  String _selectedCategory = 'Material Purchase';
  String? _receiptImageBase64;
  bool _isAttachingImage = false;

  final List<String> _categories = const [
    'Material Purchase',
    'Tools & Hardware',
    'Electricals & Cabling',
    'Plumbing & Pipes',
    'Site Consumables',
    'Safety & PPE',
    'Vehicle Fuel & Travel',
    'General Office Supplies',
    'Other',
  ];

  @override
  void initState() {
    super.initState();
    final employees = LocalDatabaseService().getEmployees();
    if (employees.isNotEmpty) {
      _selectedEmployeeId = employees.first.id;
      _selectedEmployeeName = employees.first.name;
    }
  }

  @override
  void dispose() {
    _vendorController.dispose();
    _invoiceController.dispose();
    _amountController.dispose();
    _cardLast4Controller.dispose();
    _materialController.dispose();
    super.dispose();
  }

  Future<void> _pickReceipt(ImageSource source) async {
    setState(() => _isAttachingImage = true);
    try {
      final picker = ImagePicker();
      final XFile? file = await picker.pickImage(
        source: source,
        maxWidth: 1000,
        maxHeight: 1000,
        imageQuality: 75,
      );
      if (file != null) {
        final bytes = await file.readAsBytes();
        setState(() {
          _receiptImageBase64 = base64Encode(bytes);
        });
      }
    } catch (e) {
      debugPrint('Error picking receipt image: $e');
    } finally {
      setState(() => _isAttachingImage = false);
    }
  }

  void _saveBill() {
    if (!_formKey.currentState!.validate()) return;
    if (_selectedEmployeeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select an employee.')),
      );
      return;
    }

    final amount = double.tryParse(_amountController.text.trim()) ?? 0.0;
    if (amount <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please enter a valid bill amount greater than 0.')),
      );
      return;
    }

    final newBill = ExpenseBillEntity(
      id: const Uuid().v4(),
      employeeId: _selectedEmployeeId!,
      employeeName: _selectedEmployeeName,
      vendorName: _vendorController.text.trim(),
      invoiceNumber: _invoiceController.text.trim(),
      amount: amount,
      billDate: _selectedDate,
      cardLast4: _cardLast4Controller.text.trim().isNotEmpty
          ? _cardLast4Controller.text.trim()
          : '4129',
      category: _selectedCategory,
      materialDescription: _materialController.text.trim(),
      receiptImageBase64: _receiptImageBase64,
      createdAt: DateTime.now(),
    );

    Navigator.of(context).pop(newBill);
  }

  InputDecoration _inputDeco(String label, IconData icon, {String? hint, String? prefixText}) {
    return InputDecoration(
      labelText: label,
      hintText: hint,
      prefixText: prefixText,
      prefixIcon: Icon(icon, size: 20),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
    );
  }

  @override
  Widget build(BuildContext context) {
    final employees = LocalDatabaseService().getEmployees();
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppTheme.currentColors;

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? palette.surfaceDark : Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 550, maxHeight: 720),
        padding: const EdgeInsets.all(24),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: palette.primaryLight.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.receipt_long_rounded, color: palette.primaryLight, size: 24),
                  ),
                  const SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Add Employee Bill',
                          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                        ),
                        Text(
                          'Record material purchase bill paid by company card',
                          style: TextStyle(
                            fontSize: 12,
                            color: isDark ? Colors.white60 : Colors.black54,
                          ),
                        ),
                      ],
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded),
                    onPressed: () => Navigator.pop(context),
                  ),
                ],
              ),
              const Divider(height: 24),

              // Scrollable Form Fields
              Expanded(
                child: SingleChildScrollView(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Employee Dropdown
                      const Text(
                        'Purchased By (Employee) *',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 6),
                      DropdownButtonFormField<String>(
                        initialValue: _selectedEmployeeId,
                        decoration: InputDecoration(
                          prefixIcon: const Icon(Icons.person_rounded, size: 20),
                          contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                          border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                        ),
                        items: employees.map((emp) {
                          return DropdownMenuItem<String>(
                            value: emp.id,
                            child: Text('${emp.name} (${emp.designation})'),
                          );
                        }).toList(),
                        onChanged: (val) {
                          if (val != null) {
                            setState(() {
                              _selectedEmployeeId = val;
                              final emp = employees.firstWhere((e) => e.id == val);
                              _selectedEmployeeName = emp.name;
                            });
                          }
                        },
                      ),
                      const SizedBox(height: 16),

                      // Vendor Name & Bill/Invoice No
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _vendorController,
                              decoration: _inputDeco('Vendor / Store *', Icons.store_mall_directory_rounded),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _invoiceController,
                              decoration: _inputDeco('Bill / Inv #', Icons.tag_rounded),
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Amount & Card Last 4 Digits
                      Row(
                        children: [
                          Expanded(
                            flex: 3,
                            child: TextFormField(
                              controller: _amountController,
                              decoration: _inputDeco('Bill Amount *', Icons.attach_money_rounded, prefixText: 'AED '),
                              keyboardType: const TextInputType.numberWithOptions(decimal: true),
                              validator: (val) => val == null || val.trim().isEmpty ? 'Required' : null,
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            flex: 2,
                            child: TextFormField(
                              controller: _cardLast4Controller,
                              decoration: _inputDeco('Card (Last 4)', Icons.credit_card_rounded),
                              keyboardType: TextInputType.number,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Purchase Date & Category
                      Row(
                        children: [
                          Expanded(
                            child: InkWell(
                              borderRadius: BorderRadius.circular(12),
                              onTap: () async {
                                final picked = await showDatePicker(
                                  context: context,
                                  initialDate: _selectedDate,
                                  firstDate: DateTime(2020),
                                  lastDate: DateTime.now().add(const Duration(days: 30)),
                                );
                                if (picked != null) {
                                  setState(() => _selectedDate = picked);
                                }
                              },
                              child: Container(
                                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
                                decoration: BoxDecoration(
                                  border: Border.all(color: Colors.grey.withValues(alpha: 0.4)),
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 18),
                                    const SizedBox(width: 8),
                                    Text(
                                      DateFormat('yyyy-MM-dd').format(_selectedDate),
                                      style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _selectedCategory,
                              decoration: InputDecoration(
                                contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 12),
                                border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                              ),
                              items: _categories.map((c) {
                                return DropdownMenuItem<String>(
                                  value: c,
                                  child: Text(c, style: const TextStyle(fontSize: 13)),
                                );
                              }).toList(),
                              onChanged: (val) {
                                if (val != null) setState(() => _selectedCategory = val);
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 16),

                      // Material Details / Description
                      TextFormField(
                        controller: _materialController,
                        maxLines: 2,
                        decoration: _inputDeco('Material Details / Purchased Items', Icons.construction_rounded),
                      ),
                      const SizedBox(height: 16),

                      // Receipt Photo Attachment
                      const Text(
                        'Bill Receipt Photo',
                        style: TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 8),
                      if (_receiptImageBase64 != null)
                        Stack(
                          children: [
                            Container(
                              height: 110,
                              width: double.infinity,
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(12),
                                image: DecorationImage(
                                  image: MemoryImage(base64Decode(_receiptImageBase64!)),
                                  fit: BoxFit.cover,
                                ),
                              ),
                            ),
                            Positioned(
                              top: 6,
                              right: 6,
                              child: CircleAvatar(
                                backgroundColor: Colors.black54,
                                radius: 14,
                                child: IconButton(
                                  padding: EdgeInsets.zero,
                                  icon: const Icon(Icons.close, size: 16, color: Colors.white),
                                  onPressed: () => setState(() => _receiptImageBase64 = null),
                                ),
                              ),
                            ),
                          ],
                        )
                      else
                        Row(
                          children: [
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.camera_alt_rounded, size: 18),
                                label: const Text('Capture Camera', style: TextStyle(fontSize: 12)),
                                onPressed: _isAttachingImage ? null : () => _pickReceipt(ImageSource.camera),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: OutlinedButton.icon(
                                icon: const Icon(Icons.photo_library_rounded, size: 18),
                                label: const Text('Gallery Upload', style: TextStyle(fontSize: 12)),
                                onPressed: _isAttachingImage ? null : () => _pickReceipt(ImageSource.gallery),
                              ),
                            ),
                          ],
                        ),
                    ],
                  ),
                ),
              ),

              const SizedBox(height: 16),
              // Action Buttons
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  TextButton(
                    onPressed: () => Navigator.pop(context),
                    child: const Text('Cancel'),
                  ),
                  const SizedBox(width: 12),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primaryLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.check_rounded, size: 18),
                    label: const Text('Save Bill'),
                    onPressed: _saveBill,
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
