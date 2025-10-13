// ──────────────────────────────────────────────────────────────
//  ORDINAL ARCHETYPES
//  Ordinal archetypes represent a ranked scale, where values move from lower to higher states in a meaningful order.
//  Each level in the archetype reflects an increase in the measured behavior.
// ──────────────────────────────────────────────────────────────

abstract interface class TrainingArchetype {
  String get name;

  String get description;
}

/// This determines the training frequency of users
enum TrainingFrequencyArchetype implements TrainingArchetype {
  rarelyTrains(
      name: "rarely_trains", description: "Trains 1 to 2 times a week"),
  oftenTrains(name: "often_trains", description: "Trains 3 to 4 times a week"),
  alwaysTrains(
      name: "always_trains", description: "Trains over 4 times a week");

  const TrainingFrequencyArchetype(
      {required this.name, required this.description});

  @override
  final String name;
  @override
  final String description;
}

/// This determines the length of a users training session
enum TrainingDurationArchetype implements TrainingArchetype {
  shortSessions(
      name: "short_training_sessions",
      description: "Short training sessions (<30 min)"),
  standardSessions(
      name: "standard_training_sessions",
      description: "Standard training Sessions (30–59 min)"),
  extendedSessions(
      name: "extended_training_sessions",
      description: "Extended training sessions (> 60 min)");

  const TrainingDurationArchetype(
      {required this.name, required this.description});

  @override
  final String name;
  @override
  final String description;
}

/// This determines if users always stick to training plan or not
enum ExerciseNoveltyArchetype implements TrainingArchetype {
  fixedExercises(
      name: "fixed_exercises",
      description: "Always trains with same exercises"),
  plannedExercises(
      name: "planned_exercises",
      description: "Often trains with same exercises with occasional changes."),
  randomExercises(
      name: "random_exercises", description: "Always changing exercises");

  const ExerciseNoveltyArchetype(
      {required this.name, required this.description});

  @override
  final String name;
  @override
  final String description;
}

// ──────────────────────────────────────────────────────────────
//  CATEGORICAL ARCHETYPES
//  Categorical archetypes group users into distinct categories without any hierarchical ranking.
//  Unlike ordinal archetypes, these categories are independent of each other and do not imply a progression.
// ──────────────────────────────────────────────────────────────

/// User’s bias in **exercise TYPES** (compound vs accessory / isolation).
enum ExerciseSelectionArchetype implements TrainingArchetype {
  compoundDominant(
      name: 'compound_dominant',
      description: 'Mostly uses compound, multi-joint lifts'),
  balancedMix(
      name: 'balanced_mix',
      description: 'Mixes compound and accessory / isolation work'),
  isolationDominant(
      name: 'isolation_dominant',
      description: 'Prefers accessory or isolation movements');

  const ExerciseSelectionArchetype(
      {required this.name, required this.description});

  @override
  final String name;
  @override
  final String description;
}

/// Primary **muscle-group focus** shown across recent workouts.
enum MuscleFocusArchetype implements TrainingArchetype {
  upperBodyFocus(name: 'upper_body_focus', description: 'Trains upper body'),
  lowerBodyFocus(name: 'lower_body_focus', description: 'Trains lower body'),
  fullBodyBalanced(
      name: 'full_body_balanced', description: 'Trains upper and lower body');

  const MuscleFocusArchetype({required this.name, required this.description});

  @override
  final String name;
  @override
  final String description;
}
