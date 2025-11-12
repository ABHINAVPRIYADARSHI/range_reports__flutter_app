// lib/screens/dashboards/range_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../routes.dart';

class RangeDashboard extends StatefulWidget {
  const RangeDashboard({super.key});

  @override
  State<RangeDashboard> createState() => _RangeDashboardState();
}

class _RangeDashboardState extends State<RangeDashboard> {
  @override
  void initState() {
    super.initState();
    // Fetch the report status when the widget is first built
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _fetchTodaysReport();
    });
  }

  Future<void> _fetchTodaysReport() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    final activeScope = authProvider.activeScope;

    if (activeScope != null) {
      await reportProvider.getReportForRange(activeScope.rangeId!, DateTime.now());
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportProvider = Provider.of<ReportProvider>(context);
    final todaysReport = reportProvider.todaysReport;

    return Scaffold(
      body: Center(
        child: Padding(
          padding: const EdgeInsets.all(20.0),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Text(
                'Range Officer Dashboard',
                style: TextStyle(fontSize: 24, fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 30),
              if (reportProvider.isLoading)
                const CircularProgressIndicator()
              else if (todaysReport != null)
                // TODO: Replace with ReportSummaryCard widget
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16.0),
                    child: Column(
                      children: [
                        const Text('Today\'s report submitted.', style: TextStyle(fontSize: 16)),
                        const SizedBox(height: 10),
                        ElevatedButton.icon(
                          onPressed: () {
                            Navigator.pushNamed(context, Routes.reportForm, arguments: {
                              'mode': 'edit',
                              'report': todaysReport,
                            });
                          },
                          icon: const Icon(Icons.edit),
                          label: const Text('Edit Report'),
                        ),
                      ],
                    ),
                  ),
                )
              else
                ElevatedButton.icon(
                  onPressed: () async {
                    // Navigate and wait for the form to be closed
                    await Navigator.pushNamed(context, Routes.reportForm, arguments: {'mode': 'new'});
                    // When back, re-fetch the report to update the UI
                    _fetchTodaysReport();
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('Submit Today\'s Report'),
                  style: ElevatedButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12)),
                ),
            ],
          ),
        ),
      ),
    );
  }
}