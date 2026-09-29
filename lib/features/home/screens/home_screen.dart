import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../../core/theme.dart';
import '../../../models/complaint.dart';
import '../../../services/db_service.dart';
import '../../track/screens/track_screen.dart';
import '../../dashboard/screens/dashboard_screen.dart';
import '../../profile/screens/profile_screen.dart';
import '../../track/widgets/complaint_card.dart';

final homeDbServiceProvider = Provider<DBService>((ref) => DBService());

class HomeScreen extends ConsumerStatefulWidget {
  const HomeScreen({super.key});

  @override
  ConsumerState<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends ConsumerState<HomeScreen> {
  int _currentIndex = 0;
  Map<String, dynamic>? _userProfile;
  Map<String, dynamic>? _userStats;

  @override
  void initState() {
    super.initState();
    _loadUserProfile();
  }

  Future<void> _loadUserProfile() async {
    final session = Supabase.instance.client.auth.currentSession;
    if (session == null) return;

    try {
      final dbService = ref.read(homeDbServiceProvider);
      final profile = await dbService.getUserProfile();
      final stats = await dbService.getUserStats();
      if (mounted) {
        setState(() {
          _userProfile = profile;
          _userStats = stats;
        });
      }
    } catch (_) {
      // Graceful fallback to default session details
    }
  }

  Future<void> _signOut() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.getCardColor(context),
        title: Text('Sign Out', style: TextStyle(color: AppTheme.getTextColor(context))),
        content: Text(
          'Are you sure you want to sign out of RoadSense AI?',
          style: TextStyle(color: AppTheme.getSubtextColor(context)),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.dangerousRed,
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Sign Out', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      await Supabase.instance.client.auth.signOut();
      if (mounted) {
        context.go('/login');
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final scaffoldBg = AppTheme.getScaffoldColor(context);
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getCardBorderColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    // 4 Primary Views: Home Hub, My Complaints, City Dashboard, Profile
    final pages = [
      _buildHomeFeed(),
      const TrackScreen(),
      const DashboardScreen(),
      const ProfileScreen(),
    ];

    return Scaffold(
      backgroundColor: scaffoldBg,
      body: Container(
        decoration: AppTheme.adaptiveBackgroundGradient(context),
        child: IndexedStack(
          index: _currentIndex,
          children: pages,
        ),
      ),
      bottomNavigationBar: Container(
        decoration: BoxDecoration(
          color: cardColor,
          boxShadow: AppTheme.softShadows,
          border: Border(
            top: BorderSide(
              color: borderColor,
              width: 1,
            ),
          ),
        ),
        child: SafeArea(
          child: NavigationBarTheme(
            data: NavigationBarThemeData(
              indicatorColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
              labelTextStyle: WidgetStateProperty.resolveWith((states) {
                if (states.contains(WidgetState.selected)) {
                  return const TextStyle(
                    fontSize: 12,
                    fontWeight: FontWeight.bold,
                    color: AppTheme.primaryTeal,
                  );
                }
                return TextStyle(
                  fontSize: 12,
                  color: subtextColor,
                );
              }),
            ),
            child: NavigationBar(
              height: 65,
              backgroundColor: Colors.transparent,
              selectedIndex: _currentIndex,
              onDestinationSelected: (index) {
                HapticFeedback.selectionClick();
                setState(() => _currentIndex = index);
              },
              destinations: const [
                NavigationDestination(
                  icon: Icon(PhosphorIconsRegular.house),
                  selectedIcon: Icon(PhosphorIconsFill.house, color: AppTheme.primaryTeal),
                  label: 'Home',
                ),
                NavigationDestination(
                  icon: Icon(PhosphorIconsRegular.listBullets),
                  selectedIcon: Icon(PhosphorIconsFill.listBullets, color: AppTheme.primaryTeal),
                  label: 'Track',
                ),
                NavigationDestination(
                  icon: Icon(PhosphorIconsRegular.chartBar),
                  selectedIcon: Icon(PhosphorIconsFill.chartBar, color: AppTheme.primaryTeal),
                  label: 'Dashboard',
                ),
                NavigationDestination(
                  icon: Icon(PhosphorIconsRegular.user),
                  selectedIcon: Icon(PhosphorIconsFill.user, color: AppTheme.primaryTeal),
                  label: 'Profile',
                ),
              ],
            ),
          ),
        ),
      ),
      floatingActionButton: _currentIndex == 0
          ? FloatingActionButton.extended(
              onPressed: () {
                HapticFeedback.lightImpact();
                context.push('/report');
              },
              backgroundColor: AppTheme.primaryTeal,
              elevation: 6,
              icon: const Icon(PhosphorIconsBold.plus, color: Colors.white),
              label: const Text(
                'Report Hazard',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  letterSpacing: 0.5,
                ),
              ),
            )
          : null,
    );
  }

  Widget _buildHomeFeed() {
    final user = Supabase.instance.client.auth.currentUser;
    final userName = _userProfile?['name'] ?? user?.email?.split('@').first ?? 'Citizen';
    final role = _userProfile?['role'] ?? 'citizen';
    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    return SafeArea(
      child: RefreshIndicator(
        onRefresh: _loadUserProfile,
        color: AppTheme.primaryTeal,
        child: SingleChildScrollView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 20.0, vertical: 16.0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 1. Top Header Row
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      GestureDetector(
                        onTap: () => setState(() => _currentIndex = 3),
                        child: CircleAvatar(
                          radius: 24,
                          backgroundColor: AppTheme.primaryTeal.withValues(alpha: 0.2),
                          child: Text(
                            userName.isNotEmpty ? userName[0].toUpperCase() : 'U',
                            style: const TextStyle(
                              color: AppTheme.primaryTeal,
                              fontWeight: FontWeight.bold,
                              fontSize: 18,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Hello, $userName 👋',
                            style: TextStyle(
                              fontSize: 18,
                              fontWeight: FontWeight.bold,
                              color: textColor,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Row(
                            children: [
                              Container(
                                width: 8,
                                height: 8,
                                decoration: const BoxDecoration(
                                  color: Colors.greenAccent,
                                  shape: BoxShape.circle,
                                ),
                              ),
                              const SizedBox(width: 6),
                              Text(
                                role == 'engineer' ? 'City Engineer' : 'Active Citizen Reporter',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: subtextColor,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    ],
                  ),
                  Row(
                    children: [
                      IconButton(
                        tooltip: 'Notifications',
                        icon: Icon(PhosphorIconsRegular.bell, color: subtextColor),
                        onPressed: () => context.push('/notifications-permission'),
                      ),
                      IconButton(
                        tooltip: 'Sign Out / Switch Account',
                        icon: Icon(PhosphorIconsRegular.signOut, color: subtextColor),
                        onPressed: _signOut,
                      ),
                    ],
                  ),
                ],
              ),
              const SizedBox(height: 24),

              // 2. Hero Action Card: "Report Road Hazard"
              _buildHeroReportCard(),
              const SizedBox(height: 24),

              // 3. Quick Stats Ribbon
              _buildQuickStatsRibbon(),
              const SizedBox(height: 24),

              // 4. Quick Actions Grid
              Text(
                'Quick Navigation',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                  color: textColor,
                ),
              ),
              const SizedBox(height: 12),
              _buildQuickActionsGrid(),
              const SizedBox(height: 28),

              // 5. Recent Complaints Live Stream
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Your Recent Reports',
                    style: TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  TextButton(
                    onPressed: () => setState(() => _currentIndex = 1),
                    child: const Text(
                      'View All',
                      style: TextStyle(
                        color: AppTheme.primaryTeal,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              _buildRecentComplaintsSection(),
              const SizedBox(height: 80), // bottom padding for FAB
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeroReportCard() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(20.0),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [
            Color(0xFF0E7C7B),
            Color(0xFF144D4D),
            Color(0xFF1E1E2A),
          ],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(20),
        boxShadow: [
          BoxShadow(
            color: AppTheme.primaryTeal.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.black.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(
                    color: Colors.white.withValues(alpha: 0.2),
                  ),
                ),
                child: const Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(PhosphorIconsFill.sparkle, size: 14, color: Colors.amber),
                    SizedBox(width: 4),
                    Text(
                      'AI Powered Assessment',
                      style: TextStyle(
                        fontSize: 11,
                        color: Colors.white,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                PhosphorIconsFill.shieldWarning,
                color: Colors.white70,
                size: 28,
              ),
            ],
          ),
          const SizedBox(height: 16),
          const Text(
            'Spot a Pothole or Hazard?',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
              letterSpacing: 0.3,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            'Take a quick photo. Our AI automatically classifies severity, verifies duplicate reports, and dispatches municipal work orders.',
            style: TextStyle(
              fontSize: 13,
              color: Colors.white.withValues(alpha: 0.9),
              height: 1.4,
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: ElevatedButton.icon(
                  onPressed: () {
                    HapticFeedback.mediumImpact();
                    context.push('/report');
                  },
                  icon: const Icon(PhosphorIconsBold.camera, size: 18),
                  label: const Text(
                    'REPORT NOW',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: Colors.white,
                    foregroundColor: const Color(0xFF0E7C7B),
                    elevation: 2,
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              OutlinedButton(
                onPressed: () => setState(() => _currentIndex = 1),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: BorderSide(color: Colors.white.withValues(alpha: 0.6)),
                  padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                  ),
                ),
                child: const Text('Track Live'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildQuickStatsRibbon() {
    final totalReports = _userStats?['total_reports'] ?? 0;
    final resolvedReports = _userStats?['resolved_reports'] ?? 0;
    final totalUpvotes = _userStats?['total_upvotes'] ?? 0;
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getCardBorderColor(context);

    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: AppTheme.softShadows,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _buildStatItem('My Reports', '$totalReports', PhosphorIconsFill.files, Colors.blueAccent),
          Container(height: 35, width: 1, color: borderColor),
          _buildStatItem('Resolved', '$resolvedReports', PhosphorIconsFill.checkCircle, Colors.greenAccent),
          Container(height: 35, width: 1, color: borderColor),
          _buildStatItem('Impact / Upvotes', '$totalUpvotes', PhosphorIconsFill.thumbsUp, Colors.amberAccent),
        ],
      ),
    );
  }

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    return Column(
      children: [
        Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 16, color: color),
            const SizedBox(width: 6),
            Text(
              value,
              style: TextStyle(
                fontSize: 18,
                fontWeight: FontWeight.bold,
                color: textColor,
              ),
            ),
          ],
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: TextStyle(
            fontSize: 11,
            color: subtextColor,
          ),
        ),
      ],
    );
  }

  Widget _buildQuickActionsGrid() {
    return GridView.count(
      crossAxisCount: 2,
      crossAxisSpacing: 14,
      mainAxisSpacing: 14,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      childAspectRatio: 1.35,
      children: [
        _buildActionTile(
          title: 'Report Hazard',
          subtitle: 'Camera & GPS',
          icon: PhosphorIconsFill.cameraPlus,
          color: AppTheme.primaryTeal,
          onTap: () => context.push('/report'),
        ),
        _buildActionTile(
          title: 'My Complaints',
          subtitle: 'Live Tracking & Status',
          icon: PhosphorIconsFill.clockCounterClockwise,
          color: Colors.orangeAccent,
          onTap: () => setState(() => _currentIndex = 1),
        ),
        _buildActionTile(
          title: 'Ward Stats',
          subtitle: 'City Resolution Rates',
          icon: PhosphorIconsFill.chartLineUp,
          color: Colors.purpleAccent,
          onTap: () => setState(() => _currentIndex = 2),
        ),
        _buildActionTile(
          title: 'Leaderboard',
          subtitle: 'Top Contributors',
          icon: PhosphorIconsFill.trophy,
          color: Colors.amberAccent,
          onTap: () => setState(() => _currentIndex = 3),
        ),
      ],
    );
  }

  Widget _buildActionTile({
    required String title,
    required String subtitle,
    required IconData icon,
    required Color color,
    required VoidCallback onTap,
  }) {
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getCardBorderColor(context);
    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.all(16.0),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: borderColor),
            boxShadow: AppTheme.softShadows,
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Icon(icon, color: color, size: 22),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.bold,
                      color: textColor,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    subtitle,
                    style: TextStyle(
                      fontSize: 11,
                      color: subtextColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRecentComplaintsSection() {
    final dbService = ref.read(homeDbServiceProvider);
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getCardBorderColor(context);
    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    return StreamBuilder<List<Complaint>>(
      stream: dbService.watchMyComplaints(),
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting && !snapshot.hasData) {
          return const Center(
            child: Padding(
              padding: EdgeInsets.all(24.0),
              child: CircularProgressIndicator(color: AppTheme.primaryTeal),
            ),
          );
        }

        final complaints = snapshot.data ?? [];
        if (complaints.isEmpty) {
          return Container(
            width: double.infinity,
            padding: const EdgeInsets.all(24.0),
            decoration: BoxDecoration(
              color: cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: borderColor),
              boxShadow: AppTheme.softShadows,
            ),
            child: Column(
              children: [
                Icon(
                  PhosphorIconsRegular.trafficCone,
                  size: 48,
                  color: subtextColor.withValues(alpha: 0.5),
                ),
                const SizedBox(height: 12),
                Text(
                  'No reports submitted yet',
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: textColor,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Report potholes, damaged roads, or open drains to keep your city safe.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 12,
                    color: subtextColor,
                  ),
                ),
                const SizedBox(height: 16),
                ElevatedButton.icon(
                  onPressed: () => context.push('/report'),
                  icon: const Icon(PhosphorIconsRegular.camera, size: 16),
                  label: const Text('Submit First Report'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.primaryTeal,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                ),
              ],
            ),
          );
        }

        // Show top 3 recent complaints
        final previewComplaints = complaints.take(3).toList();
        return Column(
          children: previewComplaints.map((complaint) {
            return ComplaintCard(
              complaint: complaint,
              onTap: () => context.push('/track/${complaint.id}'),
            );
          }).toList(),
        );
      },
    );
  }
}
