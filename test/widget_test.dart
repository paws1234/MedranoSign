// Basic app-level smoke test: the app boots into the responsive shell
// (Task 03) without layout errors.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_esign_app/app.dart';

void main() {
  testWidgets('App boots to the responsive shell without errors', (
    WidgetTester tester,
  ) async {
    await tester.pumpWidget(const ProviderScope(child: PdfEsignApp()));
    await tester.pumpAndSettle();

    expect(find.byType(MaterialApp), findsOneWidget);
    expect(find.text('PDF e-Sign'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
