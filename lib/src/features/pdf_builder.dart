import 'package:flutter/foundation.dart';
import 'package:pdf/pdf.dart' as pdf;
import 'package:pdf/widgets.dart' as pw;

import '../models.dart';

Future<Uint8List?> buildPdfBytesFromImages(
  List<PickedImage> images,
  ImagePdfPageMode pageMode,
) async {
  final doc = pw.Document();
  var addedPages = 0;

  for (final pickedImage in images) {
    final processed = await compute(prepareImageForPdf, pickedImage.bytes);
    if (processed == null) {
      continue;
    }

    final image = pw.MemoryImage(processed.bytes);
    final pageFormat = pageMode == ImagePdfPageMode.matchImage
        ? pdf.PdfPageFormat(
            processed.width.toDouble(),
            processed.height.toDouble(),
            marginAll: 0,
          )
        : pdf.PdfPageFormat.a4;

    final imageWidget = pageMode == ImagePdfPageMode.matchImage
        ? pw.SizedBox(
            width: processed.width.toDouble(),
            height: processed.height.toDouble(),
            child: pw.Image(image, fit: pw.BoxFit.fill),
          )
        : pw.LayoutBuilder(
            builder: (context, constraints) {
              final maxWidth = constraints?.maxWidth ?? processed.width.toDouble();
              final maxHeight = constraints?.maxHeight ?? processed.height.toDouble();
              final widthScale = maxWidth / processed.width.toDouble();
              final heightScale = maxHeight / processed.height.toDouble();
              final scale = widthScale < heightScale ? widthScale : heightScale;
              final finalScale = scale < 1.0 ? scale : 1.0;

              return pw.Center(
                child: pw.SizedBox(
                  width: processed.width.toDouble() * finalScale,
                  height: processed.height.toDouble() * finalScale,
                  child: pw.Image(image, fit: pw.BoxFit.fill),
                ),
              );
            },
          );

    doc.addPage(
      pw.Page(
        pageFormat: pageFormat,
        margin: pw.EdgeInsets.zero,
        build: (_) => imageWidget,
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