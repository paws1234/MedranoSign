import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_esign_app/features/modifier/modifier_models.dart';
import 'package:pdf_esign_app/features/modifier/pdf_modifier_service.dart';

import '_png_fixtures.dart';

Uint8List _png(String name) => base64Decode(pngFixtures[name]!);

/// Number of page objects (`/Type /Page`, not `/Type /Pages`) in a PDF.
int _pageCount(Uint8List bytes) {
  final s = latin1.decode(bytes);
  return RegExp(r'/Type\s*/Page\b').allMatches(s).length;
}

/// Number of embedded image XObjects (`/Subtype /Image`).
int _imageCount(Uint8List bytes) {
  final s = latin1.decode(bytes);
  return RegExp(r'/Subtype\s*/Image\b').allMatches(s).length;
}

/// Returns the bodies of every stream in the PDF. Each body is kept both as
/// inflated text (when it is a FlateDecode stream) and as raw bytes, so
/// compressed *and* uncompressed content streams are searchable.
List<String> _streamBodies(Uint8List bytes) {
  final s = latin1.decode(bytes);
  final results = <String>[];
  var from = 0;
  while (true) {
    final start = s.indexOf('stream', from);
    if (start < 0) break;
    var dataStart = start + 'stream'.length;
    if (dataStart < s.length && s[dataStart] == '\r') dataStart++;
    if (dataStart < s.length && s[dataStart] == '\n') dataStart++;
    final endIdx = s.indexOf('endstream', dataStart);
    if (endIdx < 0) break;
    final raw = Uint8List.sublistView(bytes, dataStart, endIdx);
    try {
      results.add(latin1.decode(ZLibCodec().decode(raw)));
    } on Exception {
      results.add(latin1.decode(raw));
    }
    from = endIdx + 'endstream'.length;
  }
  return results;
}

