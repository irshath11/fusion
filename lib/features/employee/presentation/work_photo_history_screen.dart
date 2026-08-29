import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:printing/printing.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/services/supabase_service.dart';
import '../../../core/services/work_photo_report_pdf_service.dart';
import '../../../core/utils/image_saver.dart';
import '../../../database/local_database_service.dart';

class WorkPhotoHistoryScreen extends StatefulWidget {
  final String? initialSearchQuery;
  const WorkPhotoHistoryScreen({super.key, this.initialSearchQuery});

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
    if (widget.initialSearchQuery != null &&
        widget.initialSearchQuery!.trim().isNotEmpty) {
      _searchController.text = widget.initialSearchQuery!.trim();
    }
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
            content:
                Text('Successfully synced $count offline report(s) to cloud!'),
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
          SnackBar(
              content: Text('Sync error: $e'), backgroundColor: Colors.red),
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
      final success =
          await SupabaseService().syncSingleWorkPhotoSubmission(item);
      _loadSubmissions();
      if (!mounted) return;
      if (success) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
                'Successfully synced record "${item['workTitle'] ?? id}" to cloud!'),
            backgroundColor: Colors.green,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text(
                'Failed to sync record. Please check your internet connection.'),
            backgroundColor: Colors.red,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Sync error: $e'), backgroundColor: Colors.red),
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
    if (_searchController.text.isNotEmpty) {
      _filterSubmissions();
    }
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

  final Map<String, Uint8List> _base64Cache = {};

  Uint8List? _getOrDecodeBase64(String photoStr) {
    if (_base64Cache.containsKey(photoStr)) {
      return _base64Cache[photoStr];
    }
    final cleanB64 =
        photoStr.contains(',') ? photoStr.split(',').last : photoStr;
    try {
      final decoded = base64Decode(cleanB64.trim());
      _base64Cache[photoStr] = decoded;
      return decoded;
    } catch (_) {
      return null;
    }
  }

  Future<Uint8List?> _fetchOrDecodeImageBytes(String photoStr) async {
    final photoTrim = photoStr.trim();
    if (photoTrim.isEmpty) return null;

    final bool isNetwork =
        photoTrim.startsWith('http://') || photoTrim.startsWith('https://');

    if (!isNetwork) {
      if (photoTrim.startsWith('data:image/') || photoTrim.length > 500) {
        return _getOrDecodeBase64(photoTrim);
      }
      try {
        final file = File(photoTrim);
        if (await file.exists()) {
          return await file.readAsBytes();
        }
      } catch (e) {
        debugPrint('Error checking local file path: $e');
      }
      return _getOrDecodeBase64(photoTrim);
    }
    try {
      final request = await HttpClient().getUrl(Uri.parse(photoTrim));
      final response = await request.close();
      if (response.statusCode == 200) {
        final bytesList =
            await response.fold<List<int>>([], (p, e) => p..addAll(e));
        return Uint8List.fromList(bytesList);
      }
    } catch (e) {
      debugPrint('Error fetching network photo bytes: $e');
    }
    return null;
  }

  String _getPhotoExtension(String photoStr, Uint8List? bytes) {
    if (photoStr.toLowerCase().contains('.png') ||
        photoStr.contains('image/png')) {
      return 'png';
    }
    if (bytes != null && bytes.length >= 4) {
      if (bytes[0] == 0x89 &&
          bytes[1] == 0x50 &&
          bytes[2] == 0x4E &&
          bytes[3] == 0x47) {
        return 'png';
      }
    }
    return 'jpg';
  }

  Future<void> _downloadAllImages(Map<String, dynamic> submission) async {
    final photos = (submission['photos'] as List<dynamic>?)
            ?.map((e) => e.toString())
            .toList() ??
        [];

    if (photos.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('No images found in this record to download.'),
            backgroundColor: Colors.orange,
          ),
        );
      }
      return;
    }

    try {
      final reportDate = submission['reportDate'] != null
          ? (DateTime.tryParse(submission['reportDate'].toString()) ??
              DateTime.now())
          : DateTime.now();
      final dateStr = DateFormat('yyyyMMdd_HHmm').format(reportDate);
      int loadedCount = 0;
      String? lastSavedPath;

      for (int i = 0; i < photos.length; i++) {
        final photoStr = photos[i];
        final bytes = await _fetchOrDecodeImageBytes(photoStr);
        if (bytes != null && bytes.isNotEmpty) {
          final ext = _getPhotoExtension(photoStr, bytes);
          final filename = 'Work_Photo_${dateStr}_${i + 1}.$ext';
          final savedPath = await ImageSaver.saveImageToDevice(bytes, filename);
          if (savedPath != null) {
            loadedCount++;
            lastSavedPath = savedPath;
          }
        }
      }

      if (loadedCount > 0) {
        if (mounted) {
          final isGallery = lastSavedPath != null && lastSavedPath.contains('Pictures');
          final msg = isGallery
              ? 'Successfully saved $loadedCount photo(s) directly to device Gallery ("FusionAttendance" album)!'
              : 'Successfully saved $loadedCount photo(s) to device Downloads / storage!';
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(msg),
              backgroundColor: Colors.green,
              duration: const Duration(seconds: 4),
            ),
          );
        }
      } else {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Could not load image data for download.'),
              backgroundColor: Colors.red,
            ),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error downloading images: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  Future<void> _downloadSinglePhoto(String photoStr) async {
    try {
      final bytes = await _fetchOrDecodeImageBytes(photoStr);
      if (bytes == null || bytes.isEmpty) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
                content: Text('Could not load image bytes to download.'),
                backgroundColor: Colors.orange),
          );
        }
        return;
      }

      final ext = _getPhotoExtension(photoStr, bytes);
      final filename =
          'Work_Photo_${DateTime.now().millisecondsSinceEpoch}.$ext';

      final savedPath = await ImageSaver.saveImageToDevice(bytes, filename);
      if (mounted && savedPath != null) {
        final isGallery = savedPath.contains('Pictures');
        final msg = isGallery
            ? 'Photo saved directly to device Gallery ("FusionAttendance" album)!'
            : (savedPath != 'Downloads'
                ? 'Photo saved directly to $savedPath'
                : 'Photo downloaded automatically to device Downloads folder!');
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(msg), backgroundColor: Colors.green),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
              content: Text('Failed to download photo: $e'),
              backgroundColor: Colors.red),
        );
      }
    }
  }

  void _openFullImagePreview(String photoStr, int photoIndex, int totalPhotos) {
    final bool isNetwork =
        photoStr.startsWith('http://') || photoStr.startsWith('https://');
    Uint8List? bytes;
    if (!isNetwork) {
      bytes = _getOrDecodeBase64(photoStr);
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
                                  child: CircularProgressIndicator(
                                      color: Colors.white),
                                );
                              },
                              errorBuilder: (_, __, ___) => const Center(
                                child: Text('Failed to load image from cloud',
                                    style: TextStyle(color: Colors.white70)),
                              ),
                            )
                          : (bytes != null
                              ? Image.memory(bytes, fit: BoxFit.contain)
                              : const Icon(Icons.broken_image,
                                  color: Colors.white)),
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              top: 8,
              right: 8,
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.7),
                    child: IconButton(
                      tooltip: 'Download Photo',
                      icon: const Icon(Icons.download_rounded,
                          color: Colors.white),
                      onPressed: () => _downloadSinglePhoto(photoStr),
                    ),
                  ),
                  const SizedBox(width: 8),
                  CircleAvatar(
                    backgroundColor: Colors.black.withValues(alpha: 0.7),
                    child: IconButton(
                      icon: const Icon(Icons.close, color: Colors.white),
                      onPressed: () => Navigator.pop(ctx),
                    ),
                  ),
                ],
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

    final pdfBytes = await WorkPhotoReportPdfService.buildPdfBytesAsync(data);
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
        titleSpacing: 0,
        title: const Text(
          'Uploaded Work Photos History',
          style: TextStyle(
              fontWeight: FontWeight.bold, color: Colors.white, fontSize: 16),
          overflow: TextOverflow.ellipsis,
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
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(12),
                    borderSide: BorderSide(
                        color: isDark ? Colors.white12 : Colors.black12),
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
                                  color:
                                      isDark ? Colors.white60 : Colors.black54,
                                  fontSize: 14,
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                        )
                      : ListView.builder(
                          padding: const EdgeInsets.only(
                              left: 12, right: 12, top: 8, bottom: 48),
                          itemCount: _filteredSubmissions.length,
                          itemBuilder: (context, index) {
                            final item = _filteredSubmissions[index];
                            final title =
                                (item['workTitle'] ?? 'Work Photos Record')
                                    .toString();
                            final location =
                                (item['location'] ?? 'Site Location')
                                    .toString();
                            final technician =
                                (item['employeeName'] ?? '').toString();
                            final remarks = (item['remarks'] ?? '').toString();
                            final photos = (item['photos'] as List<dynamic>?)
                                    ?.map((e) => e.toString())
                                    .toList() ??
                                [];

                            final syncStatus =
                                (item['syncStatus'] ?? 'pending').toString();
                            final isSynced = syncStatus == 'synced';

                            final reportDate = item['reportDate'] != null
                                ? (DateTime.tryParse(item['reportDate']) ??
                                    DateTime.now())
                                : DateTime.now();
                            final formattedDate =
                                DateFormat('dd MMM yyyy, hh:mm a')
                                    .format(reportDate);

                            return Card(
                              margin: const EdgeInsets.only(bottom: 14),
                              elevation: 2,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(14),
                                side: BorderSide(
                                  color: isDark
                                      ? Colors.white10
                                      : Colors.black.withValues(alpha: 0.05),
                                ),
                              ),
                              color: isDark
                                  ? const Color(0xFF1E293B)
                                  : Colors.white,
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    // Record Header Row
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      crossAxisAlignment:
                                          CrossAxisAlignment.start,
                                      children: [
                                        Expanded(
                                          child: Column(
                                            crossAxisAlignment:
                                                CrossAxisAlignment.start,
                                            children: [
                                              Text(
                                                title.isNotEmpty
                                                    ? title
                                                    : 'Work Photo Record #${index + 1}',
                                                style: TextStyle(
                                                  fontWeight: FontWeight.bold,
                                                  fontSize: 15,
                                                  color: isDark
                                                      ? Colors.white
                                                      : Colors.black87,
                                                ),
                                              ),
                                              if (location.isNotEmpty) ...[
                                                const SizedBox(height: 2),
                                                Row(
                                                  children: [
                                                    Icon(
                                                      Icons.location_on_rounded,
                                                      size: 13,
                                                      color: isDark
                                                          ? AppColors.primaryLight
                                                          : primaryColor,
                                                    ),
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
                                          crossAxisAlignment:
                                              CrossAxisAlignment.end,
                                          children: [
                                            Container(
                                              padding: const EdgeInsets.symmetric(
                                                  horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(
                                                color: isDark
                                                    ? AppColors.primaryLight
                                                        .withValues(alpha: 0.2)
                                                    : primaryColor.withValues(
                                                        alpha: 0.12),
                                                borderRadius:
                                                    BorderRadius.circular(8),
                                                border: Border.all(
                                                  color: isDark
                                                      ? AppColors.primaryLight
                                                          .withValues(
                                                              alpha: 0.5)
                                                      : primaryColor
                                                          .withValues(
                                                              alpha: 0.3),
                                                  width: 0.8,
                                                ),
                                              ),
                                              child: Row(
                                                mainAxisSize: MainAxisSize.min,
                                                children: [
                                                  Icon(
                                                    Icons.access_time_rounded,
                                                    size: 12,
                                                    color: isDark
                                                        ? AppColors.primaryLight
                                                        : primaryColor,
                                                  ),
                                                  const SizedBox(width: 4),
                                                  Text(
                                                    formattedDate,
                                                    style: TextStyle(
                                                      fontSize: 11,
                                                      fontWeight:
                                                          FontWeight.bold,
                                                      color: isDark
                                                          ? AppColors.primaryLight
                                                          : primaryColor,
                                                    ),
                                                  ),
                                                ],
                                              ),
                                            ),
                                            const SizedBox(height: 4),
                                            InkWell(
                                              onTap: isSynced
                                                  ? null
                                                  : () =>
                                                      _syncSingleRecord(item),
                                              borderRadius:
                                                  BorderRadius.circular(6),
                                              child: Container(
                                                padding:
                                                    const EdgeInsets.symmetric(
                                                        horizontal: 6,
                                                        vertical: 3),
                                                decoration: BoxDecoration(
                                                  color: isSynced
                                                      ? Colors.green.withValues(
                                                          alpha: 0.15)
                                                      : Colors.orange
                                                          .withValues(
                                                              alpha: 0.2),
                                                  borderRadius:
                                                      BorderRadius.circular(6),
                                                  border: Border.all(
                                                    color: isSynced
                                                        ? Colors.green.shade300
                                                        : Colors
                                                            .orange.shade400,
                                                    width: 0.8,
                                                  ),
                                                ),
                                                child: Row(
                                                  mainAxisSize:
                                                      MainAxisSize.min,
                                                  children: [
                                                    Icon(
                                                      isSynced
                                                          ? Icons
                                                              .check_circle_rounded
                                                          : Icons
                                                              .cloud_upload_rounded,
                                                      size: 11,
                                                      color: isSynced
                                                          ? Colors
                                                              .green.shade700
                                                          : Colors
                                                              .orange.shade900,
                                                    ),
                                                    const SizedBox(width: 4),
                                                    Text(
                                                      isSynced
                                                          ? 'Synced'
                                                          : 'Sync Now',
                                                      style: TextStyle(
                                                        fontSize: 10,
                                                        fontWeight:
                                                            FontWeight.bold,
                                                        color: isSynced
                                                          ? Colors.green.shade700
                                                          : Colors.orange
                                                              .shade900,
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
                                          color: isDark
                                              ? Colors.white54
                                              : Colors.grey.shade600,
                                        ),
                                      ),
                                    ],

                                    if (remarks.isNotEmpty) ...[
                                      const SizedBox(height: 6),
                                      Container(
                                        padding: const EdgeInsets.all(8),
                                        decoration: BoxDecoration(
                                          color: isDark
                                              ? Colors.white
                                                  .withValues(alpha: 0.04)
                                              : Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(6),
                                        ),
                                        child: Text(
                                          remarks,
                                          style: TextStyle(
                                            fontSize: 12,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black87,
                                          ),
                                        ),
                                      ),
                                    ],

                                    const SizedBox(height: 12),

                                    // Uploaded Photos Section
                                    Row(
                                      mainAxisAlignment:
                                          MainAxisAlignment.spaceBetween,
                                      children: [
                                        Text(
                                          'Uploaded Photos (${photos.length}):',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.bold,
                                            color: isDark
                                                ? Colors.white70
                                                : Colors.black87,
                                          ),
                                        ),
                                        Text(
                                          'Tap thumbnail to expand',
                                          style: TextStyle(
                                            fontSize: 10,
                                            color: isDark
                                                ? Colors.white38
                                                : Colors.grey.shade600,
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
                                            final bool isNetwork = photoStr
                                                    .startsWith('http://') ||
                                                photoStr.startsWith('https://');
                                            Uint8List? bytes;
                                            if (!isNetwork) {
                                              bytes =
                                                  _getOrDecodeBase64(photoStr);
                                            }

                                            return GestureDetector(
                                              onTap: () {
                                                _openFullImagePreview(photoStr,
                                                    pIdx + 1, photos.length);
                                              },
                                              child: Container(
                                                width: 90,
                                                margin: const EdgeInsets.only(
                                                    right: 8),
                                                decoration: BoxDecoration(
                                                  borderRadius:
                                                      BorderRadius.circular(8),
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
                                                        borderRadius:
                                                            BorderRadius
                                                                .circular(7),
                                                        child: isNetwork
                                                            ? Image.network(
                                                                photoStr,
                                                                fit: BoxFit
                                                                    .cover,
                                                                loadingBuilder: (_,
                                                                    child,
                                                                    progress) {
                                                                  if (progress ==
                                                                      null)
                                                                    return child;
                                                                  return const Center(
                                                                    child:
                                                                        SizedBox(
                                                                      width: 18,
                                                                      height:
                                                                          18,
                                                                      child:
                                                                          CircularProgressIndicator(
                                                                        strokeWidth:
                                                                            2,
                                                                      ),
                                                                    ),
                                                                  );
                                                                },
                                                                errorBuilder: (_,
                                                                        __,
                                                                        ___) =>
                                                                    Container(
                                                                  color: Colors
                                                                      .grey
                                                                      .shade800,
                                                                  child:
                                                                      const Icon(
                                                                    Icons
                                                                        .broken_image,
                                                                    color: Colors
                                                                        .white54,
                                                                  ),
                                                                ),
                                                              )
                                                            : (bytes != null
                                                                ? Image.memory(
                                                                    bytes,
                                                                    fit: BoxFit
                                                                        .cover)
                                                                : Container(
                                                                    color: Colors
                                                                        .grey
                                                                        .shade800,
                                                                    child: const Icon(
                                                                        Icons
                                                                            .image,
                                                                        color: Colors
                                                                            .white),
                                                                  )),
                                                      ),
                                                    ),
                                                    Positioned(
                                                      bottom: 4,
                                                      right: 4,
                                                      child: Container(
                                                        padding:
                                                            const EdgeInsets
                                                                .symmetric(
                                                                horizontal: 5,
                                                                vertical: 1),
                                                        decoration:
                                                            BoxDecoration(
                                                          color: Colors.black
                                                              .withValues(
                                                                  alpha: 0.7),
                                                          borderRadius:
                                                              BorderRadius
                                                                  .circular(4),
                                                        ),
                                                        child: Text(
                                                          '#${pIdx + 1}',
                                                          style:
                                                              const TextStyle(
                                                            color: Colors.white,
                                                            fontSize: 9,
                                                            fontWeight:
                                                                FontWeight.bold,
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
                                          color: isDark
                                              ? Colors.white10
                                              : Colors.grey.shade100,
                                          borderRadius:
                                              BorderRadius.circular(8),
                                        ),
                                        child: const Row(
                                          children: [
                                            Icon(Icons.photo_outlined,
                                                size: 16, color: Colors.grey),
                                            SizedBox(width: 8),
                                            Text('No image files attached',
                                                style: TextStyle(
                                                    fontSize: 12,
                                                    color: Colors.grey)),
                                          ],
                                        ),
                                      ),

                                    const SizedBox(height: 10),

                                    // Action Bar (Download Images & Download PDF Report)
                                    Align(
                                      alignment: Alignment.centerRight,
                                      child: Wrap(
                                        spacing: 6,
                                        runSpacing: 6,
                                        alignment: WrapAlignment.end,
                                        children: [
                                          OutlinedButton.icon(
                                            onPressed: () =>
                                                _downloadAllImages(item),
                                            icon: Icon(
                                              Icons.photo_library_rounded,
                                              size: 14,
                                              color: isDark
                                                  ? AppColors.primaryLight
                                                  : primaryColor,
                                            ),
                                            label: Text(
                                              'Download Images',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                                color: isDark
                                                    ? AppColors.primaryLight
                                                    : primaryColor,
                                              ),
                                            ),
                                            style: OutlinedButton.styleFrom(
                                              foregroundColor: isDark
                                                  ? AppColors.primaryLight
                                                  : primaryColor,
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 8, vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                              side: BorderSide(
                                                color: isDark
                                                    ? AppColors.primaryLight
                                                    : primaryColor,
                                                width: 1.0,
                                              ),
                                            ),
                                          ),
                                          ElevatedButton.icon(
                                            onPressed: () =>
                                                _exportPdfReport(item),
                                            icon: const Icon(
                                                Icons.picture_as_pdf_rounded,
                                                size: 14),
                                            label: const Text(
                                              'Download PDF',
                                              style: TextStyle(
                                                fontSize: 11,
                                                fontWeight: FontWeight.bold,
                                              ),
                                            ),
                                            style: ElevatedButton.styleFrom(
                                              backgroundColor:
                                                  Colors.red.shade700,
                                              foregroundColor: Colors.white,
                                              padding: const EdgeInsets
                                                  .symmetric(
                                                  horizontal: 8, vertical: 4),
                                              minimumSize: Size.zero,
                                              tapTargetSize:
                                                  MaterialTapTargetSize
                                                      .shrinkWrap,
                                            ),
                                          ),
                                        ],
                                      ),
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
    );
  }
}
