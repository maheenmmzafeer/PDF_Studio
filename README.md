# Local PDF Studio

Local PDF Studio is a Flutter app for quick PDF and image utilities. It is designed for on-device processing so you can convert files without sending documents to external servers.

## Why this app

- Local-first workflow: file processing happens inside the app on your device.
- Privacy-friendly by design: no cloud upload flow is required for conversions.
- Fast utility toolbox: create or extract content in a few taps.
- Offline OCR: extract text from images and PDFs without an internet connection.

## Features

- Images to PDF
  - Select one or many images.
  - Reorder pages and remove unwanted images before export.
  - Choose A4 output or match image size.
  - Manual crop tool for each image.
- Camera to PDF
  - Open camera directly and capture multiple photos.
  - After capture, review thumbnails, remove/reorder and crop before export.
  - Choose A4 output or match image size.
- PDF to Images
  - Export each PDF page as JPG.
  - Optimized for small file size while maintaining clarity.
- Text Extraction (English only)
  - Extract text from PDF files or direct camera captures using offline OCR.
  - Extract and view text with copy-to-clipboard option.
- Crop Photo
  - Manual crop tool for individual photos.

## Security and privacy

This app is local-only for its conversion flows. Your selected files are processed on-device/in-app and are not sent to a backend service by default.

Important note:
Standard platform permissions are required for camera-based features.

## Save behavior by platform

- Android: files are saved directly to the Downloads folder. The app also triggers media indexing so image files can appear in Gallery.
- iOS: files are saved directly to the app Documents folder (available in the Files app under this app).
- Web/Desktop: files are saved with the platform file-saving flow.

## Usage quick guide

1. Open the app and select a tool card.
2. Pick input files (or capture from camera).
3. Wait for processing to finish (loading overlay appears while working).
4. For Text Extraction, read/copy text from the popup dialog.
5. For file exports, check your platform-specific save location.

## Project structure

- `lib/main.dart`: main UI and conversion logic
- `pubspec.yaml`: project dependencies and assets

## Disclaimer

Text extraction quality depends on input clarity. Scanned documents or complex layouts may have variable extraction accuracy. Currently only supports English.
