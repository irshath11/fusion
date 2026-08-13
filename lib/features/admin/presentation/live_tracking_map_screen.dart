import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../../core/constants/app_colors.dart';
import '../../../core/constants/app_enums.dart';
import '../../../database/local_database_service.dart';
import '../../admin/domain/office_entity.dart';
import '../../admin/domain/work_site_entity.dart';
import '../../attendance/domain/attendance_record.dart';

class LiveTrackingMapScreen extends StatefulWidget {
  const LiveTrackingMapScreen({super.key});

  @override
  State<LiveTrackingMapScreen> createState() => _LiveTrackingMapScreenState();
}

class _LiveTrackingMapScreenState extends State<LiveTrackingMapScreen> {
  final MapController _mapController = MapController();
  final LocalDatabaseService _db = LocalDatabaseService();

  String _filterRole = 'All'; // 'All', 'Offices', 'Employees', 'WorkSites'
  bool _isSatellite = false;
  LatLng _centerPoint =
      const LatLng(24.365500, 54.500531); // Default Abu Dhabi / Musaffah

  @override
  void initState() {
    super.initState();
    _calculateInitialCenter();
  }

  void _calculateInitialCenter() {
    final offices = _db.getOffices();
    if (offices.isNotEmpty) {
      _centerPoint = LatLng(offices.first.latitude, offices.first.longitude);
    }
  }

  void _recenterMap() {
    _mapController.move(_centerPoint, 12.0);
  }

  void _zoomIn() {
    _mapController.move(
        _mapController.camera.center, _mapController.camera.zoom + 1);
  }

