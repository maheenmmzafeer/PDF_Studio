# PDF Studio 📄

PDF Studio is a fast, private Flutter app for turning images into polished PDFs across web and mobile. It keeps everything on-device, so you can create, review and manage files without sending personal images or documents to third-party services.

Simple by design and local by default, it gives you a clean way to handle everyday PDF tasks with more control over your data.

## Why this app 🔍

- Fast, focused workflow: convert, review and export in just a few taps.
- Privacy-first design: no cloud upload flow is required for conversions.
- Local control: file processing happens inside the app on your device.

## About this project 👥

This app was built as a demonstration of Flutter file workflows and as a practical tool for a family member who wanted a simple way to make PDFs while keeping personal files local.

## Features ⚙️

- Images to PDF
	- Select one or many images.
	- Reorder pages and remove unwanted images before export.
	- Choose A4 output or match image size.
	- Choose the PDF file name and save location before export.
- Camera to PDF (mobile only)
	- Open camera directly and capture multiple photos.
	- After capture, review thumbnails, remove/reorder, then create one PDF.
	- Choose A4 output or match image size.
	- Choose the PDF file name and save location before export.
- PDF to Images
	- Export each PDF page as JPG.
	- On Android, saved JPGs are indexed so they can appear in Gallery apps.
- PDF to Text
	- Extract text and show it directly in an in-app popup dialog.
	- Popup includes copy-to-clipboard and close controls.
- Crop Photo
	- Manual crop tool before saving.

## Security and privacy 🔒

This app is local-only for its conversion flows. Your selected files are processed on-device/in-app and are not sent to a backend service by default.

Important note:
Standard platform permissions are required for camera-based features.

## Usage quick guide 🧭

1. Open the app and select a tool card.
2. Pick input files or capture from camera on mobile.
3. Wait for processing to finish while the loading overlay is shown.
4. For PDF to Text, read or copy text from the popup dialog.
5. For file exports, check your platform-specific save location.

## Save behavior 💾

- PDF exports let you choose the file name and save location before saving.
- Android: files are saved directly to the Downloads folder and image files are indexed so they can appear in Gallery.
- iOS: files are saved directly to the app Documents folder, which is available in the Files app under this app.
- Web and desktop: files use the platform save dialog.

## Supported platforms 🌐

- Android
- iOS
- Web
- Windows
- macOS
- Linux

Note: Camera capture is available on Android and iOS.

## Tech stack 🛠️

- Flutter (Material 3 UI)
- `pdf` and `printing` for PDF generation and rasterization
- `syncfusion_flutter_pdf` for text extraction
- `file_picker` and `file_saver` for file input/output
- `image` for image decoding
- `crop_your_image` for manual crop
- `path_provider` for direct device storage paths
- `camera` for mobile camera capture

## Project structure 🗂️

- `lib/main.dart`: app bootstrap and theme setup
- `lib/src/home.dart`: main app shell and feature routing
- `lib/src/models.dart`: shared models and app host interface
- `lib/src/features/`: feature logic for PDF, crop, camera and text flows
- `lib/src/widgets/`: reusable UI such as the top bar, review page and capture screens
- `lib/src/theme/`: shared colors and typography

- `android/` and `ios/`: platform configuration and permissions
- `web/`, `windows/`, `macos/`, `linux/`: platform runners

## Disclaimer ℹ️

Text extraction quality depends on PDF content. Scanned PDFs without selectable text may require OCR, which is not included in this app yet.
