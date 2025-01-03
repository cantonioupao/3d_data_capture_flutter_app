import 'package:flutter/material.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'dart:io';
import 'package:image/image.dart' as img_lib;
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../widgets/detection_box_painter.dart';
import 'stored_images_screen.dart';
import 'settings_screen.dart';
import 'package:provider/provider.dart';
import '../app_state.dart';
import '../widgets/bottom_menu.dart';

class ObjectDetectionScreen extends StatefulWidget {
  final String imagePath;

  const ObjectDetectionScreen({
    Key? key,
    required this.imagePath,
  }) : super(key: key);

  @override
  _ObjectDetectionScreenState createState() => _ObjectDetectionScreenState();
}

class _ObjectDetectionScreenState extends State<ObjectDetectionScreen> {
  List<Map<String, dynamic>>? _detections;
  late img_lib.Image _originalImage;
  int _selectedIndex = 0;

  @override
  void initState() {
    super.initState();
    _runDetection();
  }

  Future<void> _runDetection() async {
    final bytes = await File(widget.imagePath).readAsBytes();
    final img = img_lib.decodeImage(bytes);

    if (img == null) return;

    _originalImage = img;

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

    final reshapedInput = List.generate(1, (b) =>
      List.generate(300, (y) =>
        List.generate(300, (x) =>
          List.generate(3, (c) =>
            inputData[(y * 300 + x) * 3 + c]
          )
        )
      )
    );

    final outputLocations = List.filled(1, List.filled(10, List.filled(4, 0.0)));
    final outputClasses = List.filled(1, List.filled(10, 0.0));
    final outputScores = List.filled(1, List.filled(10, 0.0));
    final numDetections = List.filled(1, 0.0);

    final appState = Provider.of<AppState>(context, listen: false);
    final outputs = {
      0: outputLocations,
      1: outputClasses,
      2: outputScores,
      3: numDetections,
    };
    appState.interpreter!.runForMultipleInputs([reshapedInput], outputs);

    final results = <Map<String, dynamic>>[];
    double confidenceThreshold = 0.6;

    for (var i = 0; i < outputScores[0].length; i++) {
      if (outputScores[0][i] >= confidenceThreshold) {
        final classIndex = outputClasses[0][i].round();
        results.add({
          'bounds': outputLocations[0][i],
          'score': outputScores[0][i],
          'class': appState.labels![classIndex],
        });
        print("ymin, xmin, ymax, xmax: ${outputLocations[0][i]}");
      }
    }

    setState(() {
      _detections = results;
    });
  }

  Future<void> _storeImage() async {
    final directory = await getApplicationDocumentsDirectory();
    final fileName = path.basename(widget.imagePath);
    final newPath = path.join(directory.path, 'stored_images', fileName);

    final storedImage = File(newPath);
    await storedImage.create(recursive: true);
    await storedImage.writeAsBytes(await File(widget.imagePath).readAsBytes());

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('Image stored successfully!')),
    );
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
    });

    switch (index) {
      case 0:
        Navigator.pop(context); // Navigate back to the previous screen
        break;
      case 1:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BaseScreen(
              selectedIndex: 1,
              body: StoredImagesScreen(),
            ),
          ),
        );
        break;
      case 2:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BaseScreen(
              selectedIndex: 2,
              body: SettingsScreen(),
            ),
          ),
        );
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 300,
            height: 300,
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.file(
                  File(widget.imagePath),
                  fit: BoxFit.cover,
                ),
                if (_detections != null)
                  CustomPaint(
                    painter: DetectionBoxPainter(
                      recognitions: _detections,
                      imageHeight: _originalImage.height,
                      imageWidth: _originalImage.width,
                    ),
                  ),
              ],
            ),
          ),
          SizedBox(height: 20),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton(
                onPressed: () {
                  Navigator.pop(context);
                },
                icon: Icon(Icons.refresh),
                tooltip: 'Retry',
              ),
              SizedBox(width: 10),
              IconButton(
                onPressed: _storeImage,
                icon: Icon(Icons.save),
                tooltip: 'Store Image',
              ),
            ],
          ),
        ],
      ),
    );
  }
}