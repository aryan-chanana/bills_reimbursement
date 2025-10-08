import 'dart:io';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:intl/intl.dart';

class OcrService {

  static Future<Map<String, dynamic>> processImage(File imageFile) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    final inputImage = InputImage.fromFile(imageFile);
    final recognizedText = await textRecognizer.processImage(inputImage);
    textRecognizer.close();

    String fullText = recognizedText.text;

    print("--- RAW OCR TEXT ---\n$fullText\n--- END RAW TEXT ---");

    if (fullText.toLowerCase().contains('noida auth parking')) {
      return _parseNoidaParkingReceipt(fullText);
    } else {
      return _parseGenericReceipt(fullText);
    }
  }

  static Map<String, dynamic> _parseNoidaParkingReceipt(String text) {
    final String category = 'Parking';
    double? amount;
    DateTime? date;

    final amountRegex = RegExp(r'INR\s*([\d\.]+)');
    final amountMatch = amountRegex.firstMatch(text);
    if (amountMatch != null) {
      amount = double.tryParse(amountMatch.group(1)!);
    }

    final dateRegex = RegExp(r'(\d{1,2}\s+\w{3}\s+\d{2,4},\s*\d{1,2}:\d{2}\s*(?:AM|PM))', caseSensitive: false);
    final allDateMatches = dateRegex.allMatches(text);
    DateTime? latestDate;

    for (final match in allDateMatches) {
      try {
        final parsedDate = DateFormat('dd MMM yy, hh:mm a').parse(match.group(1)!);
        if (latestDate == null || parsedDate.isAfter(latestDate)) {
          latestDate = parsedDate;
        }
      } catch (e) {
        print("Could not parse date string: ${match.group(1)}");
      }
    }
    date = latestDate;

    return {
      'category': category,
      'amount': amount,
      'date': date,
    };
  }

  static Map<String, dynamic> _parseGenericReceipt(String text) {
    return {
      'category': null,
      'amount': _findAmountFromGenericText(text),
      'date': _findDateFromGenericText(text),
    };
  }

  static double? _findAmountFromGenericText(String text) {
    final RegExp amountRegex = RegExp(r'(\d{1,3}(,\d{3})*|\d+)\.\d{2}');
    final matches = amountRegex.allMatches(text);
    double largestAmount = 0.0;
    if (matches.isEmpty) return null;

    for (final match in matches) {
      final amountString = match.group(0)?.replaceAll(',', '');
      if (amountString != null) {
        final amount = double.tryParse(amountString);
        if (amount != null && amount > largestAmount) {
          largestAmount = amount;
        }
      }
    }
    return largestAmount > 0 ? largestAmount : null;
  }

  static DateTime? _findDateFromGenericText(String text) {
    final RegExp dateRegex = RegExp(r'\b(\d{1,2})[\/\-\.](\d{1,2})[\/\-\.](\d{2,4})\b');
    final match = dateRegex.firstMatch(text);
    if (match != null) {
      try {
        int day = int.parse(match.group(1)!);
        int month = int.parse(match.group(2)!);
        int year = int.parse(match.group(3)!);
        if (year < 100) year += 2000;
        return DateTime(year, month, day);
      } catch (e) {
        return null;
      }
    }
    return null;
  }
}