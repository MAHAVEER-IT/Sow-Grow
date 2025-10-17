/// Language configuration constants for the Blog module
class BlogLanguageConstants {
  // Available languages for blog translation
  static const List<Map<String, String>> availableLanguages = [
    {'code': 'en', 'name': 'English'},
    {'code': 'ta', 'name': 'தமிழ்'},
    {'code': 'hi', 'name': 'हिन्दी'},
    {'code': 'ml', 'name': 'മലയാളം'},
  ];

  // Text-to-Speech language mapping
  static const Map<String, String> ttsLanguageCodes = {
    'en': 'en-US',
    'ta': 'ta-IN',
    'hi': 'hi-IN',
    'ml': 'ml-IN',
  };
}
