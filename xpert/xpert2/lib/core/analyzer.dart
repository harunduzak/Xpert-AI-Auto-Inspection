import 'dart:io';
import 'package:flutter/services.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img;

import 'detection.dart';

// ==========================================
// YAPAY ZEKA MOTORU (TFLITE ANALİZİ) - DÜZELTİLMİŞ SÜRÜM
// ==========================================
class Analyzer {
  static const titles = {
    'car': 'Araç Tespiti',
    'car-type': 'Araç Tipi',
    'plate': 'Plaka Tespiti',
    'car-parts': 'Araç Parçaları',
    'damage': 'Hasar Analizi',
  };

  static Map<String, dynamic> _res(String base, String label, double? conf) =>
      {'name': titles[base] ?? base, 'label': label, 'confidence': conf};

  static dynamic _buildBuffer(List<int> shape) {
    if (shape.length == 1) return List.filled(shape[0], 0.0);
    return List.generate(shape[0], (_) => _buildBuffer(shape.sublist(1)));
  }

  static Future<List<Detection>> detectAll(String base, File image,
      {double confThresh = 0.25, double iouThresh = 0.45}) async {
    Interpreter? interpreter;
    List<Detection> results = [];
    try {
      interpreter = await Interpreter.fromAsset('assets/models/${base}_best_float32.tflite');

      List<String> labels = [];
      try {
        final raw = await rootBundle.loadString('assets/models/${base}_labels.txt');
        labels = raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } catch (e) {
        print('[$base] labels.txt OKUNAMADI: $e');
      }

      final outTensors = interpreter.getOutputTensors();
      final inShape = interpreter.getInputTensor(0).shape;
      if (inShape.length < 3) return results;
      final w = inShape[2], h = inShape[1];

      final bytes = await image.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return results;
      final resized = img.copyResize(decoded, width: w, height: h);

      final input = List.generate(1, (_) => List.generate(h, (y) => List.generate(w, (x) {
        final p = resized.getPixel(x, y);
        return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
      })));

      final List<dynamic> outputBuffers = outTensors.map((t) => _buildBuffer(t.shape)).toList();
      if (outTensors.length > 1) {
        final outputsMap = <int, Object>{};
        for (int i = 0; i < outputBuffers.length; i++) {
          outputsMap[i] = outputBuffers[i];
        }
        interpreter.runForMultipleInputs([input], outputsMap);
      } else {
        interpreter.run(input, outputBuffers[0]);
      }

      int detIdx = 0;
      for (int i = 0; i < outTensors.length; i++) {
        if (outTensors[i].shape.length == 3) {
          detIdx = i;
          break;
        }
      }
      final outShape = outTensors[detIdx].shape;
      final dynamic output = outputBuffers[detIdx];
      if (outShape.length != 3) return results;

      int maskCoeffs = 0;
      for (final t in outTensors) {
        if (t.shape.length == 4) {
          maskCoeffs = t.shape[3];
          break;
        }
      }

      final d1 = outShape[1], d2 = outShape[2];
      final transposed = d1 < d2;
      final numBoxes = transposed ? d2 : d1;
      final numValues = transposed ? d1 : d2;
      final numClasses = numValues - 4 - maskCoeffs;
      if (numClasses <= 0) return results;

      // HATA DÜZELTME 1: Tip dönüşümü zorunlu kılındı (as num).toDouble()
      double v(int box, int val) {
        if (box < 0 || val < 0 || val >= numValues || box >= numBoxes) return 0.0;
        final dynamic rawVal = transposed ? output[0][val][box] : output[0][box][val];
        return (rawVal as num).toDouble();
      }

      final List<Detection> candidates = [];
      for (int i = 0; i < numBoxes; i++) {
        double bestConf = 0;
        int bestCls = -1;
        for (int c = 0; c < numClasses; c++) {
          final s = v(i, c + 4);
          if (s > bestConf) {
            bestConf = s;
            bestCls = c;
          }
        }
        if (bestConf < confThresh || bestCls < 0) continue;

        final rawCx = v(i, 0), rawCy = v(i, 1), rawW = v(i, 2), rawH = v(i, 3);

        // HATA DÜZELTME 2: pixelScale heuristiği silindi. YOLOv8 çıktıları
        // model çözünürlüğündedir, bu yüzden her zaman w ve h'ye bölünerek normalize edilir.
        final cx = rawCx / w;
        final cy = rawCy / h;
        final bw = rawW / w;
        final bh = rawH / h;

        final label = (bestCls < labels.length) ? labels[bestCls] : 'Sınıf #$bestCls';
        candidates.add(Detection(label, bestConf * 100, cx, cy, bw, bh));
      }

      candidates.sort((a, b) => b.conf.compareTo(a.conf));
      final List<Detection> kept = [];
      for (final c in candidates) {
        bool suppressed = false;
        for (final k in kept) {
          if (k.label == c.label && k.iou(c) > iouThresh) {
            suppressed = true;
            break;
          }
        }
        if (!suppressed) kept.add(c);
      }
      results = kept;

    } catch (e, st) {
      print('[$base] detectAll HATA: $e');
      print('[$base] STACK TRACE:\n$st');
    } finally {
      interpreter?.close();
    }
    return results;
  }

