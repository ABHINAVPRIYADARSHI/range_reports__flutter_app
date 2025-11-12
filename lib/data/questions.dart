// lib/data/questions.dart

class ReportQuestion {
  final int id;
  final String text;

  const ReportQuestion({required this.id, required this.text});
}

const List<ReportQuestion> dailyReportQuestions = [
  ReportQuestion(id: 1, text: 'Application for registration'),
  ReportQuestion(id: 2, text: 'Application for amendment'),
  ReportQuestion(id: 3, text: 'Cancellation proceedings for registration'),
  ReportQuestion(id: 4, text: 'Application for registration as TDS/TCS'),
  ReportQuestion(id: 5, text: 'Application for registration as Non Resident Taxable Person'),
  ReportQuestion(id: 6, text: 'Suo-Moto cancellation proceedings'),
  ReportQuestion(id: 7, text: 'Revocation of cancelled registration'),
  // ToDo: Add the 8th question when available
  // ReportQuestion(id: 8, text: 'Placeholder for 8th question'),
];