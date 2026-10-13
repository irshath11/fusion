import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:intl/intl.dart';
import 'package:uuid/uuid.dart';
import 'package:attendance_app/features/reconciliation/domain/statement_transaction_entity.dart';
import 'package:attendance_app/features/reconciliation/services/statement_ai_scanner_service.dart';
import 'package:attendance_app/core/constants/app_theme.dart';

class ScanStatementDialog extends StatefulWidget {
  final String cycleMonth;
  const ScanStatementDialog({super.key, required this.cycleMonth});

  @override
  State<ScanStatementDialog> createState() => _ScanStatementDialogState();
}

class _ScanStatementDialogState extends State<ScanStatementDialog> {
  Uint8List? _scannedImageBytes;
  bool _isScanning = false;
  String _scanStatusText = '';
  final List<StatementTransactionEntity> _parsedItems = [];

  Future<void> _captureOrUpload(ImageSource source) async {
    final file = await StatementAiScannerService.pickStatementImage(source: source);
    if (file == null) return;

    final bytes = await file.readAsBytes();
    setState(() {
      _scannedImageBytes = bytes;
      _isScanning = true;
      _scanStatusText = 'Gemini AI Vision analyzing statement lines...';
    });

    try {
      final items = await StatementAiScannerService.parseStatementImage(
        imageBytes: bytes,
        cycleMonth: widget.cycleMonth,
      );

      setState(() {
        _parsedItems.clear();
        _parsedItems.addAll(items);
        _isScanning = false;
        _scanStatusText = '${items.length} transaction lines detected.';
      });
    } catch (e) {
      setState(() {
        _isScanning = false;
        _scanStatusText = 'Error parsing image: $e';
      });
    }
  }

  void _addNewManualLine() {
    final now = DateTime.now();
    setState(() {
      _parsedItems.add(
        StatementTransactionEntity(
          id: const Uuid().v4(),
          cycleMonth: widget.cycleMonth,
          transactionDate: now,
          description: 'New Card Purchase',
          amount: 100.00,
          cardLast4: '4129',
          createdAt: now,
        ),
      );
    });
  }

