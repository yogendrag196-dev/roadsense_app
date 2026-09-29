import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../core/theme.dart';
import '../../../core/theme_provider.dart';
import '../../../models/contributor_stats.dart';
import '../../../services/db_service.dart';
import '../../../common/widgets/error_view.dart';
import 'package:go_router/go_router.dart';

class ProfileScreen extends ConsumerStatefulWidget {
  const ProfileScreen({super.key});

  @override
  ConsumerState<ProfileScreen> createState() => _ProfileScreenState();
}

class _ProfileScreenState extends ConsumerState<ProfileScreen> {
  final DBService _dbService = DBService();
  bool _isLoading = true;
  String? _error;

  Map<String, dynamic>? _profile;
  Map<String, dynamic>? _stats;
  List<ContributorStats> _topContributors = [];

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    final user = Supabase.instance.client.auth.currentUser;
    if (user == null) {
      if (mounted) {
        setState(() {
          _error = 'User not logged in';
          _isLoading = false;
        });
      }
      return;
    }

    try {
      if (mounted) {
        setState(() {
          _isLoading = true;
          _error = null;
        });
      }

      final profileFuture = _dbService.getUserProfile();
      final statsFuture = _dbService.getUserStats();
      final contributorsFuture = _dbService.getTopContributors();

      final results = await Future.wait([profileFuture, statsFuture, contributorsFuture]);

      if (mounted) {
        setState(() {
          _profile = results[0] as Map<String, dynamic>?;
          _stats = results[1] as Map<String, dynamic>?;
          final contributorsRaw = results[2] as List<Map<String, dynamic>>? ?? [];
          _topContributors = contributorsRaw
              .map((json) => ContributorStats.fromJson(json))
              .toList();
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _isLoading = false;
        });
      }
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
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.dangerousRed),
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

