import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/questions.dart';
import '../../models/daily_report.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
import '../../providers/theme_provider.dart';
import '../../widgets/loader_overlay.dart';
import 'question_row.dart';

class DailyReportFormScreen extends StatefulWidget {
  const DailyReportFormScreen({super.key});

  @override
  State<DailyReportFormScreen> createState() => _DailyReportFormScreenState();
}

class _DailyReportFormScreenState extends State<DailyReportFormScreen> {
  final _formKey = GlobalKey<FormState>();
  late List<TextEditingController> _totalControllers;
  late List<TextEditingController> _criticalControllers;

  String _mode = 'new';
  DailyReport? _existingReport;
  final bool _isInitialized = false;

  int _totalSum = 0;
  int _criticalSum = 0;

  @override
  void initState() {
    super.initState();
    _totalControllers = List.generate(
      dailyReportQuestions.length,
      (_) => TextEditingController(text: '0'),
    );
    _criticalControllers = List.generate(
      dailyReportQuestions.length,
      (_) => TextEditingController(text: '0'),
    );

    for (var i = 0; i < dailyReportQuestions.length; i++) {
      _totalControllers[i].addListener(_updateTotals);
      _criticalControllers[i].addListener(_updateTotals);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();

    try {
      final args =
          ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;

      if (args != null && args['mode'] == 'edit') {
        final report = args['report'] as DailyReport?;
        if (report != null) {
          setState(() {
            _mode = 'edit';
            _existingReport = report;
            _populateForm();
          });
        } else {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(
                content: Text('Error: Could not load report data'),
              ),
            );
            Navigator.of(context).pop();
          });
        }
      }
    } catch (e) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('An error occurred while loading the form'),
          ),
        );
        Navigator.of(context).pop();
      });
    }
  }

  void _populateForm() {
    if (_existingReport == null) return;
    for (var answer in _existingReport!.answers ?? []) {
      final index = dailyReportQuestions.indexWhere((q) => q.id == answer.qId);
      if (index != -1) {
        _totalControllers[index].text = answer.totalCount.toString();
        _criticalControllers[index].text = answer.criticalCount.toString();
      }
    }
    _updateTotals();
  }

  @override
  void dispose() {
    for (var i = 0; i < dailyReportQuestions.length; i++) {
      _totalControllers[i].removeListener(_updateTotals);
      _totalControllers[i].dispose();
      _criticalControllers[i].removeListener(_updateTotals);
      _criticalControllers[i].dispose();
    }
    super.dispose();
  }

  void _updateTotals() {
    int totalSum = 0;
    int criticalSum = 0;
    for (var i = 0; i < dailyReportQuestions.length; i++) {
      totalSum += int.tryParse(_totalControllers[i].text) ?? 0;
      criticalSum += int.tryParse(_criticalControllers[i].text) ?? 0;
    }
    setState(() {
      _totalSum = totalSum;
      _criticalSum = criticalSum;
    });
  }

  Future<void> _submitForm() async {
    if (!_formKey.currentState!.validate()) return;

    final reportProvider = Provider.of<ReportProvider>(context, listen: false);
    final authProvider = Provider.of<AuthProvider>(context, listen: false);
    final activeScope = authProvider.activeScope!;

    final answers = <ReportAnswer>[];
    for (var i = 0; i < dailyReportQuestions.length; i++) {
      answers.add(
        ReportAnswer(
          qId: dailyReportQuestions[i].id,
          totalCount: int.tryParse(_totalControllers[i].text) ?? 0,
          criticalCount: int.tryParse(_criticalControllers[i].text) ?? 0,
        ),
      );
    }

    final report = DailyReport(
      reportId: _existingReport?.reportId,
      reportDate: _existingReport?.reportDate ?? DateTime.now(),
      commissionerateId: activeScope.commissionerateId,
      divisionId: activeScope.divisionId ?? 'N/A',
      rangeId: activeScope.rangeId!,
      submittedBy: authProvider.userId!,
      answers: answers,
      totalCount: _totalSum,
      criticalCount: _criticalSum,
    );

    String? errorMessage;
    if (_mode == 'new') {
      errorMessage = await reportProvider.insertDailyReport(report);
    } else {
      errorMessage = await reportProvider.updateDailyReport(
        report.reportId!,
        report,
      );
    }

    if (mounted) {
      if (errorMessage != null) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(errorMessage),
            backgroundColor: Theme.of(context).colorScheme.error,
          ),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Report ${_mode == 'new' ? 'submitted' : 'updated'} successfully!',
            ),
            backgroundColor: Colors.green,
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportProvider = Provider.of<ReportProvider>(context);
    final themeProv = Provider.of<ThemeProvider>(context, listen: true);
    final date = DateFormat(
      'dd MMM, yyyy',
    ).format(_existingReport?.reportDate ?? DateTime.now());
    final theme = Theme.of(context);
    final gradientColors = themeProv.gradientColors;

    return Scaffold(
      backgroundColor: gradientColors.first,
      appBar: AppBar(
        title: Text('${_mode == 'new' ? 'New' : 'Edit'} Report - $date'),
        elevation: 6,
        backgroundColor: theme.colorScheme.primary,
        foregroundColor: theme.colorScheme.onPrimary,
        centerTitle: true,
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: gradientColors,
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
          ),
        ),
        child: LoaderOverlay(
          isLoading: reportProvider.isLoading,
          message: 'Saving Report...',
          child: SafeArea(
            child: SingleChildScrollView(
              padding: const EdgeInsets.all(16.0),
              child: Card(
                color: theme.colorScheme.surface,
                elevation: 10,
                shadowColor: theme.colorScheme.primary.withOpacity(0.3),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(18),
                ),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(20, 24, 20, 20),
                  child: Form(
                    key: _formKey,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Text(
                          'Daily Activity Summary',
                          style: theme.textTheme.titleLarge?.copyWith(
                            fontWeight: FontWeight.bold,
                            color: theme.colorScheme.primary,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          'Please fill in the counts for each category below.',
                          style: theme.textTheme.bodySmall?.copyWith(
                            color:
                                theme.colorScheme.onSurface.withOpacity(0.7),
                          ),
                        ),
                        const SizedBox(height: 20),
                        ...List.generate(dailyReportQuestions.length, (index) {
                          return Card(
                            margin: const EdgeInsets.symmetric(vertical: 6.0),
                            elevation: 1.5,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(12),
                            ),
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: 8.0,
                                horizontal: 4,
                              ),
                              child: QuestionRow(
                                question: dailyReportQuestions[index],
                                totalController: _totalControllers[index],
                                criticalController: _criticalControllers[index],
                              ),
                            ),
                          );
                        }),
                        const SizedBox(height: 24),
                        _buildTotalsFooter(theme),
                        const SizedBox(height: 24),
                        const Divider(height: 32),
                        Row(
                          mainAxisAlignment: MainAxisAlignment.end,
                          children: [
                            OutlinedButton(
                              onPressed: () => Navigator.of(context).pop(),
                              style: OutlinedButton.styleFrom(
                                foregroundColor: theme.colorScheme.onSurface,
                                side: BorderSide(
                                  color:
                                      theme.colorScheme.outline.withOpacity(0.6),
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 20,
                                  vertical: 12,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(10),
                                ),
                              ),
                              child: const Text('Cancel'),
                            ),
                            const SizedBox(width: 16),
                            ElevatedButton.icon(
                              onPressed: _submitForm,
                              icon: const Icon(Icons.check_circle_outline),
                              label: Text(
                                _mode == 'new'
                                    ? 'Submit Report'
                                    : 'Update Report',
                              ),
                              style: ElevatedButton.styleFrom(
                                backgroundColor: theme.colorScheme.primary,
                                foregroundColor: theme.colorScheme.onPrimary,
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 26,
                                  vertical: 13,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(12),
                                ),
                                elevation: 4,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalsFooter(ThemeData theme) {
    return Card(
      color: theme.colorScheme.secondaryContainer,
      elevation: 3,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
      ),
      child: Padding(
        padding: const EdgeInsets.all(18.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            _totalCountColumn('Total Count', _totalSum, theme),
            _totalCountColumn('Critical Count', _criticalSum, theme),
          ],
        ),
      ),
    );
  }

  Widget _totalCountColumn(String label, int count, ThemeData theme) {
    final bool isCritical = label == 'Critical Count' && count > 0;

    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(
            fontWeight: FontWeight.w600,
            color: isCritical ? theme.colorScheme.error : theme.colorScheme.onSurface,
          ),
        ),
        const SizedBox(height: 6),
        Text(
          '$count',
          style: theme.textTheme.headlineSmall?.copyWith(
            color: isCritical ? theme.colorScheme.error : theme.colorScheme.primary,
            fontWeight: FontWeight.bold,
          ),
        ),
      ],
    );
  }
}
