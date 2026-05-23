import 'package:flutter/material.dart';

import '../models.dart';
import '../widgets/camera_capture_screen.dart';

Future<void> cameraToPdf(AppHost host) async {
  if (!host.isMobilePlatform) {
    host.showMessage('Camera capture is only available on Android and iOS.');
    return;
  }

  final capturedImages = await Navigator.of(host.context).push<List<PickedImage>>(
    MaterialPageRoute(
      builder: (_) => const CameraCaptureScreen(),
    ),
  );
  if (capturedImages == null || capturedImages.isEmpty) {
    return;
  }

  final setup = await host.showImagePdfSetupDialog(
    capturedImages,
    allowAddImages: true,
  );
  if (setup == null || setup.images.isEmpty) {
    return;
  }

  final pdfBytes = await host.buildPdfBytesFromImages(
    setup.images,
    setup.pageMode,
  );
  if (pdfBytes == null) {
    host.showMessage('No valid captured images found to create a PDF.');
    return;
  }

  final savedPath = await host.savePdfBytes(
    'camera_to_pdf_${host.timestamp()}.pdf',
    pdfBytes,
  );
  if (savedPath == null) {
    host.showMessage('Save cancelled');
    return;
  }

  host.showMessage('Saved PDF: $savedPath');
}
