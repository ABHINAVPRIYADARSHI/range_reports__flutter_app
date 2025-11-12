// lib/providers/report_provider.dart

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/daily_report.dart';

class ReportProvider with ChangeNotifier {
  // Example of a private variable to hold a fetched report
  DailyReport? _todaysReport;
  DailyReport? get todaysReport => _todaysReport;

  bool _isLoading = false;
  bool get isLoading => _isLoading;

  // Fetches a report for a specific range and date
  Future<void> getReportForRange(String rangeId, DateTime date) async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      final today = DateTime.now().toIso8601String().substring(0, 10);

      final response = await client
          .from('daily_reports')
          .select()
          .eq('range_id', rangeId)
          .eq('report_date', today)
          .limit(1);

      if (response.isNotEmpty) {
        _todaysReport = DailyReport.fromJson(response.first);
      } else {
        _todaysReport = null;
      }
    } catch (e) {
      debugPrint('Error fetching report: $e');
      _todaysReport = null;
    }

    _isLoading = false;
    notifyListeners();
  }

  // Inserts a new daily report
  Future<void> insertDailyReport(DailyReport report) async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      await client.from('daily_reports').insert(report.toJson());
    } catch (e) {
      debugPrint('Error inserting report: $e');
      // Optionally, rethrow or handle the error for the UI
    }

    _isLoading = false;
    notifyListeners();
  }

  // Updates an existing daily report
  Future<void> updateDailyReport(String reportId, DailyReport report) async {
    _isLoading = true;
    notifyListeners();

    // TODO: Implement Supabase call to update the report
    await Future.delayed(const Duration(seconds: 2));
    print('Report updated for ID $reportId: ${report.toJson()}');

    _isLoading = false;
    notifyListeners();
  }
}