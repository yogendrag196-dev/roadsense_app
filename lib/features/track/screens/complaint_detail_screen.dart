import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../models/complaint.dart';
import '../../../models/ai_assessment.dart';
import '../../../models/work_order.dart';
import '../../../services/db_service.dart';
import '../widgets/timeline_stepper.dart';

final dbServiceProvider = Provider<DBService>((ref) => DBService());

class ComplaintDetailScreen extends ConsumerStatefulWidget {
  final String complaintId;

  const ComplaintDetailScreen({super.key, required this.complaintId});

  @override
  ConsumerState<ComplaintDetailScreen> createState() => _ComplaintDetailScreenState();
}

class _ComplaintDetailScreenState extends ConsumerState<ComplaintDetailScreen> {
  bool _isLoading = true;
  Complaint? _complaint;
  AIAssessment? _assessment;
  WorkOrder? _workOrder;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final dbService = ref.read(dbServiceProvider);
      // Fetch complaint first. Since we don't have a single complaint fetch, we can filter from my complaints or add a getComplaint method.
      // Wait, we can stream the complaint to get live updates.
      final complaints = await dbService.getMyComplaints();
      _complaint = complaints.firstWhere((c) => c.id == widget.complaintId);
      
      // Fetch assessment and work order
      _assessment = await dbService.getAIAssessment(widget.complaintId);
      _workOrder = await dbService.getWorkOrderForComplaint(widget.complaintId);
      
