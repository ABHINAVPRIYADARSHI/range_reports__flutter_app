import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
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

  String _formatUserDisplay(DailyReport report) {
    final name = report.userName ?? '';
    final phone = report.userPhone ?? '';

    if (name.isNotEmpty && phone.isNotEmpty) {
      return '$name • $phone';
    } else if (name.isNotEmpty) {
      return name;
    } else if (phone.isNotEmpty) {
      return phone;
    }

    return 'No user assigned';
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final activeScope = auth.activeScope;

    if (activeScope == null) {
      return const Scaffold(
        body: Center(child: Text('Please select a scope to continue.')),
      );
    }

    return Scaffold(
      appBar: AppBar(title: const Text('Nodal Dashboard')),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _reports.isEmpty
          ? const Center(child: Text('No reports found for today'))
          : ListView.builder(
              itemCount: _reports.length,
              itemBuilder: (context, index) {
                final report = _reports[index];
                final isExpanded = _expandedReportId == report.id;

                return Card(
                  margin: const EdgeInsets.symmetric(
                    horizontal: 16.0,
                    vertical: 8.0,
                  ),
                  child: Column(
                    children: [
                      Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8.0,
                          vertical: 6.0,
                        ),
                        child: Row(
                          children: [
                            // 👤 Avatar with user initials
                            CircleAvatar(
                              radius: 20,
                              child: Text(
                                _getUserInitials(report),
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),

                            // 📄 Title + subtitle (takes remaining space)
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  // Range name
                                  Text(
                                    report.rangeName ??
                                        'Range ${report.rangeId ?? 'N/A'}',
                                    style: const TextStyle(
                                      fontSize: 16,
                                      fontWeight: FontWeight.w600,
                                    ),
                                    maxLines: 1,
                                    overflow: TextOverflow.ellipsis,
                                  ),
                                  const SizedBox(height: 4),

                                  // User name + phone
                                  Text(
                                    _formatUserDisplay(report),
                                    style: const TextStyle(
                                      fontSize: 13,
                                      color: Colors.grey,
                                    ),
                                    maxLines: 2,
                                    overflow: TextOverflow.ellipsis,
                                    softWrap: true,
                                  ),
                                ],
                              ),
                            ),

                            // ➕ Trailing section (counts + expand button)
                            const SizedBox(width: 12),
                            Row(
                              mainAxisSize: MainAxisSize
                                  .min, // 👈 This ensures it doesn’t push outward
                              children: [
                                // Counts column
                                Column(
                                  mainAxisSize: MainAxisSize.min,
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Total count: ${report.totalCount ?? 0}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    const SizedBox(height: 4),
                                    Text(
                                      'Critical count: ${report.criticalCount ?? 0}',
                                      style: const TextStyle(
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),

                                // Expand/collapse button
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(
                                    isExpanded
                                        ? Icons.expand_less
                                        : Icons.expand_more,
                                  ),
                                  onPressed: () =>
                                      _toggleExpandReport(report.id),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),

                      // 📋 Expanded section (if any)
                      if (isExpanded) _buildReportDetails(report),
                    ],
                  ),
                );
              },
            ),
    );
  }

  Widget _buildReportDetails(DailyReport report) {
    return Padding(
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          const Divider(),
          const SizedBox(height: 8),
          ...report.answers.map((answer) {
            final question = dailyReportQuestions.firstWhere(
              (q) => q.id == answer.qId,
              orElse: () =>
                  const ReportQuestion(id: -1, text: 'Unknown Question'),
            );

            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(
                      question.text,
                      style: const TextStyle(fontSize: 14),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Text(
                    '${answer.totalCount} (${answer.criticalCount} critical)',
                    style: const TextStyle(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
            );
          }).toList(),
        ],
      ),
    );
  }
}
