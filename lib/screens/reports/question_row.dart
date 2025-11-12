// lib/widgets/reports/question_row.dart

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../data/questions.dart';

class QuestionRow extends StatelessWidget {
  final ReportQuestion question;
  final TextEditingController totalController;
  final TextEditingController criticalController;

  const QuestionRow({
    super.key,
    required this.question,
    required this.totalController,
    required this.criticalController,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8.0),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            flex: 3,
            child: Text(question.text),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: _buildNumericFormField(
              controller: totalController,
              labelText: 'Total',
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            flex: 1,
            child: _buildNumericFormField(
              controller: criticalController,
              labelText: 'Critical',
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildNumericFormField({
    required TextEditingController controller,
    required String labelText,
  }) {
    return TextFormField(
      controller: controller,
      decoration: InputDecoration(
        labelText: labelText,
        border: const OutlineInputBorder(),
        contentPadding: const EdgeInsets.symmetric(horizontal: 12.0),
      ),
      keyboardType: TextInputType.number,
      inputFormatters: [FilteringTextInputFormatter.digitsOnly],
      textAlign: TextAlign.center,
      validator: (value) {
        if (value == null || value.isEmpty) {
          return 'Req.'; // A short error message for required
        }
        return null;
      },
    );
  }
}