const defaultPlanId = "DEFAULT_PLAN_ID";

class RoutinePlanDto {
  final String id;
  final String name;
  final String notes;

  static final defaultPlan = RoutinePlanDto(
      id: defaultPlanId,
      name: "Your workout plans",
      notes:
          "This is your default plan. If you'd like to organize your workouts into different plans, simply create a new one.");

  RoutinePlanDto({
    this.id = "",
    required this.name,
    required this.notes,
  });

  Map<String, dynamic> toJson() {
    return {
      'name': name,
      'notes': notes,
    };
  }

  factory RoutinePlanDto.fromJson({required Map<String, dynamic> json}) {
    final id = json["id"] ?? "";
    final name = json["name"] ?? "";
    final notes = json["notes"] ?? "";

    return RoutinePlanDto(
      id: id,
      name: name,
      notes: notes,
    );
  }

  RoutinePlanDto copyWith({
    String? id,
    String? name,
    String? notes,
  }) {
    return RoutinePlanDto(
      id: id ?? this.id,
      name: name ?? this.name,
      notes: notes ?? this.notes,
    );
  }

  @override
  String toString() {
    return 'RoutinePlanDto{id: $id, name: $name, notes: $notes}';
  }
}
