enum ExerciseType {
  weights("WR", "Weights", "Log weights and reps"),
  bodyWeight("BW", "Bodyweight", "Log only reps"),
  duration("DR", "Duration", "Log duration");

  const ExerciseType(this.id, this.name, this.description);

  final String id;
  final String name;
  final String description;

  static ExerciseType fromString(String string) {
    return ExerciseType.values
        .firstWhere((value) => value.id.toLowerCase() == string.toLowerCase());
  }
}
