import 'dart:io';
import 'package:fab_circular_menu/fab_circular_menu.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:tflite/tflite.dart';
import 'package:image_picker/image_picker.dart';

void main() => runApp(MyApp());

String ssdM = "SSD MobileNet";
String yoloM = "Tiny YOLOv2";

class MyApp extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      theme: ThemeData.dark(),
      debugShowCheckedModeBanner: false,
      home: Homepage(),
    );
  }
}

class Homepage extends StatefulWidget {
  @override
  _HomepageState createState() => _HomepageState();
}

class _HomepageState extends State<Homepage> {
  String _model = yoloM;

  bool _isBusy = false;

  File _image;

  List _recognizations;

  double _tempimageWidth;
  double _tempimageHeight;

  final _picker = ImagePicker();

  @override
  void initState() {
    super.initState();
    _isBusy = true;
    loadModel().then((value) {
      setState(() {
        _isBusy = false;
      });
    });
  }

  loadModel() async {
    Tflite.close();
    try {
      String res;
      if (_model == yoloM) {
        res = await Tflite.loadModel(
            model: "tfliteModels/yolov2_tiny.tflite",
            labels: "tfliteModels/yolov2_tiny.txt");
      } else {
        res = await Tflite.loadModel(
            model: "tfliteModels/ssd_mobilenet.tflite",
            labels: "tfliteModels/ssd_mobilenet.txt");
      }
      print(res);
    } on PlatformException {
      print("Failed to load the model");
    }
  }

  pickFromGallery() async {
    PickedFile timage = await _picker.getImage(source: ImageSource.gallery);
    File _tempimage = File(timage.path);
    if (_tempimage == null) return;
    setState(() {
      _isBusy = true;
    });
    doingPredection(_tempimage);
  }

  Future pickFromCamera() async {
    File timage = await ImagePicker.pickImage(source: ImageSource.camera);

    if (timage == null) return;
    setState(() {
      _isBusy = true;
    });
    doingPredection(timage);
  }

  doingPredection(_tempimage) async {
    if (_tempimage == null) return;

    if (_model == yoloM) {
      await yolov2Tiny(_tempimage);
    } else {
      await ssd(_tempimage);
    }

    FileImage(_tempimage)
        .resolve(ImageConfiguration())
        .addListener(ImageStreamListener((ImageInfo info, bool _) {
      _tempimageWidth = info.image.height.toDouble();
      _tempimageHeight = info.image.width.toDouble();
    }));

    setState(() {
      _image = _tempimage;
      _isBusy = false;
    });
  }

  yolov2Tiny(File image) async {
    var recognizations = await Tflite.detectObjectOnImage(
      path: image.path,
      model: "YOLO",
      threshold: 0.3,
      imageMean: 0.0,
      imageStd: 255.0,
      numResultsPerClass: 1,
    );

    setState(() {
      _recognizations = recognizations;
    });
  }

  ssd(File image) async {
    var recognizations = await Tflite.detectObjectOnImage(
      path: image.path,
      numResultsPerClass: 1,
    );

    setState(() {
      _recognizations = recognizations;
    });
  }

  List<Widget> renderBoxes(Size screen) {
    if (_recognizations == null) return [];
    if (_tempimageWidth == null || _tempimageHeight == null) return [];

    double factorX = screen.width;
    double factorY = _tempimageHeight / _tempimageWidth * screen.width;

    return _recognizations.map((e) {
      return Positioned(
        left: e["rect"]["x"] * factorX,
        top: e["rect"]["y"] * factorY,
        width: e["rect"]["w"] * factorX,
        height: e["rect"]["h"] * factorY,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.all(Radius.circular(8.0)),
            border: Border.all(color: Colors.red, width: 3),
          ),
          child: Text(
            "${e["detectedClass"]} ${(e["confidenceInClass"] * 100).toStringAsFixed(0)}%",
            style: TextStyle(
              background: Paint()..color = Colors.red,
              color: Colors.white,
              fontSize: 15.0,
            ),
          ),
        ),
      );
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    Size size = MediaQuery.of(context).size;

    List<Widget> stack = [];

    stack.add(
      Positioned(
        top: 0.0,
        left: 0.0,
        width: size.width,
        //height: size.height - 50.0,
        child: _image == null
            ? Container(
                padding: EdgeInsets.symmetric(vertical: 300),
                alignment: Alignment.bottomCenter,
                child: Center(
                    child: Text(
                  'No image yet selected',
                  style: TextStyle(fontSize: 20.0, fontWeight: FontWeight.bold),
                )),
              )
            : Image.file(_image),
      ),
    );

    stack.addAll(renderBoxes(size));

    return Scaffold(
      appBar: AppBar(
        title: Text('Detection of Objects'),
      ),
      floatingActionButton: FabCircularMenu(
        children: [
          IconButton(
              icon: Icon(
                Icons.camera,
                color: Colors.red,
                size: 50.0,
              ),
              onPressed: pickFromCamera),
          IconButton(
              icon: Icon(
                Icons.image,
                size: 50.0,
                color: Colors.orange,
              ),
              onPressed: pickFromGallery),
        ],
        fabElevation: 5.0,
        fabOpenColor: Colors.black,
        fabCloseColor: Colors.white,
        fabOpenIcon: Icon(
          Icons.keyboard_arrow_up,
          size: 40.0,
          color: Colors.black,
        ),
        fabCloseIcon: Icon(
          Icons.keyboard_arrow_down,
          color: Colors.white,
          size: 40.0,
        ),
        ringWidth: 100.0,
        ringDiameter: 350.0,
        fabMargin: EdgeInsets.all(20.0),
        ringColor: Colors.transparent,
        fabColor: Colors.amber,
      ),
      body: _isBusy
          ? Center(
              child: CircularProgressIndicator(),
            )
          : Stack(
              children: stack,
            ),
    );
  }
}
