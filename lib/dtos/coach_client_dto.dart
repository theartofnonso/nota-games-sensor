/// DTO matching [coach_clients] schema: id, coach_id, client_id, created_at.
/// [clientName] and [clientEmail] come from the joined [clients] table for display.
class CoachClientDto {
  final String id;
  final String coachId;
  final String clientId;
  final DateTime createdAt;
  final String? clientName;
  final String? clientEmail;

  const CoachClientDto({
    required this.id,
    required this.coachId,
    required this.clientId,
    required this.createdAt,
    this.clientName,
    this.clientEmail,
  });

  factory CoachClientDto.fromJson(
    Map<String, dynamic> coachClientsRow,
    Map<String, dynamic> clientsRow,
  ) {
    final rawCreated = coachClientsRow['created_at'];
    DateTime createdAt;
    if (rawCreated != null) {
      createdAt = rawCreated is String
          ? DateTime.tryParse(rawCreated) ?? DateTime.now()
          : DateTime.now();
    } else {
      createdAt = DateTime.now();
    }
    return CoachClientDto(
      id: coachClientsRow['id'] as String? ?? '',
      coachId: coachClientsRow['coach_id'] as String? ?? '',
      clientId: coachClientsRow['client_id'] as String? ?? '',
      createdAt: createdAt,
      clientName: clientsRow['name'] as String?,
      clientEmail: clientsRow['email'] as String?,
    );
  }

  /// Initials for avatar display. Uses [clientName] if present, else [clientEmail].
  String get initials {
    final name = (clientName ?? '').trim();
    if (name.isNotEmpty) {
      final parts = name.split(RegExp(r'\s+'));
      if (parts.isNotEmpty) {
        if (parts.length == 1) {
          final s = parts.first;
          return s.isEmpty
              ? ''
              : s.substring(0, s.length.clamp(0, 2)).toUpperCase();
        }
        final f = parts.first;
        final l = parts.last;
        final first = f.isEmpty ? '' : f[0].toUpperCase();
        final last = l.isEmpty ? '' : l[0].toUpperCase();
        return '$first$last';
      }
    }
    return _fallbackInitials(clientEmail ?? '');
  }

  static String _fallbackInitials(String value) {
    if (value.isEmpty) return '';
    final cleaned = value.split('@').first;
    return cleaned.isEmpty
        ? ''
        : cleaned.substring(0, cleaned.length.clamp(0, 2)).toUpperCase();
  }
}