  static Future<Map<String, dynamic>> run(String base, File image) async {
    Interpreter? interpreter;
    try {
      interpreter = await Interpreter.fromAsset('assets/models/${base}_best_float32.tflite');

      List<String> labels = [];
      try {
        final raw = await rootBundle.loadString('assets/models/${base}_labels.txt');
        labels = raw.split('\n').map((e) => e.trim()).where((e) => e.isNotEmpty).toList();
      } catch (_) {}

      final inShape = interpreter.getInputTensor(0).shape;
      if (inShape.length < 3) return _res(base, 'Geçersiz giriş boyutu', null);
      final h = inShape[1], w = inShape[2];

      final bytes = await image.readAsBytes();
      final decoded = img.decodeImage(bytes);
      if (decoded == null) return _res(base, 'Resim çözümlenemedi', null);
      final resized = img.copyResize(decoded, width: w, height: h);

      final input = List.generate(1, (_) => List.generate(h, (y) => List.generate(w, (x) {
        final p = resized.getPixel(x, y);
        return [p.r / 255.0, p.g / 255.0, p.b / 255.0];
      })));

      final outTensors = interpreter.getOutputTensors();
      final List<dynamic> outputBuffers = outTensors.map((t) => _buildBuffer(t.shape)).toList();

      if (outTensors.length > 1) {
        final outputsMap = <int, Object>{};
        for (int i = 0; i < outputBuffers.length; i++) {
          outputsMap[i] = outputBuffers[i];
        }
        interpreter.runForMultipleInputs([input], outputsMap);
      } else {
        interpreter.run(input, outputBuffers[0]);
      }

      int detIdx = 0;
      for (int i = 0; i < outTensors.length; i++) {
        if (outTensors[i].shape.length == 3) {
          detIdx = i;
          break;
        }
      }
      final outShape = outTensors[detIdx].shape;
      final dynamic output = outputBuffers[detIdx];

      int maskCoeffs = 0;
      for (final t in outTensors) {
        if (t.shape.length == 4) {
          maskCoeffs = t.shape[3];
          break;
        }
      }

      int bestIdx = -1;
      double conf = 0;

      if (outShape.length == 3) {
        final d1 = outShape[1], d2 = outShape[2];
        final transposed = d1 < d2;
        final numBoxes = transposed ? d2 : d1;
        final numValues = transposed ? d1 : d2;

        // Burada da aynı tip dönüşümü güvenliğini uyguladık
        double v(int box, int val) {
          if (box < 0 || val < 0 || val >= numValues || box >= numBoxes) return 0.0;
          final dynamic rawVal = transposed ? output[0][val][box] : output[0][box][val];
          return (rawVal as num).toDouble();
        }

        final numClasses = numValues - 4 - maskCoeffs;
        if (numClasses <= 0) return _res(base, 'Geçersiz çıktı boyutu', null);
        final bool isV8 = numClasses == labels.length || numValues != 6;

        for (int i = 0; i < numBoxes; i++) {
          if (isV8) {
            for (int c = 0; c < numClasses; c++) {
              final s = v(i, c + 4);
              if (s > conf) {
                conf = s;
                bestIdx = c;
              }
            }
          } else {
            final s = v(i, 4);
            if (s > conf) {
              conf = s;
              final cls = v(i, 5).round();
              bestIdx = (cls >= 0 && cls < labels.length) ? cls : -1;
            }
          }
        }
        if (bestIdx < 0 || conf < 0.25) return _res(base, 'Tespit edilemedi', null);
      } else if (outShape.length == 2) {
        final n = outShape[1];
        for (int i = 0; i < n; i++) {
          final s = (output[0][i] as num).toDouble();
          if (s > conf) {
            conf = s;
            bestIdx = i;
          }
        }
      } else {
        return _res(base, 'Desteklenmeyen çıktı: $outShape', null);
      }

      if (bestIdx < 0) return _res(base, 'Tespit edilemedi', null);
      final label = (bestIdx < labels.length) ? labels[bestIdx] : 'Sınıf #$bestIdx';
      return _res(base, label, conf * 100);

    } catch (e, st) {
      print('[$base] HATA: $e');
      print('[$base] STACK TRACE:\n$st');
      return _res(base, 'Hata: $e', null);
    } finally {
      interpreter?.close();
    }
  }
}