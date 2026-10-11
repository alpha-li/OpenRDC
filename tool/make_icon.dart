// Generates the OpenRDC application icon from a single geometric definition.
//
// Run from the repository root:
//
//   dart run tool/make_icon.dart
//
// It writes two committed files:
//
//   windows/runner/resources/app_icon.ico   what Windows actually loads
//   windows/runner/resources/app_icon.svg   the same icon as vector art
//
// The .ico is embedded in the executable by Runner.rc (IDI_APP_ICON) and handed
// to the window class by win32_window.cpp, so it is what the title bar, the
// taskbar and Alt+Tab show. Windows cannot load an SVG, which is why the icon
// exists twice -- but only once as a design: `_shapes` below is the source of
// truth for both outputs, so they cannot drift apart.
//
//   dart run tool/make_icon.dart --preview
//
// additionally writes build/icon_preview.png: every size, on light and dark
// backgrounds, for judging the small entries without building the application.
import 'dart:io';
import 'dart:typed_data';

import 'package:image/image.dart' as img;

/// The design box. Every coordinate below is in these units, which is also the
/// SVG's viewBox, so the two outputs are directly comparable.
const int _designExtent = 256;

/// Drawn once at this size and scaled down. Large enough that the 16px entry is
/// an average of many samples rather than a guess.
const int _masterExtent = 1024;

/// Every size Windows asks for. 16 is the taskbar, 32 the Alt+Tab switcher and
/// the small Explorer views, 256 the extra-large one.
const List<int> _sizes = [16, 24, 32, 48, 64, 128, 256];

/// The WinUI accent from lib/theme/fluent_colors.dart, so the icon and the
/// application it belongs to are the same blue.
const int _accent = 0x005FB8;
const int _glyph = 0xFFFFFF;

/// One rounded rectangle of the drawing, back to front.
class _Shape {
  const _Shape(this.x, this.y, this.width, this.height, this.radius, this.color);

  final num x;
  final num y;
  final num width;
  final num height;
  final num radius;
  final int color;
}

/// The icon: a monitor on a rounded tile, and nothing else.
///
/// At 16px -- the size that matters most, because that is the taskbar -- any
/// further detail turns to mud. The screen is left the colour of the tile so the
/// monitor reads as a crisp white outline at every size, which is the one
/// feature that survives the downscale.
///
/// The proportions are deliberate: 16 units of bezel all round, 40 units of tile
/// either side of the monitor, and the same 51 units above the monitor as below
/// the stand, so the glyph sits centred rather than floating.
///
/// A second, smaller screen nested inside the first was tried, to say "remote"
/// rather than merely "desktop". It reads well at 256px but turns into a smudge
/// inside the screen by 32px, so it was dropped: the monitor is the glyph every
/// remote desktop client is drawn with, and it stays legible at every size.
const List<_Shape> _shapes = [
  _Shape(0, 0, 256, 256, 56, _accent), // the tile
  _Shape(40, 51, 176, 112, 16, _glyph), // monitor bezel
  _Shape(56, 67, 144, 80, 8, _accent), // screen
  _Shape(116, 163, 24, 26, 0, _glyph), // neck
  _Shape(84, 189, 88, 16, 8, _glyph), // base
];

/// Above this size the .ico entries are PNG, below it they are DIB.
///
/// This is what icon editors produce and for the same reasons: a DIB is exact
/// and universally readable at the sizes every Windows version has always
/// drawn, while PNG keeps the 256px entry from costing a quarter of a megabyte.
const int _pngFromSize = 128;

void main(List<String> arguments) {
  final root = Directory.current;
  final resources = Directory('${root.path}/windows/runner/resources');
  if (!resources.existsSync()) {
    stderr.writeln(
      'Run this from the repository root: windows/runner/resources was not '
      'found under ${root.path}',
    );
    exitCode = 1;
    return;
  }

  final master = _render();
  final icons = <int, img.Image>{
    for (final size in _sizes)
      size: size == _masterExtent
          ? master
          : img.copyResize(
              master,
              width: size,
              height: size,
              interpolation: img.Interpolation.average,
            ),
  };

  final icoBytes = _encodeIco({
    for (final size in _sizes) size: icons[size]!,
  });
  final icoFile = File('${resources.path}/app_icon.ico')
    ..writeAsBytesSync(icoBytes);

  final svgFile = File('${resources.path}/app_icon.svg')
    ..writeAsStringSync(_svg());

  _verify(icoFile);

  stdout.writeln('wrote ${icoFile.path} (${_sizes.join(', ')} px)');
  stdout.writeln('wrote ${svgFile.path}');

  if (arguments.contains('--preview')) {
    final preview = File('${root.path}/build/icon_preview.png')
      ..createSync(recursive: true)
      ..writeAsBytesSync(_preview(icons));
    stdout.writeln('wrote ${preview.path}');
  }
}

