enum ExerciseType {
  weights("WR", "Weights", "Bench Press, Dumbbell Curls"),
  bodyWeight("BW", "Bodyweight", "Pull-Ups, Crunches, Burpees"),
  duration("DR", "Duration", "Planks, Yoga");

  const ExerciseType(this.id, this.name, this.description);

  final String id;
  final String name;
  final String description;

  static ExerciseType fromString(String string) {
    return ExerciseType.values
        .firstWhere((value) => value.id.toLowerCase() == string.toLowerCase());
  }
}
