import 'dart:async';
import 'dart:typed_data';
import 'dart:ui';

import 'package:flutter/widgets.dart'
    show ImageConfiguration, ImageProvider, ImageStreamListener;

import 'package:pdf/widgets.dart' as pw show ImageProvider, RawImage;

extension ImageProviderConverter on ImageProvider {
  Future<pw.ImageProvider> toPdfImageProvider() async {
    final MapEntry<Uint8List?, Size> tuple = await getBytes();

    return pw.RawImage(
      bytes: tuple.key!,
      width: tuple.value.width.toInt(),
      height: tuple.value.height.toInt(),
    );
  }

  /// Resolves the [ImageProvider]´s bytes
  /// and returns the bytes together with their [Size].
  ///
  /// Defaults to straight alpha because [pw.RawImage] splits the alpha into
  /// a soft mask and keeps the color channels as they are. Premultiplied
  /// [ImageByteFormat.rawRgba] bytes get their alpha applied a second time
  /// when the viewer composites the mask, so every semi-transparent pixel
  /// (a cut-out headshot, an icon's antialiased edge) comes out too dark.
  ///
  /// Load and decode errors propagate to the caller. [timeout] also bounds
  /// providers that never deliver an image or an error, so export can finish.
  Future<MapEntry<Uint8List?, Size>> getBytes({
    ImageByteFormat format = ImageByteFormat.rawStraightRgba,
    Duration timeout = const Duration(seconds: 30),
  }) async {
    final imageStream = resolve(ImageConfiguration.empty);
    final completer = Completer<MapEntry<Uint8List?, Size>>();
    void completeError(Object error, StackTrace? stack) {
      if (!completer.isCompleted) {
        completer.completeError(error, stack);
      }
    }

    final ImageStreamListener listener = ImageStreamListener((
      imageInfo,
      synchronousCall,
    ) async {
      try {
        final size = Size(
          imageInfo.image.width.toDouble(),
          imageInfo.image.height.toDouble(),
        );
        final bytes = await imageInfo.image.toByteData(format: format);
        if (bytes == null) {
          throw StateError('Image returned no pixel data during PDF export.');
        }
        if (!completer.isCompleted) {
          completer.complete(MapEntry(bytes.buffer.asUint8List(), size));
        }
      } catch (error, stack) {
        completeError(error, stack);
      } finally {
        imageInfo.dispose();
      }
    }, onError: completeError);

    try {
      imageStream.addListener(listener);
      return await completer.future.timeout(timeout);
    } finally {
      imageStream.removeListener(listener);
    }
  }
}
