import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'data.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// AMBİYANS ARKA PLAN
//  Her sayfanın arkasında, o sayfanın rengine ait açık-koyu tonlar arasında yumuşak geçiş
//  ve saydam şekiller. Kartlar dolu renkte kaldığı için yazılar okunur.
//  Ana ekran: her açılışta / uygulamaya dönüşte şu şekillerden biri rastgele gelir:
//    R (iki dalga), D (dalga sol altta), D (dalga sol üstte), çapraz kalp (iki yöne yatık).
//  Hava durumu sayfası: güncel hava koduna göre güneş, bulut, yağmur, kar, sis, fırtına, gece.
//  Ayarlar > Ana ekran > "Ambiyans arka plan" ile hepsi birden kapatılır.
// ---------------------------------------------------------------
bool ambienceOn() => store.pBool('amb', true);

/// AppBar / Scaffold rengi: ambiyans açıkken saydam (arkadaki geçiş görünsün)
Color ambBg(Pal p) => ambienceOn() ? Colors.transparent : p.bg;

// kind -> (renk, şekil türü). Renk null ise temanın vurgu rengi kullanılır.
// Şekil türü 0 = ana ekran (rastgele R / D / kalp)
const Map<String, (Color?, int)> _kinds = {
  'home': (null, 0),
  'wallet': (Color(0xFF2FB38A), 1),
  'study': (Color(0xFF4F8EF7), 2),
  'media': (Color(0xFF9A6BF0), 3),
  'settings': (Color(0xFF6B8CA8), 4),
  'stats': (Color(0xFFF08A3C), 1),
  'diary': (Color(0xFFB36BD6), 2),
  'tools': (Color(0xFF17A9C4), 3),
  'short': (Color(0xFF5C6BC0), 4),
  'weather': (Color(0xFF3FA7E0), 1),
  'misc': (null, 2),
};

class AmbientBg extends StatefulWidget {
  final String kind;

  /// Doluysa hava durumu arka planı: (WMO hava kodu, gece mi)
  final (int, bool)? wx;
  const AmbientBg({super.key, this.kind = 'home', this.wx});

  @override
  State<AmbientBg> createState() => _AmbientBgState();
}

class _AmbientBgState extends State<AmbientBg> with WidgetsBindingObserver {
  int _v = 0; // ana ekran şekli: 0 R, 1 D-alt, 2 D-üst, 3 kalp sola, 4 kalp sağa

