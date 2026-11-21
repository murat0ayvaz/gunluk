import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'data.dart';
import 'media.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// CANLI TV (Müzik ve Radyo > TV sekmesi)
//  - Kanal listesi: favori yıldızı, düzenle, sil (geri al ile), kendi adresini ekle
//  - "Hazır kanallar": resmî ve herkese açık yayınlardan başlangıç listesi
//  - Oynatıcı: video_player (HLS .m3u8 ve benzeri adresler); yatay mod, ekranı açık tutma
//  Yayın adresleri zamanla değişebilir; çalışmayan kanalın adresini düzenleyebilirsin.
// ---------------------------------------------------------------

/// Hazır kanal listesi (ad, adres). Adresler yayıncıya aittir; değişirse düzenlenir.
const List<(String, String)> kTvPresets = [
  ('TRT 1', 'https://tv-trt1.medya.trt.com.tr/master.m3u8'),
  ('TRT Haber', 'https://tv-trthaber.medya.trt.com.tr/master.m3u8'),
  ('TRT Spor', 'https://tv-trtspor1.medya.trt.com.tr/master.m3u8'),
  ('TRT Belgesel', 'https://tv-trtbelgesel.medya.trt.com.tr/master.m3u8'),
  ('TRT Çocuk', 'https://tv-trtcocuk.medya.trt.com.tr/master.m3u8'),
  ('TRT Müzik', 'https://tv-trtmuzik.medya.trt.com.tr/master.m3u8'),
  ('TRT World', 'https://tv-trtworld.medya.trt.com.tr/master.m3u8'),
  ('TBMM TV', 'https://meclistv-stream.ercdn.net/meclistv/meclistv.m3u8'),
];

/// Favoriler üstte, sonra eklenme sırası
List<TvChan> tvSorted() {
  final l = List<TvChan>.of(store.tvChans);
  final fav = [for (final c in l) if (c.fav) c];
  final rest = [for (final c in l) if (!c.fav) c];
  return [...fav, ...rest];
}

/// Kanalı tam ekran oynatıcıda açar
Future<void> openTvChannel(BuildContext context, TvChan c) {
  // Radyo/müzik çalıyorsa duraklat; iki ses üst üste binmesin
  try {
    media.player.pause();
  } catch (_) {}
  return Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => TvPlayerPage(chan: c)));
}

class TvTab extends StatelessWidget {
  const TvTab({super.key});

  Future<void> _edit(BuildContext context, TvChan? c) async {
    final name = TextEditingController(text: c?.name ?? '');
    final url = TextEditingController(text: c?.url ?? '');
    String? err;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(c == null ? tx('Kanal ekle') : tx('Kanalı düzenle')),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: name,
                autofocus: true,
                textCapitalization: TextCapitalization.words,
                decoration: InputDecoration(labelText: tx('Kanal adı')),
              ),
              const SizedBox(height: 8),
              TextField(
                controller: url,
                keyboardType: TextInputType.url,
                decoration: InputDecoration(
                    labelText: tx('Yayın adresi (.m3u8)'),
                    hintText: 'https://…',
                    errorText: err),
              ),
            ],
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(ctx, false),
                child: Text(tx('Vazgeç'))),
            FilledButton(
              onPressed: () {
                final u = Uri.tryParse(url.text.trim());
                if (name.text.trim().isEmpty) {
                  set(() => err = tx('Kanal adını yaz.'));
                  return;
                }
                if (u == null || !(u.isScheme('http') || u.isScheme('https'))) {
                  set(() => err = tx('Adres http veya https ile başlamalı.'));
                  return;
                }
                Navigator.pop(ctx, true);
              },
              child: Text(tx('Kaydet')),
            ),
          ],
        ),
      ),
    );
    final n = name.text;
    final u = url.text;
    name.dispose();
    url.dispose();
    if (ok != true) return;
    if (c == null) {
      store.addTvChan(n, u);
    } else {
      store.updateTvChan(c, n, u);
    }
  }

  void _remove(BuildContext context, TvChan c) {
    final i = store.tvChans.indexOf(c);
    store.removeTvChan(c);
    showUndo(context, tx('"{0}" silindi.', [c.name]),
        () => store.restoreTvChan(c, i));
  }

  void _presets(BuildContext context) {
    final n = store.addTvPresets(kTvPresets);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(n > 0
              ? tx('{0} kanal eklendi. Çalışmayan olursa adresini düzenle.', [n])
              : tx('Hazır kanalların hepsi zaten listede.'))));
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = tvSorted();
        return Stack(
          children: [
            ListView(
              padding: const EdgeInsets.fromLTRB(12, 8, 12, 96),
              children: [
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 24, 8, 12),
                    child: Column(
                      children: [
                        Icon(Icons.live_tv_rounded, size: 48, color: p.soft),
                        const SizedBox(height: 12),
                        Text(tx('Henüz kanal yok.'),
                            style: TextStyle(fontSize: 16, color: p.ink)),
                        const SizedBox(height: 6),
                        Text(
                            tx('Hazır kanalları ekleyebilir ya da kendi yayın adresini girebilirsin.'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.soft)),
                      ],
                    ),
                  ),
                for (final c in list)
                  Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    color: p.card,
                    child: ListTile(
                      leading: Icon(Icons.live_tv_rounded, color: p.accent),
                      title: Text(c.name,
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                      subtitle: Text(Uri.tryParse(c.url)?.host ?? c.url,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      onTap: () => openTvChannel(context, c),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: tx('Favori'),
                            onPressed: () => store.toggleTvFav(c),
                            icon: Icon(
                                c.fav
                                    ? Icons.star_rounded
                                    : Icons.star_border_rounded,
                                color: c.fav ? p.accent : p.soft),
                          ),
                          PopupMenuButton<String>(
                            onSelected: (v) {
                              if (v == 'edit') _edit(context, c);
                              if (v == 'del') _remove(context, c);
                            },
                            itemBuilder: (_) => [
                              PopupMenuItem(
                                  value: 'edit', child: Text(tx('Düzenle'))),
                              PopupMenuItem(
                                  value: 'del', child: Text(tx('Sil'))),
                            ],
                          ),
                        ],
                      ),
                    ),
                  ),
                const SizedBox(height: 4),
                OutlinedButton.icon(
                  onPressed: () => _presets(context),
                  icon: const Icon(Icons.playlist_add_rounded),
                  label: Text(tx('Hazır kanalları ekle')),
                ),
              ],
            ),
            Positioned(
              right: 16,
              bottom: 16,
              child: FloatingActionButton.extended(
                heroTag: null,
                onPressed: () => _edit(context, null),
                icon: const Icon(Icons.add_rounded),
                label: Text(tx('Kanal ekle')),
              ),
            ),
          ],
        );
      },
    );
  }
}

