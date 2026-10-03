import 'dart:convert';
import 'dart:typed_data';
import 'package:google_generative_ai/google_generative_ai.dart';
import '../core/prompts.dart';
import '../models/models.dart';

class GeminiException implements Exception {
  final String message;
  final bool retryable;
  GeminiException(this.message, {this.retryable = false});
  @override
  String toString() => message;
}

/// Asynchronous Gemini API handler.
/// - Uses the official Google AI Dart SDK with `responseMimeType: application/json`.
/// - Supports multimodal input (camera / gallery bytes) for OCR homework solving.
/// - Retries transient failures with exponential back-off.
/// - Repairs slightly malformed JSON (stray fences / prose) before parsing.
class GeminiService {
  GeminiService({required String apiKey, String model = 'gemini-2.0-flash'})
      : _apiKey = apiKey,
        _modelName = model;

  final String _apiKey;
  final String _modelName;

  GenerativeModel _model(StudyModule module, AppLang lang, String? target, StudyLevel level) => GenerativeModel(
        model: _modelName,
        apiKey: _apiKey,
        systemInstruction: Content.system(Prompts.system(module, lang, targetLanguage: target, level: level)),
        generationConfig: GenerationConfig(
          temperature: 0.4,
          topP: 0.95,
          maxOutputTokens: 8192,
          responseMimeType: 'application/json',
        ),
        safetySettings: [
          SafetySetting(HarmCategory.harassment, HarmBlockThreshold.high),
          SafetySetting(HarmCategory.hateSpeech, HarmBlockThreshold.high),
          SafetySetting(HarmCategory.dangerousContent, HarmBlockThreshold.high),
        ],
      );

  Future<AIResult> generate({
    required StudyModule module,
    required AppLang lang,
    required String input,
    Uint8List? imageBytes,
    String imageMime = 'image/jpeg',
    String? targetLanguage,
    StudyLevel level = StudyLevel.bac,
  }) async {
    if (input.trim().isEmpty && imageBytes == null) {
      throw GeminiException('Please provide text or an image.');
    }
    final parts = <Part>[TextPart(Prompts.user(module, input, hasImage: imageBytes != null))];
    if (imageBytes != null) parts.add(DataPart(imageMime, imageBytes));

    Object? lastError;
    for (var attempt = 0; attempt < 3; attempt++) {
      try {
        final res = await _model(module, lang, targetLanguage, level)
            .generateContent([Content.multi(parts)])
            .timeout(const Duration(seconds: 60));
        final text = res.text;
        if (text == null || text.isEmpty) {
          throw GeminiException('Empty response (finishReason: ${res.candidates.firstOrNull?.finishReason})');
        }
        return AIResult.fromJson(module, _extractJson(text));
      } on GenerativeAIException catch (e) {
        lastError = GeminiException('Gemini error: ${e.message}', retryable: e.message.contains('429') || e.message.contains('503'));
        if (!(lastError as GeminiException).retryable) rethrow;
      } catch (e) {
        lastError = e;
      }
      await Future.delayed(Duration(milliseconds: 600 * (1 << attempt)));
    }
    throw lastError is GeminiException ? lastError : GeminiException('Network failure: $lastError', retryable: true);
  }

  /// Robust JSON extraction from model text.
  static Map<String, dynamic> _extractJson(String text) {
    final cleaned = text.replaceAll(RegExp(r'```(?:json)?', caseSensitive: false), '').trim();
    try {
      return Map<String, dynamic>.from(jsonDecode(cleaned));
    } catch (_) {
      final start = cleaned.indexOf('{');
      final end = cleaned.lastIndexOf('}');
      if (start == -1 || end == -1) throw GeminiException('Model returned non-JSON output');
      return Map<String, dynamic>.from(jsonDecode(cleaned.substring(start, end + 1)));
    }
  }
}
