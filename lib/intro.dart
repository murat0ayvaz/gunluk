import 'dart:math';
import 'package:flutter/material.dart';
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
      tx('Bir satırı sağa kaydırınca düzenlenir, sola kaydırınca o günün verisi silinir.'),
      tx('Satıra 2 saniye basılı tutarak rutinlerini sıralayabilirsin.'),
      tx('Boş yere sağa veya sola kaydırarak günler arasında geçebilirsin.'),
      tx('En alttaki Günlük başlığına dokunup günün notunu yazabilirsin.'),
      tx('Yapılacaklar listesi ekranın altında; dokununca yukarı doğru tüm ekrana açılır.'),
      tx('Soldaki menüden kategorilerin istatistiklerine ulaşabilirsin.'),
      tx('Soldaki menüde Günlük’e dokunarak notlarını takvimden görebilirsin.'),
      tx('Rutin oluştururken hangi günlerde görüneceğini seçebilirsin.'),
      tx('Ayarlar’dan tema, dil, özlü sözler ve uygulama kilidini ayarlayabilirsin.'),
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
      backgroundColor: Colors.white,
      body: LayoutBuilder(
        builder: (context, c) {
          final imgH = _imageHeight(c.maxWidth, c.maxHeight, 170);
          return Stack(
            children: [
              Positioned(top: 0, left: 0, right: 0, child: _bookImage(imgH)),
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
                                  color: _gold, size: 18),
                              const SizedBox(width: 6),
                              Text(tx('İpucu'),
                                  style: const TextStyle(
                                      color: _gold,
                                      fontWeight: FontWeight.w700)),
                            ],
                          ),
                          const SizedBox(height: 6),
                          Text(
                            _tip,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                                color: _ink, fontSize: 15, height: 1.4),
                          ),
                        ],
                      ),
                    ),
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
        tx('Sağ alttaki DR düğmesine dokun; kategori ve alt kategori seç, “Rutin olsun” anahtarını aç ve günlük hedefini yaz. Hedefe ulaşınca satır yeşile döner. Satırı sola kaydırarak o günün verisini sil, sağa kaydırarak düzenle; 2 saniye basılı tutarak sırala. Boş yere sağa veya sola kaydırarak günler arasında geçebilirsin.'),
      ),
      _Pg(
        tx('İstatistikler soldaki menüde'),
        tx('Üstteki “Daily” yazısına dokun: soldaki menüde kategori istatistiklerini ve notu olan günlerin takvimini (Günlük) görürsün. Yapılacaklar ve Günlük ekranın altında; ayarlar menünün içinde. Tüm verilerin sadece telefonunda saklanır.'),
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
