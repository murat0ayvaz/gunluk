import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'data.dart';
import 'music.dart';
import 'news.dart';
import 'online.dart';
import 'net.dart';
import 'podcast.dart';
import 'radio.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// MÜZİK, RADYO VE PODCAST
// Ana ekranın sağ üstündeki kulaklık simgesiyle sağdan açılan sayfa.
//  - Müzik:   oynatma listeleri (aşağı açılır), ≡ ile sıralama, çalma stili
//  - Radyo:   kategoriler (aşağı açılır), ≡ ile sıralama, ada göre arama,
//             ülke/türe göre listeden ekleme
//  - Podcast: ara, takip et, bölümleri dinle, kaldığın yerden devam et
// Çalar tek bir yerde (media) yaşar; sayfa kapansa da çalma sürer.
// Dosyalar: media.dart (çalar+sayfa), music.dart, radio.dart, podcast.dart,
//           net.dart (internet işleri)
// ---------------------------------------------------------------

/// Arka planda çalma ve bildirimdeki kontroller için bir kez başlatılır
Future<void> initAudio() async {
  try {
    await JustAudioBackground.init(
      androidNotificationChannelId: 'com.example.gunluk.audio',
      androidNotificationChannelName: 'Daily Routine müzik',
      androidNotificationOngoing: true,
    ).timeout(const Duration(seconds: 5));
  } catch (_) {
    // başlatılamazsa çalar yine çalışır, sadece bildirim kontrolü olmaz
  }
}

/// Sağdan kayarak açılan sayfa geçişi
Route<void> slideFromRight(Widget page) {
  return PageRouteBuilder<void>(
    transitionDuration: const Duration(milliseconds: 260),
    reverseTransitionDuration: const Duration(milliseconds: 220),
    pageBuilder: (context, a, b) => page,
    transitionsBuilder: (context, a, b, child) {
      final tween = Tween<Offset>(begin: const Offset(1, 0), end: Offset.zero)
          .chain(CurveTween(curve: Curves.easeOutCubic));
      return SlideTransition(position: a.drive(tween), child: child);
    },
  );
}

const _kSong = 'song';
const _kRadio = 'radio';
const _kPod = 'pod';
const _kVoice = 'voice';
const _kOnline = 'online';

class MediaCtl extends ChangeNotifier {
  final AudioPlayer player = AudioPlayer();
  final Random _rnd = Random();
  String? nowId; // çalan şarkı / radyo / bölüm kimliği
  String nowTitle = '';
  String nowKind = ''; // song | radio | pod
  String? curListId; // çalan şarkının oynatma listesi
  String? podKey; // çalan podcast bölümünün kayıt anahtarı
  bool loading = false;
  String? error;
  bool _started = false;
  int _lastSave = 0;

  bool get playing => player.playing;
  bool get isRadio => nowKind == _kRadio;
  bool get isSong => nowKind == _kSong;
  bool get isPod => nowKind == _kPod;
  bool get isVoice => nowKind == _kVoice;
  bool get isOnline => nowKind == _kOnline;
  List<OnTrack> onQueue = []; // online çalma sırası

