import 'dart:math';
import 'package:flutter/material.dart';
import 'data.dart';
import 'fireworks.dart';
import 'quotes.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// ORTAK: açılış / kurulum görseli
// Görsel TAM GENİŞLİKTE ve KIRPILMADAN üstte durur (altı beyaza soluyor);
// altındaki alan beyazdır ve yazılar bu beyaz alana koyu renkte yazılır.
// Ekran çok kısaysa görselin sadece alt kısmı (beyaz soluma) kırpılır.
// ---------------------------------------------------------------
const _ink = Color(0xFF2E3238); // beyaz zeminde koyu yazı
const _soft = Color(0xFF6B7078);
const _gold = Color(0xFF9A7B3D);
const _imgRatio = 1200 / 896; // görselin yükseklik / genişlik oranı

/// Verilen genişlikte görselin ekranda kaplayacağı yükseklik
double _imageHeight(double w, double maxH, double reserve) {
  final natural = w * _imgRatio;
  final room = maxH - reserve;
  if (natural <= room) return natural;
  return room < 200 ? 200 : room;
}

Widget _bookImage(double h) => SizedBox(
      width: double.infinity,
      height: h,
      child: Image.asset(
        'assets/splash.jpg',
        fit: BoxFit.cover,
        alignment: Alignment.topCenter,
        errorBuilder: (context, error, stack) =>
            const ColoredBox(color: Colors.white),
      ),
    );

// ---------------------------------------------------------------
// AÇILIŞ EKRANI: her açılışta 3 saniye görünür; altta kısa bir
// kullanım ipucu (tooltip) çıkar, her açılışta farklı bir ipucu.
// ---------------------------------------------------------------
List<String> _tips() => [
      tx('Ekle için sağ alttaki DR düğmesine dokun.'),
      tx('Bir satırı sağa kaydırınca düzenlenir; sola kısa kaydırınca rutin o gün kalkar, tamamen kaydırınca tüm günlerden kalkar.'),
      tx('Satırın solundaki ≡ simgesinden sürükleyerek rutinlerini sıralayabilirsin.'),
      tx('Boş yere sağa veya sola kaydırarak günler arasında geçebilirsin.'),
      tx('Günün notunu yazmak için ana ekranda rutinlerin altındaki Günlük başlığını açabilirsin.'),
      tx('Yapılacaklar, Günlük ve Hatırlatıcı ana ekranda rutinlerin altındaki açılır başlıklarda.'),
      tx('Soldaki menüden kategorilerin istatistiklerine ulaşabilirsin.'),
      tx('Soldaki menüde Günlük’e dokunarak notlarını takvimden görebilirsin.'),
      tx('Rutin oluştururken hangi günlerde görüneceğini seçebilirsin.'),
      tx('Ayarlar’dan tema, dil, özlü sözler ve uygulama kilidini ayarlayabilirsin.'),
      tx('Uygulamayı kaldırmadan önce Ayarlar’dan yedek almayı unutma.'),
    ];

class SplashPage extends StatefulWidget {
  final bool ready; // veri okundu mu (okununca yüzde ve "Geç" görünür)
  final VoidCallback onGo;
  const SplashPage({super.key, required this.ready, required this.onGo});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late final String _tip = () {
    final t = _tips();
    return t[Random().nextInt(t.length)];
  }();

  // Açılışta gösterilen rastgele motivasyon sözü
  late final int _quoteSeed =
      store.pickSplashQuote(builtInQuotes('motivation', appLang).length);

  /// Bugünkü hedef yüzdesine göre açıklama
  String _message(GoalStat g) {
    final p = g.pct;
    if (g.all) return tx('Tebrikler! Bugünkü hedeflerinin tamamına ulaştın.');
    if (p == 0) {
      return tx('Bugün henüz bir hedefine ulaşmadın. Küçük bir adımla başla, hepsine ulaşman zor olmayacak.');
    }
    if (p < 40) {
      return tx('Hedeflerinin %{0} kadarına ulaştın. Güzel bir başlangıç, hepsine ulaşman zor olmayacak.', [p]);
    }
    if (p < 80) {
      return tx('Hedeflerinin %{0} kadarına ulaştın. Yolun büyük kısmı geride, hepsine ulaşman zor olmayacak.', [p]);
    }
    return tx('Hedeflerinin %{0} kadarına ulaştın. Bitirmene çok az kaldı!', [p]);
  }

