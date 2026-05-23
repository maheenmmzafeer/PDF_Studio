import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';

import '../models.dart';
import '../theme/app_colors.dart';
import 'app_top_bar.dart';
import 'manual_crop_screen.dart';

class CameraCaptureScreen extends StatefulWidget {
  const CameraCaptureScreen({super.key});

  @override
  State<CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<CameraCaptureScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  List<CameraDescription> _cameras = <CameraDescription>[];
  final List<PickedImage> _captured = <PickedImage>[];
  XFile? _lastShot;
  bool _reviewingLastShot = false;
  bool _loadingCameras = true;
  bool _flash = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _initCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _controller?.dispose();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }

    if (state == AppLifecycleState.inactive) {
      controller.dispose();
      _controller = null;
    } else if (state == AppLifecycleState.resumed) {
      _initCamera(selectedIndex: 0);
    }
  }

  Future<void> _initCamera({int selectedIndex = 0}) async {
    setState(() {
      _loadingCameras = true;
      _reviewingLastShot = false;
    });

    try {
      _cameras = await availableCameras();
      if (_cameras.isEmpty) {
        return;
      }

      final controller = CameraController(
        _cameras[selectedIndex.clamp(0, _cameras.length - 1)],
        ResolutionPreset.high,
        enableAudio: false,
      );
      _controller = controller;
      await controller.initialize();
    } catch (_) {
      // Keep the screen usable even if camera init fails.
    } finally {
      if (mounted) {
        setState(() => _loadingCameras = false);
      }
    }
  }

  Future<Uint8List> _readFileBytes(XFile file) async {
    final fileBytes = await file.readAsBytes();
    return Uint8List.fromList(fileBytes);
  }

  Future<void> _takePhoto() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _reviewingLastShot) {
      return;
    }

    setState(() => _flash = true);
    try {
      final shot = await controller.takePicture();
      if (!mounted) return;
      setState(() {
        _lastShot = shot;
        _reviewingLastShot = true;
      });
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not take photo.')),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _flash = false);
      }
    }
  }

  Future<void> _confirmLastShot() async {
    final lastShot = _lastShot;
    if (lastShot == null) return;

    final bytes = await _readFileBytes(lastShot);
    if (!mounted) return;

    setState(() {
      _captured.add(
        PickedImage(
          id: '${DateTime.now().microsecondsSinceEpoch}_${_captured.length}',
          name: 'camera_${_captured.length + 1}.jpg',
          bytes: bytes,
        ),
      );
      _reviewingLastShot = false;
      _lastShot = null;
    });
  }

  void _retryLastShot() {
    if (_lastShot == null) return;
    setState(() {
      _reviewingLastShot = false;
      _lastShot = null;
    });
  }

  Future<void> _cropCapturedAt(int index) async {
    final item = _captured[index];
    final cropped = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => ManualCropScreen(
          imageBytes: item.bytes,
          title: item.name,
        ),
      ),
    );
    if (cropped == null || !mounted) return;
    setState(() {
      _captured[index] = PickedImage(
        id: item.id,
        name: item.name,
        bytes: cropped,
      );
    });
  }

  void _removeCapturedAt(int index) {
    setState(() => _captured.removeAt(index));
  }

  void _done() {
    Navigator.of(context).pop(List<PickedImage>.from(_captured));
  }

  @override
  Widget build(BuildContext context) {
    final controller = _controller;
    final cameraBody = _loadingCameras
        ? const Center(child: CircularProgressIndicator())
        : controller == null || !controller.value.isInitialized
            ? const Center(child: Text('Camera unavailable on this device.'))
            : Center(
                child: AspectRatio(
                  aspectRatio: 3 / 4,
                  child: Container(
                    color: Colors.white,
                    child: FittedBox(
                      fit: BoxFit.contain,
                      child: SizedBox(
                        width: controller.value.previewSize?.height ?? 1,
                        height: controller.value.previewSize?.width ?? 1,
                        child: Stack(
                          fit: StackFit.expand,
                          children: <Widget>[
                            CameraPreview(controller),
                            if (_flash)
                              Container(
                                color: Colors.white.withValues(alpha: 0.22),
                              ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              );

    return Scaffold(
      appBar: const AppTopBar(
        title: 'Camera',
        subtitle: 'Capture multiple photos, then tap Done',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Stack(
                children: <Widget>[
                  Positioned.fill(
                    child: Container(
                      color: Colors.white,
                      child: cameraBody,
                    ),
                  ),
                  Positioned(
                    left: 0,
                    right: 0,
                    bottom: 18,
                    child: Center(
                      child: GestureDetector(
                        onTap: _takePhoto,
                        child: Container(
                          width: 78,
                          height: 78,
                          decoration: BoxDecoration(
                            shape: BoxShape.circle,
                            border: Border.all(
                              color: Colors.white,
                              width: 5,
                            ),
                            color: AppColors.primaryRed,
                            boxShadow: const <BoxShadow>[
                              BoxShadow(
                                color: Colors.black26,
                                blurRadius: 10,
                                offset: Offset(0, 4),
                              ),
                            ],
                          ),
                          child: const Icon(
                            Icons.camera_alt_rounded,
                            color: Colors.white,
                            size: 30,
                          ),
                        ),
                      ),
                    ),
                  ),
                  if (_reviewingLastShot && _lastShot != null)
                    Positioned.fill(
                      child: Container(
                        color: Colors.black.withValues(alpha: 0.88),
                        child: Column(
                          children: <Widget>[
                            const SizedBox(height: 16),
                            Expanded(
                              child: Center(
                                child: FutureBuilder<Uint8List>(
                                  future: _readFileBytes(_lastShot!),
                                  builder: (context, snapshot) {
                                    final data = snapshot.data;
                                    if (data == null) {
                                      return const CircularProgressIndicator();
                                    }
                                    return Image.memory(
                                      data,
                                      fit: BoxFit.contain,
                                    );
                                  },
                                ),
                              ),
                            ),
                            Padding(
                              padding: const EdgeInsets.all(16),
                              child: Row(
                                children: <Widget>[
                                  Expanded(
                                    child: OutlinedButton(
                                      onPressed: _retryLastShot,
                                      child: const Text('Retry'),
                                    ),
                                  ),
                                  const SizedBox(width: 12),
                                  Expanded(
                                    child: FilledButton(
                                      onPressed: _confirmLastShot,
                                      child: const Text('OK'),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
              decoration: BoxDecoration(
                color: Theme.of(context).colorScheme.surface,
                boxShadow: const <BoxShadow>[
                  BoxShadow(blurRadius: 10, color: Colors.black12),
                ],
              ),
              child: Column(
                children: <Widget>[
                  SizedBox(
                    height: 72,
                    child: _captured.isEmpty
                        ? const Center(child: Text('No photos captured yet'))
                        : ListView.separated(
                            scrollDirection: Axis.horizontal,
                            itemCount: _captured.length,
                            separatorBuilder: (context, index) =>
                                const SizedBox(width: 8),
                            itemBuilder: (context, index) {
                              final item = _captured[index];
                              return SizedBox.square(
                                dimension: 72,
                                child: Stack(
                                  children: <Widget>[
                                    Positioned.fill(
                                      child: ClipRRect(
                                        borderRadius: BorderRadius.circular(10),
                                        child: Image.memory(
                                          item.bytes,
                                          fit: BoxFit.cover,
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      top: 4,
                                      right: 4,
                                      child: GestureDetector(
                                        onTap: () => _removeCapturedAt(index),
                                        child: const CircleAvatar(
                                          radius: 11,
                                          child: Icon(Icons.close, size: 14),
                                        ),
                                      ),
                                    ),
                                    Positioned(
                                      bottom: 4,
                                      left: 4,
                                      child: GestureDetector(
                                        onTap: () => _cropCapturedAt(index),
                                        child: CircleAvatar(
                                          radius: 11,
                                          backgroundColor:
                                              AppColors.overlay(0.6),
                                          child: const Icon(
                                            Icons.crop,
                                            size: 14,
                                            color: AppColors.white,
                                          ),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              );
                            },
                          ),
                  ),
                  const SizedBox(height: 10),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton.tonalIcon(
                      onPressed: _done,
                      icon: const Icon(Icons.check),
                      label: const Text('Done'),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
