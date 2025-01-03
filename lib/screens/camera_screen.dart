import 'package:flutter/material.dart';
import 'package:camera/camera.dart';
import 'object_detection_screen.dart';
import '../widgets/bottom_menu.dart';
import 'dart:io';
import 'package:image/image.dart' as img_lib;
import 'package:provider/provider.dart';
import '../app_state.dart';

class CameraScreen extends StatefulWidget {
  @override
  State<CameraScreen> createState() => _CameraScreenState();
}

class _CameraScreenState extends State<CameraScreen> with SingleTickerProviderStateMixin {
  late CameraController _controller;
  late Future<void> _initializeControllerFuture;
  late AnimationController _animationController;
  late CameraDescription _currentCamera;
  bool _isFrontCamera = false;
  bool _isSwitchingCamera = false;

  @override
  void initState() {
    super.initState();
    final appState = Provider.of<AppState>(context, listen: false);
    _currentCamera = appState.cameras!.first;
    _controller = CameraController(_currentCamera, ResolutionPreset.max);
    _initializeControllerFuture = _controller.initialize();
    _animationController = AnimationController(
      duration: const Duration(milliseconds: 300),
      vsync: this,
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    _animationController.dispose();
    super.dispose();
  }

  Future<void> _takePicture() async {
    try {
      await _initializeControllerFuture;
      final image = await _controller.takePicture();
      Navigator.push(
        context,
        MaterialPageRoute(
          builder: (context) => ObjectDetectionScreen(
            imagePath: image.path,
          ),
        ),
      );
    } catch (e) {
      print(e);
    }
  }

  Future<void> _switchCamera() async {
    if (_isSwitchingCamera) return;

    setState(() {
      _isSwitchingCamera = true;
    });

    try {
      final appState = Provider.of<AppState>(context, listen: false);
      _isFrontCamera = !_isFrontCamera;
      _currentCamera = _isFrontCamera
          ? appState.cameras!.firstWhere((camera) => camera.lensDirection == CameraLensDirection.front)
          : appState.cameras!.firstWhere((camera) => camera.lensDirection == CameraLensDirection.back);

      await _controller.dispose();

      _controller = CameraController(_currentCamera, ResolutionPreset.max);
      _initializeControllerFuture = _controller.initialize();
      await _initializeControllerFuture;
    } catch (e) {
      print(e);
    } finally {
      setState(() {
        _isSwitchingCamera = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        FutureBuilder<void>(
          future: _initializeControllerFuture,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.done) {
              return Center(
                child: ClipRect(
                  child: AspectRatio(
                    aspectRatio: 1.0,
                    child: CameraPreview(_controller),
                  ),
                ),
              );
            } else {
              return Center(child: CircularProgressIndicator());
            }
          },
        ),
        Positioned(
          bottom: 20,
          left: 20,
          child: FloatingActionButton(
            onPressed: _switchCamera,
            heroTag: 'switchCamera',
            child: Icon(Icons.switch_camera),
            tooltip: 'Switch Camera',
          ),
        ),
        Positioned(
          bottom: 20,
          right: 20,
          child: FloatingActionButton(
            onPressed: _takePicture,
            heroTag: 'takePicture',
            child: Icon(Icons.camera_alt),
            tooltip: 'Take Picture',
          ),
        ),
      ],
    );
  }
}