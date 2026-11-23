import 'package:flutter/material.dart';
import 'data.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// AMBİYANS ARKA PLAN
//  Her sayfanın arkasında, o sayfanın rengine ait açık-koyu tonlar arasında yumuşak geçiş
//  ve saydam şekiller. Ana ekranda şekiller "D" ve "R" harflerinin akışkan şeritleridir.
//  Kartlar dolu renkte kaldığı için yazılar okunur.
//  Ayarlar > Ana ekran > "Ambiyans arka plan" ile hepsi birden kapatılır.
// ---------------------------------------------------------------
bool ambienceOn() => store.pBool('amb', true);

/// AppBar / Scaffold rengi: ambiyans açıkken saydam (arkadaki geçiş görünsün)
Color ambBg(Pal p) => ambienceOn() ? Colors.transparent : p.bg;

// kind -> (renk, şekil türü). Renk null ise temanın vurgu rengi kullanılır.
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

class AmbientBg extends StatelessWidget {
  final String kind;
  const AmbientBg({super.key, this.kind = 'home'});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final k = _kinds[kind] ?? _kinds['misc']!;
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
          painter: _ShapePainter(p.dark, base, k.$2),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// Scaffold yerine kullanılır: aynı alanlar + sayfaya özel ambiyans arka plan
class AmbScaffold extends StatelessWidget {
  final String kind;
  final PreferredSizeWidget? appBar;
  final Widget? body;
  final Color? backgroundColor;
  final Widget? floatingActionButton;
  final Widget? endDrawer;
  final Widget? bottomNavigationBar;
  const AmbScaffold({
    super.key,
    this.kind = 'misc',
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
        Positioned.fill(child: AmbientBg(kind: kind)),
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

class _ShapePainter extends CustomPainter {
  final bool dark;
  final Color accent;
  final int variant;
  _ShapePainter(this.dark, this.accent, this.variant);

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
        _letters(canvas, w, h);
        _waves(canvas, w, h);
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

  // Alttan akan geniş dalga + üstten ince dalga
  void _waves(Canvas canvas, double w, double h) {
    final low = Path()
      ..moveTo(0, h * 0.52)
      ..cubicTo(w * 0.28, h * 0.64, w * 0.58, h * 0.88, w, h * 0.80)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(low, _fill(0.30, 0.04));
    final line = Path()
      ..moveTo(0, h * 0.52)
      ..cubicTo(w * 0.28, h * 0.64, w * 0.58, h * 0.88, w, h * 0.80);
    canvas.drawPath(line, _stroke(1.6, 0.65, 0.12));
    final up = Path()
      ..moveTo(w, h * 0.14)
      ..cubicTo(w * 0.72, h * 0.30, w * 0.36, h * 0.08, 0, h * 0.26)
      ..lineTo(0, 0)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(up, _fill(0.10, 0.09, accent));
    final line2 = Path()
      ..moveTo(w, h * 0.14)
      ..cubicTo(w * 0.72, h * 0.30, w * 0.36, h * 0.08, 0, h * 0.26);
    canvas.drawPath(line2, _stroke(1.2, 0.5, 0.10));
  }

  // Ana ekran: "D" ve "R" harflerinin akışkan, yumuşak şeritleri
  void _letters(Canvas canvas, double w, double h) {
    final sw = w * 0.075; // şerit kalınlığı
    void ribbon(Path unit, Rect box, double rot) {
      canvas.save();
      canvas.translate(box.center.dx, box.center.dy);
      canvas.rotate(rot);
      canvas.translate(-box.width / 2, -box.height / 2);
      canvas.scale(box.width, box.height);
      // birim kutudaki yol, gerçek boyuta ölçeklenince kalınlık da ölçeklenir: tersiyle düzelt
      final sx = box.width, sy = box.height;
      final m = (sx + sy) / 2;
      final soft = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeJoin = StrokeJoin.round
        ..strokeWidth = sw / m
        ..maskFilter = MaskFilter.blur(BlurStyle.normal, 5 / m)
        ..shader = LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            accent.withOpacity(dark ? 0.30 : 0.30),
            Colors.white.withOpacity(dark ? 0.12 : 0.55),
          ],
        ).createShader(const Rect.fromLTWH(0, 0, 1, 1));
      canvas.drawPath(unit, soft);
      final edge = Paint()
        ..style = PaintingStyle.stroke
        ..strokeCap = StrokeCap.round
        ..strokeWidth = 1.4 / m
        ..color = Colors.white.withOpacity(dark ? 0.14 : 0.7);
      canvas.drawPath(unit, edge);
      canvas.restore();
    }

    final d = Path()
      ..moveTo(0.20, 0.04)
      ..cubicTo(0.10, 0.35, 0.12, 0.65, 0.20, 0.96)
      ..moveTo(0.20, 0.04)
      ..cubicTo(0.98, 0.0, 1.02, 1.0, 0.20, 0.96);
    final r = Path()
      ..moveTo(0.20, 0.04)
      ..cubicTo(0.10, 0.35, 0.12, 0.65, 0.20, 0.96)
      ..moveTo(0.20, 0.04)
      ..cubicTo(0.98, 0.0, 0.96, 0.56, 0.20, 0.52)
      ..moveTo(0.44, 0.52)
      ..cubicTo(0.58, 0.70, 0.78, 0.86, 1.0, 0.98);
    ribbon(d, Rect.fromLTWH(w * 0.05, h * 0.24, w * 0.46, h * 0.30), -0.14);
    ribbon(r, Rect.fromLTWH(w * 0.46, h * 0.50, w * 0.48, h * 0.32), 0.10);
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
      o.dark != dark || o.accent != accent || o.variant != variant;
}
