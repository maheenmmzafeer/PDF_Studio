import 'dart:io';
// dart:typed_data is not required; `Uint8List` comes from flutter/foundation.dart

import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'models.dart';
import 'theme/app_colors.dart';
import 'widgets/app_top_bar.dart';
import 'widgets/tool_card.dart';
import 'widgets/image_pdf_review_screen.dart';
import 'widgets/camera_capture_screen.dart';
import 'features/pdf_builder.dart' as pdf_builder_feature;
import 'features/images_to_pdf.dart' as images_feature;
import 'features/camera_to_pdf.dart' as camera_feature;
import 'features/pdf_to_images.dart' as pdf_images_feature;
import 'features/pdf_to_text.dart' as pdf_text_feature;
import 'features/crop.dart' as crop_feature;

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> implements AppHost {
  bool _isWorking = false;
  String _status = 'Ready';
  final ImagePicker _imagePicker = ImagePicker();
  static const MethodChannel _mediaScanChannel = MethodChannel(
    'pdf_studio/media_scan',
  );

  bool get _isMobilePlatform {
    if (kIsWeb) {
      return false;
    }
    return Platform.isAndroid || Platform.isIOS;
  }

  Future<void> _runTask(String title, Future<void> Function() task) async {
    setState(() {
      _isWorking = true;
      _status = 'Working: $title';
    });

    // Let Flutter paint the loading overlay before heavy work begins.
    await Future<void>.delayed(const Duration(milliseconds: 16));

    try {
      await task();
    } catch (error) {
      _showMessage('Error: $error');
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
          _status = 'Ready';
        });
      }
    }
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(message)));
  }

  String _timestamp() {
    final now = DateTime.now();
    String two(int value) => value.toString().padLeft(2, '0');
    return '${now.year}${two(now.month)}${two(now.day)}_${two(now.hour)}${two(now.minute)}${two(now.second)}';
  }

  Future<Directory?> _resolveAndroidDownloadsDirectory() async {
    final candidates = <String>[
      '/storage/emulated/0/Download',
      '/sdcard/Download',
    ];

    for (final path in candidates) {
      final dir = Directory(path);
      if (await dir.exists()) {
        return dir;
      }
      try {
        await dir.create(recursive: true);
        if (await dir.exists()) {
          return dir;
        }
      } catch (_) {
        // Try next candidate path.
      }
    }

    final fallback = await getDownloadsDirectory();
    return fallback;
  }

  Future<String?> _saveBytesToAndroidDownloads(
    String name,
    Uint8List bytes,
  ) async {
    final downloadsDir = await _resolveAndroidDownloadsDirectory();
    if (downloadsDir == null) {
      return null;
    }

    final file = File('${downloadsDir.path}/$name');
    try {
      await file.writeAsBytes(bytes, flush: true);
      await _scanFileInAndroidGallery(file.path);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<void> _scanFileInAndroidGallery(String path) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
      await _mediaScanChannel.invokeMethod('scanFile', <String, String>{
        'path': path,
      });
    } catch (_) {
      // Keep save flow successful even if indexing fails.
    }
  }

  Future<String?> _saveBytesToIosDocuments(String name, Uint8List bytes) async {
    try {
      final docsDir = await getApplicationDocumentsDirectory();
      final file = File('${docsDir.path}/$name');
      await file.writeAsBytes(bytes, flush: true);
      return file.path;
    } catch (_) {
      return null;
    }
  }

  Future<String> _saveBytes(String name, Uint8List bytes) async {
    if (!kIsWeb && Platform.isAndroid) {
      final savedPath = await _saveBytesToAndroidDownloads(name, bytes);
      if (savedPath != null) {
        return 'Saved to Downloads: $savedPath';
      }
      return 'Could not save to Downloads. Please allow storage access and try again.';
    }

    if (!kIsWeb && Platform.isIOS) {
      final savedPath = await _saveBytesToIosDocuments(name, bytes);
      if (savedPath != null) {
        return 'Saved on device: $savedPath';
      }
      return 'Could not save on iOS device storage.';
    }

    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot + 1) : 'bin';

    await FileSaver.instance.saveFile(
      name: base,
      bytes: bytes,
      fileExtension: ext,
      mimeType: MimeType.other,
    );
    return 'Saved file: $name';
  }

  Future<Uint8List?> _readPickedFileBytes(PlatformFile pickedFile) async {
    if (pickedFile.bytes != null) {
      return pickedFile.bytes;
    }
    if (!kIsWeb && pickedFile.path != null) {
      return File(pickedFile.path!).readAsBytes();
    }
    return null;
  }

  Future<Uint8List?> _buildPdfBytesFromImages(
    List<PickedImage> images,
    ImagePdfPageMode pageMode,
  ) async {
    return pdf_builder_feature.buildPdfBytesFromImages(images, pageMode);
  }

  Uint8List _convertPngToJpg(Uint8List pngBytes) => convertPngToJpg(pngBytes);

  Future<List<PickedImage>> _pickImageFiles() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: <String>[
        'png',
        'jpg',
        'jpeg',
        'webp',
        'bmp',
        'gif',
        'tif',
        'tiff',
        'heic',
      ],
      withData: true,
    );

    if (picked == null || picked.files.isEmpty) {
      return <PickedImage>[];
    }

    final items = <PickedImage>[];
    final seed = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < picked.files.length; i++) {
      final file = picked.files[i];
      final bytes = await _readPickedFileBytes(file);
      if (bytes == null) {
        continue;
      }
      items.add(
        PickedImage(
          id: '${seed}_${i}_${file.name}',
          name: file.name,
          bytes: bytes,
        ),
      );
    }
    return items;
  }

  

  Future<List<PickedImage>> _captureCameraImages() async {
    if (!_isMobilePlatform) {
      return <PickedImage>[];
    }

    final result = await Navigator.of(context).push<List<PickedImage>>(
      MaterialPageRoute(
        builder: (_) => const CameraCaptureScreen(),
      ),
    );
    return result ?? <PickedImage>[];
  }

  Future<ImagePdfSetupResult?> _showImagePdfSetupDialog(
    List<PickedImage> initialImages, {
    bool allowAddImages = true,
  }) async {
    final result = await Navigator.of(context).push<ImagePdfSetupResult>(
      MaterialPageRoute(
        builder: (_) => ImagePdfReviewScreen(
          initialImages: initialImages,
          allowAddImages: allowAddImages,
          initialPageMode: ImagePdfPageMode.a4,
          onAddFromGallery: _pickImageFiles,
          onTakePhoto: _captureCameraImages,
        ),
      ),
    );
    return result;
  }

  Future<void> _imageToPdf() async {
    await images_feature.imageToPdf(this);
  }

  Future<void> _cameraToPdf() async {
    await camera_feature.cameraToPdf(this);
  }

  Future<void> _pdfToImages() async {
    await pdf_images_feature.pdfToImages(this);
  }

  Future<void> _pdfToText() async {
    await pdf_text_feature.pdfToText(this);
  }

  Future<void> _showExtractedTextDialog(String text) async {
    await showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        titlePadding: const EdgeInsets.fromLTRB(16, 10, 8, 0),
        title: Row(
          children: <Widget>[
            const Expanded(
              child: Text(
                'Extracted Text',
                style: TextStyle(fontWeight: FontWeight.w700),
              ),
            ),
            IconButton(
              tooltip: 'Copy',
              icon: const Icon(Icons.copy_outlined),
              onPressed: () async {
                await Clipboard.setData(ClipboardData(text: text));
                if (!mounted) {
                  return;
                }
                _showMessage('Text copied to clipboard');
              },
            ),
            IconButton(
              tooltip: 'Close',
              icon: const Icon(Icons.close),
              onPressed: () => Navigator.of(dialogContext).pop(),
            ),
          ],
        ),
        content: SizedBox(
          width: 640,
          height: 420,
          child: text.trim().isEmpty
              ? const Center(child: Text('No readable text found in this PDF.'))
              : Scrollbar(
                  thumbVisibility: true,
                  child: SingleChildScrollView(
                    child: SelectableText(
                      text,
                      style: const TextStyle(height: 1.35),
                    ),
                  ),
                ),
        ),
      ),
    );
  }

  @override
  Future<void> showExtractedTextDialog(String text) async => _showExtractedTextDialog(text);

  // AppHost interface mappings
  @override
  bool get isMobilePlatform => _isMobilePlatform;

  @override
  ImagePicker get imagePicker => _imagePicker;

  @override
  String timestamp() => _timestamp();

  @override
  Future<String> saveBytes(String name, Uint8List bytes) => _saveBytes(name, bytes);

  @override
  Future<Uint8List?> readPickedFileBytes(PlatformFile pickedFile) => _readPickedFileBytes(pickedFile);

  @override
  Future<Uint8List?> buildPdfBytesFromImages(List<PickedImage> images, ImagePdfPageMode pageMode) => _buildPdfBytesFromImages(images, pageMode);

  @override
  Uint8List convertPngToJpg(Uint8List pngBytes) => _convertPngToJpg(pngBytes);

  @override
  Future<List<PickedImage>> pickImageFiles() => _pickImageFiles();

  @override
  Future<List<PickedImage>> captureCameraImages() => _captureCameraImages();

  @override
  Future<ImagePdfSetupResult?> showImagePdfSetupDialog(List<PickedImage> initialImages, {bool allowAddImages = true}) => _showImagePdfSetupDialog(initialImages, allowAddImages: allowAddImages);

  @override
  void showMessage(String message) => _showMessage(message);

  Future<void> _cropPhoto() async {
    await crop_feature.cropPhoto(this);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final webStyle = kIsWeb || width >= 900;
    final appTextScaler = _isMobilePlatform
        ? const TextScaler.linear(0.92)
        : mediaQuery.textScaler;
    final actions = <ToolAction>[
      ToolAction(
        icon: Icons.picture_as_pdf_rounded,
        title: 'Images to PDF',
        subtitle: 'JPG/PNG photos into one PDF file',
        color: AppColors.primaryRed,
        onTap: () => _runTask('Images to PDF', _imageToPdf),
      ),
      if (_isMobilePlatform)
        ToolAction(
          icon: Icons.camera_alt_outlined,
          title: 'Camera to PDF',
          subtitle: 'Capture multiple photos into one PDF',
          color: AppColors.primaryRedDark,
          onTap: () => _runTask('Camera to PDF', _cameraToPdf),
        ),
      ToolAction(
        icon: Icons.image_outlined,
        title: 'PDF to Images',
        subtitle: 'Export each page as JPG',
        color: AppColors.success,
        onTap: () => _runTask('PDF to Images', _pdfToImages),
      ),
      ToolAction(
        icon: Icons.text_snippet_outlined,
        title: 'PDF to Text',
        subtitle: 'Extract and view text with copy option',
        color: AppColors.danger,
        onTap: () => _runTask('PDF to Text', _pdfToText),
      ),
      ToolAction(
        icon: Icons.crop,
        title: 'Crop Photo',
        subtitle: 'Drag the crop corners manually',
        color: AppColors.primaryRed,
        onTap: () => _runTask('Crop Photo', _cropPhoto),
      ),
    ];

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: appTextScaler),
      child: Scaffold(
        appBar: const AppTopBar(
          title: 'Local PDF Studio',
          subtitle: 'Offline PDF + image tools',
          showLogo: true,
        ),
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  color: AppColors.white,
                ),
                child: Center(
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 1480),
                    child: Padding(
                      padding: EdgeInsets.symmetric(
                        horizontal: webStyle ? 12 : 14,
                        vertical: webStyle ? 20 : 14,
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Container(
                            width: double.infinity,
                            padding: EdgeInsets.all(webStyle ? 24 : 16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(18),
                              gradient: const LinearGradient(
                                  colors: <Color>[
                                    AppColors.primaryRed,
                                    AppColors.primaryRedDark,
                                  ],
                                ),
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: <Widget>[
                                Text(
                                  webStyle
                                      ? 'PDF + Image Toolkit'
                                      : 'Local PDF Toolkit',
                                  style: Theme.of(context)
                                      .textTheme
                                      .headlineSmall
                                      ?.copyWith(
                                        color: AppColors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Works offline on web and mobile. Pick a tool and save instantly.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: AppColors.white.withValues(
                                          alpha: 0.95,
                                        ),
                                      ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 14),
                          Row(
                            children: <Widget>[
                              Expanded(child: Text('Status: $_status')),
                              if (_isWorking)
                                const SizedBox(
                                  width: 20,
                                  height: 20,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2.2,
                                  ),
                                ),
                            ],
                          ),
                          const SizedBox(height: 14),
                          Expanded(
                            child: LayoutBuilder(
                              builder: (context, constraints) {
                                final isMobileWidth =
                                    constraints.maxWidth < 760;
                                final gridColumns = isMobileWidth
                                    ? 1
                                    : (constraints.maxWidth >= 980 ? 3 : 2);
                                final cardHeight = isMobileWidth
                                    ? 118.0
                                    : 112.0;
                                return GridView.builder(
                                  gridDelegate:
                                      SliverGridDelegateWithFixedCrossAxisCount(
                                        crossAxisCount: gridColumns,
                                        mainAxisExtent: cardHeight,
                                        crossAxisSpacing: 12,
                                        mainAxisSpacing: 12,
                                      ),
                                  itemCount: actions.length,
                                  itemBuilder: (context, index) {
                                    final action = actions[index];
                                    return ToolCard(
                                      icon: action.icon,
                                      title: action.title,
                                      subtitle: action.subtitle,
                                      color: action.color,
                                      onTap: _isWorking ? null : action.onTap,
                                    );
                                  },
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              if (_isWorking)
                Positioned.fill(
                  child: ColoredBox(
                    color: AppColors.overlay(0.35),
                    child: Center(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 280),
                        child: Card(
                          elevation: 6,
                          child: Padding(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 20,
                              vertical: 18,
                            ),
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              children: <Widget>[
                                const CircularProgressIndicator(),
                                const SizedBox(height: 12),
                                Text(
                                  _status,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
