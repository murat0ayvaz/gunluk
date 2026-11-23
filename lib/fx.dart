import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'data.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// SATIR EFEKTLERİ
//  Düzey (Ayarlar > Ana ekran > Satır efektleri): 0 kapalı, 1 hafif, 2 göz alıcı.
//  - Işık süzülmesi: satırın üzerinden zaman zaman parlak bir ışık dalgası geçer
//  - Hedef tamam parlaması: hedefi dolan satırın kenarı yeşil parlar
//  - Dokunma dalgası: dokunulan noktadan halka yayılır
//  - Giriş parlaması: değer girilince satırdan yeşil ışık geçer
//  - Eklenen satır yukarıdan süzülerek yerine oturur
//  - Kaydırırken silme / düzenleme rengi dolar (FxFillBg)
// ---------------------------------------------------------------
int fxLevel() => store.pInt('fx', 1).clamp(0, 2).toInt();

int _fxAddedAt = 0;

/// Yeni satır eklendiğinde çağrılır (satır, giriş animasyonuyla görünür)
void fxMarkAdded() => _fxAddedAt = DateTime.now().millisecondsSinceEpoch;

const _green = Color(0xFF2FB38A);

class FxShine extends StatefulWidget {
  final Widget child;
  final double radius;
  final bool met; // hedef tamam
  final Object? flashKey; // değişince giriş parlaması oynar
  final int phase; // satırlar aynı anda parlamasın diye kaydırma
  const FxShine({
    super.key,
    required this.child,
    this.radius = 14,
    this.met = false,
    this.flashKey,
    this.phase = 0,
  });

  @override
  State<FxShine> createState() => _FxShineState();
}