  void _confirmAndImport() {
    if (_parsedItems.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('No transactions to import. Please scan or add lines.')),
      );
      return;
    }
    Navigator.of(context).pop(_parsedItems);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final palette = AppTheme.currentColors;
    final df = DateFormat('yyyy-MM-dd');

    return Dialog(
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      backgroundColor: isDark ? palette.surfaceDark : Colors.white,
      child: Container(
        constraints: const BoxConstraints(maxWidth: 680, maxHeight: 760),
        padding: const EdgeInsets.all(24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: Colors.blueAccent.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: const Icon(Icons.document_scanner_rounded, color: Colors.blueAccent, size: 24),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Import Card Statement (${widget.cycleMonth})',
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      ),
                      Text(
                        'Capture via camera or upload scanned copy for AI OCR parsing',
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

            // Capture / Upload Buttons
            Row(
              children: [
                Expanded(
                  child: ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: palette.primaryLight,
                      foregroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.camera_alt_rounded, size: 18),
                    label: const Text('Capture via Camera'),
                    onPressed: _isScanning ? null : () => _captureOrUpload(ImageSource.camera),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    style: OutlinedButton.styleFrom(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                    ),
                    icon: const Icon(Icons.upload_file_rounded, size: 18),
                    label: const Text('Upload Scanned Copy'),
                    onPressed: _isScanning ? null : () => _captureOrUpload(ImageSource.gallery),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),

            // Thumbnail preview if an image was picked
            if (_scannedImageBytes != null)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    ClipRRect(
                      borderRadius: BorderRadius.circular(6),
                      child: Image.memory(
                        _scannedImageBytes!,
                        width: 48,
                        height: 48,
                        fit: BoxFit.cover,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'Statement image captured',
                            style: TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                          ),
                          Text(
                            _isScanning ? 'Extracting purchase line items...' : 'Image loaded & parsed',
                            style: const TextStyle(fontSize: 11, color: Colors.grey),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),

            // Scanning Status Banner
            if (_isScanning)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueAccent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.blueAccent.withValues(alpha: 0.3)),
                ),
                child: Row(
                  children: [
                    const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        _scanStatusText,
                        style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
                      ),
                    ),
                  ],
                ),
              )
            else if (_scanStatusText.isNotEmpty)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.green.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Row(
                  children: [
                    const Icon(Icons.check_circle_rounded, color: Colors.green, size: 16),
                    const SizedBox(width: 8),
                    Text(
                      _scanStatusText,
                      style: const TextStyle(fontSize: 12, color: Colors.green, fontWeight: FontWeight.w600),
                    ),
                  ],
                ),
              ),

            // Review & Edit Table
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  'Extracted Transactions (${_parsedItems.length})',
                  style: const TextStyle(fontSize: 14, fontWeight: FontWeight.bold),
                ),
                TextButton.icon(
                  icon: const Icon(Icons.add_circle_outline_rounded, size: 16),
                  label: const Text('Add Row Manually', style: TextStyle(fontSize: 12)),
                  onPressed: _addNewManualLine,
                ),
              ],
            ),
            const SizedBox(height: 8),

            Expanded(
              child: _parsedItems.isEmpty
                  ? Center(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(
                            Icons.receipt_long_outlined,
                            size: 48,
                            color: isDark ? Colors.white24 : Colors.black26,
                          ),
                          const SizedBox(height: 12),
                          const Text(
                            'No statement transactions detected yet.',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          const SizedBox(height: 4),
                          const Text(
                            'Take a photo of the printed statement or click "Add Row Manually".',
                            style: TextStyle(fontSize: 12, color: Colors.grey),
                          ),
                        ],
                      ),
                    )
                  : ListView.separated(
                      itemCount: _parsedItems.length,
                      separatorBuilder: (_, __) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final tx = _parsedItems[index];
                        return ListTile(
                          contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                          leading: CircleAvatar(
                            backgroundColor: palette.primaryLight.withValues(alpha: 0.12),
                            radius: 16,
                            child: Text(
                              '${index + 1}',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.bold,
                                color: palette.primaryLight,
                              ),
                            ),
                          ),
                          title: Row(
                            children: [
                              Expanded(
                                flex: 3,
                                child: TextFormField(
                                  initialValue: tx.description,
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    hintText: 'Merchant Name',
                                  ),
                                  style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                  onChanged: (val) {
                                    _parsedItems[index] = tx.copyWith(description: val.trim());
                                  },
                                ),
                              ),
                              const SizedBox(width: 8),
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  initialValue: tx.amount.toStringAsFixed(2),
                                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                                  decoration: const InputDecoration(
                                    isDense: true,
                                    border: InputBorder.none,
                                    prefixText: 'AED ',
                                  ),
                                  style: const TextStyle(
                                    fontSize: 13,
                                    fontWeight: FontWeight.bold,
                                    color: Colors.green,
                                  ),
                                  onChanged: (val) {
                                    final amt = double.tryParse(val.trim()) ?? tx.amount;
                                    _parsedItems[index] = tx.copyWith(amount: amt);
                                  },
                                ),
                              ),
                            ],
                          ),
                          subtitle: Row(
                            children: [
                              InkWell(
                                onTap: () async {
                                  final picked = await showDatePicker(
                                    context: context,
                                    initialDate: tx.transactionDate,
                                    firstDate: DateTime(2020),
                                    lastDate: DateTime.now().add(const Duration(days: 30)),
                                  );
                                  if (picked != null) {
                                    setState(() {
                                      _parsedItems[index] = tx.copyWith(transactionDate: picked);
                                    });
                                  }
                                },
                                child: Row(
                                  children: [
                                    const Icon(Icons.calendar_today_rounded, size: 12, color: Colors.grey),
                                    const SizedBox(width: 4),
                                    Text(
                                      df.format(tx.transactionDate),
                                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                                    ),
                                  ],
                                ),
                              ),
                              const SizedBox(width: 14),
                              Text(
                                'Card: *${tx.cardLast4}',
                                style: const TextStyle(fontSize: 11, color: Colors.grey),
                              ),
                            ],
                          ),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                            onPressed: () {
                              setState(() => _parsedItems.removeAt(index));
                            },
                          ),
                        );
                      },
                    ),
            ),
            const SizedBox(height: 16),

            // Action Buttons
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                if (_parsedItems.isNotEmpty)
                  Text(
                    'Total: AED ${_parsedItems.fold(0.0, (acc, item) => acc + item.amount).toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  )
                else
                  const SizedBox.shrink(),
                Row(
                  children: [
                    TextButton(
                      onPressed: () => Navigator.pop(context),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: Colors.green,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      icon: const Icon(Icons.check_rounded, size: 18),
                      label: Text('Import ${_parsedItems.length} Lines'),
                      onPressed: _parsedItems.isEmpty ? null : _confirmAndImport,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
