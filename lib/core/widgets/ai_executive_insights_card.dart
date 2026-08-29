import 'package:flutter/material.dart';
import '../../features/attendance/domain/attendance_record.dart';
import '../constants/app_colors.dart';
import '../services/ai_analytics_service.dart';

class AiExecutiveInsightsCard extends StatefulWidget {
  final List<AttendanceRecord> records;

  const AiExecutiveInsightsCard({
    super.key,
    required this.records,
  });

  @override
  State<AiExecutiveInsightsCard> createState() =>
      _AiExecutiveInsightsCardState();
}

class _AiExecutiveInsightsCardState extends State<AiExecutiveInsightsCard> {
  final AiAnalyticsService _analyticsService = AiAnalyticsService();
  final TextEditingController _queryController = TextEditingController();

  late ExecutiveAnalyticsMetrics _metrics;
  bool _isProcessingQuery = false;

  final List<String> _sampleQueries = [
    'Overtime summary for this period',
    'Geofence compliance rate details',
    'Are there any unclosed active shifts?',
    'Average daily work hours per employee',
  ];

  @override
  void initState() {
    super.initState();
    _recomputeMetrics();
  }

  @override
  void didUpdateWidget(covariant AiExecutiveInsightsCard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.records.length != widget.records.length) {
      _recomputeMetrics();
    }
  }

  void _recomputeMetrics() {
    setState(() {
      _metrics = _analyticsService.computeExecutiveMetrics(widget.records, []);
    });
  }

  @override
  void dispose() {
    _queryController.dispose();
    super.dispose();
  }

  Future<void> _handleAiQuery([String? customQuery]) async {
    final queryText = customQuery ?? _queryController.text.trim();
    if (queryText.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Please enter a question or tap a sample query.'),
          backgroundColor: AppColors.warning,
        ),
      );
      return;
    }

    setState(() {
      _isProcessingQuery = true;
    });

    final answer = await _analyticsService.queryAnalyticsWithAi(
      queryText,
      widget.records,
    );

    if (mounted) {
      setState(() {
        _isProcessingQuery = false;
      });

      _showAiAnswerModal(queryText, answer);
    }
  }

  void _showAiAnswerModal(String query, String answer) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: surfaceColor,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 16),
                decoration: BoxDecoration(
                  color: isDark
                      ? AppColors.cardBorderDark
                      : AppColors.cardBorderLight,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(8),
                  decoration: BoxDecoration(
                    color: AppColors.primary.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Icon(
                    Icons.auto_awesome,
                    color: AppColors.primaryLight,
                    size: 20,
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        'AI Workforce Insight',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        'Query: "$query"',
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                          fontStyle: FontStyle.italic,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.pop(ctx),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.2),
                ),
              ),
              child: SelectableText(
                answer,
                style: TextStyle(
                  fontSize: 13.5,
                  height: 1.5,
                  color: textPrimary,
                ),
              ),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 44,
              child: ElevatedButton(
                onPressed: () => Navigator.pop(ctx),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text(
                  'Close Answer',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _getGeofenceColor(double rate) {
    if (rate >= 90.0) return AppColors.success;
    if (rate >= 75.0) return AppColors.warning;
    return AppColors.error;
  }

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final surfaceColor =
        isDark ? AppColors.surfaceDark : AppColors.surfaceLight;
    final textPrimary =
        isDark ? AppColors.textPrimaryDark : AppColors.textPrimaryLight;
    final textSecondary =
        isDark ? AppColors.textSecondaryDark : AppColors.textSecondaryLight;
    final borderColor =
        isDark ? AppColors.cardBorderDark : AppColors.cardBorderLight;

    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: surfaceColor,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.04),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Executive Title & AI Tag
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [AppColors.primary, AppColors.primaryLight],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(
                      Icons.insights_rounded,
                      color: Colors.white,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'AI Executive Insights',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: textPrimary,
                        ),
                      ),
                      Text(
                        'Real-time workforce metrics & anomaly alerts',
                        style: TextStyle(
                          fontSize: 11,
                          color: textSecondary,
                        ),
                      ),
                    ],
                  ),
                ],
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Row(
                  children: const [
                    Icon(
                      Icons.auto_awesome,
                      color: AppColors.primaryLight,
                      size: 13,
                    ),
                    SizedBox(width: 4),
                    Text(
                      'AI Powered',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.bold,
                        color: AppColors.primaryLight,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // Metric Badges Grid
          Row(
            children: [
              Expanded(
                child: _buildMetricTile(
                  title: 'Geofence %',
                  value: '${_metrics.geofenceComplianceRate.toStringAsFixed(1)}%',
                  icon: Icons.location_on_rounded,
                  color: _getGeofenceColor(_metrics.geofenceComplianceRate),
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  title: 'Overtime Spikes',
                  value: '${_metrics.overtimeSpikeCount}',
                  icon: Icons.timer_rounded,
                  color: _metrics.overtimeSpikeCount > 0
                      ? AppColors.warning
                      : AppColors.success,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  title: 'Unclosed Shifts',
                  value: '${_metrics.unclosedShiftCount}',
                  icon: Icons.running_with_errors_rounded,
                  color: _metrics.unclosedShiftCount > 0
                      ? AppColors.error
                      : AppColors.success,
                  isDark: isDark,
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _buildMetricTile(
                  title: 'Avg Shift',
                  value: '${_metrics.averageDailyHours}h',
                  icon: Icons.schedule_rounded,
                  color: AppColors.info,
                  isDark: isDark,
                ),
              ),
            ],
          ),

          const SizedBox(height: 16),

          // AI Anomaly Insights List
          const Text(
            'Executive Highlights:',
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: AppColors.textSecondaryLight,
            ),
          ),
          const SizedBox(height: 6),
          Column(
            children: _metrics.insights.map((bullet) {
              Color iconColor;
              IconData iconData;
              switch (bullet.severity) {
                case InsightSeverity.success:
                  iconColor = AppColors.success;
                  iconData = Icons.check_circle_rounded;
                  break;
                case InsightSeverity.warning:
                  iconColor = AppColors.warning;
                  iconData = Icons.warning_rounded;
                  break;
                case InsightSeverity.info:
                  iconColor = AppColors.info;
                  iconData = Icons.info_rounded;
                  break;
              }

              return Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Icon(iconData, color: iconColor, size: 16),
                    const SizedBox(width: 8),
                    Expanded(
                      child: RichText(
                        text: TextSpan(
                          style: TextStyle(
                            fontSize: 12,
                            color: textPrimary,
                            height: 1.3,
                          ),
                          children: [
                            TextSpan(
                              text: '${bullet.title}: ',
                              style: const TextStyle(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            TextSpan(
                              text: bullet.description,
                              style: TextStyle(color: textSecondary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ],
                ),
              );
            }).toList(),
          ),

          const SizedBox(height: 14),

          // Natural Language Search / Ask AI Query Bar
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
            decoration: BoxDecoration(
              color: isDark
                  ? AppColors.backgroundDark
                  : AppColors.backgroundLight,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: borderColor),
            ),
            child: Row(
              children: [
                const Icon(
                  Icons.search_rounded,
                  color: AppColors.primaryLight,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _queryController,
                    style: TextStyle(fontSize: 12.5, color: textPrimary),
                    onSubmitted: (val) => _handleAiQuery(val),
                    decoration: const InputDecoration(
                      hintText:
                          'Ask AI (e.g. "Overtime summary", "Show unclosed shifts")...',
                      hintStyle: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryLight,
                      ),
                      border: InputBorder.none,
                      isDense: true,
                    ),
                  ),
                ),
                if (_isProcessingQuery)
                  const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  IconButton(
                    icon: const Icon(
                      Icons.arrow_forward_rounded,
                      color: AppColors.primary,
                      size: 20,
                    ),
                    onPressed: () => _handleAiQuery(),
                    tooltip: 'Ask AI',
                  ),
              ],
            ),
          ),

          const SizedBox(height: 8),

          // Sample Query Chips
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: _sampleQueries.map((q) {
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: InkWell(
                    onTap: () {
                      _queryController.text = q;
                      _handleAiQuery(q);
                    },
                    borderRadius: BorderRadius.circular(8),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.primary.withValues(alpha: 0.06),
                        borderRadius: BorderRadius.circular(8),
                      ),
                      child: Text(
                        q,
                        style: const TextStyle(
                          fontSize: 10.5,
                          color: AppColors.primary,
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMetricTile({
    required String title,
    required String value,
    required IconData icon,
    required Color color,
    required bool isDark,
  }) {
    return Container(
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 14),
              const SizedBox(width: 4),
              Expanded(
                child: Text(
                  title,
                  style: TextStyle(
                    fontSize: 9.5,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            ],
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: TextStyle(
              fontSize: 14,
              fontWeight: FontWeight.bold,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}