  void _start() {
    if (_started) return;
    _started = true;
    player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed) {
        _onCompleted();
      } else if (!s.playing && isPod) {
        _savePod();
      }
      notifyListeners();
    });
    // Podcast konumunu 15 saniyede bir kaydet
    player.positionStream.listen((pos) {
      if (isPod && player.playing) {
        final now = DateTime.now().millisecondsSinceEpoch;
        if (now - _lastSave > 15000) {
          _lastSave = now;
          _savePod();
        }
      }
    });
  }

  void _savePod() {
    final k = podKey;
    if (isPod && k != null) {
      store.setEpPos(k, player.position.inMilliseconds);
    }
  }

  void _onCompleted() {
    if (isSong) {
      if (store.playMode == 2) {
        player.seek(Duration.zero);
        player.play();
      } else {
        next(auto: true);
      }
    } else if (isOnline) {
      nextOnline(auto: true);
    } else if (isPod) {
      final k = podKey;
      if (k != null) {
        store.setEpPos(k, 0);
        store.setEpDone(k, true);
      }
    }
  }

  String _msg(Object e) {
    final s = e.toString();
    return s.length > 120 ? s.substring(0, 120) : s;
  }

  Future<void> _play(String id, String title, Uri uri, String kind,
      {Duration? start, String? album, String? art, String? pKey}) async {
    _start();
    _savePod(); // önceki podcast bölümünün konumunu kaydet
    try {
      await player.setLoopMode(LoopMode.off);
    } catch (_) {}
    podKey = pKey;
    error = null;
    nowKind = kind;
    nowId = id;
    nowTitle = title;
    loading = true;
    notifyListeners();
    try {
      await player.setAudioSource(
          AudioSource.uri(uri,
              tag: MediaItem(
                  id: id,
                  title: title,
                  album: album,
                  artist: 'Daily Routine',
                  artUri: (art == null || art.isEmpty) ? null : Uri.tryParse(art))),
          initialPosition: start);
      loading = false;
      notifyListeners();
      player.play(); // çalma bitene kadar tamamlanmaz, beklenmez
    } catch (e) {
      loading = false;
      error = tx('Çalınamadı: {0}', [_msg(e)]);
      notifyListeners();
    }
  }

  Future<void> playSong(Playlist pl, Song s) async {
    curListId = pl.id;
    if (!File(s.path).existsSync()) {
      _start();
      nowKind = _kSong;
      nowId = s.id;
      nowTitle = s.title;
      error = tx('Dosya bulunamadı; şarkıyı silip yeniden ekle.');
      notifyListeners();
      return;
    }
    await _play(s.id, s.title, Uri.file(s.path), _kSong, album: pl.name);
  }

  Future<void> playStation(Station r) async {
    final u = Uri.tryParse(r.url);
    if (u == null || !(u.isScheme('http') || u.isScheme('https'))) {
      _start();
      nowKind = _kRadio;
      nowId = r.id;
      nowTitle = r.name;
      error = tx('Yayın adresi geçersiz.');
      notifyListeners();
      return;
    }
    await _play(r.id, r.name, u, _kRadio);
  }

  Future<void> playEpisode(Podcast p, Episode e) async {
    final u = Uri.tryParse(e.url);
    if (u == null) return;
    final saved = store.epPos[e.key] ?? 0;
    await _play(e.key, e.title, u, _kPod,
        start: saved > 0 ? Duration(milliseconds: saved) : null,
        album: p.title,
        art: p.art,
        pKey: e.key);
  }

  /// Online parçayı çalar; q = çalma sırası (liste), i = sıradaki
  Future<void> playOnline(List<OnTrack> q, int i) async {
    if (i < 0 || i >= q.length) return;
    onQueue = List<OnTrack>.from(q);
    final tr = q[i];
    final u = Uri.tryParse(tr.url);
    if (u == null) return;
    await _play(tr.id, tr.title, u, _kOnline, album: tr.artist, art: tr.art);
  }

  void nextOnline({bool auto = false, int step = 1}) {
    if (!isOnline || onQueue.isEmpty) return;
    final i = onQueue.indexWhere((x) => x.id == nowId);
    var n = i + step;
    if (n >= onQueue.length) {
      if (auto) {
        player.pause();
        player.seek(Duration.zero);
        notifyListeners();
        return;
      }
      n = 0;
    }
    if (n < 0) n = onQueue.length - 1;
    playOnline(onQueue, n);
  }

  /// Günlük / yapılacaklardaki ses kaydını çalar (id = dosya adı)
  Future<void> playVoice(String path, String id, String title) async {
    if (!File(path).existsSync()) {
      _start();
      nowKind = _kVoice;
      nowId = id;
      nowTitle = title;
      error = tx('Ses dosyası bulunamadı.');
      notifyListeners();
      return;
    }
    await _play(id, title, Uri.file(path), _kVoice);
  }

  void toggle() {
    if (player.playing) {
      player.pause();
      _savePod();
    } else {
      player.play();
    }
    notifyListeners();
  }

  /// Şarkıda sonraki parça. auto: parça kendi bittiği için geçiliyor
  void next({bool auto = false}) {
    if (!isSong) return;
    final pl = store.playlistById(curListId ?? '');
    if (pl == null || pl.songs.isEmpty) return;
    final l = pl.songs;
    final i = l.indexWhere((s) => s.id == nowId);
    final mode = store.playMode;
    int n;
    if (mode == 3 && l.length > 1) {
      do {
        n = _rnd.nextInt(l.length);
      } while (n == i);
    } else {
      n = i + 1;
      if (n >= l.length) {
        // Sırayla modunda liste bitince durur
        if (auto && mode == 0) {
          player.pause();
          player.seek(Duration.zero);
          notifyListeners();
          return;
        }
        n = 0;
      }
    }
    playSong(pl, l[n]);
  }

  void prev() {
    if (!isSong) return;
    final pl = store.playlistById(curListId ?? '');
    if (pl == null || pl.songs.isEmpty) return;
    if (player.position > const Duration(seconds: 3)) {
      player.seek(Duration.zero);
      return;
    }
    final l = pl.songs;
    final i = l.indexWhere((s) => s.id == nowId);
    final n = i <= 0 ? l.length - 1 : i - 1;
    playSong(pl, l[n]);
  }

  void skipBy(int seconds) {
    var t = player.position + Duration(seconds: seconds);
    if (t < Duration.zero) t = Duration.zero;
    final d = player.duration;
    if (d != null && t > d) t = d;
    player.seek(t);
  }

  Future<void> stop() async {
    _savePod();
    nowId = null;
    nowTitle = '';
    nowKind = '';
    podKey = null;
    error = null;
    loading = false;
    notifyListeners();
    try {
      await player.stop();
    } catch (_) {}
    notifyListeners();
  }
}

