import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  runApp(MyApp());
}

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Custom AAC',
      theme: ThemeData(
        primarySwatch: Colors.blue,
      ),
      home: MyHomePage(),
    );
  }
}

class MyHomePage extends StatefulWidget {
  @override
  _MyHomePageState createState() => _MyHomePageState();
}

class _MyHomePageState extends State<MyHomePage> {
  List<ImageLabel> imageLabels = [];

  final FlutterTts flutterTts = FlutterTts();
  final ImagePicker _picker = ImagePicker();
  late SharedPreferences _prefs;
  bool _editMode = false;

  Future<void> _toggleEditMode() async {
    setState(() {
      _editMode = !_editMode;
    });
  }

  Future<void> _removeImageLabel(int index) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (BuildContext context) => AlertDialog(
        title: Text('Remove Image'),
        content: Text('Are you sure you want to remove this image?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: Text('Cancel'),
          ),
          TextButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: Text('Remove'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      final removedImage = imageLabels.removeAt(index);
      final savedImages = _prefs.getStringList('images') ?? [];
      savedImages.remove(jsonEncode(removedImage.toJson()));
      _prefs.setStringList('images', savedImages);

      setState(() {
        imageLabels = List.from(imageLabels);
      });
    }
  }

  @override
  void initState() {
    super.initState();
    initSharedPreferences();
    // Initialize the text-to-speech engine
    flutterTts.setSpeechRate(0.5);
    flutterTts.setVolume(1.0);
    flutterTts.setPitch(1.0);
  }

  void initSharedPreferences() async {
    _prefs = await SharedPreferences.getInstance();
    loadImages();
  }

  void loadImages() {
    List<String> savedImages = _prefs.getStringList('images') ?? [];

    setState(() {
      imageLabels = savedImages
          .map((imageJson) => ImageLabel.fromJson(jsonDecode(imageJson)))
          .toList();
    });
  }

  Future<void> _speakLabel(String label) async {
    await flutterTts.speak(label);
  }

  Future<void> _addImageLabel() async {
    final pickedFile = await showDialog<PickedFile>(
      context: context,
      builder: (BuildContext context) => ImageSourceDialog(),
    );

    if (pickedFile != null) {
      final File imageFile = File(pickedFile.path);
      final String label = await showDialog(
        context: context,
        builder: (BuildContext context) => LabelInputDialog(),
      );

      if (label != null) {
        final newImageLabel = ImageLabel(imageFile, label);
        setState(() {
          imageLabels.add(newImageLabel);
        });
        saveImage(newImageLabel);
      }
    }
  }

  void saveImage(ImageLabel imageLabel) {
    final String imageJson = jsonEncode(imageLabel.toJson());
    List<String> savedImages = _prefs.getStringList('images') ?? [];
    savedImages.add(imageJson);
    _prefs.setStringList('images', savedImages);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('Hello, CEDRIC !!'),
        actions: [
          IconButton(
            icon: Icon(Icons.edit),
            onPressed: _toggleEditMode,
          ),
        ],
      ),
      body: GridView.count(
        crossAxisCount: 3, // Restrict the grid to 3 columns
        childAspectRatio: 0.75, // Adjust the aspect ratio to fit a 3x4 grid
        mainAxisSpacing: 8.0, // Reduce the vertical spacing between grid cells
        crossAxisSpacing: 8.0, // Reduce the horizontal spacing between grid cells
        padding: EdgeInsets.all(8.0), // Add padding around the grid
        children: List.generate(imageLabels.length, (index) {
          return GestureDetector(
            onTap: () => _speakLabel(imageLabels[index].label),
            child: Stack(
              children: [
                Container(
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.grey,
                      width: 1.0,
                    ),
                  ),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      Expanded(
                        child: AspectRatio(
                          aspectRatio: 1.0, // Adjust the aspect ratio to create square images
                          child: Image.file(
                            imageLabels[index].image,
                            fit: BoxFit.cover,
                          ),
                        ),
                      ),
                      SizedBox(height: 10),
                      Text(imageLabels[index].label),
                    ],
                  ),
                ),
                if (_editMode)
                  Positioned(
                    top: 0,
                    right: 0,
                    child: IconButton(
                      icon: Icon(Icons.delete),
                      onPressed: () => _removeImageLabel(index),
                    ),
                  ),
              ],
            ),
          );
        }),
      ),
      floatingActionButton: FloatingActionButton(
        onPressed: _addImageLabel,
        tooltip: 'Add Image',
        child: Icon(Icons.add),
      ),
    );
  }
}

class ImageLabel {
  final File image;
  final String label;

  ImageLabel(this.image, this.label);

  Map<String, dynamic> toJson() {
    return {
      'image': image.path,
      'label': label,
    };
  }

  factory ImageLabel.fromJson(Map<String, dynamic> json) {
    return ImageLabel(
      File(json['image']),
      json['label'],
    );
  }
}

class ImageSourceDialog extends StatelessWidget {
  final ImagePicker _picker = ImagePicker();

  Future<PickedFile?> _pickImage(ImageSource source) async {
    final pickedFile = await _picker.getImage(source: source);
    return pickedFile;
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Choose Image Source'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          ListTile(
            leading: Icon(Icons.photo_library),
            title: Text('Gallery'),
            onTap: () async {
              PickedFile? pickedFile = await _pickImage(ImageSource.gallery);
              Navigator.of(context).pop(pickedFile);
            },
          ),
          ListTile(
            leading: Icon(Icons.camera_alt),
            title: Text('Camera'),
            onTap: () async {
              PickedFile? pickedFile = await _pickImage(ImageSource.camera);
              Navigator.of(context).pop(pickedFile);
            },
          ),
        ],
      ),
    );
  }
}

class LabelInputDialog extends StatefulWidget {
  @override
  _LabelInputDialogState createState() => _LabelInputDialogState();
}

class _LabelInputDialogState extends State<LabelInputDialog> {
  final TextEditingController _labelController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text('Enter Label'),
      content: TextField(
        controller: _labelController,
        decoration: InputDecoration(hintText: 'Label'),
      ),
      actions: [
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
          },
          child: Text('Cancel'),
        ),

        TextButton(
          onPressed: () {
            Navigator.of(context).pop(_labelController.text);
          },
          child: Text('OK'),
        ),

      ],
    );
  }

  @override
  void dispose() {
    _labelController.dispose();
    super.dispose();
  }
}
