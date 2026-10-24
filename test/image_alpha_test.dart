import 'dart:async';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_to_pdf/args/image_provider.dart';

void main() {
  testWidgets('getBytes returns straight alpha for pw.RawImage',
      (tester) async {
    await tester.runAsync(() async {
      // One light-blue pixel, straight (107, 190, 255) at alpha 43, as in a
      // soft-edged avatar. decodeImageFromPixels takes premultiplied input.
      final pixels = Uint8List.fromList([18, 32, 43, 43]);
      final completer = Completer<ui.Image>();
      ui.decodeImageFromPixels(
          pixels, 1, 1, ui.PixelFormat.rgba8888, completer.complete);
      final image = await completer.future;
      final png = await image.toByteData(format: ui.ImageByteFormat.png);

      final bytes =
          (await MemoryImage(png!.buffer.asUint8List()).getBytes()).key!;

      // Premultiplied bytes would read (18, 32, 43, 43).
      expect(bytes[3], 43);
      expect(bytes[0], closeTo(107, 2));
      expect(bytes[1], closeTo(190, 2));
      expect(bytes[2], closeTo(255, 2));
    });
  });
}
