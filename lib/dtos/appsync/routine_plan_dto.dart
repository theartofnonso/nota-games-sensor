class RoutinePlanDto {
  final String id;
  final String name;
  final String notes;
  final String? clientId;

  RoutinePlanDto({
    this.id = "",
    required this.name,
    required this.notes,
    this.clientId,
  });

  /// Returns true if this is a system plan created by the backend (has clientId)
  bool get isSystemPlan => clientId != null && clientId!.isNotEmpty;

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'name': name,
      'notes': notes,
      // Explicitly set clientId (null for user-created plans) to ensure RLS compliance
      'clientId': clientId,
    };
  }

  factory RoutinePlanDto.fromJson({required Map<String, dynamic> json}) {
    final id = json["id"] ?? "";
    final name = json["name"] ?? "";
    final notes = json["notes"] ?? "";
    final clientId = json["clientId"] as String?;

    return RoutinePlanDto(
      id: id,
      name: name,
      notes: notes,
      clientId: clientId,
    );
  }

  RoutinePlanDto copyWith({
    String? id,
    String? name,
    String? notes,
    String? clientId,
  }) {
    return RoutinePlanDto(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
      clientId: clientId ?? this.clientId,
    );
  }

  @override
  String toString() {
    return 'RoutinePlanDto{id: $id, name: $name, notes: $notes}';
  }
}
