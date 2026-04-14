// lib/config/api_config.dart
class ApiConfig {
  static const String geminiApiKey = String.fromEnvironment(
    'GEMINI_API_KEY',
    defaultValue: 'REMPLACE_PAR_TA_CLE',
  );
}
