import 'package:flutter/material.dart';
import 'package:timeago/timeago.dart' as timeago;

class TimelineStep {
  final String title;
  final String? subtitle;
  final DateTime? timestamp;
  final bool isCompleted;
  final bool isActive;

  TimelineStep({
    required this.title,
    this.subtitle,
    this.timestamp,
    this.isCompleted = false,
    this.isActive = false,
  });
}

class TimelineStepper extends StatelessWidget {
  final List<TimelineStep> steps;

  const TimelineStepper({super.key, required this.steps});

  @override
  Widget build(BuildContext context) {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: steps.length,
      itemBuilder: (context, index) {
        final step = steps[index];
        final isLast = index == steps.length - 1;

        return IntrinsicHeight(
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Indicator & Line Column
              SizedBox(
                width: 40,
                child: Column(
                  children: [
                    Container(
                      width: 24,
                      height: 24,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: step.isCompleted
                            ? Colors.green
                            : (step.isActive ? Colors.blue : Colors.grey.shade300),
                        border: step.isActive
                            ? Border.all(color: Colors.blue.shade200, width: 4)
                            : null,
                      ),
                      child: step.isCompleted
                          ? const Icon(Icons.check, size: 14, color: Colors.white)
                          : null,
                    ),
                    if (!isLast)
                      Expanded(
                        child: Container(
                          width: 2,
                          color: step.isCompleted ? Colors.green : Colors.grey.shade300,
                        ),
                      ),
                  ],
                ),
              ),
              // Content Column
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(bottom: 24.0, left: 8.0),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        step.title,
                        style: TextStyle(
                          fontWeight: step.isActive ? FontWeight.bold : FontWeight.w600,
                          fontSize: 16,
                          color: step.isCompleted || step.isActive ? Colors.black87 : Colors.grey.shade500,
                        ),
                      ),
                      if (step.subtitle != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          step.subtitle!,
                          style: TextStyle(fontSize: 14, color: Colors.grey.shade600),
                        ),
                      ],
                      if (step.timestamp != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          timeago.format(step.timestamp!),
                          style: TextStyle(fontSize: 12, color: Colors.grey.shade500),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}
