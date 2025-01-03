import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img_lib;
import 'dart:io';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  runApp(MyApp(cameras: cameras));
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      home: CameraScreen(camera: cameras.first),
    );
  }
}

class CameraScreen extends StatefulWidget {
  final CameraDescription camera;
  const CameraScreen({Key? key, required this.camera}) : super(key: key);

  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  XFile? _image;
  List<Map<String, dynamic>>? _detections;
  Interpreter? _interpreter;
  List<String> _labels = [];

  @override
  void initState() {
    super.initState();
    _controller = CameraController(widget.camera, ResolutionPreset.medium);
    _initializeControllerFuture = _initializeAll();
  }

  Future<void> _initializeAll() async {
    try {
      await _controller.initialize();
      await _loadModel();
      await _loadLabels();
    } catch (e) {
      print('Initialization error: $e');
    }
  }

  Future<void> _loadModel() async {
    final interpreterOptions = InterpreterOptions()
      ..threads = 4
      ..useNnApiForAndroid = true;
      
    _interpreter = await Interpreter.fromAsset(
      'assets/detect.tflite',
      options: interpreterOptions,
    );
  }

  Future<void> _loadLabels() async {
    final labelFile = await rootBundle.loadString('assets/labelmap.txt');
    _labels = labelFile.split('\n').where((s) => s.isNotEmpty).toList();
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      
      // Process the image
      final bytes = await image.readAsBytes();
      final img = img_lib.decodeImage(bytes);
      
      if (img == null) return;

      // Resize image to 300x300
      final resized = img_lib.copyResize(img, width: 300, height: 300);
      
      // Convert to RGB format
      final inputData = List<int>.filled(300 * 300 * 3, 0);
      var inputIndex = 0;
      
      for (var y = 0; y < resized.height; y++) {
        for (var x = 0; x < resized.width; x++) {
          final pixel = resized.getPixel(x, y);
          inputData[inputIndex++] = pixel.r.toInt();
          inputData[inputIndex++] = pixel.g.toInt();
          inputData[inputIndex++] = pixel.b.toInt();
        }
      }

      // Run detection
      final detections = await _runDetection(inputData);

      setState(() {
        _image = image;
        _detections = detections;
      });
    } catch (e) {
      print('Error taking picture: $e');
    }
  }

  Future<List<Map<String, dynamic>>> _runDetection(List<int> imageData) async {
    if (_interpreter == null) return [];

    final reshapedInput = List.generate(1, (b) =>
      List.generate(300, (y) =>
        List.generate(300, (x) =>
          List.generate(3, (c) =>
            imageData[(y * 300 + x) * 3 + c]
          )
        )
      )
    );

    final outputLocations = List.filled(1, List.filled(10, List.filled(4, 0.0)));
    final outputClasses = List.filled(1, List.filled(10, 0.0));
    final outputScores = List.filled(1, List.filled(10, 0.0));
    final numDetections = List.filled(1, 0.0);

    final outputs = {
      0: outputLocations,
      1: outputClasses,
      2: outputScores,
      3: numDetections
    };

    _interpreter!.runForMultipleInputs([reshapedInput], outputs);

    final results = <Map<String, dynamic>>[];
    
    for (var i = 0; i < outputScores[0].length; i++) {
      if (outputScores[0][i] >= 0.7) {
        final classIndex = outputClasses[0][i].round();
        results.add({
          'bounds': outputLocations[0][i],
          'score': outputScores[0][i],
          'class': _labels[classIndex],
        });
      }
    }
    
    return results;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Camera Detection')),
      body: FutureBuilder<void>(
        future: _initializeControllerFuture,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.done) {
            return Stack(
              fit: StackFit.expand,
              children: [
                _image == null
                    ? CameraPreview(_controller)
                    : Image.file(
                        File(_image!.path),
                        fit: BoxFit.contain,
                      ),
                if (_image != null && _detections != null)
                  CustomPaint(
                    painter: DetectionBoxPainter(
                      recognitions: _detections,
                      imageHeight: 300,
                      imageWidth: 300,
                    ),
                  ),
              ],
            );
          } else {
            return Center(child: CircularProgressIndicator());
          }
        },
      ),
      floatingActionButton: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          if (_image != null) // Only show reset button if there's a captured image
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: FloatingActionButton(
                onPressed: () {
                  setState(() {
                    _image = null;
                    _detections = null;
                  });
                },
                child: Icon(Icons.refresh),
                backgroundColor: Colors.red,
              ),
            ),
          FloatingActionButton(
            onPressed: _takePicture,
            child: Icon(Icons.camera_alt),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _interpreter?.close();
    super.dispose();
  }
}

class DetectionBoxPainter extends CustomPainter {
  final List<Map<String, dynamic>>? recognitions;
  final int imageHeight;
  final int imageWidth;

  DetectionBoxPainter({
    required this.recognitions,
    required this.imageHeight,
    required this.imageWidth,
  });

  @override
  void paint(Canvas canvas, Size size) {
    if (recognitions == null) return;

    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 3.0
      ..color = Colors.red;

    for (final detection in recognitions!) {
      final rect = _normalizedRectToScreen(
        detection['bounds'] as List<double>,
        size,
        imageHeight,
        imageWidth,
      );
      
      canvas.drawRect(rect, paint);
      
      final textPainter = TextPainter(
        text: TextSpan(
          text: '${detection['class']}: ${(detection['score'] * 100).toStringAsFixed(0)}%',
          style: TextStyle(
            color: Colors.white,
            fontSize: 16,
            backgroundColor: Colors.black54,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();

      textPainter.paint(canvas, rect.topLeft);
    }
  }

  Rect _normalizedRectToScreen(
    List<double> normalizedRect,
    Size size,
    int imageHeight,
    int imageWidth,
  ) {
    return Rect.fromLTRB(
      normalizedRect[0] * size.width,
      normalizedRect[1] * size.height,
      normalizedRect[2] * size.width,
      normalizedRect[3] * size.height,
    );
  }

  @override
  bool shouldRepaint(DetectionBoxPainter oldDelegate) {
    return recognitions != oldDelegate.recognitions;
  }
}