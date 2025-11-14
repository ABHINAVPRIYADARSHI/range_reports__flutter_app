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

  // For range officer - Fetches a report for a specific scope and date
  Future<void> getReportForRange({
    required String commissionerateId,
    required String divisionId,
    required String rangeId,
    required DateTime date,
  }) async {
    _isLoading = true;
    notifyListeners();

    try {
      final client = Supabase.instance.client;
      final today = DateTime.now().toIso8601String().substring(0, 10);

      final response = await client
          .from('daily_reports')
          .select()
          .eq('commissionerate_id', commissionerateId)
          .eq('division_id', divisionId)
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
      await client
          .from('daily_reports')
          .update(report.toJson())
          .eq('id', reportId);
    } catch (e) {
      errorMessage = 'An unexpected error occurred. Please try again.';
      debugPrint('Error updating report: $e');
    }

    _isLoading = false;
    notifyListeners();
    return errorMessage;
  }

  // For nodal officer - Fetches all reports based on commissionerate, division, and date
  Future<List<DailyReport>> getReportsForNodal({
    required String commissionerateId,
    required String divisionId,
    required DateTime date,
  }) async {
    // Schedule the loading state update for the next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isLoading == false) { // Only update if not already loading
        _isLoading = true;
        notifyListeners();
      }
    });

    try {
      final client = Supabase.instance.client;
      final dateString = date.toIso8601String().substring(0, 10);

      final response = await client
          .from('daily_reports')
          .select('*, users:submitted_by(name, phone)')
          .eq('commissionerate_id', commissionerateId)
          .eq('division_id', divisionId)
          .eq('report_date', dateString);

      if (response is List) {
        final reports = response.map((json) {
          // Flatten the user data
          final flattenedJson = Map<String, dynamic>.from(json);
          if (json['users'] != null) {
            flattenedJson['user_name'] = json['users']['name'];
            flattenedJson['user_phone'] = json['users']['phone'];
          }
          flattenedJson.remove('users'); // Remove nested object
          return DailyReport.fromJson(flattenedJson);
        }).toList();
         // Sort reports by rangeId (assuming rangeId is a String)
        reports.sort((a, b) {
          final idA = a.rangeId ?? '';
          final idB = b.rangeId ?? '';
          return idA.compareTo(idB);
        });
        return reports;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching reports for nodal officer: $e');
      rethrow;
    } finally {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isLoading = false;
        notifyListeners();
      });
    }
  }

  // For Admin officer - Fetches all reports based on commissionerate & date
  Future<List<DailyReport>> getReportsForAdmin({
    required String commissionerateId,
    required DateTime date,
  }) async {
    // Schedule the loading state update for the next frame
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isLoading == false) { // Only update if not already loading
        _isLoading = true;
        notifyListeners();
      }
    });

    try {
      final client = Supabase.instance.client;
      final dateString = date.toIso8601String().substring(0, 10);

      final response = await client
          .from('daily_reports')
          .select('*, users:submitted_by(name, phone)')
          .eq('commissionerate_id', commissionerateId)
          .eq('report_date', dateString);

      if (response is List) {
        final reports = response.map((json) {
          // Flatten the user data
          final flattenedJson = Map<String, dynamic>.from(json);
          if (json['users'] != null) {
            flattenedJson['user_name'] = json['users']['name'];
            flattenedJson['user_phone'] = json['users']['phone'];
          }
          flattenedJson.remove('users'); // Remove nested object
          return DailyReport.fromJson(flattenedJson);
        }).toList();
        
        // Sort reports by divisionId and then rangeId
        reports.sort((a, b) {
          final divA = a.divisionId ?? '';
          final divB = b.divisionId ?? '';
          if (divA != divB) return divA.compareTo(divB);
          
          final rangeA = a.rangeId ?? '';
          final rangeB = b.rangeId ?? '';
          return rangeA.compareTo(rangeB);
        });
        
        return reports;
      }
      return [];
    } catch (e) {
      debugPrint('Error fetching reports for admin: $e');
      rethrow;
    } finally {
      // Schedule the loading state reset for the next frame
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _isLoading = false;
        notifyListeners();
      });
    }
  }

}
