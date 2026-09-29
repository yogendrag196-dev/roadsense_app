class Complaint {
  final String id;
  final String? citizenId;
  final String category;
  final String? description;
  final List<String> mediaUrls;
  final dynamic location; // PostGIS geography point, Map, GeoJSON, or WKT
  final String? wardId;
  final String? wardName;
  final String severity;
  final String status;
  final int upvoteCount;
  final DateTime createdAt;

  Complaint({
    required this.id,
    this.citizenId,
    required this.category,
    this.description,
    this.mediaUrls = const [],
    required this.location,
    this.wardId,
    this.wardName,
    required this.severity,
    required this.status,
    this.upvoteCount = 1,
    required this.createdAt,
  });

  factory Complaint.fromJson(Map<String, dynamic> json) {
    return Complaint(
      id: json['id'] as String? ?? '',
      citizenId: (json['citizen_id'] ?? json['user_id']) as String?,
      category: json['category'] as String? ?? 'Road Hazard',
      description: json['description'] as String?,
      mediaUrls: (json['media_urls'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      location: json['location'],
      wardId: json['ward_id'] as String?,
      wardName: json['ward_name'] as String?,
      severity: json['severity'] as String? ?? 'Minor',
      status: json['status'] as String? ?? 'Submitted',
      upvoteCount: (json['upvote_count'] as num?)?.toInt() ?? 1,
      createdAt: json['created_at'] != null
          ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
          : DateTime.now(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'citizen_id': citizenId,
      'user_id': citizenId,
      'category': category,
      'description': description,
      'media_urls': mediaUrls,
      'location': location,
      'ward_id': wardId,
      'ward_name': wardName,
      'severity': severity,
      'status': status,
      'upvote_count': upvoteCount,
      'created_at': createdAt.toIso8601String(),
    };
  }
}
