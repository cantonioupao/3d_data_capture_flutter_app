import 'dart:async';
import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img_lib;

void main() async {
  try {
    WidgetsFlutterBinding.ensureInitialized();
    final cameras = await availableCameras();
    if (cameras.isEmpty) throw 'No cameras found';
    runApp(MyApp(cameras: cameras));
  } catch (e) {
    print('Failed to initialize: $e');
  }
}

class MyApp extends StatelessWidget {
  final List<CameraDescription> cameras;
  const MyApp({Key? key, required this.cameras}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Object Detection',
      theme: ThemeData(primarySwatch: Colors.blue),
      home: ObjectDetectionScreen(cameras: cameras),
    );
  }
}

class ObjectDetectionScreen extends StatefulWidget {
  final List<CameraDescription> cameras;
  const ObjectDetectionScreen({Key? key, required this.cameras}) : super(key: key);

  @override
  _ObjectDetectionScreenState createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> with WidgetsBindingObserver {
  CameraController? _cameraController;
  Interpreter? _interpreter;
  bool _isDetecting = false;
  bool _isInitialized = false;
  List<dynamic>? _recognitions;
  List<String> _labels = [];
  double _fps = 0;
  int _imageHeight = 0;
  int _imageWidth = 0;
  int _lastProcessingTime = 0;
  Timer? _captureTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initializeAll();
  }

  Future<void> _initializeAll() async {
    try {
      print('Starting initialization...');
      
      print('Loading model...');
      await _loadModel();
      
      print('Loading labels...');
      await _loadLabels();
      
      print('Initializing camera...');
      await _initializeCamera();
      
      if (_interpreter == null) {
        throw Exception('Failed to initialize interpreter');
      }
      
      if (_cameraController == null) {
        throw Exception('Failed to initialize camera controller');
      }
      
      if (_labels.isEmpty) {
        throw Exception('Failed to load labels');
      }

      print('All components initialized successfully');
      setState(() => _isInitialized = true);
    } catch (e) {
      print('Initialization error: $e');
      _showError('Initialization failed: ${e.toString()}');
    }
  }

  Future<void> _loadModel() async {
    try {
      final interpreterOptions = InterpreterOptions()
        ..threads = 4
        ..useNnApiForAndroid = true;
        
      _interpreter = await Interpreter.fromAsset(
        'assets/detect.tflite',
        options: interpreterOptions,
      );
      
      final inputShape = _interpreter?.getInputTensor(0).shape;
      print('Model input shape: $inputShape');
      
      if (inputShape == null || inputShape.length != 4) {
        throw Exception('Model input must be 4-dimensional [batch_size, height, width, channels]');
      }
      
      if (inputShape[1] != 300 || inputShape[2] != 300 || inputShape[3] != 3) {
        throw Exception('Model input shape must be [1, 300, 300, 3]');
      }
    } catch (e) {
      throw Exception('Model loading failed: $e');
    }
  }

  Future<void> _loadLabels() async {
    try {
      final labelFile = await rootBundle.loadString('assets/labelmap.txt');
      _labels = labelFile.split('\n').where((s) => s.isNotEmpty).toList();
      print('Labels loaded successfully: ${_labels.length} labels');
      print('First few labels: ${_labels.take(5).toList()}');
    } catch (e) {
      print('Label loading error: $e');
      throw Exception('Label loading failed: $e');
    }
  }

