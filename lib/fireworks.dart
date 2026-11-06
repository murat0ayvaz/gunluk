import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'strings.dart';

// ---------------------------------------------------------------
// KUTLAMA: tüm hedefler tamamlanınca ~5,5 saniye oynar.
// Havai fişek (iz bırakan parçacıklar) + konfeti yağmuru +
// ortada büyüyen "Tebrikler!" yazısı + hafif titreşim.
// Dokunuşları engellemez. Eklenti kullanmaz (kendi çizimi).
// ---------------------------------------------------------------
class _Spark {
  final double angle; // yön (radyan)
  final double speed; // hız (ekran yüksekliğinin oranı)
  _Spark(this.angle, this.speed);
}

class _Burst {
  final double x; // 0..1 (genişlik oranı)
  final double y; // 0..1 (yükseklik oranı)
  final double start; // 0..1 (animasyon zamanı)
  final Color color;
  final Color color2; // ikinci renk (parçacıkların yarısı)
  final List<_Spark> sparks;
  _Burst(this.x, this.y, this.start, this.color, this.color2, this.sparks);
}

class _Confetti {
  final double x; // 0..1
  final double delay; // 0..0.5
  final double fall; // düşüş hızı çarpanı
  final double sway; // yana salınım
  final double spin; // dönüş hızı
  final double w;
  final double h;
  final Color color;
  _Confetti(this.x, this.delay, this.fall, this.sway, this.spin, this.w, this.h,
      this.color);
}

class FireworksOverlay extends StatefulWidget {
  final VoidCallback? onDone;
  const FireworksOverlay({super.key, this.onDone});

  @override
  State<FireworksOverlay> createState() => _FireworksOverlayState();
}

class _FireworksOverlayState extends State<FireworksOverlay>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 5500));
  late final List<_Burst> _bursts = _make();
  late final List<_Confetti> _conf = _makeConfetti();

  static const _colors = [
    Color(0xFFFFC857),
    Color(0xFFFF6B6B),
    Color(0xFF4ECDC4),
    Color(0xFF6C9EFF),
    Color(0xFFC77DFF),
    Color(0xFF7BE495),
    Color(0xFFFF9F5A),
    Color(0xFFFF7EB6),
  ];

  List<_Burst> _make() {
    final r = Random();
    return List.generate(13, (i) {
      final n = 34 + r.nextInt(16);
      return _Burst(
        0.12 + r.nextDouble() * 0.76,
        0.12 + r.nextDouble() * 0.42,
        i * 0.055 + r.nextDouble() * 0.04,
        _colors[r.nextInt(_colors.length)],
        _colors[r.nextInt(_colors.length)],
        List.generate(
            n,
            (k) => _Spark(k / n * 2 * pi + r.nextDouble() * 0.2,
                0.09 + r.nextDouble() * 0.15)),
      );
    });
  }

  List<_Confetti> _makeConfetti() {
    final r = Random();
    return List.generate(
        90,
        (i) => _Confetti(
              r.nextDouble(),
              r.nextDouble() * 0.45,
              0.75 + r.nextDouble() * 0.6,
              0.02 + r.nextDouble() * 0.05,
              (r.nextDouble() - 0.5) * 18,
              6 + r.nextDouble() * 6,
              10 + r.nextDouble() * 8,
              _colors[r.nextInt(_colors.length)],
            ));
  }

  @override
  void initState() {
    super.initState();
    HapticFeedback.mediumImpact();
    Future.delayed(const Duration(milliseconds: 280), () {
      HapticFeedback.lightImpact();
    });
    Future.delayed(const Duration(milliseconds: 700), () {
      HapticFeedback.lightImpact();
    });
    _c.forward().whenComplete(() {
      if (mounted) widget.onDone?.call();
    });
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return IgnorePointer(
      child: SizedBox.expand(
        child: AnimatedBuilder(
          animation: _c,
          builder: (context, _) {
            final t = _c.value;
            // yazı: 0..0.22 arası esneyerek büyür, 0.78'den sonra kaybolur
            final grow = Curves.elasticOut.transform((t / 0.22).clamp(0.0, 1.0));
            final fade = t < 0.78 ? 1.0 : (1 - (t - 0.78) / 0.22).clamp(0.0, 1.0);
            return Stack(
              fit: StackFit.expand,
              children: [
                CustomPaint(painter: _FwPainter(_bursts, _conf, t)),
                Center(
                  child: Opacity(
                    opacity: fade,
                    child: Transform.scale(
                      scale: 0.3 + 0.7 * grow,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text('🎉', style: TextStyle(fontSize: 64)),
                          Text(
                            tx('Tebrikler!'),
                            style: const TextStyle(
                              fontSize: 40,
                              fontWeight: FontWeight.w800,
                              color: Colors.white,
                              decoration: TextDecoration.none,
                              shadows: [
                                Shadow(blurRadius: 14, color: Color(0xCC000000)),
                                Shadow(
                                    blurRadius: 30, color: Color(0x99FFC857)),
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

class _FwPainter extends CustomPainter {
  final List<_Burst> bursts;
  final List<_Confetti> conf;
  final double t; // 0..1
  _FwPainter(this.bursts, this.conf, this.t);

  @override
  void paint(Canvas canvas, Size size) {
    // --- konfeti ---
    for (final c in conf) {
      final age = (t - c.delay) / 0.55;
      if (age < 0 || age > 1.25) continue;
      final y = -20 + age * (size.height + 60) * c.fall;
      final x = c.x * size.width + sin(age * 9 + c.x * 20) * c.sway * size.width;
      final op = age > 1 ? (1.25 - age) / 0.25 : 1.0;
      canvas.save();
      canvas.translate(x, y);
      canvas.rotate(age * c.spin);
      // dönerken ince görünsün (kâğıt etkisi)
      canvas.scale(1, 0.35 + 0.65 * cos(age * c.spin * 1.3).abs());
      canvas.drawRect(
          Rect.fromCenter(center: Offset.zero, width: c.w, height: c.h),
          Paint()..color = c.color.withOpacity(op.clamp(0.0, 1.0)));
      canvas.restore();
    }

    // --- havai fişek (her parçacığın arkasında iz) ---
    const life = 0.36; // bir patlamanın ömrü (animasyon zamanı cinsinden)
    for (final b in bursts) {
      final age = (t - b.start) / life;
      if (age < 0 || age > 1) continue;
      final fade = (1 - age).clamp(0.0, 1.0);
      final cx = b.x * size.width;
      final cy = b.y * size.height;
      // patlama anında kısa parlama
      if (age < 0.12) {
        canvas.drawCircle(
            Offset(cx, cy),
            46 * (1 - age / 0.12),
            Paint()
              ..color = Colors.white.withOpacity(0.55 * (1 - age / 0.12)));
      }
      var k = 0;
      for (final s in b.sparks) {
        final col = (k++ % 2 == 0) ? b.color : b.color2;
        for (var tr = 0; tr < 5; tr++) {
          final a2 = (age - tr * 0.025).clamp(0.0, 1.0);
          final ease = 1 - pow(1 - a2, 2).toDouble();
          final d = s.speed * size.height * 3 * ease;
          final x = cx + cos(s.angle) * d;
          final y = cy + sin(s.angle) * d + a2 * a2 * size.height * 0.07;
          final op = fade * (1 - tr * 0.2);
          canvas.drawCircle(
              Offset(x, y),
              (3.6 - tr * 0.5) * (1 - age * 0.5),
              Paint()..color = col.withOpacity(op.clamp(0.0, 1.0)));
        }
      }
    }
  }

  @override
  bool shouldRepaint(_FwPainter old) => old.t != t;
}
