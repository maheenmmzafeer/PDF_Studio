import 'dart:typed_data';
import 'package:image/image.dart' as img;
import 'package:file_picker/file_picker.dart';
import 'package:image_picker/image_picker.dart';
import 'package:flutter/widgets.dart';

enum ImagePdfPageMode { a4, matchImage }

const int _pdfImageJpegQuality = 86;

class ProcessedPdfImage {
  const ProcessedPdfImage({
    required this.width,
    required this.height,
    required this.bytes,
  });

  final int width;
  final int height;
  final Uint8List bytes;
}

ProcessedPdfImage? prepareImageForPdf(Uint8List sourceBytes) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    return null;
  }

  final canvas = img.Image(width: decoded.width, height: decoded.height);
  img.fill(canvas, color: img.ColorRgb8(255, 255, 255));
  img.compositeImage(canvas, decoded);

  return ProcessedPdfImage(
    width: canvas.width,
    height: canvas.height,
    bytes: Uint8List.fromList(
      img.encodeJpg(canvas, quality: _pdfImageJpegQuality),
    ),
  );
}

Uint8List convertPngToJpg(Uint8List pngBytes) {
  final decoded = img.decodeImage(pngBytes);
  if (decoded == null) {
    return pngBytes;
  }
  return Uint8List.fromList(img.encodeJpg(decoded, quality: 94));
}

class PickedImage {
  const PickedImage({required this.id, required this.name, required this.bytes});

  final String id;
  final String name;
  final Uint8List bytes;
}

class ImagePdfSetupResult {
  const ImagePdfSetupResult({required this.pageMode, required this.images});

  final ImagePdfPageMode pageMode;
  final List<PickedImage> images;
}

/// Interface implemented by the home screen to allow feature modules
/// to call back into app helpers without circular imports.
abstract class AppHost {
  bool get isMobilePlatform;
  ImagePicker get imagePicker;
  BuildContext get context;
  bool get mounted;

  String timestamp();

  Future<String> saveBytes(String name, Uint8List bytes);
  Future<String?> savePdfBytes(String suggestedName, Uint8List bytes);
  Future<Uint8List?> readPickedFileBytes(PlatformFile pickedFile);
  Future<Uint8List?> buildPdfBytesFromImages(List<PickedImage> images, ImagePdfPageMode pageMode);
  Uint8List convertPngToJpg(Uint8List pngBytes);
  Future<List<PickedImage>> pickImageFiles();
  Future<List<PickedImage>> captureCameraImages();
  Future<ImagePdfSetupResult?> showImagePdfSetupDialog(List<PickedImage> initialImages, {bool allowAddImages});
  void showMessage(String message);
  Future<void> showExtractedTextDialog(String text);
}