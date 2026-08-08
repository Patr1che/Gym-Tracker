/// One body-measurement log entry. All metric fields are optional — the user
/// logs whatever they measured. Values are stored in kg / cm / percent.
class MeasurementEntry {
  const MeasurementEntry({
    required this.id,
    required this.userId,
    required this.date,
    this.weightKg,
    this.bodyFatPct,
    this.chestCm,
    this.waistCm,
    this.armsCm,
    this.legsCm,
    this.shouldersCm,
    this.neckCm,
    this.hipsCm,
  });

  final String id;
  final String userId;
  final DateTime date;
  final double? weightKg;
  final double? bodyFatPct;
  final double? chestCm;
  final double? waistCm;
  final double? armsCm;
  final double? legsCm;
  final double? shouldersCm;
  final double? neckCm;
  final double? hipsCm;

  bool get isEmpty =>
      weightKg == null &&
      bodyFatPct == null &&
      chestCm == null &&
      waistCm == null &&
      armsCm == null &&
      legsCm == null &&
      shouldersCm == null &&
      neckCm == null &&
      hipsCm == null;

  Map<String, dynamic> toJson() => {
        'id': id,
        'userId': userId,
        'date': date.toIso8601String(),
        'weightKg': weightKg,
        'bodyFatPct': bodyFatPct,
        'chestCm': chestCm,
        'waistCm': waistCm,
        'armsCm': armsCm,
        'legsCm': legsCm,
        'shouldersCm': shouldersCm,
        'neckCm': neckCm,
        'hipsCm': hipsCm,
      };

  factory MeasurementEntry.fromJson(Map<String, dynamic> json) {
    double? d(String key) => (json[key] as num?)?.toDouble();
    return MeasurementEntry(
      id: json['id'] as String,
      userId: json['userId'] as String? ?? '',
      date: DateTime.tryParse(json['date'] as String? ?? '') ?? DateTime(2020),
      weightKg: d('weightKg'),
      bodyFatPct: d('bodyFatPct'),
      chestCm: d('chestCm'),
      waistCm: d('waistCm'),
      armsCm: d('armsCm'),
      legsCm: d('legsCm'),
      shouldersCm: d('shouldersCm'),
      neckCm: d('neckCm'),
      hipsCm: d('hipsCm'),
    );
  }
}
