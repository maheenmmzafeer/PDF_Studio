# Local PDF Studio

Local PDF Studio is a Flutter app for quick PDF and image utilities across web and mobile. It is designed for on-device processing so you can convert files without sending documents to external servers.

## Why this app

- Local-first workflow: file processing happens inside the app on your device.
- Privacy-friendly by design: no cloud upload flow is required for conversions.
- Fast utility toolbox: create or extract content in a few taps.

## Features

- Images to PDF
	- Select one or many images.
	- Reorder pages and remove unwanted images before export.
	- Choose A4 output or match image size.
- Camera to PDF (mobile only)
	- Open camera directly and capture multiple photos.
	- After capture, review thumbnails, remove/reorder, then create one PDF.
	- Choose A4 output or match image size.
- PDF to Images
	- Export each PDF page as JPG.
	- On Android, saved JPGs are indexed so they can appear in Gallery apps.
- PDF to Text
	- Extract text and show it directly in an in-app popup dialog.
	- Popup includes copy-to-clipboard and close controls.
- Crop Photo
	- Manual crop tool before saving.

## Security and privacy

This app is local-only for its conversion flows. Your selected files are processed on-device/in-app and are not sent to a backend service by default.

Important note:
Standard platform permissions are required for camera-based features.

## Save behavior by platform

- Android: files are saved directly to the Downloads folder. The app also triggers media indexing so image files can appear in Gallery.
- iOS: files are saved directly to the app Documents folder (available in the Files app under this app). iOS does not use an Android-style Downloads folder path for apps.
- Web/Desktop: files are saved with the platform file-saving flow.

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
- `path_provider` for direct device storage paths

## Usage quick guide

1. Open the app and select a tool card.
2. Pick input files (or capture from camera on mobile).
3. Wait for processing to finish (loading overlay appears while working).
4. For PDF to Text, read/copy text from the popup dialog.
5. For file exports, check your platform-specific save location.

## Project structure

- `lib/main.dart`: main UI and conversion logic
- `android/` and `ios/`: platform configuration and permissions
- `web/`, `windows/`, `macos/`, `linux/`: platform runners

## Disclaimer

Text extraction quality depends on PDF content. Scanned PDFs without selectable text may require OCR, which is not included in this app yet.