final media = MediaCtl();

String mmss(Duration d) {
  final h = d.inHours;
  final m = d.inMinutes % 60;
  final s = d.inSeconds % 60;
  final ss = s.toString().padLeft(2, '0');
  if (h > 0) return '$h:${m.toString().padLeft(2, '0')}:$ss';
  return '$m:$ss';
}

// ---------------------------------------------------------------
// Aşağı doğru açılan başlık + içerik kutusu (liste / kategori / podcast)
// ---------------------------------------------------------------
class MediaGroup extends StatelessWidget {
  final String title;
  final String info;
  final bool open;
  final VoidCallback onToggle;
  final Widget? menu;
  final Widget? leading;
  final Widget? handle; // soldaki ≡ sıralama tutamacı
  final EdgeInsetsGeometry margin;
  final String? colorSeed; // renk için kimlik (yoksa başlık)
  final Widget child;
  const MediaGroup({
    super.key,
    required this.title,
    required this.info,
    required this.open,
    required this.onToggle,
    required this.child,
    this.menu,
    this.leading,
    this.handle,
    this.colorSeed,
    this.margin = const EdgeInsets.fromLTRB(12, 4, 12, 4),
  });

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final tone = tagTone(colorSeed ?? title);
    final head = Color.alphaBlend(
        tone.withOpacity(p.dark ? 0.20 : 0.14), p.card);
    return Container(
      margin: margin,
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withOpacity(p.dark ? 0.55 : 0.45)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: head,
            borderRadius: BorderRadius.vertical(
                top: const Radius.circular(13),
                bottom: Radius.circular(open ? 0 : 13)),
            child: InkWell(
              borderRadius: BorderRadius.circular(13),
              onTap: onToggle,
              child: Padding(
                padding: EdgeInsets.fromLTRB(handle == null ? 12 : 2, 6, 0, 6),
                child: Row(
                  children: [
                    if (handle != null) handle!,
                    leading ??
                        Icon(
                            open
                                ? Icons.expand_less_rounded
                                : Icons.expand_more_rounded,
                            color: tone),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(title,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w700,
                              fontSize: 15.5,
                              color: p.ink)),
                    ),
                    Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                      decoration: BoxDecoration(
                          color: tone.withOpacity(0.18),
                          borderRadius: BorderRadius.circular(10)),
                      child: Text(info,
                          style: TextStyle(
                              color: p.ink,
                              fontSize: 12.5,
                              fontWeight: FontWeight.w600)),
                    ),
                    menu ?? const SizedBox(width: 12),
                  ],
                ),
              ),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: open
                ? child
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// Sayfa
// ---------------------------------------------------------------
class MediaPage extends StatelessWidget {
  const MediaPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(
          title: Text(tx('Müzik ve Radyo')),
          bottom: TabBar(
            tabs: [
              Tab(icon: const Icon(Icons.music_note_rounded), text: tx('Müzik')),
              Tab(icon: const Icon(Icons.radio_rounded), text: tx('Radyo')),
              Tab(icon: const Icon(Icons.podcasts_rounded), text: tx('Podcast')),
              Tab(icon: const Icon(Icons.newspaper_rounded), text: tx('Haber')),
              Tab(icon: const Icon(Icons.cloud_queue_rounded), text: tx('Online')),
            ],
          ),
        ),
        body: const Column(
          children: [
            Expanded(
              child: TabBarView(
                  children: [
                    MusicTab(),
                    RadioTab(),
                    PodcastTab(),
                    NewsTab(),
                    OnlineTab()
                  ]),
            ),
            NowBar(),
          ],
        ),
      ),
    );
  }
}

