# Local PDF Studio

Local PDF Studio is a Flutter app for quick PDF and image utilities across web and mobile. It is designed for on-device processing so you can convert files without sending documents to external servers.

## Why this app

- Local-first workflow: file processing happens inside the app on your device.
- Privacy-friendly by design: no cloud upload flow is required for conversions.
- Fast utility toolbox: create or extract content in a few taps.

## Features

- Images to PDF
	- Select one or many images.
	- Reorder pages before export.
	- Choose A4 output or match image size.
- Camera to PDF (mobile only)
	- Capture a single photo or multiple photos.
	- Combine captures into one PDF.
- PDF to Images
	- Export each PDF page as PNG.
- PDF to Text
	- Extract plain text from a PDF.
- PDF to Word
	- Export extracted text into a basic `.doc` file.
- Crop Photo
	- Manual crop tool before saving.

## Security and privacy

This app is local-only for its conversion flows. Your selected files are processed on-device/in-app and are not sent to a backend service by default.

Important note:
Standard platform permissions are required for camera-based features.

## Supported platforms

- Android
- iOS
- Web
- Windows
- macOS
- Linux

Note: Camera capture is available on Android and iOS.

## Tech stack

- Flutter (Material 3 UI)
- `pdf` and `printing` for PDF generation and rasterization
- `syncfusion_flutter_pdf` for text extraction
- `file_picker` and `file_saver` for file input/output
- `image` for image decoding
- `crop_your_image` for manual crop
- `image_picker` for camera capture on mobile

## Usage quick guide

1. Open the app and select a tool card.
2. Pick input files (or capture from camera on mobile).
3. Wait for processing to finish (loading overlay appears while working).
4. Save exported output when prompted.

## Project structure

- `lib/main.dart`: main UI and conversion logic
- `android/` and `ios/`: platform configuration and permissions
- `web/`, `windows/`, `macos/`, `linux/`: platform runners

## Disclaimer

Text extraction quality depends on PDF content. Scanned PDFs without selectable text may require OCR, which is not included in this app yet.
