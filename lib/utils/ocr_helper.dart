import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image_picker/image_picker.dart';
import '../services/api_service.dart';

class OcrHelper {
  static Future<List<Map<String, dynamic>>> scanReceipt({
    ImageSource source = ImageSource.camera,
    ApiService? apiService,
  }) async {
    final picker = ImagePicker();
    final image = await picker.pickImage(
      source: source,
      maxWidth: 2000,
      maxHeight: 3000,
      imageQuality: 95,
    );

    if (image == null) return [];

    if (apiService != null) {
      try {
        final items = await apiService.scanReceipt(File(image.path));
        if (items.isNotEmpty) return items;
      } catch (_) {
        // Fallback to local on-device OCR
      }
    }

    final inputImage = InputImage.fromFilePath(image.path);
    final textRecognizer = TextRecognizer();

    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      return _parseReceiptText(recognizedText.text);
    } finally {
      await textRecognizer.close();
    }
  }

  static List<Map<String, dynamic>> _parseReceiptText(String text) {
    final lines = text.split('\n').map((l) => l.trim()).toList();

    // Strategy 1: Numbered items with =TOTAL on nearby lines
    // Format: "1: 1015 Суп Солянка 250г" + "30x100 =3000.00"
    final numbered = _parseNumberedFormat(lines);
    if (numbered.length >= 2) return numbered;

    // Strategy 2: Lines with =PRICE inline
    // Format: "Суп Солянка ....... =3000"
    final equalSign = _parseEqualSignFormat(lines);
    if (equalSign.length >= 2) return equalSign;

    // Strategy 3: Single-line name + price (fallback)
    return _parseSingleLineFormat(lines);
  }

  // --- Strategy 1: Numbered items (Russian receipt standard) ---
  // "1: 1015 Суп "Солянка сборная" 250г"
  // "30x100                          =3000.00"
  static List<Map<String, dynamic>> _parseNumberedFormat(List<String> lines) {
    final items = <Map<String, dynamic>>[];

    for (int i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.isEmpty) continue;

      // Match: "N: CODE Name..." or "N) CODE Name..." or "N. CODE Name..."
      // where N is 1-3 digits and CODE is 3+ digits
      final itemMatch = RegExp(
        r'^\d{1,3}\s*[:.)]\s*\d{3,}\s+(.+)',
      ).firstMatch(line);

      if (itemMatch == null) continue;

      var rawName = itemMatch.group(1)!;

      // Remove weight/volume/quantity suffix: "250г", "120мл", "5 шт", "1л", "375г"
      rawName = rawName
          .replaceAll(
              RegExp(r'\s+\d+\s*(?:[гГgкКkмлМЛmlшт]+\.?|[лЛlL])\s*$'), '')
          .trim();

      final name = _cleanName(rawName);
      if (name.length < 2) continue;

      // Look for =TOTAL on this line or next 1-3 lines
      double? total;
      for (int j = i; j < lines.length && j <= i + 3; j++) {
        final totalMatch =
            RegExp(r'[=≡]\s*(\d+[.,]?\d*)').firstMatch(lines[j]);
        if (totalMatch != null) {
          total = _parsePrice(totalMatch.group(1)!);
          break;
        }
      }

      if (total != null && total > 0) {
        items.add({'name': name, 'price': total});
      }
    }

    return items;
  }

  // --- Strategy 2: Lines with = sign before price ---
  // "Суп Солянка ......... =3000.00"
  static List<Map<String, dynamic>> _parseEqualSignFormat(List<String> lines) {
    final items = <Map<String, dynamic>>[];

    for (final line in lines) {
      if (line.isEmpty) continue;
      if (_isJunkLine(line)) continue;

      final match = RegExp(
        r'^(.+?)\s*[=≡]\s*(\d+[.,]?\d*)\s*$',
      ).firstMatch(line);

      if (match == null) continue;

      final name = _cleanName(match.group(1)!);
      final price = _parsePrice(match.group(2)!);

      if (price == null || price <= 0 || name.length < 2) continue;

      // Name must contain at least 2 letters (not just numbers/codes)
      final alphaCount =
          name.replaceAll(RegExp(r'[^a-zA-Zа-яА-ЯёЁ]'), '').length;
      if (alphaCount < 2) continue;

      items.add({'name': name, 'price': price});
    }

    return items;
  }

  // --- Strategy 3: Single-line fallback ---
  static List<Map<String, dynamic>> _parseSingleLineFormat(
      List<String> lines) {
    final items = <Map<String, dynamic>>[];

    for (final line in lines) {
      if (line.isEmpty || line.length < 3) continue;
      if (_isJunkLine(line)) continue;

      // Skip date/time lines
      if (RegExp(r'^\d{2}[./\-]\d{2}[./\-]\d{2,4}').hasMatch(line)) continue;
      // Skip lines that are only numbers/symbols
      if (RegExp(r'^[\d\s.,=*xх×\-+]+$').hasMatch(line)) continue;
      // Skip lines with phone numbers
      if (RegExp(r'\+?\d[\d\s\-()]{8,}').hasMatch(line)) continue;

      final parsed = _tryParseSingleLine(line);
      if (parsed != null) {
        items.add(parsed);
      }
    }

    return items;
  }

  static Map<String, dynamic>? _tryParseSingleLine(String line) {
    final cleaned = line
        .replaceAll(
            RegExp(r'\s*(сом|som|kgs|тг|руб|₽|₸)\s*$', caseSensitive: false),
            '')
        .trim();

    // Pattern 1: "Name  2x250" or "Name 2 x 250"
    final qtyMatch = RegExp(
      r'^(.+?)\s+(\d+)\s*[xхXХ*×]\s*(\d+[.,]?\d*)\s*$',
    ).firstMatch(cleaned);
    if (qtyMatch != null) {
      final name = _cleanName(qtyMatch.group(1)!);
      final qty = int.tryParse(qtyMatch.group(2)!) ?? 1;
      final unitPrice = _parsePrice(qtyMatch.group(3)!);
      if (unitPrice != null && unitPrice > 0 && name.length > 1) {
        final alphaCount =
            name.replaceAll(RegExp(r'[^a-zA-Zа-яА-ЯёЁ]'), '').length;
        if (alphaCount >= 2) {
          return {'name': name, 'price': unitPrice * qty};
        }
      }
    }

    // Pattern 2: "Name ......... 250" (dotted lines)
    final dottedMatch = RegExp(
      r'^(.+?)\s*[.\-_=]{2,}\s*(\d+[.,]?\d*)\s*$',
    ).firstMatch(cleaned);
    if (dottedMatch != null) {
      final name = _cleanName(dottedMatch.group(1)!);
      final price = _parsePrice(dottedMatch.group(2)!);
      if (price != null && price > 0 && name.length > 1) {
        return {'name': name, 'price': price};
      }
    }

    // Pattern 3: "Name 1 250" (space as thousands separator)
    final spaceThousandMatch = RegExp(
      r'^(.+?)\s+(\d{1,3})\s(\d{3}(?:[.,]\d{1,2})?)\s*$',
    ).firstMatch(cleaned);
    if (spaceThousandMatch != null) {
      final name = _cleanName(spaceThousandMatch.group(1)!);
      final priceStr =
          '${spaceThousandMatch.group(2)}${spaceThousandMatch.group(3)}';
      final price = _parsePrice(priceStr);
      if (price != null && price > 0 && name.length > 1) {
        return {'name': name, 'price': price};
      }
    }

    // Pattern 4: "Name   250" or "Name 250.50" (basic: name then price)
    final basicMatch = RegExp(
      r'^(.+?)\s+(\d+[.,]?\d*)\s*$',
    ).firstMatch(cleaned);
    if (basicMatch != null) {
      final name = _cleanName(basicMatch.group(1)!);
      final price = _parsePrice(basicMatch.group(2)!);
      if (price != null && price > 0 && name.length > 1) {
        final alphaCount =
            name.replaceAll(RegExp(r'[^a-zA-Zа-яА-ЯёЁ]'), '').length;
        if (alphaCount >= 2) {
          return {'name': name, 'price': price};
        }
      }
    }

    return null;
  }

  // --- Helpers ---

  static bool _isJunkLine(String line) {
    return RegExp(
      r'(итого|всего|total|subtotal|сумма|касс[аи]р?|чек[а ]|дата|время|'
      r'спасибо|thank|ккм|инн|кассир|оплат|нал[ич]|безнал|сдача|'
      r'ндс|ндфл|фн |фп |фд |скидка|discount|change|cash|card|'
      r'тел[еф]|адрес|address|ожидаем|добро|welcome|wifi|'
      r'обслуж|service|tips|чаевые|бонус|bonus|'
      r'продажа|гостей|кафе|ресторан|магазин|ул\.|'
      r'вологда|москва|документ|док:|рнм|эклз|'
      r'наличн|покупк)',
      caseSensitive: false,
    ).hasMatch(line);
  }

  static String _cleanName(String name) {
    return name
        .replaceAll(RegExp(r'^[\d.)\-*#:]+\s*'), '') // leading numbers/bullets
        .replaceAll(RegExp(r'[.]{2,}'), '') // dotted fillers
        .replaceAll(RegExp(r'\s{2,}'), ' ') // collapse whitespace
        .trim();
  }

  static double? _parsePrice(String priceStr) {
    final normalized = priceStr.replaceAll(',', '.').replaceAll(' ', '');
    return double.tryParse(normalized);
  }
}