// ---------- Alttaki çalan parça çubuğu ----------
class NowBar extends StatelessWidget {
  const NowBar({super.key});

  static const _modeIcons = [
    Icons.playlist_play_rounded,
    Icons.repeat_rounded,
    Icons.repeat_one_rounded,
    Icons.shuffle_rounded,
  ];

  String _modeName(int m) {
    switch (m) {
      case 1:
        return tx('Tekrar');
      case 2:
        return tx('Tek şarkı tekrar');
      case 3:
        return tx('Karışık');
      default:
        return tx('Sırayla');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([media, store]),
      builder: (context, _) {
        if (media.nowId == null) return const SizedBox.shrink();
        final mode = store.playMode;
        final tone = tagTone(media.nowId ?? '');
        return Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.alphaBlend(
                    tone.withOpacity(p.dark ? 0.28 : 0.20), p.card),
                p.card,
              ],
            ),
            border: Border(top: BorderSide(color: tone.withOpacity(0.6))),
          ),
          padding: const EdgeInsets.fromLTRB(16, 8, 8, 8),
          child: SafeArea(
            top: false,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(media.nowTitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontWeight: FontWeight.w700, color: p.ink)),
                    ),
                    IconButton(
                        tooltip: tx('Durdur'),
                        onPressed: media.stop,
                        icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                if (media.error != null)
                  Align(
                    alignment: Alignment.centerLeft,
                    child: Text(media.error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error,
                            fontSize: 12.5)),
                  ),
                if (!media.isRadio)
                  StreamBuilder<Duration>(
                    stream: media.player.positionStream,
                    builder: (context, snap) {
                      final pos = snap.data ?? Duration.zero;
                      final dur = media.player.duration ?? Duration.zero;
                      final maxMs = dur.inMilliseconds.toDouble();
                      final v = pos.inMilliseconds
                          .clamp(0, dur.inMilliseconds)
                          .toDouble();
                      return Row(
                        children: [
                          Text(mmss(pos),
                              style: TextStyle(color: p.soft, fontSize: 12)),
                          Expanded(
                            child: Slider(
                              value: v,
                              max: maxMs > 0 ? maxMs : 1,
                              onChanged: maxMs > 0
                                  ? (x) => media.player
                                      .seek(Duration(milliseconds: x.round()))
                                  : null,
                            ),
                          ),
                          Text(mmss(dur),
                              style: TextStyle(color: p.soft, fontSize: 12)),
                        ],
                      );
                    },
                  ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (media.isSong)
                      IconButton(
                        tooltip: _modeName(mode),
                        onPressed: () {
                          final nm = (mode + 1) % 4;
                          store.setPlayMode(nm);
                          final m = ScaffoldMessenger.of(context);
                          m.clearSnackBars();
                          m.showSnackBar(SnackBar(
                              duration: const Duration(milliseconds: 1200),
                              content: Text(_modeName(nm))));
                        },
                        icon: Icon(_modeIcons[mode],
                            color: mode == 0 ? p.soft : p.ink),
                      ),
                    if (media.isSong || media.isOnline)
                      IconButton(
                          tooltip: tx('Önceki'),
                          onPressed: media.isOnline
                              ? () => media.nextOnline(step: -1)
                              : media.prev,
                          icon: const Icon(Icons.skip_previous_rounded,
                              size: 32)),
                    if (media.isPod)
                      IconButton(
                          tooltip: tx('10 sn geri'),
                          onPressed: () => media.skipBy(-10),
                          icon: const Icon(Icons.replay_10_rounded, size: 30)),
                    media.loading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 28,
                                height: 28,
                                child:
                                    CircularProgressIndicator(strokeWidth: 3)),
                          )
                        : IconButton(
                            tooltip: media.playing ? tx('Duraklat') : tx('Çal'),
                            onPressed: media.toggle,
                            icon: Icon(
                                media.playing
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_fill_rounded,
                                size: 48)),
                    if (media.isSong || media.isOnline)
                      IconButton(
                          tooltip: tx('Sonraki'),
                          onPressed: media.isOnline
                              ? () => media.nextOnline()
                              : media.next,
                          icon: const Icon(Icons.skip_next_rounded, size: 32)),
                    if (media.isPod)
                      IconButton(
                          tooltip: tx('30 sn ileri'),
                          onPressed: () => media.skipBy(30),
                          icon: const Icon(Icons.forward_30_rounded, size: 30)),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
