import 'package:flutter/material.dart';
import 'dart:io';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as path;
import '../widgets/bottom_menu.dart';

class StoredImagesScreen extends StatefulWidget {
  @override
  _StoredImagesScreenState createState() => _StoredImagesScreenState();
}

class _StoredImagesScreenState extends State<StoredImagesScreen> {
  late Future<List<File>> _storedImages;

  @override
  void initState() {
    super.initState();
    _storedImages = _loadStoredImages();
  }

  Future<List<File>> _loadStoredImages() async {
    final directory = await getApplicationDocumentsDirectory();
    final storedImagesDir = Directory(path.join(directory.path, 'stored_images'));

    if (!storedImagesDir.existsSync()) {
      return [];
    }

    final storedImages = storedImagesDir
        .listSync()
        .where((item) => item is File)
        .map((item) => item as File)
        .toList();

    return storedImages;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: FutureBuilder<List<File>>(
        future: _storedImages,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return Center(child: CircularProgressIndicator());
          } else if (snapshot.hasError) {
            return Center(child: Text('Error loading images'));
          } else if (!snapshot.hasData || snapshot.data!.isEmpty) {
            return Center(child: Text('No stored images'));
          } else {
            final storedImages = snapshot.data!;
            return GridView.builder(
              gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                crossAxisCount: 3,
                crossAxisSpacing: 4.0,
                mainAxisSpacing: 4.0,
              ),
              itemCount: storedImages.length,
              itemBuilder: (context, index) {
                final imageFile = storedImages[index];
                return Image.file(imageFile, fit: BoxFit.cover);
              },
            );
          }
        },
      ),
    );
  }
}