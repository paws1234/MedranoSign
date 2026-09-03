# pdf_esign_app

A production-ready **Flutter multiplatform PDF viewer & e-sign application**.

Open any standard PDF, overlay interactive text fields and electronic signatures,
stamp **only** the elements the user explicitly placed onto the original PDF,
append a clean **audit trail** page (UTC timestamp, device/user-agent info,
SHA-256 hash of the signed content), and export the result.

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
- 🖋 **Stamping service** that draws *only* the user-placed text and signature
  images onto the original PDF (`syncfusion_flutter_pdf`, pure Dart).
- 📄 **Certificate of Completion / audit trail** page appended to the document
  with the signing time, platform/device info, action list and the SHA-256 hash
  of the signed document bytes.
- 💾 Save / download the final PDF on Web, mobile and desktop.

> **Important rule:** the exporter never adds stamps, watermarks, logos, borders
> or any other visual element the user did not explicitly place. Overlay → stamp
> → audit is the complete write path.

## Repository layout

The Flutter project lives at the repository root (package name `pdf_esign_app`).
Planning documents:

- [.claude/Plan.md](.claude/Plan.md) – full product plan and milestones.
- [.claude/implement.md](.claude/implement.md) – task-by-task agentic implementation guide with statuses.
- `.claude/taskNN.md` – per-task briefs + completion logs (one task, one session).

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
│   ├── modifier/             # PDF stamping + audit trail (syncfusion)
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

### Syncfusion license note

PDF *stamping / editing* uses `syncfusion_flutter_pdf`, which is distributed
under Syncfusion's free **Community License** (for organizations under
US$1M annual revenue and < 5 developers) or a commercial license. Since
Syncfusion 18.3.35-beta no license-key registration or watermark is required in
code, but you are legally required to hold a valid license before shipping.
Register at <https://www.syncfusion.com/products/communitylicense> and follow
their Flutter licensing terms. The viewer and signature pad are independent
open implementations and carry no such obligation.

## Tests

```bash
flutter analyze
flutter test
```

Headless (CI) verification: `flutter test` runs the full unit + widget suite;
`flutter build web` compiles the complete application for a real target.
Manual on-device verification is recommended before release (see
[implement.md](.claude/implement.md), Tasks 15–17).

## License

Third-party packages retain their own licenses. This application source is
provided as-is under the MIT license (see `LICENSE` if present).
