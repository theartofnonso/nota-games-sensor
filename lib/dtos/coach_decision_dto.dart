class CoachDecisionDto {
  final String id;
  final String clientId;
  final String coachId;
  final String summary;
  final DateTime createdAt;

  const CoachDecisionDto({
    required this.id,
    required this.clientId,
    required this.coachId,
    required this.summary,
    required this.createdAt,
  });

  Map<String, dynamic> toInsertJson() {
    return {
      'client_id': clientId,
      'coach_id': coachId,
      'summary': summary,
    };
  }

  factory CoachDecisionDto.fromJson({required Map<String, dynamic> json}) {
    return CoachDecisionDto(
      id: json['id'] as String? ?? '',
      clientId: json['client_id'] as String? ?? '',
      coachId: json['coach_id'] as String? ?? '',
      summary: json['summary'] as String? ?? '',
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }
}