  Future<void> _initializeCamera() async {
    _cameraController = CameraController(
      widget.cameras[0],
      ResolutionPreset.medium,
      enableAudio: false,
      imageFormatGroup: ImageFormatGroup.yuv420,
    );

    try {
      await _cameraController?.initialize();
      _imageHeight = _cameraController?.value.previewSize?.height.toInt() ?? 0;
      _imageWidth = _cameraController?.value.previewSize?.width.toInt() ?? 0;
      print('Camera initialized: $_imageWidth x $_imageHeight');
      
      // Start periodic capture
      _captureTimer = Timer.periodic(Duration(milliseconds: 1000), (_) {
        if (!_isDetecting) {
          _captureAndDetect();
        }
      });
      
    } catch (e) {
      throw Exception('Camera initialization failed: $e');
    }
  }

Future<void> _captureAndDetect() async {
    if (_isDetecting || _cameraController == null || !_cameraController!.value.isInitialized) {
      return;
    }

    _isDetecting = true;
    final currentTime = DateTime.now().millisecondsSinceEpoch;

    try {
      // Capture image
      final image = await _cameraController!.takePicture();
      
      // Convert to bytes and preprocess
      final bytes = await image.readAsBytes();
      final img = img_lib.decodeImage(bytes);
      
      if (img == null) {
        print('Failed to decode image');
        return;
      }

      // Resize image
      final resized = img_lib.copyResize(img, width: 300, height: 300);
      
      // Convert to RGB format
      final inputData = List<int>.filled(300 * 300 * 3, 0);
      var inputIndex = 0;
      
      for (var y = 0; y < resized.height; y++) {
        for (var x = 0; x < resized.width; x++) {
          final pixel = resized.getPixel(x, y);
          inputData[inputIndex++] = pixel.r.toInt();  // Red
          inputData[inputIndex++] = pixel.g.toInt();  // Green
          inputData[inputIndex++] = pixel.b.toInt();  // Blue
        }
      }

      // Run inference
      final results = await _runInference(inputData);
      
      if (mounted) {
        setState(() {
          _recognitions = results;
          _fps = 1000 / (currentTime - _lastProcessingTime);
          _lastProcessingTime = currentTime;
        });
      }
    } catch (e) {
      print('Processing error: $e');
    } finally {
      _isDetecting = false;
    }
}

  Future<List<Map<String, dynamic>>> _runInference(List<int> imageData) async {
    try {
      if (_interpreter == null) {
        print('Interpreter is null');
        return [];
      }

      print('Starting inference...');
      print('Input data length: ${imageData.length}');

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

      try {
        _interpreter!.runForMultipleInputs([reshapedInput], outputs);
        print('Inference completed successfully');
      } catch (e) {
        print('Error during inference: $e');
        throw e;
      }

      return _processResults(
        outputLocations[0],
        outputScores[0],
        outputClasses[0]
      );

    } catch (e) {
      print('Inference error: $e');
      print('Stack trace: ${StackTrace.current}');
      return [];
    }
  }

  List<Map<String, dynamic>> _processResults(
    List<List<double>> boxes,
    List<double> scores,
    List<double> classes,
  ) {
    if (_labels.isEmpty) {
      print('Labels list is empty');
      return [];
    }

    final results = <Map<String, dynamic>>[];
    
    try {
      for (var i = 0; i < scores.length; i++) {
        final classIndex = classes[i].round();
        if (classIndex < 0 || classIndex >= _labels.length) {
          print('Invalid class index: $classIndex');
          continue;
        }

        if (scores[i] >= 0.7) {
          results.add({
            'bounds': boxes[i],
            'score': scores[i],
            'class': _labels[classIndex],
          });
        }
      }
    } catch (e) {
      print('Error processing results: $e');
    }
    
    return results;
  }

  void _showError(String message) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text('Error'),
        content: Text(message),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text('OK'),
          ),
        ],
      ),
    );
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_cameraController?.value.isInitialized != true) return;
    
    if (state == AppLifecycleState.inactive) {
      _captureTimer?.cancel();
      _cameraController?.dispose();
    } else if (state == AppLifecycleState.resumed) {
      _initializeCamera();
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized || _cameraController?.value.isInitialized != true) {
      return Scaffold(body: Center(child: CircularProgressIndicator()));
    }

    return Scaffold(
      appBar: AppBar(title: Text('Object Detection')),
      body: Stack(
        fit: StackFit.expand,
        children: [
          if (_cameraController != null && _cameraController!.value.isInitialized)
            CameraPreview(_cameraController!),
          CustomPaint(
            painter: DetectionBoxPainter(
              recognitions: _recognitions,
              imageHeight: _imageHeight,
              imageWidth: _imageWidth,
            ),
          ),
          if (_isDetecting)
            Container(
              color: Colors.black26,
              child: Center(
                child: CircularProgressIndicator(),
              ),
            ),
          Positioned(
            top: 10,
            left: 10,
            child: Container(
              padding: EdgeInsets.all(8),
              decoration: BoxDecoration(
                color: Colors.black54,
                borderRadius: BorderRadius.circular(4),
              ),
              child: Text(
                'FPS: ${_fps.toStringAsFixed(1)}',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  @override
  void dispose() {
    _captureTimer?.cancel();
    WidgetsBinding.instance.removeObserver(this);
    _cameraController?.dispose();
    _interpreter?.close();
    super.dispose();
  }
}

class DetectionBoxPainter extends CustomPainter {
  final List<dynamic>? recognitions;
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
        detection['bounds'],
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
    final double scaleX = size.width / imageWidth;
    final double scaleY = size.height / imageHeight;
    
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