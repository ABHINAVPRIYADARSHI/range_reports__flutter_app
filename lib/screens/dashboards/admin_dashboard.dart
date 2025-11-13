import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:collection/collection.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../models/daily_report.dart';
import '../../data/questions.dart';

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

  @override
  void initState() {
    super.initState();
    _previousKeyValue = widget.keyValue;
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

    if (_isLoading) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    if (_error != null) {
      return Scaffold(body: Center(child: Text(_error!)));
    }

    if (_reports.isEmpty) {
      return const Scaffold(
        body: Center(child: Text('No reports found for today')),
      );
    }

    final groupedByDivision = groupBy(_reports, (DailyReport r) => r.divisionName ?? 'Unknown Division');
    final sortedEntries = groupedByDivision.entries.toList()
      ..sort((a, b) {
        // Assuming divisionId is a string; if it's an int, remove .toString()
        final idA = a.value.first.divisionId ?? '';
        final idB = b.value.first.divisionId ?? '';
        return idA.compareTo(idB);
      });

    return Scaffold(
      appBar: AppBar(title: const Text('Admin Dashboard')),
      body: ListView(
        children: sortedEntries.map((entry) {
          final divisionName = entry.key;
          final reports = entry.value;

          // Aggregate total and critical counts for division
          final totalDivisionCount = reports.fold<int>(0, (sum, r) => sum + (r.totalCount ?? 0));
          final criticalDivisionCount = reports.fold<int>(0, (sum, r) => sum + (r.criticalCount ?? 0));

          return Card(
            margin: const EdgeInsets.symmetric(horizontal: 16.0, vertical: 8.0),
            child: Column(
              children: [
                ListTile(
                  title: Text(
                    divisionName,
                    style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                  subtitle: Text(
                    'Total: $totalDivisionCount | Critical: $criticalDivisionCount',
                    style: const TextStyle(color: Colors.grey),
                  ),
                ),
                ...reports.map((report) {
                  final reportExpanded = _expandedReportId == report.id;
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 4.0),
                    child: Card(
                      margin: const EdgeInsets.symmetric(vertical: 4.0),
                      child: Column(
                        children: [
                          Padding(
                            padding: const EdgeInsets.symmetric(horizontal: 8.0, vertical: 6.0),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 20,
                                  child: Text(
                                    _getUserInitials(report),
                                    style: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(
                                        report.rangeName ?? 'Range ${report.rangeId ?? 'N/A'}',
                                        style: const TextStyle(
                                          fontSize: 16,
                                          fontWeight: FontWeight.w600,
                                        ),
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        _formatUserDisplay(report),
                                        style: const TextStyle(fontSize: 13, color: Colors.grey),
                                        softWrap: true,
                                        overflow: TextOverflow.ellipsis,
                                      ),
                                    ],
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.end,
                                  children: [
                                    Text(
                                      'Total: ${report.totalCount ?? 0}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                    Text(
                                      'Critical: ${report.criticalCount ?? 0}',
                                      style: const TextStyle(fontWeight: FontWeight.bold),
                                    ),
                                  ],
                                ),
                                const SizedBox(width: 8),
                                IconButton(
                                  padding: EdgeInsets.zero,
                                  constraints: const BoxConstraints(),
                                  icon: Icon(reportExpanded ? Icons.expand_less : Icons.expand_more),
                                  onPressed: () => _toggleExpandReport(report.id),
                                ),
                              ],
                            ),
                          ),
                          if (reportExpanded) _buildReportDetails(report),
                        ],
                      ),
                    ),
                  );
                }).toList(),
              ],
            ),
          );
        }).toList(),
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
              orElse: () => const ReportQuestion(id: -1, text: 'Unknown Question'),
            );
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 4.0),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Expanded(
                    child: Text(question.text, style: const TextStyle(fontSize: 14)),
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
