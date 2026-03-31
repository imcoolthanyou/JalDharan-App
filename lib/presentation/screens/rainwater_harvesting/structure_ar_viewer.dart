import 'dart:io';
import 'package:ar_flutter_plugin_updated/ar_flutter_plugin.dart';
import 'package:ar_flutter_plugin_updated/datatypes/config_planedetection.dart';
import 'package:ar_flutter_plugin_updated/datatypes/node_types.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_anchor_manager.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_location_manager.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_object_manager.dart';
import 'package:ar_flutter_plugin_updated/managers/ar_session_manager.dart';
import 'package:ar_flutter_plugin_updated/models/ar_node.dart';
import 'package:ar_flutter_plugin_updated/models/ar_anchor.dart';
import 'package:ar_flutter_plugin_updated/models/ar_hittest_result.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:vector_math/vector_math_64.dart' as vector;

class StructureARViewer extends StatefulWidget {
  final String modelPath;
  final String title;

  const StructureARViewer({
    super.key,
    required this.modelPath,
    required this.title,
  });

  @override
  State<StructureARViewer> createState() => _StructureARViewerState();
}

class _StructureARViewerState extends State<StructureARViewer> {
  ARSessionManager? arSessionManager;
  ARObjectManager? arObjectManager;
  ARAnchorManager? arAnchorManager;

  bool _isModelAdded = false;
  String? _localModelPath;

  @override
  void initState() {
    super.initState();
    _prepareModel();
  }

  Future<void> _prepareModel() async {
    // Copy asset to local file for AR plugin
    try {
      final filename = widget.modelPath.split('/').last;

      // Use Application Documents Directory for better persistence/access
      final directory = await getApplicationDocumentsDirectory();
      final file = File('${directory.path}/$filename');

      // Always overwrite to ensure latest version
      final byteData = await rootBundle.load(widget.modelPath);
      await file.writeAsBytes(
        byteData.buffer.asUint8List(
          byteData.offsetInBytes,
          byteData.lengthInBytes,
        ),
      );

      setState(() {
        _localModelPath =
            filename; // for fileSystemAppFolderGLB we usually need just the name if relative
      });
      debugPrint("Model copied to: ${file.path}");
    } catch (e) {
      debugPrint("Error copying models: $e");
    }
  }

  @override
  void dispose() {
    arSessionManager?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text(widget.title)),
      body: Stack(
        children: [
          ARView(
            onARViewCreated: onARViewCreated,
            planeDetectionConfig: PlaneDetectionConfig.horizontalAndVertical,
          ),
          if (!_isModelAdded)
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.all(20.0),
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Text(
                    _localModelPath == null
                        ? 'Preparing models...'
                        : 'Tap on the detected plane to place the structure',
                    style: const TextStyle(color: Colors.white),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  void onARViewCreated(
    ARSessionManager arSessionManager,
    ARObjectManager arObjectManager,
    ARAnchorManager arAnchorManager,
    ARLocationManager arLocationManager,
  ) {
    this.arSessionManager = arSessionManager;
    this.arObjectManager = arObjectManager;
    this.arAnchorManager = arAnchorManager;

    this.arSessionManager!.onInitialize(
      showFeaturePoints: false,
      showPlanes: true,
      showWorldOrigin: false,
      handlePans: true,
      handleRotation: true,
    );
    this.arObjectManager!.onInitialize();

    this.arSessionManager!.onPlaneOrPointTap = onPlaneOrPointTap;
  }

  Future<void> onPlaneOrPointTap(List<ARHitTestResult> hitTestResults) async {
    if (_isModelAdded || hitTestResults.isEmpty || _localModelPath == null) {
      return;
    }

    var singleHitResult = hitTestResults.first;
    var newAnchor = ARPlaneAnchor(
      transformation: singleHitResult.worldTransform,
    );
    bool? didAddAnchor = await arAnchorManager!.addAnchor(newAnchor);
    if (didAddAnchor == true) {
      var newNode = ARNode(
        type: NodeType.fileSystemAppFolderGLB,
        uri: _localModelPath!, // Filename only, relative to document dir
        scale: vector.Vector3(0.5, 0.5, 0.5),
        position: vector.Vector3(0.0, 0.0, 0.0),
        rotation: vector.Vector4(1.0, 0.0, 0.0, 0.0),
      );

      bool? didAddNodeToAnchor = await arObjectManager!.addNode(
        newNode,
        planeAnchor: newAnchor,
      );
      if (didAddNodeToAnchor == true) {
        setState(() {
          _isModelAdded = true;
        });
      }
    }
  }
}
