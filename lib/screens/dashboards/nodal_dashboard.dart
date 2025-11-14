import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'dart:io' show Platform;
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/daily_report.dart';
import '../../data/questions.dart';

class NodalDashboard extends StatefulWidget {
  const NodalDashboard({super.key, this.keyValue});
  final String? keyValue;

  @override
  State<NodalDashboard> createState() => _NodalDashboardState();
}

class _NodalDashboardState extends State<NodalDashboard> {
  late String? _previousKeyValue;
  String? _expandedReportId;
  List<DailyReport> _reports = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _previousKeyValue = widget.keyValue;
    _fetchReports();
  }

  @override
  void didUpdateWidget(NodalDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.keyValue != _previousKeyValue) {
      _previousKeyValue = widget.keyValue;
      _fetchReports();
    }
  }

  Future<void> _fetchReports() async {
    if (!mounted) return;

    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final reportProvider = context.read<ReportProvider>();
      final activeScope = auth.activeScope;

      if (activeScope == null) {
        throw Exception('No active scope selected');
      }

      if (activeScope.divisionId == null) {
        throw Exception('Division ID is required for nodal officer');
      }

      final reports = await reportProvider.getReportsForNodal(
        commissionerateId: activeScope.commissionerateId,
        divisionId: activeScope.divisionId!,
        date: DateTime.now(),
      );

      if (mounted) {
        setState(() {
          _reports = reports;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = 'Failed to load reports: ${e.toString()}';
        });
      }
    } finally {
      if (mounted) {
        setState(() => _isLoading = false);
      }
    }
  }

  void _toggleExpandReport(String? reportId) {
    if (reportId == null) return;
    setState(() {
      _expandedReportId = _expandedReportId == reportId ? null : reportId;
    });
  }

  String _getUserInitials(DailyReport report) {
    final name = report.userName ?? '';
    if (name.isEmpty) return 'N/A';

    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    final first = parts[0].substring(0, 1).toUpperCase();
    final last = parts[1].substring(0, 1).toUpperCase();
    return '$first$last';
  }

  Widget _formatUserDisplay(DailyReport report) {
    final name = report.userName ?? '';
    final phone = report.userPhone ?? '';

    Future<void> makePhoneCall(String phoneNumber) async {
      final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
      if (await canLaunchUrlString(phoneUri.toString())) {
        await launchUrlString(phoneUri.toString());
      } else {
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Could not launch phone call')),
          );
        }
      }
    }

    Widget buildCallButton() {
      return GestureDetector(
        onTap: () => makePhoneCall(phone),
        child: TweenAnimationBuilder<double>(
          tween: Tween(begin: 1.0, end: 1.0),
          duration: const Duration(milliseconds: 1500),
          builder: (context, scale, child) {
            return Transform.scale(
              scale: scale,
              child: Container(
                width: 28,
                height: 28,
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    colors: [
                      Colors.blue.shade400,
                      Colors.blue.shade600,
                    ],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  ),
                  shape: BoxShape.circle,
                  boxShadow: [
                    BoxShadow(
                      color: Colors.blue.withOpacity(0.4),
                      blurRadius: 4,
                      offset: const Offset(0, 2),
                    ),
                  ],
                ),
                child: const Icon(
                  Icons.phone_in_talk,
                  size: 16,
                  color: Colors.white,
                ),
              ),
            );
          },
        ),
      );
    }

    if (name.isNotEmpty && phone.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text('$name • $phone'),
          if (phone.isNotEmpty) ...[
            const SizedBox(width: 12),
            MouseRegion(
              cursor: SystemMouseCursors.click,
              child: Tooltip(
                message: 'Call $phone',
                child: buildCallButton(),
              ),
            ),
          ],
        ],
      );
    } else if (name.isNotEmpty) {
      return Text(name);
    } else if (phone.isNotEmpty) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(phone),
          const SizedBox(width: 12),
          MouseRegion(
            cursor: SystemMouseCursors.click,
            child: Tooltip(
              message: 'Call $phone',
              child: buildCallButton(),
            ),
          ),
        ],
      );
    }

    return const Text('No user assigned');
  }

  Widget _buildSummaryItem({
    required BuildContext context,
    required String label,
    required int count,
    required IconData icon,
    required Color color,
  }) {
    final theme = Theme.of(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          padding: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            color: color.withOpacity(0.1),
            shape: BoxShape.circle,
          ),
          child: Icon(icon, color: color, size: 20),
        ),
        const SizedBox(height: 8),
        Text(
          count.toString(),
          style: theme.textTheme.titleLarge?.copyWith(
            fontWeight: FontWeight.bold,
            color: theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 2),
        Text(
          label,
          style: theme.textTheme.bodySmall?.copyWith(
            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
          ),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProv = Provider.of<ThemeProvider>(context, listen: true);
    final auth = context.watch<AuthProvider>();
    final activeScope = auth.activeScope;
    final isDark = themeProv.isDarkMode;

    // Define gradient colors based on theme
    final gradientColors = isDark
        ? [
            const Color(0xFF0F2027), // Dark teal
            const Color(0xFF203A43), // Darker teal
            const Color(0xFF2C5364), // Dark blue-gray
          ]
        : [
            const Color(0xFFE0EAFC), // Very light blue
            const Color(0xFFCFDEF3), // Light blue
            const Color(0xFFE0EAFC), // Very light blue
          ];

    if (activeScope == null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(
            child: Text(
              'Please select a scope to continue.',
              style: TextStyle(fontSize: 16),
            ),
          ),
        ),
      );
    }

    return Scaffold(
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: SafeArea(
          child: Column(
            children: [
              // Header with title and refresh button
              Padding(
                padding: const EdgeInsets.all(16.0),
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Text(
                      'Hi, ${auth.user?['name'] ?? 'Officer'}!',
                      style: theme.textTheme.headlineSmall?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.onSurface,
                      ),
                    ),
                    IconButton(
                      icon: const Icon(Icons.refresh),
                      onPressed: _fetchReports,
                      tooltip: 'Refresh',
                    ),
                  ],
                ),
              ),
              
              // Summary card with total and critical counts
              if (!_isLoading && _error == null && _reports.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                  child: Card(
                    elevation: 2,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12.0),
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(16.0),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _buildSummaryItem(
                            context: context,
                            label: 'Total Issues',
                            count: _reports.fold(0, (sum, report) => sum + (report.totalCount ?? 0)),
                            icon: Icons.assignment,
                            color: theme.colorScheme.primary,
                          ),
                          _buildSummaryItem(
                            context: context,
                            label: 'Critical Issues',
                            count: _reports.fold(0, (sum, report) => sum + (report.criticalCount ?? 0)),
                            icon: Icons.warning_amber_rounded,
                            color: Colors.red,
                          ),
                          _buildSummaryItem(
                            context: context,
                            label: 'Ranges',
                            count: _reports.length,
                            icon: Icons.location_on,
                            color: Colors.green,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              
              // Main content
              Expanded(
                child: _isLoading
                    ? const Center(child: CircularProgressIndicator())
                    : _error != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(16.0),
                              child: Text(
                                _error!,
                                style: theme.textTheme.bodyLarge?.copyWith(
                                  color: theme.colorScheme.error,
                                ),
                                textAlign: TextAlign.center,
                              ),
                            ),
                          )
                        : _reports.isEmpty
                            ? Center(
                                child: Column(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    Icon(
                                      Icons.assignment_outlined,
                                      size: 64,
                                      color: theme.colorScheme.primary.withOpacity(0.5),
                                    ),
                                    const SizedBox(height: 16),
                                    Text(
                                      'No reports found for today',
                                      style: theme.textTheme.titleMedium,
                                    ),
                                    const SizedBox(height: 8),
                                    TextButton.icon(
                                      onPressed: _fetchReports,
                                      icon: const Icon(Icons.refresh),
                                      label: const Text('Refresh'),
                                    ),
                                  ],
                                ),
                              )
                            : ListView.builder(
                                padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
                                itemCount: _reports.length,
                                itemBuilder: (context, index) {
                                  final report = _reports[index];
                                  final isExpanded = _expandedReportId == report.id;

                                  return AnimatedContainer(
                                    duration: const Duration(milliseconds: 200),
                                    margin: const EdgeInsets.only(bottom: 12.0),
                                    decoration: BoxDecoration(
                                      color: theme.cardColor,
                                      borderRadius: BorderRadius.circular(12.0),
                                      boxShadow: [
                                        BoxShadow(
                                          color: Colors.black.withOpacity(0.1),
                                          blurRadius: 8.0,
                                          offset: const Offset(0, 2),
                                        ),
                                      ],
                                    ),
                                    child: Material(
                                      color: Colors.transparent,
                                      child: InkWell(
                                        borderRadius: BorderRadius.circular(12.0),
                                        onTap: () => _toggleExpandReport(report.id),
                                        child: Padding(
                                          padding: const EdgeInsets.all(16.0),
                                          child: Column(
                                            crossAxisAlignment: CrossAxisAlignment.start,
                                            children: [
                                              // Header row
                                              Row(
                                                children: [
                                                  // Avatar with user initials
                                                  Container(
                                                    width: 40,
                                                    height: 40,
                                                    decoration: BoxDecoration(
                                                      color: theme.colorScheme.primary.withOpacity(0.1),
                                                      shape: BoxShape.circle,
                                                    ),
                                                    child: Center(
                                                      child: Text(
                                                        _getUserInitials(report),
                                                        style: TextStyle(
                                                          fontSize: 14,
                                                          fontWeight: FontWeight.bold,
                                                          color: theme.colorScheme.primary,
                                                        ),
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 12),

                                                  // Title and subtitle
                                                  Expanded(
                                                    child: Column(
                                                      crossAxisAlignment: CrossAxisAlignment.start,
                                                      children: [
                                                        Text(
                                                          report.rangeName ?? 'Range ${report.rangeId ?? 'N/A'}',
                                                          style: theme.textTheme.titleMedium?.copyWith(
                                                            fontWeight: FontWeight.bold,
                                                          ),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                        ),
                                                        const SizedBox(height: 2),
                                                        DefaultTextStyle(
                                                          style: theme.textTheme.bodySmall?.copyWith(
                                                            color: theme.textTheme.bodySmall?.color?.withOpacity(0.7),
                                                          ) ?? const TextStyle(),
                                                          maxLines: 1,
                                                          overflow: TextOverflow.ellipsis,
                                                          child: _formatUserDisplay(report),
                                                        ),
                                                      ],
                                                    ),
                                                  ),

                                                  // Status indicators
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: theme.colorScheme.primary.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      '${report.totalCount ?? 0} Total',
                                                      style: theme.textTheme.labelSmall?.copyWith(
                                                        color: theme.colorScheme.primary,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Container(
                                                    padding: const EdgeInsets.symmetric(
                                                      horizontal: 8,
                                                      vertical: 4,
                                                    ),
                                                    decoration: BoxDecoration(
                                                      color: Colors.red.withOpacity(0.1),
                                                      borderRadius: BorderRadius.circular(12),
                                                    ),
                                                    child: Text(
                                                      '${report.criticalCount ?? 0} Critical',
                                                      style: theme.textTheme.labelSmall?.copyWith(
                                                        color: Colors.red,
                                                        fontWeight: FontWeight.bold,
                                                      ),
                                                    ),
                                                  ),
                                                  const SizedBox(width: 8),
                                                  Icon(
                                                    isExpanded ? Icons.expand_less : Icons.expand_more,
                                                    color: theme.colorScheme.onSurface.withOpacity(0.6),
                                                  ),
                                                ],
                                              ),

                                              // Expanded content
                                              if (isExpanded) _buildReportDetails(report),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  );
                                },
                              ),
                          ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildReportDetails(DailyReport report) {
    final theme = Theme.of(context);
    
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        ...report.answers.map((answer) {
          final question = dailyReportQuestions.firstWhere(
            (q) => q.id == answer.qId,
            orElse: () => const ReportQuestion(id: -1, text: 'Unknown Question'),
          );

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                // Question indicator
                Container(
                  width: 24,
                  height: 24,
                  margin: const EdgeInsets.only(right: 12, top: 2),
                  decoration: BoxDecoration(
                    color: theme.colorScheme.primary.withOpacity(0.1),
                    shape: BoxShape.circle,
                  ),
                  child: Center(
                    child: Text(
                      '${report.answers.indexOf(answer) + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
                
                // Question and answer
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        question.text,
                        style: theme.textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w500,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          // Total count badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: theme.colorScheme.primary.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${answer.totalCount} Total',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: theme.colorScheme.primary,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          // Critical count badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 8,
                              vertical: 2,
                            ),
                            decoration: BoxDecoration(
                              color: answer.criticalCount > 0 
                                ? Colors.red.withOpacity(0.1) 
                                : Colors.grey.withOpacity(0.1),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              '${answer.criticalCount} Critical',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: answer.criticalCount > 0 
                                  ? Colors.red 
                                  : Colors.grey,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          );
        }),
        const SizedBox(height: 8),
      ],
    );
  }
}
