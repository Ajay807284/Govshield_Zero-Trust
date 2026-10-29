import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class ClassifierService {
  Interpreter? _interpreter;
  final Map<String, int> _vocab = {};
  bool isLoaded = false;

  final int maxSeqLen = 50;

  // 1. TFLite மாடல் மற்றும் Vocab.txt ஏற்றுதல்
  Future<void> loadModel() async {
    try {
      _interpreter = await Interpreter.fromAsset('assets/models/threat_model.tflite');
      debugPrint('GovShield: TFLite model loaded successfully.');

      final vocabData = await rootBundle.loadString('assets/models/vocab.txt');
      final lines = vocabData.split('\n');
      _vocab.clear();
      for (int i = 0; i < lines.length; i++) {
        final token = lines[i].trim();
        if (token.isNotEmpty) {
          _vocab[token] = i;
        }
      }
      debugPrint('GovShield: Vocab loaded with ${_vocab.length} tokens.');
      isLoaded = true;
    } catch (e) {
      debugPrint('GovShield Model Load Error: $e');
      isLoaded = false;
    }
  }

  // 2. Preprocessing & Real-time Inference
  Future<Map<String, dynamic>> predict(String text) async {
    if (!isLoaded || _interpreter == null) {
      debugPrint('GovShield: Model not loaded yet, returning fallback.');
      return {'score': 0.05, 'latency': 0};
    }

    final stopwatch = Stopwatch()..start();

    final cleanText = text.toLowerCase().replaceAll(RegExp(r'[^\w\s]'), ' ');
    final words = cleanText.split(RegExp(r'\s+')).where((w) => w.isNotEmpty).toList();

    List<int> inputSequence = List.filled(maxSeqLen, 0);
    int oovIndex = _vocab['<OOV>'] ?? _vocab['<unk>'] ?? 1;

    for (int i = 0; i < words.length && i < maxSeqLen; i++) {
      inputSequence[i] = _vocab[words[i]] ?? oovIndex;
    }

    var input = [inputSequence];
    var output = List.filled(1 * 1, 0.0).reshape([1, 1]);

    try {
      _interpreter!.run(input, output);
    } catch (e) {
      debugPrint("GovShield Inference Run Error: $e");
    }

    stopwatch.stop();

    double rawScore = output[0][0];
    double threatScore = rawScore.clamp(0.0, 1.0);

    return {
      'score': threatScore,
      'latency': stopwatch.elapsedMilliseconds,
    };
  }

  void dispose() {
    _interpreter?.close();
  }
}