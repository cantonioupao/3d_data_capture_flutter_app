import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../screens/camera_screen.dart';
import '../screens/stored_images_screen.dart';
import '../screens/settings_screen.dart';
import '../app_state.dart';

class BaseScreen extends StatefulWidget {
  final Widget body;
  final int selectedIndex;

  const BaseScreen({
    Key? key,
    required this.body,
    required this.selectedIndex,
  }) : super(key: key);

  @override
  _BaseScreenState createState() => _BaseScreenState();
}

class _BaseScreenState extends State<BaseScreen> {
  void _onItemTapped(int index) {
    final appState = Provider.of<AppState>(context, listen: false);
    switch (index) {
      case 0:
        Navigator.pushReplacement(
          context,
          MaterialPageRoute(
            builder: (context) => BaseScreen(
              selectedIndex: 0,
              body: CameraScreen(),
            ),
          ),
        );
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
    return Scaffold(
      body: widget.body,
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
        currentIndex: widget.selectedIndex,
        selectedItemColor: Theme.of(context).bottomNavigationBarTheme.selectedItemColor,
        unselectedItemColor: Theme.of(context).bottomNavigationBarTheme.unselectedItemColor,
        onTap: _onItemTapped,
      ),
    );
  }
}