class ContributorStats {
  final String citizenId;
  final String name;
  final int totalReports;
  final int resolvedReports;
  final int totalUpvotes;

  String get fullName => name;

  ContributorStats({
    required this.citizenId,
    required this.name,
    required this.totalReports,
    required this.resolvedReports,
    required this.totalUpvotes,
  });

  factory ContributorStats.fromJson(Map<String, dynamic> json) {
    return ContributorStats(
      citizenId: (json['citizen_id'] ?? json['id'] ?? '') as String,
      name: (json['name'] ?? json['full_name']) as String? ?? 'Anonymous',
      totalReports: (json['total_reports'] as num?)?.toInt() ?? 0,
      resolvedReports: (json['resolved_reports'] as num?)?.toInt() ?? 0,
      totalUpvotes: (json['total_upvotes'] as num?)?.toInt() ?? 0,
    );
  }
}
