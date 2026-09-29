import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:fl_chart/fl_chart.dart';
import 'package:phosphor_icons/phosphor_icons.dart';
import '../../../models/ward_stats.dart';
import '../../../services/db_service.dart';
import '../../../core/theme.dart';

final dbServiceProvider = Provider<DBService>((ref) => DBService());

class CityStats {
  int totalReports = 0;
  int resolvedReports = 0;
  int activeReports = 0;
  int dangerousCount = 0;
  int mediumCount = 0;
  int minorCount = 0;
  Map<String, int> categoryBreakdown = {};

  double get resolutionRate {
    if (totalReports == 0) return 0.0;
    return (resolvedReports / totalReports) * 100;
  }
}

class DashboardScreen extends ConsumerStatefulWidget {
  const DashboardScreen({super.key});

  @override
  ConsumerState<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends ConsumerState<DashboardScreen> {
  bool _isLoading = true;
  List<WardStats> _wardStats = [];
  CityStats _cityStats = CityStats();

  @override
  void initState() {
    super.initState();
    _loadData();
  }

  Future<void> _loadData() async {
    try {
      final dbService = ref.read(dbServiceProvider);
      final stats = await dbService.getWardStatsSummary();

      final cityStats = CityStats();
      for (var ward in stats) {
        cityStats.totalReports += ward.totalReports;
        cityStats.resolvedReports += ward.resolvedReports;
        cityStats.activeReports += ward.activeReports;
        cityStats.dangerousCount += ward.dangerousCount;
        cityStats.mediumCount += ward.mediumCount;
        cityStats.minorCount += ward.minorCount;

        ward.categoryBreakdown.forEach((category, count) {
          cityStats.categoryBreakdown[category] = (cityStats.categoryBreakdown[category] ?? 0) + count;
        });
      }

      if (mounted) {
        setState(() {
          _wardStats = stats;
          _cityStats = cityStats;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Widget _buildStatCard(String title, String value, IconData icon, Color color) {
    return Container(
      padding: const EdgeInsets.all(16.0),
      decoration: BoxDecoration(
        color: AppTheme.cardColor,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, color: color, size: 22),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: Colors.white70,
                    fontWeight: FontWeight.bold,
                    fontSize: 12,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            value,
            style: const TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.bold,
              color: Colors.white,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSeverityRow() {
    return Row(
      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
      children: [
        _buildSeverityIndicator('Critical / High', _cityStats.dangerousCount, AppTheme.dangerousRed),
        _buildSeverityIndicator('Medium', _cityStats.mediumCount, AppTheme.secondaryAmber),
        _buildSeverityIndicator('Minor / Low', _cityStats.minorCount, Colors.greenAccent),
      ],
    );
  }

  Widget _buildSeverityIndicator(String label, int count, Color color) {
    return Column(
      children: [
        Text(
          count.toString(),
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: color,
          ),
        ),
        const SizedBox(height: 4),
        Text(
          label,
          style: const TextStyle(
            fontSize: 12,
            color: Colors.white70,
          ),
        ),
      ],
    );
  }

  Widget _buildBarChart() {
    if (_cityStats.categoryBreakdown.isEmpty) {
      return const Center(child: Text('No report categories yet', style: TextStyle(color: Colors.white60)));
    }

    final categories = _cityStats.categoryBreakdown.keys.toList();
    final maxCount = _cityStats.categoryBreakdown.values.fold(0, (maxVal, v) => v > maxVal ? v : maxVal);

    return SizedBox(
      height: 220,
      child: BarChart(
        BarChartData(
          alignment: BarChartAlignment.spaceAround,
          maxY: max(5, maxCount.toDouble() * 1.3),
          barTouchData: const BarTouchData(enabled: true),
          titlesData: FlTitlesData(
            show: true,
            bottomTitles: AxisTitles(
              sideTitles: SideTitles(
                showTitles: true,
                getTitlesWidget: (value, meta) {
                  if (value.toInt() >= 0 && value.toInt() < categories.length) {
                    return Padding(
                      padding: const EdgeInsets.only(top: 8.0),
                      child: Text(
                        categories[value.toInt()],
                        style: const TextStyle(fontSize: 10, color: Colors.white70),
                      ),
                    );
                  }
                  return const Text('');
                },
              ),
            ),
            leftTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            topTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
            rightTitles: const AxisTitles(sideTitles: SideTitles(showTitles: false)),
          ),
          gridData: const FlGridData(show: false),
          borderData: FlBorderData(show: false),
          barGroups: categories.asMap().entries.map((entry) {
            return BarChartGroupData(
              x: entry.key,
              barRods: [
                BarChartRodData(
                  toY: _cityStats.categoryBreakdown[entry.value]!.toDouble(),
                  color: AppTheme.primaryTeal,
                  width: 18,
                  borderRadius: BorderRadius.circular(6),
                ),
              ],
            );
          }).toList(),
        ),
      ),
    );
  }

  Widget _buildLeaderboard() {
    return ListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _wardStats.length,
      itemBuilder: (context, index) {
        final ward = _wardStats[index];
        final isTop3 = index < 3;
        final rankColor = index == 0 ? Colors.amber : (index == 1 ? Colors.grey.shade300 : (index == 2 ? Colors.orange : AppTheme.primaryTeal));

        return Container(
          margin: const EdgeInsets.only(bottom: 8),
          decoration: BoxDecoration(
            color: AppTheme.cardColor,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(
              color: isTop3 ? rankColor.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.05),
            ),
          ),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: rankColor.withValues(alpha: 0.2),
              child: Text(
                '#${index + 1}',
                style: TextStyle(
                  color: rankColor,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
            title: Text(
              ward.wardName,
              style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.white, fontSize: 14),
            ),
            subtitle: Text(
              '${ward.resolvedReports} resolved / ${ward.totalReports} total',
              style: const TextStyle(color: Colors.white60, fontSize: 12),
            ),
            trailing: Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: Colors.green.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '${ward.resolutionRate.toStringAsFixed(0)}% fix',
                style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13, color: Colors.greenAccent),
              ),
            ),
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.scaffoldBackgroundColor,
      appBar: AppBar(
        title: const Text('Bangalore Ward Dashboard', style: TextStyle(fontWeight: FontWeight.bold)),
        centerTitle: true,
      ),
      body: Container(
        decoration: AppTheme.backgroundGradient,
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

    return SingleChildScrollView(
      physics: const AlwaysScrollableScrollPhysics(),
      padding: const EdgeInsets.all(16.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          GridView.count(
            crossAxisCount: 2,
            crossAxisSpacing: 12,
            mainAxisSpacing: 12,
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            childAspectRatio: 1.4,
            children: [
              _buildStatCard('Total Reports', '${_cityStats.totalReports}', PhosphorIconsFill.files, Colors.blueAccent),
              _buildStatCard('Active Issues', '${_cityStats.activeReports}', PhosphorIconsFill.clockCounterClockwise, Colors.orangeAccent),
              _buildStatCard('Resolved', '${_cityStats.resolvedReports}', PhosphorIconsFill.checkCircle, Colors.greenAccent),
              _buildStatCard('Resolution Rate', '${_cityStats.resolutionRate.toStringAsFixed(1)}%', PhosphorIconsFill.chartLineUp, Colors.purpleAccent),
            ],
          ),
          const SizedBox(height: 24),

          const Text('Severity Breakdown', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: _buildSeverityRow(),
          ),
          const SizedBox(height: 24),

          const Text('Complaints by Category', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          Container(
            padding: const EdgeInsets.all(16.0),
            decoration: BoxDecoration(
              color: AppTheme.cardColor,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: _buildBarChart(),
          ),
          const SizedBox(height: 24),

          const Text('Bangalore BBMP Wards Leaderboard', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold, color: Colors.white)),
          const SizedBox(height: 12),
          _buildLeaderboard(),
          const SizedBox(height: 32),
        ],
      ),
    );
  }
}
