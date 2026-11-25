import 'dart:async';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';
import 'voicecmd.dart' show voiceListener;

// ---------------------------------------------------------------
// ANA EKRAN: SÜREKLİ DİNLEME ŞERİDİ + ÖZLÜ SÖZ / İPUCU SATIRI
//  - Sürekli dinleme açıkken (mikrofona uzun basınca ya da Ayarlar'dan) üstte "Sürekli dinleme aktif"
//    şeridi görünür; dokununca kapanır. İkinci satırda son duyulan söz ya da uyandırma kelimesi yazar.
//  - Altında ince bir satırda özlü sözler (Ayarlar > Özlü sözler'de seçili türlerden) ve uygulama
//    ipuçları dönüşümlü görünür. Dokununca bir sonrakine geçer. Ayarlar > Ana ekran'dan kapatılır.
// ---------------------------------------------------------------
bool tipsOn() => store.pBool('tipson', true);

const _tips = <String>[
  'İpucu: Mikrofona uzun basınca sürekli dinleme açılır.',
  'İpucu: "Komut listesi" dersen tüm sesli komutları görürsün.',
  'İpucu: Radyo, TV ve diğer sayfaların üstündeki anahtarla çalma çubuğunu ana ekrana ekleyebilirsin.',
  'İpucu: Ana ekrandaki radyo şeridini yukarı ya da aşağı kaydırınca istasyon değişir.',
  'İpucu: Radyoda istasyonun yanındaki yıldıza basarak favori yap; şeridin ⌄ panelinde görünür.',
  'İpucu: "TV aç" dersen son izlediğin kanal pop-up olarak açılır.',
  'İpucu: TV pop-up\'ına dokununca büyür; köşedeki düğmeyle tam ekran olur.',
  'İpucu: Radyoda çalan şarkıyı tanımak için Shazam düğmesine bas.',
  'İpucu: Beğendiğin şarkıyı kalp simgesiyle İsteklerim listene ekleyebilirsin.',
  'İpucu: Yedeği Ayarlar > Yedek bölümünden alabilirsin; otomatik yedek de var.',
  'İpucu: "Radyo kapat" ya da "durdur" diyerek çalanı susturabilirsin.',
  'İpucu: Uyandırma kelimesini Ayarlar > Sesli komut bölümünden değiştirebilirsin.',
  'İpucu: "Asistan" gibi uzun ve net bir uyandırma kelimesi daha iyi algılanır.',
  'İpucu: Rutini sola tam çekersen yalnız o günden silinir.',
  'İpucu: "Haber oku" dersen haberler sesli okunur.',
  'İpucu: "Saat kaç" ya da "bugün ne yaptım" diye sorabilirsin.',
  'İpucu: Bu satır dokununca bir sonrakine geçer; Ayarlar > Ana ekran\'dan kapatabilirsin.',
];

class HomeTicker extends StatefulWidget {
  const HomeTicker({super.key});

  @override
  State<HomeTicker> createState() => _HomeTickerState();
}

class _HomeTickerState extends State<HomeTicker> {
  final _rnd = Random();
  Timer? _t;
  int _n = 0;
  String _cur = '';

  @override
  void initState() {
    super.initState();
    _cur = _next();
    _t = Timer.periodic(const Duration(seconds: 9), (_) {
      if (!mounted || !tipsOn()) return;
      setState(() => _cur = _next());
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String _next() {
    _n++;
    final pool = store.quotePool();
    if (_n.isOdd || pool.isEmpty) {
      return tx(_tips[_rnd.nextInt(_tips.length)]);
    }
    final q = pool[_rnd.nextInt(pool.length)];
    return q.ref.isEmpty ? '“${q.text}”' : '“${q.text}” · ${q.ref}';
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([store, voiceListener]),
      builder: (context, _) {
        final listen = store.voiceListen && !store.appHidden('voice');
        final tips = tipsOn();
        if (!listen && !tips) return const SizedBox.shrink();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (listen)
              InkWell(
                onTap: () {
                  HapticFeedback.selectionClick();
                  store.setVoiceListen(false);
                  voiceListener.sync();
                },
                child: Container(
                  width: double.infinity,
                  color: p.accent.withOpacity(0.12),
                  padding: const EdgeInsets.fromLTRB(14, 6, 8, 6),
                  child: Row(children: [
                    _Pulse(child: Icon(Icons.mic_rounded, size: 18, color: p.accent)),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(tx('Sürekli dinleme aktif'),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: p.ink)),
                          Text(
                              voiceListener.lastHeard.isNotEmpty
                                  ? tx('Son duyulan: {0}', [voiceListener.lastHeard])
                                  : (voiceListener.listening
                                      ? tx('"{0}" de', [store.voiceWake])
                                      : tx('Mikrofon açılıyor…')),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: TextStyle(fontSize: 11.5, color: p.soft)),
                        ],
                      ),
                    ),
                    Icon(Icons.close_rounded, size: 18, color: p.soft),
                  ]),
                ),
              ),
            if (tips && _cur.isNotEmpty)
              InkWell(
                onTap: () => setState(() => _cur = _next()),
                child: Container(
                  width: double.infinity,
                  padding: const EdgeInsets.fromLTRB(16, 5, 16, 5),
                  child: AnimatedSwitcher(
                    duration: const Duration(milliseconds: 350),
                    child: Text(_cur,
                        key: ValueKey(_cur),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12,
                            height: 1.25,
                            fontStyle: FontStyle.italic,
                            color: p.soft)),
                  ),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// Yanıp sönen küçük gösterge (dinleme açık)
class _Pulse extends StatefulWidget {
  final Widget child;
  const _Pulse({required this.child});

  @override
  State<_Pulse> createState() => _PulseState();
}

class _PulseState extends State<_Pulse> with SingleTickerProviderStateMixin {
  late final AnimationController _c = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 900))
    ..repeat(reverse: true);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      FadeTransition(opacity: Tween<double>(begin: 0.35, end: 1).animate(_c), child: widget.child);
}
