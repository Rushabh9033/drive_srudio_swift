import 'package:flutter/painting.dart';

import '../models/models.dart';
import 'layer_factory.dart';

/// Category used by the executable Apex stock collection.
const apexTemplateCategory = 'Apex';

const _createdAt = '2026-08-08';
const _bg0 = '#05080C';
const _bg1 = '#101720';
const _panel = '#0D141C';
const _line = '#26313D';
const _text = '#F7F9FC';
const _muted = '#7E8A98';
const _cyan = '#66D9FF';
const _volt = '#A8FF60';
const _amber = '#FFB55C';
const _violet = '#BDA6FF';

/// Twelve code-native, editable V2 templates.
///
/// This catalogue intentionally uses only layer kinds that the current Flutter
/// canvas and common WidgetKit renderer both implement. Runtime values come
/// from [LayerKind.clock], [LayerKind.date], and [LayerKind.battery]. It does
/// not use weather, cabin temperature, vehicle range/telemetry, Spotify data,
/// or unimplemented semantic roles.
List<TemplateItem> buildApexWidgetTemplates() => [
  _template(
    id: 'apex-pulse-clock',
    name: 'Pulse Clock',
    premium: false,
    layers: [
      _panelLayer(),
      _dot(x: 10, y: 11, color: _cyan),
      _label('LOCAL TIME', x: 16, y: 9, w: 48),
      _label('24 HOUR', x: 68, y: 9, w: 22, align: TextAlign.right),
      _clock(x: 10, y: 28, w: 80, h: 23, size: 58),
      _divider(x: 10, y: 64, w: 80),
      _date(x: 10, y: 72, w: 80, h: 9, size: 16),
      _rail(x: 34, y: 87, w: 32, color: _cyan),
    ],
  ),
  _template(
    id: 'apex-calendar-focus',
    name: 'Calendar Focus',
    premium: false,
    layers: [
      _panelLayer(),
      _shape(x: 8, y: 8, w: 5, h: 5, color: _violet, radius: 50),
      _label('TODAY', x: 16, y: 8, w: 32, color: _violet),
      _label('CALENDAR', x: 62, y: 8, w: 28, align: TextAlign.right),
      _date(x: 9, y: 29, w: 82, h: 18, size: 28),
      _divider(x: 14, y: 57, w: 72, color: '#302A42'),
      _label('CURRENT TIME', x: 10, y: 67, w: 35),
      _clock(
        x: 48,
        y: 64,
        w: 42,
        h: 13,
        size: 29,
        align: TextAlign.right,
        color: _violet,
      ),
      _rail(x: 10, y: 86, w: 80, color: _violet),
    ],
  ),
  _template(
    id: 'apex-phone-energy',
    name: 'Phone Energy',
    premium: false,
    layers: [
      _panelLayer(),
      _label('IPHONE POWER', x: 10, y: 9, w: 48, color: _volt),
      _label('DEVICE', x: 68, y: 9, w: 22, align: TextAlign.right),
      _battery(x: 13, y: 26, w: 74, h: 25, size: 32, color: _volt),
      _divider(x: 10, y: 62, w: 80, color: '#26372B'),
      _label('UPDATED BY IPHONE', x: 10, y: 71, w: 47),
      _date(x: 56, y: 68, w: 34, h: 9, size: 14, align: TextAlign.right),
      _rail(x: 10, y: 86, w: 52, color: _volt),
      _rail(x: 64, y: 86, w: 26, color: '#24302A'),
    ],
  ),
  _template(
    id: 'apex-drive-deck',
    name: 'Drive Deck',
    premium: false,
    layers: [
      _panelLayer(),
      _label('DRIVE DECK', x: 10, y: 9, w: 40, color: _cyan),
      _dot(x: 86, y: 11, color: _cyan),
      _clock(x: 10, y: 25, w: 80, h: 19, size: 48),
      _divider(x: 10, y: 53, w: 80),
      _label('PHONE', x: 10, y: 62, w: 20),
      _battery(x: 10, y: 69, w: 38, h: 12, size: 18, color: _cyan),
      _label('DATE', x: 55, y: 62, w: 35, align: TextAlign.right),
      _date(x: 50, y: 70, w: 40, h: 10, size: 14, align: TextAlign.right),
      _rail(x: 10, y: 88, w: 80, color: _cyan),
    ],
  ),
  _template(
    id: 'apex-minimal-time',
    name: 'Minimal Time',
    premium: true,
    backgroundFrom: '#07090C',
    backgroundTo: '#0B0F14',
    layers: [
      _shape(x: 8, y: 8, w: 84, h: 84, color: '#090D12', radius: 18),
      _rail(x: 10, y: 10, w: 18, color: _cyan),
      _clock(x: 9, y: 31, w: 82, h: 23, size: 60),
      _date(x: 16, y: 68, w: 68, h: 9, size: 15, color: _muted),
      _label('APEX', x: 36, y: 84, w: 28, align: TextAlign.center),
    ],
  ),
  _template(
    id: 'apex-split-status',
    name: 'Split Status',
    premium: true,
    layers: [
      _panelLayer(),
      _label('TIME', x: 10, y: 9, w: 35, color: _amber),
      _label('POWER', x: 55, y: 9, w: 35, color: _amber),
      _divider(x: 49.7, y: 19, w: 0.6, h: 62, color: '#3A3025'),
      _clock(x: 8, y: 31, w: 38, h: 18, size: 33, align: TextAlign.center),
      _battery(x: 54, y: 31, w: 38, h: 18, size: 24, color: _amber),
      _date(x: 12, y: 69, w: 76, h: 9, size: 14, color: _muted),
      _rail(x: 10, y: 87, w: 35, color: _amber),
      _rail(x: 55, y: 87, w: 35, color: '#3A3025'),
    ],
  ),
  _template(
    id: 'apex-charge-orbit',
    name: 'Charge Orbit',
    premium: true,
    layers: [
      _panelLayer(),
      _shape(x: 23, y: 18, w: 54, h: 54, color: '#172019', radius: 50),
      _shape(x: 29, y: 24, w: 42, h: 42, color: _panel, radius: 50),
      _battery(x: 31, y: 37, w: 38, h: 14, size: 22, color: _volt),
      _dot(x: 48, y: 14, color: _volt, size: 4),
      _label(
        'PHONE ENERGY',
        x: 25,
        y: 76,
        w: 50,
        color: _volt,
        align: TextAlign.center,
      ),
      _clock(x: 30, y: 84, w: 40, h: 8, size: 15, align: TextAlign.center),
    ],
  ),
  _template(
    id: 'apex-nightline',
    name: 'Nightline',
    premium: true,
    backgroundFrom: '#07070C',
    backgroundTo: '#141020',
    layers: [
      _shape(x: 6, y: 6, w: 88, h: 88, color: '#0C0B13', radius: 20),
      _shape(x: 8, y: 8, w: 2, h: 84, color: _violet, radius: 2),
      _label('NIGHTLINE', x: 15, y: 10, w: 44, color: _violet),
      _clock(x: 15, y: 29, w: 75, h: 23, size: 56),
      _divider(x: 15, y: 63, w: 75, color: '#322A43'),
      _date(x: 15, y: 72, w: 75, h: 9, size: 15, align: TextAlign.left),
      _dot(x: 85, y: 84, color: _violet),
    ],
  ),
  _template(
    id: 'apex-date-focus',
    name: 'Date Focus',
    premium: true,
    layers: [
      _panelLayer(),
      _label('DATE FOCUS', x: 10, y: 9, w: 40, color: _violet),
      _rail(x: 65, y: 11, w: 25, color: _violet),
      _date(x: 9, y: 30, w: 82, h: 18, size: 29),
      _divider(x: 10, y: 59, w: 80),
      _label('LOCAL', x: 10, y: 69, w: 22),
      _clock(
        x: 38,
        y: 66,
        w: 52,
        h: 13,
        size: 29,
        color: _violet,
        align: TextAlign.right,
      ),
      _shape(x: 10, y: 86, w: 80, h: 2, color: '#241F30', radius: 2),
      _shape(x: 10, y: 86, w: 46, h: 2, color: _violet, radius: 2),
    ],
  ),
  _template(
    id: 'apex-volt-panel',
    name: 'Volt Panel',
    premium: true,
    layers: [
      _panelLayer(),
      _shape(x: 8, y: 8, w: 84, h: 16, color: '#142019', radius: 8),
      _label('IPHONE STATUS', x: 13, y: 11, w: 44, color: _volt),
      _dot(x: 85, y: 13, color: _volt),
      _battery(x: 12, y: 34, w: 76, h: 22, size: 30, color: _volt),
      _divider(x: 12, y: 66, w: 76, color: '#2B382F'),
      _date(x: 12, y: 75, w: 46, h: 9, size: 14, align: TextAlign.left),
      _clock(x: 61, y: 74, w: 27, h: 9, size: 17, align: TextAlign.right),
    ],
  ),
  _template(
    id: 'apex-horizon-time',
    name: 'Horizon Time',
    premium: true,
    layers: [
      _shape(x: 6, y: 6, w: 88, h: 88, color: '#091019', radius: 19),
      _label('HORIZON', x: 10, y: 10, w: 35, color: _cyan),
      _shape(x: 68, y: 12, w: 22, h: 1, color: _cyan, radius: 2),
      _clock(x: 10, y: 31, w: 80, h: 22, size: 57),
      _shape(x: 10, y: 62, w: 80, h: 2, color: '#192D3A', radius: 2),
      _shape(x: 10, y: 62, w: 58, h: 2, color: _cyan, radius: 2),
      _date(x: 10, y: 73, w: 80, h: 9, size: 15, align: TextAlign.center),
      _label('LOCAL DEVICE TIME', x: 25, y: 86, w: 50, align: TextAlign.center),
    ],
  ),
  _template(
    id: 'apex-essential',
    name: 'Apex Essential',
    premium: true,
    layers: [
      _panelLayer(),
      _label('APEX ESSENTIAL', x: 10, y: 9, w: 52, color: _cyan),
      _clock(x: 10, y: 25, w: 80, h: 19, size: 48),
      _date(x: 10, y: 50, w: 80, h: 9, size: 14, color: _muted),
      _divider(x: 10, y: 64, w: 80),
      _label('PHONE', x: 10, y: 73, w: 25),
      _battery(x: 46, y: 70, w: 44, h: 12, size: 19, color: _cyan),
      _shape(x: 10, y: 88, w: 80, h: 1.5, color: '#1B2A34', radius: 2),
      _shape(x: 10, y: 88, w: 34, h: 1.5, color: _cyan, radius: 2),
    ],
  ),
];

