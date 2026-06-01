import '../models.dart';

Future<void> imageToPdf(AppHost host) async {
  final initialImages = await host.pickImageFiles();
  if (initialImages.isEmpty) {
    return;
  }

  if (!host.mounted) {
    return;
  }

  final setup = await host.showImagePdfSetupDialog(initialImages);
  if (setup == null || setup.images.isEmpty) {
    return;
  }

  final pdfBytes = await host.buildPdfBytesFromImages(
    setup.images,
    setup.pageMode,
  );
  if (pdfBytes == null) {
    host.showMessage('Failed to create PDF');
    return;
  }

  final savedPath = await host.savePdfBytes(
    'images_to_pdf_${host.timestamp()}',
    pdfBytes,
  );
  if (savedPath == null) {
    host.showMessage('Save cancelled');
    return;
  }

  host.showMessage('Saved PDF');
}
