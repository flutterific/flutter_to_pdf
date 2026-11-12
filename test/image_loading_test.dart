import 'dart:async';
import 'dart:typed_data';

import 'package:flutter/foundation.dart' show SynchronousFuture;
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_to_pdf/args/image_provider.dart';
import 'package:flutter_to_pdf/flutter_to_pdf.dart';

class _ControlledImageProvider extends ImageProvider<Object> {
  final result = Completer<ImageInfo>();
  late final completer = OneFrameImageStreamCompleter(result.future);

  @override
  void resolveStreamForKey(
    ImageConfiguration configuration,
    ImageStream stream,
    Object key,
    ImageErrorListener handleError,
  ) {
    stream.setCompleter(completer);
  }

  @override
  Future<Object> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture(this);
}

void main() {
  testWidgets('missing asset fails instead of hanging', (tester) async {
    await tester.runAsync(() async {
      await expectLater(
        const AssetImage('missing-pdf-image.png')
            .toPdfImageProvider()
            .timeout(const Duration(seconds: 2)),
        throwsA(isA<FlutterError>()),
      );
    });
  });

  testWidgets('PDF export fails even when preview hides a corrupt image', (
    tester,
  ) async {
    final delegate = ExportDelegate();
    final provider = MemoryImage(Uint8List.fromList([0, 1, 2, 3]));
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: ExportFrame(
          frameId: 'broken-image',
          exportDelegate: delegate,
          child: Image(
            image: provider,
            errorBuilder: (_, __, ___) => const SizedBox.shrink(),
          ),
        ),
      ),
    );

    await tester.runAsync(() async {
      await expectLater(
        delegate
            .exportToPdfWidget('broken-image')
            .timeout(const Duration(seconds: 2)),
        throwsA(isNot(isA<TimeoutException>())),
      );
    });
  });

  testWidgets('image errors propagate and release the listener', (
    tester,
  ) async {
    final provider = _ControlledImageProvider();
    final error = StateError('Image load failed');
    final expectation = expectLater(provider.getBytes(), throwsA(same(error)));
    expect(provider.completer.hasListeners, isTrue);

    provider.result.completeError(error);
    await expectation;
    expect(provider.completer.hasListeners, isFalse);
  });

  testWidgets('stalled images time out and release the listener', (
    tester,
  ) async {
    final provider = _ControlledImageProvider();
    final expectation = expectLater(
      provider.getBytes(timeout: const Duration(seconds: 1)),
      throwsA(isA<TimeoutException>()),
    );
    expect(provider.completer.hasListeners, isTrue);

    await tester.pump(const Duration(seconds: 1));
    await expectation;
    expect(provider.completer.hasListeners, isFalse);
  });
}
