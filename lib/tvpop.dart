import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'data.dart';
import 'main.dart' show navKey;
import 'media.dart';
import 'strings.dart';
import 'tv.dart' show TvPlayerPage;

// ---------------------------------------------------------------
// TV POP-UP: ana ekranın (ve diğer sayfaların) üstünde yüzen küçük TV penceresi.
//  Sürükleyerek taşınır; dokununca büyür (ekran genişliğine yakın), tekrar dokununca küçülür;
//  büyükken önceki/sonraki kanal, tam ekran ve kapat düğmeleri çıkar. Boyut hatırlanır (prof 'tvbig').
//  Telefon yan çevrilince pencere tam ekran olur, dikeye dönünce küçülür.
//  Uygulamadan çıkınca durur (video oynatıcı arka planda çalışmaz).
// ---------------------------------------------------------------
class TvPop extends ChangeNotifier {
  TvChan? chan;

  /// Kanalı pop-up'ta açar; çalan radyo duraklatılır
  void show(TvChan c) {
    if (media.nowId != null && media.playing) media.toggle();
    chan = c;
    store.setProf('ltv', c.id);
    notifyListeners();
  }

  void close() {
    if (chan == null) return;
    chan = null;
    notifyListeners();
  }

  /// Önceki (-1) / sonraki (+1) kanal (aynı kategoride)
  void step(int d) {
    final c = chan;
    if (c == null) return;
    final l = store.tvIn(c.cat);
    final i = l.indexWhere((x) => x.id == c.id);
    if (l.length < 2 || i < 0) return;
    final n = (i + d) % l.length;
    show(l[n < 0 ? n + l.length : n]);
  }
}

final tvPop = TvPop();

class TvPopHost extends StatefulWidget {
  const TvPopHost({super.key});

  @override
  State<TvPopHost> createState() => _TvPopHostState();
}

class _TvPopHostState extends State<TvPopHost> with WidgetsBindingObserver {
  VideoPlayerController? _c;
  String? _loaded; // açık kanalın kimliği
  String? _err;
  bool _ui = true;
  bool _big = false; // büyük boyut (dokununca değişir, hatırlanır)
  Offset? _pos; // pencerenin sol üst köşesi
  int _gen = 0;
  static const double _w = 224, _h = 126;

  @override
  void initState() {
    super.initState();
    _big = store.pBool('tvbig', false);
    WidgetsBinding.instance.addObserver(this);
    tvPop.addListener(_sync);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    tvPop.removeListener(_sync);
    _release();
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState s) {
    if (s == AppLifecycleState.paused) tvPop.close(); // arka planda TV çalmaz
  }

  void _release() {
    _gen++;
    final old = _c;
    _c = null;
    _loaded = null;
    old?.dispose();
    try {
      WakelockPlus.disable();
    } catch (_) {}
  }

  void _sync() {
    final ch = tvPop.chan;
    if (ch == null) {
      _release();
      if (mounted) setState(() {});
      return;
    }
    if (ch.id == _loaded) {
      if (mounted) setState(() {});
      return;
    }
    _open(ch);
  }

  Future<void> _open(TvChan ch) async {
    final old = _c;
    _gen++;
    final g = _gen;
    _loaded = ch.id;
    _c = null;
    _err = null;
    _ui = true;
    old?.dispose();
    if (mounted) setState(() {});
    try {
      WakelockPlus.enable();
    } catch (_) {}
    final u = Uri.tryParse(ch.url);
    if (u == null) {
      if (mounted) setState(() => _err = tx('Yayın adresi geçersiz.'));
      return;
    }
    final c = VideoPlayerController.networkUrl(u);
    _c = c;
    try {
      await c.initialize();
      if (!mounted || g != _gen) {
        if (g != _gen) await c.dispose();
        return;
      }
      await c.play();
      if (mounted) setState(() {});
    } catch (_) {
      if (mounted && g == _gen) {
        setState(() => _err = tx('Yayın açılamadı. İnterneti ya da adresi kontrol et.'));
      }
    }
  }

