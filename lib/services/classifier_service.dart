import 'dart:typed_data';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ThreatAssessment {
  final double score;
  final bool isThreat;
  final String verdict;

  ThreatAssessment({
    required this.score,
    required this.isThreat,
    required this.verdict,
  });
}

class ClassifierService {
  Interpreter? _interpreter;
  final Map<String, int> _vocab = {};
  static const int maxLen = 64;
  bool _isInitialized = false;

  bool get isReady => _isInitialized;

  Future<void> initialize() async {
    try {
      // 1. Load Vocabulary mapping
      final vocabData = await rootBundle.loadString('assets/models/vocab.txt');
      final lines = vocabData.split('\n');
      for (int i = 0; i < lines.length; i++) {
        final token = lines[i].trim();
        if (token.isNotEmpty) {
          _vocab[token] = i;
        }
      }

      // 2. Load TFLite Model
      _interpreter = await Interpreter.fromAsset('assets/models/threat_model.tflite');
      _isInitialized = true;
    } catch (e) {
      _isInitialized = false;
      rethrow;
    }
  }

  Int32List _tokenize(String text) {
    final tokens = Int32List(maxLen);
    
    // Clean string: lowercase and remove punctuation while keeping Tamil Unicode
    final cleaned = text.toLowerCase().replaceAll(RegExp(r'[^\w\s\u0B80-\u0BFF]'), ' ');
    final words = cleaned.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    for (int i = 0; i < maxLen; i++) {
      if (i < words.length) {
        tokens[i] = _vocab[words[i]] ?? 1; // 1 = OOV token
      } else {
        tokens[i] = 0; // Padding token
      }
    }
    return tokens;
  }

  ThreatAssessment analyzeSms(String smsContent) {
    if (!_isInitialized || _interpreter == null) {
      throw StateError("ClassifierService is not initialized.");
    }

    final inputTokens = _tokenize(smsContent);

    // Reshape input to [1, 64]
    final input = [inputTokens];
    // Output tensor for binary classification: [1, 1]
    final output = List.generate(1, (_) => List<double>.filled(1, 0.0));

    _interpreter!.run(input, output);

    final double probability = output[0][0] * 100.0;
    final bool isThreat = probability >= 75.0;

    String verdict;
    if (probability >= 75.0) {
      verdict = "CRITICAL WHALING ATTACK";
    } else if (probability >= 50.0) {
      verdict = "SUSPICIOUS DISBURSEMENT PATTERN";
    } else {
      verdict = "LEGITIMATE / BENIGN COMMUNICATION";
    }

    return ThreatAssessment(
      score: probability,
      isThreat: isThreat,
      verdict: verdict,
    );
  }

  void dispose() {
    _interpreter?.close();
  }
}