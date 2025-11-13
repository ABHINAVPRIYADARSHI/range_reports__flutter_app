// lib/models/daily_report.dart

class DailyReport {
  final String? id; // Nullable for new reports that don't have a DB ID yet
  final DateTime reportDate;
  final String commissionerateId;
  final String? commissionerateName;
  final String divisionId;
  final String? divisionName;
  final String rangeId;
  final String? rangeName;
  final List<ReportAnswer> answers;
  final int totalCount;
  final int criticalCount;
  final String submittedBy; // User ID
  final String? userName;
  final String? userPhone;

  DailyReport({
    this.id,
    required this.reportDate,
    required this.commissionerateId,
    this.commissionerateName,
    required this.divisionId,
    this.divisionName,
    required this.rangeId,
    this.rangeName,
    required this.answers,
    required this.totalCount,
    required this.criticalCount,
    required this.submittedBy,
    this.userName,
    this.userPhone,
  });

  // Note: A fromJson factory will be added later when we need to fetch data
  Map<String, dynamic> toJson() {
    return {
      // Omit 'id' as the database will generate it on insert
      'report_date': reportDate.toIso8601String().substring(0, 10),
      'commissionerate_id': commissionerateId,
      'commissionerate_name': commissionerateName,
      'division_id': divisionId,
      'division_name': divisionName,
      'range_id': rangeId,
      'range_name': rangeName,
      'answers': answers.map((a) => a.toJson()).toList(),
      'total_count': totalCount,
      'critical_count': criticalCount,
      'submitted_by': submittedBy,
    };
  }

  factory DailyReport.fromJson(Map<String, dynamic> json) {
    final answersList = json['answers'] as List<dynamic>? ?? [];
    return DailyReport(
      id: json['id']?.toString(), // The DB primary key
      reportDate: DateTime.parse(json['report_date'] as String),
      commissionerateId: json['commissionerate_id'] as String,
      commissionerateName: json['commissionerate_name'] as String?,
      divisionId: json['division_id'] as String,
      divisionName: json['division_name'] as String?,
      rangeId: json['range_id'] as String,
      rangeName: json['range_name'] as String?,
      answers: answersList
          .map((a) => ReportAnswer.fromJson(a as Map<String, dynamic>))
          .toList(),
      totalCount: json['total_count'] as int,
      criticalCount: json['critical_count'] as int,
      submittedBy: json['submitted_by'] as String,
      userName: json['user_name'] as String,
      userPhone: json['user_phone'] as String,
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
