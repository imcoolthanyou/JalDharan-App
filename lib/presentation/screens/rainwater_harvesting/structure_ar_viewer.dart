import 'dart:io';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:model_viewer_plus/model_viewer_plus.dart';
import 'package:path_provider/path_provider.dart';
import '../../../core/theme/app_colors.dart';

class StructureARViewer extends StatefulWidget {
  final String modelPath; // asset path e.g. assets/recharge_shaft_with_pit.glb
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
  String? _localFileUri; // file:// URI served to model-viewer
  bool _isReady = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _prepareModel();
  }

  Future<void> _prepareModel() async {
    try {
      // Copy the GLB asset to a local file so model_viewer_plus can serve it
      final ByteData data = await rootBundle.load(widget.modelPath);
      final Uint8List bytes = data.buffer.asUint8List();

      final Directory dir = await getApplicationDocumentsDirectory();
      final String filename = widget.modelPath.split('/').last;
      final File file = File('${dir.path}/$filename');
      await file.writeAsBytes(bytes, flush: true);

      if (mounted) {
        setState(() {
          _localFileUri = file.uri.toString(); // file:///...
          _isReady = true;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF0F172A),
      appBar: AppBar(
        title: Text(
          widget.title,
          style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
        ),
        backgroundColor: AppColors.deepAquiferBlue,
        foregroundColor: Colors.white,
        elevation: 0,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: Colors.red, size: 48),
              const SizedBox(height: 16),
              const Text(
                'Failed to load model',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                style: const TextStyle(color: Colors.white54, fontSize: 12),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    if (!_isReady || _localFileUri == null) {
      return const Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(color: AppColors.deepAquiferBlue),
            SizedBox(height: 16),
            Text(
              'Preparing 3D model...',
              style: TextStyle(color: Colors.white70, fontSize: 14),
            ),
          ],
        ),
      );
    }

    return Stack(
      children: [
        // ModelViewer with AR enabled
        ModelViewer(
          src: _localFileUri!,
          alt: widget.title,
          ar: true, // enables AR button on Android
          arModes: const ['scene-viewer', 'webxr', 'quick-look'],
          arScale: ArScale.auto,
          autoRotate: true,
          autoRotateDelay: 1000,
          cameraControls: true,
          shadowIntensity: 1,
          backgroundColor: const Color(0xFF0F172A),
        ),

        // Instruction overlay at bottom
        Positioned(
          bottom: 24,
          left: 16,
          right: 16,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.black.withOpacity(0.65),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.touch_app_rounded, color: Colors.white70, size: 16),
                SizedBox(width: 8),
                Flexible(
                  child: Text(
                    'Drag to rotate • Pinch to zoom • Tap AR button to view in real world',
                    style: TextStyle(color: Colors.white70, fontSize: 11),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
