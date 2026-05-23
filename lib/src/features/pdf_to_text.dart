import 'package:file_picker/file_picker.dart';
import 'package:syncfusion_flutter_pdf/pdf.dart' as sfpdf;
import '../models.dart';

Future<void> pdfToText(AppHost host) async {
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

  final bytes = await host.readPickedFileBytes(selected);
  if (bytes == null) {
    host.showMessage('Could not read selected PDF');
    return;
  }

  final document = sfpdf.PdfDocument(inputBytes: bytes);
  final extractor = sfpdf.PdfTextExtractor(document);
  final text = extractor.extractText();
  document.dispose();

  if (!host.mounted) {
    return;
  }

  await host.showExtractedTextDialog(text);
}
