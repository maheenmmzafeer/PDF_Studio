import '../models.dart';

Future<void> cameraToPdf(AppHost host) async {
  if (!host.isMobilePlatform) {
    host.showMessage('Camera capture is only available on Android and iOS.');
    return;
  }

  final setup = await host.showImagePdfSetupDialog(
    <PickedImage>[],
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

  final saved = await host.saveBytes('camera_to_pdf_${host.timestamp()}.pdf', pdfBytes);
  host.showMessage(saved);
}
