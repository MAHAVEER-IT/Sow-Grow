import 'dart:convert';
import 'package:http/http.dart' as http;

/// Translation service for blog content
class TranslationService {
  /// Translates text from English to target language using MyMemory API
  static Future<String> translateText(String text, String targetLang) async {
    if (text.isEmpty || targetLang == 'en') {
      return text;
    }

    try {
      // Split text into chunks of approximately 500 characters at sentence boundaries
      List<String> chunks = _splitTextIntoChunks(text);

      // Translate each chunk
      List<String> translatedChunks = [];
      for (String chunk in chunks) {
        String translated = await _translateChunk(chunk, targetLang);
        translatedChunks.add(translated);

        // Add a small delay between requests to avoid rate limiting
        await Future.delayed(Duration(milliseconds: 300));
      }

      // Combine translated chunks
      return translatedChunks.join(' ');
    } catch (e) {
      print('Translation error: $e');
      return text; // Return original text if translation fails
    }
  }

  /// Splits text into chunks at sentence boundaries
  static List<String> _splitTextIntoChunks(String text) {
    List<String> chunks = [];
    String currentChunk = '';

    // Split by sentences (looking for . ! ? followed by space)
    List<String> sentences = text.split(RegExp(r'(?<=[.!?])\s+'));

    for (String sentence in sentences) {
      if ((currentChunk + sentence).length > 500) {
        if (currentChunk.isNotEmpty) {
          chunks.add(currentChunk);
        }
        currentChunk = sentence;
      } else {
        currentChunk += (currentChunk.isEmpty ? '' : ' ') + sentence;
      }
    }

    if (currentChunk.isNotEmpty) {
      chunks.add(currentChunk);
    }

    return chunks;
  }

  /// Translates a single chunk using MyMemory API
  static Future<String> _translateChunk(String chunk, String targetLang) async {
    try {
      final url = Uri.parse(
        'https://api.mymemory.translated.net/get?q=${Uri.encodeComponent(chunk)}&langpair=en|$targetLang',
      );

      final response = await http.get(url);

      if (response.statusCode == 200) {
        final data = json.decode(response.body);

        if (data['responseStatus'] == 200 && data['responseData'] != null) {
          return data['responseData']['translatedText'];
        }
      }

      return chunk; // Keep original if translation fails
    } catch (e) {
      print('Chunk translation error: $e');
      return chunk;
    }
  }
}
