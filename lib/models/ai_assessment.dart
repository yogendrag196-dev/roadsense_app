class AIAssessment {
  final String id;
  final String complaintId;
  final String severity;
  final double confidence;
  final String? reason;
  final String? duplicateOf; // ID of the complaint it is a duplicate of
  final bool isAuthentic;
  final double authenticityScore;
  final String photoVerdict;
  final bool isAiGenerated;

  AIAssessment({
    required this.id,
    required this.complaintId,
    required this.severity,
    required this.confidence,
    this.reason,
    this.duplicateOf,
    this.isAuthentic = true,
    this.authenticityScore = 0.95,
    this.photoVerdict = 'Real Photo',
    this.isAiGenerated = false,
  });

  factory AIAssessment.fromJson(Map<String, dynamic> json) {
    final verdict = (json['photo_verdict'] as String?) ?? 'Real Photo';
    final isAuth = json['is_authentic'] as bool? ?? (verdict == 'Real Photo');
    final authScore = json['authenticity_score'] != null
        ? (json['authenticity_score'] as num).toDouble()
        : (isAuth ? 0.95 : 0.40);
    final isAi = json['is_ai_generated'] as bool? ?? (verdict.toLowerCase().contains('ai'));

    return AIAssessment(
      id: json['id'] as String? ?? json['complaint_id'] as String? ?? '',
      complaintId: (json['complaint_id'] as String?) ?? '',
      severity: (json['severity'] as String?) ?? 'Medium',
      confidence: json['confidence'] != null ? (json['confidence'] as num).toDouble() : 0.85,
      reason: (json['reason'] as String?) ?? (json['reasoning'] as String?),
      duplicateOf: json['duplicate_of'] as String?,
      isAuthentic: isAuth,
      authenticityScore: authScore,
      photoVerdict: verdict,
      isAiGenerated: isAi,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'complaint_id': complaintId,
      'severity': severity,
      'confidence': confidence,
      'reason': reason,
      'reasoning': reason,
      'duplicate_of': duplicateOf,
      'is_authentic': isAuthentic,
      'authenticity_score': authenticityScore,
      'photo_verdict': photoVerdict,
      'is_ai_generated': isAiGenerated,
    };
  }
}
