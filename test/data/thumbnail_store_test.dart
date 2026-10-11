import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter_test/flutter_test.dart';
import 'package:openrdc/data/storage_paths.dart';
import 'package:openrdc/data/thumbnail_store.dart';
import 'package:openrdc/engine/rdc_engine.dart';

void main() {
  // Decoding and encoding go through the engine, so the binding has to exist
  // before the first save.
  TestWidgetsFlutterBinding.ensureInitialized();

  late Directory tempDir;
  late ThumbnailStore store;

  setUp(() async {
    tempDir = await Directory.systemTemp.createTemp('openrdc_thumbnail_test');
    store = ThumbnailStore(StoragePaths.forDirectory(tempDir));
  });

  tearDown(() async {
    if (tempDir.existsSync()) {
      await tempDir.delete(recursive: true);
    }
  });

  /// A frame of [width] x [height] filled with one colour. Only its geometry
  /// matters here: nothing is asserted about the pixels, because the point of
  /// the preview is that it looks like the desktop, which no test can see.
  RdcFrame frame(int width, int height) {
    final pixels = Uint8List(width * height * 4);
    for (var i = 0; i < pixels.length; i += 4) {
      pixels[i] = 40;
      pixels[i + 1] = 80;
      pixels[i + 2] = 120;
      pixels[i + 3] = 255;
    }
    return RdcFrame(width: width, height: height, pixels: pixels);
  }

  testWidgets('writes a preview scaled to the store width', (tester) async {
    final saved = await tester.runAsync(
      () => store.save('pc', frame(1920, 1080)),
    );
    expect(saved, isTrue);

    final file = File(store.pathFor('pc'));
    expect(file.existsSync(), isTrue);

    final image = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(await file.readAsBytes());
      final decoded = await codec.getNextFrame();
      return decoded.image;
    });
    expect(image, isNotNull);
    expect(image!.width, ThumbnailStore.width);
    // The proportions of the desktop are kept, so a card shows a screen rather
    // than a square.
    expect(
      image.height,
      (ThumbnailStore.width * 1080 / 1920).round(),
    );
    image.dispose();
  });

  testWidgets('keeps a portrait desktop portrait', (tester) async {
    await tester.runAsync(() => store.save('pc', frame(1080, 1920)));

    final image = await tester.runAsync(() async {
      final codec = await ui.instantiateImageCodec(
        await File(store.pathFor('pc')).readAsBytes(),
      );
      return (await codec.getNextFrame()).image;
    });
    expect(image!.height, greaterThan(image.width));
    image.dispose();
  });

  testWidgets('replaces the previous preview of the same connection', (
    tester,
  ) async {
    await tester.runAsync(() => store.save('pc', frame(4, 4)));
    final first = File(store.pathFor('pc')).lengthSync();

    await tester.runAsync(() => store.save('pc', frame(64, 32)));
    expect(File(store.pathFor('pc')).lengthSync(), isNot(first));
  });

  testWidgets('a degenerate frame is refused rather than written', (
    tester,
  ) async {
    final saved = await tester.runAsync(
      () => store.save('pc', frame(0, 0)),
    );

    expect(saved, isFalse);
    expect(File(store.pathFor('pc')).existsSync(), isFalse);
  });
}
