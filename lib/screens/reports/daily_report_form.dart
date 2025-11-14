import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../data/questions.dart';
import '../../models/daily_report.dart';
import '../../providers/auth_provider.dart';
import '../../providers/report_provider.dart';
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
      final args = ModalRoute.of(context)?.settings.arguments as Map<String, dynamic>?;
      
      if (args != null && args['mode'] == 'edit') {
        final report = args['report'] as DailyReport?;
        if (report != null) {
          setState(() {
            _mode = 'edit';
            _existingReport = report;
            _populateForm();
          });
        } else {
          // Show error and go back if report data is missing
          WidgetsBinding.instance.addPostFrameCallback((_) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Error: Could not load report data')),
            );
            Navigator.of(context).pop();
          });
        }
      }
    } catch (e) {
      // Handle any unexpected errors
      WidgetsBinding.instance.addPostFrameCallback((_) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('An error occurred while loading the form')),
        );
        Navigator.of(context).pop();
      });
    }
  }

  void _populateForm() {
    if (_existingReport == null) return;
    for (var answer in _existingReport!.answers) {
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
      answers.add(ReportAnswer(
        qId: dailyReportQuestions[i].id,
        totalCount: int.tryParse(_totalControllers[i].text) ?? 0,
        criticalCount: int.tryParse(_criticalControllers[i].text) ?? 0,
      ));
    }

    final report = DailyReport(
      id: _existingReport?.id,
      reportDate: _existingReport?.reportDate ?? DateTime.now(),
      commissionerateId: activeScope.commissionerateId,
      commissionerateName: activeScope.commissionerateName,
      divisionId: activeScope.divisionId ?? 'N/A',
      divisionName: activeScope.divisionName,
      rangeId: activeScope.rangeId!,
      rangeName: activeScope.rangeName,
      submittedBy: authProvider.userId!,
      answers: answers,
      totalCount: _totalSum,
      criticalCount: _criticalSum,
    );

    String? errorMessage;
    if (_mode == 'new') {
      errorMessage = await reportProvider.insertDailyReport(report);
    } else {
      errorMessage = await reportProvider.updateDailyReport(report.id!, report);
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
            content: Text('Report ${_mode == 'new' ? 'submitted' : 'updated'} successfully!'),
            backgroundColor: Colors.green,  // Green snackbar on success
          ),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportProvider = Provider.of<ReportProvider>(context);
    final date = DateFormat('dd MMM, yyyy').format(_existingReport?.reportDate ?? DateTime.now());
    final theme = Theme.of(context);

    return Scaffold(
      appBar: AppBar(
        title: Text('${_mode == 'new' ? 'New' : 'Edit'} Report - $date'),
        elevation: 4,
        backgroundColor: theme.colorScheme.primaryContainer,
        foregroundColor: theme.colorScheme.onPrimaryContainer,
      ),
      body: LoaderOverlay(
        isLoading: reportProvider.isLoading,
        message: 'Saving Report...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Card(
            elevation: 5,
            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            child: Padding(
              padding: const EdgeInsets.all(16.0),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    ...List.generate(dailyReportQuestions.length, (index) {
                      return Padding(
                        padding: const EdgeInsets.symmetric(vertical: 8.0),
                        child: QuestionRow(
                          question: dailyReportQuestions[index],
                          totalController: _totalControllers[index],
                          criticalController: _criticalControllers[index],
                        ),
                      );
                    }),
                    const SizedBox(height: 30),
                    _buildTotalsFooter(theme),
                    const SizedBox(height: 30),
                    const Divider(),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.end,
                      children: [
                        OutlinedButton(
                          onPressed: () => Navigator.of(context).pop(),
                          style: OutlinedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                          ),
                          child: const Text('Cancel'),
                        ),
                        const SizedBox(width: 16),
                        ElevatedButton.icon(
                          onPressed: _submitForm,
                          icon: const Icon(Icons.check_circle_outline),
                          label: Text(_mode == 'new' ? 'Submit Report' : 'Update Report'),
                          style: ElevatedButton.styleFrom(
                            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
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
    );
  }

  Widget _buildTotalsFooter(ThemeData theme) {
    return Card(
      color: theme.colorScheme.surfaceContainerHighest,
      elevation: 2,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
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
    return Column(
      children: [
        Text(
          label,
          style: theme.textTheme.titleSmall?.copyWith(fontWeight: FontWeight.w600),
        ),
        const SizedBox(height: 6),
        Text(
          '$count',
          style: theme.textTheme.headlineSmall?.copyWith(color: theme.colorScheme.primary),
        ),
      ],
    );
  }
}
