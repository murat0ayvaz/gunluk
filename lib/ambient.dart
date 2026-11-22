import 'package:flutter/material.dart';
import 'data.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// AMBİYANS ARKA PLAN
//  Ana ekranın arkasında, tema renginin açık ve koyu tonları arasında yumuşak geçiş
//  ve iki geniş saydam dalga. Kartlar dolu renkte kaldığı için yazılar okunur.
//  Ayarlar > Ana ekran > "Ambiyans arka plan" ile kapatılır.
// ---------------------------------------------------------------
bool ambienceOn() => store.pBool('amb', true);

class AmbientBg extends StatelessWidget {
  const AmbientBg({super.key});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    Color mix(double o) => Color.alphaBlend(p.accent.withOpacity(o), p.bg);
    final a = p.dark ? [0.26, 0.09, 0.18] : [0.20, 0.06, 0.15];
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
          painter: _WavePainter(p.dark, p.accent),
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

class _WavePainter extends CustomPainter {
  final bool dark;
  final Color accent;
  _WavePainter(this.dark, this.accent);

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    // alttan akan geniş dalga
    final low = Path()
      ..moveTo(0, h * 0.52)
      ..cubicTo(w * 0.28, h * 0.64, w * 0.58, h * 0.88, w, h * 0.80)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    canvas.drawPath(
        low, Paint()..color = Colors.white.withOpacity(dark ? 0.035 : 0.30));
    final line = Path()
      ..moveTo(0, h * 0.52)
      ..cubicTo(w * 0.28, h * 0.64, w * 0.58, h * 0.88, w, h * 0.80);
    canvas.drawPath(
        line,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.6
          ..color = Colors.white.withOpacity(dark ? 0.10 : 0.65));
    // üstten gelen ince dalga
    final up = Path()
      ..moveTo(w, h * 0.14)
      ..cubicTo(w * 0.72, h * 0.30, w * 0.36, h * 0.08, 0, h * 0.26)
      ..lineTo(0, 0)
      ..lineTo(w, 0)
      ..close();
    canvas.drawPath(up, Paint()..color = accent.withOpacity(dark ? 0.07 : 0.07));
    final line2 = Path()
      ..moveTo(w, h * 0.14)
      ..cubicTo(w * 0.72, h * 0.30, w * 0.36, h * 0.08, 0, h * 0.26);
    canvas.drawPath(
        line2,
        Paint()
          ..style = PaintingStyle.stroke
          ..strokeWidth = 1.2
          ..color = Colors.white.withOpacity(dark ? 0.08 : 0.5));
  }

  @override
  bool shouldRepaint(_WavePainter o) => o.dark != dark || o.accent != accent;
}
