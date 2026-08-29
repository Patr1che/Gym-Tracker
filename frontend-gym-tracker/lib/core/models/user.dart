import 'enums.dart';

/// Onboarding data. `User.profile == null` means onboarding is incomplete.
class UserProfile {
  const UserProfile({
    required this.gender,
    required this.age,
    required this.heightCm,
    required this.weightKg,
    required this.goal,
    required this.experience,
    required this.weeklyFrequency,
  });

  final Gender gender;
  final int age;
  final double heightCm;
  final double weightKg;
  final FitnessGoal goal;
  final ExperienceLevel experience;
  final int weeklyFrequency;

  UserProfile copyWith({
    Gender? gender,
    int? age,
    double? heightCm,
    double? weightKg,
    FitnessGoal? goal,
    ExperienceLevel? experience,
    int? weeklyFrequency,
  }) =>
      UserProfile(
        gender: gender ?? this.gender,
        age: age ?? this.age,
        heightCm: heightCm ?? this.heightCm,
        weightKg: weightKg ?? this.weightKg,
        goal: goal ?? this.goal,
        experience: experience ?? this.experience,
        weeklyFrequency: weeklyFrequency ?? this.weeklyFrequency,
      );

  Map<String, dynamic> toJson() => {
        'gender': gender.name,
        'age': age,
        'heightCm': heightCm,
        'weightKg': weightKg,
        'goal': goal.name,
        'experience': experience.name,
        'weeklyFrequency': weeklyFrequency,
      };

  factory UserProfile.fromJson(Map<String, dynamic> json) => UserProfile(
        gender: Gender.fromName(json['gender'] as String?),
        age: (json['age'] as num?)?.toInt() ?? 0,
        heightCm: (json['heightCm'] as num?)?.toDouble() ?? 0,
        weightKg: (json['weightKg'] as num?)?.toDouble() ?? 0,
        goal: FitnessGoal.fromName(json['goal'] as String?),
        experience: ExperienceLevel.fromName(json['experience'] as String?),
        weeklyFrequency: (json['weeklyFrequency'] as num?)?.toInt() ?? 3,
      );
}

class User {
  const User({
    required this.id,
    required this.name,
    required this.email,
    required this.passwordHash,
    required this.salt,
    required this.createdAt,
    required this.photoSeed,
    this.emailVerified = true,
    this.profile,
  });

  final String id;
  final String name;

  /// Always stored lowercased.
  final String email;
  final String passwordHash;
  final String salt;
  final DateTime createdAt;

  /// Seed for the generated avatar (initials + gradient variant).
  final int photoSeed;

  /// Whether the server has confirmed this address. Defaults to true, and only
  /// a server response ever sets it false: an account created locally - the
  /// local-only build, or a test - has nothing to verify against, and treating
  /// those as unconfirmed would strand them on a screen no code can ever reach.
  final bool emailVerified;

  final UserProfile? profile;

  bool get isOnboarded => profile != null;

  User copyWith({
    String? name,
    String? email,
    String? passwordHash,
    String? salt,
    int? photoSeed,
    bool? emailVerified,
    UserProfile? profile,
  }) =>
      User(
        id: id,
        name: name ?? this.name,
        email: email ?? this.email,
        passwordHash: passwordHash ?? this.passwordHash,
        salt: salt ?? this.salt,
        createdAt: createdAt,
        photoSeed: photoSeed ?? this.photoSeed,
        emailVerified: emailVerified ?? this.emailVerified,
        profile: profile ?? this.profile,
      );

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'email': email,
        'passwordHash': passwordHash,
        'salt': salt,
        'createdAt': createdAt.toIso8601String(),
        'photoSeed': photoSeed,
        'emailVerified': emailVerified,
        'profile': profile?.toJson(),
      };

  factory User.fromJson(Map<String, dynamic> json) => User(
        id: json['id'] as String,
        name: json['name'] as String? ?? '',
        email: json['email'] as String? ?? '',
        passwordHash: json['passwordHash'] as String? ?? '',
        salt: json['salt'] as String? ?? '',
        createdAt:
            DateTime.tryParse(json['createdAt'] as String? ?? '') ??
                DateTime(2020),
        photoSeed: (json['photoSeed'] as num?)?.toInt() ?? 0,
        // Absent for accounts stored before verification existed, and in
        // local-only builds. Those have nothing to verify against, so they are
        // treated as confirmed rather than nagged forever.
        emailVerified: json['emailVerified'] as bool? ?? true,
        profile: json['profile'] == null
            ? null
            : UserProfile.fromJson(json['profile'] as Map<String, dynamic>),
      );
}
