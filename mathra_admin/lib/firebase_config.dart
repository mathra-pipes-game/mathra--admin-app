/// SAME two values as the game's lib/data/services/firebase_config.dart
/// (Firebase console -> Project settings -> General).
class FirebaseConfig {
  FirebaseConfig._();

  static const String projectId = 'mathra-pipes-game';
  static const String apiKey = 'AIzaSyB2f0Pg8AIWW-VhoqwoIcXBtphnuAyV2-Y';

  static bool get isConfigured => projectId.isNotEmpty && apiKey.isNotEmpty;
}
