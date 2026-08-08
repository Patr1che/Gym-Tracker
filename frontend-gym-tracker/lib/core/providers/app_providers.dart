import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:uuid/uuid.dart';

typedef Clock = DateTime Function();

/// Current-time source. Override in tests for deterministic dates.
final clockProvider = Provider<Clock>((ref) => DateTime.now);

/// ID generator. Override in tests for deterministic IDs.
final uuidProvider = Provider<String Function()>((ref) {
  const uuid = Uuid();
  return uuid.v4;
});
