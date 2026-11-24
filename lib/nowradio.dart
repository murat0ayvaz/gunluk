import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'media.dart';
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// ANA EKRANDA "ÇALAN RADYO" SATIRI
//  Radyo çalarken (ya da duraklatılmışken) görünür; ✕ ile kapatılınca kaybolur.
//  Önceki / oynat-duraklat / sonraki istasyon ve kapat tuşları; yukarı kaydırınca sonraki,
//  aşağı kaydırınca önceki istasyon. Satıra dokununca Müzik ve Radyo > Radyo açılır.
// ---------------------------------------------------------------
/// Ana ekran için yer tutucu: radyo çalarken satırı (sarmalayıcıyla) gösterir, yoksa hiçbir yer kaplamaz
class RadioNowSlot extends StatelessWidget {
  final Widget Function(Widget row) wrap;
  const RadioNowSlot({super.key, required this.wrap});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: media,
      builder: (context, _) => (media.nowId != null && media.isRadio)
          ? wrap(const RadioNowRow())
          : const SizedBox.shrink(),
    );
  }
}

class RadioNowRow extends StatelessWidget {
  const RadioNowRow({super.key});

  String _catName() {
    for (final c in store.radCats) {
      if (c.stations.any((s) => s.id == media.nowId)) return c.name;
    }
    return '';
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([media, store]),
      builder: (context, _) {
        if (media.nowId == null || !media.isRadio) return const SizedBox.shrink();
        final tone = tagTone(_catName().isEmpty ? (media.nowId ?? '') : _catName());
        final cat = _catName();
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context)
              .push(slideFromRight(const MediaPage(initial: 'radio'))),
          onVerticalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -400) {
              HapticFeedback.selectionClick();
              media.radioStep(1);
            } else if (v > 400) {
              HapticFeedback.selectionClick();
              media.radioStep(-1);
            }
          },
          child: Container(
            padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: tone.withOpacity(p.dark ? 0.55 : 0.45)),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color.alphaBlend(tone.withOpacity(p.dark ? 0.28 : 0.18), p.card),
                  p.card,
                ],
              ),
            ),
            child: Row(
              children: [
                _Eq(on: media.playing, color: tone),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(media.nowTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              color: p.ink,
                              fontSize: 14.5)),
                      Text(
                          !media.playing
                              ? tx('Duraklatıldı')
                              : (media.icyTitle.isNotEmpty
                                  ? media.icyTitle
                                  : (cat.isEmpty ? tx('Radyo') : cat)),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.soft, fontSize: 12)),
                    ],
                  ),
                ),
                IconButton(
                  tooltip: tx('Önceki istasyon'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => media.radioStep(-1),
                  icon: const Icon(Icons.skip_previous_rounded),
                ),
                media.loading
                    ? const Padding(
                        padding: EdgeInsets.all(10),
                        child: SizedBox(
                            width: 22,
                            height: 22,
                            child: CircularProgressIndicator(strokeWidth: 2.5)),
                      )
                    : IconButton(
                        tooltip: media.playing ? tx('Duraklat') : tx('Çal'),
                        visualDensity: VisualDensity.compact,
                        onPressed: media.toggle,
                        icon: Icon(
                            media.playing
                                ? Icons.pause_circle_filled_rounded
                                : Icons.play_circle_fill_rounded,
                            size: 34),
                      ),
                IconButton(
                  tooltip: tx('Sonraki istasyon'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => media.radioStep(1),
                  icon: const Icon(Icons.skip_next_rounded),
                ),
                IconButton(
                  tooltip: tx('Durdur'),
                  visualDensity: VisualDensity.compact,
                  onPressed: media.stop,
                  icon: const Icon(Icons.close_rounded),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Ses dalgası göstergesi: yalnız çalarken oynar (pil için duraklatınca durur)
class _Eq extends StatefulWidget {
  final bool on;
  final Color color;
  const _Eq({required this.on, required this.color});

  @override
  State<_Eq> createState() => _EqState();
}

class _EqState extends State<_Eq> with SingleTickerProviderStateMixin {
  late final AnimationController _c =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1200));

  @override
  void initState() {
    super.initState();
    if (widget.on) _c.repeat();
  }

  @override
  void didUpdateWidget(_Eq old) {
    super.didUpdateWidget(old);
    if (widget.on && !_c.isAnimating) {
      _c.repeat();
    } else if (!widget.on && _c.isAnimating) {
      _c.stop();
    }
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 26,
      height: 26,
      child: AnimatedBuilder(
        animation: _c,
        builder: (context, _) => CustomPaint(
          painter: _EqPainter(widget.on ? _c.value : 0.35, widget.color, widget.on),
        ),
      ),
    );
  }
}

class _EqPainter extends CustomPainter {
  final double t;
  final Color color;
  final bool on;
  _EqPainter(this.t, this.color, this.on);

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color.withOpacity(on ? 0.95 : 0.5)
      ..strokeCap = StrokeCap.round
      ..strokeWidth = 4;
    for (var i = 0; i < 4; i++) {
      final k = on
          ? 0.35 + 0.65 * (0.5 + 0.5 * math.sin(t * 2 * math.pi * (1 + i % 2) + i * 1.7)).abs()
          : 0.35;
      final h = size.height * k;
      final x = 3.0 + i * 6.7;
      canvas.drawLine(Offset(x, size.height - 1), Offset(x, size.height - 1 - h), paint);
    }
  }

  @override
  bool shouldRepaint(_EqPainter o) => o.t != t || o.color != color || o.on != on;
}
