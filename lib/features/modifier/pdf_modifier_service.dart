import 'dart:convert';
import 'dart:math' as math;
import 'dart:typed_data';

import 'package:crypto/crypto.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;

import 'modifier_models.dart';

/// Size (in pixels) decoded from a PNG header.
class PngSize {
  const PngSize(this.width, this.height);

  final int width;
  final int height;

  @override
  bool operator ==(Object other) =>
      other is PngSize && other.width == width && other.height == height;

  @override
  int get hashCode => Object.hash(width, height);
}

/// Reads the width/height stored in a PNG file's IHDR chunk.
///
/// Returns `null` when [bytes] is not a PNG (or is too short to contain a
/// header). Used to preserve the aspect ratio of signature images.
PngSize? pngDimensions(Uint8List bytes) {
  if (bytes.length < 24) return null;
  // PNG signature: 89 50 4E 47 0D 0A 1A 0A
  if (bytes[0] != 0x89 ||
      bytes[1] != 0x50 ||
      bytes[2] != 0x4E ||
      bytes[3] != 0x47) {
    return null;
  }
  final data = ByteData.sublistView(bytes);
  return PngSize(data.getUint32(16), data.getUint32(20)); // big-endian default
}

/// Result of composing a signed document.
class SignedPdfResult {
  const SignedPdfResult({
    required this.contentBytes,
    required this.finalBytes,
    required this.contentSha256Hex,
  });

  /// A PDF of the signed content (pages + user elements) *without* the audit
  /// page. Informational (e.g. previews); the audit fingerprint does not hash
  /// this serialization because the `pdf` library randomizes the document ID
  /// on every save, so raw bytes are not reproducible.
  final Uint8List contentBytes;

  /// The complete final document: content pages + the audit-trail page.
  final Uint8List finalBytes;

  /// Lower-case hex SHA-256 over the *canonical digest* of the signed content
  /// (page renders + placed elements). Deterministic and reproducible — see
  /// [PdfModifierService.contentSha256]. This is the value the audit page
  /// records.
  final String contentSha256Hex;
}

/// Composes a new, flattened PDF from already-rendered page images plus only
/// the user-placed elements, then appends a clean audit-trail page.
///
/// ## Why "compose" and not "stamp-in-place" (license-free pipeline)
///
/// The free `pdf` package (Apache-2.0) can only *create* documents — it cannot
/// load and modify an existing PDF (that capability only exists in Syncfusion,
/// which carries a license, or the paid `pdf_crypto`). To keep the whole stack
/// free we therefore never touch the original bytes:
///
/// 1. The viewer rasterizes each source page with `pdfx` (MIT) — e.g.
///    `page.render(width: page.width * 2, height: page.height * 2)`.
/// 2. This service builds a brand-new document where every page is that
///    rendered image with the user's text/signatures drawn on top at the exact
///    coordinates they saw, and finally appends one audit-trail page.
///
/// The exported document is *flattened* (the original text layer is not
/// selectable), which is standard — and arguably desirable — for signed
/// documents (DocuSign-style), and keeps appearance identical to the screen.
///
/// ## Invariant
///
/// Only the elements supplied in [elements] and the single appended audit page
/// are ever added. No watermarks, logos, borders or decorative content.
class PdfModifierService {
  const PdfModifierService();

  /// Composes [pages] with [elements] and returns the content bytes without
  /// the audit page (useful for previews and verification).
  Future<Uint8List> buildContentPdf({
    required List<PdfPageRender> pages,
    List<StampElement> elements = const [],
  }) async {
    _validate(pages, elements);
    final doc = pw.Document(creator: 'pdf_esign_app');
    _addContentPages(doc, pages, elements);
    return doc.save();
  }

