// Pixel-art / 8-bit asset generator for the Drive Studio premium widget
// bundle. Every visual element is rendered as a grid of small filled
// squares ("pixels") — chunky, anti-aliasing-free, deliberately hand-
// crafted per design. The goal is to look like a small ROM-art kit:
// sharp edges, distinctive silhouettes, decorative chevrons, brackets,
// pips and tickmarks.
//
// Coordinate system inside each painter:
//   x and y are integers in the pixel grid. The "size" of one pixel in
//   logical points is set per-painter (_ps). All drawings compose by
//   stamping `_px(x, y, color)` calls; the painter multiplies by `_ps`
//   internally before drawing the fillRect onto the canvas.
//
// Output pipeline: paint -> PictureRecorder -> ui.Image (size*pixelRatio)
// -> PNG bytes. Identical to RepaintBoundary.toImage but callable outside
// a widget tree (for `flutter test`, background isolates, etc.).
//
// Caching: every public entry point keys the cache by style × size ×
// pixelRatio so identical renders are O(1) after the first call.

import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

/// Discrete battery fill levels used by the cached icons. The widget
/// extension only ever requests one of these five so the live overlay
/// can stay locked to a handful of PNG files.
enum BatteryLevel { zero, quarter, half, threeQuarters, full }

/// Battery icon visual styles — each is a hand-crafted pixel-art
/// identity with its own outline treatment, fill pattern and charging
/// glyph.
enum BatteryStyle {
  /// Yellow chevron-fill outline on near-black. 80s arcade.
  classic,

  /// Cyan/green neon glow with inner highlight.
  neon,

  /// Compact 18x8 step pattern on graphite. Two-state.
  minimal,

  /// Gold brushed-metal with sparkle. High-end chronograph.
  premium,

  /// Orange diagonal stripes. High-octane.
  energy,
}

/// Pixel-art clock face designs (no hands — the widget draws those).
enum ClockFaceStyle {
  /// Outer ring with chunky numeral shapes and 60 minute ticks.
  classic,

  /// Pure matrix: 12 columns of dots, center cross.
  pixel,

  /// Cyan neon glow ring with 12 tickmark dots.
  neon,

  /// Bold chronograph with 3 subdials at 3 / 6 / 9.
  sport,

  /// Triple concentric rings + 12 hour markers.
  rings,
}

/// Background texture presets — pixel-art gradient compositions sized
/// to the 338x354 design canvas.
enum BackgroundPreset { aurora, midnight, sandstorm, neonGrid, ocean }

/// Shared battery geometry — every style renders onto the same
/// 24x12 cell body with a 2x4 terminal at a 6-cell gap. Centred in a
/// 35x18 cell canvas with a 3-cell padding above and below.
class _BatteryGrid {
  _BatteryGrid._();
  static const double ps = 4.0;
  // Body bounding box in pixel coords (cols inclusive, rows inclusive).
  static const int bodyL = 1, bodyT = 3;
  static const int bodyR = 24, bodyB = 14; // 24 wide, 12 tall.
  static const int innerL = 2, innerT = 4;
  static const int innerR = 23, innerB = 13; // 22 wide, 10 tall interior.

  // Terminal sits 6 cells past the body's right edge, vertically
  // centred on the body (rows 7..10).
  static const int termL = 31, termT = 7;
  static const int termR = 32, termB = 10; // 2 wide, 4 tall.
}

/// Shared clock face geometry — 140pt square at 4pt pixels → 35x35 cells.
class _ClockGrid {
  _ClockGrid._();
  static const double ps = 4.0;
  static const int dim = 35;
}

/// Pixel-art pipeline. Public entry points return PNG bytes; the
/// generation is synchronous on the canvas side, then awaits the
/// rasterisation + PNG encode to yield a `Future<Uint8List>`.
class PremiumAssetGenerator {
  PremiumAssetGenerator._();

  // Single shared cache, namespaced by call-site + params.
  static final Map<String, Uint8List> _cache = <String, Uint8List>{};

  /// Drop every cached PNG. Useful for tests and for hot-reloading
  /// styles without restarting the isolate.
  @visibleForTesting
  static void clearCache() => _cache.clear();

  /// Total entries currently in the static cache. Used by tests.
  @visibleForTesting
  static int get cacheSize => _cache.length;

  /// Generate (or fetch from cache) a PNG of the battery icon at the
  /// requested fill level / style.
  ///
  /// - [size] / [pixelRatio] control captured bitmap resolution
  ///   (`size * pixelRatio` actual pixels per axis). Defaults match the
  ///   project's standard 3x retina export.
  /// - Caching is keyed by (level, style, size, pixelRatio) so e.g. a
  ///   `classic half` 140x70 @3x is painted exactly once per process.
  static Future<Uint8List> generateBatteryIcon({
    required BatteryLevel level,
    required BatteryStyle style,
    Size size = const Size(140, 70),
    double pixelRatio = 3.0,
  }) async {
    final key = _key('bat', <String>[
      level.name,
      style.name,
      _sizeKey(size),
      _prKey(pixelRatio),
    ]);
    final cached = _cache[key];
    if (cached != null) return cached;
    final bytes = await _render(
      size: size,
      pixelRatio: pixelRatio,
      paint: (canvas, s) => _paintBattery(canvas, s, level, style),
    );
    _cache[key] = bytes;
    return bytes;
  }

  /// Generate (or fetch from cache) a PNG of a static clock face for
  /// the requested style. **No hands** — the widget overlay draws
  /// dynamic hour/minute/second hands on top of the cached face so the
  /// dial bitmap is regenerated only when style / size change.
  static Future<Uint8List> generateClockFace({
    required ClockFaceStyle style,
    Size size = const Size(140, 140),
    double pixelRatio = 3.0,
  }) async {
    final key = _key('clk', <String>[
      style.name,
      _sizeKey(size),
      _prKey(pixelRatio),
    ]);
    final cached = _cache[key];
    if (cached != null) return cached;
    final bytes = await _render(
      size: size,
      pixelRatio: pixelRatio,
      paint: (canvas, s) => _paintClock(canvas, s, style),
    );
    _cache[key] = bytes;
    return bytes;
  }

  /// Generate (or fetch from cache) a PNG of the procedural background
  /// matching the given [preset]. Sized to Drive Studio's 338x354
  /// design canvas by default.
  static Future<Uint8List> generateBackground({
    required BackgroundPreset preset,
    Size size = const Size(338, 354),
    double pixelRatio = 3.0,
  }) async {
    final key = _key('bg', <String>[
      preset.name,
      _sizeKey(size),
      _prKey(pixelRatio),
    ]);
    final cached = _cache[key];
    if (cached != null) return cached;
    final bytes = await _render(
      size: size,
      pixelRatio: pixelRatio,
      paint: (canvas, s) => _paintBackground(canvas, s, preset),
    );
    _cache[key] = bytes;
    return bytes;
  }

  // --- key helpers -------------------------------------------------------

  static String _key(String ns, List<String> parts) => '$ns|${parts.join('|')}';

