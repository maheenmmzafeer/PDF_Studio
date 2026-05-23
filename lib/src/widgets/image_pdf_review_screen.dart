import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import '../models.dart';
import '../theme/app_colors.dart';
import 'app_top_bar.dart';
import 'manual_crop_screen.dart';

class ImagePdfReviewScreen extends StatefulWidget {
  const ImagePdfReviewScreen({
    required this.initialImages,
    required this.allowAddImages,
    required this.initialPageMode,
    required this.onAddFromGallery,
    required this.onTakePhoto,
    super.key,
  });

  final List<PickedImage> initialImages;
  final bool allowAddImages;
  final ImagePdfPageMode initialPageMode;
  final Future<List<PickedImage>> Function() onAddFromGallery;
  final Future<List<PickedImage>> Function() onTakePhoto;

  @override
  State<ImagePdfReviewScreen> createState() => _ImagePdfReviewScreenState();
}

class _ImagePdfReviewScreenState extends State<ImagePdfReviewScreen> {
  late ImagePdfPageMode _pageMode;
  late List<PickedImage> _images;
  String? _hoveredImageId;

  @override
  void initState() {
    super.initState();
    _pageMode = widget.initialPageMode;
    _images = List<PickedImage>.from(widget.initialImages);
  }

  Future<void> _appendImages(Future<List<PickedImage>> source) async {
    final result = await source;
    if (!mounted || result.isEmpty) return;
    setState(() => _images.addAll(result));
  }

  Future<void> _addFromCamera() async {
    await _appendImages(widget.onTakePhoto());
  }

  Future<void> _cropImageAt(int index) async {
    final item = _images[index];
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
      _images[index] = PickedImage(id: item.id, name: item.name, bytes: cropped);
      if (_hoveredImageId == item.id) {
        _hoveredImageId = null;
      }
    });
  }

  void _removeAt(int index) {
    setState(() {
      final removed = _images.removeAt(index);
      if (_hoveredImageId == removed.id) {
        _hoveredImageId = null;
      }
    });
  }

  void _finish() {
    Navigator.of(context).pop(
      ImagePdfSetupResult(
        pageMode: _pageMode,
        images: List<PickedImage>.from(_images),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: const AppTopBar(
        title: 'Prepare PDF',
        subtitle: 'Review, crop, and reorder your photos',
        showBackButton: true,
      ),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              Text(
                'Page size',
                style: theme.textTheme.titleSmall?.copyWith(fontSize: 14),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: SegmentedButton<ImagePdfPageMode>(
                  segments: const <ButtonSegment<ImagePdfPageMode>>[
                    ButtonSegment<ImagePdfPageMode>(
                      value: ImagePdfPageMode.a4,
                      label: Text('A4'),
                      icon: Icon(Icons.picture_as_pdf_outlined),
                    ),
                    ButtonSegment<ImagePdfPageMode>(
                      value: ImagePdfPageMode.matchImage,
                      label: Text('Image size'),
                      icon: Icon(Icons.photo_size_select_actual_outlined),
                    ),
                  ],
                  selected: <ImagePdfPageMode>{_pageMode},
                  onSelectionChanged: (value) {
                    setState(() => _pageMode = value.first);
                  },
                ),
              ),
              const SizedBox(height: 12),
              if (widget.allowAddImages)
                Row(
                  children: <Widget>[
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: () => _appendImages(widget.onAddFromGallery()),
                        icon: const Icon(Icons.photo_library_outlined),
                        label: const Text('From gallery'),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: _addFromCamera,
                        icon: const Icon(Icons.camera_alt_outlined),
                        label: const Text('Take photo'),
                      ),
                    ),
                  ],
                ),
              const SizedBox(height: 8),
              Text(
                '${_images.length} selected',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 8),
              Text(
                'Drag thumbnails to sort page order',
                style: theme.textTheme.bodySmall?.copyWith(fontSize: 12),
              ),
              const SizedBox(height: 12),
              const Text(
                'Selected photos',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 13),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: _images.isEmpty
                    ? const Center(child: Text('No images selected'))
                    : GridView.builder(
                        padding: const EdgeInsets.only(right: 4),
                        gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 116,
                          mainAxisExtent: 116,
                          crossAxisSpacing: 8,
                          mainAxisSpacing: 8,
                        ),
                        itemCount: _images.length,
                        itemBuilder: (context, index) {
                          final item = _images[index];
                          final tile = MouseRegion(
                            onEnter: (_) => setState(() => _hoveredImageId = item.id),
                            onExit: (_) {
                              if (_hoveredImageId == item.id) {
                                setState(() => _hoveredImageId = null);
                              }
                            },
                            child: Stack(
                              children: <Widget>[
                                Positioned.fill(
                                  child: ClipRRect(
                                    borderRadius: BorderRadius.circular(14),
                                    child: Image.memory(item.bytes, fit: BoxFit.cover),
                                  ),
                                ),
                                Positioned(
                                  left: 8,
                                  bottom: 8,
                                  child: Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                    decoration: BoxDecoration(
                                      color: AppColors.overlay(0.55),
                                      borderRadius: BorderRadius.circular(10),
                                    ),
                                    child: Text(
                                      '${index + 1}',
                                      style: const TextStyle(
                                        color: AppColors.white,
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
                                    opacity: (_hoveredImageId == item.id || !kIsWeb) ? 1 : 0,
                                    child: Row(
                                      children: <Widget>[
                                        Material(
                                          color: AppColors.overlay(0.55),
                                          shape: const CircleBorder(),
                                          child: InkWell(
                                            customBorder: const CircleBorder(),
                                            onTap: () => _cropImageAt(index),
                                            child: const Padding(
                                              padding: EdgeInsets.all(5),
                                              child: Icon(Icons.crop, size: 15, color: AppColors.white),
                                            ),
                                          ),
                                        ),
                                        const SizedBox(width: 6),
                                        Material(
                                          color: AppColors.overlay(0.55),
                                          shape: const CircleBorder(),
                                          child: InkWell(
                                            customBorder: const CircleBorder(),
                                            onTap: () => _removeAt(index),
                                            child: const Padding(
                                              padding: EdgeInsets.all(5),
                                              child: Icon(Icons.close, size: 15, color: AppColors.white),
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

                          return SizedBox.square(
                            key: ValueKey(item.id),
                            dimension: 116,
                            child: kIsWeb
                                ? ReorderableDragStartListener(index: index, child: tile)
                                : ReorderableDelayedDragStartListener(index: index, child: tile),
                          );
                        },
                      ),
              ),
              const SizedBox(height: 12),
              Row(
                children: <Widget>[
                  TextButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('Cancel'),
                  ),
                  const Spacer(),
                  FilledButton(
                    onPressed: _images.isEmpty ? null : _finish,
                    child: const Text('Create PDF'),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
