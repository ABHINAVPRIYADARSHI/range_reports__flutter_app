// lib/screens/dashboards/range_dashboard.dart

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/theme_provider.dart';
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

  @override
  void didUpdateWidget(covariant RangeDashboard oldWidget) {
    super.didUpdateWidget(oldWidget);
    // If the key has changed, it means the scope has changed, so re-fetch.
    if (oldWidget.key != widget.key) {
      _fetchTodaysReport();
    }
  }

  Future<void> _fetchTodaysReport() async {
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    final activeScope = authProvider.activeScope;

    if (activeScope != null) {
      await reportProvider.getReportForRange(
        commissionerateId: activeScope.commissionerateId,
        divisionId: activeScope.divisionId!,
        rangeId: activeScope.rangeId!,
        date: DateTime.now(),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    final themeProv = Provider.of<ThemeProvider>(context, listen: true);
    final authProvider = Provider.of<AuthProvider>(context, listen: true);
    final isDark = themeProv.isDarkMode;
    final reportProvider = Provider.of<ReportProvider>(context);
    final todaysReport = reportProvider.todaysReport;
    final userName = (authProvider.user?['name'] as String?) ?? 'Officer!';

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
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  // Header Section
                  Column(
                    children: [
                      Text(
                        'Hi, $userName',
                        style: theme.textTheme.headlineSmall?.copyWith(
                          fontWeight: FontWeight.bold,
                          color: theme.colorScheme.onSurface,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'Range Officer Dashboard',
                        style: theme.textTheme.bodyLarge?.copyWith(
                          color: theme.colorScheme.onSurface.withOpacity(0.7),
                        ),
                      ),
                    ],
                  ),
                  
                  const SizedBox(height: 40),
                  
                  // Main Content
                  if (reportProvider.isLoading)
                    const Center(
                      child: Padding(
                        padding: EdgeInsets.all(32.0),
                        child: CircularProgressIndicator(),
                      ),
                    )
                  else if (todaysReport != null)
                    // Report Status Card
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.check_circle_outline,
                              size: 64,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'Report Submitted',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You have successfully submitted today\'s report.',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: () {
                                  Navigator.pushNamed(
                                    context, 
                                    Routes.reportForm, 
                                    arguments: {
                                      'mode': 'edit',
                                      'report': todaysReport,
                                    },
                                  );
                                },
                                icon: const Icon(Icons.edit_document, size: 20),
                                label: const Text('View/Edit Report'),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    )
                  else
                    // No Report Card
                    Card(
                      elevation: 8,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                      ),
                      child: Padding(
                        padding: const EdgeInsets.all(24.0),
                        child: Column(
                          children: [
                            Icon(
                              Icons.assignment_outlined,
                              size: 64,
                              color: theme.colorScheme.primary,
                            ),
                            const SizedBox(height: 16),
                            Text(
                              'No Report Submitted',
                              style: theme.textTheme.titleLarge?.copyWith(
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Text(
                              'You haven\'t submitted a report for today yet.',
                              style: theme.textTheme.bodyMedium,
                              textAlign: TextAlign.center,
                            ),
                            const SizedBox(height: 24),
                            SizedBox(
                              width: double.infinity,
                              height: 48,
                              child: ElevatedButton.icon(
                                onPressed: () async {
                                  await Navigator.pushNamed(
                                    context, 
                                    Routes.reportForm, 
                                    arguments: {'mode': 'new'},
                                  );
                                  _fetchTodaysReport();
                                },
                                icon: const Icon(Icons.add, size: 20),
                                label: const Text('Submit Today\'s Report'),
                                style: ElevatedButton.styleFrom(
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}