  @override
  void initState() {
    super.initState();
    _v = math.Random().nextInt(5);
    if (widget.kind == 'home') WidgetsBinding.instance.addObserver(this);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    // uygulamaya her dönüşte yeni şekil
    if (s == AppLifecycleState.resumed && mounted) {
      setState(() => _v = math.Random().nextInt(5));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final w = widget.wx;
    if (w != null) return _WxBg(code: w.$1, night: w.$2);
    final p = palOf(context);
    final k = _kinds[widget.kind] ?? _kinds['misc']!;
    final base = k.$1 ?? p.accent;
    Color mix(double o) => Color.alphaBlend(base.withOpacity(o), p.bg);
    // tonlar belirgin: açık temada 0.30'a, koyu temada 0.34'e kadar
    final a = p.dark ? [0.34, 0.12, 0.26] : [0.30, 0.10, 0.24];
    return IgnorePointer(
      child: DecoratedBox(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [mix(a[0]), mix(a[1]), mix(a[2])],
            stops: const [0.0, 0.5, 1.0],
          ),
        ),
        child: CustomPaint(
          painter: _ShapePainter(p.dark, base, k.$2, _v),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Scaffold yerine kullanılır: aynı alanlar + sayfaya özel ambiyans arka plan
class AmbScaffold extends StatelessWidget {
  final String kind;
  final (int, bool)? wx;
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  const AmbScaffold({
    super.key,
    this.kind = 'misc',
    this.wx,
    this.appBar,
    this.body,
    this.backgroundColor,
    this.floatingActionButton,
    this.endDrawer,
    this.bottomNavigationBar,
  });

  @override
  Widget build(BuildContext context) {
    if (!ambienceOn()) {
      return Scaffold(
        appBar: appBar,
        body: body,
        backgroundColor: backgroundColor,
        floatingActionButton: floatingActionButton,
        endDrawer: endDrawer,
        bottomNavigationBar: bottomNavigationBar,
      );
    }
    return Stack(
      fit: StackFit.expand,
      children: [
        Positioned.fill(child: AmbientBg(kind: kind, wx: wx)),
        Scaffold(
          backgroundColor: Colors.transparent,
          appBar: appBar,
          body: body,
          floatingActionButton: floatingActionButton,
          endDrawer: endDrawer,
          bottomNavigationBar: bottomNavigationBar,
        ),
      ],
    );
  }
}

/// Vurgu renginden türetilen köşe tonu (renk çemberinde kaydırma)
Color _shift(Color c, double deg, {double s = 0.7, double l = 0.62}) {
  final h = HSLColor.fromColor(c);
  return h
      .withHue((h.hue + deg) % 360)
      .withSaturation(s)
      .withLightness(l)
      .toColor();
}

class _ShapePainter extends CustomPainter {
  final bool dark;
  final Color accent;
  final int variant; // sayfa şekli türü (0 = ana ekran)
  final int home; // ana ekran şekli (0..4)
  _ShapePainter(this.dark, this.accent, this.variant, this.home);

  Paint _fill(double light, double dk, [Color? c]) =>
      Paint()..color = (c ?? Colors.white).withOpacity(dark ? dk : light);

  Paint _stroke(double w, double light, double dk, [Color? c]) => Paint()
    ..style = PaintingStyle.stroke
    ..strokeWidth = w
    ..strokeCap = StrokeCap.round
    ..color = (c ?? Colors.white).withOpacity(dark ? dk : light);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    switch (variant) {
      case 0:
        switch (home) {
          case 1:
            _dShape(canvas, w, h, true);
            break;
          case 2:
            _dShape(canvas, w, h, false);
            break;
          case 3:
            _upWave(canvas, w, h);
            _heart(canvas, w, h, -28);
            break;
          case 4:
            _upWave(canvas, w, h);
            _heart(canvas, w, h, 28);
            break;
          default:
            _waves(canvas, w, h);
        }
        break;
      case 1:
        _waves(canvas, w, h);
        break;
      case 2:
        _bands(canvas, w, h);
        break;
      case 3:
        _blobs(canvas, w, h);
        break;
      default:
        _stripes(canvas, w, h);
    }
  }

  // Üstten gelen ince dalga
  void _upWave(Canvas canvas, double w, double h) {
    final up = Path()
      ..moveTo(w, h * 0.14)
      ..cubicTo(w * 0.72, h * 0.30, w * 0.36, h * 0.08, 0, h * 0.26);
    final area = Path.from(up)
      ..lineTo(0, 0)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(area, _fill(0.10, 0.09, accent));
    canvas.drawPath(up, _stroke(1.2, 0.5, 0.10));
  }

  // Alttan akan geniş dalga + üstten ince dalga (ilk ambiyans, "R")
  void _waves(Canvas canvas, double w, double h) {
    final line = Path()
      ..moveTo(0, h * 0.52)
      ..cubicTo(w * 0.28, h * 0.64, w * 0.58, h * 0.88, w, h * 0.80);
    final low = Path.from(line)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(low, _fill(0.30, 0.04));
    canvas.drawPath(line, _stroke(1.6, 0.65, 0.12));
    _upWave(canvas, w, h);
  }

  // "D": soldan taşan geniş kavis; yuvarlağın içinde köşelerden farklı tonlar
  void _dShape(Canvas canvas, double w, double h, bool waveBottom) {
    final arc = Path()
      ..moveTo(w * 0.22, 0)
      ..cubicTo(w * 1.12, h * 0.10, w * 1.12, h * 0.90, w * 0.22, h);
    final inside = Path.from(arc)
      ..lineTo(0, h)
      ..lineTo(0, 0)
      ..close();
    final outside = Path.from(arc)
      ..lineTo(w, h)
      ..lineTo(w, 0)
      ..close();
    final rect = Rect.fromLTWH(0, 0, w, h);
    final op = dark ? 0.34 : 0.30;
    final t1 = _shift(accent, 40);
    final t2 = _shift(accent, -45, l: 0.6);
    final t3 = _shift(accent, 85);
    Shader rg(Alignment c, double r, Color col, double o) => RadialGradient(
          center: c,
          radius: r,
          colors: [col.withOpacity(o), col.withOpacity(0)],
        ).createShader(rect);
    canvas.drawPath(
        inside, Paint()..shader = rg(const Alignment(-1, -1), 0.95, t1, op));
    canvas.drawPath(inside,
        Paint()..shader = rg(const Alignment(0.8, -0.1), 0.75, t2, op * 0.9));
    canvas.drawPath(
        inside, Paint()..shader = rg(const Alignment(-1, 1), 1.05, t3, op));
    canvas.drawPath(outside, _fill(0.30, 0.04));
    canvas.drawPath(arc, _stroke(1.8, 0.70, 0.14));
    // karşı köşedeki dalga
    final Path wv;
    final Path area;
    if (waveBottom) {
      wv = Path()
        ..moveTo(0, h * 0.80)
        ..cubicTo(w * 0.30, h * 0.70, w * 0.60, h * 0.96, w, h * 0.88);
      area = Path.from(wv)
        ..lineTo(w, h)
        ..lineTo(0, h)
        ..close();
    } else {
      wv = Path()
        ..moveTo(0, h * 0.12)
        ..cubicTo(w * 0.18, h * 0.02, w * 0.34, h * 0.12, w * 0.40, 0);
      area = Path.from(wv)
        ..lineTo(0, 0)
        ..close();
    }
    canvas.drawPath(area, _fill(0.14, 0.12, accent));
    canvas.drawPath(wv, _stroke(1.4, 0.6, 0.12));
  }

  // Çapraz yatmış, iki yumrulu kalp: kenarlardan taşar, sadece ima eder
  void _heart(Canvas canvas, double w, double h, double deg) {
    canvas.save();
    canvas.translate(w * 0.5, h * 0.62);
    canvas.rotate(deg * math.pi / 180);
    canvas.translate(-w * 0.5, -h * 0.62);
    final top = Path()
      ..moveTo(-w * 0.15, h * 0.64)
      ..cubicTo(-w * 0.12, h * 0.42, w * 0.46, h * 0.40, w * 0.5, h * 0.62)
      ..cubicTo(w * 0.54, h * 0.40, w * 1.12, h * 0.42, w * 1.15, h * 0.64);
    final full = Path.from(top)
      ..cubicTo(w * 1.0, h * 0.95, w * 0.7, h * 1.12, w * 0.5, h * 1.22)
      ..cubicTo(w * 0.3, h * 1.12, 0, h * 0.95, -w * 0.15, h * 0.64)
      ..close();
    canvas.drawPath(full, _fill(0.30, 0.04));
    canvas.drawPath(top, _stroke(1.6, 0.65, 0.12));
    canvas.restore();
  }

  // Çapraz geniş bantlar
  void _bands(Canvas canvas, double w, double h) {
    for (var i = 0; i < 3; i++) {
      final y = h * (0.18 + i * 0.30);
      final p = Path()
        ..moveTo(0, y)
        ..cubicTo(w * 0.3, y - h * 0.10, w * 0.7, y + h * 0.12, w, y - h * 0.04)
        ..lineTo(w, y + h * 0.10)
        ..cubicTo(w * 0.7, y + h * 0.22, w * 0.3, y, 0, y + h * 0.14)
        ..close();
      canvas.drawPath(p, i.isEven ? _fill(0.28, 0.04) : _fill(0.10, 0.09, accent));
    }
  }

  // Yumuşak daireler
  void _blobs(Canvas canvas, double w, double h) {
    void c(double x, double y, double r, Paint p) =>
        canvas.drawCircle(Offset(x * w, y * h), r * w, p);
    c(0.85, 0.12, 0.38, _fill(0.10, 0.09, accent));
    c(0.10, 0.45, 0.30, _fill(0.24, 0.04));
    c(0.75, 0.80, 0.42, _fill(0.12, 0.09, accent));
    c(0.20, 0.95, 0.28, _fill(0.26, 0.04));
    canvas.drawCircle(Offset(0.85 * w, 0.12 * h), 0.38 * w, _stroke(1.2, 0.5, 0.10));
    canvas.drawCircle(Offset(0.75 * w, 0.80 * h), 0.42 * w, _stroke(1.2, 0.5, 0.10));
  }

  // Sakin yatay dalgalı çizgiler
  void _stripes(Canvas canvas, double w, double h) {
    for (var i = 0; i < 5; i++) {
      final y = h * (0.12 + i * 0.19);
      final p = Path()
        ..moveTo(0, y)
        ..cubicTo(w * 0.25, y - h * 0.04, w * 0.5, y + h * 0.05, w * 0.75, y - h * 0.02)
        ..cubicTo(w * 0.88, y - h * 0.05, w * 0.95, y, w, y + h * 0.01);
      canvas.drawPath(p, _stroke(i.isEven ? 22 : 10, i.isEven ? 0.20 : 0.45, i.isEven ? 0.03 : 0.09, i.isEven ? null : accent));
    }
  }

  @override
  bool shouldRepaint(_ShapePainter o) =>
      o.dark != dark ||
      o.accent != accent ||
      o.variant != variant ||
      o.home != home;
}

// ---------------------------------------------------------------
// HAVA DURUMU ARKA PLANI
//  Güncel hava koduna göre yavaş hareketli arka plan. Hareket 40 sn'lik tek döngüdür.
// ---------------------------------------------------------------

/// WMO hava kodu -> arka plan türü
String _wxKind(int code) {
  if (code == 0 || code == 1) return 'sun';
  if (code == 2) return 'part';
  if (code == 3) return 'cloud';
  if (code == 45 || code == 48) return 'fog';
  if ((code >= 51 && code <= 67) || (code >= 80 && code <= 82)) return 'rain';
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) return 'snow';
  if (code >= 95) return 'storm';
  return 'cloud';
}

/// Sözde rastgele (sabit) sayı: 0..1
double _h(num x) {
  final s = math.sin(x.toDouble() * 12.9898) * 43758.5453;
  return s - s.floorToDouble();
}

class _WxBg extends StatefulWidget {
  final int code;
  final bool night;
  const _WxBg({required this.code, required this.night});

  @override
  State<_WxBg> createState() => _WxBgState();
}

class _WxBgState extends State<_WxBg> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(seconds: 40))
        ..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final kind = _wxKind(widget.code);
    final night = widget.night;
    // (renk, opaklık) üçlüsü: sol üst, orta, sağ alt
    List<(Color, double)> t;
    if (night && (kind == 'sun' || kind == 'part' || kind == 'cloud' || kind == 'fog')) {
      t = const [
        (Color(0xFF1B2A5C), 0.50),
        (Color(0xFF0E1633), 0.22),
        (Color(0xFF243A7A), 0.42)
      ];
    } else {
      switch (kind) {
        case 'sun':
          t = const [
            (Color(0xFFF6B042), 0.36),
            (Color(0xFFFFE08A), 0.14),
            (Color(0xFFF59E42), 0.28)
          ];
          break;
        case 'part':
          t = const [
            (Color(0xFF4F8EF7), 0.32),
            (Color(0xFF9CC4F5), 0.12),
            (Color(0xFF6FA8E8), 0.24)
          ];
          break;
        case 'rain':
          t = const [
            (Color(0xFF4A5D78), 0.44),
            (Color(0xFF7A8CA6), 0.18),
            (Color(0xFF3F5068), 0.38)
          ];
          break;
        case 'storm':
          t = const [
            (Color(0xFF3B3F63), 0.50),
            (Color(0xFF6A6A9A), 0.18),
            (Color(0xFF2E3150), 0.44)
          ];
          break;
        case 'snow':
          t = const [
            (Color(0xFFA9CBE8), 0.42),
            (Color(0xFFE6F1FA), 0.18),
            (Color(0xFF93B8DA), 0.32)
          ];
          break;
        case 'fog':
          t = const [
            (Color(0xFFA8B0B8), 0.38),
            (Color(0xFFD5DAE0), 0.18),
            (Color(0xFF9AA2AB), 0.32)
          ];
          break;
        default:
          t = const [
            (Color(0xFF8895A5), 0.36),
            (Color(0xFFB4BDC8), 0.14),
            (Color(0xFF7C8795), 0.28)
          ];
      }
    }
    final extra = p.dark ? 0.06 : 0.0; // koyu temada biraz daha belirgin
    final cols = [
      for (final e in t)
        Color.alphaBlend(e.$1.withOpacity((e.$2 + extra).clamp(0.0, 1.0)), p.bg)
    ];
    return IgnorePointer(
      child: RepaintBoundary(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) => CustomPaint(
            painter: _WxPainter(kind, night, p.dark, _c.value, cols),
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

class _WxPainter extends CustomPainter {
  final String kind;
  final bool night, dark;
  final double t; // 0..1, 40 sn'lik döngü
  final List<Color> cols;
  _WxPainter(this.kind, this.night, this.dark, this.t, this.cols);

  void _halo(Canvas c, Offset o, double r, Color col, double op) {
    c.drawCircle(
        o,
        r,
        Paint()
          ..shader = RadialGradient(
                  colors: [col.withOpacity(op), col.withOpacity(0)])
              .createShader(Rect.fromCircle(center: o, radius: r)));
  }

  /// Tek parça (üst üste binmeyen) bulut şekli
  void _cloud(Canvas c, double cx, double cy, double s, double op) {
    final path = Path()
      ..addOval(Rect.fromCircle(center: Offset(cx, cy), radius: s * 0.5))
      ..addOval(
          Rect.fromCircle(center: Offset(cx + s * 0.5, cy + s * 0.1), radius: s * 0.6))
      ..addOval(
          Rect.fromCircle(center: Offset(cx - s * 0.5, cy + s * 0.15), radius: s * 0.4))
      ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(cx - s * 0.9, cy + s * 0.1, s * 1.8, s * 0.5),
          Radius.circular(s * 0.25)));
    c.drawPath(path, Paint()..color = Colors.white.withOpacity(op));
  }

  void _clouds(Canvas c, Size z, int n, double op, double speedK) {
    for (var i = 0; i < n; i++) {
      final s = z.width * (0.16 + _h(i * 3 + 1) * 0.12);
      final span = z.width + s * 3;
      final x = ((t * speedK + _h(i * 7 + 2)) % 1.0) * span - s * 1.5;
      final y = z.height * (0.08 + _h(i * 5 + 3) * 0.55);
      _cloud(c, x, y, s, op);
    }
  }

  void _rain(Canvas c, Size z, int n, {double speed = 1}) {
    final col = dark ? Colors.white : const Color(0xFF3E5A7C);
    final pt = Paint()
      ..strokeWidth = 1.2
      ..strokeCap = StrokeCap.round
      ..color = col.withOpacity(dark ? 0.30 : 0.38);
    for (var i = 0; i < n; i++) {
      final x = _h(i * 2 + 1) * z.width * 1.2 - z.width * 0.1;
      final sp = (12 + (i % 5) * 2) * speed;
      final y = ((t * sp + _h(i * 3 + 2)) % 1.0) * (z.height + 60) - 30;
      c.drawLine(Offset(x, y), Offset(x - 5, y + 16), pt);
    }
  }

  void _snow(Canvas c, Size z, int n) {
    final col = dark ? Colors.white : const Color(0xFF8DB6DD);
    for (var i = 0; i < n; i++) {
      final sp = 4 + (i % 4);
      final x = _h(i * 2 + 1) * z.width +
          math.sin(t * 2 * math.pi * 2 + _h(i + 5) * 6) * 14;
      final y = ((t * sp + _h(i * 3 + 2)) % 1.0) * (z.height + 20) - 10;
      final r = 1.5 + _h(i * 4 + 3) * 2.5;
      c.drawCircle(Offset(x, y), r, Paint()..color = col.withOpacity(dark ? 0.55 : 0.70));
    }
  }

  void _stars(Canvas c, Size z) {
    for (var i = 0; i < 40; i++) {
      final x = _h(i * 2 + 1) * z.width;
      final y = _h(i * 5 + 2) * z.height * 0.7;
      final tw = 0.5 + 0.5 * math.sin(t * 2 * math.pi * 3 + _h(i + 9) * 6.28);
      c.drawCircle(Offset(x, y), 0.8 + _h(i + 3) * 0.9,
          Paint()..color = Colors.white.withOpacity(0.25 + 0.6 * tw));
    }
  }

  void _fog(Canvas c, Size z) {
    final op = dark ? 0.08 : 0.24;
    for (var i = 0; i < 4; i++) {
      final cx = z.width * 0.5 + math.sin(t * 2 * math.pi + i * 1.7) * z.width * 0.15;
      final cy = z.height * (0.18 + i * 0.22);
      c.drawOval(
          Rect.fromCenter(
              center: Offset(cx, cy), width: z.width * 1.5, height: z.height * 0.16),
          Paint()
            ..color = Colors.white.withOpacity(op)
            ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 30));
    }
  }

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final rect = Offset.zero & size;
    canvas.drawRect(
        rect,
        Paint()
          ..shader = LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: cols,
            stops: const [0.0, 0.5, 1.0],
          ).createShader(rect));
    final cloudOp = dark ? 0.07 : 0.34;
    switch (kind) {
      case 'sun':
        if (night) {
          _stars(canvas, size);
          _halo(canvas, Offset(w * 0.8, h * 0.12), w * 0.38,
              const Color(0xFFFFF3C4), 0.22);
          canvas.drawCircle(Offset(w * 0.8, h * 0.12), w * 0.055,
              Paint()..color = const Color(0xFFFFF3C4).withOpacity(0.75));
        } else {
          final pulse = 1 + 0.04 * math.sin(t * 2 * math.pi * 2);
          final o = Offset(w * 0.82, h * 0.10);
          _halo(canvas, o, w * 0.60 * pulse, const Color(0xFFFFE08A), dark ? 0.30 : 0.60);
          for (var i = 0; i < 3; i++) {
            final u = (t * 2 + i / 3) % 1.0;
            canvas.drawCircle(
                o,
                w * (0.16 + 0.34 * u),
                Paint()
                  ..style = PaintingStyle.stroke
                  ..strokeWidth = 1.4
                  ..color = Colors.white.withOpacity((dark ? 0.16 : 0.55) * (1 - u)));
          }
        }
        break;
      case 'part':
        if (night) {
          _stars(canvas, size);
        } else {
          _halo(canvas, Offset(w * 0.82, h * 0.10), w * 0.45,
              const Color(0xFFFFE08A), dark ? 0.18 : 0.40);
        }
        _clouds(canvas, size, 3, cloudOp, 1);
        break;
      case 'cloud':
        _clouds(canvas, size, 6, cloudOp, 1);
        break;
      case 'fog':
        _fog(canvas, size);
        break;
      case 'rain':
        _clouds(canvas, size, 3, dark ? 0.06 : 0.20, 1);
        _rain(canvas, size, 46);
        break;
      case 'storm':
        _clouds(canvas, size, 4, dark ? 0.06 : 0.20, 1);
        _rain(canvas, size, 70, speed: 1.3);
        // 40 sn'de 3 kısa şimşek parlaması
        var f = 0.0;
        for (final c0 in const [0.12, 0.47, 0.78]) {
          final d = (t - c0).abs();
          if (d < 0.012) f = math.max(f, 1 - d / 0.012);
        }
        if (f > 0) {
          canvas.drawRect(rect,
              Paint()..color = Colors.white.withOpacity((dark ? 0.12 : 0.18) * f));
        }
        break;
      case 'snow':
        _snow(canvas, size, 40);
        break;
    }
  }

  @override
  bool shouldRepaint(_WxPainter o) => true;
}
