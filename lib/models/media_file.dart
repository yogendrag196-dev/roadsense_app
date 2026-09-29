class MediaFile {
  final String id;
  final String complaintId;
  final String url;
  final String type; // photo or video

  MediaFile({
    required this.id,
    required this.complaintId,
    required this.url,
    required this.type,
  });

  factory MediaFile.fromJson(Map<String, dynamic> json) {
    return MediaFile(
      id: json['id'] as String,
      complaintId: json['complaint_id'] as String,
      url: json['url'] as String,
      type: json['type'] as String,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'complaint_id': complaintId,
      'url': url,
      'type': type,
    };
  }
}
