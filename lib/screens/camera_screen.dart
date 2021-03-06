import 'dart:convert';

import 'package:http/http.dart' as http;
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
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
  bool _sendingImage = false;

  List<String> _probabilities = [];

  double ar = 1;

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
    final double viewportHeight = getViewportHeight(context);
    double digitFrameHW = 0;
    double cameraPH = 0;
    double cameraPW = 0;

    try {
      digitFrameHW = ((viewportHeight * _imageHeightFactor) /
              _controller.value.aspectRatio) *
          0.8;
      cameraPH = viewportHeight * _imageHeightFactor;
      cameraPW =
          (viewportHeight * _imageHeightFactor) / _controller.value.aspectRatio;
      ar = _controller.value.aspectRatio;
    } catch (_) {}

    return Scaffold(
      appBar: AppBar(
        title: Text(
          _probabilities.isEmpty ? "Scan the digit" : "Classification Data",
          style: TextStyle(color: Colors.black),
        ),
        iconTheme: IconThemeData(color: Colors.black),
        backgroundColor: Colors.white,
        brightness: Brightness.light,
      ),
      body: Center(
        child: !_controller.value.isInitialized
            ? Text("Loading camera...")
            : _probabilities.isNotEmpty
                ? Container(
                    decoration: BoxDecoration(
                        border: Border.all(width: 1, color: Colors.black54)),
                    height: viewportHeight * 0.85,
                    child: SingleChildScrollView(
                      child: DataTable(
                        columns: [
                          DataColumn(label: Center(child: Text("Digit"))),
                          DataColumn(label: Center(child: Text("Probability")))
                        ],
                        rows: _probabilities
                            .asMap()
                            .entries
                            .map((e) => DataRow(cells: [
                                  DataCell(Text(e.key.toString())),
                                  DataCell(Text(e.value.toString()))
                                ]))
                            .toList(),
                      ),
                    ),
                  )
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
                              _imageBytes.isEmpty
                                  ? SizedBox(
                                      height:
                                          viewportHeight * _imageHeightFactor,
                                      child: Stack(
                                        alignment: Alignment.center,
                                        children: [
                                          CameraPreview(_controller),
                                          Container(
                                            height: digitFrameHW,
                                            width: digitFrameHW,
                                            decoration: BoxDecoration(
                                              color: Colors.transparent,
                                              border: Border.all(
                                                width: 2,
                                                color: Colors.white70,
                                              ),
                                            ),
                                          )
                                        ],
                                      ))
                                  : Container(
                                      width: digitFrameHW,
                                      height: digitFrameHW,
                                      child: Image.memory(_imageBytes),
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
                            ? _imageBytes.isEmpty
                                ? _buildCaptureButton()
                                : _sendingImage
                                    ? Text(
                                        "Sending image...",
                                        style: TextStyle(
                                            fontWeight: FontWeight.bold,
                                            fontSize: 18),
                                      )
                                    : _buildClassifyButton()
                            : Text(
                                "Processing image...",
                                style: TextStyle(
                                    fontWeight: FontWeight.bold, fontSize: 18),
                              )
                      ],
                    ),
                  ),
      ),
    );
  }

  Widget _buildCaptureButton() {
    if (!_controller.value.isInitialized) return CircularProgressIndicator();
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
        try {
          setState(() {
            _isLoading = true;
          });
          XFile imageFile = await _controller.takePicture();
          Uint8List imageBytes = await imageFile.readAsBytes();
          img.Image image = img.decodeImage(imageBytes);

          int h1 = image.height.toInt();
          int w1 = image.width;
          int h2 = (w1 * 0.8).toInt();
          int w2 = h2;
          setState(() {
            _imageBytes = Uint8List.fromList(
              img.encodeJpg(
                img.copyCrop(
                  image,
                  (w1 - w2) ~/ 2,
                  (h1 - h2) ~/ 2,
                  w2.toInt(),
                  h2.toInt(),
                ),
              ),
            );
            _isLoading = false;
          });
        } catch (_) {
          setState(() {
            _isLoading = false;
          });
        }
      },
    );
  }

  Widget _buildClassifyButton() {
    return ElevatedButton(
      child: Text(
        "Classify",
        style: TextStyle(fontSize: 18),
      ),
      onPressed: _sendImage,
    );
  }

  void _sendImage() async {
    setState(() {
      _sendingImage = true;
    });

    try {
      var response = await http.post(
        Uri.parse("{API}}/api/test"),
        headers: {"content-type": "application/json"},
        body: json.encode(
          {"image": _imageBytes},
        ),
      );
      _probabilities =
          List<String>.from(json.decode(response.body)["probabilities"]);
    } catch (e) {
      print("####");
      print(e.toString());
    }

    setState(() {
      _sendingImage = false;
    });
  }
}
