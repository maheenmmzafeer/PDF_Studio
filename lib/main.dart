import 'dart:convert';
import 'dart:io';
import 'package:crop_your_image/crop_your_image.dart';
import 'package:file_picker/file_picker.dart';
import 'package:file_saver/file_saver.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:image/image.dart' as img;
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

  Future<void> _runTask(String title, Future<void> Function() task) async {
    setState(() {
      _isWorking = true;
      _status = 'Working: $title';
    });

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

  Future<String> _saveBytes(String name, Uint8List bytes) async {
    final dot = name.lastIndexOf('.');
    final base = dot > 0 ? name.substring(0, dot) : name;
    final ext = dot > 0 ? name.substring(dot + 1) : 'bin';

    await FileSaver.instance.saveFile(
      name: base,
      bytes: bytes,
      fileExtension: ext,
      mimeType: MimeType.other,
    );
    return 'Saved $name';
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

  Future<_ImagePdfSetupResult?> _showImagePdfSetupDialog(
    List<_PickedImage> initialImages,
  ) async {
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
                    const SizedBox(width: 8),
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
                                        color: Colors.black.withValues(alpha: 0.55),
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
                                      duration: const Duration(milliseconds: 120),
                                      opacity: (hoveredImageId == item.id || !kIsWeb) ? 1 : 0,
                                      child: Material(
                                        color: Colors.black.withValues(alpha: 0.55),
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
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: Center(
                                  child: SizedBox.square(
                                    dimension: 136,
                                    child: kIsWeb
                                        ? ReorderableDragStartListener(index: index, child: tile)
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

    final doc = pw.Document();
    var addedPages = 0;
    for (final pickedImage in setup.images) {
      final decoded = img.decodeImage(pickedImage.bytes);
      if (decoded == null) {
        continue;
      }

      final image = pw.MemoryImage(img.encodePng(decoded));
      final pageFormat = setup.pageMode == _ImagePdfPageMode.matchImage
          ? pdf.PdfPageFormat(
              decoded.width.toDouble(),
              decoded.height.toDouble(),
              marginAll: 0,
            )
          : pdf.PdfPageFormat.a4;

      doc.addPage(
        pw.Page(
          pageFormat: pageFormat,
          margin: setup.pageMode == _ImagePdfPageMode.matchImage
              ? pw.EdgeInsets.zero
              : const pw.EdgeInsets.all(20),
          build: (_) => pw.Center(
            child: pw.FittedBox(
              fit: pw.BoxFit.contain,
              child: pw.Image(image),
            ),
          ),
        ),
      );
      addedPages += 1;
    }

    if (addedPages == 0) {
      _showMessage('No valid image pages found to create a PDF.');
      return;
    }

    final saved = await _saveBytes(
      'images_to_pdf_${_timestamp()}.pdf',
      await doc.save(),
    );
    _showMessage('Saved: $saved');
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
      final png = await page.toPng();
      await _saveBytes('pdf_page_${_timestamp()}_$pageCounter.png', png);
    }

    if (pageCounter == 0) {
      _showMessage('No pages rendered');
      return;
    }
    _showMessage('$pageCounter page images saved');
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

    final outputPath = await _saveBytes(
      'pdf_text_${_timestamp()}.txt',
      Uint8List.fromList(text.codeUnits),
    );
    _showMessage('Saved: $outputPath');
  }

  Future<String?> _extractPdfText() async {
    final picked = await FilePicker.platform.pickFiles(
      allowMultiple: false,
      type: FileType.custom,
      allowedExtensions: <String>['pdf'],
      withData: true,
    );
    final selected = picked?.files.single;
    if (selected == null) {
      return null;
    }

    final bytes = await _readPickedFileBytes(selected);
    if (bytes == null) {
      _showMessage('Could not read selected PDF');
      return null;
    }

    final document = sfpdf.PdfDocument(inputBytes: bytes);
    final extractor = sfpdf.PdfTextExtractor(document);
    final text = extractor.extractText();
    document.dispose();
    return text;
  }

  Future<void> _pdfToWord() async {
    final text = await _extractPdfText();
    if (text == null) {
      return;
    }

    final outputPath = await _saveBytes(
      'pdf_to_word_${_timestamp()}.doc',
      Uint8List.fromList(text.codeUnits),
    );
    _showMessage('Saved: $outputPath');
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
        builder: (_) => _ManualCropScreen(
          imageBytes: sourceBytes,
          title: selected.name,
        ),
      ),
    );

    if (croppedBytes == null) {
      return;
    }

    final outputPath = await _saveBytes('cropped_${_timestamp()}.png', croppedBytes);
    _showMessage('Saved: $outputPath');
  }

  @override
  Widget build(BuildContext context) {
    final width = MediaQuery.of(context).size.width;
    final webStyle = kIsWeb || width >= 900;
    final actions = <_ToolAction>[
      _ToolAction(
        icon: Icons.picture_as_pdf_rounded,
        title: 'Images to PDF',
        subtitle: 'JPG/PNG photos into one PDF file',
        color: const Color(0xFFB71C1C),
        onTap: () => _runTask('Images to PDF', _imageToPdf),
      ),
      _ToolAction(
        icon: Icons.image_outlined,
        title: 'PDF to Images',
        subtitle: 'Export each page as PNG',
        color: const Color(0xFFAD1457),
        onTap: () => _runTask('PDF to Images', _pdfToImages),
      ),
      _ToolAction(
        icon: Icons.text_snippet_outlined,
        title: 'PDF to Text',
        subtitle: 'Extract plain text',
        color: const Color(0xFF6A1B9A),
        onTap: () => _runTask('PDF to Text', _pdfToText),
      ),
      _ToolAction(
        icon: Icons.article_outlined,
        title: 'PDF to Word',
        subtitle: 'Create a simple .doc text export',
        color: const Color(0xFF1565C0),
        onTap: () => _runTask('PDF to Word', _pdfToWord),
      ),
      _ToolAction(
        icon: Icons.crop,
        title: 'Crop Photo',
        subtitle: 'Drag the crop corners manually',
        color: const Color(0xFFC62828),
        onTap: () => _runTask('Crop Photo', _cropPhoto),
      ),
    ];

    return Scaffold(
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
        child: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: <Color>[
                const Color(0xFFFFEBEE),
                const Color(0xFFFFF3E0),
                Theme.of(context).colorScheme.surface,
              ],
            ),
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
                          colors: <Color>[Color(0xFFB71C1C), Color(0xFFE53935)],
                        ),
                      ),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: <Widget>[
                          Text(
                            webStyle ? 'PDF + Image Toolkit' : 'Local PDF Toolkit',
                            style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700,
                                ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            'Works offline on web and mobile. Pick a tool and save instantly.',
                            style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                                  color: Colors.white.withValues(alpha: 0.95),
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
                            child: CircularProgressIndicator(strokeWidth: 2.2),
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
                          return GridView.builder(
                            gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
                              crossAxisCount: gridColumns,
                              mainAxisExtent: 112,
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
  const _ImagePdfSetupResult({
    required this.pageMode,
    required this.images,
  });

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
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Ink(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(16),
          color: Colors.white,
          border: Border.all(color: color.withValues(alpha: 0.22)),
          boxShadow: <BoxShadow>[
            BoxShadow(
              color: color.withValues(alpha: 0.1),
              blurRadius: 14,
              offset: const Offset(0, 4),
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
