class Ward {
  final String id;
  final String name;
  final int? wardNumber;
  final double? centerLat;
  final double? centerLng;
  final double resolutionRate;
  final int totalReports;
  final int resolvedReports;

  Ward({
    required this.id,
    required this.name,
    this.wardNumber,
    this.centerLat,
    this.centerLng,
    required this.resolutionRate,
    this.totalReports = 0,
    this.resolvedReports = 0,
  });

  factory Ward.fromJson(Map<String, dynamic> json) {
    return Ward(
      id: json['id'] as String? ?? '',
      name: json['name'] as String? ?? 'Bangalore Ward',
      wardNumber: (json['ward_number'] as num?)?.toInt(),
      centerLat: (json['center_lat'] as num?)?.toDouble(),
      centerLng: (json['center_lng'] as num?)?.toDouble(),
      resolutionRate: (json['resolution_rate'] as num?)?.toDouble() ?? 0.0,
      totalReports: (json['total_reports'] as num?)?.toInt() ?? 0,
      resolvedReports: (json['resolved_reports'] as num?)?.toInt() ?? 0,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'ward_number': wardNumber,
      'center_lat': centerLat,
      'center_lng': centerLng,
      'resolution_rate': resolutionRate,
      'total_reports': totalReports,
      'resolved_reports': resolvedReports,
    };
  }
}