  static String _sizeKey(Size s) =>
      '${s.width.toStringAsFixed(2)}x${s.height.toStringAsFixed(2)}';

  static String _prKey(double pr) => pr.toStringAsFixed(2);

  // --- render pipeline ---------------------------------------------------

  static Future<Uint8List> _render({
    required Size size,
    required double pixelRatio,
    required void Function(Canvas canvas, Size size) paint,
  }) async {
    assert(size.width > 0 && size.height > 0, 'size must be positive');
    assert(pixelRatio > 0, 'pixelRatio must be positive');

    final recorder = ui.PictureRecorder();
    final canvas = Canvas(recorder, Offset.zero & size);
    paint(canvas, size);
    final picture = recorder.endRecording();

    final image = await picture.toImage(
      (size.width * pixelRatio).round(),
      (size.height * pixelRatio).round(),
    );
    picture.dispose();
    try {
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);
      if (byteData == null) {
        throw StateError('PremiumAssetGenerator: PNG encode returned null');
      }
      return byteData.buffer.asUint8List();
    } finally {
      image.dispose();
    }
  }

  // -- pixel cell --------------------------------------------------------
  /// Stamp a single pixel-art cell at grid coords (x, y) with size
  /// [ps] (logical points). Uses an opaque paint so the call is cheap
  /// to issue thousands of times per icon.
  static void _px(Canvas c, int x, int y, Color color, {double ps = 4}) {
    final p = Paint()..color = color;
    c.drawRect(Rect.fromLTWH(x.toDouble() * ps, y.toDouble() * ps, ps, ps), p);
  }

  /// Stamp an opaque horizontal run of [n] pixels starting at (x, y).
  static void _run(
    Canvas c,
    int x,
    int y,
    int n,
    Color color, {
    double ps = 4,
  }) {
    final p = Paint()..color = color;
    c.drawRect(
      Rect.fromLTWH(x.toDouble() * ps, y.toDouble() * ps, n * ps, ps),
      p,
    );
  }

  /// Stamp an opaque vertical run of [n] pixels starting at (x, y).
  static void _runV(
    Canvas c,
    int x,
    int y,
    int n,
    Color color, {
    double ps = 4,
  }) {
    final p = Paint()..color = color;
    c.drawRect(
      Rect.fromLTWH(x.toDouble() * ps, y.toDouble() * ps, ps, n * ps),
      p,
    );
  }

  /// Stamp a filled rectangle of opaque pixels with grid-coord bounds
  /// (inclusive l..r inclusive t..b).
  static void _rect(
    Canvas c,
    int l,
    int t,
    int r,
    int b,
    Color color, {
    double ps = 4,
  }) {
    if (r < l || b < t) return;
    final p = Paint()..color = color;
    c.drawRect(
      Rect.fromLTWH(
        l.toDouble() * ps,
        t.toDouble() * ps,
        (r - l + 1) * ps,
        (b - t + 1) * ps,
      ),
      p,
    );
  }

  // ---------------------------------------------------------------------
  // Battery painter (dispatches to one of 5 styles)
  // ---------------------------------------------------------------------
  static void _paintBattery(
    Canvas canvas,
    Size size,
    BatteryLevel level,
    BatteryStyle style,
  ) {
    // Always start with the bg/track so partial fills don't bleed into
    // transparency — Drive widgets sit on multiple bg textures.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0A0E1A),
    );
    switch (style) {
      case BatteryStyle.classic:
        _paintBatteryClassic(canvas, level);
        break;
      case BatteryStyle.neon:
        _paintBatteryNeon(canvas, level);
        break;
      case BatteryStyle.minimal:
        _paintBatteryMinimal(canvas, level);
        break;
      case BatteryStyle.premium:
        _paintBatteryPremium(canvas, level);
        break;
      case BatteryStyle.energy:
        _paintBatteryEnergy(canvas, level);
        break;
    }
  }

  /// Draw the battery terminal cap (small "+" tab).
  static void _drawTerminal(Canvas c, Color color) {
    _rect(
      c,
      _BatteryGrid.termL,
      _BatteryGrid.termT,
      _BatteryGrid.termR,
      _BatteryGrid.termB,
      color,
      ps: _BatteryGrid.ps,
    );
  }

  /// Draw a 2-pixel thick outline for the body — top + bottom rows and
  /// left + right columns.
  static void _drawBodyOutline(Canvas c, Color color) {
    _run(
      c,
      _BatteryGrid.bodyL,
      _BatteryGrid.bodyT,
      _BatteryGrid.bodyR - _BatteryGrid.bodyL + 1,
      color,
      ps: _BatteryGrid.ps,
    );
    _run(
      c,
      _BatteryGrid.bodyL,
      _BatteryGrid.bodyB,
      _BatteryGrid.bodyR - _BatteryGrid.bodyL + 1,
      color,
      ps: _BatteryGrid.ps,
    );
    _runV(
      c,
      _BatteryGrid.bodyL,
      _BatteryGrid.bodyT,
      _BatteryGrid.bodyB - _BatteryGrid.bodyT + 1,
      color,
      ps: _BatteryGrid.ps,
    );
    _runV(
      c,
      _BatteryGrid.bodyR,
      _BatteryGrid.bodyT,
      _BatteryGrid.bodyB - _BatteryGrid.bodyT + 1,
      color,
      ps: _BatteryGrid.ps,
    );
  }

  /// Draw a 1-pixel inner-inset outline (used by neon for the cyan
  /// glow strip inside the body shell).
  static void _drawBodyInset(Canvas c, Color color) {
    final l = _BatteryGrid.bodyL + 1, t = _BatteryGrid.bodyT + 1;
    final r = _BatteryGrid.bodyR - 1, b = _BatteryGrid.bodyB - 1;
    _run(c, l, t, r - l + 1, color, ps: _BatteryGrid.ps);
    _run(c, l, b, r - l + 1, color, ps: _BatteryGrid.ps);
    _runV(c, l, t, b - t + 1, color, ps: _BatteryGrid.ps);
    _runV(c, r, t, b - t + 1, color, ps: _BatteryGrid.ps);
  }

  // -- Classic -------------------------------------------------------------
  // Yellow chevron fill, 2-px outline, dark interior; lightning bolt for
  // full / threeQuarters accent.
  static void _paintBatteryClassic(Canvas c, BatteryLevel level) {
    const Color outline = Color(0xFFFFD54F);
    const Color track = Color(0xFF1A1E2A);
    const Color fill = Color(0xFFFFE066);

    // Track interior.
    _rect(
      c,
      _BatteryGrid.innerL,
      _BatteryGrid.innerT,
      _BatteryGrid.innerR,
      _BatteryGrid.innerB,
      track,
      ps: _BatteryGrid.ps,
    );

    // Chevron-fill by level — each level draws N chevrons along the
    // bottom row, growing leftward.
    final fillCount = _chevronCount(level);
    if (fillCount > 0) {
      final fillW =
          _BatteryGrid.innerR - _BatteryGrid.innerL + 1; // 22 cells wide.
      // Chevron 5x3 cell. Pattern:
      //   .X.
      //   XOX
      //   XXX
      // Each chevron occupies 5 cols × 3 rows. We tile them
      // horizontally (4 chevrons across = 20 cols), then add a final
      // partial chevron for finer step-grain.
      for (var i = 0; i < fillCount; i++) {
        final base = _BatteryGrid.innerR - i * 5;
        if (base - 4 < _BatteryGrid.innerL) continue;
        _drawChevron(
          c,
          base - 4,
          _BatteryGrid.innerB - 2,
          fill,
          ps: _BatteryGrid.ps,
        );
      }
      // For half / threeQuarters / full also fill the sliver space
      // before the first chevron so the gradient feels continuous.
      final fillStart = _BatteryGrid.innerL;
      final fillEnd = _BatteryGrid.innerR - fillCount * 5;
      if (fillEnd >= fillStart) {
        _rect(
          c,
          fillStart,
          _BatteryGrid.innerB,
          fillEnd,
          _BatteryGrid.innerB,
          fill,
          ps: _BatteryGrid.ps,
        );
        if (level.index >= BatteryLevel.half.index) {
          _rect(
            c,
            fillStart,
            _BatteryGrid.innerB - 1,
            fillEnd,
            _BatteryGrid.innerB - 1,
            fill,
            ps: _BatteryGrid.ps,
          );
        }
        if (level.index >= BatteryLevel.threeQuarters.index) {
          _rect(
            c,
            fillStart,
            _BatteryGrid.innerB - 2,
            fillEnd,
            _BatteryGrid.innerB - 2,
            fill,
            ps: _BatteryGrid.ps,
          );
        }
        if (level == BatteryLevel.full) {
          _rect(
            c,
            _BatteryGrid.innerL,
            _BatteryGrid.innerT,
            _BatteryGrid.innerR,
            _BatteryGrid.innerB,
            fill,
            ps: _BatteryGrid.ps,
          );
          // Restore chevron pattern in the bottom row so full doesn't
          // feel flat.
          for (var i = 0; i < fillCount - 1; i++) {
            final base = _BatteryGrid.innerR - i * 5;
            if (base - 4 < _BatteryGrid.innerL) continue;
            _drawChevron(
              c,
              base - 4,
              _BatteryGrid.innerB - 2,
              fill,
              ps: _BatteryGrid.ps,
            );
          }
        }
      }
      // Reference unused vars for lints.
      assert(fillW >= 0);
    }

    // Body outline (2-pixel thick — we draw a 1-px outline then a
    // second offset one inside).
    _drawBodyOutline(c, outline);
    _drawBodyInset(c, outline);
    _drawTerminal(c, outline);

    // Charging bolt overlay when full / threeQuarters — chunky
    // pixel-art lightning centred on the body.
    if (level == BatteryLevel.full || level == BatteryLevel.threeQuarters) {
      _drawLightningBolt(c, outline, scale: 1);
    }
  }

  /// 5-col × 3-row chevron pattern stamp; (x, y) is the bottom-left
  /// corner of the bounding box (inclusive).
  static void _drawChevron(
    Canvas c,
    int x,
    int y,
    Color color, {
    double ps = 4,
  }) {
    // Bottom row (full width — pattern tile):
    _run(c, x, y, 5, color, ps: ps);
    // Middle row (gap at edges):
    _px(c, x + 1, y - 1, color, ps: ps);
    _px(c, x + 2, y - 1, color, ps: ps);
    _px(c, x + 3, y - 1, color, ps: ps);
    // Top row (centre only):
    _px(c, x + 2, y - 2, color, ps: ps);
  }

  static int _chevronCount(BatteryLevel level) {
    switch (level) {
      case BatteryLevel.zero:
        return 0;
      case BatteryLevel.quarter:
        return 1;
      case BatteryLevel.half:
        return 2;
      case BatteryLevel.threeQuarters:
        return 3;
      case BatteryLevel.full:
        return 4;
    }
  }

  // -- Neon ----------------------------------------------------------------
  // Cyan glow outline, white inner highlight, green pixel blocks growing
  // with level; cyan lightning bolt overlay.
  static void _paintBatteryNeon(Canvas c, BatteryLevel level) {
    const Color shell = Color(0xFF1B2638);
    const Color glow = Color(0xFF00E5FF);
    const Color highlight = Color(0xFFFFFFFF);
    const Color fill = Color(0xFF4DC98A);
    const Color cellOff = Color(0xFF1B2638);

    // Outer glow outline (cyan, 1 cell thick) — painted AFTER the body
    // so it sits on top.
    _drawBodyOutline(c, glow);
    _drawTerminal(c, glow);

    // Body shell.
    _rect(
      c,
      _BatteryGrid.bodyL + 1,
      _BatteryGrid.bodyT + 1,
      _BatteryGrid.bodyR - 1,
      _BatteryGrid.bodyB - 1,
      shell,
      ps: _BatteryGrid.ps,
    );

    // Cell-matrix fill: 22 interior cells wide × 10 tall = small block
    // grid. Each level selects how many columns (4) of cells are
    // filled.
    final cols = _chevronCount(level);
    const cellW = 5;
    const cellH = 2;
    for (var row = 0; row < 3; row++) {
      for (var col = 0; col < cols; col++) {
        final cellX = _BatteryGrid.innerL + col * cellW + 1;
        final cellY = _BatteryGrid.innerT + row * cellH + 1;
        // Hollow 3x3 stipple-like block (3 wide × 1 tall) so the fill
        // reads as "discrete cells" instead of a flat bar.
        _run(c, cellX, cellY, 3, fill, ps: _BatteryGrid.ps);
        _run(c, cellX, cellY + 1, 3, fill, ps: _BatteryGrid.ps);
      }
      // Off-state cells for the remaining columns (palette contrast).
      for (var col = cols; col < 4; col++) {
        final cellX = _BatteryGrid.innerL + col * cellW + 1;
        final cellY = _BatteryGrid.innerT + row * cellH + 1;
        _run(c, cellX, cellY, 3, cellOff, ps: _BatteryGrid.ps);
      }
    }

    // White inner highlight on the top edge of the body.
    _run(
      c,
      _BatteryGrid.bodyL + 1,
      _BatteryGrid.bodyT + 1,
      _BatteryGrid.bodyR - _BatteryGrid.bodyL - 1,
      highlight.withValues(alpha: 0.20),
      ps: _BatteryGrid.ps,
    );

    // Outer cyan halo offset by 1 cell — gives a faint glow.
    _halo(c, glow);

    // Charging glyph when level is full.
    if (level == BatteryLevel.full) {
      _drawLightningBolt(c, glow, scale: 1);
    }
  }

  /// Tiny diagonal cyan sparkle dots around the body for the neon style.
  static void _halo(Canvas c, Color glow) {
    final positions = <List<int>>[
      [0, _BatteryGrid.bodyT - 1],
      [_BatteryGrid.bodyL - 1, 5],
      [_BatteryGrid.bodyL - 1, 11],
      [0, _BatteryGrid.bodyB + 1],
      [_BatteryGrid.termR + 1, _BatteryGrid.termT],
      [_BatteryGrid.termR + 1, _BatteryGrid.termB],
    ];
    for (final p in positions) {
      _px(c, p[0], p[1], glow.withValues(alpha: 0.45), ps: _BatteryGrid.ps);
    }
  }

  // -- Minimal -------------------------------------------------------------
  // 18x8 cell body, simple two-state, gray track, green blocks.
  static void _paintBatteryMinimal(Canvas c, BatteryLevel level) {
    // Background already painted (graphite). Compose a smaller battery
    // centred on the canvas for the compact look.
    final ps = _BatteryGrid.ps;
    final bodyL = 4;
    final bodyT = 5;
    final bodyW = 18;
    final bodyH = 8;
    final bodyR = bodyL + bodyW - 1;
    final bodyB = bodyT + bodyH - 1;
    final interiorL = bodyL + 1, interiorT = bodyT + 1;
    final interiorR = bodyR - 1, interiorB = bodyB - 1;
    final innerW = interiorR - interiorL + 1; // 16
    final innerH = interiorB - interiorT + 1; // 6

    const Color track = Color(0xFF1F242E);
    const Color fill = Color(0xFF4DC98A);
    const Color shell = Color(0xFF2B3140);

    // Body shell — only the top/bottom edges (a sketchy pixel panel).
    _run(c, bodyL, bodyT, bodyW, shell, ps: ps);
    _run(c, bodyL, bodyB, bodyW, shell, ps: ps);
    _runV(c, bodyL, bodyT, bodyH, shell, ps: ps);
    _runV(c, bodyR, bodyT, bodyH, shell, ps: ps);

    // Terminal.
    final termL = bodyR + 3;
    final termT = bodyT + 2;
    _run(c, termL, termT, 1, shell, ps: ps);
    _run(c, termL, termT + 1, 1, shell, ps: ps);
    _run(c, termL, termT + 2, 1, shell, ps: ps);
    _run(c, termL, termT + 3, 1, shell, ps: ps);

    // Track.
    _rect(c, interiorL, interiorT, interiorR, interiorB, track, ps: ps);

    // Step-pattern fill — bottom-up terrace: 4 columns of cells.
    // Each column = 4 wide × 6 tall. Show only `level`-many columns
    // fully lit (the rest stay dark for a binary feel).
    const colW = 4;
    final colsLit = _chevronCount(level);
    for (var col = 0; col < 4; col++) {
      final x = interiorL + col * colW;
      if (col < colsLit) {
        _rect(c, x, interiorT, x + colW - 1, interiorB, fill, ps: ps);
      } else {
        // Off columns get a 1-cell highlight at the top so the empty
        // state still reads as designed (not a glitch).
        _run(c, x, interiorT, colW, track, ps: ps);
      }
    }

    // Tiny dot row of "charging" pips when level == full — 3 mid dots.
    if (level == BatteryLevel.full) {
      final cy = (interiorT + interiorB) ~/ 2;
      _px(c, interiorL + 3, cy, fill, ps: ps);
      _px(c, interiorL + 7, cy, fill, ps: ps);
      _px(c, interiorL + 11, cy, fill, ps: ps);
      _px(c, interiorL + 15, cy, fill, ps: ps);
    }
    assert(innerW >= 0 && innerH >= 0);
  }

  // -- Premium -------------------------------------------------------------
  // Gold outline + brushed-metal interior pattern + sparkle.
  static void _paintBatteryPremium(Canvas c, BatteryLevel level) {
    const Color gold = Color(0xFFD4AF37);
    const Color goldDeep = Color(0xFF9A7F1F);
    const Color sparkle = Color(0xFFFFE9A3);
    const Color track = Color(0xFF120C04);

    // Track.
    _rect(
      c,
      _BatteryGrid.bodyL,
      _BatteryGrid.bodyT,
      _BatteryGrid.bodyR,
      _BatteryGrid.bodyB,
      track,
      ps: _BatteryGrid.ps,
    );
    // Brushed-metal pattern: 1-pixel alternating dot per row.
    for (var y = _BatteryGrid.innerT; y <= _BatteryGrid.innerB; y++) {
      var alt = (y - _BatteryGrid.innerT).isEven;
      for (var x = _BatteryGrid.innerL; x <= _BatteryGrid.innerR; x++) {
        if (alt) _px(c, x, y, goldDeep, ps: _BatteryGrid.ps);
        alt = !alt;
      }
    }

    // Solid gold fill above the brushed-metal "track" — based on level.
    final fillRows = _fillRows(level); // 0..10
    if (fillRows > 0) {
      final bottom = _BatteryGrid.innerB;
      final top = _BatteryGrid.innerB - fillRows + 1;
      _rect(
        c,
        _BatteryGrid.innerL,
        top,
        _BatteryGrid.innerR,
        bottom,
        gold,
        ps: _BatteryGrid.ps,
      );
    }

    // Outline (2-px thick gold) — draw outline AFTER fill.
    _drawBodyOutline(c, gold);
    _drawBodyInset(c, gold);
    _drawTerminal(c, gold);

    // Sparkle stars (4 small + shapes) when full / threeQuarters.
    if (level == BatteryLevel.full || level == BatteryLevel.threeQuarters) {
      _drawSparkle(c, 5, 5, sparkle, ps: _BatteryGrid.ps);
      _drawSparkle(c, _BatteryGrid.bodyR - 5, 6, sparkle, ps: _BatteryGrid.ps);
      _drawSparkle(c, 8, _BatteryGrid.bodyB - 1, sparkle, ps: _BatteryGrid.ps);
    }

    // Charging bolt when full.
    if (level == BatteryLevel.full) {
      _drawLightningBolt(c, sparkle, scale: 1);
    }
  }

  static int _fillRows(BatteryLevel level) {
    switch (level) {
      case BatteryLevel.zero:
        return 0;
      case BatteryLevel.quarter:
        return 3;
      case BatteryLevel.half:
        return 5;
      case BatteryLevel.threeQuarters:
        return 8;
      case BatteryLevel.full:
        return 10;
    }
  }

  /// 5x5 pixel sparkle ("+").
  static void _drawSparkle(
    Canvas c,
    int cx,
    int cy,
    Color color, {
    double ps = 4,
  }) {
    _px(c, cx, cy, color, ps: ps);
    _px(c, cx - 1, cy, color, ps: ps);
    _px(c, cx + 1, cy, color, ps: ps);
    _px(c, cx, cy - 1, color, ps: ps);
    _px(c, cx, cy + 1, color, ps: ps);
  }

  // -- Energy --------------------------------------------------------------
  // Orange diagonal stripe fill, red lightning for charging.
  static void _paintBatteryEnergy(Canvas c, BatteryLevel level) {
    const Color shell = Color(0xFFFF6B35);
    const Color shellDeep = Color(0xFFB23E1A);
    const Color track = Color(0xFF180806);
    const Color boltRed = Color(0xFFE63946);

    // Track.
    _rect(
      c,
      _BatteryGrid.bodyL,
      _BatteryGrid.bodyT,
      _BatteryGrid.bodyR,
      _BatteryGrid.bodyB,
      track,
      ps: _BatteryGrid.ps,
    );

    // Fill — diagonal stripes pattern grows with level.
    final rowsLit = _fillRows(level);
    if (rowsLit > 0) {
      for (
        var y = _BatteryGrid.innerB;
        y >= _BatteryGrid.innerB - rowsLit + 1;
        y--
      ) {
        var phase = (y - _BatteryGrid.innerT) % 4;
        for (var x = _BatteryGrid.innerL; x <= _BatteryGrid.innerR; x++) {
          // 2-cell-wide diagonal stripe every 4 cells.
          if ((x + phase) % 4 < 2) {
            _px(c, x, y, shell, ps: _BatteryGrid.ps);
          } else {
            _px(c, x, y, shellDeep, ps: _BatteryGrid.ps);
          }
        }
      }
    }

    // Outline (orange) on top.
    _drawBodyOutline(c, shell);
    _drawTerminal(c, shell);

    // Red charging bolt.
    if (level == BatteryLevel.full) {
      _drawLightningBolt(c, boltRed, scale: 1);
    }
  }

  // -- Chunky pixel-art lightning bolt -------------------------------------
  // 9-wide × 12-tall zig-zag. Centred on the body interior.
  static void _drawLightningBolt(
    Canvas c,
    Color color, {
    int scale = 1,
    double ps = 4,
  }) {
    // Anchor: bolt bounding box drawn at body interior centre.
    final cx = (_BatteryGrid.innerL + _BatteryGrid.innerR) ~/ 2;
    final cy = (_BatteryGrid.innerT + _BatteryGrid.innerB) ~/ 2;
    _bolt(c, cx, cy, color, ps: ps);
  }

  /// Tiny lightning stamp anchored at its top-tip cell (cx, cy).
  /// The shape is 9 cols × 13 rows — explicit list of filled cells.
  static void _bolt(Canvas c, int cx, int cy, Color color, {double ps = 4}) {
    // Offsets relative to (cx, cy) — bolt-graphic is hand-coded.
    const offsets = <List<int>>[
      [-2, 0],
      [-1, 0],
      [0, 0],
      [-3, 1],
      [-2, 1],
      [-1, 1],
      [-1, 2],
      [0, 2],
      [1, 2],
      [0, 3],
      [1, 3],
      [2, 3],
      [1, 4],
      [2, 4],
      [3, 4],
      [2, 5],
      [3, 5],
      [4, 5],
      [1, 6],
      [2, 6],
      [3, 6],
      [0, 7],
      [1, 7],
      [2, 7],
      [-1, 8],
      [0, 8],
      [1, 8],
      [-2, 9],
      [-1, 9],
      [0, 9],
      [-3, 10],
      [-2, 10],
      [-1, 10],
    ];
    for (final o in offsets) {
      _px(c, cx + o[0], cy + o[1], color, ps: ps);
    }
  }

  // ---------------------------------------------------------------------
  // Clock face painter
  // ---------------------------------------------------------------------
  static void _paintClock(Canvas canvas, Size size, ClockFaceStyle style) {
    // Solid dark fill.
    canvas.drawRect(
      Offset.zero & size,
      Paint()..color = const Color(0xFF0A0E1A),
    );
    // Inner radial wash via inexpensive gradient — keeps backgrounds
    // feeling centered without slowing pixel-art composition.
    canvas.drawRect(
      Offset.zero & size,
      Paint()
        ..shader = RadialGradient(
          center: Alignment.center,
          radius: 0.6,
          colors: const [Color(0xFF111A2C), Color(0xFF0A0E1A)],
        ).createShader(Offset.zero & size),
    );
    switch (style) {
      case ClockFaceStyle.classic:
        _paintClockClassic(canvas);
        break;
      case ClockFaceStyle.pixel:
        _paintClockPixel(canvas);
        break;
      case ClockFaceStyle.neon:
        _paintClockNeon(canvas);
        break;
      case ClockFaceStyle.sport:
        _paintClockSport(canvas);
        break;
      case ClockFaceStyle.rings:
        _paintClockRings(canvas);
        break;
    }
  }

  /// Pixel-art numeral shape for hour value 1..12 (or 0 for noon is
  /// intentionally treated as "12"). Drawn within a 5x7 cell bounding
  /// box anchored at top-left (x, y).
  static void _drawDigit(
    Canvas c,
    int digit,
    int x,
    int y,
    Color color, {
    double ps = 4,
  }) {
    final rows = _digitRows(digit);
    for (var row = 0; row < rows.length; row++) {
      final s = rows[row];
      for (var col = 0; col < s.length; col++) {
        if (s[col] == 'X') {
          _px(c, x + col, y + row, color, ps: ps);
        }
      }
    }
  }

  /// 5x7 pixel-art numerals — handy minis.
  static List<String> _digitRows(int d) {
    switch (d) {
      case 0:
        return const [
          'XXXXX',
          'X...X',
          'X...X',
          'X...X',
          'X...X',
          'X...X',
          'XXXXX',
        ];
      case 1:
        return const [
          '..X..',
          '.XX..',
          '..X..',
          '..X..',
          '..X..',
          '..X..',
          '.XXX.',
        ];
      case 2:
        return const [
          'XXXXX',
          '....X',
          '....X',
          'XXXXX',
          'X....',
          'X....',
          'XXXXX',
        ];
      case 3:
        return const [
          'XXXXX',
          '....X',
          '....X',
          '.XXXX',
          '....X',
          '....X',
          'XXXXX',
        ];
      case 4:
        return const [
          'X...X',
          'X...X',
          'X...X',
          'XXXXX',
          '....X',
          '....X',
          '....X',
        ];
      case 5:
        return const [
          'XXXXX',
          'X....',
          'X....',
          'XXXXX',
          '....X',
          '....X',
          'XXXXX',
        ];
      case 6:
        return const [
          'XXXXX',
          'X....',
          'X....',
          'XXXXX',
          'X...X',
          'X...X',
          'XXXXX',
        ];
      case 7:
        return const [
          'XXXXX',
          '....X',
          '....X',
          '...X.',
          '..X..',
          '..X..',
          '..X..',
        ];
      case 8:
        return const [
          'XXXXX',
          'X...X',
          'X...X',
          'XXXXX',
          'X...X',
          'X...X',
          'XXXXX',
        ];
      case 9:
        return const [
          'XXXXX',
          'X...X',
          'X...X',
          'XXXXX',
          '....X',
          '....X',
          'XXXXX',
        ];
      default:
        return const [
          'XXXXX',
          'X...X',
          'X...X',
          'XXXXX',
          'X...X',
          'X...X',
          'XXXXX',
        ];
    }
  }

  /// Draw a 60-tick ring with bold 5-min pips and 1-min pips.
  static void _drawTicks(
    Canvas c,
    Color pipColor, {
    bool boldEveryFive = true,
    double ps = 4,
  }) {
    final cx = _ClockGrid.dim ~/ 2;
    final cy = _ClockGrid.dim ~/ 2;
    final r = (_ClockGrid.dim ~/ 2) - 2;
    for (var i = 0; i < 60; i++) {
      final angle = (i / 60) * 2 * math.pi - math.pi / 2;
      final dx = math.cos(angle);
      final dy = math.sin(angle);
      final isMajor = i % 5 == 0;
      final length = boldEveryFive && isMajor ? 2 : 1;
      for (var k = 0; k < length; k++) {
        final x = (cx + dx * (r - k)).round();
        final y = (cy + dy * (r - k)).round();
        _px(c, x, y, pipColor, ps: ps);
      }
    }
  }

  /// Classic — single pixel ring + chunky pixel numerals + minute ticks.
  static void _paintClockClassic(Canvas c) {
    const fg = Color(0xFFF2F5FA);
    const accent = Color(0xFFFFD54F);

    final cx = _ClockGrid.dim ~/ 2; // 17
    final cy = _ClockGrid.dim ~/ 2;
    final rOuter = (_ClockGrid.dim ~/ 2) - 2; // 15
    final rInner = rOuter - 1;

    // Outer ring (1 cell thick).
    for (var i = 0; i < 360; i += 3) {
      final a = i * math.pi / 180;
      final x = (cx + math.cos(a) * rOuter).round();
      final y = (cy + math.sin(a) * rOuter).round();
      _px(c, x, y, fg, ps: _ClockGrid.ps);
    }
    // Inner ring (1 cell thick, dim).
    final dim = fg.withValues(alpha: 0.4);
    for (var i = 0; i < 360; i += 3) {
      final a = i * math.pi / 180;
      final x = (cx + math.cos(a) * rInner).round();
      final y = (cy + math.sin(a) * rInner).round();
      _px(c, x, y, dim, ps: _ClockGrid.ps);
    }

    // 60 minute ticks.
    _drawTicks(c, fg, ps: _ClockGrid.ps);

    // 12 chunky numerals — 5x7 each, positioned along inner ring.
    final numR = rOuter - 5;
    for (var hour = 1; hour <= 12; hour++) {
      final angle = _hourAngle(hour);
      // Place digits so they sit tangent to the inner ring — offset by
      // 3 cells horizontally and 4 vertically (so 5x7 sits centred).
      final tx = (cx + math.cos(angle) * numR - 2).round();
      final ty = (cy + math.sin(angle) * numR - 3).round();
      // Cardinals use accent.
      final col = (hour % 3 == 0) ? accent : fg;
      _drawDigit(
        c,
        hour % 10 == 0 ? 1 : hour % 10,
        tx,
        ty,
        col,
        ps: _ClockGrid.ps,
      );
      if (hour == 10) {
        _drawDigit(c, 0, tx - 6, ty, col, ps: _ClockGrid.ps);
      } else if (hour == 11) {
        _drawDigit(c, 1, tx - 6, ty, col, ps: _ClockGrid.ps);
      } else if (hour == 12) {
        _drawDigit(c, 1, tx - 6, ty, col, ps: _ClockGrid.ps);
        _drawDigit(c, 2, tx, ty, col, ps: _ClockGrid.ps);
      }
    }
  }

  /// Pixel — 12 columns of dots arranged in a circle, centre cross.
  static void _paintClockPixel(Canvas c) {
    const fg = Color(0xFF7EB8FF);
    const accent = Color(0xFFFFFFFF);

    final cx = _ClockGrid.dim ~/ 2;
    final cy = _ClockGrid.dim ~/ 2;
    final r = (_ClockGrid.dim ~/ 2) - 5;
    for (var hour = 1; hour <= 12; hour++) {
      final angle = _hourAngle(hour);
      final px = (cx + math.cos(angle) * r).round();
      final py = (cy + math.sin(angle) * r).round();
      // Each dot is a 3x3 cell with a 1-cell gap.
      final col = (hour % 3 == 0) ? accent : fg;
      _rect(c, px - 1, py - 1, px + 1, py + 1, col, ps: _ClockGrid.ps);
    }

    // Inner guide ring — 24 dots lighter.
    final guide = fg.withValues(alpha: 0.35);
    final rGuide = (_ClockGrid.dim ~/ 2) - 9;
    for (var i = 0; i < 24; i++) {
      final a = (i / 24) * 2 * math.pi;
      _px(
        c,
        (cx + math.cos(a) * rGuide).round(),
        (cy + math.sin(a) * rGuide).round(),
        guide,
        ps: _ClockGrid.ps,
      );
    }

    // Centre cross (5x5).
    final cc = (_ClockGrid.dim ~/ 2) - 2;
    _rect(c, cc, cc + 2, cc + 4, cc + 2, accent, ps: _ClockGrid.ps);
    _runV(c, cc + 2, cc, 5, accent, ps: _ClockGrid.ps);
  }

  /// Neon — outer ring (2 thick) with 1-cell halo + 12 tickmark dots.
  static void _paintClockNeon(Canvas c) {
    final cx = _ClockGrid.dim ~/ 2;
    final cy = _ClockGrid.dim ~/ 2;
    final rOuter = (_ClockGrid.dim ~/ 2) - 1;
    const neon = Color(0xFF4D9EFF);
    // Outer ring 2 thick.
    for (var i = 0; i < 360; i += 2) {
      final a = i * math.pi / 180;
      final x = (cx + math.cos(a) * rOuter).round();
      final y = (cy + math.sin(a) * rOuter).round();
      _px(c, x, y, neon, ps: _ClockGrid.ps);
      final x2 = (cx + math.cos(a) * (rOuter - 1)).round();
      final y2 = (cy + math.sin(a) * (rOuter - 1)).round();
      _px(c, x2, y2, neon, ps: _ClockGrid.ps);
    }
    // Outer halo — fainter wider ring.
    final halo = neon.withValues(alpha: 0.35);
    for (var i = 0; i < 360; i += 4) {
      final a = i * math.pi / 180;
      final x = (cx + math.cos(a) * (rOuter + 1)).round();
      final y = (cy + math.sin(a) * (rOuter + 1)).round();
      _px(c, x, y, halo, ps: _ClockGrid.ps);
    }

    // 12 tickmark dots — each is 3 dots stacked vertically.
    final rTick = (_ClockGrid.dim ~/ 2) - 6;
    for (var hour = 1; hour <= 12; hour++) {
      final angle = _hourAngle(hour);
      final px = (cx + math.cos(angle) * rTick).round();
      final py = (cy + math.sin(angle) * rTick).round();
      _px(c, px, py, neon, ps: _ClockGrid.ps);
      _px(
        c,
        (cx + math.cos(angle) * (rTick - 1)).round(),
        (cy + math.sin(angle) * (rTick - 1)).round(),
        neon,
        ps: _ClockGrid.ps,
      );
      _px(
        c,
        (cx + math.cos(angle) * (rTick - 2)).round(),
        (cy + math.sin(angle) * (rTick - 2)).round(),
        neon,
        ps: _ClockGrid.ps,
      );
    }

    // Centre pin.
    final ccx = cx;
    final ccy = cy;
    _px(c, ccx, ccy, neon, ps: _ClockGrid.ps);
    _px(c, ccx - 1, ccy, neon, ps: _ClockGrid.ps);
    _px(c, ccx + 1, ccy, neon, ps: _ClockGrid.ps);
    _px(c, ccx, ccy - 1, neon, ps: _ClockGrid.ps);
    _px(c, ccx, ccy + 1, neon, ps: _ClockGrid.ps);
  }

  /// Sport — bold outer ring, 12 numerals, 3 subdials at 3/6/9.
  static void _paintClockSport(Canvas c) {
    const fg = Color(0xFFF2F5FA);
    const accent = Color(0xFFFF3868);
    final cx = _ClockGrid.dim ~/ 2;
    final cy = _ClockGrid.dim ~/ 2;
    final rOuter = (_ClockGrid.dim ~/ 2) - 1;

    // Bold outer ring — 3 cells thick.
    for (var thickness = 0; thickness < 3; thickness++) {
      for (var i = 0; i < 360; i += 2) {
        final a = i * math.pi / 180;
        final x = (cx + math.cos(a) * (rOuter - thickness)).round();
        final y = (cy + math.sin(a) * (rOuter - thickness)).round();
        _px(c, x, y, fg, ps: _ClockGrid.ps);
      }
    }

    // 12 hour markers — 2-cell ticks.
    _drawTicks(c, fg, ps: _ClockGrid.ps);

    // Subdials at 3 / 6 / 9.
    _drawSubdial(c, cx + 8, cy, 4, fg, accent, ps: _ClockGrid.ps);
    _drawSubdial(c, cx - 8, cy, 4, fg, accent, ps: _ClockGrid.ps);
    _drawSubdial(c, cx, cy - 8, 4, fg, accent, ps: _ClockGrid.ps);

    // Centre "+" pin.
    _px(c, cx, cy, fg, ps: _ClockGrid.ps);
    _px(c, cx - 1, cy, fg, ps: _ClockGrid.ps);
    _px(c, cx + 1, cy, fg, ps: _ClockGrid.ps);
    _px(c, cx, cy - 1, fg, ps: _ClockGrid.ps);
    _px(c, cx, cy + 1, fg, ps: _ClockGrid.ps);
  }

  /// Tiny circular subdial — 6x6 outline + 4 cardinal pips + accent dot.
  static void _drawSubdial(
    Canvas c,
    int cx,
    int cy,
    int r,
    Color shell,
    Color accent, {
    double ps = 4,
  }) {
    for (var i = 0; i < 360; i += 30) {
      final a = i * math.pi / 180;
      _px(
        c,
        (cx + math.cos(a) * r).round(),
        (cy + math.sin(a) * r).round(),
        shell,
        ps: ps,
      );
    }
    _px(c, cx, cy, accent, ps: ps);
  }

  /// Rings — triple concentric pixel-art rings + 12 hour markers.
  static void _paintClockRings(Canvas c) {
    final cx = _ClockGrid.dim ~/ 2;
    final cy = _ClockGrid.dim ~/ 2;
    final radii = [
      _ClockGrid.dim ~/ 2 - 1,
      _ClockGrid.dim ~/ 2 - 5,
      _ClockGrid.dim ~/ 2 - 9,
    ];
    final colors = [
      const Color(0xFF7EB8FF),
      const Color(0xFFFFFFFF),
      const Color(0xFF4D9EFF),
    ];
    final widths = [1, 1, 1];

    for (var idx = 0; idx < radii.length; idx++) {
      final r = radii[idx];
      for (var i = 0; i < 360; i += 2) {
        final a = i * math.pi / 180;
        for (var k = 0; k < widths[idx]; k++) {
          _px(
            c,
            (cx + math.cos(a) * (r - k)).round(),
            (cy + math.sin(a) * (r - k)).round(),
            colors[idx],
            ps: _ClockGrid.ps,
          );
        }
      }
    }

    // 12 hour markers — single pixel dot on innermost ring.
    final rTick = radii.last;
    for (var hour = 1; hour <= 12; hour++) {
      final a = _hourAngle(hour);
      _px(
        c,
        (cx + math.cos(a) * rTick).round(),
        (cy + math.sin(a) * rTick).round(),
        colors.first,
        ps: _ClockGrid.ps,
      );
    }

    // Centre pip.
    _px(c, cx, cy, colors[1], ps: _ClockGrid.ps);
  }

  /// Hour-to-angle helper. 12 o'clock is at -π/2 (up).
  static double _hourAngle(int hour) {
    final h = hour % 12;
    return (h / 12) * 2 * math.pi - math.pi / 2;
  }

  // ---------------------------------------------------------------------
  // Background painter
  // ---------------------------------------------------------------------
  static void _paintBackground(
    Canvas canvas,
    Size size,
    BackgroundPreset preset,
  ) {
    switch (preset) {
      case BackgroundPreset.aurora:
        _paintBgAurora(canvas, size);
        break;
      case BackgroundPreset.midnight:
        _paintBgMidnight(canvas, size);
        break;
      case BackgroundPreset.sandstorm:
        _paintBgSandstorm(canvas, size);
        break;
      case BackgroundPreset.neonGrid:
        _paintBgNeonGrid(canvas, size);
        break;
      case BackgroundPreset.ocean:
        _paintBgOcean(canvas, size);
        break;
    }
  }

  /// Per-pixel gradient sampler. For a given (x, y) in pixel coords and
  /// a list of gradient stops (color, position 0..1), returns the
  /// interpolated colour. Used by all bg presets except neonGrid.
  static Color _sampleGradient(
    int x,
    int y,
    int gridW,
    int gridH,
    bool vertical,
    List<MapEntry<double, Color>> stops,
  ) {
    final t = vertical ? (y / (gridH - 1)) : (x / (gridW - 1));
    // Locate bracket.
    for (var i = 0; i < stops.length - 1; i++) {
      final a = stops[i];
      final b = stops[i + 1];
      if (t >= a.key && t <= b.key) {
        final local = (t - a.key) / (b.key - a.key == 0 ? 1 : b.key - a.key);
        final colA = a.value;
        final colB = b.value;
        final r = (colA.r * 255 * (1 - local) + colB.r * 255 * local)
            .round()
            .clamp(0, 255);
        final gC = (colA.g * 255 * (1 - local) + colB.g * 255 * local)
            .round()
            .clamp(0, 255);
        final bl = (colA.b * 255 * (1 - local) + colB.b * 255 * local)
            .round()
            .clamp(0, 255);
        return Color.fromARGB(255, r, gC, bl);
      }
    }
    return stops.last.value;
  }

  /// Aurora — vertical pixel gradient with horizontal white streaks.
  static void _paintBgAurora(Canvas c, Size size) {
    const ps = 4.0;
    final gridW = (size.width / ps).floor();
    final gridH = (size.height / ps).floor();
    final stops = <MapEntry<double, Color>>[
      const MapEntry(0.0, Color(0xFF0F1B3D)),
      const MapEntry(0.25, Color(0xFF1E3A8A)),
      const MapEntry(0.55, Color(0xFF3B82F6)),
      const MapEntry(0.78, Color(0xFF4D9EFF)),
      const MapEntry(1.0, Color(0xFF93C5FD)),
    ];

    // Compute stroke rows up front (horizontal pixel streaks at 8-row
    // intervals) so we only touch per-pixel paint state once per row.
    final strokeAt = <int>{};
    for (var i = 0; i < gridH; i += 8) {
      strokeAt.add(i);
      strokeAt.add(i + 1);
    }

    for (var y = 0; y < gridH; y++) {
      for (var x = 0; x < gridW; x++) {
        final col = _sampleGradient(x, y, gridW, gridH, true, stops);
        // 5% white streak.
        if (strokeAt.contains(y) && x % 2 == 0) {
          final w = Color.fromARGB(
            255,
            (col.r * 255 * 0.95 + 255 * 0.05).round().clamp(0, 255),
            (col.g * 255 * 0.95 + 255 * 0.05).round().clamp(0, 255),
            (col.b * 255 * 0.95 + 255 * 0.05).round().clamp(0, 255),
          );
          _px(c, x, y, w, ps: ps);
        } else {
          _px(c, x, y, col, ps: ps);
        }
      }
    }
  }

  /// Midnight — radial dark gradient + 30..50 pixel stars.
  static void _paintBgMidnight(Canvas c, Size size) {
    const ps = 4.0;
    final gridW = (size.width / ps).floor();
    final gridH = (size.height / ps).floor();
    // Centre the radial at canvas center.
    final cx = gridW / 2;
    final cy = gridH / 2;
    final maxR = math.sqrt(cx * cx + cy * cy);
    final stops = <MapEntry<double, Color>>[
      const MapEntry(0.0, Color(0xFF1A1E2A)),
      const MapEntry(0.45, Color(0xFF0F1419)),
      const MapEntry(1.0, Color(0xFF050810)),
    ];

    for (var y = 0; y < gridH; y++) {
      for (var x = 0; x < gridW; x++) {
        final dx = x - cx;
        final dy = y - cy;
        final r = math.sqrt(dx * dx + dy * dy) / maxR;
        final col = _sampleGradient(
          0,
          0,
          1,
          (r * 100).round() + 1,
          true,
          stops,
        );
        _px(c, x, y, col, ps: ps);
      }
    }

    // Stars — 40 small white pixel sparks, varying 1/2-px sizes.
    final rng = math.Random(42);
    final starColor = const Color(0xFFE8F0FF);
    for (var i = 0; i < 48; i++) {
      final sx = rng.nextInt(gridW);
      final sy = rng.nextInt(gridH);
      _px(c, sx, sy, starColor, ps: ps);
      if (rng.nextDouble() < 0.35) {
        _px(c, sx + 1, sy, starColor, ps: ps);
      }
      if (rng.nextDouble() < 0.25) {
        _px(c, sx, sy + 1, starColor, ps: ps);
      }
    }
  }

  /// Sandstorm — horizontal ochre gradient + diagonal streaks.
  static void _paintBgSandstorm(Canvas c, Size size) {
    const ps = 4.0;
    final gridW = (size.width / ps).floor();
    final gridH = (size.height / ps).floor();
    final stops = <MapEntry<double, Color>>[
      const MapEntry(0.0, Color(0xFF3D2817)),
      const MapEntry(0.35, Color(0xFF8B5A2B)),
      const MapEntry(0.7, Color(0xFFC9844F)),
      const MapEntry(1.0, Color(0xFFE5A876)),
    ];

    for (var y = 0; y < gridH; y++) {
      for (var x = 0; x < gridW; x++) {
        final base = _sampleGradient(x, y, gridW, gridH, false, stops);
        // 4 diagonal streaks — bands where the sand "dunes" show.
        final phase = (x + y) % 12;
        Color col = base;
        if (phase >= 4 && phase <= 6) {
          col = _mix(base, const Color(0xFFFFF1D6), 0.18);
        }
        _px(c, x, y, col, ps: ps);
      }
    }
  }

  static Color _mix(Color a, Color b, double t) {
    return Color.fromARGB(
      255,
      (a.r * 255 * (1 - t) + b.r * 255 * t).round().clamp(0, 255),
      (a.g * 255 * (1 - t) + b.g * 255 * t).round().clamp(0, 255),
      (a.b * 255 * (1 - t) + b.b * 255 * t).round().clamp(0, 255),
    );
  }

  /// NeonGrid — dark ground + 8-cell grid lines + faint intersections.
  static void _paintBgNeonGrid(Canvas c, Size size) {
    const ps = 4.0;
    final gridW = (size.width / ps).floor();
    final gridH = (size.height / ps).floor();
    const Color base = Color(0xFF0A0E1A);
    const Color line = Color(0xFF1A4060);

    for (var y = 0; y < gridH; y++) {
      for (var x = 0; x < gridW; x++) {
        Color col = base;
        // Vignette: cells farther from the centre get darker.
        final dx = x - gridW / 2;
        final dy = y - gridH / 2;
        final dist = math.sqrt(dx * dx + dy * dy);
        final maxD = math.sqrt(math.pow(gridW / 2, 2) + math.pow(gridH / 2, 2));
        final t = (dist / maxD).clamp(0.0, 1.0);
        col = _mix(col, const Color(0xFF03070D), t * 0.6);
        // Grid lines every 8 cells (mod == 0).
        if (x % 8 == 0 || y % 8 == 0) {
          col = _mix(col, const Color(0xFF4D9EFF), 0.35);
        }
        // Brighter dot at intersections.
        if (x % 8 == 0 && y % 8 == 0) {
          col = _mix(col, const Color(0xFF4D9EFF), 0.7);
        }
        // Unused colour selectors for lint.
        assert(line != base);
        _px(c, x, y, col, ps: ps);
      }
    }
  }

  /// Ocean — vertical blue gradient + 4 wave patterns.
  static void _paintBgOcean(Canvas c, Size size) {
    const ps = 4.0;
    final gridW = (size.width / ps).floor();
    final gridH = (size.height / ps).floor();
    final stops = <MapEntry<double, Color>>[
      const MapEntry(0.0, Color(0xFF001E3C)),
      const MapEntry(0.35, Color(0xFF003566)),
      const MapEntry(0.7, Color(0xFF1E5A8C)),
      const MapEntry(1.0, Color(0xFF4D9EFF)),
    ];

    for (var y = 0; y < gridH; y++) {
      for (var x = 0; x < gridW; x++) {
        final base = _sampleGradient(x, y, gridW, gridH, true, stops);
        // 4 wave lines — sine-modulated offset rows.
        final wave1 = ((math.sin((x / 6.0)) + 1) * 1.5).round();
        final wave2 = ((math.sin((x / 4.0 + 1)) + 1) * 2).round();
        Color col = base;
        if (y == gridH * 3 ~/ 7 + wave1 ||
            y == gridH * 4 ~/ 7 + wave2 ||
            y == gridH * 5 ~/ 7 + wave1) {
          col = _mix(base, const Color(0xFFFFFFFF), 0.15);
        }
        // Surface highlight at very top.
        if (y < 6) {
          col = _mix(base, const Color(0xFFEFF6FF), 0.25);
        }
        _px(c, x, y, col, ps: ps);
      }
    }
  }
}
