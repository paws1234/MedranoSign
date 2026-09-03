import 'dart:typed_data';

/// An already-rasterized page of the source document.
///
/// In the free, license-free export pipeline these images come from the
/// viewer's renderer (`pdfx`'s `PdfPage.render(...)`), so the modifier never
/// opens or mutates the original PDF bytes — that is precisely what lets the
/// whole stack stay on permissively-licensed packages (`pdf` is Apache-2.0,
/// `pdfx` is MIT). See `PdfModifierService` for the full rationale.
class PdfPageRender {
  PdfPageRender({
    required this.pageIndex,
    required this.widthPt,
    required this.heightPt,
    required this.imageBytes,
  })  : assert(pageIndex >= 0),
        assert(widthPt > 0 && heightPt > 0),
        assert(imageBytes.isNotEmpty);

  /// 0-based index of this page in the source document.
  final int pageIndex;

  /// Page display width in PDF points (1 pt = 1/72 inch).
  ///
  /// The renderer must hand over the page already oriented the way it was
  /// displayed (any `/Rotate` applied) so it matches the on-screen overlay
  /// coordinate space exactly.
  final double widthPt;

  /// Page display height in PDF points.
  final double heightPt;

  /// Rendered page raster. PNG is recommended; the web backend always emits
  /// PNG.
  final Uint8List imageBytes;
}

/// Kind of a user-placed element that will be stamped onto a page.
enum StampElementType { text, signature }

/// A single element the user explicitly placed on [pageIndex].
///
/// Coordinates are normalized (0..1) in top-left space of the *displayed*
/// page, matching the coordinate system used by the interactive overlay
/// layer, so a stamp lands exactly where the user saw it.
class StampElement {
  StampElement.text({
    required this.pageIndex,
    required this.normalizedLeft,
    required this.normalizedTop,
    required this.normalizedWidth,
    required this.normalizedHeight,
    required String text,
    this.textScale = 0.5,
    this.textColorArgb = 0xFF000000,
  })  : type = StampElementType.text,
        text = text,
        imageBytes = null,
        assert(text.isNotEmpty),
        assert(normalizedWidth > 0 && normalizedHeight > 0);

  StampElement.signature({
    required this.pageIndex,
    required this.normalizedLeft,
    required this.normalizedTop,
    required this.normalizedWidth,
    required this.normalizedHeight,
    required this.imageBytes,
  })  : type = StampElementType.signature,
        text = null,
        textScale = 0.5,
        textColorArgb = 0xFF000000,
        assert(normalizedWidth > 0 && normalizedHeight > 0);

  /// 0-based target page.
  final int pageIndex;

  /// Normalized (0..1) top-left corner of the element box.
  final double normalizedLeft;

  /// Normalized (0..1) top-left corner of the element box.
  final double normalizedTop;

  /// Normalized (0..1) width of the element box (> 0).
  final double normalizedWidth;

  /// Normalized (0..1) height of the element box (> 0).
  final double normalizedHeight;

  final StampElementType type;

  /// Text content (only for [StampElementType.text]).
  final String? text;

  /// Transparent PNG bytes (only for [StampElementType.signature]).
  final Uint8List? imageBytes;

  /// Font size as a fraction of the element box height (0.5 = half the box).
  final double textScale;

  /// Text color as ARGB (used for text elements only).
  final int textColorArgb;
}

/// Static, factual information rendered on the appended audit-trail page.
class AuditInfo {
  AuditInfo({
    required this.signedAtUtc,
    required this.deviceInfo,
    this.appName = 'pdf_esign_app',
    this.userAgent = '',
    this.sourceFileName,
    this.customActions,
  });

  /// Signing timestamp in UTC. Serialized as ISO-8601 with a trailing 'Z'.
  final DateTime signedAtUtc;

  /// Platform / device description, e.g. `Android 14 · Pixel 7`.
  final String deviceInfo;

  /// Application/product name shown in the title metadata and audit page.
  final String appName;

  /// User-agent string where available (web), otherwise empty.
  final String userAgent;

  /// Optional original file name shown on the audit page.
  final String? sourceFileName;

  /// Optional explicit action list. When null, the service derives one from
  /// the stamped elements (e.g. `Signature — page 2`).
  final List<String>? customActions;
}
