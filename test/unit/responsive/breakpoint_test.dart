import 'package:flutter_test/flutter_test.dart';

import 'package:pdf_esign_app/core/responsive/breakpoint.dart';

void main() {
  group('breakpointOfWidth', () {
    test('classifies the documented sample widths 400 / 800 / 1200', () {
      expect(breakpointOfWidth(400), Breakpoint.mobile);
      expect(breakpointOfWidth(800), Breakpoint.tablet);
      expect(breakpointOfWidth(1200), Breakpoint.desktop);
    });

    test('mobile is any width below 600 px', () {
      expect(breakpointOfWidth(0), Breakpoint.mobile);
      expect(breakpointOfWidth(359), Breakpoint.mobile);
      expect(breakpointOfWidth(599), Breakpoint.mobile);
    });

    test('tablet spans 600..1024 px inclusive', () {
      expect(breakpointOfWidth(600), Breakpoint.tablet);
      expect(breakpointOfWidth(768), Breakpoint.tablet);
      expect(breakpointOfWidth(1024), Breakpoint.tablet);
    });

    test('desktop is any width above 1024 px', () {
      expect(breakpointOfWidth(1025), Breakpoint.desktop);
      expect(breakpointOfWidth(1440), Breakpoint.desktop);
      expect(breakpointOfWidth(2560), Breakpoint.desktop);
    });
  });
}
