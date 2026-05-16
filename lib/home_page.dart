import 'dart:io';
import 'dart:typed_data';

import 'package:camera/camera.dart';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import 'app_theme.dart';

typedef _ProgressReporter = void Function(String status, [double? progress]);

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const MethodChannel _mediaScanChannel = MethodChannel(
    'pdf_studio/media_scan',
  );

  bool _isWorking = false;
  String _status = 'Ready';
  double? _progress;

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
      _progress = null;
    });

    await Future<void>.delayed(const Duration(milliseconds: 16));

    try {
      await task();
    } catch (error) {
      _showMessage('Error: $error');
    } finally {
      if (mounted) {
        setState(() {

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
      } catch (_) {}
    }

    return getDownloadsDirectory();
  }

  Future<void> _scanFileInAndroidGallery(String path) async {
    if (kIsWeb || !Platform.isAndroid) {
      return;
    }
    try {
      await _mediaScanChannel.invokeMethod('scanFile', <String, String>{
        'path': path,
      });
    } catch (_) {}
  }

  Future<String?> _saveBytesToAndroidDownloads(String name, Uint8List bytes) async {
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
      final path = await _saveBytesToAndroidDownloads(name, bytes);
      if (path != null) {
        return 'Saved to Downloads: $path';
      }
      return 'Could not save to Downloads. Please allow storage access and try again.';
    }

    if (!kIsWeb && Platform.isIOS) {
      final path = await _saveBytesToIosDocuments(name, bytes);
      if (path != null) {
        return 'Saved on device: $path';
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

  Future<Uint8List?> _captureFromCamera() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        _showMessage('No camera was found on this device.');
        return null;
      }

      final preferredCamera = cameras.firstWhere(
        (camera) => camera.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );

      if (!mounted) {
        return null;
      }

      return Navigator.of(context, rootNavigator: true).push<Uint8List>(
        MaterialPageRoute(
          builder: (_) => _CameraCaptureScreen(camera: preferredCamera),
        ),
      );
    } catch (error) {
      _showMessage('Could not open camera: $error');
      return null;
    }
  }

  Future<List<_PickedImage>> _pickImageFiles() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: true,
      type: FileType.custom,
      allowedExtensions: const <String>[
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

    final seed = DateTime.now().microsecondsSinceEpoch;
    final items = <_PickedImage>[];
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

  Future<_ImagePdfSetupResult?> _showImagePdfSetupDialog(
    List<_PickedImage> initialImages,
  ) async {
    var pageMode = _ImagePdfPageMode.a4;
    final images = <_PickedImage>[...initialImages];
    String? hoveredImageId;

    return showDialog<_ImagePdfSetupResult>(
      context: context,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Prepare PDF'),
              content: SizedBox(
                width: 680,
                height: 500,
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
                    Wrap(
                      spacing: 8,
                      runSpacing: 8,
                      children: <Widget>[
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
                          icon: const Icon(Icons.photo_library_outlined),
                          label: const Text('Gallery'),
                        ),
                        FilledButton.tonalIcon(
                          onPressed: () async {
                            final shot = await _captureFromCamera();
                            if (shot == null) {
                              return;
                            }
                            setDialogState(() {
                              images.add(
                                _PickedImage(
                                  id:
                                      '${DateTime.now().microsecondsSinceEpoch}_camera',
                                  name: 'camera_${images.length + 1}.jpg',
                                  bytes: shot,
                                ),
                              );
                            });
                          },
                          icon: const Icon(Icons.camera_alt_outlined),
                          label: const Text('Camera'),
                        ),
                      ],
                    ),
                    const SizedBox(height: 8),
                    Text('${images.length} selected'),
                    const SizedBox(height: 10),
                    Text(
                      'Drag thumbnails to reorder. Use overlay controls to crop or remove.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                    const SizedBox(height: 10),
                    Expanded(
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
                                            borderRadius: BorderRadius.circular(
                                              10,
                                            ),
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
                                          opacity: (hoveredImageId == item.id ||
                                                  !kIsWeb)
                                              ? 1
                                              : 0,
                                          child: Column(
                                            children: <Widget>[
                                              Material(
                                                color: Colors.black.withValues(
                                                  alpha: 0.55,
                                                ),
                                                shape: const CircleBorder(),
                                                child: InkWell(
                                                  customBorder:
                                                      const CircleBorder(),
                                                  onTap: () {
                                                    setDialogState(() {
                                                      images.removeAt(index);
                                                      if (hoveredImageId ==
                                                          item.id) {
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
                                              const SizedBox(height: 6),
                                              Material(
                                                color: Colors.black.withValues(
                                                  alpha: 0.55,
                                                ),
                                                shape: const CircleBorder(),
                                                child: InkWell(
                                                  customBorder:
                                                      const CircleBorder(),
                                                  onTap: () async {
                                                    final cropped =
                                                        await Navigator.of(
                                                      context,
                                                      rootNavigator: true,
                                                    ).push<Uint8List>(
                                                      MaterialPageRoute(
                                                        builder: (_) =>
                                                            _ManualCropScreen(
                                                          imageBytes: item.bytes,
                                                          title: item.name,
                                                        ),
                                                      ),
                                                    );
                                                    if (cropped != null) {
                                                      setDialogState(() {
                                                        images[index] =
                                                            _PickedImage(
                                                          id: item.id,
                                                          name: item.name,
                                                          bytes: cropped,
                                                        );
                                                      });
                                                    }
                                                  },
                                                  child: const Padding(
                                                    padding: EdgeInsets.all(5),
                                                    child: Icon(
                                                      Icons.crop,
                                                      size: 15,
                                                      color: Colors.white,
                                                    ),
                                                  ),
                                                ),
                                              ),
                                              const SizedBox(height: 6),
                                              Material(
                                                color: Colors.black.withValues(
                                                  alpha: 0.55,
                                                ),
                                                shape: const CircleBorder(),
                                                child: const Padding(
                                                  padding: EdgeInsets.all(5),
                                                  child: Icon(
                                                    Icons.drag_indicator,
                                                    size: 15,
                                                    color: Colors.white,
                                                  ),
                                                ),
                                              ),
                                            ],
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
            );
          },
        );
      },
    );
  }

  Future<Uint8List?> _buildPdfBytesFromImages(
    List<_PickedImage> images,
    _ImagePdfPageMode pageMode,
    {
    required _ProgressReporter report,
  }) async {
    const batchSize = 4;
    final prepared = <_ProcessedPdfImage?>[];
    final totalImages = images.length;

    for (var i = 0; i < images.length; i += batchSize) {
      final end = (i + batchSize < images.length) ? i + batchSize : images.length;
      final batch = images.sublist(i, end);
      report('Working: Images to PDF (processing images ${i + 1} to $end of $totalImages)', (i + 1) / totalImages);
      final chunk = await Future.wait<_ProcessedPdfImage?>(
        batch.map((item) => compute(_prepareImageForPdf, item.bytes)),
      );
      prepared.addAll(chunk);
      await Future<void>.delayed(Duration.zero);
    }

    final doc = pw.Document();
    var addedPages = 0;

    for (var pageIndex = 0; pageIndex < prepared.length; pageIndex++) {
      final processed = prepared[pageIndex];
      report(
        'Working: Images to PDF (building page ${pageIndex + 1} of $totalImages)',
        (pageIndex + 1) / totalImages,
      );
      if (processed == null) {
        continue;
      }

      final image = pw.MemoryImage(processed.jpegBytes);
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
          build: (_) {
            return pw.Center(
              child: pw.FittedBox(
                fit: pw.BoxFit.contain,
                child: pw.Image(image),
              ),
            );
          },
        ),
      );

      addedPages += 1;
    }

    if (addedPages == 0) {
      return null;
    }

    return doc.save();
  }

  Future<void> _imageToPdf({required _ProgressReporter report}) async {
    if (!mounted) {
      return;
    }

    final setup = await _showImagePdfSetupDialog(<_PickedImage>[]);
    if (setup == null || setup.images.isEmpty) {
      return;
    }

    final pdfBytes = await _buildPdfBytesFromImages(
      setup.images,
      setup.pageMode,
      report: report,
    );
    if (pdfBytes == null) {
      _showMessage('No valid image pages found to create a PDF.');
      return;
    }

    final saved = await _saveBytes('images_to_pdf_${_timestamp()}.pdf', pdfBytes);
    _showMessage(saved);
  }

  Uint8List _convertPngToJpg(Uint8List pngBytes) {
    final decoded = img.decodeImage(pngBytes);
    if (decoded == null) {
      return pngBytes;
    }
    return Uint8List.fromList(img.encodeJpg(decoded, quality: 85));
  }

  Future<void> _pdfToImages({required _ProgressReporter report}) async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: const <String>['pdf'],
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

    var totalPages = 0;
    report('Working: PDF to Images (counting pages...)', null);
    await for (final _ in Printing.raster(pdfBytes, dpi: 36)) {
      totalPages += 1;
    }

    if (totalPages == 0) {
      _showMessage('No pages rendered');
      return;
    }

    var pageCounter = 0;
    report('Working: PDF to Images (processing page 0 of $totalPages)', 0);
    await for (final page in Printing.raster(pdfBytes, dpi: 144)) {
      pageCounter += 1;
      report(
        'Working: PDF to Images (processing page $pageCounter of $totalPages)',
        pageCounter / totalPages,
      );
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

  Future<String> _performOcr(InputImage inputImage) async {
    final textRecognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final recognizedText = await textRecognizer.processImage(inputImage);
      return recognizedText.text;
    } catch (e) {
      return 'OCR Error: $e';
    } finally {
      textRecognizer.close();
    }
  }

  String _sanitizeText(String text) {
    if (text.isEmpty) {
      return text;
    }
    var sanitized = text.replaceAll('—', ' ');
    sanitized = sanitized.replaceAll(RegExp(r',\s+and\b'), ' and');
    sanitized = sanitized.replaceAll(RegExp(r'\s{2,}'), ' ');
    return sanitized.trim();
  }

  Future<void> _showExtractedTextDialog(String text) async {
    final sanitized = _sanitizeText(text);
    await showDialog<void>(
      context: context,
      builder: (dialogContext) {
        return AlertDialog(
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
                  await Clipboard.setData(ClipboardData(text: sanitized));
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
            child: sanitized.trim().isEmpty
                ? const Center(child: Text('No readable text found in this PDF.'))
                : Scrollbar(
                    thumbVisibility: true,
                    child: SingleChildScrollView(
                      child: SelectableText(
                        sanitized,
                        style: const TextStyle(height: 1.35),
                      ),
                    ),
                  ),
          ),
        );
      },
    );
  }

  Future<void> _textExtraction({required _ProgressReporter report}) async {
    if (kIsWeb) {
      _showMessage('Text extraction is not yet supported on Web.');
      return;
    }

    final source = await showDialog<_TextSource>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('Extract text from?'),
          actions: <Widget>[
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(_TextSource.camera),
              icon: const Icon(Icons.camera_alt_outlined),
              label: const Text('Camera'),
            ),
            TextButton.icon(
              onPressed: () => Navigator.of(context).pop(_TextSource.pdf),
              icon: const Icon(Icons.picture_as_pdf_outlined),
              label: const Text('PDF File'),
            ),
          ],
        );
      },
    );

    if (source == null) {
      return;
    }

    String extractedText = '';
    if (source == _TextSource.camera) {
      final shot = await _captureFromCamera();
      if (shot == null) {
        return;
      }
      final tempDir = await getTemporaryDirectory();
      final tempFile = File('${tempDir.path}/camera_text_${_timestamp()}.jpg');
      await tempFile.writeAsBytes(shot, flush: true);
      final inputImage = InputImage.fromFilePath(tempFile.path);
      report('Working: Text Extraction (processing camera image)', null);
      extractedText = await _performOcr(inputImage);
    } else {
      final picked = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        type: FileType.custom,
        allowedExtensions: const <String>['pdf'],
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

      final tempDir = await getTemporaryDirectory();
      final textBuffer = StringBuffer();
      var pageIndex = 0;
      var totalPages = 0;
      report('Working: Text Extraction (counting pages...)', null);
      await for (final _ in Printing.raster(bytes, dpi: 36)) {
        totalPages += 1;
      }
      await for (final page in Printing.raster(bytes, dpi: 144)) {
        pageIndex += 1;
        report(
          'Working: Text Extraction (processing page $pageIndex of $totalPages)',
          pageIndex / totalPages,
        );
        final pngBytes = await page.toPng();
        final tempFile = File('${tempDir.path}/ocr_page_$pageIndex.png');
        await tempFile.writeAsBytes(pngBytes, flush: true);
        final inputImage = InputImage.fromFilePath(tempFile.path);
        textBuffer.writeln(await _performOcr(inputImage));
      }
      extractedText = textBuffer.toString();
    }

    if (!mounted) {
      return;
    }
    await _showExtractedTextDialog(extractedText);
  }

  Future<void> _cropPhoto({required _ProgressReporter report}) async {
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

    report('Working: Cropping image...', null);

    final croppedBytes = await Navigator.of(context).push<Uint8List>(
      MaterialPageRoute(
        builder: (_) => _ManualCropScreen(
          imageBytes: sourceBytes,
          title: selected.name,
        ),
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

  void _navigateToFeature(BuildContext context, _ToolAction action) {
    Navigator.of(context).push(
      MaterialPageRoute<void>(
        builder: (_) => _FeatureDetailScreen(action: action),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final mediaQuery = MediaQuery.of(context);
    final width = mediaQuery.size.width;
    final webStyle = kIsWeb || width >= 900;
    final appTextScaler = _isMobilePlatform
        ? const TextScaler.linear(0.92)
        : mediaQuery.textScaler;

    const cardSchemes = <_CardColorScheme>[
      _CardColorScheme.red(),
      _CardColorScheme.turquoise(),
    ];

    final actions = <_ToolAction>[
      _ToolAction(
        icon: Icons.picture_as_pdf_rounded,
        title: 'Images to PDF',
        subtitle: 'JPG/PNG photos into one PDF file',
        onTap: (report) => _imageToPdf(report: report),
      ),
      _ToolAction(
        icon: Icons.image_outlined,
        title: 'PDF to Images',
        subtitle: 'Export each page as JPG',
        onTap: (report) => _pdfToImages(report: report),
      ),
      _ToolAction(
        icon: Icons.text_snippet_outlined,
        title: 'Text Extraction',
        subtitle: 'Extract text from images or PDF files using offline OCR',
        onTap: (report) => _textExtraction(report: report),
      ),
      _ToolAction(
        icon: Icons.crop,
        title: 'Crop Photo',
        subtitle: 'Drag the crop corners manually',
        onTap: (report) => _cropPhoto(report: report),
      ),
    ];

    return MediaQuery(
      data: mediaQuery.copyWith(textScaler: appTextScaler),
      child: Scaffold(
        appBar: AppBar(
          backgroundColor: Colors.transparent,
          elevation: 0,
          flexibleSpace: const _GradientSurface(
            gradient: AppGradients.redToWhite,
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
                  color: Colors.black87,
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
                decoration: const BoxDecoration(color: Colors.white),
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
                          _GradientSurface(
                            width: double.infinity,
                            padding: EdgeInsets.all(webStyle ? 24 : 16),
                            borderRadius: BorderRadius.circular(18),
                            gradient: AppGradients.redToWhite,
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
                                        color: Colors.black87,
                                        fontWeight: FontWeight.w700,
                                      ),
                                ),
                                const SizedBox(height: 8),
                                Text(
                                  'Works offline on web and mobile. Pick a tool and save instantly.',
                                  style: Theme.of(context)
                                      .textTheme
                                      .bodyMedium
                                      ?.copyWith(
                                        color: Colors.black87,
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
                                final isMobileWidth = constraints.maxWidth < 760;
                                final gridColumns = isMobileWidth
                                    ? 1
                                    : (constraints.maxWidth >= 980 ? 3 : 2);
                                final cardHeight = isMobileWidth ? 118.0 : 112.0;

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
                                    final scheme =
                                        cardSchemes[index % cardSchemes.length];
                                    return _ToolCard(
                                      icon: action.icon,
                                      title: action.title,
                                      subtitle: action.subtitle,
                                      scheme: scheme,
                                      onTap: _isWorking
                                          ? null
                                          : () => _navigateToFeature(
                                                context,
                                                action,
                                              ),
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
                                SizedBox(
                                  width: 220,
                                  child: _progress == null
                                      ? const LinearProgressIndicator()
                                      : LinearProgressIndicator(
                                          value: _progress!.clamp(0.0, 1.0),
                                        ),
                                ),
                                const SizedBox(height: 14),
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
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Future<void> Function(_ProgressReporter report) onTap;
}

class _CardColorScheme {
  const _CardColorScheme({
    required this.accent,
    required this.gradient,
  });

  const _CardColorScheme.red()
      : accent = AppPalette.red,
        gradient = AppGradients.redCardSurface;

  const _CardColorScheme.turquoise()
      : accent = AppPalette.turquoise,
        gradient = AppGradients.turquoiseCardSurface;

  final Color accent;
  final LinearGradient gradient;
}

enum _ImagePdfPageMode { a4, matchImage }

enum _TextSource { camera, pdf }

class _ProcessedPdfImage {
  const _ProcessedPdfImage({
    required this.width,
    required this.height,
    required this.jpegBytes,
  });

  final int width;
  final int height;
  final Uint8List jpegBytes;
}

_ProcessedPdfImage? _prepareImageForPdf(Uint8List sourceBytes) {
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    return null;
  }

  const maxDim = 1600;
  img.Image resized = decoded;
  if (decoded.width > maxDim || decoded.height > maxDim) {
    final maxCurrent = decoded.width > decoded.height
        ? decoded.width.toDouble()
        : decoded.height.toDouble();
    final ratio = maxDim / maxCurrent;
    final newWidth = (decoded.width * ratio).round();
    final newHeight = (decoded.height * ratio).round();
    resized = img.copyResize(decoded, width: newWidth, height: newHeight);
  }

  return _ProcessedPdfImage(
    width: resized.width,
    height: resized.height,
    jpegBytes: Uint8List.fromList(img.encodeJpg(resized, quality: 80)),
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

class _FeatureDetailScreen extends StatefulWidget {
  const _FeatureDetailScreen({required this.action});

  final _ToolAction action;

  @override
  State<_FeatureDetailScreen> createState() => _FeatureDetailScreenState();
}

class _FeatureDetailScreenState extends State<_FeatureDetailScreen> {
  bool _isWorking = false;
  String _status = 'Ready';
  double? _progress;

  void _report(String status, [double? progress]) {
    if (!mounted) {
      return;
    }
    setState(() {
      _status = status;
      _progress = progress;
    });
  }

  Future<void> _runFeature() async {
    setState(() {
      _isWorking = true;
      _status = 'Processing...';
      _progress = null;
    });

    await WidgetsBinding.instance.endOfFrame;
    await Future<void>.delayed(const Duration(milliseconds: 50));

    try {
      await widget.action.onTap(_report);
    } finally {
      if (mounted) {
        setState(() {
          _isWorking = false;
          _status = 'Ready';
          _progress = null;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isWebWide = kIsWeb && MediaQuery.of(context).size.width >= 900;
    return Scaffold(
      appBar: AppBar(title: Text(widget.action.title)),
      body: SafeArea(
        child: Stack(
          children: <Widget>[
            Center(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 520),
                child: Card(
                  elevation: 8,
                  margin: const EdgeInsets.all(20),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(18),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(24),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: <Widget>[
                        Icon(widget.action.icon, size: 48, color: AppPalette.turquoise),
                        const SizedBox(height: 14),
                        Text(
                          widget.action.title,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          widget.action.subtitle,
                          textAlign: TextAlign.center,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                        const SizedBox(height: 22),
                        Align(
                          child: SizedBox(
                            width: isWebWide ? 260 : double.infinity,
                            child: FilledButton.icon(
                              style: FilledButton.styleFrom(
                                backgroundColor: AppPalette.turquoise,
                                foregroundColor: Colors.white,
                                padding: const EdgeInsets.symmetric(vertical: 14),
                              ),
                              icon: const Icon(Icons.play_arrow_rounded),
                              onPressed: _isWorking ? null : _runFeature,
                              label: const Text('Run'),
                            ),
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
                  color: Colors.black.withValues(alpha: 0.28),
                  child: Center(
                    child: Card(
                      elevation: 6,
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 18,
                          vertical: 16,
                        ),
                        child: Column(
                          mainAxisSize: MainAxisSize.min,
                          children: <Widget>[
                            SizedBox(
                              width: 220,
                              child: _progress == null
                                  ? const LinearProgressIndicator()
                                  : LinearProgressIndicator(
                                      value: _progress!.clamp(0.0, 1.0),
                                    ),
                            ),
                            const SizedBox(height: 14),
                            const CircularProgressIndicator(),
                            const SizedBox(height: 12),
                            Text(
                              _status,
                              textAlign: TextAlign.center,
                              style: const TextStyle(fontWeight: FontWeight.w600),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _CameraCaptureScreen extends StatefulWidget {
  const _CameraCaptureScreen({required this.camera});

  final CameraDescription camera;

  @override
  State<_CameraCaptureScreen> createState() => _CameraCaptureScreenState();
}

class _CameraCaptureScreenState extends State<_CameraCaptureScreen> {
  late final CameraController _controller;
  bool _initializing = true;
  bool _capturing = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    _controller = CameraController(
      widget.camera,
      ResolutionPreset.medium,
      enableAudio: false,
    );
    _controller.initialize().then((_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
      });
    }).catchError((Object error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
        _errorMessage = 'Could not start camera: $error';
      });
    });
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  Future<void> _capture() async {
    if (_capturing || !_controller.value.isInitialized) {
      return;
    }

    setState(() {
      _capturing = true;
    });

    try {
      final picture = await _controller.takePicture();
      final bytes = await picture.readAsBytes();
      if (!mounted) {
        return;
      }
      Navigator.of(context).pop<Uint8List>(bytes);
    } catch (error) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Capture failed: $error')),
        );
      }
    } finally {
      if (mounted) {
        setState(() {
          _capturing = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Camera')),
      body: SafeArea(
        child: _errorMessage != null
            ? Center(
                child: Padding(
                  padding: const EdgeInsets.all(24),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: <Widget>[
                      const Icon(Icons.no_photography_outlined, size: 48),
                      const SizedBox(height: 12),
                      Text(
                        _errorMessage!,
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 16),
                      FilledButton(
                        onPressed: () => Navigator.of(context).pop(),
                        child: const Text('Close'),
                      ),
                    ],
                  ),
                ),
              )
            : _initializing
                ? const Center(child: CircularProgressIndicator())
                : Column(
                    children: <Widget>[
                      Expanded(
                        child: Center(
                          child: AspectRatio(
                            aspectRatio: _controller.value.aspectRatio,
                            child: CameraPreview(_controller),
                          ),
                        ),
                      ),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(16),
                        color: Colors.black87,
                        child: Row(
                          children: <Widget>[
                            Expanded(
                              child: OutlinedButton(
                                style: OutlinedButton.styleFrom(
                                  foregroundColor: Colors.white,
                                  side: const BorderSide(color: Colors.white70),
                                ),
                                onPressed: () => Navigator.of(context).pop(),
                                child: const Text('Cancel'),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: FilledButton(
                                onPressed: _capturing ? null : _capture,
                                child: Text(_capturing ? 'Capturing...' : 'Capture'),
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

class _ToolCard extends StatelessWidget {
  const _ToolCard({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.scheme,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final _CardColorScheme scheme;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: scheme.accent.withValues(alpha: 0.45)),
          gradient: scheme.gradient,
        ),
        child: Padding(
          padding: const EdgeInsets.all(14),
          child: Row(
            children: <Widget>[
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: scheme.accent.withValues(alpha: 0.15),
                  shape: BoxShape.circle,
                ),
                child: Icon(icon, color: scheme.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
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
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GradientSurface extends StatelessWidget {
  const _GradientSurface({
    required this.gradient,
    this.child,
    this.width,
    this.padding,
    this.borderRadius,
  });

  final LinearGradient gradient;
  final Widget? child;
  final double? width;
  final EdgeInsetsGeometry? padding;
  final BorderRadius? borderRadius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: width,
      padding: padding,
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: borderRadius,
      ),
      child: child,
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

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
          'Crop: ${widget.title}',
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ),
      body: SafeArea(
        child: Column(
          children: <Widget>[
            Expanded(
              child: Crop(
                image: widget.imageBytes,
                controller: _controller,
                withCircleUi: false,
                onCropped: (croppedImage) {
                  if (!mounted) {
                    return;
                  }
                  Navigator.of(context).pop<Uint8List>(croppedImage);
                },
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 14),
              child: Row(
                children: <Widget>[
                  Expanded(
                    child: OutlinedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('Cancel'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: FilledButton(
                      onPressed: () => _controller.crop(),
                      child: const Text('Apply Crop'),
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
