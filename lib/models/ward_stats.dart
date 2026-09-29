class WardStats {
  final String wardId;
  final String wardName;
  final int totalReports;
  final int resolvedReports;
  final int activeReports;
  final double resolutionRate;
  final int dangerousCount;
  final int mediumCount;
  final int minorCount;
  final Map<String, int> categoryBreakdown;

  WardStats({
    required this.wardId,
    required this.wardName,
    required this.totalReports,
    required this.resolvedReports,
    required this.activeReports,
    required this.resolutionRate,
    required this.dangerousCount,
    required this.mediumCount,
    required this.minorCount,
    required this.categoryBreakdown,
  });

  factory WardStats.fromJson(Map<String, dynamic> json) {
    final breakdownJson = json['category_breakdown'] as Map<String, dynamic>? ?? {};
    final categoryBreakdown = breakdownJson.map((key, value) => MapEntry(key, value as int));

    return WardStats(
      wardId: json['ward_id'] as String,
      wardName: json['ward_name'] as String,
      totalReports: json['total_reports'] as int,
      resolvedReports: json['resolved_reports'] as int,
      activeReports: json['active_reports'] as int,
      resolutionRate: (json['resolution_rate'] as num).toDouble(),
      dangerousCount: json['dangerous_count'] as int,
      mediumCount: json['medium_count'] as int,
      minorCount: json['minor_count'] as int,
      categoryBreakdown: categoryBreakdown,
    );
  }
}
