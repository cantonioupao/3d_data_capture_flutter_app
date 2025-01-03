import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:image/image.dart' as img_lib;
import 'dart:io';
import 'dart:math';

class TFLiteService {
  static Future<Interpreter> loadModel(String modelPath) async {
    return await Interpreter.fromAsset(modelPath);
  }

  static Future<List<dynamic>> runModelOnImage(Interpreter interpreter, String imagePath) async {
    final image = img_lib.decodeImage(File(imagePath).readAsBytesSync())!;
    // Preprocess the image and run inference
    // ...
    return [];
  }

  static List<Map<String, dynamic>> processDetectionResults(
    List<List<List<double>>> outputs,
    List<String> labels,
    double confidenceThreshold
  ) {
    final List<Map<String, dynamic>> detections = [];
    
    // Process detection boxes
    final boxes = outputs[0];
    final scores = outputs[1][0];
    final classes = outputs[2][0];
    
    for (var i = 0; i < min(boxes.length, scores.length); i++) {
      if (scores[i] >= confidenceThreshold) {
        final detection = {
          'bounds': boxes[i],
          'score': scores[i],
          'class': labels[classes[i].round()],
        };
        detections.add(detection);
      }
    }
    
    return detections;
  }
}