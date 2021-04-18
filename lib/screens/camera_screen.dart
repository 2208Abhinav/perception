import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:perception/main.dart';
import 'package:perception/utils/dimensions.dart';

class CameraScreen extends StatefulWidget {
  @override
  State<StatefulWidget> createState() {
    return _CameraScreenState();
  }
}

class _CameraScreenState extends State<CameraScreen> {
  bool _isLoading = false;
  CameraController _controller;
  Uint8List _imageBytes = Uint8List(0);
  double _imageHeightFactor = 0.65;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(cameras[0], ResolutionPreset.max);
    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {});
    });
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // if (!controller.value.isInitialized) {
    //   return Container();
    // }
    // return MaterialApp(
    //   home: CameraPreview(controller),
    // );
    final double viewportHeight = getViewportHeight(context);
    return Scaffold(
      appBar: AppBar(
        title: Text(
          "Scan the digit",
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: IconThemeData(color: Colors.black),
        backgroundColor: Colors.white,
        brightness: Brightness.light,
      ),
      body: Center(
        child: !_controller.value.isInitialized
            ? Text("Loading camera...")
            : Container(
                height: viewportHeight * 0.9,
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                  children: [
                    Container(
                      decoration: BoxDecoration(
                        border: Border.all(width: 3, color: Colors.white),
                        color: Colors.white,
                        boxShadow: [
                          BoxShadow(blurRadius: 5, color: Colors.black54)
                        ],
                      ),
                      child: Column(
                        children: [
                          SizedBox(
                            height: viewportHeight * _imageHeightFactor,
                            child: _imageBytes.isNotEmpty
                                ? Container(
                                    width: (viewportHeight * _imageHeightFactor) / _controller.value.aspectRatio,
                                    height: viewportHeight * _imageHeightFactor,
                                    child: Image.memory(_imageBytes),
                                  )
                                : CameraPreview(_controller),
                          ),
                          SizedBox(height: 5),
                          Text(
                            'Digit',
                            style: TextStyle(fontWeight: FontWeight.bold),
                          ),
                          SizedBox(height: 5),
                        ],
                      ),
                    ),
                    !_isLoading
                        ? _imageBytes.isEmpty ? _buildCaptureButton() : _buildClassifyButton()
                        : CircularProgressIndicator()
                  ],
                ),
              ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    return GestureDetector(
      child: Container(
        height: 56,
        width: 56,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: Colors.red,
          border: Border.all(width: 3, color: Colors.white),
          boxShadow: [BoxShadow(blurRadius: 5, color: Colors.black54)],
        ),
      ),
      onTap: () async {
        setState(() {
          _isLoading = true;
        });
        XFile imageFile = await _controller.takePicture();
        Uint8List imageBytes = await imageFile.readAsBytes();
        setState(() {
          _imageBytes = imageBytes;
          _isLoading = false;
        });
      },
    );
  }

  Widget _buildClassifyButton() {
    return ElevatedButton(
      child: Text(
        "Classify",
        style: TextStyle(fontSize: 18),
      ),
      onPressed: () {

      },
    );
  }
}
