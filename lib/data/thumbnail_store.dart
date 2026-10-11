/// Session previews: the picture a saved PC shows once it has been connected to.
///
/// The Windows App puts a frame of the last session on the card, and that is
/// what this is: one screenshot, taken a little after the desktop comes up, kept
/// as a PNG next to the connections. Nothing about it is precious -- a stale or
/// missing one falls back to the generic artwork -- so failures are reported and
/// then forgotten rather than surfaced.
library;

import 'dart:async';
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/painting.dart';

import '../engine/rdc_engine.dart';
import 'storage_paths.dart';

/// Writes and locates the per-connection session preview.
class ThumbnailStore {
  ThumbnailStore(this.paths);

  final StoragePaths paths;

  /// Width the preview is scaled to. The card artwork is around 300 logical
  /// pixels wide, so this is a little more than it will ever be drawn at, and
  /// far less than the desktop it came from: encoding a full-resolution frame
  /// would cost a visible stall for pixels nobody sees.
  static const int width = 320;

  /// Where the preview for [connectionId] belongs, whether or not one exists.
  String pathFor(String connectionId) => paths.thumbnailFor(connectionId);

  /// Encodes [frame] and writes it as the preview for [connectionId].
  ///
  /// Returns false when the frame could not be turned into a picture or the
  /// file could not be written; the caller is expected to carry on either way.
  Future<bool> save(String connectionId, RdcFrame frame) async {
    if (frame.width <= 0 || frame.height <= 0) {
      return false;
    }

    ui.Image? full;
    ui.Image? scaled;
    try {
      full = await _decode(frame);
      scaled = await _scale(full);

      final data = await scaled.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) {
        return false;
      }

      await paths.ensureExists();
      final file = File(pathFor(connectionId));
      await file.writeAsBytes(data.buffer.asUint8List(), flush: true);

      // The image cache is keyed by path and scale alone, so the card would go
      // on showing the previous session's preview until something evicted this.
      PaintingBinding.instance.imageCache.evict(FileImage(file));
      return true;
    } on Object {
      // A preview is a nicety; the connection it belongs to is not.
      return false;
    } finally {
      full?.dispose();
      scaled?.dispose();
    }
  }

  Future<ui.Image> _decode(RdcFrame frame) {
    final completer = Completer<ui.Image>();
    ui.decodeImageFromPixels(
      frame.pixels,
      frame.width,
      frame.height,
      ui.PixelFormat.rgba8888,
      completer.complete,
    );
    return completer.future;
  }

  /// Scales the frame down, keeping its proportions. A desktop wider than it is
  /// tall stays that way, which is what makes the card look like a screen rather
  /// than a square.
  Future<ui.Image> _scale(ui.Image source) {
    final height = (width * source.height / source.width).round().clamp(1, 4096);
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    canvas.drawImageRect(
      source,
      ui.Rect.fromLTWH(0, 0, source.width.toDouble(), source.height.toDouble()),
      ui.Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
      ui.Paint()..filterQuality = ui.FilterQuality.medium,
    );
    final picture = recorder.endRecording();
    try {
      return picture.toImage(width, height);
    } finally {
      picture.dispose();
    }
  }
}