  /// Full write path: content (pages + user elements) + appended audit page.
  ///
  /// The audit fingerprint is the SHA-256 over a canonical digest of the
  /// signed content (see [contentSha256]) — deterministic and reproducible
  /// from the same pages/elements, which is the value the audit page records.
  Future<SignedPdfResult> composeSignedDocument({
    required List<PdfPageRender> pages,
    List<StampElement> elements = const [],
    required AuditInfo audit,
  }) async {
    _validate(pages, elements);

    final contentBytes =
        await buildContentPdf(pages: pages, elements: elements);
    final contentSha256Hex = contentSha256(pages: pages, elements: elements);
    final actions = audit.customActions ?? _deriveActions(elements);

    final doc = pw.Document(
      title: audit.appName,
      creator: 'pdf_esign_app',
      subject: 'Electronically signed document',
    );
    _addContentPages(doc, pages, elements);
    doc.addPage(_buildAuditPage(audit, contentSha256Hex, actions));
    final finalBytes = await doc.save();

    return SignedPdfResult(
      contentBytes: contentBytes,
      finalBytes: finalBytes,
      contentSha256Hex: contentSha256Hex,
    );
  }

  /// Deterministic SHA-256 fingerprint of the signed content.
  ///
  /// Because the `pdf` library inserts a random document ID on every save, raw
  /// PDF bytes are not reproducible. Instead we hash a canonical, ordered text
  /// digest of what is actually signed — every page (index, size, image hash)
  /// and every placed element (type, normalized rect, text or image hash) — so
  /// the fingerprint changes if and only if the signed content changes, and it
  /// can be recomputed identically at any time from the same inputs.
  String contentSha256({
    required List<PdfPageRender> pages,
    List<StampElement> elements = const [],
  }) {
    final buffer = StringBuffer('pdf-esign/compose/v1\n');
    final orderedPages = [...pages]
      ..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
    for (final p in orderedPages) {
      buffer
        ..write('page\t${p.pageIndex}\t${p.widthPt}\t${p.heightPt}\t')
        ..writeln(sha256.convert(p.imageBytes));
    }
    int compareElements(StampElement a, StampElement b) {
      if (a.pageIndex != b.pageIndex) {
        return a.pageIndex.compareTo(b.pageIndex);
      }
      if (a.normalizedTop != b.normalizedTop) {
        return a.normalizedTop.compareTo(b.normalizedTop);
      }
      return a.normalizedLeft.compareTo(b.normalizedLeft);
    }

    final orderedElements = [...elements]..sort(compareElements);
    for (final e in orderedElements) {
      buffer
        ..write('element\t${e.pageIndex}\t${e.type.name}\t')
        ..write('${e.normalizedLeft}\t${e.normalizedTop}\t')
        ..write('${e.normalizedWidth}\t${e.normalizedHeight}\t');
      switch (e.type) {
        case StampElementType.text:
          buffer.writeln(base64Encode(utf8.encode(e.text ?? '')));
          break;
        case StampElementType.signature:
          buffer.writeln(sha256.convert(e.imageBytes ?? Uint8List(0)));
          break;
      }
    }
    return sha256.convert(utf8.encode(buffer.toString())).toString();
  }

  // ---------------------------------------------------------------------------
  // Content pages
  // ---------------------------------------------------------------------------

  void _addContentPages(
    pw.Document doc,
    List<PdfPageRender> pages,
    List<StampElement> elements,
  ) {
    final byPage = <int, List<StampElement>>{};
    for (final e in elements) {
      byPage.putIfAbsent(e.pageIndex, () => []).add(e);
    }
    final ordered = [...pages]..sort((a, b) => a.pageIndex.compareTo(b.pageIndex));
    for (final page in ordered) {
      doc.addPage(_pageWidget(page, byPage[page.pageIndex] ?? const []));
    }
  }

