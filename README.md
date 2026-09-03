# pdf_esign_app

A production-ready **Flutter multiplatform PDF viewer & e-sign application**.

Open any standard PDF, overlay interactive text fields and electronic signatures,
export a **flattened** PDF that contains only the elements the user explicitly
placed, append a clean **audit trail** page (UTC timestamp, device/user-agent
info, SHA-256 fingerprint of the signed content), and save the result. The whole
stack is open source — **no licenses required**.

## Supported platforms

| Platform   | Rendering backend                        | Notes |
|------------|------------------------------------------|-------|
| Web        | PDF.js (via `pdfx`)                      | Run `dart run pdfx:install_web` after adding the dependency so the PDF.js library is injected into `web/index.html`. |
| Android    | PDFium (via `pdfx`)                      | |
| iOS        | Core Graphics (via `pdfx`)               | Build requires macOS + Xcode. |
| macOS      | Core Graphics (via `pdfx`)               | Build requires macOS + Xcode. |
| Windows    | PDFium (via `pdfx`)                      | Run `dart run pdfx:install_windows` to add the pdfium override to `CMakeLists.txt`. |
| Linux      | PDFium (via `pdfx`)                      | Needs `clang cmake ninja-build g++ pkg-config libgtk-3-dev` on the host. |

## Features

- 📂 Open a local PDF on every platform (`file_picker`).
- 📄 Multi-page viewer with page navigation, pinch / mouse-wheel zoom and pan.
- ✏️ Tap-to-add **text fields** and **signature blocks**; drag to reposition;
  resize; per-page overlay state in normalized coordinates (robust to zoom/resize).
- ✍️ High-fidelity **signature capture** with finger, mouse and stylus input;
  transparent PNG export at 2×/3× resolution.
- 🖋 **Export service** that rebuilds a **flattened** PDF (`pdf`, Apache-2.0)
  from high-resolution page renders (`pdfx`, MIT), drawing *only* the
  user-placed text and signature images at the exact on-screen positions, then
  appending the audit page. No Syncfusion, no license keys.
- 📄 **Certificate of Completion / audit trail** page appended to the document
  with the signing time, platform/device info, action list and a SHA-256
  fingerprint of the signed content (deterministic canonical digest).
- 💾 Save / download the final PDF on Web, mobile and desktop.

> **Important rule:** the exporter never adds stamps, watermarks, logos, borders
> or any other visual element the user did not explicitly place. Overlay →
> compose/export → audit is the complete write path.

## Repository layout

The Flutter project lives at the repository root (package name `pdf_esign_app`).

Application code structure under `lib/`:

```
lib/
├── main.dart                 # entry point, provider scope
├── app.dart                  # root PdfEsignApp + theming
├── core/
│   ├── theme/                # light/dark themes, colors, type
│   ├── constants/            # breakpoints, keys
│   ├── geometry/             # normalized-coordinate math + PDF point mapping
│   └── utils/
├── features/
│   ├── document/             # document session state (Riverpod ChangeNotifier)
│   ├── viewer/               # PDF rendering abstraction + custom paged viewer
│   ├── overlay/              # overlay element models, painter, edit widgets
│   ├── signature/            # custom signature pad (capture + PNG export)
│   ├── editor/               # e-sign workspace screen wiring viewer + overlays
│   ├── modifier/             # flattened PDF composer + audit trail (free)
│   ├── export/               # cross-platform save / download service
│   └── home/                 # file-open home / responsive app shell
└── shared/
    ├── models/
    ├── services/             # file_service, hashing_service, …
    └── widgets/
```

## State management

`flutter_riverpod`. Long-lived document state (open PDF, per-page overlays, page
raster cache) is held in `ChangeNotifier` controllers exposed as Riverpod
providers; the UI is rebuilt via `ConsumerWidget`.

## Getting started

```bash
flutter pub get

# One-time web setup: injects the PDF.js <script> into web/index.html
dart run pdfx:install_web

# One-time Windows setup (on Windows)
dart run pdfx:install_windows
```

Run:

```bash
flutter run -d chrome     # web
flutter run -d linux      # desktop
flutter run               # connected device / emulator
```

### Platform-specific notes

- **Web**: picking and opening files happens fully in the browser; the final
  document is produced as bytes and downloaded through the browser. No CORS
  issues for local files because the PDF never leaves the client.
- **Android**: uses the system storage access framework via `file_picker`;
  no broad storage permission is required. Exported files are written to the
  app documents / Downloads folder and can be shared via the system share sheet.
- **iOS / macOS / Windows / Linux**: native save dialogs via `file_picker`
  (desktop) and the app documents directory.

### Licensing — fully open source, no licenses required

This project deliberately uses only permissively-licensed, open-source packages.
**Syncfusion is not used**: its PDF-editing and signature widgets carry a
Community-license / paid obligation, so they were removed in favor of the free
alternatives below.

| Package | License | Role |
|---------|---------|------|
| `pdf` | Apache-2.0 | PDF creation: rebuilds the flattened export pages + audit page |
| `pdfx` | MIT | PDF rendering: renders original pages (PDFium / PDF.js / Core Graphics) |
| `signature` | MIT | Signature capture pad with transparent PNG export |
| `file_picker`, `path_provider`, `crypto`, `flutter_riverpod` | OSS | file access, paths, SHA-256, state |

**Export model (flattening).** The free `pdf` package cannot load and edit an
existing PDF (that capability exists only in Syncfusion or the paid
`pdf_crypto`), so the exporter never touches the original bytes. Instead each
original page is rendered to a high-resolution image by `pdfx` and the final
document is a new, flattened PDF containing those page images plus only the
text/signatures the user placed. The output looks identical to the screen; the
original text layer is not selectable in the exported file — standard practice
for signed documents (DocuSign-style).

**Audit hash.** The `pdf` library randomizes the document ID on every save, so
raw PDF bytes are not reproducible. The audit page therefore records a SHA-256
*canonical fingerprint* of the signed content (each page render plus each
placed element), which is deterministic and can be recomputed at any time from
the same content.

If you ever need true vector editing of existing PDFs, the only current options
are Syncfusion (Community/paid license) or `pdf_crypto` (paid); this project
intentionally avoids both.

## Tests

```bash
flutter analyze
flutter test
```

Headless (CI) verification: `flutter test` runs the full unit + widget suite;
`flutter build web` compiles the complete application for a real target.
Manual on-device verification is recommended before release.

## License

Third-party packages retain their own licenses. This application source is
provided as-is under the MIT license (see `LICENSE` if present).
