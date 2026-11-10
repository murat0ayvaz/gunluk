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
      androidNotificationOngoing: false,
      androidStopForegroundOnPause: false, // duraklatınca medya oturumu açık kalır (direksiyon tuşları için)
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
const _kNews = 'news';

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
  bool get isNews => nowKind == _kNews;
  // Direksiyon / kulaklık tuşları için: asıl parça iki sessiz "nöbetçi" parça
  // arasına konur; ileri/geri tuşu nöbetçiye geçişi tetikler.
  bool _guarded = false;
  DateTime newsIgnoreUntil = DateTime(2000);
  int _srcGen = 0;
  Duration _realPos = Duration.zero;
  Duration? _realDur;

  AudioSource _guard(String id, String title) => AudioSource.asset(
      'assets/sounds/silence.wav',
      tag: MediaItem(id: 'g_$id', title: title, artist: 'Daily Routine'));
  List<OnTrack> onQueue = []; // online çalma sırası

  void _start() {
    if (_started) return;
    _started = true;
    player.currentIndexStream.listen((i) {
      if (_guarded && i != null && i != 1) _onGuard(i);
    });
    player.playingStream.listen((pl) {
      if (!isNews || DateTime.now().isBefore(newsIgnoreUntil)) return;
      if (pl) {
        newsReader.resume(fromMedia: true);
      } else {
        newsReader.pause(fromMedia: true);
      }
    });
    player.playerStateStream.listen((s) {
      if (s.processingState == ProcessingState.completed && !_guarded) {
        _onCompleted();
      } else if (!s.playing && isPod) {
        _savePod();
      }
      notifyListeners();
    });
    // Podcast konumunu 15 saniyede bir kaydet
    player.positionStream.listen((pos) {
      if (_guarded && player.currentIndex == 1) {
        _realPos = pos;
        _realDur = player.duration;
      }
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
      if (store.repeatMode == 2) {
        player.seek(Duration.zero);
        player.play();
      } else {
        next(auto: true);
      }
    } else if (isOnline) {
      if (store.repeatMode == 2) {
        player.seek(Duration.zero);
        player.play();
      } else {
        nextOnline(auto: true);
      }
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
    if (newsReader.reading) newsReader.stop(keepMedia: true);
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
      final real = AudioSource.uri(uri,
          tag: MediaItem(
              id: id,
              title: title,
              album: album,
              artist: 'Daily Routine',
              artUri: (art == null || art.isEmpty) ? null : Uri.tryParse(art)));
      _srcGen++;
      _realPos = start ?? Duration.zero;
      _realDur = null;
      if (kind == _kVoice) {
        _guarded = false;
        await player.setAudioSource(real, initialPosition: start);
      } else {
        _guarded = false;
        await player.setAudioSource(
            ConcatenatingAudioSource(
                children: [_guard('p', title), real, _guard('n', title)]),
            initialIndex: 1,
            initialPosition: start);
        _guarded = true;
      }
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
    int n;
    if (store.shuffleOn && onQueue.length > 1 && step > 0) {
      do {
        n = _rnd.nextInt(onQueue.length);
      } while (n == i);
    } else {
      n = i + step;
      if (n >= onQueue.length) {
        // Tekrar kapalıyken liste bitince durur (otomatik geçişte)
        if (auto && store.repeatMode == 0) {
          player.pause();
          player.seek(Duration.zero);
          notifyListeners();
          return;
        }
        n = 0;
      }
      if (n < 0) n = onQueue.length - 1;
    }
    playOnline(onQueue, n);
  }

  Future<void> _backToReal(int gen, {Duration? pos, bool play = true}) async {
    if (gen != _srcGen || !_guarded) return;
    try {
      await player.seek(pos ?? _realPos, index: 1);
      if (play) {
        player.play();
      } else {
        await player.pause();
      }
    } catch (_) {}
  }

  void _radioStep(int d) {
    for (final c in store.radCats) {
      final i = c.stations.indexWhere((x) => x.id == nowId);
      if (i < 0) continue;
      final n = (i + d) % c.stations.length;
      playStation(c.stations[n < 0 ? n + c.stations.length : n]);
      return;
    }
  }

  /// Nöbetçi parçaya geçildi: 0 = geri tuşu, 2 = ileri tuşu (ya da parça bitti)
  void _onGuard(int i) {
    final gen = _srcGen;
    if (isNews) {
      if (i == 2) {
        newsReader.nextItem();
      } else {
        newsReader.prevItem();
      }
      _backToReal(gen, pos: Duration.zero);
      return;
    }
    final dur = _realDur;
    final ended = i == 2 &&
        dur != null &&
        _realPos >= dur - const Duration(seconds: 2);
    if (ended && (isSong || isOnline) && store.repeatMode == 2) {
      _backToReal(gen, pos: Duration.zero);
      return;
    }
    if (i == 2) {
      if (ended) {
        _onCompleted();
      } else if (isSong) {
        next();
      } else if (isOnline) {
        nextOnline(step: 1);
      } else if (isRadio) {
        _radioStep(1);
      } else if (isPod) {
        _backToReal(gen, pos: _realPos + const Duration(seconds: 30));
        return;
      }
    } else {
      if (isSong) {
        if (_realPos > const Duration(seconds: 3)) {
          _backToReal(gen, pos: Duration.zero);
          return;
        }
        prev();
      } else if (isOnline) {
        nextOnline(step: -1);
      } else if (isRadio) {
        _radioStep(-1);
      } else if (isPod) {
        final t = _realPos - const Duration(seconds: 15);
        _backToReal(gen, pos: t < Duration.zero ? Duration.zero : t);
        return;
      }
    }
    // Kaynak değişmediyse (liste bitti vb.) asıl parçaya dön
    Future.delayed(const Duration(milliseconds: 500), () {
      if (gen == _srcGen) _backToReal(gen, play: !ended);
    });
  }

  /// Haber okurken medya oturumunu (bildirim + direksiyon tuşları) açık tutar
  Future<void> startNewsSession(String title) async {
    _start();
    _savePod();
    podKey = null;
    error = null;
    nowKind = _kNews;
    nowId = 'news';
    nowTitle = title;
    notifyListeners();
    try {
      await player.setLoopMode(LoopMode.off);
      _srcGen++;
      _guarded = false;
      _realPos = Duration.zero;
      final src = AudioSource.asset('assets/sounds/silence.wav',
          tag: MediaItem(id: 'news', title: title, artist: 'Daily Routine'));
      await player.setAudioSource(
          ConcatenatingAudioSource(children: [
            _guard('p', title),
            src,
            _guard('n', title),
          ]),
          initialIndex: 1);
      _guarded = true;
      await player.setLoopMode(LoopMode.one);
      player.play();
    } catch (_) {}
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
    if (isNews) {
      newsReader.togglePause();
      return;
    }
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
    int n;
    if (store.shuffleOn && l.length > 1) {
      do {
        n = _rnd.nextInt(l.length);
      } while (n == i);
    } else {
      n = i + 1;
      if (n >= l.length) {
        // Tekrar kapalıyken liste bitince durur
        if (auto && store.repeatMode == 0) {
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
    _guarded = false;
    _srcGen++;
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

  static const _repIcons = [
    Icons.repeat_rounded,
    Icons.repeat_rounded,
    Icons.repeat_one_rounded,
  ];

  String _repName(int m) {
    switch (m) {
      case 1:
        return tx('Sürekli tekrar');
      case 2:
        return tx('Tek parça tekrar');
      default:
        return tx('Tekrar kapalı');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([media, store]),
      builder: (context, _) {
        if (media.nowId == null) return const SizedBox.shrink();
        final rep = store.repeatMode;
        final shuf = store.shuffleOn;
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
                    // Tekrar: Kapalı > Sürekli > 1 tekrar (her basışta döner)
                    if (media.isSong || media.isOnline)
                      IconButton(
                        tooltip: _repName(rep),
                        onPressed: () {
                          final nr = (rep + 1) % 3;
                          store.setRepeat(nr);
                          final m = ScaffoldMessenger.of(context);
                          m.clearSnackBars();
                          m.showSnackBar(SnackBar(
                              duration: const Duration(milliseconds: 1200),
                              content: Text(_repName(nr))));
                        },
                        icon: Icon(_repIcons[rep],
                            color: rep == 0 ? p.soft : tone),
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
                    if (media.isSong || media.isOnline)
                      IconButton(
                        tooltip: tx('Karışık'),
                        onPressed: () => store.setShuffle(!shuf),
                        icon: Icon(Icons.shuffle_rounded,
                            color: shuf ? tone : p.soft),
                      ),
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
