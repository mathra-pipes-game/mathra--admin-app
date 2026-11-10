/// SAME two values as the game's lib/data/services/firebase_config.dart
/// (Firebase console -> Project settings -> General).
class FirebaseConfig {
  FirebaseConfig._();

  static const String projectId = 'mathra-98401';
  static const String apiKey = 'AIzaSyDs5xzfmgyjRqBat2gtaFQIhpSHbfW0M9w';

  static bool get isConfigured => projectId.isNotEmpty && apiKey.isNotEmpty;
}