  Widget _ring(GoalStat g) {
    return SizedBox(
      width: 112,
      height: 112,
      child: TweenAnimationBuilder<double>(
        tween: Tween<double>(begin: 0, end: g.pct / 100),
        duration: const Duration(milliseconds: 1000),
        curve: Curves.easeOutCubic,
        builder: (context, v, _) => Stack(
          alignment: Alignment.center,
          children: [
            SizedBox(
              width: 112,
              height: 112,
              child: CircularProgressIndicator(
                value: v,
                strokeWidth: 10,
                backgroundColor: const Color(0xFFE6E8EC),
                color: g.all ? const Color(0xFF3E8E5A) : _gold,
              ),
            ),
            Text('%${(v * 100).round()}',
                style: const TextStyle(
                    fontSize: 28, fontWeight: FontWeight.w800, color: _ink)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final pool = builtInQuotes('motivation', appLang);
    final q = pool.isEmpty ? null : pool[_quoteSeed % pool.length];
    final g = widget.ready ? store.todayGoals() : const GoalStat(0, 0);
    final showGoal = widget.ready && g.total > 0;
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, c) {
          final imgH = _imageHeight(c.maxWidth, c.maxHeight, 340);
          return Stack(
            children: [
              Positioned(top: 0, left: 0, right: 0, child: _bookImage(imgH)),
              // Görselin altındaki alan: yüzde, açıklama, motivasyon sözü, ipucu
              Positioned(
                top: imgH + 4,
                left: 24,
                right: 24,
                bottom: 96,
                child: Center(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    child: ConstrainedBox(
                      constraints: BoxConstraints(maxWidth: c.maxWidth - 48),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (showGoal) ...[
                            _ring(g),
                            const SizedBox(height: 10),
                            Text(
                              _message(g),
                              textAlign: TextAlign.center,
                              style: const TextStyle(
                                  color: _ink,
                                  fontSize: 16,
                                  fontWeight: FontWeight.w600,
                                  height: 1.35),
                            ),
                            const SizedBox(height: 12),
                          ],
                          if (q != null)
                            Text(
                              q.ref.isEmpty
                                  ? '“${q.text}”'
                                  : '“${q.text}”\n— ${q.ref}',
                              textAlign: TextAlign.center,
                              style: TextStyle(
                                  color: showGoal ? _soft : _ink,
                                  fontSize: showGoal ? 14.5 : 16,
                                  height: 1.4,
                                  fontStyle: FontStyle.italic),
                            ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
              // Altta: "Geç" düğmesi ve küçük ipucu
              Positioned(
                left: 24,
                right: 24,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 20),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        SizedBox(
                          width: double.infinity,
                          height: 50,
                          child: widget.ready
                              ? FilledButton(
                                  onPressed: widget.onGo,
                                  child: Text(tx('Geç')),
                                )
                              : const Center(
                                  child: SizedBox(
                                      width: 22,
                                      height: 22,
                                      child: CircularProgressIndicator(
                                          strokeWidth: 2.5))),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          _tip,
                          textAlign: TextAlign.center,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              color: _soft, fontSize: 12.5, height: 1.3),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
              if (showGoal && g.all)
                const Positioned.fill(child: FireworksOverlay()),
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------
// TANITIM SAYFALARI: ilk kurulumda 3 kaydırmalı sayfa.
// Her sayfada aynı görsel üstte, yazılar altındaki beyaz alanda.
// (Ayarlar'dan "Tanıtımı göster" ile tekrar açılabilir)
// ---------------------------------------------------------------
class _Pg {
  final String title;
  final String text;
  const _Pg(this.title, this.text);
}

List<_Pg> _pages() => [
      _Pg(
        tx('Günün tek ekranda'),
        tx('Su, adım, çözülen soru, satılan ürün... Takip etmek istediğin her şeyi günlük olarak kaydet. Geçmiş günlere de veri girebilir, günün notunu yazabilirsin.'),
      ),
      _Pg(
        tx('Rutin oluştur, hedef koy'),
        tx('Sağ alttaki DR düğmesine dokun; kategori ve alt kategori seç, “Rutin olsun” anahtarını aç ve günlük hedefini yaz. Hedefe ulaşınca satır yeşile döner. Satırı sağa kaydırarak düzenle; sola kısa kaydırarak rutini o gün için, tamamen kaydırarak tüm günlerden kaldır; ≡ ile sürükleyip sırala. Boş yere sağa veya sola kaydırarak günler arasında geçebilirsin.'),
      ),
      _Pg(
        tx('İstatistikler soldaki menüde'),
        tx('Sol üstteki ≡ menüsüne dokun: kategori istatistiklerini ve notu olan günlerin takvimini (Günlük) görürsün. Yapılacaklar, Günlük ve Hatırlatıcı ana ekranda rutinlerin altındaki açılır başlıklarda; ayarlar menünün içinde. Tüm verilerin sadece telefonunda saklanır.'),
      ),
    ];

class IntroPage extends StatefulWidget {
  final VoidCallback onDone;
  const IntroPage({super.key, required this.onDone});

  @override
  State<IntroPage> createState() => _IntroPageState();
}

class _IntroPageState extends State<IntroPage> {
  final _ctrl = PageController();
  int _i = 0;

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _next(int count) {
    if (_i == count - 1) {
      widget.onDone();
    } else {
      _ctrl.nextPage(
          duration: const Duration(milliseconds: 300), curve: Curves.easeOut);
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final pages = _pages();
    final last = _i == pages.length - 1;
    return Scaffold(
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, c) {
          final imgH = _imageHeight(c.maxWidth, c.maxHeight, 380);
          return Stack(
            children: [
              Positioned(top: 0, left: 0, right: 0, child: _bookImage(imgH)),
              // Atla düğmesi (görselin üstünde, okunsun diye koyu yarı saydam zemin)
              Positioned(
                top: 0,
                right: 0,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.all(8),
                    child: last
                        ? const SizedBox.shrink()
                        : TextButton(
                            style: TextButton.styleFrom(
                              foregroundColor: Colors.white,
                              backgroundColor: Colors.black38,
                            ),
                            onPressed: widget.onDone,
                            child: Text(tx('Atla')),
                          ),
                  ),
                ),
              ),
              // Görselin altındaki beyaz alan: sayfa yazıları, noktalar, düğme
              Positioned(
                top: imgH,
                left: 0,
                right: 0,
                bottom: 0,
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      Expanded(
                        child: PageView.builder(
                          controller: _ctrl,
                          itemCount: pages.length,
                          onPageChanged: (v) => setState(() => _i = v),
                          itemBuilder: (_, i) {
                            final pg = pages[i];
                            return SingleChildScrollView(
                              padding: const EdgeInsets.fromLTRB(28, 4, 28, 8),
                              child: Column(
                                children: [
                                  Text(
                                    pg.title,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 24,
                                        fontWeight: FontWeight.w700,
                                        color: _ink),
                                  ),
                                  const SizedBox(height: 10),
                                  Text(
                                    pg.text,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                        fontSize: 15.5,
                                        height: 1.45,
                                        color: _soft),
                                  ),
                                ],
                              ),
                            );
                          },
                        ),
                      ),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          for (var i = 0; i < pages.length; i++)
                            AnimatedContainer(
                              duration: const Duration(milliseconds: 200),
                              margin: const EdgeInsets.symmetric(horizontal: 4),
                              width: i == _i ? 22 : 8,
                              height: 8,
                              decoration: BoxDecoration(
                                color: i == _i
                                    ? p.accent
                                    : const Color(0xFFD5D7DB),
                                borderRadius: BorderRadius.circular(4),
                              ),
                            ),
                        ],
                      ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(24, 14, 24, 20),
                        child: SizedBox(
                          width: double.infinity,
                          height: 52,
                          child: FilledButton(
                            onPressed: () => _next(pages.length),
                            child: Text(last ? tx('Başla') : tx('İleri')),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}
