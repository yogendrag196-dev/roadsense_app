import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../models/complaint.dart';
import '../../../services/db_service.dart';
import '../widgets/complaint_card.dart';
import '../../../common/widgets/skeleton_loader.dart';
import '../../../common/widgets/error_view.dart';
import '../../../core/theme.dart';

final dbServiceProvider = Provider<DBService>((ref) => DBService());

class TrackScreen extends ConsumerStatefulWidget {
  const TrackScreen({super.key});

  @override
  ConsumerState<TrackScreen> createState() => _TrackScreenState();
}

class _TrackScreenState extends ConsumerState<TrackScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late Stream<List<Complaint>> _complaintsStream;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 4, vsync: this);
    _initStream();
  }

  void _initStream() {
    setState(() {
      _complaintsStream = ref.read(dbServiceProvider).watchMyComplaints();
    });
  }

  Future<void> _onRefresh() async {
    HapticFeedback.lightImpact();
    _initStream();
    await Future.delayed(const Duration(milliseconds: 600));
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Widget _buildEmptyState(String filterType) {
    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32.0),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              filterType == 'Cancelled'
                  ? PhosphorIconsRegular.xCircle
                  : PhosphorIconsRegular.trafficCone,
              size: 64,
              color: filterType == 'Cancelled'
                  ? Colors.redAccent.withValues(alpha: 0.4)
                  : subtextColor.withValues(alpha: 0.4),
            ),
            const SizedBox(height: 16),
            Text(
              filterType == 'All'
                  ? 'No complaints submitted yet'
                  : filterType == 'Cancelled'
                      ? 'No Cancelled Complaints'
                      : 'No $filterType complaints',
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              filterType == 'Cancelled'
                  ? 'Complaints flagged or rejected by AI for non-hazard or invalid photos appear here.'
                  : 'Report road hazards, potholes, or waterlogging in Bangalore to track resolution progress here.',
              textAlign: TextAlign.center,
              style: TextStyle(
                fontSize: 13,
                color: subtextColor,
                height: 1.4,
              ),
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => context.push('/report'),
              icon: const Icon(PhosphorIconsBold.plus, size: 18),
              label: const Text('Report Hazard'),
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.primaryTeal,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            )
          ],
        ),
      ),
    );
  }

  Widget _buildList(List<Complaint> complaints, String filterType) {
    if (complaints.isEmpty) {
      return RefreshIndicator(
        onRefresh: _onRefresh,
        color: AppTheme.primaryTeal,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          child: SizedBox(
            height: MediaQuery.of(context).size.height * 0.6,
            child: _buildEmptyState(filterType),
          ),
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _onRefresh,
      color: AppTheme.primaryTeal,
      child: ListView.builder(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.only(top: 12, bottom: 32),
        itemCount: complaints.length,
        itemBuilder: (context, index) {
          final complaint = complaints[index];
          return ComplaintCard(
            complaint: complaint,
            onTap: () {
              context.push('/track/${complaint.id}');
            },
          );
        },
      ),
    );
  }

  Widget _buildLoadingSkeletons() {
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getCardBorderColor(context);

    return ListView.builder(
      padding: const EdgeInsets.only(top: 12, bottom: 24),
      itemCount: 4,
      itemBuilder: (context, index) {
        return Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: Card(
            elevation: 0,
            color: cardColor,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: borderColor),
            ),
            child: const Padding(
              padding: EdgeInsets.all(16.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      SkeletonLoader(width: 44, height: 44, borderRadius: 22),
                      SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            SkeletonLoader(width: double.infinity, height: 16),
                            SizedBox(height: 8),
                            SkeletonLoader(width: 120, height: 12),
                          ],
                        ),
                      ),
                    ],
                  ),
                  SizedBox(height: 16),
                  SkeletonLoader(width: double.infinity, height: 14),
                  SizedBox(height: 8),
                  SkeletonLoader(width: 200, height: 14),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = AppTheme.getScaffoldColor(context);
    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text('My Complaints', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        centerTitle: true,
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryTeal,
          indicatorWeight: 3,
          labelColor: AppTheme.primaryTeal,
          unselectedLabelColor: subtextColor,
          isScrollable: false,
          tabs: const [
            Tab(text: 'All'),
            Tab(text: 'Active'),
            Tab(text: 'Completed'),
            Tab(text: 'Cancelled'),
          ],
        ),
      ),
      body: Container(
        decoration: AppTheme.adaptiveBackgroundGradient(context),
        child: StreamBuilder<List<Complaint>>(
          stream: _complaintsStream,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
              return _buildLoadingSkeletons();
            }

            if (snapshot.hasError) {
              return ErrorView(
                message: snapshot.error.toString(),
                onRetry: _initStream,
              );
            }

            final allComplaints = snapshot.data ?? [];
            
            // Cancelled complaints (AI rejected, fake photos, merged duplicates)
            final cancelledComplaints = allComplaints.where((c) {
              final s = c.status.toLowerCase();
              return s.contains('cancel') || s.contains('reject') || s.contains('fake') || s.contains('invalid') || s == 'merged';
            }).toList();

            // Completed complaints (resolved real hazards)
            final completedComplaints = allComplaints.where((c) {
              final s = c.status.toLowerCase();
              return (s == 'completed' || s == 'resolved') && !s.contains('cancel') && !s.contains('reject') && s != 'merged';
            }).toList();

            // Active complaints (in progress / assigned)
            final activeComplaints = allComplaints.where((c) {
              final s = c.status.toLowerCase();
              return !s.contains('cancel') && !s.contains('reject') && !s.contains('fake') && !s.contains('invalid') && s != 'merged' && s != 'completed' && s != 'resolved';
            }).toList();

            return TabBarView(
              controller: _tabController,
              children: [
                _buildList(allComplaints, 'All'),
                _buildList(activeComplaints, 'Active'),
                _buildList(completedComplaints, 'Completed'),
                _buildList(cancelledComplaints, 'Cancelled'),
              ],
            );
          },
        ),
      ),
    );
  }
}