class _FxShineState extends State<FxShine> with TickerProviderStateMixin {
  AnimationController? _loop;
  late final AnimationController _flash = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 750));
  late final AnimationController _rip = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 550));
  late final AnimationController _in = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 420), value: 1);
  Offset _tap = Offset.zero;
  int _lv = 0;

  @override
  void initState() {
    super.initState();
    if (fxLevel() > 0 &&
        DateTime.now().millisecondsSinceEpoch - _fxAddedAt < 900) {
      _in.forward(from: 0); // yeni eklenen satır
    }
    _sync();
  }

  @override
  void didUpdateWidget(FxShine old) {
    super.didUpdateWidget(old);
    if (old.flashKey != widget.flashKey && widget.flashKey != null && fxLevel() > 0) {
      _flash.forward(from: 0);
    }
    _sync();
  }

  // Düzey değişince (ayar) döngüyü kur / kaldır
  void _sync() {
    final lv = fxLevel();
    if (lv == _lv) return;
    _lv = lv;
    _loop?.dispose();
    _loop = null;
    if (lv > 0) {
      _loop = AnimationController(
          vsync: this, duration: Duration(milliseconds: lv == 2 ? 3800 : 7600))
        ..value = ((widget.phase * 0.19) % 1.0)
        ..repeat();
    }
  }

  @override
  void dispose() {
    _loop?.dispose();
    _flash.dispose();
    _rip.dispose();
    _in.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final lv = fxLevel();
    if (lv == 0) return widget.child;
    if (_loop == null) _sync();
    final p = palOf(context);
    final anims = <Listenable>[
      if (_loop != null) _loop!,
      _flash,
      _rip,
      _in,
    ];
    return Listener(
      behavior: HitTestBehavior.translucent,
      onPointerDown: (e) {
        _tap = e.localPosition;
        _rip.forward(from: 0);
      },
      child: AnimatedBuilder(
        animation: Listenable.merge(anims),
        builder: (context, child) {
          final t = Curves.easeOut.transform(_in.value);
          return Opacity(
            opacity: t,
            child: Transform.translate(
              offset: Offset(0, (1 - t) * -14),
              child: Stack(
                children: [
                  child!,
                  Positioned.fill(
                    child: IgnorePointer(
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(widget.radius),
                        child: CustomPaint(
                          painter: _FxPainter(
                            level: lv,
                            phase: _loop?.value ?? 0,
                            met: widget.met,
                            flash: _flash.isAnimating ? _flash.value : -1,
                            ripple: _rip.isAnimating ? _rip.value : -1,
                            tap: _tap,
                            tint: p.dark ? Colors.white : p.accent,
                            dark: p.dark,
                            accent: p.accent,
                            radius: widget.radius,
                          ),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
        child: widget.child,
      ),
    );
  }
}

class _FxPainter extends CustomPainter {
  final int level;
  final double phase, flash, ripple;
  final bool met, dark;
  final Offset tap;
  final Color tint, accent;
  final double radius;
  _FxPainter({
    required this.level,
    required this.phase,
    required this.met,
    required this.flash,
    required this.ripple,
    required this.tap,
    required this.tint,
    required this.dark,
    required this.accent,
    required this.radius,
  });

  void _band(Canvas c, Size s, double u, Color col, double op, double widthF) {
    final bw = s.width * widthF;
    final x = -bw + (s.width + bw) * u;
    final skew = s.height * 0.5;
    final path = Path()
      ..moveTo(x + skew, 0)
      ..lineTo(x + bw + skew, 0)
      ..lineTo(x + bw, s.height)
      ..lineTo(x, s.height)
      ..close();
    c.drawPath(
        path,
        Paint()
          ..shader = LinearGradient(colors: [
            col.withOpacity(0),
            col.withOpacity(op),
            col.withOpacity(0),
          ]).createShader(Rect.fromLTWH(x, 0, bw + skew, s.height)));
  }

  @override
  void paint(Canvas canvas, Size size) {
    // 1) Işık süzülmesi: döngünün başında bir geçiş, kalanında bekleme
    final frac = level == 2 ? 0.34 : 0.20;
    if (phase < frac) {
      final u = Curves.easeInOut.transform(phase / frac);
      _band(canvas, size, u, tint, level == 2 ? (dark ? 0.30 : 0.34) : (dark ? 0.16 : 0.20), 0.36);
    }
    // 2) Hedef tamam: yeşil kenar parlaması
    if (met) {
      final a = level == 2 ? 0.40 + 0.35 * math.sin(phase * 2 * math.pi) : 0.50;
      canvas.drawRRect(
          RRect.fromRectAndRadius(
              (Offset.zero & size).deflate(1), Radius.circular(radius)),
          Paint()
            ..style = PaintingStyle.stroke
            ..strokeWidth = level == 2 ? 2.4 : 1.8
            ..color = _green.withOpacity(a.clamp(0.0, 1.0)));
    }
    // 3) Giriş parlaması
    if (flash >= 0) {
      _band(canvas, size, Curves.easeOut.transform(flash), _green, 0.55, 0.5);
      canvas.drawRect(Offset.zero & size,
          Paint()..color = _green.withOpacity(0.18 * (1 - flash)));
    }
    // 4) Dokunma dalgası
    if (ripple >= 0) {
      final r = size.width * 0.55 * Curves.easeOut.transform(ripple);
      canvas.drawCircle(tap, r,
          Paint()..color = accent.withOpacity((level == 2 ? 0.26 : 0.16) * (1 - ripple)));
    }
  }

  @override
  bool shouldRepaint(_FxPainter o) => true;
}

/// Kaydırırken dolan arka plan: ilerledikçe renk koyulaşır, eşikte parlar.
/// [prog] Dismissible.onUpdate ile 0..1 güncellenir.
class FxFillBg extends StatelessWidget {
  final ValueNotifier<double> prog;
  final Color base;
  final Color strong;
  final IconData icon;
  final Alignment align;
  final String Function(double)? label;
  final double hot; // bu ilerlemeden sonra "tamam" durumu
  final IconData? hotIcon; // eşik aşılınca değişen simge
  const FxFillBg({
    super.key,
    required this.prog,
    required this.base,
    required this.strong,
    required this.icon,
    required this.align,
    this.label,
    this.hot = 0.6,
    this.hotIcon,
  });

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ValueListenableBuilder<double>(
      valueListenable: prog,
      builder: (_, v, __) {
        final lv = fxLevel();
        final t = (v / hot).clamp(0.0, 1.0);
        final fill = lv == 0 ? base : Color.lerp(base.withOpacity(0.55), strong, t)!;
        final txt = label?.call(v);
        return Stack(
          children: [
            Positioned.fill(child: ColoredBox(color: fill)),
            if (lv > 0)
              Positioned.fill(
                child: Align(
                  alignment: align,
                  child: FractionallySizedBox(
                    widthFactor: (v * 1.4).clamp(0.0, 1.0),
                    heightFactor: 1,
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: align == Alignment.centerRight
                              ? Alignment.centerRight
                              : Alignment.centerLeft,
                          end: align == Alignment.centerRight
                              ? Alignment.centerLeft
                              : Alignment.centerRight,
                          colors: [
                            strong.withOpacity(lv == 2 ? 0.95 : 0.7),
                            strong.withOpacity(0),
                          ],
                        ),
                      ),
                    ),
                  ),
                ),
              ),
            Positioned.fill(
              child: Container(
                alignment: align,
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (txt != null && txt.isNotEmpty && align == Alignment.centerRight) ...[
                      Text(txt,
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: p.ink)),
                      const SizedBox(width: 8),
                    ],
                    Transform.scale(
                      scale: lv == 0 ? 1 : 1 + 0.35 * t,
                      child: Icon(v >= hot && hotIcon != null ? hotIcon : icon, color: p.ink),
                    ),
                    if (txt != null && txt.isNotEmpty && align != Alignment.centerRight) ...[
                      const SizedBox(width: 8),
                      Text(txt,
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: p.ink)),
                    ],
                  ],
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
