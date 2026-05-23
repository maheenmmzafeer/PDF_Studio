import 'dart:typed_data';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import '../models.dart';
import '../widgets/manual_crop_screen.dart';

Future<void> cropPhoto(AppHost host) async {
  final picked = await FilePicker.platform.pickFiles(
    allowMultiple: false,
    type: FileType.image,
    withData: true,
  );
  final selected = picked?.files.single;
  if (selected == null) {
    return;
  }

  final ctx = host.context;
  final sourceBytes = await host.readPickedFileBytes(selected);
  if (sourceBytes == null) {
    host.showMessage('Could not read selected image');
    return;
  }

  if (!host.mounted) {
    return;
  }
  // ignore: use_build_context_synchronously
  final croppedBytes = await Navigator.of(ctx).push<Uint8List>(
    MaterialPageRoute(
      builder: (_) => ManualCropScreen(imageBytes: sourceBytes, title: selected.name),
    ),
  );

  if (croppedBytes == null) {
    return;
  }

  final outputPath = await host.saveBytes('cropped_${host.timestamp()}.png', croppedBytes);
  host.showMessage(outputPath);
}
