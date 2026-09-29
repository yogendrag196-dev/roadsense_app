class WorkOrder {
  final String id;
  final String complaintId;
  final String priority;
  final DateTime slaDeadline;
  final String stage;
  final List<dynamic> history;

  WorkOrder({
    required this.id,
    required this.complaintId,
    required this.priority,
    required this.slaDeadline,
    required this.stage,
    this.history = const [],
  });

  factory WorkOrder.fromJson(Map<String, dynamic> json) {
    return WorkOrder(
      id: json['id'] as String,
      complaintId: json['complaint_id'] as String,
      priority: json['priority'] as String,
      slaDeadline: DateTime.parse(json['sla_deadline'] as String),
      stage: json['stage'] as String,
      history: json['history'] as List<dynamic>? ?? [],
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'complaint_id': complaintId,
      'priority': priority,
      'sla_deadline': slaDeadline.toIso8601String(),
      'stage': stage,
      'history': history,
    };
  }
}
