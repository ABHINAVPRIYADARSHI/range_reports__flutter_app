import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import 'package:url_launcher/url_launcher_string.dart';
import 'dart:io' show Platform;
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/theme_provider.dart';
import '../../models/daily_report.dart';
import '../../data/questions.dart';
import '../admin/user_management_screen.dart';

class AdminDashboard extends StatefulWidget {
  const AdminDashboard({super.key, this.keyValue});
  final String? keyValue;

  @override
  State<AdminDashboard> createState() => _AdminDashboardState();
}

class _AdminDashboardState extends State<AdminDashboard> {
  late String? _previousKeyValue;
  String? _expandedReportId;
  List<DailyReport> _reports = [];
  bool _isLoading = true;
  String? _error;
  late DateTime _selectedDate;

  @override
  void initState() {
    super.initState();
    _previousKeyValue = widget.keyValue;
    _selectedDate = DateTime.now();
    _fetchReports();
  }

  @override
  void didUpdateWidget(AdminDashboard oldWidget) {
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

      final reports = await reportProvider.getReportsForAdmin(
        commissionerateId: activeScope.commissionerateId,
        date: _selectedDate,
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

  Future<void> _selectDate(BuildContext context) async {
    final DateTime? picked = await showDatePicker(
      context: context,
      initialDate: _selectedDate,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
    );
    if (picked != null && picked != _selectedDate) {
      setState(() {
        _selectedDate = picked;
      });
      await _fetchReports();
    }
  }

  void _toggleExpandReport(String? reportId) {
    if (reportId == null) return;
    setState(() {
      _expandedReportId = _expandedReportId == reportId ? null : reportId;
    });
  }

  String _getUserInitials(DailyReport report) {
    final name = report.name ?? '';
    if (name.isEmpty) return 'N/A';
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length == 1) {
      return parts[0].substring(0, 1).toUpperCase();
    }
    final first = parts[0].substring(0, 1).toUpperCase();
    final last = parts[1].substring(0, 1).toUpperCase();
    return '$first$last';
  }

  Future<void> makePhoneCall(String phoneNumber) async {
    final Uri phoneUri = Uri(scheme: 'tel', path: phoneNumber);
    if (await canLaunchUrlString(phoneUri.toString())) {
      await launchUrlString(phoneUri.toString());
    } else if (mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Could not launch phone call')),
      );
    }
  }

