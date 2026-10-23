import 'package:flutter/material.dart';
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// AÇILIŞ EKRANI: her açılışta 1-2 saniye görünür
// ---------------------------------------------------------------
class SplashPage extends StatelessWidget {
  const SplashPage({super.key});

  // Görsel bulunamazsa gösterilecek eski sade logo
  Widget _fallback(Pal p) => Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 96,
            height: 96,
            decoration: BoxDecoration(color: p.accent, shape: BoxShape.circle),
            child: Icon(Icons.checklist_rounded, size: 52, color: p.onAccent),
          ),
          const SizedBox(height: 20),
          Text.rich(
            const TextSpan(
              children: [
                TextSpan(
                    text: 'Daily ',
                    style: TextStyle(fontWeight: FontWeight.w700)),
                TextSpan(
                    text: 'Routine',
                    style: TextStyle(fontWeight: FontWeight.w300)),
              ],
            ),
            style: TextStyle(fontSize: 32, letterSpacing: 0.5, color: p.ink),
          ),
        ],
      );

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Scaffold(
      backgroundColor: p.bg,
      body: Center(
        child: TweenAnimationBuilder<double>(
          tween: Tween<double>(begin: 0, end: 1),
          duration: const Duration(milliseconds: 700),
          curve: Curves.easeOut,
          builder: (context, t, child) => Opacity(
            opacity: t,
            child: Transform.scale(scale: 0.96 + 0.04 * t, child: child),
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Açılış görseli (Daily Routine)
                ClipRRect(
                  borderRadius: BorderRadius.circular(22),
                  child: Image.asset(
                    'assets/splash.jpg',
                    fit: BoxFit.contain,
                    errorBuilder: (context, error, stack) => _fallback(p),
                  ),
                ),
                const SizedBox(height: 18),
                Text(tx('Rutinlerin, hedeflerin, günlerin'),
                    style: TextStyle(color: p.soft)),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// TANITIM SAYFALARI: ilk kurulumda 3 kaydırmalı sayfa
// (Ayarlar'dan "Tanıtımı göster" ile tekrar açılabilir)
// ---------------------------------------------------------------
class _Pg {
  final IconData icon;
  final String title;
  final String text;
  const _Pg(this.icon, this.title, this.text);
}

List<_Pg> _pages() => [
      _Pg(
        Icons.today_rounded,
        tx('Günün tek ekranda'),
        tx('Su, adım, çözülen soru, satılan ürün... Takip etmek istediğin her şeyi günlük olarak kaydet. Geçmiş günlere de veri girebilir, günün notunu yazabilirsin.'),
      ),
      _Pg(
        Icons.flag_rounded,
        tx('Rutin oluştur, hedef koy'),
        tx('Sağ alttaki DR düğmesine dokun; kategori ve alt kategori seç, “Rutin olsun” anahtarını aç ve günlük hedefini yaz. Hedefe ulaşınca satır yeşile döner. Satırı sola kaydırarak o günün verisini sil, sağa kaydırarak düzenle; 2 saniye basılı tutarak sırala. Boş yere sağa veya sola kaydırarak günler arasında geçebilirsin.'),
      ),
      _Pg(
        Icons.bar_chart_rounded,
        tx('İstatistikler soldaki menüde'),
        tx('Üstteki “Daily” yazısına dokun, menüden bir alt kategori seç: günlük, haftalık ve aylık toplamlarını gör. Yapılacaklar listesi ve ayarlar da aynı menüde. Tüm verilerin sadece telefonunda saklanır.'),
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
      backgroundColor: p.bg,
      body: SafeArea(
        child: Column(
          children: [
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(right: 8, top: 4),
                child: TextButton(
                  onPressed: last ? null : widget.onDone,
                  child: Text(last ? '' : tx('Atla')),
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
                  return Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 32),
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Container(
                          width: 110,
                          height: 110,
                          decoration: BoxDecoration(
                              color: p.accent, shape: BoxShape.circle),
                          child: Icon(pg.icon, size: 56, color: p.onAccent),
                        ),
                        const SizedBox(height: 32),
                        Text(
                          pg.title,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w600,
                              color: p.ink),
                        ),
                        const SizedBox(height: 14),
                        Text(
                          pg.text,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 16, height: 1.45, color: p.soft),
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
                      color: i == _i ? p.accent : p.line,
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
    );
  }
}
