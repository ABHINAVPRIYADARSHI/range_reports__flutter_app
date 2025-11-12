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

  // Inserts a new daily report. Returns an error message on failure.
  Future<String?> insertDailyReport(DailyReport report) async {
    _isLoading = true;
    notifyListeners();
    String? errorMessage;

    try {
      final client = Supabase.instance.client;
      await client.from('daily_reports').insert(report.toJson());
    } on PostgrestException catch (e) {
      if (e.code == '23505') {
        errorMessage = 'A report for this date has already been submitted.';
      } else {
        errorMessage = 'Database Error: ${e.message}';
      }
      debugPrint('Error inserting report: $e');
    } catch (e) {
      errorMessage = 'An unexpected error occurred. Please try again.';
      debugPrint('Error inserting report: $e');
    }

    _isLoading = false;
    notifyListeners();
    return errorMessage;
  }

  // Updates an existing daily report. Returns an error message on failure.
  Future<String?> updateDailyReport(String reportId, DailyReport report) async {
    _isLoading = true;
    notifyListeners();
    String? errorMessage;

    try {
      final client = Supabase.instance.client;
      await client.from('daily_reports').update(report.toJson()).eq('id', reportId);
    } catch (e) {
      errorMessage = 'An unexpected error occurred. Please try again.';
      debugPrint('Error updating report: $e');
    }

    _isLoading = false;
    notifyListeners();
    return errorMessage;
  }
}