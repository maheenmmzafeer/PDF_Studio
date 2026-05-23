import 'dart:typed_data';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:flutter/material.dart';
import '../theme/app_colors.dart';
import 'app_top_bar.dart';

class ManualCropScreen extends StatefulWidget {
  const ManualCropScreen({required this.imageBytes, required this.title, super.key});

  final Uint8List imageBytes;
  final String title;

  @override
  State<ManualCropScreen> createState() => _ManualCropScreenState();
}

class _ManualCropScreenState extends State<ManualCropScreen> {
  final CropController _controller = CropController();
  bool _cropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppTopBar(
        title: 'Crop Photo',
        subtitle: 'Adjust the crop box before saving',
        showBackButton: true,
        actions: <Widget>[
          TextButton.icon(
            onPressed: _cropping
                ? null
                : () {
                    setState(() => _cropping = true);
                    _controller.crop();
                  },
            icon: const Icon(Icons.check),
            label: const Text('Crop'),
          ),
        ],
      ),
      body: Column(
        children: <Widget>[
          Expanded(
            child: Crop(
              image: widget.imageBytes,
              controller: _controller,
              withCircleUi: false,
              baseColor: AppColors.black87,
              maskColor: AppColors.overlay(0.55),
              radius: 10,
              onCropped: (croppedData) {
                if (!mounted) {
                  return;
                }
                Navigator.of(context).pop(Uint8List.fromList(croppedData));
              },
            ),
          ),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            color: AppColors.pink50,
            child: const Text(
              'Tip: Drag any corner of the crop box, then tap "Crop".',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
