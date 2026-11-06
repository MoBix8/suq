import 'dart:convert';

import 'package:dio/dio.dart';

import 'gemini_key.dart';

/// Calls the Gemini API to suggest Amharic and Afan Oromo translations for an
/// English product name.
class TranslationService {
  TranslationService({String? apiKey}) : _apiKey = apiKey?.trim() ?? '';

  final String _apiKey;
  final Dio _dio = Dio();

  Future<String> _resolveKey() async {
    if (_apiKey.isNotEmpty) return _apiKey;
    final saved = await GeminiKeyStore.read();
    if (saved != null && saved.isNotEmpty) return saved;
    const env = String.fromEnvironment('GEMINI_API_KEY');
    if (env.isNotEmpty) return env;
    throw Exception('Missing Gemini API key. Add it in Settings.');
  }

  String? _textFromResponse(Map<String, dynamic>? data) {
    final candidates = data?['candidates'];
    if (candidates is! List || candidates.isEmpty) return null;
    final first = candidates.first;
    if (first is! Map) return null;
    final content = first['content'];
    if (content is! Map) return null;
    final parts = content['parts'];
    if (parts is! List || parts.isEmpty) return null;
    final part = parts.first;
    if (part is! Map) return null;
    return part['text'] as String?;
  }

  Future<({String? amharic, String? oromo})> suggest(String englishName) async {
    if (englishName.trim().isEmpty) {
      return (amharic: null, oromo: null);
    }
    final apiKey = await _resolveKey();

    final models = ['gemini-2.5-flash', 'gemini-2.0-flash'];
    DioException? lastError;
    for (final model in models) {
      try {
        final response = await _dio.post<Map<String, dynamic>>(
          'https://generativelanguage.googleapis.com/v1beta/models/$model:generateContent',
          options: Options(headers: {
            'Content-Type': 'application/json',
            'x-goog-api-key': apiKey,
          }),
          data: {
            'contents': [
              {
                'parts': [
                  {
                    'text':
                        'Translate the following product name into Amharic and Afan Oromo. '
                        'Reply ONLY as JSON: {"amharic":"...","oromo":"..."}. '
                        'Product name: $englishName',
                  }
                ]
              }
            ],
            'generationConfig': {'responseMimeType': 'application/json'},
          },
        );
        final text = _textFromResponse(response.data);
        if (text == null) {
          throw Exception('No response text. Body: ${response.data}');
        }
        final cleaned = text.trim().replaceAll(RegExp(r'^```json|```$'), '').trim();
        final decoded = jsonDecode(cleaned);
        if (decoded is Map) {
          final am = decoded['amharic'] as String?;
          final or = decoded['oromo'] as String?;
          if ((am == null || am.trim().isEmpty) && (or == null || or.trim().isEmpty)) {
            throw Exception('Empty translation. Raw: $text');
          }
          return (amharic: am, oromo: or);
        }
        throw Exception('Unexpected response: $text');
      } on DioException catch (e) {
        lastError = e;
        if (e.response?.statusCode == 404) continue;
        throw Exception(
          'Gemini request failed (${e.response?.statusCode}): ${e.response?.data ?? e.message}',
        );
      }
    }
    throw Exception('Gemini request failed: ${lastError?.response?.data ?? lastError}');
  }
}
