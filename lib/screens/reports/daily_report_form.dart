// lib/screens/reports/daily_report_form.dart

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

  String _mode = 'new'; // 'new' or 'edit'
  DailyReport? _existingReport;
  bool _isInitialized = false;

  int _totalSum = 0;
  int _criticalSum = 0;

  @override
  void initState() {
    super.initState();
    _totalControllers = List.generate(dailyReportQuestions.length, (_) => TextEditingController(text: '0'));
    _criticalControllers = List.generate(dailyReportQuestions.length, (_) => TextEditingController(text: '0'));

    for (var i = 0; i < dailyReportQuestions.length; i++) {
      _totalControllers[i].addListener(_updateTotals);
      _criticalControllers[i].addListener(_updateTotals);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!_isInitialized) {
      final args = ModalRoute.of(context)!.settings.arguments as Map?;
      if (args != null && args['mode'] == 'edit') {
        _mode = 'edit';
        _existingReport = args['report'] as DailyReport;
        _populateForm();
      }
      _isInitialized = true;
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
      id: _existingReport?.id, // Pass existing ID for updates
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
          SnackBar(content: Text(errorMessage), backgroundColor: Theme.of(context).colorScheme.error),
        );
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Report ${_mode == 'new' ? 'submitted' : 'updated'} successfully!')),
        );
        Navigator.of(context).pop();
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final reportProvider = Provider.of<ReportProvider>(context);
    final date = DateFormat('dd MMM, yyyy').format(_existingReport?.reportDate ?? DateTime.now());

    return Scaffold(
      appBar: AppBar(
        title: Text('${_mode == 'new' ? 'New' : 'Edit'} Report - $date'),
      ),
      body: LoaderOverlay(
        isLoading: reportProvider.isLoading,
        message: 'Saving Report...',
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(16.0),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ...List.generate(dailyReportQuestions.length, (index) {
                  return QuestionRow(
                    question: dailyReportQuestions[index],
                    totalController: _totalControllers[index],
                    criticalController: _criticalControllers[index],
                  );
                }),
                const SizedBox(height: 24),
                _buildTotalsFooter(),
                const SizedBox(height: 24),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                    const SizedBox(width: 12),
                    ElevatedButton.icon(
                      onPressed: _submitForm,
                      icon: const Icon(Icons.check),
                      label: Text(_mode == 'new' ? 'Submit Report' : 'Update Report'),
                    ),
                  ],
                )
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildTotalsFooter() {
    return Card(
      elevation: 2,
      child: Padding(
        padding: const EdgeInsets.all(16.0),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            Column(
              children: [
                const Text('Total Count', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$_totalSum', style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
            Column(
              children: [
                const Text('Critical Count', style: TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('$_criticalSum', style: Theme.of(context).textTheme.headlineSmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}