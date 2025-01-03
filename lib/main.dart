import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:camera/camera.dart';
import 'package:tflite_flutter/tflite_flutter.dart';
import 'app_state.dart';
import 'package:flutter/services.dart';
import 'screens/camera_screen.dart';
import 'screens/stored_images_screen.dart';
import 'screens/settings_screen.dart';
import 'widgets/bottom_menu.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final cameras = await availableCameras();
  final interpreter = await loadModel();
  final labels = await loadLabels();

  runApp(
    ChangeNotifierProvider(
      create: (context) => AppState()
        ..setCameras(cameras)
        ..setInterpreter(interpreter)
        ..setLabels(labels),
      child: MyApp(),
    ),
  );
}

Future<Interpreter> loadModel() async {
  final interpreterOptions = InterpreterOptions()
    ..threads = 4
    ..useNnApiForAndroid = true;

  return await Interpreter.fromAsset(
    'assets/detect.tflite',
    options: interpreterOptions,
  );
}

Future<List<String>> loadLabels() async {
  final labelFile = await rootBundle.loadString('assets/labelmap.txt');
  return labelFile.split('\n').where((s) => s.isNotEmpty).toList();
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData(
        primaryColor: Color(0xFF0A0E21),
        colorScheme: ColorScheme.fromSwatch().copyWith(secondary: Colors.blue),
        textTheme: TextTheme(
          headlineLarge: TextStyle(
            fontFamily: 'Additiv',
            fontSize: 36,
            fontWeight: FontWeight.bold,
            color: Colors.white,
          ),
          bodyLarge: TextStyle(
            fontFamily: 'Additiv',
            fontSize: 18,
            color: Colors.white,
          ),
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: Colors.blue,
            foregroundColor: Colors.white,
          ),
        ),
        floatingActionButtonTheme: FloatingActionButtonThemeData(
          backgroundColor: Colors.blue,
          foregroundColor: Colors.white,
        ),
        bottomNavigationBarTheme: BottomNavigationBarThemeData(
          selectedItemColor: Colors.blue,
          unselectedItemColor: Colors.grey,
        ),
      ),
      home: BaseScreen(
        selectedIndex: 0,
        body: CameraScreen(), 
      ),
    );
  }
}