  void _fullscreen() {
    final ch = tvPop.chan;
    if (ch == null) return;
    tvPop.close();
    navKey.currentState?.push(MaterialPageRoute<void>(
        builder: (_) => TvPlayerPage(chan: ch)));
  }

  Widget _video(BuildContext context, {required bool big}) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    if (_err != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(8),
          child: Text(_err!,
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.white70, fontSize: big ? 15 : 11)),
        ),
      );
    }
    if (!ready) return const Center(child: CircularProgressIndicator(strokeWidth: 2));
    return Center(
      child: AspectRatio(
        aspectRatio: c.value.aspectRatio <= 0 ? 16 / 9 : c.value.aspectRatio,
        child: VideoPlayer(c),
      ),
    );
  }

  Widget _controls(bool big, {bool compact = false}) {
    final ch = tvPop.chan!;
    final sz = big ? 28.0 : 20.0;
    Widget btn(IconData i, VoidCallback f, String tip) => IconButton(
          tooltip: tip,
          color: Colors.white,
          iconSize: sz,
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: BoxConstraints(minWidth: sz + 12, minHeight: sz + 12),
          onPressed: f,
          icon: Icon(i),
        );
    return Container(
      color: Colors.black45,
      child: Column(
        children: [
          Row(children: [
            const SizedBox(width: 8),
            Expanded(
              child: Text(ch.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: Colors.white, fontSize: big ? 16 : 12, fontWeight: FontWeight.w600)),
            ),
            btn(Icons.close_rounded, tvPop.close, tx('Kapat')),
          ]),
          const Spacer(),
          if (compact)
            Row(mainAxisAlignment: MainAxisAlignment.end, children: [
              btn(Icons.fullscreen_rounded, _fullscreen, tx('Tam ekran')),
            ])
          else
            Row(mainAxisAlignment: MainAxisAlignment.spaceEvenly, children: [
              btn(Icons.skip_previous_rounded, () => tvPop.step(-1), tx('Önceki kanal')),
              btn(Icons.fullscreen_rounded, _fullscreen, tx('Tam ekran')),
              btn(Icons.skip_next_rounded, () => tvPop.step(1), tx('Sonraki kanal')),
            ]),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    if (tvPop.chan == null) return const SizedBox.shrink();
    final mq = MediaQuery.of(context);
    final land = mq.orientation == Orientation.landscape;
    if (land) {
      // yan çevrildi: tam ekran
      return Positioned.fill(
        child: Material(
          color: Colors.black,
          child: GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => setState(() => _ui = !_ui),
            onVerticalDragEnd: (d) {
              final v = d.primaryVelocity ?? 0;
              if (v < -400) tvPop.step(1);
              if (v > 400) tvPop.step(-1);
            },
            child: Stack(children: [
              Positioned.fill(child: _video(context, big: true)),
              if (_ui) Positioned.fill(child: _controls(true)),
            ]),
          ),
        ),
      );
    }
    final size = mq.size;
    final w = _big ? (size.width - 16).clamp(_w, 560.0).toDouble() : _w;
    final h = _big ? w * 9 / 16 : _h;
    final pos = _pos ?? Offset(size.width - w - 12, mq.padding.top + 120);
    final dx = pos.dx.clamp(0.0, size.width - w).toDouble();
    final dy = pos.dy.clamp(0.0, size.height - h).toDouble();
    return Positioned(
      left: dx,
      top: dy,
      width: w,
      height: h,
      child: Material(
        elevation: 10,
        borderRadius: BorderRadius.circular(12),
        color: Colors.black,
        clipBehavior: Clip.antiAlias,
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () {
            HapticFeedback.selectionClick();
            setState(() => _big = !_big);
            store.setProf('tvbig', _big);
          },
          onPanUpdate: (d) => setState(() => _pos = Offset(dx, dy) + d.delta),
          child: Stack(children: [
            Positioned.fill(child: _video(context, big: _big)),
            Positioned.fill(child: _controls(_big, compact: !_big)),
          ]),
        ),
      ),
    );
  }
}