void main() {
  const service = PdfModifierService();

  final page0 = PdfPageRender(
    pageIndex: 0,
    widthPt: 612,
    heightPt: 792,
    imageBytes: _png('png320x240'),
  );
  final page1 = PdfPageRender(
    pageIndex: 1,
    widthPt: 595,
    heightPt: 842,
    imageBytes: _png('png64x96'),
  );
  final page2 = PdfPageRender(
    pageIndex: 2,
    widthPt: 300,
    heightPt: 200,
    imageBytes: _png('png48x16'),
  );
  final pages = [page0, page1, page2];

  AuditInfo audit({List<String>? actions}) => AuditInfo(
        signedAtUtc: DateTime.utc(2026, 9, 3, 12, 34, 56),
        deviceInfo: 'Test host · flutter_test',
        appName: 'pdf_esign_app',
        userAgent: 'flutter_test/unit',
        sourceFileName: 'sample.pdf',
        customActions: actions,
      );

  group('pngDimensions', () {
    test('reads width/height from the PNG header', () {
      expect(pngDimensions(_png('png1x1')), const PngSize(1, 1));
      expect(pngDimensions(_png('png64x96')), const PngSize(64, 96));
      expect(pngDimensions(_png('png320x240')), const PngSize(320, 240));
      expect(pngDimensions(_png('png48x16')), const PngSize(48, 16));
    });

    test('returns null for non-PNG / short input', () {
      expect(pngDimensions(Uint8List.fromList([1, 2, 3])), isNull);
      expect(
        pngDimensions(Uint8List.fromList(List.filled(64, 0x00))),
        isNull,
      );
    });
  });

  group('buildContentPdf', () {
    test('produces a valid PDF with one page object per rendered page', () async {
      final bytes = await service.buildContentPdf(pages: pages);
      expect(String.fromCharCodes(bytes.sublist(0, 5)), '%PDF-');
      expect(latin1.decode(bytes), contains('%%EOF'));
      expect(_pageCount(bytes), pages.length);
      // Each rendered page embeds its raster as an image XObject.
      expect(_imageCount(bytes), greaterThanOrEqualTo(pages.length));
    });

    test('adds image XObjects for signature stamps and none for text', () async {
      final sig = StampElement.signature(
        pageIndex: 0,
        normalizedLeft: 0.1,
        normalizedTop: 0.2,
        normalizedWidth: 0.3,
        normalizedHeight: 0.1,
        imageBytes: _png('png64x96'),
      );
      final text = StampElement.text(
        pageIndex: 1,
        normalizedLeft: 0.1,
        normalizedTop: 0.1,
        normalizedWidth: 0.5,
        normalizedHeight: 0.05,
        text: 'Approved by QA',
      );

      final baseline = await service.buildContentPdf(pages: pages);
      final withText = await service.buildContentPdf(
        pages: pages,
        elements: [text],
      );
      final withSig = await service.buildContentPdf(
        pages: pages,
        elements: [sig],
      );

      expect(_imageCount(withText), _imageCount(baseline));
      expect(_imageCount(withSig), greaterThan(_imageCount(baseline)));
    });

    test('is reproducible and content-sensitive via canonical fingerprint',
        () async {
      final elements = [
        StampElement.text(
          pageIndex: 0,
          normalizedLeft: 0.2,
          normalizedTop: 0.3,
          normalizedWidth: 0.4,
          normalizedHeight: 0.1,
          text: 'Deterministic',
        ),
      ];
      // Same inputs → identical fingerprint regardless of PDF serialization
      // (the `pdf` package randomizes the document ID on every save).
      final first = await service.buildContentPdf(
        pages: pages,
        elements: elements,
      );
      final second = await service.buildContentPdf(
        pages: pages,
        elements: elements,
      );
      expect(_pageCount(first), pages.length);
      expect(_pageCount(second), pages.length);
      expect(
        service.contentSha256(pages: pages, elements: elements),
        service.contentSha256(pages: pages, elements: elements),
      );

      // Changing the text changes the fingerprint.
      final changed = [
        StampElement.text(
          pageIndex: 0,
          normalizedLeft: 0.2,
          normalizedTop: 0.3,
          normalizedWidth: 0.4,
          normalizedHeight: 0.1,
          text: 'Different text',
        ),
      ];
      expect(
        service.contentSha256(pages: pages, elements: changed),
        isNot(service.contentSha256(pages: pages, elements: elements)),
      );
    });
  });

  group('composeSignedDocument', () {
    test('appends exactly one audit page and records a content hash', () async {
      final elements = [
        StampElement.text(
          pageIndex: 0,
          normalizedLeft: 0.15,
          normalizedTop: 0.15,
          normalizedWidth: 0.4,
          normalizedHeight: 0.06,
          text: 'Signed field',
        ),
        StampElement.signature(
          pageIndex: 0,
          normalizedLeft: 0.6,
          normalizedTop: 0.6,
          normalizedWidth: 0.25,
          normalizedHeight: 0.12,
          imageBytes: _png('png48x16'),
        ),
      ];

      final result = await service.composeSignedDocument(
        pages: pages,
        elements: elements,
        audit: audit(),
      );

      expect(
        result.contentSha256Hex,
        service.contentSha256(pages: pages, elements: elements),
      );
      expect(_pageCount(result.contentBytes), pages.length);
      expect(_pageCount(result.finalBytes), pages.length + 1);
      expect(result.finalBytes, isNot(equals(result.contentBytes)));
      expect(String.fromCharCodes(result.finalBytes.sublist(0, 5)), '%PDF-');
    });

    test('audit page contains timestamp, device info and the content hash',
        () async {
      final result = await service.composeSignedDocument(
        pages: pages,
        elements: [
          StampElement.signature(
            pageIndex: 1,
            normalizedLeft: 0.3,
            normalizedTop: 0.3,
            normalizedWidth: 0.2,
            normalizedHeight: 0.1,
            imageBytes: _png('png64x96'),
          ),
        ],
        audit: audit(),
      );

      final streams = _streamBodies(result.finalBytes);
      // The `pdf` library splits text into per-word tokens (TJ arrays), so
      // assert on contiguous tokens rather than whole sentences.
      final auditBodies =
          streams.where((s) => s.contains('Certificate'));
      expect(auditBodies, isNotEmpty,
          reason: 'final document should contain an audit-trail page');

      final text = auditBodies.first;
      expect(text, contains('Completion'));
      expect(text, contains(result.contentSha256Hex));
      expect(text, contains('2026-09-03T12:34:56.000Z'));
      expect(text, contains('flutter_test'));
      expect(text, contains('pdf_esign_app'));
      expect(text, contains('Signature'));

      // The signed content itself must NOT contain the audit marker.
      final contentStreams = _streamBodies(result.contentBytes);
      expect(
        contentStreams.where((s) => s.contains('Certificate')),
        isEmpty,
      );
    });
  });

  group('validation', () {
    test('rejects an empty page list', () async {
      expect(
        () => service.buildContentPdf(pages: const []),
        throwsArgumentError,
      );
    });

    test('rejects elements referencing unknown pages', () async {
      final bad = StampElement.text(
        pageIndex: 7,
        normalizedLeft: 0.1,
        normalizedTop: 0.1,
        normalizedWidth: 0.2,
        normalizedHeight: 0.1,
        text: 'x',
      );
      expect(
        () => service.buildContentPdf(pages: pages, elements: [bad]),
        throwsArgumentError,
      );
    });

    test('rejects out-of-range normalized coordinates', () async {
      final bad = StampElement.text(
        pageIndex: 0,
        normalizedLeft: 0.9,
        normalizedTop: 0.1,
        normalizedWidth: 0.2, // 0.9 + 0.2 > 1
        normalizedHeight: 0.1,
        text: 'x',
      );
      expect(
        () => service.buildContentPdf(pages: pages, elements: [bad]),
        throwsArgumentError,
      );
    });

    test('rejects text elements without content', () async {
      expect(
        () => StampElement.text(
          pageIndex: 0,
          normalizedLeft: 0.1,
          normalizedTop: 0.1,
          normalizedWidth: 0.2,
          normalizedHeight: 0.1,
          text: '',
        ),
        throwsAssertionError,
      );
    });
  });
}