  Widget _buildStatItem(String label, String value, IconData icon, Color color) {
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getCardBorderColor(context);
    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: AppTheme.softShadows,
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.15),
              shape: BoxShape.circle,
            ),
            child: Icon(icon, color: color, size: 22),
          ),
          const SizedBox(height: 8),
          Text(
            value,
            style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: TextStyle(fontSize: 11, color: subtextColor),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector() {
    final currentTheme = ref.watch(themeModeProvider);
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getCardBorderColor(context);
    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    final themeOptions = [
      {'mode': ThemeMode.dark, 'title': 'Dark', 'icon': PhosphorIconsFill.moon},
      {'mode': ThemeMode.light, 'title': 'Light', 'icon': PhosphorIconsFill.sun},
      {'mode': ThemeMode.system, 'title': 'System', 'icon': PhosphorIconsFill.deviceMobile},
    ];

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: borderColor),
        boxShadow: AppTheme.softShadows,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(8),
                decoration: BoxDecoration(
                  color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: const Icon(PhosphorIconsFill.palette, color: AppTheme.primaryTeal, size: 20),
              ),
              const SizedBox(width: 12),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'App Appearance',
                    style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15, color: textColor),
                  ),
                  Text(
                    'Choose Light, Dark, or System theme',
                    style: TextStyle(fontSize: 12, color: subtextColor),
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: themeOptions.map((opt) {
              final mode = opt['mode'] as ThemeMode;
              final isSelected = currentTheme == mode;
              final icon = opt['icon'] as IconData;
              final title = opt['title'] as String;

              return Expanded(
                child: GestureDetector(
                  onTap: () {
                    HapticFeedback.selectionClick();
                    ref.read(themeModeProvider.notifier).setThemeMode(mode);
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    margin: const EdgeInsets.symmetric(horizontal: 4),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.primaryTeal.withValues(alpha: 0.2)
                          : (Theme.of(context).brightness == Brightness.dark
                              ? Colors.white.withValues(alpha: 0.04)
                              : Colors.black.withValues(alpha: 0.04)),
                      borderRadius: BorderRadius.circular(12),
                      border: Border.all(
                        color: isSelected ? AppTheme.primaryTeal : Colors.transparent,
                        width: 1.5,
                      ),
                    ),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(
                          icon,
                          size: 20,
                          color: isSelected ? AppTheme.primaryTeal : subtextColor,
                        ),
                        const SizedBox(height: 6),
                        Text(
                          title,
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: isSelected ? FontWeight.bold : FontWeight.normal,
                            color: isSelected ? AppTheme.primaryTeal : textColor,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
        ],
      ),
    );
  }

  Widget _buildTopContributors() {
    final cardColor = AppTheme.getCardColor(context);
    final borderColor = AppTheme.getCardBorderColor(context);
    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    if (_topContributors.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16.0),
        child: Text('No contributors recorded yet.', style: TextStyle(color: subtextColor)),
      );
    }

    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _topContributors.length,
      itemBuilder: (context, index) {
        final contributor = _topContributors[index];
        final isFirst = index == 0;
        final initials = contributor.fullName.isNotEmpty
            ? contributor.fullName.trim().split(' ').map((e) => e[0]).take(2).join('').toUpperCase()
            : '?';

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isFirst ? Colors.amber.withValues(alpha: 0.3) : borderColor,
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: isFirst ? Colors.amber : AppTheme.primaryTeal.withValues(alpha: 0.2),
              child: Text(
                initials,
                style: TextStyle(
                  color: isFirst ? Colors.black : AppTheme.primaryTeal,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              contributor.fullName,
              style: TextStyle(fontWeight: FontWeight.bold, color: textColor),
            ),
            subtitle: Text(
              '${contributor.resolvedReports} resolved',
              style: TextStyle(color: subtextColor, fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.primaryTeal.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(10),
              ),
              child: Text(
                '${contributor.totalReports} Reports',
                style: const TextStyle(fontWeight: FontWeight.bold, color: AppTheme.primaryTeal, fontSize: 12),
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

    return Scaffold(
      backgroundColor: scaffoldBg,
      appBar: AppBar(
        title: Text('Citizen Profile', style: TextStyle(fontWeight: FontWeight.bold, color: textColor)),
        centerTitle: true,
        actions: [
          IconButton(
            icon: Icon(PhosphorIconsRegular.signOut, color: textColor.withValues(alpha: 0.7)),
            onPressed: _signOut,
          ),
        ],
      ),
      body: Container(
        decoration: AppTheme.adaptiveBackgroundGradient(context),
        child: RefreshIndicator(
          onRefresh: () async {
            HapticFeedback.lightImpact();
            await _loadData();
          },
          color: AppTheme.primaryTeal,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_isLoading) {
      return const Center(child: CircularProgressIndicator(color: AppTheme.primaryTeal));
    }

    if (_error != null) {
      return SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        child: SizedBox(
          height: MediaQuery.of(context).size.height * 0.8,
          child: ErrorView(
            message: _error!,
            onRetry: _loadData,
          ),
        ),
      );
    }

    final user = Supabase.instance.client.auth.currentUser;
    final name = _profile?['name'] ?? _profile?['full_name'] ?? user?.email?.split('@').first ?? 'Citizen';
    final email = _profile?['email'] ?? user?.email ?? 'No email';
    final role = _profile?['role'] ?? 'citizen';
    final initials = name.trim().isNotEmpty
        ? name.trim().split(' ').map((e) => e[0]).take(2).join('').toUpperCase()
        : 'C';

    final totalReports = _stats?['total_reports'] ?? 0;
    final resolvedReports = _stats?['resolved_reports'] ?? 0;
    final upvotes = _stats?['total_upvotes'] ?? 0;

    final textColor = AppTheme.getTextColor(context);
    final subtextColor = AppTheme.getSubtextColor(context);

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          CircleAvatar(
            radius: 48,
            backgroundColor: AppTheme.primaryTeal,
            child: Text(
              initials,
              style: const TextStyle(fontSize: 28, fontWeight: FontWeight.bold, color: Colors.white),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            name,
            style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold, color: textColor),
          ),
          const SizedBox(height: 4),
          Text(
            email,
            style: TextStyle(fontSize: 14, color: subtextColor),
          ),
          const SizedBox(height: 10),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
            decoration: BoxDecoration(
              color: role == 'citizen' ? Colors.blue.withValues(alpha: 0.15) : Colors.orange.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: role == 'citizen' ? Colors.blueAccent : Colors.orangeAccent,
              ),
            ),
            child: Text(
              role == 'citizen' ? 'Civic Reporter (Bangalore)' : 'City Engineer',
              style: TextStyle(
                color: role == 'citizen' ? Colors.blueAccent : Colors.orangeAccent,
                fontWeight: FontWeight.bold,
                fontSize: 12,
              ),
            ),
          ),
          const SizedBox(height: 24),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildStatItem('My Reports', '$totalReports', PhosphorIconsFill.files, Colors.blueAccent),
              _buildStatItem('Resolved', '$resolvedReports', PhosphorIconsFill.checkCircle, Colors.greenAccent),
              _buildStatItem('Upvotes', '$upvotes', PhosphorIconsFill.thumbsUp, Colors.amberAccent),
            ],
          ),
          const SizedBox(height: 24),
          _buildThemeSelector(),
          const SizedBox(height: 28),
          Align(
            alignment: Alignment.centerLeft,
            child: Text(
              'Bangalore Top Civic Champions',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: textColor),
            ),
          ),
          const SizedBox(height: 12),
          _buildTopContributors(),
          const SizedBox(height: 28),
          SizedBox(
            width: double.infinity,
            child: OutlinedButton.icon(
              onPressed: _signOut,
              icon: const Icon(PhosphorIconsRegular.signOut),
              label: const Text('Sign Out of RoadSense AI'),
              style: OutlinedButton.styleFrom(
                foregroundColor: AppTheme.dangerousRed,
                side: const BorderSide(color: AppTheme.dangerousRed),
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
            ),
          ),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
