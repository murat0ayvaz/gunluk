import 'dart:math';
import 'package:flutter/material.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// ORTAK: tam ekran arka plan görseli + alttan koyulaşan gölge
// (görselin alt kısmı açık renkte olduğu için beyaz yazılar okunsun diye)
// ---------------------------------------------------------------
class _BookBackground extends StatelessWidget {
  final double shadeFrom; // gölgenin başladığı yükseklik oranı (0-1)
  const _BookBackground({this.shadeFrom = 0.45});

  @override
  Widget build(BuildContext context) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.asset(
          'assets/splash.jpg',
          fit: BoxFit.cover,
          alignment: Alignment.topCenter,
          errorBuilder: (context, error, stack) =>
              const ColoredBox(color: Color(0xFF1F2125)),
        ),
        DecoratedBox(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: const [
                Colors.transparent,
                Colors.transparent,
                Color(0xE6000000),
              ],
              stops: [0, shadeFrom, 1],
            ),
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------
// AÇILIŞ EKRANI: her açılışta 3 saniye görünür; altta kısa bir
// kullanım ipucu (tooltip) çıkar, her açılışta farklı bir ipucu.
// ---------------------------------------------------------------
List<String> _tips() => [
      tx('Ekle için sağ alttaki DR düğmesine dokun.'),
      tx('Bir satırı sağa kaydırınca düzenlenir, sola kaydırınca o günün verisi silinir.'),
      tx('Satıra 2 saniye basılı tutarak rutinlerini sıralayabilirsin.'),
      tx('Boş yere sağa veya sola kaydırarak günler arasında geçebilirsin.'),
      tx('En alttaki Günlük başlığına dokunup günün notunu yazabilirsin.'),
      tx('Yapılacaklar listesi ekranın altında; dokununca yukarı doğru tüm ekrana açılır.'),
      tx('Soldaki menüden kategorilerin istatistiklerine ulaşabilirsin.'),
      tx('Soldaki menüde Günlük’e dokunarak notlarını takvimden görebilirsin.'),
      tx('Rutin oluştururken hangi günlerde görüneceğini seçebilirsin.'),
      tx('Ayarlar’dan tema, dil ve özlü sözleri değiştirebilirsin.'),
      tx('Uygulamayı kaldırmadan önce Ayarlar’dan yedek almayı unutma.'),
    ];

class SplashPage extends StatefulWidget {
  const SplashPage({super.key});

  @override
  State<SplashPage> createState() => _SplashPageState();
}

class _SplashPageState extends State<SplashPage> {
  late final String _tip = () {
    final t = _tips();
    return t[Random().nextInt(t.length)];
  }();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF1F2125),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _BookBackground(shadeFrom: 0.6),
          Positioned(
            left: 24,
            right: 24,
            bottom: 0,
            child: SafeArea(
              top: false,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 28),
                child: TweenAnimationBuilder<double>(
                  tween: Tween<double>(begin: 0, end: 1),
                  duration: const Duration(milliseconds: 700),
                  curve: Curves.easeOut,
                  builder: (context, t, child) => Opacity(
                    opacity: t,
                    child: Transform.translate(
                        offset: Offset(0, 10 * (1 - t)), child: child),
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Icon(Icons.lightbulb_outline_rounded,
                              color: Colors.white, size: 18),
                          const SizedBox(width: 6),
                          Text(tx('İpucu'),
                              style: const TextStyle(
                                  color: Colors.white,
                                  fontWeight: FontWeight.w700)),
                        ],
                      ),
                      const SizedBox(height: 6),
                      Text(
                        _tip,
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 15,
                          height: 1.4,
                          shadows: [Shadow(blurRadius: 8, color: Colors.black54)],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// TANITIM SAYFALARI: ilk kurulumda 3 kaydırmalı sayfa.
// Her sayfada aynı görsel arka planda durur, yazılar beyaz ve altta.
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
        tx('Sağ alttaki DR düğmesine dokun; kategori ve alt kategori seç, “Rutin olsun” anahtarını aç ve günlük hedefini yaz. Hedefe ulaşınca satır yeşile döner. Satırı sola kaydırarak o günün verisini sil, sağa kaydırarak düzenle; 2 saniye basılı tutarak sırala. Boş yere sağa veya sola kaydırarak günler arasında geçebilirsin.'),
      ),
      _Pg(
        tx('İstatistikler soldaki menüde'),
        tx('Üstteki “Daily” yazısına dokun: soldaki menüde kategori istatistiklerini ve notu olan günlerin takvimini (Günlük) görürsün. Yapılacaklar ve Günlük ekranın altında; ayarlar menünün içinde. Tüm verilerin sadece telefonunda saklanır.'),
      ),
    ];

const _shadow = [Shadow(blurRadius: 10, color: Colors.black87)];

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
      backgroundColor: const Color(0xFF1F2125),
      body: Stack(
        fit: StackFit.expand,
        children: [
          const _BookBackground(shadeFrom: 0.28),
          SafeArea(
            child: Column(
              children: [
                Align(
                  alignment: Alignment.centerRight,
                  child: Padding(
                    padding: const EdgeInsets.only(right: 8, top: 4),
                    child: TextButton(
                      style: TextButton.styleFrom(foregroundColor: Colors.white),
                      onPressed: last ? null : widget.onDone,
                      child: Text(last ? '' : tx('Atla'),
                          style: const TextStyle(shadows: _shadow)),
                    ),
                  ),
                ),
                Expanded(
                  child: PageView.builder(
                    controller: _ctrl,
                    itemCount: pages.length,
                    onPageChanged: (v) => setState(() => _i = v),
                    itemBuilder: (_, i) {
                      final pg = pages[i];
                      // Yazılar sayfanın ALT kısmında ve beyaz
                      return Align(
                        alignment: Alignment.bottomCenter,
                        child: Padding(
                          padding: const EdgeInsets.fromLTRB(28, 0, 28, 16),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                pg.title,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 26,
                                  fontWeight: FontWeight.w700,
                                  color: Colors.white,
                                  shadows: _shadow,
                                ),
                              ),
                              const SizedBox(height: 12),
                              Text(
                                pg.text,
                                textAlign: TextAlign.center,
                                style: const TextStyle(
                                  fontSize: 16,
                                  height: 1.45,
                                  color: Colors.white,
                                  shadows: _shadow,
                                ),
                              ),
                            ],
                          ),
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
                          color: i == _i ? p.accent : Colors.white54,
                          borderRadius: BorderRadius.circular(4),
                        ),
                      ),
                  ],
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(24, 20, 24, 24),
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
        ],
      ),
    );
  }
}