  Widget _formatUserDisplay(DailyReport report) {
    final name = report.name ?? '';
    final phone = report.phone ?? '';

    if (name.isNotEmpty && phone.isNotEmpty) {
      return Text('$name • $phone');
    } else if (name.isNotEmpty) {
      return Text(name);
    } else if (phone.isNotEmpty) {
      return Text(phone);
    }

    return const Text('No user assigned');
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProv = Provider.of<ThemeProvider>(context, listen: true);
    final auth = context.watch<AuthProvider>();
    final activeScope = auth.activeScope;
    final gradientColors = themeProv.gradientColors;

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

    if (_isLoading) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: const Center(child: CircularProgressIndicator()),
        ),
      );
    }

    if (_error != null) {
      return Scaffold(
        body: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: gradientColors,
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
            ),
          ),
          child: Center(
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
          ),
        ),
      );
    }

    // Always show the header with greeting and buttons
    Widget _buildHeader() {
      return Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        child: Row(
          children: [
            // Greeting text
            Expanded(
              child: Text(
                'Hi, ${auth.user?['name'] ?? 'Admin'}!',
                style: theme.textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: theme.colorScheme.onSurface,
                ),
                overflow: TextOverflow.ellipsis,
              ),
            ),

            // Calendar Button
            Container(
              margin: const EdgeInsets.only(left: 8.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: Material(
                color: Colors.transparent,
                child: InkWell(
                  borderRadius: BorderRadius.circular(20),
                  onTap: () => _selectDate(context),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 12,
                      vertical: 8,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          Icons.calendar_today,
                          size: 18,
                          color: theme.colorScheme.primary,
                        ),
                        const SizedBox(width: 6),
                        Text(
                          '${_selectedDate.year}-${_selectedDate.month.toString().padLeft(2, '0')}-${_selectedDate.day.toString().padLeft(2, '0')}',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color: theme.colorScheme.primary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),

            // User Management Button
            Container(
              margin: const EdgeInsets.only(left: 8.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.people_alt_outlined, size: 22),
                onPressed: () {
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (context) => const UserManagementScreen(),
                    ),
                  );
                },
                tooltip: 'User Management',
                color: theme.colorScheme.primary,
                padding: const EdgeInsets.all(8.0),
                constraints: const BoxConstraints(),
              ),
            ),

            // Refresh Button
            Container(
              margin: const EdgeInsets.only(left: 8.0),
              decoration: BoxDecoration(
                color: theme.colorScheme.primary.withOpacity(0.1),
                borderRadius: BorderRadius.circular(20),
              ),
              child: IconButton(
                icon: const Icon(Icons.refresh, size: 22),
                onPressed: _fetchReports,
                tooltip: 'Refresh',
                color: theme.colorScheme.primary,
                padding: const EdgeInsets.all(8.0),
                constraints: const BoxConstraints(),
              ),
            ),
          ],
        ),
      );
    }

    Widget _buildNoReportsView() {
      return Center(
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
      );
    }

    // ----------- MAIN MODIFICATION -----------
    // GROUP REPORTS BY DIVISION AND BUILD DIVISION CARDS

    Widget _buildGroupedReports() {
      // group reports by divisionName (change to divisionId if needed)
      final groupedReports = groupBy(
        _reports,
        (DailyReport r) => r.divisionName ?? 'Unknown Division',
      );

      if (groupedReports.isEmpty) {
        return _buildNoReportsView();
      }

      return ListView(
        padding: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
        children: groupedReports.entries.map((entry) {
          final divisionName = entry.key;
          final reports = entry.value;
          // aggregate division totals
          final totalCount = reports.fold<int>(
            0,
            (sum, r) => sum + (r.totalCount ?? 0),
          );
          final criticalCount = reports.fold<int>(
            0,
            (sum, r) => sum + (r.criticalCount ?? 0),
          );

          return _buildDivisionCard(
            context,
            divisionName: divisionName,
            totalCount: totalCount,
            criticalCount: criticalCount,
            reports: reports,
          );
        }).toList(),
      );
    }
    // ----------- END MAIN MODIFICATION -----------

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
              _buildHeader(),
              Expanded(child: _buildGroupedReports()),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDivisionCard(
    BuildContext context, {
    required String divisionName,
    required int totalCount,
    required int criticalCount,
    required List<DailyReport> reports,
  }) {
    final theme = Theme.of(context);

    return Card(
      margin: const EdgeInsets.only(bottom: 16.0),
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12.0)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Division header
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: theme.colorScheme.primary.withOpacity(0.1),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(12.0),
                topRight: Radius.circular(12.0),
              ),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  divisionName,
                  style: theme.textTheme.titleMedium?.copyWith(
                    fontWeight: FontWeight.bold,
                    color: theme.colorScheme.primary,
                  ),
                ),
                const SizedBox(height: 4),
                Row(
                  children: [
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
                        '$totalCount Total',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: theme.colorScheme.primary,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 2,
                      ),
                      decoration: BoxDecoration(
                        color: criticalCount > 0
                            ? Colors.red.withOpacity(0.1)
                            : Colors.grey.withOpacity(0.1),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '$criticalCount Critical',
                        style: theme.textTheme.labelSmall?.copyWith(
                          color: criticalCount > 0 ? Colors.red : Colors.grey,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
          ...reports.map((report) {
            final uniqueId =
                '${report.submittedBy}_${report.divisionId}_${report.rangeId}';
            final isExpanded = _expandedReportId == uniqueId;
            return _buildReportCard(theme, report, isExpanded);
          }),
        ],
      ),
    );
  }

  Widget _buildReportCard(
    ThemeData theme,
    DailyReport report,
    bool isExpanded,
  ) {
    final isNotSubmitted = !(report.hasSubmitted ?? false);
    final borderColor = isNotSubmitted ? Colors.red.withOpacity(0.5) : Colors.green.withOpacity(0.5);

    return Stack(
      children: [
        Container(
          margin: const EdgeInsets.all(8.0),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12.0),
            boxShadow: [
              BoxShadow(
                color: isNotSubmitted
                    ? Colors.red.withOpacity(0.3)
                    : Colors.green.withOpacity(0.5),
                blurRadius: 4.0,
                offset: const Offset(0, 2),
              ),
            ],
          ),
          child: Material(
            color: theme.cardColor,
            borderRadius: BorderRadius.circular(12.0),
            child: InkWell(
              borderRadius: BorderRadius.circular(12.0),
              onTap: () {
                final uniqueId =
                    '${report.submittedBy}_${report.divisionId}_${report.rangeId}';
                _toggleExpandReport(uniqueId);
              },
              child: Padding(
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const SizedBox(height: 4), // Space for the floating label
                    Row(
                      children: [
                        GestureDetector(
                          onTap: report.phone?.isNotEmpty == true
                              ? () => makePhoneCall(report.phone!)
                              : null,
                          child: Container(
                            width: 40,
                            height: 40,
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
                              size: 20,
                              color: Colors.white,
                            ),
                          ),
                        ),
                        const SizedBox(width: 12),
                        Expanded(
                          child: Text(
                            report.name ?? 'N/A',
                            style: theme.textTheme.bodyMedium?.copyWith(
                              fontWeight: FontWeight.w500,
                            ),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                        
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
                              fontWeight: FontWeight.w600,
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
                            color: (report.criticalCount ?? 0) > 0
                                ? Colors.red.withOpacity(0.1)
                                : Colors.grey.withOpacity(0.1),
                            borderRadius: BorderRadius.circular(12),
                          ),
                          child: Text(
                            '${report.criticalCount ?? 0} Critical',
                            style: theme.textTheme.labelSmall?.copyWith(
                              color: (report.criticalCount ?? 0) > 0
                                  ? Colors.red
                                  : Colors.grey,
                              fontWeight: FontWeight.w600,
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
                    if (isExpanded) _buildReportDetails(report, theme),
                  ],
                ),
              ),
            ),
          ),
        ),
        // Range name as notched label
        Positioned(
          left: 24,
          top: 0,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: theme.scaffoldBackgroundColor,
              borderRadius: BorderRadius.circular(8),
            ),
            child: Text(
              report.rangeName ?? 'Range ${report.rangeId ?? 'N/A'}',
              style: theme.textTheme.bodySmall?.copyWith(
                color: borderColor,
                fontWeight: FontWeight.w500,
              ),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildReportDetails(DailyReport report, ThemeData theme) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 12),
        const Divider(height: 1),
        const SizedBox(height: 12),
        ...(report.answers ?? []).map((answer) {
          final question = dailyReportQuestions.firstWhere(
            (q) => q.id == answer.qId,
            orElse: () =>
                const ReportQuestion(id: -1, text: 'Unknown Question'),
          );

          return Padding(
            padding: const EdgeInsets.symmetric(vertical: 8.0, horizontal: 4.0),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
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
                      '${(report.answers ?? []).indexOf(answer) + 1}',
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.primary,
                      ),
                    ),
                  ),
                ),
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
