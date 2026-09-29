class AppUser {
  final String id;
  final String role; // citizen, engineer, admin
  final String? name;
  final int warningCount;
  final bool isBanned;
  final String? banReason;

  AppUser({
    required this.id,
    required this.role,
    this.name,
    this.warningCount = 0,
    this.isBanned = false,
    this.banReason,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) {
    return AppUser(
      id: json['id'] as String,
      role: (json['role'] as String?) ?? 'citizen',
      name: json['name'] as String?,
      warningCount: (json['warning_count'] as num?)?.toInt() ?? 0,
      isBanned: (json['is_banned'] as bool?) ?? false,
      banReason: json['ban_reason'] as String?,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'role': role,
      'name': name,
      'warning_count': warningCount,
      'is_banned': isBanned,
      'ban_reason': banReason,
    };
  }
}