  pw.Page _pageWidget(PdfPageRender page, List<StampElement> elements) {
    final w = page.widthPt;
    final h = page.heightPt;
    final children = <pw.Widget>[
      // Non-positioned child sized exactly to the page: gives the Stack its
      // size and paints the original page full-bleed (0 margin ⇒ page==content).
      pw.Image(pw.MemoryImage(page.imageBytes), width: w, height: h),
    ];

    for (final e in elements) {
      final left = e.normalizedLeft * w;
      final top = e.normalizedTop * h;
      final boxW = e.normalizedWidth * w;
      final boxH = e.normalizedHeight * h;

      switch (e.type) {
        case StampElementType.text:
          // `pdf`'s Positioned has no width/height: size the box via the four
          // edges (left+right and top+bottom resolve to an explicit box).
          children.add(pw.Positioned(
            left: left,
            right: w - (left + boxW),
            top: top,
            bottom: h - (top + boxH),
            child: pw.Container(
              alignment: pw.Alignment.center,
              child: pw.Text(
                e.text ?? '',
                style: pw.TextStyle(
                  font: pw.Font.helvetica(),
                  fontSize: math.max(1, boxH * e.textScale),
                  color: PdfColor.fromInt(e.textColorArgb),
                ),
              ),
            ),
          ));
          break;
        case StampElementType.signature:
          final bytes = e.imageBytes;
          if (bytes == null) continue;
          final size = pngDimensions(bytes);
          if (size == null) continue; // Not a PNG we can measure: skip safely.
          // Fit the signature inside its box preserving aspect ratio.
          final scale = math.min(boxW / size.width, boxH / size.height);
          final sw = size.width * scale;
          final sh = size.height * scale;
          children.add(pw.Positioned(
            left: left + (boxW - sw) / 2,
            top: top + (boxH - sh) / 2,
            child: pw.Image(pw.MemoryImage(bytes), width: sw, height: sh),
          ));
          break;
      }
    }

    return pw.Page(
      pageFormat: PdfPageFormat(w, h),
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Stack(children: children),
    );
  }

  // ---------------------------------------------------------------------------
  // Audit trail page
  // ---------------------------------------------------------------------------

  List<String> _deriveActions(List<StampElement> elements) {
    return elements.map((e) {
      final page = e.pageIndex + 1; // 1-based for humans
      switch (e.type) {
        case StampElementType.text:
          return 'Text "${e.text}" placed on page $page';
        case StampElementType.signature:
          return 'Signature placed on page $page';
      }
    }).toList();
  }

  String _formatUtc(DateTime utc) {
    final t = utc.toUtc();
    final iso = t.toIso8601String();
    return iso.endsWith('Z') ? iso : '${iso}Z';
  }

  pw.Page _buildAuditPage(
    AuditInfo audit,
    String hashHex,
    List<String> actions,
  ) {
    const margin = 52.0;

    pw.Widget row(String label, String value) => pw.Padding(
          padding: const pw.EdgeInsets.only(bottom: 10),
          child: pw.Row(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.SizedBox(
                width: 150,
                child: pw.Text(
                  label,
                  style: pw.TextStyle(
                    font: pw.Font.helveticaBold(),
                    fontSize: 10,
                    color: PdfColors.grey700,
                  ),
                ),
              ),
              pw.Expanded(
                child: pw.Text(
                  value,
                  style: pw.TextStyle(
                    font: pw.Font.helvetica(),
                    fontSize: 10,
                    color: PdfColors.black,
                  ),
                ),
              ),
            ],
          ),
        );

