import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';

class AppState extends ChangeNotifier {
  List<CameraDescription>? cameras;
  Interpreter? interpreter;
  List<String>? labels;

  void setCameras(List<CameraDescription> cameras) {
    this.cameras = cameras;
    notifyListeners();
  }

  void setInterpreter(Interpreter interpreter) {
    this.interpreter = interpreter;
    notifyListeners();
  }

  void setLabels(List<String> labels) {
    this.labels = labels;
    notifyListeners();
  }
}