// ---------------------------------------------------------------------------
// Drawing
// ---------------------------------------------------------------------------

img.ColorRgba8 _rgba(int rgb, [int alpha = 255]) => img.ColorRgba8(
  (rgb >> 16) & 0xFF,
  (rgb >> 8) & 0xFF,
  rgb & 0xFF,
  alpha,
);

img.Image _render() {
  // Transparent areas are filled with the tile's colour at zero alpha rather
  // than with transparent black. The downscale below averages colour and alpha
  // independently, so black corners would bleed a dark fringe around the tile's
  // rounded corners; blue ones composite cleanly onto whatever is behind them.
  final image = img.Image(width: _masterExtent, height: _masterExtent, numChannels: 4);
  img.fill(image, color: _rgba(_accent, 0));

  const scale = _masterExtent / _designExtent;
  for (final shape in _shapes) {
    // fillRect's corners are inclusive, hence the -1: without it every shape
    // would be a master pixel wider than it is tall.
    img.fillRect(
      image,
      x1: (shape.x * scale).round(),
      y1: (shape.y * scale).round(),
      x2: ((shape.x + shape.width) * scale).round() - 1,
      y2: ((shape.y + shape.height) * scale).round() - 1,
      radius: shape.radius * scale,
      color: _rgba(shape.color),
    );
  }
  return image;
}

String _svg() {
  String number(num value) =>
      value == value.roundToDouble() ? value.round().toString() : '$value';

  final shapes = _shapes
      .map(
        (shape) => '  <rect x="${number(shape.x)}" y="${number(shape.y)}" '
            'width="${number(shape.width)}" height="${number(shape.height)}"'
            '${shape.radius > 0 ? ' rx="${number(shape.radius)}"' : ''} '
            'fill="#${shape.color.toRadixString(16).padLeft(6, '0').toUpperCase()}"/>',
      )
      .join('\n');

  return '''
<?xml version="1.0" encoding="UTF-8"?>
<!-- Generated by tool/make_icon.dart. Change the geometry there, not here. -->
<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 $_designExtent $_designExtent"
     width="$_designExtent" height="$_designExtent" role="img">
  <title>OpenRDC</title>
  <desc>A monitor on a rounded blue tile.</desc>
$shapes
</svg>
''';
}

// ---------------------------------------------------------------------------
// ICO container
// ---------------------------------------------------------------------------

Uint8List _encodeIco(Map<int, img.Image> icons) {
  final sizes = icons.keys.toList()..sort();
  final entries = <Uint8List>[];
  final payloads = <Uint8List>[];

  for (final size in sizes) {
    final image = icons[size]!;
    final payload = size >= _pngFromSize
        ? Uint8List.fromList(img.encodePng(image))
        : _encodeDib(image);
    payloads.add(payload);

    final entry = ByteData(16)
      // 0 means 256: the directory stores a size in one byte.
      ..setUint8(0, size == 256 ? 0 : size)
      ..setUint8(1, size == 256 ? 0 : size)
      ..setUint8(2, 0) // palette size, 0 for true colour
      ..setUint8(3, 0) // reserved
      ..setUint16(4, 1, Endian.little) // colour planes
      ..setUint16(6, 32, Endian.little) // bits per pixel
      ..setUint32(8, payload.length, Endian.little);
    entries.add(entry.buffer.asUint8List());
  }

  final header = ByteData(6)
    ..setUint16(0, 0, Endian.little) // reserved
    ..setUint16(2, 1, Endian.little) // 1 = icon, 2 = cursor
    ..setUint16(4, sizes.length, Endian.little);

  // The payloads start after the header and the whole directory, and the
  // directory entries have to say where; so the offsets are filled in once the
  // directory's own size is known.
  var offset = 6 + entries.length * 16;
  for (var i = 0; i < entries.length; i++) {
    ByteData.view(entries[i].buffer).setUint32(12, offset, Endian.little);
    offset += payloads[i].length;
  }

  final out = BytesBuilder(copy: false)..add(header.buffer.asUint8List());
  for (final entry in entries) {
    out.add(entry);
  }
  for (final payload in payloads) {
    out.add(payload);
  }
  return out.toBytes();
}

