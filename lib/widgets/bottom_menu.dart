import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/camera_screen.dart';
import '../screens/stored_images_screen.dart';
import '../screens/settings_screen.dart';
import '../app_state.dart';

class BaseScreen extends StatefulWidget {
  final int selectedIndex;
  final Widget body;

  BaseScreen({required this.selectedIndex, required this.body});

  @override
  _BaseScreenState createState() => _BaseScreenState();
}

class _BaseScreenState extends State<BaseScreen> {
  late PageController _pageController;
  int _selectedIndex = 0;
  late Widget _currentBody;

  @override
  void initState() {
    super.initState();
    _selectedIndex = widget.selectedIndex;
    _currentBody = widget.body;
    _pageController = PageController(initialPage: _selectedIndex);
  }

  void _onItemTapped(int index) {
    setState(() {
      _selectedIndex = index;
      switch (index) {
        case 0:
          _currentBody = CameraScreen();
          break;
        case 1:
          _currentBody = StoredImagesScreen();
          break;
        case 2:
          _currentBody = SettingsScreen();
          break;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: _currentBody,
      bottomNavigationBar: BottomNavigationBar(
        items: const <BottomNavigationBarItem>[
          BottomNavigationBarItem(
            icon: Icon(Icons.camera),
            label: 'Camera Capture',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.photo_library),
            label: 'Stored Images',
          ),
          BottomNavigationBarItem(
            icon: Icon(Icons.settings),
            label: 'Settings',
          ),
        ],
        currentIndex: _selectedIndex,
        selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
        unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
        onTap: _onItemTapped,
      ),
    );
  }
}