TemplateItem _template({
  required String id,
  required String name,
  required bool premium,
  required List<Layer> layers,
  String backgroundFrom = _bg0,
  String backgroundTo = _bg1,
}) {
  return TemplateItem(
    id: id,
    name: name,
    category: apexTemplateCategory,
    premium: premium,
    createdAt: _createdAt,
    spec: WidgetSpec(
      background: WidgetBackground(
        type: BgType.gradient,
        from: backgroundFrom,
        to: backgroundTo,
      ),
      layers: layers,
    ),
  );
}

Layer _panelLayer() =>
    _shape(x: 5, y: 5, w: 90, h: 90, color: _panel, radius: 18);

Layer _label(
  String value, {
  required double x,
  required double y,
  required double w,
  double h = 6,
  double size = 11,
  String color = _muted,
  TextAlign align = TextAlign.left,
}) => _textLayer(
  value,
  x: x,
  y: y,
  w: w,
  h: h,
  size: size,
  weight: 700,
  color: color,
  align: align,
);

Layer _textLayer(
  String value, {
  required double x,
  required double y,
  required double w,
  required double h,
  required double size,
  int weight = 600,
  String color = _text,
  TextAlign align = TextAlign.left,
}) => baseLayer(
  LayerKind.text,
  overrides: {
    'label': value,
    'text': value,
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'fontSize': size,
    'weight': weight,
    'color': color,
  },
).copyWith(align: align, maxLines: 1, animate: false, animStyle: '');