      setState(() {
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<TimelineStep> _buildTimeline(Complaint complaint, WorkOrder? workOrder) {
    final stages = ['Submitted', 'Assigned', 'En Route', 'Repairing', 'Completed'];
    
    // Determine current stage index based on complaint status or work order stage
    int currentIndex = 0;
    if (complaint.status == 'Merged') {
      return [
        TimelineStep(title: 'Submitted', timestamp: complaint.createdAt, isCompleted: true),
        TimelineStep(title: 'Merged', subtitle: 'This was merged with an existing complaint.', isActive: true, isCompleted: true),
      ];
    }
    
    if (workOrder != null) {
      final woStage = workOrder.stage;
      if (woStage == 'queued') {
        currentIndex = 0; // Wait for assignment
      } else if (woStage == 'assigned') currentIndex = 1;
      else if (woStage == 'en_route') currentIndex = 2;
      else if (woStage == 'in_progress') currentIndex = 3;
      else if (woStage == 'completed') currentIndex = 4;
    }
    if (complaint.status == 'Completed') {
      currentIndex = 4;
    }

    return List.generate(stages.length, (index) {
      return TimelineStep(
        title: stages[index],
        isCompleted: index < currentIndex || (index == 4 && complaint.status == 'Completed'),
        isActive: index == currentIndex && complaint.status != 'Completed',
        timestamp: index == 0 ? complaint.createdAt : null, // Would parse from history if available
      );
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_isLoading) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    if (_error != null || _complaint == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Error')),
        body: Center(child: Text('Could not load complaint: $_error')),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Complaint Details'),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Complaint Header
            Row(
              children: [
                Icon(PhosphorIcons.mapPin(PhosphorIconsStyle.fill), color: Colors.blue),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _complaint!.category,
                    style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),

            // Cancelled / Rejected Alert Banner
            if (_complaint!.status.toLowerCase().contains('cancel') ||
                _complaint!.status.toLowerCase().contains('reject') ||
                _complaint!.status.toLowerCase().contains('fake') ||
                _complaint!.status.toLowerCase() == 'merged') ...[
              Container(
                margin: const EdgeInsets.only(bottom: 16),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
                ),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Icon(PhosphorIconsFill.xCircle, color: Colors.redAccent, size: 24),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'REPORT CANCELLED & REJECTED BY AI',
                            style: TextStyle(color: Colors.redAccent, fontWeight: FontWeight.bold, fontSize: 13),
                          ),
                          const SizedBox(height: 4),
                          Text(
                            _assessment?.reason ??
                                (_complaint!.status.toLowerCase() == 'merged'
                                    ? 'Duplicate hazard report at this location - merged and closed.'
                                    : 'This report was flagged as a non-hazard or invalid photo and cancelled.'),
                            style: const TextStyle(color: Colors.white70, fontSize: 12, height: 1.3),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ],

            if (_complaint!.description != null && _complaint!.description!.isNotEmpty)
              Text(_complaint!.description!, style: const TextStyle(fontSize: 16)),
            const SizedBox(height: 24),
            
            // Media (Before photos)
            if (_complaint!.mediaUrls.isNotEmpty) ...[
              const Text('Photos', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              SizedBox(
                height: 120,
                child: ListView.builder(
                  scrollDirection: Axis.horizontal,
                  itemCount: _complaint!.mediaUrls.length,
                  itemBuilder: (context, index) {
                    return Container(
                      margin: const EdgeInsets.only(right: 8),
                      width: 120,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(8),
                        image: DecorationImage(
                          image: NetworkImage(_complaint!.mediaUrls[index]),
                          fit: BoxFit.cover,
                        ),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 24),
            ],

            // AI Reasoning & Photo Authenticity Card
            if (_assessment != null) ...[
              const Text('RoadSense AI Inspection', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
              const SizedBox(height: 10),
              Container(
                decoration: BoxDecoration(
                  color: const Color(0xFF161F2C),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(
                    color: _assessment!.severity.toLowerCase() == 'critical'
                        ? Colors.redAccent.withValues(alpha: 0.5)
                        : _assessment!.severity.toLowerCase() == 'high'
                            ? Colors.orangeAccent.withValues(alpha: 0.5)
                            : const Color(0xFF00B4D8).withValues(alpha: 0.3),
                    width: 1.5,
                  ),
                ),
                padding: const EdgeInsets.all(16.0),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Top Row: Severity & Authenticity Badges
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: [
                        // Severity Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _assessment!.severity.toLowerCase() == 'critical'
                                ? Colors.redAccent.withValues(alpha: 0.2)
                                : _assessment!.severity.toLowerCase() == 'high'
                                    ? Colors.orangeAccent.withValues(alpha: 0.2)
                                    : Colors.tealAccent.withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                PhosphorIcons.warning(PhosphorIconsStyle.fill),
                                size: 14,
                                color: _assessment!.severity.toLowerCase() == 'critical'
                                    ? Colors.redAccent
                                    : _assessment!.severity.toLowerCase() == 'high'
                                        ? Colors.orangeAccent
                                        : Colors.tealAccent,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                'Severity: ${_assessment!.severity}',
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: _assessment!.severity.toLowerCase() == 'critical'
                                      ? Colors.redAccent
                                      : _assessment!.severity.toLowerCase() == 'high'
                                          ? Colors.orangeAccent
                                          : Colors.tealAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Authenticity Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                          decoration: BoxDecoration(
                            color: _assessment!.isAuthentic
                                ? Colors.greenAccent.withValues(alpha: 0.15)
                                : Colors.purpleAccent.withValues(alpha: 0.15),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Icon(
                                _assessment!.isAuthentic
                                    ? PhosphorIcons.shieldCheck(PhosphorIconsStyle.fill)
                                    : PhosphorIcons.scan(PhosphorIconsStyle.fill),
                                size: 14,
                                color: _assessment!.isAuthentic ? Colors.greenAccent : Colors.purpleAccent,
                              ),
                              const SizedBox(width: 5),
                              Text(
                                _assessment!.photoVerdict,
                                style: TextStyle(
                                  fontWeight: FontWeight.bold,
                                  fontSize: 12,
                                  color: _assessment!.isAuthentic ? Colors.greenAccent : Colors.purpleAccent,
                                ),
                              ),
                            ],
                          ),
                        ),
                        // Confidence Badge
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            '${(_assessment!.confidence * 100).toInt()}% Confidence',
                            style: const TextStyle(fontSize: 11, color: Colors.white70, fontWeight: FontWeight.w600),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 12),
                    if (_assessment!.reason != null && _assessment!.reason!.isNotEmpty)
                      Text(
                        _assessment!.reason!,
                        style: const TextStyle(color: Colors.white, fontSize: 13.5, height: 1.4),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 24),
            ],

            // Timeline
            const Text('Timeline', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TimelineStepper(steps: _buildTimeline(_complaint!, _workOrder)),
          ],
        ),
      ),
    );
  }
}