    return pw.Page(
      pageFormat: PdfPageFormat.letter,
      margin: pw.EdgeInsets.zero,
      build: (_) => pw.Container(
        padding: const pw.EdgeInsets.all(margin),
        child: pw.Column(
          crossAxisAlignment: pw.CrossAxisAlignment.start,
          children: [
            pw.Text(
              'Certificate of Completion',
              style: pw.TextStyle(
                font: pw.Font.helveticaBold(),
                fontSize: 20,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 6),
            pw.Text(
              'Electronically signed document',
              style: pw.TextStyle(
                font: pw.Font.helvetica(),
                fontSize: 12,
                color: PdfColors.grey700,
              ),
            ),
            pw.SizedBox(height: 20),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 16),
            row('Application', audit.appName),
            row('Signed at (UTC)', _formatUtc(audit.signedAtUtc)),
            row('Platform / device', audit.deviceInfo),
            if (audit.userAgent.isNotEmpty) row('User agent', audit.userAgent),
            if (audit.sourceFileName != null &&
                audit.sourceFileName!.isNotEmpty)
              row('Source document', audit.sourceFileName!),
            pw.SizedBox(height: 4),
            pw.Text(
              'Actions recorded',
              style: pw.TextStyle(
                font: pw.Font.helveticaBold(),
                fontSize: 11,
                color: PdfColors.black,
              ),
            ),
            pw.SizedBox(height: 8),
            if (actions.isEmpty)
              row('(none)', 'No elements were placed on this document.')
            else
              ...actions.map(
                (a) => pw.Padding(
                  padding: const pw.EdgeInsets.only(bottom: 6),
                  child: pw.Text(
                    // U+00B7 (middle dot) is present in the core Helvetica
                    // font; U+2022 and smart quotes are not.
                    '·  $a',
                    style: pw.TextStyle(
                      font: pw.Font.helvetica(),
                      fontSize: 10,
                      color: PdfColors.black,
                    ),
                  ),
                ),
              ),
            pw.SizedBox(height: 12),
            pw.Divider(color: PdfColors.grey400),
            pw.SizedBox(height: 16),
            row(
              'Content integrity',
              'SHA-256 fingerprint of the signed content '
                  '(page renders and the placed text/signature elements):',
            ),
            pw.SizedBox(height: 4),
            pw.Container(
              width: double.infinity,
              padding: const pw.EdgeInsets.all(10),
              decoration: pw.BoxDecoration(
                color: PdfColors.grey100,
                border: pw.Border.all(color: PdfColors.grey400),
                borderRadius: pw.BorderRadius.circular(4),
              ),
              child: pw.Text(
                hashHex,
                style: pw.TextStyle(
                  font: pw.Font.helvetica(),
                  fontSize: 10,
                  color: PdfColors.black,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------------
  // Validation
  // ---------------------------------------------------------------------------

  void _validate(List<PdfPageRender> pages, List<StampElement> elements) {
    if (pages.isEmpty) {
      throw ArgumentError('At least one rendered page is required.');
    }
    final knownPages = <int>{};
    for (final p in pages) {
      if (p.widthPt <= 0 || p.heightPt <= 0) {
        throw ArgumentError(
            'Page ${p.pageIndex} must have positive dimensions in points.');
      }
      if (p.imageBytes.isEmpty) {
        throw ArgumentError('Page ${p.pageIndex} has no raster bytes.');
      }
      knownPages.add(p.pageIndex);
    }
    for (final e in elements) {
      final inUnitRange =
          e.normalizedLeft >= 0 &&
              e.normalizedTop >= 0 &&
              e.normalizedWidth > 0 &&
              e.normalizedHeight > 0 &&
              e.normalizedLeft + e.normalizedWidth <= 1.0001 &&
              e.normalizedTop + e.normalizedHeight <= 1.0001;
      if (!inUnitRange) {
        throw ArgumentError(
            'Element on page ${e.pageIndex} must lie within normalized 0..1.');
      }
      if (!knownPages.contains(e.pageIndex)) {
        throw ArgumentError(
            'Element references unknown page ${e.pageIndex}.');
      }
      switch (e.type) {
        case StampElementType.text:
          if (e.text == null || e.text!.isEmpty) {
            throw ArgumentError('A text element requires non-empty text.');
          }
          break;
        case StampElementType.signature:
          if (e.imageBytes == null) {
            throw ArgumentError('A signature element requires PNG bytes.');
          }
          break;
      }
    }
  }
}