Layer _clock({
  required double x,
  required double y,
  required double w,
  required double h,
  required double size,
  String color = _text,
  TextAlign align = TextAlign.center,
}) => baseLayer(
  LayerKind.clock,
  overrides: {
    'label': 'Current time',
    'text': '',
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'fontSize': size,
    'weight': 700,
    'color': color,
    'format': '24',
    'animate': false,
    'animStyle': '',
    'showSeconds': false,
  },
).copyWith(align: align, maxLines: 1);

Layer _date({
  required double x,
  required double y,
  required double w,
  required double h,
  required double size,
  String color = _text,
  TextAlign align = TextAlign.center,
}) => baseLayer(
  LayerKind.date,
  overrides: {
    'label': 'Current date',
    'text': '',
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'fontSize': size,
    'weight': 600,
    'color': color,
    'format': 'abbrev',
    'animate': false,
    'animStyle': '',
  },
).copyWith(align: align, maxLines: 1);

Layer _battery({
  required double x,
  required double y,
  required double w,
  required double h,
  required double size,
  String color = _cyan,
}) => baseLayer(
  LayerKind.battery,
  overrides: {
    'label': 'iPhone battery',
    'text': '',
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'fontSize': size,
    'weight': 700,
    'color': color,
    'format': 'minimal',
    'animate': false,
    'animStyle': '',
  },
).copyWith(align: TextAlign.center);

Layer _divider({
  required double x,
  required double y,
  required double w,
  double h = 1,
  String color = _line,
}) => baseLayer(
  LayerKind.divider,
  overrides: {
    'label': 'Divider',
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'color': color,
    'animate': false,
    'animStyle': '',
  },
);

Layer _rail({
  required double x,
  required double y,
  required double w,
  required String color,
}) => _shape(x: x, y: y, w: w, h: 1.5, color: color, radius: 2);

Layer _dot({
  required double x,
  required double y,
  required String color,
  double size = 3,
}) => _shape(x: x, y: y, w: size, h: size, color: color, radius: 50);

Layer _shape({
  required double x,
  required double y,
  required double w,
  required double h,
  required String color,
  required double radius,
}) => baseLayer(
  LayerKind.shape,
  overrides: {
    'label': 'Decoration',
    'x': x,
    'y': y,
    'w': w,
    'h': h,
    'color': color,
    'radius': radius,
    'animate': false,
    'animStyle': '',
  },
);
