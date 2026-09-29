import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:roadsense_app/core/theme.dart';
import 'package:roadsense_app/features/report/widgets/report_step_widgets.dart';

void main() {
  testWidgets('ReportFlowStepIndicator renders steps correctly', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.darkTheme,
        home: const Scaffold(
          body: ReportFlowStepIndicator(currentStep: 2, totalSteps: 5),
        ),
      ),
    );

    expect(find.textContaining('Duplicates'), findsOneWidget);
    expect(find.text('60% Completed'), findsOneWidget);
  });
}
