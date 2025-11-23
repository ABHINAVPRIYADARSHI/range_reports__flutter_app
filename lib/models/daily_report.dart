// lib/models/daily_report.dart

class DailyReport {
  final String? submittedBy; // User ID
  final String? name;
  final String? phone;
  final String commissionerateId;
  final String? commissionerateName;
  final String? divisionId;
  final String? divisionName;
  final String? rangeId;
  final String? rangeName;
  final String? reportId; // Nullable for new reports that don't have a DB ID yet
  final DateTime? reportDate;
  final int? totalCount;
  final int? criticalCount;
  final List<ReportAnswer>? answers;
  final bool? hasSubmitted; 

  DailyReport({
    this.submittedBy,
    this.name,
    this.phone,
    required this.commissionerateId,
    this.commissionerateName,
    this.divisionId,
    this.divisionName,
    this.rangeId,
    this.rangeName,
    this.reportId,
    this.reportDate,
    this.totalCount,
    this.criticalCount,
    this.answers,
    this.hasSubmitted,
  });

  // Note: A fromJson factory will be added later when we need to fetch data
  Map<String, dynamic> toJson() {
    return {
      // Omit 'id' as the database will generate it on insert
      'report_date': reportDate!.toIso8601String().substring(0, 10),
      'commissionerate_id': commissionerateId,
      'commissionerate_name': commissionerateName,
      'division_id': divisionId,
      'division_name': divisionName,
      'range_id': rangeId,
      'range_name': rangeName,
      'answers': answers!.map((a) => a.toJson()).toList(),
      'total_count': totalCount,
      'critical_count': criticalCount,
      'submitted_by': submittedBy,
    };
  }

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    final answersList = json['answers'] as List<dynamic>? ?? [];
    return DailyReport(
      reportId: json['id']?.toString(), // The DB primary key
      // reportDate: DateTime.parse(json['report_date'] as String? ?? ''),
      commissionerateId: json['commissionerate_id'] as String,
      commissionerateName: json['commissionerate_name'] as String? ?? '',
      divisionId: json['division_id'] as String? ?? '',
      divisionName: json['division_name'] as String? ?? '',
      rangeId: json['range_id'] as String? ?? '',
      rangeName: json['range_name'] as String? ?? '',
      answers: answersList
          .map((a) => ReportAnswer.fromJson(a as Map<String, dynamic>))
          .toList(),
      totalCount: json['total_count'] as int? ?? 0,
      criticalCount: json['critical_count'] as int? ?? 0,
      submittedBy: json['submitted_by'] as String? ?? '',
      name: json['name'] as String? ?? '',
      phone: json['phone'] as String? ?? '',
      hasSubmitted: json['has_submitted'] as bool? ?? false,
    );
  }
}

class ReportAnswer {
  final int qId;
  final int totalCount;
  final int criticalCount;

  ReportAnswer({
    required this.qId,
    this.totalCount = 0,
    this.criticalCount = 0,
  });

  Map<String, dynamic> toJson() {
    return {
      'q_id': qId,
      'total_count': totalCount,
      'critical_count': criticalCount,
    };
  }

  factory ReportAnswer.fromJson(Map<String, dynamic> json) {
    return ReportAnswer(
      qId: json['q_id'] as int,
      totalCount: json['total_count'] as int,
      criticalCount: json['critical_count'] as int,
    );
  }
}