/// Encodes one image as a DIB: a BITMAPINFOHEADER, bottom-up BGRA rows, then the
/// 1bpp AND mask every reader expects even when the alpha channel is what
/// actually decides what is drawn.
Uint8List _encodeDib(img.Image image) {
  final width = image.width;
  final height = image.height;
  final maskStride = ((width + 31) ~/ 32) * 4;
  final xorLength = width * height * 4;
  final maskLength = maskStride * height;

  final out = BytesBuilder(copy: false);
  out.add(
    (ByteData(40)
          ..setUint32(0, 40, Endian.little) // header size
          ..setInt32(4, width, Endian.little)
          // Twice the height: the DIB holds the colour rows and the mask rows.
          ..setInt32(8, height * 2, Endian.little)
          ..setUint16(12, 1, Endian.little) // planes
          ..setUint16(14, 32, Endian.little) // bits per pixel
          ..setUint32(16, 0, Endian.little) // BI_RGB, uncompressed
          ..setUint32(20, xorLength, Endian.little)
          ..setInt32(24, 0, Endian.little) // pixels per metre, unused
          ..setInt32(28, 0, Endian.little)
          ..setUint32(32, 0, Endian.little) // palette entries used
          ..setUint32(36, 0, Endian.little)) // palette entries required
        .buffer
        .asUint8List(),
  );

  final xor = Uint8List(xorLength);
  final mask = Uint8List(maskLength);
  var index = 0;
  // Both blocks are stored bottom-up, while the source image is top-down.
  for (var y = height - 1; y >= 0; y--) {
    final maskRow = (height - 1 - y) * maskStride;
    for (var x = 0; x < width; x++) {
      final pixel = image.getPixel(x, y);
      xor[index++] = pixel.b.toInt();
      xor[index++] = pixel.g.toInt();
      xor[index++] = pixel.r.toInt();
      xor[index++] = pixel.a.toInt();
      if (pixel.a < 128) {
        mask[maskRow + (x >> 3)] |= 0x80 >> (x & 7);
      }
    }
  }

  out.add(xor);
  out.add(mask);
  return out.toBytes();
}

/// Reads the file back and checks it holds what was asked for. Without this the
/// failure mode is a build that succeeds and an icon that is simply missing or
/// mis-scaled, which nothing else here would notice.
void _verify(File file) {
  final decoded = img.decodeIco(file.readAsBytesSync());
  if (decoded == null) {
    stderr.writeln('${file.path} does not decode as an ICO');
    exitCode = 1;
    return;
  }

  final found = <int>[];
  for (var frame = 0; frame < decoded.numFrames; frame++) {
    final image = img.decodeIco(file.readAsBytesSync(), frame: frame);
    if (image == null) {
      stderr.writeln('${file.path} entry $frame does not decode');
      exitCode = 1;
      return;
    }
    found.add(image.width);
  }

  if (found.join(',') != _sizes.join(',')) {
    stderr.writeln(
      '${file.path} holds ${found.join(', ')} px, expected ${_sizes.join(', ')}',
    );
    exitCode = 1;
  }
}

// ---------------------------------------------------------------------------
// Preview sheet
// ---------------------------------------------------------------------------

/// The sizes at 1:1 on light and dark rows, plus the smallest few blown up with
/// no interpolation, since that is the only way to see what the taskbar is
/// actually given.
Uint8List _preview(Map<int, img.Image> icons) {
  const padding = 12;
  final sheet = img.Image(width: 660, height: 832, numChannels: 4);
  img.fill(sheet, color: _rgba(0xF3F3F3));

  // Two rows of the sizes as Windows draws them -- one on a light background,
  // one on a dark -- with room for the largest entry in each.
  for (final (top, background) in const [(padding, 0xF3F3F3), (288, 0x1F1F1F)]) {
    var x = padding;
    for (final size in _sizes) {
      // A swatch behind each icon, so the rounded corners and the anti-aliased
      // edges are judged against something rather than against transparency.
      img.fillRect(
        sheet,
        x1: x,
        y1: top,
        x2: x + size,
        y2: top + size,
        color: _rgba(background),
      );
      img.compositeImage(sheet, icons[size]!, dstX: x, dstY: top);
      x += size + 8;
    }
  }

  // The three smallest, magnified eightfold with no interpolation: this is what
  // tells whether the outline survives at taskbar size.
  var x = padding;
  for (final size in const [16, 24, 32]) {
    final magnified = img.copyResize(
      icons[size]!,
      width: size * 8,
      height: size * 8,
      interpolation: img.Interpolation.nearest,
    );
    img.compositeImage(sheet, magnified, dstX: x, dstY: 564);
    x += size * 8 + 8;
  }

  return Uint8List.fromList(img.encodePng(sheet));
}
