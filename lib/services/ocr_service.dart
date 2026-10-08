// OCR receipt scanner (PRO feature).
// 1. google_mlkit_text_recognition extracts raw text from the photo.
// 2. The text is sent to claude-opus-5.5 (CodeCraft API) which returns a
//    structured transaction {amount, category, date, note}.

import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../services/ai_service.dart';

class OcrResult {
  const OcrResult({required this.rawText, this.parsed});

  final String rawText;
  final AiParsedTransaction? parsed;

  bool get isEmpty => rawText.trim().isEmpty;
}

abstract final class OcrService {
  /// Runs on-device OCR (works fully offline), then AI-parses the text.
  static Future<OcrResult> scanReceipt(String imagePath,
      {required AiService ai}) async {
    final String raw = await extractText(imagePath);
    if (raw.trim().isEmpty) {
      return const OcrResult(rawText: '');
    }
    AiParsedTransaction? parsed;
    try {
      parsed = await ai.receiptToTransaction(raw);
    } on AiNotConfiguredException {
      // No API key: return raw text; UI lets the user fill fields manually.
      parsed = null;
    }
    return OcrResult(rawText: raw, parsed: parsed);
  }

  /// On-device text recognition (Latin script covers digits & totals on
  /// Egyptian/Gulf receipts; Arabic store names are parsed by the AI layer).
  static Future<String> extractText(String imagePath) async {
    final InputImage input = InputImage.fromFilePath(imagePath);
    final TextRecognizer recognizer =
        TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final RecognizedText result = await recognizer.processImage(input);
      return result.text;
    } catch (_) {
      return '';
    } finally {
      await recognizer.close();
    }
  }
}
