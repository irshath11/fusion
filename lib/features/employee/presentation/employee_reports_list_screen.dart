import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_theme.dart';
import '../../../core/services/service_report_pdf_service.dart';
import '../../../core/services/supabase_service.dart';
import '../../../database/local_database_service.dart';
import 'employee_report_generator_screen.dart';

class EmployeeReportsListScreen extends StatefulWidget {
  const EmployeeReportsListScreen({super.key});

  @override
  State<EmployeeReportsListScreen> createState() =>
      _EmployeeReportsListScreenState();
}

class _EmployeeReportsListScreenState extends State<EmployeeReportsListScreen> {
  final LocalDatabaseService _db = LocalDatabaseService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allReports = [];
  List<Map<String, dynamic>> _filteredReports = [];
  bool _isLoading = false;

  @override
  void initState() {
    super.initState();
    _loadReports();
    _searchController.addListener(_filterReports);
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  Future<void> _loadReports() async {
    setState(() {
      _isLoading = true;
    });

    // 1. Load local reports first for instant display
    var reports = _db.getAllSavedServiceReports();
    _applyReportsList(reports);

    // 2. Fetch cloud reports from Supabase database & merge into local storage
    try {
      final cloudReports = await SupabaseService().fetchServiceReportsFromSupabase();
      if (cloudReports.isNotEmpty) {
        await _db.mergeCloudServiceReports(cloudReports);
        reports = _db.getAllSavedServiceReports();
        _applyReportsList(reports);
        return;
      }
    } catch (e) {
      debugPrint('Error fetching cloud reports: $e');
    }

    if (mounted) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  void _applyReportsList(List<Map<String, dynamic>> reports) {
    // Sort newest first
    reports.sort((a, b) {
      final String da = a['createdAt'] ?? '';
      final String dbStr = b['createdAt'] ?? '';
      return dbStr.compareTo(da);
    });

    if (mounted) {
      setState(() {
        _allReports = reports;
        _filteredReports = List.from(reports);
        _isLoading = false;
      });
    }
  }

  void _filterReports() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredReports = List.from(_allReports);
      });
      return;
    }

    setState(() {
      _filteredReports = _allReports.where((item) {
        final ref = (item['reportRefNumber'] ?? '').toString().toLowerCase();
        final Map<String, dynamic> data = item['reportData'] != null
            ? Map<String, dynamic>.from(item['reportData'])
            : {};
        final prop = (data['propertyDetails'] ?? '').toString().toLowerCase();
        final job = (data['jobNo'] ?? '').toString().toLowerCase();
        final tech = (data['technicianName'] ?? '').toString().toLowerCase();
        final cust = (data['customerName'] ?? '').toString().toLowerCase();

        return ref.contains(query) ||
            prop.contains(query) ||
            job.contains(query) ||
            tech.contains(query) ||
            cust.contains(query);
      }).toList();
    });
  }

  Future<void> _confirmClearCache() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Row(
          children: [
            Icon(Icons.cleaning_services_rounded, color: Colors.redAccent),
            SizedBox(width: 10),
            Text('Clear Local Reports Cache?'),
          ],
        ),
        content: const Text(
          'Are you sure you want to clear all locally cached service reports from this device?\n\n'
          'Note: Synced reports stored in the cloud database will remain completely safe and can be re-fetched by refreshing.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.redAccent,
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Clear Cache'),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _isLoading = true);
      await _db.clearServiceReportsCache();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Local service reports cache cleared successfully.'),
            backgroundColor: Colors.green,
          ),
        );
      }
      await _loadReports();
    }
  }

  Future<void> _triggerCloudSync() async {
    setState(() => _isLoading = true);
    final synced = await SupabaseService().syncPendingServiceReports();
    await _loadReports();

    if (mounted) {
      if (synced > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully synced $synced report(s) to cloud database.'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Reports are up to date with cloud database.'),
            backgroundColor: Colors.blueAccent,
          ),
        );
      }
    }
  }

  void _previewPdf(ServiceReportData reportData) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final headerColor = AppTheme.currentColors.primaryFor(Theme.of(context).brightness);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        height: MediaQuery.of(context).size.height * 0.9,
        decoration: BoxDecoration(
          color: isDark ? const Color(0xFF1E293B) : Colors.white,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
        ),
        child: Column(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                color: headerColor,
                borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.picture_as_pdf_rounded, color: Colors.white, size: 22),
                      const SizedBox(width: 10),
                      Text(
                        'Report #${reportData.reportRefNumber}',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 17,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                    ],
                  ),
                  IconButton(
                    icon: const Icon(Icons.close_rounded, color: Colors.white),
                    onPressed: () => Navigator.pop(ctx),
                  ),
                ],
              ),
            ),
            Expanded(
              child: PdfPreview(
                build: (format) => ServiceReportPdfService.buildReportPdfBytes(reportData),
                allowPrinting: true,
                allowSharing: true,
                canChangePageFormat: false,
                canChangeOrientation: false,
                maxPageWidth: 700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  void _editReport(ServiceReportData reportData) {
    Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => EmployeeReportGeneratorScreen(existingReport: reportData),
      ),
    ).then((_) => _loadReports());
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppTheme.currentColors.primaryFor(Theme.of(context).brightness);

    return Scaffold(
      appBar: AppBar(
        title: const Row(
          children: [
            Icon(Icons.assignment_turned_in_rounded, color: Colors.white, size: 22),
            SizedBox(width: 10),
            Text(
              'Generated Reports History',
              style: TextStyle(
                color: Colors.white,
                fontSize: 16,
                fontWeight: FontWeight.bold,
              ),
            ),
          ],
        ),
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        elevation: 0,
        actions: [
          IconButton(
            tooltip: 'Clear Local Cache',
            icon: const Icon(Icons.delete_sweep_rounded, color: Colors.white),
            onPressed: _confirmClearCache,
          ),
          IconButton(
            tooltip: 'Sync Reports',
            icon: const Icon(Icons.cloud_upload_rounded, color: Colors.white),
            onPressed: _triggerCloudSync,
          ),
          IconButton(
            tooltip: 'Refresh',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadReports,
          ),
        ],
      ),
      body: Container(
        color: isDark ? const Color(0xFF0F172A) : const Color(0xFFF8FAFC),
        child: Column(
          children: [
            // Search Bar
            Padding(
              padding: const EdgeInsets.all(12),
              child: TextField(
                controller: _searchController,
                decoration: InputDecoration(
                  hintText: 'Search by Ref No, Job No, Property, Technician...',
                  prefixIcon: const Icon(Icons.search_rounded),
                  suffixIcon: _searchController.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear_rounded),
                          onPressed: () => _searchController.clear(),
                        )
                      : null,
                  filled: true,
                  fillColor: isDark ? const Color(0xFF1E293B) : Colors.white,
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(color: isDark ? Colors.white12 : Colors.black12),
                  ),
                ),
              ),
            ),

            // Reports Count Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Reports: ${_filteredReports.length}',
                    style: TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black54,
                    ),
                  ),
                  Text(
                    'Pull to sync or tap sync button',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black38,
                    ),
                  ),
                ],
              ),
            ),

            // List of Reports
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredReports.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.folder_off_rounded,
                                size: 54,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No reports match your search query'
                                    : 'No service reports generated yet',
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : RefreshIndicator(
                          onRefresh: _triggerCloudSync,
                          child: ListView.builder(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                            itemCount: _filteredReports.length,
                            itemBuilder: (context, index) {
                              final item = _filteredReports[index];
                              final refNum = item['reportRefNumber'] ?? 'Unknown';
                              final syncStatus = item['syncStatus'] ?? 'pending';
                              final Map<String, dynamic> rawData = item['reportData'] != null
                                  ? Map<String, dynamic>.from(item['reportData'])
                                  : {};

                              final reportData = ServiceReportData.fromJson(rawData);
                              final createdStr = item['createdAt'] != null
                                  ? DateFormat('dd MMM yyyy, hh:mm a').format(
                                      DateTime.tryParse(item['createdAt']) ?? DateTime.now())
                                  : 'N/A';

                              final isSynced = syncStatus == 'synced';

                              return Card(
                                margin: const EdgeInsets.only(bottom: 12),
                                elevation: 1.5,
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                  side: BorderSide(
                                    color: isDark ? Colors.white10 : Colors.black.withValues(alpha: 0.05),
                                  ),
                                ),
                                color: isDark ? const Color(0xFF1E293B) : Colors.white,
                                child: Padding(
                                  padding: const EdgeInsets.all(14),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      // Top Header Row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                                            decoration: BoxDecoration(
                                              color: AppColors.primary,
                                              borderRadius: BorderRadius.circular(6),
                                            ),
                                            child: Text(
                                              '#$refNum',
                                              style: const TextStyle(
                                                color: Colors.white,
                                                fontWeight: FontWeight.bold,
                                                fontSize: 13,
                                              ),
                                            ),
                                          ),
                                          Container(
                                            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                            decoration: BoxDecoration(
                                              color: isSynced
                                                  ? Colors.green.withValues(alpha: 0.15)
                                                  : Colors.orange.withValues(alpha: 0.15),
                                              borderRadius: BorderRadius.circular(4),
                                              border: Border.all(
                                                color: isSynced ? Colors.green : Colors.orange,
                                                width: 0.8,
                                              ),
                                            ),
                                            child: Row(
                                              children: [
                                                Icon(
                                                  isSynced
                                                      ? Icons.cloud_done_rounded
                                                      : Icons.cloud_upload_rounded,
                                                  size: 13,
                                                  color: isSynced ? Colors.green : Colors.orange,
                                                ),
                                                const SizedBox(width: 4),
                                                Text(
                                                  isSynced ? 'Cloud Synced' : 'Pending Sync',
                                                  style: TextStyle(
                                                    fontSize: 11,
                                                    fontWeight: FontWeight.bold,
                                                    color: isSynced ? Colors.green : Colors.orange,
                                                  ),
                                                ),
                                              ],
                                            ),
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 10),

                                       // Property & Job Details
                                      if (reportData.propertyDetails.isNotEmpty)
                                        Text(
                                          reportData.propertyDetails,
                                          style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 14,
                                            color: isDark ? Colors.white : AppColors.textPrimaryLight,
                                          ),
                                        ),
                                      if (reportData.jobNo.isNotEmpty)
                                        Padding(
                                          padding: const EdgeInsets.only(top: 2),
                                          child: Text(
                                            'Job No: ${reportData.jobNo}',
                                            style: TextStyle(
                                              fontSize: 12,
                                              color: isDark ? Colors.white70 : Colors.black87,
                                            ),
                                          ),
                                        ),

                                      const SizedBox(height: 6),
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                        children: [
                                          Text(
                                            'Created: $createdStr',
                                            style: TextStyle(
                                              fontSize: 11,
                                              color: isDark ? Colors.white60 : Colors.black54,
                                            ),
                                          ),
                                          if (reportData.technicianName.isNotEmpty)
                                            Text(
                                              'Tech: ${reportData.technicianName}',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? AppColors.primaryLight : AppColors.primary,
                                              ),
                                            ),
                                        ],
                                      ),

                                      const Divider(height: 18),

                                      // Actions Row
                                      Row(
                                        mainAxisAlignment: MainAxisAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () => _editReport(reportData),
                                            icon: Icon(
                                              Icons.edit_note_rounded,
                                              size: 18,
                                              color: isDark ? AppColors.primaryLight : AppColors.primary,
                                            ),
                                            label: Text(
                                              'Edit Report',
                                              style: TextStyle(
                                                fontWeight: FontWeight.bold,
                                                color: isDark ? AppColors.primaryLight : AppColors.primary,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                              side: BorderSide(
                                                color: isDark ? AppColors.primaryLight : AppColors.primary,
                                                width: 1.2,
                                              ),
                                            ),
                                          ),
                                          const SizedBox(width: 8),
                                          ElevatedButton.icon(
                                            onPressed: () => _previewPdf(reportData),
                                            icon: const Icon(Icons.picture_as_pdf_rounded, size: 18),
                                            label: const Text('View PDF'),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor: isDark ? AppColors.primaryLight : AppColors.primary,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              );
                            },
                          ),
                        ),
            ),
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const EmployeeReportGeneratorScreen(),
            ),
          ).then((_) => _loadReports());
        },
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_rounded),
        label: const Text('New Report', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