  void _zoomOut() {
    _mapController.move(
        _mapController.camera.center, _mapController.camera.zoom - 1);
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final offices = _db.getOffices();
    final workSites = _db.getWorkSites();
    final records = _db.getAttendanceRecords();

    // Map today's latest record for each active employee
    final Map<String, AttendanceRecord> latestEmployeeRecords = {};
    for (final r in records) {
      final key = r.employeeId.isNotEmpty ? r.employeeId : r.employeeName;
      if (!latestEmployeeRecords.containsKey(key) ||
          r.eventTimestamp
              .isAfter(latestEmployeeRecords[key]!.eventTimestamp)) {
        latestEmployeeRecords[key] = r;
      }
    }

    // Build Office Geofence Circles
    final List<CircleMarker> geofenceCircles = [];
    if (_filterRole == 'All' || _filterRole == 'Offices') {
      for (final office in offices) {
        geofenceCircles.add(
          CircleMarker(
            point: LatLng(office.latitude, office.longitude),
            radius: office.geofenceRadiusMeters,
            useRadiusInMeter: true,
            color: AppColors.primary.withValues(alpha: 0.15),
            borderColor: AppColors.primary,
            borderStrokeWidth: 2,
          ),
        );
      }
    }

    // Build Map Markers
    final List<Marker> markers = [];

    // 1. Office Markers
    if (_filterRole == 'All' || _filterRole == 'Offices') {
      for (final office in offices) {
        markers.add(
          Marker(
            point: LatLng(office.latitude, office.longitude),
            width: 50,
            height: 50,
            child: GestureDetector(
              onTap: () => _showOfficeDetails(office),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: AppColors.primary,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6),
                      ],
                    ),
                    child: const Icon(Icons.business_rounded,
                        color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    // 2. WorkSite Markers
    if (_filterRole == 'All' || _filterRole == 'WorkSites') {
      for (final site in workSites) {
        markers.add(
          Marker(
            point: LatLng(site.latitude, site.longitude),
            width: 50,
            height: 50,
            child: GestureDetector(
              onTap: () => _showWorkSiteDetails(site),
              child: Column(
                children: [
                  Container(
                    padding: const EdgeInsets.all(6),
                    decoration: BoxDecoration(
                      color: Colors.orange.shade700,
                      shape: BoxShape.circle,
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.3),
                            blurRadius: 6),
                      ],
                    ),
                    child: const Icon(Icons.location_on_rounded,
                        color: Colors.white, size: 20),
                  ),
                ],
              ),
            ),
          ),
        );
      }
    }

    // 3. Employee Markers
    if (_filterRole == 'All' || _filterRole == 'Employees') {
      latestEmployeeRecords.forEach((empKey, record) {
        markers.add(
          Marker(
            point: LatLng(record.latitude, record.longitude),
            width: 60,
            height: 60,
            child: GestureDetector(
              onTap: () => _showEmployeeDetails(record),
              child: Column(
                children: [
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: AppColors.success,
                      borderRadius: BorderRadius.circular(8),
                      boxShadow: [
                        BoxShadow(
                            color: Colors.black.withValues(alpha: 0.2),
                            blurRadius: 4),
                      ],
                    ),
                    child: Text(
                      record.employeeName.split(' ').first,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 10,
                        fontWeight: FontWeight.bold,
                      ),
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Container(
                    padding: const EdgeInsets.all(4),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      shape: BoxShape.circle,
                      border: Border.all(color: AppColors.success, width: 2),
                    ),
                    child: const Icon(Icons.person_pin_circle_rounded,
                        color: AppColors.success, size: 20),
                  ),
                ],
              ),
            ),
          ),
        );
      });
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Live Field Workforce Map'),
        actions: [
          IconButton(
            icon: Icon(
                _isSatellite ? Icons.map_rounded : Icons.satellite_alt_rounded),
            tooltip:
                _isSatellite ? 'Switch to Standard Map' : 'Switch to Dark Map',
            onPressed: () {
              setState(() => _isSatellite = !_isSatellite);
            },
          ),
          IconButton(
            icon: const Icon(Icons.center_focus_strong_rounded),
            tooltip: 'Recenter Map',
            onPressed: _recenterMap,
          ),
        ],
      ),
      body: Stack(
        children: [
          FlutterMap(
            mapController: _mapController,
            options: MapOptions(
              initialCenter: _centerPoint,
              initialZoom: 12.0,
              minZoom: 3.0,
              maxZoom: 18.0,
            ),
            children: [
              TileLayer(
                urlTemplate: _isSatellite
                    ? 'https://{s}.basemaps.cartocdn.com/dark_all/{z}/{x}/{y}{r}.png'
                    : 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                userAgentPackageName: 'com.example.fusion_attendance',
              ),
              CircleLayer(circles: geofenceCircles),
              MarkerLayer(markers: markers),
            ],
          ),

          // Floating Filter Pill Bar at Top
          Positioned(
            top: 14,
            left: 14,
            right: 14,
            child: Container(
              padding: const EdgeInsets.all(6),
              decoration: BoxDecoration(
                color: isDark
                    ? const Color(0xFF0F172A).withValues(alpha: 0.92)
                    : Colors.white.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(28),
                border: Border.all(
                  color: isDark ? Colors.white12 : Colors.grey.shade300,
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.15),
                    blurRadius: 16,
                    offset: const Offset(0, 4),
                  ),
                ],
              ),
              child: SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                child: Row(
                  children: [
                    _buildFilterTab(context, 'All', Icons.apps_rounded),
                    const SizedBox(width: 6),
                    _buildFilterTab(context, 'Offices', Icons.business_rounded),
                    const SizedBox(width: 6),
                    _buildFilterTab(
                        context, 'WorkSites', Icons.location_on_rounded),
                    const SizedBox(width: 6),
                    _buildFilterTab(
                        context, 'Employees', Icons.people_alt_rounded),
                  ],
                ),
              ),
            ),
          ),

          // Map Zoom Controls (Right)
          Positioned(
            right: 12,
            bottom: 110,
            child: Column(
              children: [
                FloatingActionButton.small(
                  heroTag: 'zoom_in',
                  backgroundColor: Theme.of(context).cardColor,
                  onPressed: _zoomIn,
                  child: Icon(Icons.add,
                      color: isDark
                          ? AppColors.primaryLight
                          : AppColors.primary),
                ),
                const SizedBox(height: 8),
                FloatingActionButton.small(
                  heroTag: 'zoom_out',
                  backgroundColor: Theme.of(context).cardColor,
                  onPressed: _zoomOut,
                  child: Icon(Icons.remove,
                      color: isDark
                          ? AppColors.primaryLight
                          : AppColors.primary),
                ),
              ],
            ),
          ),

          // Bottom Stats Banner & Quick Overview
          Positioned(
            bottom: 16,
            left: 12,
            right: 12,
            child: Card(
              elevation: 6,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
              child: Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceAround,
                  children: [
                    _buildStatItem('${offices.length}', 'Offices',
                        Icons.business_rounded, AppColors.primary),
                    Container(
                        height: 30, width: 1, color: Colors.grey.shade300),
                    _buildStatItem('${workSites.length}', 'Sites',
                        Icons.location_on_rounded, Colors.orange.shade700),
                    Container(
                        height: 30, width: 1, color: Colors.grey.shade300),
                    _buildStatItem(
                        '${latestEmployeeRecords.length}',
                        'Live Active',
                        Icons.person_pin_circle_rounded,
                        AppColors.success),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilterTab(BuildContext context, String label, IconData icon) {
    final isSelected = _filterRole == label;
    final isDark = Theme.of(context).brightness == Brightness.dark;

    final Color activeBg = AppColors.primary;
    final Color inactiveBg =
        isDark ? const Color(0xFF1E293B) : const Color(0xFFF1F5F9);
    final Color activeFg = Colors.white;
    final Color inactiveFg =
        isDark ? Colors.grey.shade200 : const Color(0xFF1E293B);

    return GestureDetector(
      onTap: () => setState(() => _filterRole = label),
      child: AnimatedContainer(
        duration: const Duration(milliseconds: 200),
        curve: Curves.easeInOut,
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
        decoration: BoxDecoration(
          color: isSelected ? activeBg : inactiveBg,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
            color: isSelected
                ? AppColors.primary
                : (isDark ? const Color(0xFF334155) : Colors.grey.shade300),
            width: 1.2,
          ),
          boxShadow: isSelected
              ? [
                  BoxShadow(
                    color: AppColors.primary.withValues(alpha: 0.35),
                    blurRadius: 8,
                    offset: const Offset(0, 3),
                  ),
                ]
              : [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 3,
                    offset: const Offset(0, 1),
                  ),
                ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              icon,
              size: 16,
              color: isSelected
                  ? activeFg
                  : (isDark ? Colors.lightBlueAccent : AppColors.primary),
            ),
            const SizedBox(width: 6),
            Text(
              label,
              style: TextStyle(
                color: isSelected ? activeFg : inactiveFg,
                fontWeight: isSelected ? FontWeight.bold : FontWeight.w600,
                fontSize: 13,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildStatItem(
      String count, String label, IconData icon, Color color) {
    return Row(
      children: [
        Icon(icon, size: 20, color: color),
        const SizedBox(width: 8),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(count,
                style:
                    const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
            Text(label,
                style: const TextStyle(
                    fontSize: 11, color: AppColors.textSecondaryLight)),
          ],
        ),
      ],
    );
  }

  void _showOfficeDetails(OfficeEntity office) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.business_rounded,
                    color: AppColors.primary, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    office.name,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('Address: ${office.address}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Text('Geofence Radius: ${office.geofenceRadiusMeters}m',
                style: const TextStyle(
                    fontSize: 13,
                    color: AppColors.primary,
                    fontWeight: FontWeight.w600)),
            const SizedBox(height: 6),
            Text(
                'GPS Coordinates: ${office.latitude.toStringAsFixed(6)}, ${office.longitude.toStringAsFixed(6)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondaryLight)),
          ],
        ),
      ),
    );
  }

  void _showWorkSiteDetails(WorkSiteEntity site) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Icon(Icons.location_on_rounded,
                    color: Colors.orange.shade700, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    site.siteName,
                    style: const TextStyle(
                        fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('Address: ${site.address}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Text(
                'Client: ${site.clientName.isNotEmpty ? site.clientName : "N/A"}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Text(
                'GPS Coordinates: ${site.latitude.toStringAsFixed(6)}, ${site.longitude.toStringAsFixed(6)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondaryLight)),
          ],
        ),
      ),
    );
  }

  void _showEmployeeDetails(AttendanceRecord record) {
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(20))),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.person_pin_circle_rounded,
                    color: AppColors.success, size: 28),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(record.employeeName,
                          style: const TextStyle(
                              fontSize: 18, fontWeight: FontWeight.bold)),
                      Text(record.workflowStep.displayName,
                          style: const TextStyle(
                              fontSize: 12,
                              color: AppColors.success,
                              fontWeight: FontWeight.bold)),
                    ],
                  ),
                ),
              ],
            ),
            const Divider(height: 24),
            Text('Last Location: ${record.address}',
                style: const TextStyle(fontSize: 13)),
            const SizedBox(height: 6),
            Text(
                'GPS Coordinates: ${record.latitude.toStringAsFixed(6)}, ${record.longitude.toStringAsFixed(6)}',
                style: const TextStyle(
                    fontSize: 12, color: AppColors.textSecondaryLight)),
          ],
        ),
      ),
    );
  }
}
