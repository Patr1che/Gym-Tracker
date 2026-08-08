/// Shared enums. All serialize by `.name` and parse with a safe fallback —
/// never use `values.byName` directly on persisted data.
enum Gender {
  male('Male'),
  female('Female'),
  other('Other');

  const Gender(this.label);
  final String label;

  static Gender fromName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => Gender.other);
}

enum FitnessGoal {
  buildMuscle('Build Muscle'),
  loseFat('Lose Fat'),
  maintainWeight('Maintain Weight'),
  increaseStrength('Increase Strength'),
  improveEndurance('Improve Endurance');

  const FitnessGoal(this.label);
  final String label;

  static FitnessGoal fromName(String? name) => values
      .firstWhere((v) => v.name == name, orElse: () => FitnessGoal.buildMuscle);
}

enum ExperienceLevel {
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced');

  const ExperienceLevel(this.label);
  final String label;

  static ExperienceLevel fromName(String? name) => values.firstWhere(
      (v) => v.name == name,
      orElse: () => ExperienceLevel.beginner);
}

enum MuscleGroup {
  chest('Chest'),
  back('Back'),
  shoulders('Shoulders'),
  arms('Arms'),
  legs('Legs'),
  core('Core'),
  cardio('Cardio');

  const MuscleGroup(this.label);
  final String label;

  static MuscleGroup fromName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => MuscleGroup.chest);
}

enum Difficulty {
  beginner('Beginner'),
  intermediate('Intermediate'),
  advanced('Advanced');

  const Difficulty(this.label);
  final String label;

  static Difficulty fromName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => Difficulty.beginner);
}

enum Units {
  metric('Metric (kg, cm)'),
  imperial('Imperial (lb, in)');

  const Units(this.label);
  final String label;

  static Units fromName(String? name) =>
      values.firstWhere((v) => v.name == name, orElse: () => Units.metric);
}
