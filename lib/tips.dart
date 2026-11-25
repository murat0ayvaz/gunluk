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
//  - Aşağıdaki bildirim alanının (hava, namaz) en üstünde bir kart: özlü sözler (Ayarlar > Özlü
//    sözler'de seçili türlerden) ve uygulama ipuçları sırayla gelir. Dokununca kapanır. Saat başı ve her
//    açılışta yenilenir. Ayarlar > Ana ekran'dan kapatılır.
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

/// Söz / ipucu seçimi: uygulama genelinde tek yerde tutulur (sayfa yenilense de aynı kalır).
/// Yenilenme: program açıkken saat başı; program kapalıyken her açılışta; arka plandan 1 dakikadan
/// uzun süre sonra dönüşte. Sözler ve ipuçları sırayla (söz, ipucu, söz...) gelir.
class _TipBrain extends ChangeNotifier with WidgetsBindingObserver {
  final _rnd = Random();
  Timer? _t;
  String text = '';
  bool isQuote = false;
  bool dismissed = false; // karta dokununca kapanır; yenisi gelene kadar görünmez
  DateTime _at = DateTime.fromMillisecondsSinceEpoch(0);
  DateTime? _paused;
  int _n = 0;

  void start() {
    if (_t != null) return;
    WidgetsBinding.instance.addObserver(this);
    _t = Timer.periodic(const Duration(minutes: 1), (_) {
      if (DateTime.now().difference(_at) >= const Duration(hours: 1)) next();
    });
    next(); // uygulama her açıldığında yeni söz / ipucu
  }

  void next() {
    _n++;
    _at = DateTime.now();
    dismissed = false;
    final pool = store.quotePool();
    if (_n.isOdd || pool.isEmpty) {
      isQuote = false;
      text = tx(_tips[_rnd.nextInt(_tips.length)]);
    } else {
      isQuote = true;
      final q = pool[_rnd.nextInt(pool.length)];
      text = q.ref.isEmpty ? '“${q.text}”' : '“${q.text}” · ${q.ref}';
    }
    notifyListeners();
  }

  void dismiss() {
    dismissed = true;
    notifyListeners();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) {
      _paused = DateTime.now();
    } else if (s == AppLifecycleState.resumed) {
      final p = _paused;
      _paused = null;
      if (p != null && DateTime.now().difference(p) >= const Duration(minutes: 1)) next();
    }
  }
}

final _tipBrain = _TipBrain();

/// Ana ekranın alt bildirim alanında (hava, namaz kartlarıyla birlikte) en üstte görünen söz / ipucu kartı
class HomeTipCard extends StatefulWidget {
  const HomeTipCard({super.key});

  @override
  State<HomeTipCard> createState() => _HomeTipCardState();
}

class _HomeTipCardState extends State<HomeTipCard> {
  @override
  void initState() {
    super.initState();
    _tipBrain.start();
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([_tipBrain, store]),
      builder: (context, _) {
        if (!tipsOn() || _tipBrain.dismissed || _tipBrain.text.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
          child: Material(
            color: p.card,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(16),
              side: BorderSide(color: p.line),
            ),
            child: InkWell(
              borderRadius: BorderRadius.circular(16),
              onTap: _tipBrain.dismiss,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 10, 14, 10),
                child: Row(children: [
                  Icon(
                      _tipBrain.isQuote
                          ? Icons.format_quote_rounded
                          : Icons.lightbulb_outline_rounded,
                      size: 22,
                      color: p.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(_tipBrain.text,
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 12.5, height: 1.3, color: p.ink)),
                  ),
                ]),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// Sürekli dinleme açıkken ana ekranda üstte görünen şerit (çalma şeridinin altında).
/// Dokununca dinleme kapanır. İkinci satırda son duyulan söz ya da uyandırma kelimesi yazar.
class HomeTicker extends StatelessWidget {
  const HomeTicker({super.key});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([store, voiceListener]),
      builder: (context, _) {
        final listen = store.voiceListen && !store.appHidden('voice');
        if (!listen) return const SizedBox.shrink();
        return InkWell(
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
                            fontSize: 13, fontWeight: FontWeight.w700, color: p.ink)),
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
