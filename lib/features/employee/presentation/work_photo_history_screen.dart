import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/work_photo_report_pdf_service.dart';
import '../../../database/local_database_service.dart';
import 'work_photos_report_screen.dart';

class WorkPhotoHistoryScreen extends StatefulWidget {
  const WorkPhotoHistoryScreen({super.key});

  @override
  State<WorkPhotoHistoryScreen> createState() => _WorkPhotoHistoryScreenState();
}

class _WorkPhotoHistoryScreenState extends State<WorkPhotoHistoryScreen> {
  final LocalDatabaseService _db = LocalDatabaseService();
  final TextEditingController _searchController = TextEditingController();
  List<Map<String, dynamic>> _allSubmissions = [];
  List<Map<String, dynamic>> _filteredSubmissions = [];
  bool _isLoading = false;
  bool _isSyncing = false;

  @override
  void initState() {
    super.initState();
    _loadSubmissions();
    _searchController.addListener(_filterSubmissions);
  }

  Future<void> _syncAllPending() async {
    if (_isSyncing) return;
    setState(() => _isSyncing = true);
    try {
      final count = await SupabaseService().syncPendingWorkPhotoSubmissions();
      _loadSubmissions();
      if (!mounted) return;
      if (count > 0) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully synced $count offline report(s) to cloud!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All work photo reports are already synced!'),
            backgroundColor: Colors.blue,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  Future<void> _syncSingleRecord(Map<String, dynamic> item) async {
    final id = item['id']?.toString();
    if (id == null) return;
    
    setState(() => _isSyncing = true);
    try {
      final success = await SupabaseService().syncSingleWorkPhotoSubmission(item);
      _loadSubmissions();
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Successfully synced record "${item['workTitle'] ?? id}" to cloud!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Failed to sync record. Please check your internet connection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Sync error: $e'), backgroundColor: Colors.red),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isSyncing = false);
      }
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _loadSubmissions() {
    setState(() {
      _isLoading = true;
    });

    final records = _db.getSavedWorkPhotoSubmissions();
    
    // Sort newest first
    records.sort((a, b) {
      final String da = a['createdAt'] ?? a['reportDate'] ?? '';
      final String dbStr = b['createdAt'] ?? b['reportDate'] ?? '';
      return dbStr.compareTo(da);
    });

    setState(() {
      _allSubmissions = records;
      _filteredSubmissions = List.from(records);
      _isLoading = false;
    });
  }

  void _filterSubmissions() {
    final query = _searchController.text.trim().toLowerCase();
    if (query.isEmpty) {
      setState(() {
        _filteredSubmissions = List.from(_allSubmissions);
      });
      return;
    }

    setState(() {
      _filteredSubmissions = _allSubmissions.where((item) {
        final title = (item['workTitle'] ?? '').toString().toLowerCase();
        final location = (item['location'] ?? '').toString().toLowerCase();
        final emp = (item['employeeName'] ?? '').toString().toLowerCase();
        final remarks = (item['remarks'] ?? '').toString().toLowerCase();
        return title.contains(query) ||
            location.contains(query) ||
            emp.contains(query) ||
            remarks.contains(query);
      }).toList();
    });
  }

  void _openFullImagePreview(String photoStr, int photoIndex, int totalPhotos) {
    final bool isNetwork = photoStr.startsWith('http://') || photoStr.startsWith('https://');
    Uint8List? bytes;
    if (!isNetwork) {
      final cleanB64 = photoStr.contains(',') ? photoStr.split(',').last : photoStr;
      try {
        bytes = base64Decode(cleanB64.trim());
      } catch (_) {}
    }

    showDialog(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.transparent,
        insetPadding: const EdgeInsets.all(12),
        child: Stack(
          alignment: Alignment.topRight,
          children: [
            Container(
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.9),
                borderRadius: BorderRadius.circular(16),
              ),
              padding: const EdgeInsets.all(12),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    'Photo $photoIndex of $totalPhotos',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  const SizedBox(height: 10),
                  Flexible(
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(12),
                      child: isNetwork
                          ? Image.network(
                              photoStr,
                              fit: BoxFit.contain,
                              loadingBuilder: (_, child, progress) {
                                if (progress == null) return child;
                                return const Center(
                                  child: CircularProgressIndicator(color: Colors.white),
                                );
                              },
                              errorBuilder: (_, __, ___) => const Center(
                                child: Text('Failed to load image from cloud',
                                    style: TextStyle(color: Colors.white70)),
                              ),
                            )
                          : (bytes != null
                              ? Image.memory(bytes, fit: BoxFit.contain)
                              : const Icon(Icons.broken_image, color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: CircleAvatar(
                backgroundColor: Colors.black.withValues(alpha: 0.7),
                child: IconButton(
                  icon: const Icon(Icons.close, color: Colors.white),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _exportPdfReport(Map<String, dynamic> submission) async {
    final reportDate = submission['reportDate'] != null
        ? (DateTime.tryParse(submission['reportDate']) ?? DateTime.now())
        : DateTime.now();

    final data = WorkPhotoReportData(
      reportRefNumber: '',
      reportDate: reportDate,
      workTitle: submission['workTitle'] ?? '',
      location: submission['location'] ?? '',
      employeeName: submission['employeeName'] ?? '',
      remarks: submission['remarks'] ?? '',
      photos: (submission['photos'] as List<dynamic>?)
              ?.map((e) => e.toString())
              .toList() ??
          [],
    );

    final pdfBytes = await WorkPhotoReportPdfService.buildPdfBytes(data);
    final dateStr = DateFormat('yyyyMMdd').format(reportDate);

    await Printing.sharePdf(
      bytes: pdfBytes,
      filename: 'Work_Photos_Report_$dateStr.pdf',
    );
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final primaryColor = AppColors.primary;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'Uploaded Work Photos History',
          style: TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 17),
        ),
        backgroundColor: primaryColor,
        iconTheme: const IconThemeData(color: Colors.white),
        actionsIconTheme: const IconThemeData(color: Colors.white),
        actions: [
          IconButton(
            tooltip: 'Sync Offline Reports',
            icon: _isSyncing
                ? const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                      color: Colors.white,
                      strokeWidth: 2,
                    ),
                  )
                : const Icon(Icons.sync_rounded, color: Colors.white),
            onPressed: _syncAllPending,
          ),
          IconButton(
            tooltip: 'Refresh Records',
            icon: const Icon(Icons.refresh_rounded, color: Colors.white),
            onPressed: _loadSubmissions,
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
                  hintText: 'Search by title, location, or technician...',
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

            // Records Count Banner
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Total Records: ${_filteredSubmissions.length}',
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.bold,
                      color: isDark ? Colors.white70 : Colors.black87,
                    ),
                  ),
                  Text(
                    'Tap any photo to view full image',
                    style: TextStyle(
                      fontSize: 11,
                      color: isDark ? Colors.white38 : Colors.black45,
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 4),

            // Submissions List
            Expanded(
              child: _isLoading
                  ? const Center(child: CircularProgressIndicator())
                  : _filteredSubmissions.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Icon(
                                Icons.photo_library_outlined,
                                size: 54,
                                color: isDark ? Colors.white24 : Colors.black26,
                              ),
                              const SizedBox(height: 12),
                              Text(
                                _searchController.text.isNotEmpty
                                    ? 'No records match your search'
                                    : 'No work photo records uploaded yet',
                                style: TextStyle(
                                  color: isDark ? Colors.white60 : Colors.black54,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                              const SizedBox(height: 16),
                              ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.push(
                                    context,
                                    MaterialPageRoute(
                                      builder: (_) => const WorkPhotosReportScreen(),
                                    ),
                                  ).then((_) => _loadSubmissions());
                                },
                                icon: const Icon(Icons.add_a_photo_rounded),
                                label: const Text('Upload Work Photos'),
                                style: ElevatedButton.styleFrom(
                                  backgroundColor: primaryColor,
                                  foregroundColor: Colors.white,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                          itemCount: _filteredSubmissions.length,
                          itemBuilder: (context, index) {
                            final item = _filteredSubmissions[index];
                            final title = (item['workTitle'] ?? 'Work Photos Record').toString();
                            final location = (item['location'] ?? 'Site Location').toString();
                            final technician = (item['employeeName'] ?? '').toString();
                            final remarks = (item['remarks'] ?? '').toString();
                            final photos = (item['photos'] as List<dynamic>?)
                                    ?.map((e) => e.toString())
                                    .toList() ??
                                [];

                            final syncStatus = (item['syncStatus'] ?? 'pending').toString();
                            final isSynced = syncStatus == 'synced';

                            final reportDate = item['reportDate'] != null
                                ? (DateTime.tryParse(item['reportDate']) ?? DateTime.now())
                                : DateTime.now();
                            final formattedDate =
                                DateFormat('dd MMM yyyy, hh:mm a').format(reportDate);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 14),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
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
                                    // Record Header Row
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title.isNotEmpty ? title : 'Work Photo Record #${index + 1}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: isDark ? Colors.white : Colors.black87,
                                                ),
                                              ),
                                              if (location.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(Icons.location_on_rounded,
                                                        size: 13, color: primaryColor),
                                                    const SizedBox(width: 4),
                                                    Expanded(
                                                      child: Text(
                                                        location,
                                                        style: TextStyle(
                                                          fontSize: 12,
                                                          color: isDark
                                                              ? Colors.white70
                                                              : Colors.black87,
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ],
                                            ],
                                          ),
                                        ),
                                        Column(
                                          crossAxisAlignment: CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: primaryColor.withValues(alpha: 0.12),
                                                borderRadius: BorderRadius.circular(8),
                                              ),
                                              child: Text(
                                                formattedDate,
                                                style: TextStyle(
                                                  fontSize: 11,
                                                  fontWeight: FontWeight.bold,
                                                  color: primaryColor,
                                                ),
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            InkWell(
                                              onTap: isSynced ? null : () => _syncSingleRecord(item),
                                              borderRadius: BorderRadius.circular(6),
                                              child: Container(
                                                padding: const EdgeInsets.symmetric(
                                                    horizontal: 6, vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isSynced
                                                      ? Colors.green.withValues(alpha: 0.15)
                                                      : Colors.orange.withValues(alpha: 0.2),
                                                  borderRadius: BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: isSynced
                                                        ? Colors.green.shade300
                                                        : Colors.orange.shade400,
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize: MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isSynced
                                                          ? Icons.check_circle_rounded
                                                          : Icons.cloud_upload_rounded,
                                                      size: 11,
                                                      color: isSynced
                                                          ? Colors.green.shade700
                                                          : Colors.orange.shade900,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      isSynced ? 'Synced' : 'Sync Now',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight: FontWeight.bold,
                                                        color: isSynced
                                                            ? Colors.green.shade700
                                                            : Colors.orange.shade900,
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            ),
                                          ],
                                        ),
                                      ],
                                    ),

                                    if (technician.isNotEmpty) ...[
                                      const SizedBox(height: 4),
                                      Text(
                                        'Uploaded by: $technician',
                                        style: TextStyle(
                                          fontSize: 11,
                                          fontStyle: FontStyle.italic,
                                          color: isDark ? Colors.white54 : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],

                                    if (remarks.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white.withValues(alpha: 0.04)
                                              : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          remarks,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 12),

                                    // Uploaded Photos Section
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Uploaded Photos (${photos.length}):',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark ? Colors.white70 : Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          'Tap thumbnail to expand',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark ? Colors.white38 : Colors.grey.shade600,
                                          ),
                                        ),
                                      ],
                                    ),
                                    const SizedBox(height: 8),

                                    if (photos.isNotEmpty)
                                      SizedBox(
                                        height: 90,
                                        child: ListView.builder(
                                          scrollDirection: Axis.horizontal,
                                          itemCount: photos.length,
                                          itemBuilder: (ctx, pIdx) {
                                            final photoStr = photos[pIdx];
                                            final bool isNetwork = photoStr.startsWith('http://') ||
                                                photoStr.startsWith('https://');
                                            Uint8List? bytes;
                                            if (!isNetwork) {
                                              final cleanB64 = photoStr.contains(',')
                                                  ? photoStr.split(',').last
                                                  : photoStr;
                                              try {
                                                bytes = base64Decode(cleanB64.trim());
                                              } catch (_) {}
                                            }

                                            return GestureDetector(
                                              onTap: () {
                                                _openFullImagePreview(
                                                    photoStr, pIdx + 1, photos.length);
                                              },
                                              child: Container(
                                                width: 90,
                                                margin: const EdgeInsets.only(right: 8),
                                                decoration: BoxDecoration(
                                                  borderRadius: BorderRadius.circular(8),
                                                  border: Border.all(
                                                    color: isDark
                                                        ? Colors.white24
                                                        : Colors.grey.shade300,
                                                  ),
                                                ),
                                                child: Stack(
                                                  children: [
                                                    Positioned.fill(
                                                      child: ClipRRect(
                                                        borderRadius: BorderRadius.circular(7),
                                                        child: isNetwork
                                                            ? Image.network(
                                                                photoStr,
                                                                fit: BoxFit.cover,
                                                                loadingBuilder: (_, child, progress) {
                                                                  if (progress == null) return child;
                                                                  return const Center(
                                                                    child: SizedBox(
                                                                      width: 18,
                                                                      height: 18,
                                                                      child: CircularProgressIndicator(
                                                                        strokeWidth: 2,
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                                errorBuilder: (_, __, ___) => Container(
                                                                  color: Colors.grey.shade800,
                                                                  child: const Icon(
                                                                    Icons.broken_image,
                                                                    color: Colors.white54,
                                                                  ),
                                                                ),
                                                              )
                                                            : (bytes != null
                                                                ? Image.memory(bytes, fit: BoxFit.cover)
                                                                : Container(
                                                                    color: Colors.grey.shade800,
                                                                    child: const Icon(Icons.image,
                                                                        color: Colors.white),
                                                                  )),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      bottom: 4,
                                                      right: 4,
                                                      child: Container(
                                                        padding: const EdgeInsets.symmetric(
                                                            horizontal: 5, vertical: 1),
                                                        decoration: BoxDecoration(
                                                          color: Colors.black.withValues(alpha: 0.7),
                                                          borderRadius: BorderRadius.circular(4),
                                                        ),
                                                        child: Text(
                                                          '#${pIdx + 1}',
                                                          style: const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 9,
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                        ),
                                                      ),
                                                    ),
                                                  ],
                                                ),
                                              ),
                                            );
                                          },
                                        ),
                                      )
                                    else
                                      Container(
                                        padding: const EdgeInsets.all(12),
                                        decoration: BoxDecoration(
                                          color: isDark ? Colors.white10 : Colors.grey.shade100,
                                          borderRadius: BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.photo_outlined,
                                                size: 16, color: Colors.grey),
                                            SizedBox(width: 8),
                                            Text('No image files attached',
                                                style: TextStyle(
                                                    fontSize: 12, color: Colors.grey)),
                                          ],
                                        ),
                                      ),

                                    const SizedBox(height: 10),

                                    // Action Bar (Export PDF optional)
                                    Row(
                                      mainAxisAlignment: MainAxisAlignment.end,
                                      children: [
                                        TextButton.icon(
                                          onPressed: () => _exportPdfReport(item),
                                          icon: Icon(Icons.picture_as_pdf_rounded,
                                              size: 16, color: primaryColor),
                                          label: Text(
                                            'PDF Report',
                                            style: TextStyle(
                                              color: primaryColor,
                                              fontSize: 12,
                                              fontWeight: FontWeight.bold,
                                            ),
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
          ],
        ),
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => const WorkPhotosReportScreen(),
            ),
          ).then((_) => _loadSubmissions());
        },
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add_a_photo_rounded),
        label: const Text('Upload New Photos', style: TextStyle(fontWeight: FontWeight.bold)),
      ),
    );
  }
}
