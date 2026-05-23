import '../models.dart';
import 'package:file_picker/file_picker.dart';
import 'package:printing/printing.dart';
import 'package:flutter/foundation.dart';

Future<void> pdfToImages(AppHost host) async {
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

  final pdfBytes = await host.readPickedFileBytes(selected);
  if (pdfBytes == null) {
    host.showMessage('Could not read selected PDF');
    return;
  }

  var pageCounter = 0;
  await for (final page in Printing.raster(pdfBytes, dpi: 144)) {
    pageCounter += 1;
    final stamp = host.timestamp();
    Uint8List png;
    try {
      png = await page.toPng();
    } catch (e) {
      host.showMessage('Failed to render page $pageCounter: $e');
      continue;
    }

    // Offload PNG->JPG conversion to a background isolate to avoid deep
    // stack/CPU pressure on the main isolate which has caused stack overflows.
    Uint8List jpgBytes;
    try {
      jpgBytes = await compute(convertPngToJpg, png);
    } catch (e) {
      // Fallback: try synchronous conversion on error
      jpgBytes = host.convertPngToJpg(png);
    }

    final imageName = 'pdf_page_${stamp}_$pageCounter';
    await host.saveBytes('$imageName.jpg', jpgBytes);
  }

  if (pageCounter == 0) {
    host.showMessage('No pages rendered');
    return;
  }
  host.showMessage('$pageCounter JPG page image(s) saved');
}