/// Tam ekran oynatıcı
class TvPlayerPage extends StatefulWidget {
  final TvChan chan;
  const TvPlayerPage({super.key, required this.chan});

  @override
  State<TvPlayerPage> createState() => _TvPlayerPageState();
}

class _TvPlayerPageState extends State<TvPlayerPage> {
  VideoPlayerController? _c;
  String? _err;
  bool _ui = true; // kontroller görünsün mü
  bool _land = false;

  @override
  void initState() {
    super.initState();
    try {
      WakelockPlus.enable(); // izlerken ekran kapanmasın
    } catch (_) {}
    _open();
  }

  Future<void> _open() async {
    final u = Uri.tryParse(widget.chan.url);
    if (u == null) {
      setState(() => _err = tx('Yayın adresi geçersiz.'));
      return;
    }
    final c = VideoPlayerController.networkUrl(u);
    _c = c;
    try {
      await c.initialize();
      if (!mounted) return;
      await c.play();
      setState(() {});
    } catch (_) {
      if (mounted) {
        setState(() => _err = tx('Yayın açılamadı. İnterneti ya da adresi kontrol et.'));
      }
    }
  }

  Future<void> _toggleLandscape() async {
    _land = !_land;
    if (_land) {
      await SystemChrome.setPreferredOrientations([
        DeviceOrientation.landscapeLeft,
        DeviceOrientation.landscapeRight,
      ]);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.immersiveSticky);
    } else {
      await SystemChrome.setPreferredOrientations(const []);
      await SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    }
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    try {
      WakelockPlus.disable();
    } catch (_) {}
    SystemChrome.setPreferredOrientations(const []);
    SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
    _c?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final c = _c;
    final ready = c != null && c.value.isInitialized;
    return Scaffold(
      backgroundColor: Colors.black,
      body: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => setState(() => _ui = !_ui),
        child: Stack(
          children: [
            Center(
              child: _err != null
                  ? Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(_err!,
                          textAlign: TextAlign.center,
                          style: const TextStyle(color: Colors.white70)),
                    )
                  : ready
                      ? AspectRatio(
                          aspectRatio: c!.value.aspectRatio <= 0
                              ? 16 / 9
                              : c!.value.aspectRatio,
                          child: VideoPlayer(c!),
                        )
                      : const CircularProgressIndicator(),
            ),
            if (_ui)
              SafeArea(
                child: Align(
                  alignment: Alignment.topCenter,
                  child: Row(
                    children: [
                      IconButton(
                        color: Colors.white,
                        icon: const Icon(Icons.arrow_back_rounded),
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                      Expanded(
                        child: Text(widget.chan.name,
                            style: const TextStyle(
                                color: Colors.white,
                                fontSize: 17,
                                fontWeight: FontWeight.w600)),
                      ),
                      IconButton(
                        color: Colors.white,
                        tooltip: tx('Yatay / dikey'),
                        icon: Icon(_land
                            ? Icons.stay_current_portrait_rounded
                            : Icons.screen_rotation_rounded),
                        onPressed: _toggleLandscape,
                      ),
                    ],
                  ),
                ),
              ),
            if (_ui && ready)
              Align(
                alignment: Alignment.bottomCenter,
                child: SafeArea(
                  child: Padding(
                    padding: const EdgeInsets.only(bottom: 12),
                    child: ValueListenableBuilder<VideoPlayerValue>(
                      valueListenable: c!,
                      builder: (_, v, __) => IconButton(
                        iconSize: 46,
                        color: Colors.white,
                        icon: Icon(v.isPlaying
                            ? Icons.pause_circle_filled_rounded
                            : Icons.play_circle_fill_rounded),
                        onPressed: () => v.isPlaying ? c!.pause() : c!.play(),
                      ),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
