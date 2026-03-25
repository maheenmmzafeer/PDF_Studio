import 'dart:io';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image/image.dart' as img;
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;

void main() {
  runApp(const LocalPdfStudioApp());
}

class LocalPdfStudioApp extends StatelessWidget {
  const LocalPdfStudioApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'PDF Studio',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: const Color(0xFF0B7A75)),
        useMaterial3: true,
      ),
      home: const HomeScreen(),
    );
  }
}

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
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
    List<_PickedImage> images,
    _ImagePdfPageMode pageMode,
  ) async {
    final doc = pw.Document();
    var addedPages = 0;

    for (final pickedImage in images) {
      final processed = await compute(_prepareImageForPdf, pickedImage.bytes);
      if (processed == null) {
        continue;
      }

      final image = pw.MemoryImage(processed.pngBytes);
      final pageFormat = pageMode == _ImagePdfPageMode.matchImage
          ? pdf.PdfPageFormat(
              processed.width.toDouble(),
              processed.height.toDouble(),
              marginAll: 0,
            )
          : pdf.PdfPageFormat.a4;

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: pageMode == _ImagePdfPageMode.matchImage
              ? pw.EdgeInsets.zero
              : const pw.EdgeInsets.all(20),
          build: (_) => pw.Center(
            child: pw.FittedBox(fit: pw.BoxFit.contain, child: pw.Image(image)),
          ),
        ),
      );
      addedPages += 1;

      // Yield occasionally so the progress overlay keeps animating.
      await Future<void>.delayed(Duration.zero);
    }

    if (addedPages == 0) {
      return null;
    }
    return doc.save();
  }

  Uint8List _convertPngToJpg(Uint8List pngBytes) {
    final decoded = img.decodeImage(pngBytes);
    if (decoded == null) {
      return pngBytes;
    }
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 94));
  }

  Future<List<_PickedImage>> _pickImageFiles() async {
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
      return <_PickedImage>[];
    }

    final items = <_PickedImage>[];
    final seed = DateTime.now().microsecondsSinceEpoch;
    for (var i = 0; i < picked.files.length; i++) {
      final file = picked.files[i];
      final bytes = await _readPickedFileBytes(file);
      if (bytes == null) {
        continue;
      }
      items.add(
        _PickedImage(
          id: '${seed}_${i}_${file.name}',
          name: file.name,
          bytes: bytes,
        ),
      );
    }
    return items;
  }

  Future<bool> _askTakeAnotherPhoto(int capturedCount) async {
    final result = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Add another photo?'),
        content: Text(
          'Captured $capturedCount photo${capturedCount == 1 ? '' : 's'}.',
        ),
        actions: <Widget>[
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Finish'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Take another'),
          ),
        ],
      ),
    );
    return result ?? false;
  }

  Future<List<_PickedImage>> _captureCameraImages() async {
    if (!_isMobilePlatform) {
      return <_PickedImage>[];
    }

    final captured = <_PickedImage>[];
    final seed = DateTime.now().microsecondsSinceEpoch;
    var index = 0;

    while (true) {
      final shot = await _imagePicker.pickImage(source: ImageSource.camera);
      if (shot == null) {
        break;
      }

      final bytes = await shot.readAsBytes();
      captured.add(
        _PickedImage(
          id: '${seed}_camera_$index',
          name: 'camera_${index + 1}.jpg',
          bytes: bytes,
        ),
      );
      index += 1;

      if (!mounted) {
        break;
      }

      final takeAnother = await _askTakeAnotherPhoto(captured.length);
      if (!takeAnother) {
        break;
      }
    }

    return captured;
  }

  Future<_ImagePdfSetupResult?> _showImagePdfSetupDialog(
    List<_PickedImage> initialImages, {
    bool allowAddImages = true,
  }) async {
    var pageMode = _ImagePdfPageMode.a4;
    final images = <_PickedImage>[...initialImages];
    String? hoveredImageId;

    return showDialog<_ImagePdfSetupResult>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setDialogState) => AlertDialog(
          title: const Text('Prepare PDF'),
          content: SizedBox(
            width: 620,
            height: 450,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: <Widget>[
                Text(
                  'Page size',
                  style: Theme.of(context).textTheme.titleSmall,
                ),
                const SizedBox(height: 8),
                SegmentedButton<_ImagePdfPageMode>(
                  segments: const <ButtonSegment<_ImagePdfPageMode>>[
                    ButtonSegment<_ImagePdfPageMode>(
                      value: _ImagePdfPageMode.a4,
                      label: Text('A4'),
                      icon: Icon(Icons.picture_as_pdf_outlined),
                    ),
                    ButtonSegment<_ImagePdfPageMode>(
                      value: _ImagePdfPageMode.matchImage,
                      label: Text('Match image size'),
                      icon: Icon(Icons.photo_size_select_actual_outlined),
                    ),
                  ],
                  selected: <_ImagePdfPageMode>{pageMode},
                  onSelectionChanged: (value) {
                    setDialogState(() {
                      pageMode = value.first;
                    });
                  },
                ),
                const SizedBox(height: 12),
                Row(
                  children: <Widget>[
                    if (allowAddImages)
                      FilledButton.tonalIcon(
                        onPressed: () async {
                          final more = await _pickImageFiles();
                          if (more.isEmpty) {
                            return;
                          }
                          setDialogState(() {
                            images.addAll(more);
                          });
                        },
                        icon: const Icon(Icons.add_photo_alternate_outlined),
                        label: const Text('Add images'),
                      ),
                    if (allowAddImages) const SizedBox(width: 8),
                    Text('${images.length} selected'),
                  ],
                ),
                const SizedBox(height: 6),
                Text(
                  'Drag thumbnails to sort page order',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
                const SizedBox(height: 10),
                SizedBox(
                  height: 160,
                  child: images.isEmpty
                      ? const Center(child: Text('No images selected'))
                      : ReorderableListView.builder(
                          scrollDirection: Axis.horizontal,
                          buildDefaultDragHandles: false,
                          padding: const EdgeInsets.symmetric(horizontal: 4),
                          itemCount: images.length,
                          onReorder: (oldIndex, newIndex) {
                            setDialogState(() {
                              if (newIndex > oldIndex) {
                                newIndex -= 1;
                              }
                              final item = images.removeAt(oldIndex);
                              images.insert(newIndex, item);
                            });
                          },
                          itemBuilder: (context, index) {
                            final item = images[index];
                            final tile = MouseRegion(
                              onEnter: (_) {
                                setDialogState(() {
                                  hoveredImageId = item.id;
                                });
                              },
                              onExit: (_) {
                                setDialogState(() {
                                  if (hoveredImageId == item.id) {
                                    hoveredImageId = null;
                                  }
                                });
                              },
                              child: Stack(
                                children: <Widget>[
                                  Positioned.fill(
                                    child: ClipRRect(
                                      borderRadius: BorderRadius.circular(14),
                                      child: Image.memory(
                                        item.bytes,
                                        fit: BoxFit.cover,
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    left: 8,
                                    bottom: 8,
                                    child: Container(
                                      padding: const EdgeInsets.symmetric(
                                        horizontal: 8,
                                        vertical: 4,
                                      ),
                                      decoration: BoxDecoration(
                                        color: Colors.black.withValues(
                                          alpha: 0.55,
                                        ),
                                        borderRadius: BorderRadius.circular(10),
                                      ),
                                      child: Text(
                                        '${index + 1}',
                                        style: const TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                        ),
                                      ),
                                    ),
                                  ),
                                  Positioned(
                                    top: 6,
                                    right: 6,
                                    child: AnimatedOpacity(
                                      duration: const Duration(
                                        milliseconds: 120,
                                      ),
                                      opacity:
                                          (hoveredImageId == item.id || !kIsWeb)
                                          ? 1
                                          : 0,
                                      child: Material(
                                        color: Colors.black.withValues(
                                          alpha: 0.55,
                                        ),
                                        shape: const CircleBorder(),
                                        child: InkWell(
                                          customBorder: const CircleBorder(),
                                          onTap: () {
                                            setDialogState(() {
                                              images.removeAt(index);
                                              if (hoveredImageId == item.id) {
                                                hoveredImageId = null;
                                              }
                                            });
                                          },
                                          child: const Padding(
                                            padding: EdgeInsets.all(5),
                                            child: Icon(
                                              Icons.close,
                                              size: 15,
                                              color: Colors.white,
                                            ),
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            );

                            return SizedBox(
                              key: ValueKey(item.id),
                              width: 150,
                              child: Padding(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 6,
                                ),
                                child: Center(
                                  child: SizedBox.square(
                                    dimension: 136,
                                    child: kIsWeb
                                        ? ReorderableDragStartListener(
                                            index: index,
                                            child: tile,
                                          )
                                        : ReorderableDelayedDragStartListener(
                                            index: index,
                                            child: tile,
                                          ),
                                  ),
                                ),
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
          ),
          actions: <Widget>[
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: images.isEmpty
                  ? null
                  : () {
                      Navigator.of(context).pop(
                        _ImagePdfSetupResult(
                          pageMode: pageMode,
                          images: List<_PickedImage>.from(images),
                        ),
                      );
                    },
              child: const Text('Create PDF'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _imageToPdf() async {
    final initialImages = await _pickImageFiles();
    if (initialImages.isEmpty) {
      return;
    }

    if (!mounted) {
      return;
    }

    final setup = await _showImagePdfSetupDialog(initialImages);
    if (setup == null || setup.images.isEmpty) {
      return;
    }

    final pdfBytes = await _buildPdfBytesFromImages(
      setup.images,
      setup.pageMode,
    );
    if (pdfBytes == null) {
      _showMessage('No valid image pages found to create a PDF.');
      return;
    }

    final saved = await _saveBytes(
      'images_to_pdf_${_timestamp()}.pdf',
      pdfBytes,
    );
    _showMessage(saved);
  }

  Future<void> _cameraToPdf() async {
    if (!_isMobilePlatform) {
      _showMessage('Camera capture is only available on Android and iOS.');
      return;
    }

    final capturedImages = await _captureCameraImages();
    if (capturedImages.isEmpty || !mounted) {
      return;
    }

    final setup = await _showImagePdfSetupDialog(
      capturedImages,
      allowAddImages: false,
    );
    if (setup == null || setup.images.isEmpty) {
      return;
    }

    final pdfBytes = await _buildPdfBytesFromImages(
      setup.images,
      setup.pageMode,
    );
    if (pdfBytes == null) {
      _showMessage('No valid captured images found to create a PDF.');
      return;
    }

    final saved = await _saveBytes(
      'camera_to_pdf_${_timestamp()}.pdf',
      pdfBytes,
    );
    _showMessage(saved);
  }

  Future<void> _pdfToImages() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: <String>['pdf'],
      withData: true,
    );
    final selected = picked?.files.single;
    if (selected == null) {
      return;
    }

    final pdfBytes = await _readPickedFileBytes(selected);
    if (pdfBytes == null) {
      _showMessage('Could not read selected PDF');
      return;
    }

    var pageCounter = 0;
    await for (final page in Printing.raster(pdfBytes, dpi: 144)) {
      pageCounter += 1;
      final stamp = _timestamp();
      final png = await page.toPng();
      final jpgBytes = _convertPngToJpg(png);
      final imageName = 'pdf_page_${stamp}_$pageCounter';

      await _saveBytes('$imageName.jpg', jpgBytes);
    }

    if (pageCounter == 0) {
      _showMessage('No pages rendered');
      return;
    }
    _showMessage('$pageCounter JPG page image(s) saved');
  }

  Future<void> _pdfToText() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: <String>['pdf'],
      withData: true,
    );
    final selected = picked?.files.single;
    if (selected == null) {
      return;
    }

    final bytes = await _readPickedFileBytes(selected);
    if (bytes == null) {
      _showMessage('Could not read selected PDF');
      return;
    }

    final document = sfpdf.PdfDocument(inputBytes: bytes);
    final extractor = sfpdf.PdfTextExtractor(document);
    final text = extractor.extractText();
    document.dispose();

    if (!mounted) {
      return;
    }

    await _showExtractedTextDialog(text);
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

  Future<void> _cropPhoto() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.image,
      withData: true,
    );
    final selected = picked?.files.single;
    if (selected == null) {
      return;
    }

    final sourceBytes = await _readPickedFileBytes(selected);
    if (sourceBytes == null) {
      _showMessage('Could not read selected image');
      return;
    }

    if (!mounted) {
      return;
    }

    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) =>
            _ManualCropScreen(imageBytes: sourceBytes, title: selected.name),
      ),
    );

    if (croppedBytes == null) {
      return;
    }

    final outputPath = await _saveBytes(
      'cropped_${_timestamp()}.png',
      croppedBytes,
    );
    _showMessage(outputPath);
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final webStyle = kIsWeb || width >= 900;
    final appTextScaler = _isMobilePlatform
        ? const TextScaler.linear(0.92)
        : mediaQuery.textScaler;
    final actions = <_ToolAction>[
      _ToolAction(
        icon: Icons.picture_as_pdf_rounded,
        title: 'Images to PDF',
        subtitle: 'JPG/PNG photos into one PDF file',
        color: const Color(0xFFB71C1C),
        onTap: () => _runTask('Images to PDF', _imageToPdf),
      ),
      if (_isMobilePlatform)
        _ToolAction(
          icon: Icons.camera_alt_outlined,
          title: 'Camera to PDF',
          subtitle: 'Capture multiple photos into one PDF',
          color: const Color(0xFF2E7D32),
          onTap: () => _runTask('Camera to PDF', _cameraToPdf),
        ),
      _ToolAction(
        icon: Icons.image_outlined,
        title: 'PDF to Images',
        subtitle: 'Export each page as JPG',
        color: const Color(0xFFAD1457),
        onTap: () => _runTask('PDF to Images', _pdfToImages),
      ),
      _ToolAction(
        icon: Icons.text_snippet_outlined,
        title: 'PDF to Text',
        subtitle: 'Extract and view text with copy option',
        color: const Color(0xFF6A1B9A),
        onTap: () => _runTask('PDF to Text', _pdfToText),
      ),
      _ToolAction(
        icon: Icons.crop,
        title: 'Crop Photo',
        subtitle: 'Drag the crop corners manually',
        color: const Color(0xFFC62828),
        onTap: () => _runTask('Crop Photo', _cropPhoto),
      ),
    ];

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: appTextScaler),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                begin: Alignment.centerLeft,
                end: Alignment.centerRight,
                colors: <Color>[Colors.white, Color(0xFFB71C1C)],
              ),
            ),
          ),
          title: Row(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              ClipRRect(
                borderRadius: BorderRadius.circular(6),
                child: Image.asset(
                  'PDF_icon.jpg',
                  width: 30,
                  height: 30,
                  fit: BoxFit.cover,
                ),
              ),
              const SizedBox(width: 10),
              const Text(
                'Local PDF Studio',
                style: TextStyle(
                  color: Color(0xFF7F0000),
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
        body: SafeArea(
          child: Stack(
            children: <Widget>[
              Container(
                decoration: BoxDecoration(
                  color: Colors.white,
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
                                  Color(0xFFB71C1C),
                                  Color(0xFFE53935),
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
                                        color: Colors.white,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Works offline on web and mobile. Pick a tool and save instantly.',
                                  style: Theme.of(context).textTheme.bodyMedium
                                      ?.copyWith(
                                        color: Colors.white.withValues(
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
                                    return _ToolCard(
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
                    color: Colors.black.withValues(alpha: 0.35),
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

class _ToolAction {
  const _ToolAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback onTap;
}

enum _ImagePdfPageMode { a4, matchImage }

class _ProcessedPdfImage {
  const _ProcessedPdfImage({
    required this.width,
    required this.height,
    required this.pngBytes,
  });

  final int width;
  final int height;
  final Uint8List pngBytes;
}

_ProcessedPdfImage? _prepareImageForPdf(Uint8List sourceBytes) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    return null;
  }

  return _ProcessedPdfImage(
    width: decoded.width,
    height: decoded.height,
    pngBytes: Uint8List.fromList(img.encodePng(decoded)),
  );
}

class _PickedImage {
  const _PickedImage({
    required this.id,
    required this.name,
    required this.bytes,
  });

  final String id;
  final String name;
  final Uint8List bytes;
}

class _ImagePdfSetupResult {
  const _ImagePdfSetupResult({required this.pageMode, required this.images});

  final _ImagePdfPageMode pageMode;
  final List<_PickedImage> images;
}

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    const buttonColor = Color.fromARGB(255, 255, 242, 247);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            color: buttonColor,
            boxShadow: <BoxShadow>[
              BoxShadow(
                color: const Color.fromARGB(28, 255, 227, 231),
                blurRadius: 18,
                offset: const Offset(0, 6),
              ),
            ],
          ),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: <Widget>[
                CircleAvatar(
                  radius: 22,
                  backgroundColor: color.withValues(alpha: 0.15),
                  child: Icon(icon, color: color),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: <Widget>[
                      Text(
                        title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        subtitle,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ),
                ),
                Icon(Icons.arrow_forward_rounded, color: color),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ManualCropScreen extends StatefulWidget {
  const _ManualCropScreen({required this.imageBytes, required this.title});

  final Uint8List imageBytes;
  final String title;

  @override
  State<_ManualCropScreen> createState() => _ManualCropScreenState();
}

class _ManualCropScreenState extends State<_ManualCropScreen> {
  final CropController _controller = CropController();
  bool _cropping = false;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Crop Photo'),
        actions: <Widget>[
          TextButton.icon(
            onPressed: _cropping
                ? null
                : () {
                    setState(() => _cropping = true);
                    _controller.crop();
                  },
            icon: const Icon(Icons.check),
            label: const Text('Use Crop'),
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
              baseColor: const Color(0xFF111111),
              maskColor: Colors.black.withValues(alpha: 0.55),
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
            color: const Color(0xFFFCE4EC),
            child: const Text(
              'Tip: Drag any corner of the crop box, then tap "Use Crop".',
              textAlign: TextAlign.center,
            ),
          ),
        ],
      ),
    );
  }
}
