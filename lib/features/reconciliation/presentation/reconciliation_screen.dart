import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:intl/intl.dart';
import 'reconciliation_cubit.dart';
import 'reconciliation_state.dart';
import '../domain/expense_bill_entity.dart';
import '../domain/statement_transaction_entity.dart';
import '../services/reconciliation_export_service.dart';
import 'dialogs/add_bill_dialog.dart';
import 'dialogs/scan_statement_dialog.dart';
import 'dialogs/manual_match_dialog.dart';
import 'dialogs/bill_preview_dialog.dart';
import '../../../database/local_database_service.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/theme/app_theme_preset.dart';
import '../../../core/widgets/app_glass_card.dart';

class ReconciliationScreen extends StatefulWidget {
  const ReconciliationScreen({super.key});

  @override
  State<ReconciliationScreen> createState() => _ReconciliationScreenState();
}

class _ReconciliationScreenState extends State<ReconciliationScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  final TextEditingController _searchController = TextEditingController();
  String _billFilter = 'All'; // 'All', 'Matched', 'Unmatched'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchController.dispose();
    super.dispose();
  }

  void _openAddBillDialog(BuildContext context, String currentMonth) async {
    final newBill = await showDialog<ExpenseBillEntity>(
      context: context,
      builder: (ctx) => AddBillDialog(initialCycleMonth: currentMonth),
    );
    if (newBill != null && mounted) {
      context.read<ReconciliationCubit>().addExpenseBill(newBill);
    }
  }

  void _openScanStatementDialog(BuildContext context, String currentMonth) async {
    final items = await showDialog<List<StatementTransactionEntity>>(
      context: context,
      builder: (ctx) => ScanStatementDialog(cycleMonth: currentMonth),
    );
    if (items != null && items.isNotEmpty && mounted) {
      context.read<ReconciliationCubit>().importStatementTransactions(items);
    }
  }

  void _openManualMatchDialog(
    BuildContext context,
    StatementTransactionEntity statement,
    List<ExpenseBillEntity> allBills,
  ) {
    final availableBills = allBills.where((b) => !b.isMatched).toList();
    showDialog(
      context: context,
      builder: (ctx) => ManualMatchDialog(
        statement: statement,
        availableBills: availableBills,
        onMatch: (billId) {
          context.read<ReconciliationCubit>().pairMatch(statement.id, billId);
        },
      ),
    );
  }

  void _exportOptions(BuildContext context, ReconciliationLoaded state) {
    final org = LocalDatabaseService().organization?.name ?? 'Fusion Corporation';

    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.all(20),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Export Reconciliation Report',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Select format to export matched bills and zero-balance status',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 16),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.green.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.table_view_rounded, color: Colors.green),
                  ),
                  title: const Text('Export CSV (Google Sheet / Excel)'),
                  subtitle: const Text('Formatted data table with matched items, amounts & variance', style: TextStyle(fontSize: 11)),
                  onTap: () {
                    Navigator.pop(ctx);
                    final csv = ReconciliationExportService.generateCsv(
                      cycleMonth: state.selectedCycleMonth,
                      transactions: state.transactions,
                      bills: state.bills,
                      organizationName: org,
                    );
                    _showCsvViewer(context, csv, state.selectedCycleMonth);
                  },
                ),
                ListTile(
                  leading: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: Colors.indigo.withValues(alpha: 0.12),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.picture_as_pdf_rounded, color: Colors.indigo),
                  ),
                  title: const Text('Generate PDF Audit Report'),
                  subtitle: const Text('Professional PDF with executive summary & zero-balance seal', style: TextStyle(fontSize: 11)),
                  onTap: () async {
                    Navigator.pop(ctx);
                    await ReconciliationExportService.sharePdfReport(
                      cycleMonth: state.selectedCycleMonth,
                      transactions: state.transactions,
                      bills: state.bills,
                      organizationName: org,
                    );
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  void _showCsvViewer(BuildContext context, String csv, String month) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text('Google Sheets / Excel CSV ($month)'),
        content: SizedBox(
          width: 600,
          height: 350,
          child: SingleChildScrollView(
            child: SelectableText(
              csv,
              style: const TextStyle(fontFamily: 'monospace', fontSize: 11),
            ),
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Close'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return BlocProvider(
      create: (context) => ReconciliationCubit(),
      child: BlocConsumer<ReconciliationCubit, ReconciliationState>(
        listener: (context, state) {
          if (state is ReconciliationLoaded && state.feedbackMessage != null) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.feedbackMessage!),
                backgroundColor: AppTheme.currentColors.primaryLight,
                duration: const Duration(seconds: 3),
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is ReconciliationInitial || state is ReconciliationLoading) {
            return const Center(child: CircularProgressIndicator());
          }

          if (state is! ReconciliationLoaded) {
            return const Center(child: Text('Unable to load reconciliation data.'));
          }

          final summary = state.summary;
          final isDark = Theme.of(context).brightness == Brightness.dark;
          final palette = AppTheme.currentColors;

          return Scaffold(
            body: SingleChildScrollView(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  // Top Header & Month Bar
                  _buildHeader(context, state, isDark, palette),
                  const SizedBox(height: 18),

                  // Hero Zero-Balance Card
                  _buildZeroBalanceHero(context, summary, isDark, palette),
                  const SizedBox(height: 20),

                  // Segmented Tabs Header
                  Container(
                    decoration: BoxDecoration(
                      color: isDark ? Colors.white.withValues(alpha: 0.05) : Colors.grey.withValues(alpha: 0.08),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: TabBar(
                      controller: _tabController,
                      indicatorSize: TabBarIndicatorSize.tab,
                      dividerColor: Colors.transparent,
                      indicator: BoxDecoration(
                        color: palette.primaryLight,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      labelColor: Colors.white,
                      unselectedLabelColor: isDark ? Colors.white70 : Colors.black87,
                      labelStyle: const TextStyle(fontWeight: FontWeight.bold, fontSize: 12),
                      tabs: [
                        Tab(
                          icon: const Icon(Icons.compare_arrows_rounded, size: 18),
                          text: 'Reconciliation (${state.pairs.length})',
                        ),
                        Tab(
                          icon: const Icon(Icons.receipt_long_rounded, size: 18),
                          text: 'Employee Bills (${state.bills.length})',
                        ),
                        Tab(
                          icon: const Icon(Icons.credit_card_rounded, size: 18),
                          text: 'Statement (${state.transactions.length})',
                        ),
                        Tab(
                          icon: const Icon(Icons.warning_amber_rounded, size: 18),
                          text: 'Discrepancies (${summary.unmatchedTransactionsCount + summary.unmatchedBillsCount})',
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 16),

                  // Tab Views Content
                  SizedBox(
                    height: 580,
                    child: TabBarView(
                      controller: _tabController,
                      children: [
                        _buildPairsTab(context, state, isDark, palette),
                        _buildBillsTab(context, state, isDark, palette),
                        _buildStatementTab(context, state, isDark, palette),
                        _buildDiscrepanciesTab(context, state, isDark, palette),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildHeader(
    BuildContext context,
    ReconciliationLoaded state,
    bool isDark,
    AppThemePalette palette,
  ) {
    return Row(
      children: [
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Credit Card & Bills Reconciliation',
                style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                'Validate material receipts against bank statements and ensure zero balance',
                style: TextStyle(fontSize: 13, color: isDark ? Colors.white60 : Colors.black54),
              ),
            ],
          ),
        ),

        // Month Selector
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: isDark ? Colors.white.withValues(alpha: 0.08) : Colors.grey.withValues(alpha: 0.1),
            borderRadius: BorderRadius.circular(12),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.calendar_month_rounded, size: 18, color: Colors.blueAccent),
              const SizedBox(width: 8),
              DropdownButton<String>(
                value: state.selectedCycleMonth,
                underline: const SizedBox.shrink(),
                items: [
                  '2026-10',
                  '2026-09',
                  '2026-08',
                  '2026-07',
                ].map((m) {
                  return DropdownMenuItem(
                    value: m,
                    child: Text(m, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                  );
                }).toList(),
                onChanged: (val) {
                  if (val != null) context.read<ReconciliationCubit>().changeMonth(val);
                },
              ),
            ],
          ),
        ),
        const SizedBox(width: 10),

        // Quick Actions
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: palette.primaryLight,
            foregroundColor: Colors.white,
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.camera_alt_rounded, size: 16),
          label: const Text('Scan Statement', style: TextStyle(fontSize: 12)),
          onPressed: () => _openScanStatementDialog(context, state.selectedCycleMonth),
        ),
        const SizedBox(width: 8),

        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
          ),
          icon: const Icon(Icons.add_rounded, size: 16),
          label: const Text('Add Bill', style: TextStyle(fontSize: 12)),
          onPressed: () => _openAddBillDialog(context, state.selectedCycleMonth),
        ),
        const SizedBox(width: 8),

        IconButton(
          tooltip: 'Smart Auto-Match',
          icon: const Icon(Icons.auto_awesome_rounded, color: Colors.amber),
          onPressed: () => context.read<ReconciliationCubit>().triggerAutoMatch(),
        ),
        IconButton(
          tooltip: 'Export Report',
          icon: const Icon(Icons.file_download_outlined),
          onPressed: () => _exportOptions(context, state),
        ),
        IconButton(
          tooltip: 'Load Sample Data',
          icon: const Icon(Icons.science_outlined),
          onPressed: () => context.read<ReconciliationCubit>().seedDemoData(),
        ),
      ],
    );
  }

  Widget _buildZeroBalanceHero(
    BuildContext context,
    dynamic summary,
    bool isDark,
    AppThemePalette palette,
  ) {
    final isZero = summary.isZeroBalance;
    final variance = summary.variance;

    return AppGlassCard(
      padding: const EdgeInsets.all(20),
      borderRadius: 18,
      child: Column(
        children: [
          Row(
            children: [
              // Badge
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                decoration: BoxDecoration(
                  color: isZero ? Colors.green.withValues(alpha: 0.15) : Colors.amber.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: isZero ? Colors.green : Colors.amber,
                  ),
                ),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(
                      isZero ? Icons.verified_rounded : Icons.warning_amber_rounded,
                      size: 16,
                      color: isZero ? Colors.green : Colors.amber,
                    ),
                    const SizedBox(width: 6),
                    Text(
                      isZero ? 'ZERO BALANCE RECONCILED' : 'RECONCILIATION IN PROGRESS',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: isZero ? Colors.green : Colors.amber,
                      ),
                    ),
                  ],
                ),
              ),
              const Spacer(),
              Text(
                'Reconciled Rate: ${summary.reconciliationRate.toStringAsFixed(1)}%',
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.grey),
              ),
            ],
          ),
          const SizedBox(height: 16),

          // 3 Metric Cards
          Row(
            children: [
              Expanded(
                child: _heroMetricItem(
                  'Credit Card Statement',
                  'AED ${summary.totalStatementAmount.toStringAsFixed(2)}',
                  '${summary.totalTransactionsCount} charges',
                  Icons.credit_card_rounded,
                  Colors.blueAccent,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _heroMetricItem(
                  'Matched Employee Bills',
                  'AED ${summary.matchedBillsAmount.toStringAsFixed(2)}',
                  '${summary.matchedBillsCount} of ${summary.totalBillsCount} receipts',
                  Icons.receipt_long_rounded,
                  Colors.green,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: _heroMetricItem(
                  'Reconciliation Variance',
                  'AED ${variance.abs().toStringAsFixed(2)}',
                  isZero ? 'Zero Balance achieved' : (variance > 0 ? 'AED ${variance.toStringAsFixed(2)} missing bills' : 'Over-matched'),
                  Icons.balance_rounded,
                  isZero ? Colors.green : Colors.redAccent,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _heroMetricItem(
    String title,
    String value,
    String subtitle,
    IconData icon,
    Color color,
  ) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: color.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 16, color: color),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.grey),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 17, fontWeight: FontWeight.bold, color: color),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(fontSize: 11, color: Colors.grey),
          ),
        ],
      ),
    );
  }

  // TAB 1: Pairs & Reconciled rows
  Widget _buildPairsTab(
    BuildContext context,
    ReconciliationLoaded state,
    bool isDark,
    AppThemePalette palette,
  ) {
    final df = DateFormat('yyyy-MM-dd');
    final pairs = state.pairs;

    if (pairs.isEmpty) {
      return _buildEmptyState(
        'No transactions in this statement period.',
        'Use "Scan Statement" or "Load Sample Data" to begin reconciliation.',
      );
    }

    return ListView.separated(
      itemCount: pairs.length,
      separatorBuilder: (_, __) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final pair = pairs[index];
        final s = pair.statement;
        final b = pair.bill;

        return AppGlassCard(
          padding: const EdgeInsets.all(14),
          borderRadius: 14,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              // Statement Line
              Expanded(
                flex: 4,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        const Icon(Icons.credit_card_rounded, size: 14, color: Colors.blueAccent),
                        const SizedBox(width: 6),
                        Text(
                          '${df.format(s.transactionDate)} • *${s.cardLast4}',
                          style: const TextStyle(fontSize: 11, color: Colors.grey),
                        ),
                      ],
                    ),
                    const SizedBox(height: 4),
                    Text(
                      s.description,
                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      'Statement: AED ${s.amount.toStringAsFixed(2)}',
                      style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.blueAccent),
                    ),
                  ],
                ),
              ),

              // Match Indicator Icon
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 10),
                child: Icon(
                  b != null ? Icons.link_rounded : Icons.link_off_rounded,
                  color: b != null ? Colors.green : Colors.amber,
                  size: 24,
                ),
              ),

              // Matched Bill Line
              Expanded(
                flex: 5,
                child: b != null
                    ? InkWell(
                        onTap: () => showDialog(
                          context: context,
                          builder: (ctx) => BillPreviewDialog(bill: b),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                const Icon(Icons.person_rounded, size: 14, color: Colors.green),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${b.employeeName} (${b.vendorName})',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '${b.category} • ${b.materialDescription}',
                              style: const TextStyle(fontSize: 11, color: Colors.grey),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            const SizedBox(height: 2),
                            Text(
                              'Bill Amount: AED ${b.amount.toStringAsFixed(2)}',
                              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600, color: Colors.green),
                            ),
                          ],
                        ),
                      )
                    : Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Row(
                          children: [
                            Icon(Icons.warning_amber_rounded, size: 16, color: Colors.amber),
                            SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                'Missing Receipt / Unmatched Bill',
                                style: TextStyle(fontSize: 12, color: Colors.amber, fontWeight: FontWeight.bold),
                              ),
                            ),
                          ],
                        ),
                      ),
              ),

              // Action (Unlink or Link)
              const SizedBox(width: 10),
              if (b != null)
                IconButton(
                  tooltip: 'Unlink Match',
                  icon: const Icon(Icons.link_off_rounded, color: Colors.redAccent, size: 20),
                  onPressed: () {
                    context.read<ReconciliationCubit>().unpairMatch(s.id);
                  },
                )
              else
                ElevatedButton.icon(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.blueAccent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    visualDensity: VisualDensity.compact,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
                  ),
                  icon: const Icon(Icons.link_rounded, size: 14),
                  label: const Text('Match', style: TextStyle(fontSize: 11)),
                  onPressed: () => _openManualMatchDialog(context, s, state.bills),
                ),
            ],
          ),
        );
      },
    );
  }

  // TAB 2: Employee Bills
  Widget _buildBillsTab(
    BuildContext context,
    ReconciliationLoaded state,
    bool isDark,
    AppThemePalette palette,
  ) {
    final df = DateFormat('yyyy-MM-dd');
    var list = state.bills.where((b) {
      final bMonth = '${b.billDate.year}-${b.billDate.month.toString().padLeft(2, '0')}';
      return bMonth == state.selectedCycleMonth;
    }).toList();

    if (_billFilter == 'Matched') {
      list = list.where((b) => b.isMatched).toList();
    } else if (_billFilter == 'Unmatched') {
      list = list.where((b) => !b.isMatched).toList();
    }

    return Column(
      children: [
        // Filter bar
        Row(
          children: [
            Wrap(
              spacing: 8,
              children: ['All', 'Matched', 'Unmatched'].map((f) {
                final isSelected = _billFilter == f;
                return ChoiceChip(
                  label: Text(f, style: TextStyle(fontSize: 11, color: isSelected ? Colors.white : null)),
                  selected: isSelected,
                  selectedColor: palette.primaryLight,
                  onSelected: (_) => setState(() => _billFilter = f),
                );
              }).toList(),
            ),
            const Spacer(),
            TextButton.icon(
              icon: const Icon(Icons.add_rounded, size: 16),
              label: const Text('Add Employee Bill', style: TextStyle(fontSize: 12)),
              onPressed: () => _openAddBillDialog(context, state.selectedCycleMonth),
            ),
          ],
        ),
        const SizedBox(height: 10),

        Expanded(
          child: list.isEmpty
              ? _buildEmptyState('No employee bills matching filter.', 'Click "Add Employee Bill" to record material receipts.')
              : ListView.separated(
                  itemCount: list.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, index) {
                    final bill = list[index];
                    return AppGlassCard(
                      padding: const EdgeInsets.all(12),
                      borderRadius: 12,
                      child: Row(
                        children: [
                          CircleAvatar(
                            backgroundColor: palette.primaryLight.withValues(alpha: 0.15),
                            child: Icon(Icons.receipt_rounded, color: palette.primaryLight, size: 18),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Text(
                                      bill.vendorName,
                                      style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                                    ),
                                    const SizedBox(width: 8),
                                    Container(
                                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                                      decoration: BoxDecoration(
                                        color: bill.isMatched ? Colors.green.withValues(alpha: 0.12) : Colors.orange.withValues(alpha: 0.12),
                                        borderRadius: BorderRadius.circular(6),
                                      ),
                                      child: Text(
                                        bill.isMatched ? 'MATCHED' : 'UNMATCHED',
                                        style: TextStyle(
                                          color: bill.isMatched ? Colors.green : Colors.orange,
                                          fontSize: 9,
                                          fontWeight: FontWeight.bold,
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  '${bill.employeeName} • ${df.format(bill.billDate)} • ${bill.category}',
                                  style: const TextStyle(fontSize: 11, color: Colors.grey),
                                ),
                                if (bill.materialDescription.isNotEmpty)
                                  Text(
                                    bill.materialDescription,
                                    style: const TextStyle(fontSize: 11),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.end,
                            children: [
                              Text(
                                'AED ${bill.amount.toStringAsFixed(2)}',
                                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                              ),
                              Row(
                                children: [
                                  IconButton(
                                    icon: const Icon(Icons.remove_red_eye_outlined, size: 18, color: Colors.blueAccent),
                                    onPressed: () => showDialog(
                                      context: context,
                                      builder: (ctx) => BillPreviewDialog(bill: bill),
                                    ),
                                  ),
                                  IconButton(
                                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                                    onPressed: () {
                                      context.read<ReconciliationCubit>().deleteExpenseBill(bill.id);
                                    },
                                  ),
                                ],
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  // TAB 3: Statement Lines
  Widget _buildStatementTab(
    BuildContext context,
    ReconciliationLoaded state,
    bool isDark,
    AppThemePalette palette,
  ) {
    final df = DateFormat('yyyy-MM-dd');
    final list = state.transactions;

    if (list.isEmpty) {
      return _buildEmptyState('No card statement transactions imported.', 'Use "Scan Statement" or "Load Sample Data".');
    }

    return ListView.separated(
      itemCount: list.length,
      separatorBuilder: (_, __) => const SizedBox(height: 8),
      itemBuilder: (context, index) {
        final tx = list[index];
        return AppGlassCard(
          padding: const EdgeInsets.all(12),
          borderRadius: 12,
          child: Row(
            children: [
              CircleAvatar(
                backgroundColor: Colors.blueAccent.withValues(alpha: 0.15),
                child: const Icon(Icons.credit_card_rounded, color: Colors.blueAccent, size: 18),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            tx.description,
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                        ),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                          decoration: BoxDecoration(
                            color: tx.isMatched ? Colors.green.withValues(alpha: 0.12) : Colors.redAccent.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(6),
                          ),
                          child: Text(
                            tx.isMatched ? 'RECONCILED' : 'MISSING BILL',
                            style: TextStyle(
                              color: tx.isMatched ? Colors.green : Colors.redAccent,
                              fontSize: 9,
                              fontWeight: FontWeight.bold,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 2),
                    Text(
                      '${df.format(tx.transactionDate)} • Card ending in *${tx.cardLast4}',
                      style: const TextStyle(fontSize: 11, color: Colors.grey),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(
                    'AED ${tx.amount.toStringAsFixed(2)}',
                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                  ),
                  IconButton(
                    icon: const Icon(Icons.delete_outline_rounded, size: 18, color: Colors.redAccent),
                    onPressed: () {
                      context.read<ReconciliationCubit>().deleteStatementTransaction(tx.id);
                    },
                  ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }

  // TAB 4: Discrepancies
  Widget _buildDiscrepanciesTab(
    BuildContext context,
    ReconciliationLoaded state,
    bool isDark,
    AppThemePalette palette,
  ) {
    final df = DateFormat('yyyy-MM-dd');
    final unmatchedTxs = state.transactions.where((t) => !t.isMatched).toList();
    final unmatchedBills = state.bills.where((b) {
      final bMonth = '${b.billDate.year}-${b.billDate.month.toString().padLeft(2, '0')}';
      return bMonth == state.selectedCycleMonth && !b.isMatched;
    }).toList();

    if (unmatchedTxs.isEmpty && unmatchedBills.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.check_circle_outline_rounded, color: Colors.green, size: 54),
            const SizedBox(height: 12),
            const Text(
              'Zero Discrepancies!',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 4),
            const Text(
              'All credit card statement charges match valid employee bills.',
              style: TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ],
        ),
      );
    }

    return ListView(
      children: [
        if (unmatchedTxs.isNotEmpty) ...[
          Text(
            'Missing Employee Receipts (${unmatchedTxs.length})',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.redAccent),
          ),
          const SizedBox(height: 6),
          ...unmatchedTxs.map((tx) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.receipt_long_outlined, color: Colors.redAccent),
                title: Text(tx.description, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('${df.format(tx.transactionDate)} • Card *${tx.cardLast4}'),
                trailing: Text(
                  'AED ${tx.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.redAccent),
                ),
              ),
            );
          }),
          const SizedBox(height: 14),
        ],

        if (unmatchedBills.isNotEmpty) ...[
          Text(
            'Unclaimed Bills Not on Statement (${unmatchedBills.length})',
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.bold, color: Colors.orange),
          ),
          const SizedBox(height: 6),
          ...unmatchedBills.map((bill) {
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: const Icon(Icons.pending_actions_rounded, color: Colors.orange),
                title: Text('${bill.vendorName} (${bill.employeeName})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
                subtitle: Text('${df.format(bill.billDate)} • ${bill.materialDescription}'),
                trailing: Text(
                  'AED ${bill.amount.toStringAsFixed(2)}',
                  style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.orange),
                ),
              ),
            );
          }),
        ],
      ],
    );
  }

  Widget _buildEmptyState(String title, String subtitle) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.grey),
          const SizedBox(height: 12),
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 4),
          Text(subtitle, style: const TextStyle(fontSize: 12, color: Colors.grey)),
        ],
      ),
    );
  }
}
