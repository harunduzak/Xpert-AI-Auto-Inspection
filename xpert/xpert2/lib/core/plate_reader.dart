import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

class PlateReader {
  static Future<String> readPlate(File imageFile) async {
    try {
      final inputImage = InputImage.fromFilePath(imageFile.path);
      final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
      final RecognizedText recognizedText = await textRecognizer.processImage(inputImage);
      textRecognizer.close();
      String allText = recognizedText.text.replaceAll('\n', ' ');
      String cleanedText = allText.replaceAll(RegExp(r'[^A-Z0-9a-z]'), '').toUpperCase();

      // İl kodu / harf grubu / rakam grubu ayrı ayrı yakalanıyor ki aralarına
      // boşluk koyarak standart Türk plaka biçiminde ("34 ABC 123") dönebilelim.
      RegExp plateRegex = RegExp(r'(0[1-9]|[1-7][0-9]|8[0-1])([A-Z]{1,3})([0-9]{2,4})');
      Match? match = plateRegex.firstMatch(cleanedText);
      if (match != null) {
        final il = match.group(1)!;
        final harf = match.group(2)!;
        final rakam = match.group(3)!;
        return '$il $harf $rakam';
      } else if (cleanedText.length >= 5 && cleanedText.length <= 10) {
        // Standart formata tam uymayan ama makul uzunluktaki metinler için de
        // harf/rakam geçişlerine boşluk koyarak okunabilirliği artırıyoruz.
        return _spaceOutTransitions(cleanedText);
      } else if (cleanedText.isNotEmpty) {
        return "Plaka net değil";
      }
      return "Plaka bulunamadı";
    } catch (e) {
      return "Okuma hatası";
    }
  }

  /// "34ABC123" gibi bitişik bir metni, harf/rakam grubu değiştiği her yerde
  /// boşluk koyarak "34 ABC 123" biçimine çevirir.
  static String _spaceOutTransitions(String text) {
    final buffer = StringBuffer();
    bool? lastWasDigit;
    for (final rune in text.runes) {
      final ch = String.fromCharCode(rune);
      final isDigit = RegExp(r'[0-9]').hasMatch(ch);
      if (lastWasDigit != null && lastWasDigit != isDigit) {
        buffer.write(' ');
      }
      buffer.write(ch);
      lastWasDigit = isDigit;
    }
    return buffer.toString();
  }
}