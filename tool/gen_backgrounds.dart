import 'dart:io';
import 'dart:math' as math;

import 'package:image/image.dart' as img;

void main() {
  Directory('assets/backgrounds').createSync(recursive: true);
  _write('carbon_weave.png', _carbon());
  _write('brushed_metal.png', _brushed());
  _write('night_noise.png', _noise());
  _write('hud_grid.png', _grid());
  _write('garage_concrete.png', _concrete());
  _write('diagonal_carbon.png', _diagonal());
  stdout.writeln('Background textures written.');
}

void _write(String name, img.Image image) {
  File('assets/backgrounds/$name').writeAsBytesSync(img.encodePng(image));
}

img.Image _carbon() {
  final im = img.Image(width: 256, height: 256);
  for (var y = 0; y < 256; y++) {
    for (var x = 0; x < 256; x++) {
      final cell = ((x ~/ 8) + (y ~/ 8)) % 2;
      final weave = ((x + y * 2) % 16) < 8 ? 1 : 0;
      final v = 18 + cell * 10 + weave * 6 + ((x * 13 + y * 7) % 5);
      im.setPixelRgba(x, y, v, v + 2, v + 6, 255);
    }
  }
  return im;
}

img.Image _brushed() {
  final im = img.Image(width: 256, height: 256);
  final rnd = math.Random(42);
  for (var y = 0; y < 256; y++) {
    final base = 28 + (y % 7);
    for (var x = 0; x < 256; x++) {
      final n = base + rnd.nextInt(12);
      im.setPixelRgba(x, y, n, n + 2, n + 4, 255);
    }
  }
  return im;
}

img.Image _noise() {
  final im = img.Image(width: 256, height: 256);
  final rnd = math.Random(7);
  for (var y = 0; y < 256; y++) {
    for (var x = 0; x < 256; x++) {
      final n = 10 + rnd.nextInt(28);
      final blue = n + 8;
      im.setPixelRgba(x, y, n, n + 2, blue, 255);
    }
  }
  return im;
}

img.Image _grid() {
  final im = img.Image(width: 256, height: 256);
  for (var y = 0; y < 256; y++) {
    for (var x = 0; x < 256; x++) {
      final line = x % 24 == 0 || y % 24 == 0;
      final v = line ? 48 : 14;
      final b = line ? 90 : 22;
      im.setPixelRgba(x, y, v, v + 4, b, 255);
    }
  }
  return im;
}

img.Image _concrete() {
  final im = img.Image(width: 256, height: 256);
  final rnd = math.Random(99);
  for (var y = 0; y < 256; y++) {
    for (var x = 0; x < 256; x++) {
      final n = 22 + rnd.nextInt(18) + ((x ~/ 32 + y ~/ 32) % 3) * 3;
      im.setPixelRgba(x, y, n, n, n + 2, 255);
    }
  }
  return im;
}

img.Image _diagonal() {
  final im = img.Image(width: 256, height: 256);
  for (var y = 0; y < 256; y++) {
    for (var x = 0; x < 256; x++) {
      final d = (x + y) % 10;
      final v = d < 4 ? 16 : (d < 7 ? 28 : 20);
      im.setPixelRgba(x, y, v, v + 1, v + 4, 255);
    }
  }
  return im;
}
