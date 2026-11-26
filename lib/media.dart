import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:just_audio/just_audio.dart';
import 'package:just_audio_background/just_audio_background.dart';
import 'ambient.dart';
import 'data.dart';
import 'dock.dart' show DockSwitch;
import 'icy.dart';
import 'music.dart';
import 'news.dart';
import 'online.dart';
import 'net.dart';
import 'nowsong.dart';
import 'podcast.dart';
import 'radio.dart';
import 'strings.dart';
import 'tv.dart';
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
      // false: duraklatınca bildirim yerinde kalır, tekrar başlatınca yeni bildirim sesi çıkmaz.
      // ✕ ile durdurulunca çalar kapatıldığı için (stop) bildirim yine tamamen kalkar.
      androidStopForegroundOnPause: false,
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
  // Çalar ilk gerektiğinde oluşturulur. ✕ ile kapatınca eski çalar bırakılır ve YENİSİ hemen oluşturulmaz:
  // boşta duran yeni çalar telefondaki medya bildirimini ekranda tutabiliyordu.
  AudioPlayer? _p;
  AudioPlayer get player => _p ??= AudioPlayer();
  set player(AudioPlayer v) => _p = v;
  final Random _rnd = Random();
  String? nowId; // çalan şarkı / radyo / bölüm kimliği
  String nowTitle = '';
  String icyTitle = ''; // radyo yayınından gelen şarkı adı (StreamTitle)
  String icyUrl = ''; // yayından gelen adres / kapak (StreamUrl)
  String icyState = 'search'; // search | ok | empty | none | err
  String icyDiag = ''; // yayından gelen ham bilgi / hata nedeni (küçük teşhis satırı)
  Timer? _icyTimer;
  int _icyGen = 0;
  String? _radioUrl; // çalan radyonun yayın adresi (bildirim başlığını yenilemek için)
  String _tagged = ''; // bildirim başlığına yazılan son şarkı
  bool _retagBusy = false;

  /// Radyoda şarkı değişince bildirimin / kilit ekranının başlığını "Sanatçı - Şarkı" yapar.
  /// Paket başlığı yalnız kaynakla birlikte değiştirebildiği için yayın kısa süre yeniden bağlanır
  /// (Ayarlar'dan kapatılabilir: prof 'ntitle').
  Future<void> _retag() async {
    if (!isRadio || nowId == null || _retagBusy || loading) return;
    if (!store.pBool('ntitle', true)) return;
    final t = icyTitle;
    final u = _radioUrl == null ? null : Uri.tryParse(_radioUrl!);
    if (u == null || t.isEmpty || t == _tagged) return;
    _retagBusy = true;
    final id = nowId!;
    final station = nowTitle;
    final my = ++_srcGen;
    try {
      final wasPlaying = player.playing;
      _guarded = false;
      final real = AudioSource.uri(u,
          tag: MediaItem(id: id, title: t, album: station, artist: station));
      await player.setAudioSource(
          ConcatenatingAudioSource(
              children: [_guard('p', t), real, _guard('n', t)]),
          initialIndex: 1);
      if (my != _srcGen || !isRadio || nowId != id) return;
      _guarded = true;
      _tagged = t;
      if (wasPlaying) player.play();
    } catch (e) {
      if (my == _srcGen) {
        _guarded = true;
        icyDiag = 'bildirim: ${_msg(e)}'; // teşhis için küçük satırda görünür
        notifyListeners();
      }
    } finally {
      _retagBusy = false;
    }
  }

  /// Radyo çalarken yayından şarkı adını ~15 sn'de bir okur (çaladan bağımsız)
  void _icyStart(String url) {
    _icyStop();
    final g = _icyGen;
    Future<void> tick() async {
      if (g != _icyGen || !isRadio) return;
      final r = await icyFetch(url);
      if (g != _icyGen || !isRadio) return;
      var t = r.title;
      if (t.toLowerCase() == nowTitle.toLowerCase()) t = ''; // istasyon adını tekrar etme
      var st = r.state;
      if (st == 'ok' && t.isEmpty) st = 'empty';
      if (t.isNotEmpty) st = 'ok';
      // şarkı adı gelmediyse mevcut (çaladan gelen) adı silme
      final nt = t.isNotEmpty ? t : icyTitle;
      if (nt.isNotEmpty) st = 'ok';
      if (nt != icyTitle || (r.url.isNotEmpty && r.url != icyUrl) || st != icyState || r.diag != icyDiag) {
        icyTitle = nt;
        if (r.url.isNotEmpty) icyUrl = r.url;
        icyState = st;
        icyDiag = r.diag;
        notifyListeners();
        _retag();
      }
      if (st == 'none') _icyTimer?.cancel(); // desteklemiyor: boşuna tekrar etme
    }

    tick();
    _icyTimer = Timer.periodic(const Duration(seconds: 15), (_) => tick());
  }

  void _icyStop() {
    _icyGen++;
    _icyTimer?.cancel();
    _icyTimer = null;
    icyState = 'search';
    icyDiag = '';
  }
  String nowKind = ''; // song | radio | pod
  String? curListId; // çalan şarkının oynatma listesi
  String? podKey; // çalan podcast bölümünün kayıt anahtarı
  bool loading = false;
  String? error;
  bool _started = false;
  int _lastSave = 0;

  bool get playing => _p?.playing ?? false;

  /// Çalan radyonun kapağı: listedeki logo, yoksa yayının gönderdiği resim adresi
  String get nowArt {
    if (!isRadio) return '';
    for (final c in store.radCats) {
      for (final st in c.stations) {
        if (st.id == nowId && st.art.isNotEmpty) return st.art;
      }
    }
    final u = icyUrl.toLowerCase().split('?').first;
    if (u.startsWith('http') &&
        (u.endsWith('.jpg') || u.endsWith('.jpeg') || u.endsWith('.png') || u.endsWith('.webp'))) {
      return icyUrl;
    }
    return '';
  }

  /// Şarkı: radyoda yayından gelen "Sanatçı - Şarkı", çalarda parça adı; (sanatçı, şarkı)
  (String, String) get nowSong {
    final t = isRadio ? icyTitle : (isSong || isOnline ? nowTitle : '');
    if (t.isEmpty) return ('', '');
    final i = t.indexOf(' - ');
    if (i > 0 && i < t.length - 3) {
      return (t.substring(0, i).trim(), t.substring(i + 3).trim());
    }
    return ('', t.trim());
  }
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
    player.icyMetadataStream.listen((m) {
      if (!isRadio) return;
      var t = (m?.info?.title ?? '').trim();
      final u = (m?.info?.url ?? '').trim();
      if (t.toLowerCase() == nowTitle.toLowerCase()) t = ''; // istasyon adını tekrar etme
      if (t.isEmpty || (t == icyTitle && u == icyUrl)) return; // boş gelen, kendi okuduğumuzu silmesin
      icyTitle = t;
      if (u.isNotEmpty) icyUrl = u;
      icyState = 'ok';
      notifyListeners();
      _retag();
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
    _icyStop();
    icyTitle = '';
    icyUrl = '';
    _tagged = '';
    _radioUrl = kind == _kRadio ? uri.toString() : null;
    nowKind = kind;
    nowId = id;
    nowTitle = title;
    loading = true;
    notifyListeners();
    var my = _srcGen;
    try {
      final real = AudioSource.uri(uri,
          tag: MediaItem(
              id: id,
              title: title,
              album: album,
              artist: 'Daily Routine',
              artUri: (art == null || art.isEmpty) ? null : Uri.tryParse(art)));
      my = ++_srcGen;
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
      if (kind == _kRadio) {
        _icyStart(uri.toString());
      } else {
        _icyStop();
      }
      player.play(); // çalma bitene kadar tamamlanmaz, beklenmez
    } catch (e) {
      // Daha yeni bir yükleme (başka istasyon ya da başlık yenileme) bu yüklemeyi iptal ettiyse
      // "Connection aborted" hatası yalancıdır; gösterilmez.
      if (my != _srcGen) return;
      loading = false;
      error = tx('Çalınamadı: {0}', [_msg(e)]);
      notifyListeners();
    }
  }

  Future<void> playSong(Playlist pl, Song s) async {
    curListId = pl.id;
    store.setProf('lspl', pl.id); // ana ekran kısayolu: son çalan şarkı
    store.setProf('lsong', s.id);
    store.setProf('lmus', 'song'); // Müzik şeridinde ▶ en son çalınanı başlatır
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
    store.setLastRadio(r.id);
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
    // ana ekran şeridinde ▶ son dinlenen bölümü devam ettirir
    store.setProf('lpod',
        jsonEncode({'k': e.key, 't': e.title, 'u': e.url, 'a': p.title, 'r': p.art}));
    await playPodRaw(e.key, e.title, e.url, p.title, p.art);
  }

  Future<void> playPodRaw(String key, String title, String url, String album, String art) async {
    final u = Uri.tryParse(url);
    if (u == null) return;
    final saved = store.epPos[key] ?? 0;
    await _play(key, title, u, _kPod,
        start: saved > 0 ? Duration(milliseconds: saved) : null,
        album: album,
        art: art,
        pKey: key);
  }

  /// Online parçayı çalar; q = çalma sırası (liste), i = sıradaki
  Future<void> playOnline(List<OnTrack> q, int i) async {
    if (i < 0 || i >= q.length) return;
    onQueue = List<OnTrack>.from(q);
    final tr = q[i];
    final u = Uri.tryParse(tr.url);
    if (u == null) return;
    store.setProf('lonl', jsonEncode(tr.toJson())); // Müzik şeridinde ▶ için son online parça
    store.setProf('lmus', 'online');
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

  /// Radyoda önceki (-1) / sonraki (+1) istasyon; aynı kategoride döner.
  /// Yüklenirken art arda basış yok sayılır.
  void radioStep(int d) {
    if (loading) return;
    _radioStep(d);
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
    _icyStop();
    icyTitle = '';
    icyUrl = '';
    nowKind = '';
    podKey = null;
    error = null;
    loading = false;
    notifyListeners();
    // Çaları tamamen kapatıp yenisini oluştururuz: telefondaki medya bildirimi ve
    // oturumu da kapanır (yalnız stop() bildirimi ekranda bırakıyordu).
    final old = _p;
    _p = null; // yenisi bir sonraki çalmada oluşturulur
    _started = false; // sonraki çalmada dinleyiciler yeni çaların üstüne bağlanır
    try {
      await old?.stop();
    } catch (_) {}
    try {
      await old?.dispose();
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
/// Açık olan sekmeler (Ayarlar > Uygulamalar'dan kapatılanlar çıkar)
List<String> mediaTabIds() => [
      for (final id in const ['music', 'radio', 'tv', 'podcast', 'news'])
        if (!store.appHidden(id)) id
    ];

class MediaPage extends StatelessWidget {
  final String? initial; // açılacak sekme: music | radio | tv | podcast | news | online
  const MediaPage({super.key, this.initial});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final ids = mediaTabIds();
        final initial2 = initial == 'online' ? 'music' : initial; // Online artık Müzik sekmesinin içinde
        if (ids.isEmpty) {
          return AmbScaffold(kind: 'media', 
            backgroundColor: ambBg(p),
            appBar: AppBar(title: Text(tx('Medya'))),
            body: Center(child: Text(tx('Tüm sekmeler Ayarlar > Uygulamalar bölümünden kapatılmış.'))),
          );
        }
        Tab tab(String id) {
          switch (id) {
            case 'music':
              return Tab(icon: const Icon(Icons.music_note_rounded), text: tx('Müzik'));
            case 'radio':
              return Tab(icon: const Icon(Icons.radio_rounded), text: tx('Radyo'));
            case 'tv':
              return Tab(icon: const Icon(Icons.live_tv_rounded), text: tx('TV'));
            case 'podcast':
              return Tab(icon: const Icon(Icons.podcasts_rounded), text: tx('Podcast'));
            case 'news':
              return Tab(icon: const Icon(Icons.newspaper_rounded), text: tx('Haber'));
            default:
              return Tab(icon: const Icon(Icons.cloud_queue_rounded), text: tx('Online'));
          }
        }

        Widget view(String id) {
          switch (id) {
            case 'music':
              return const MusicHub();
            case 'radio':
              return const RadioTab();
            case 'tv':
              return const TvTab();
            case 'podcast':
              return const PodcastTab();
            case 'news':
              return const NewsTab();
            default:
              return const OnlineTab();
          }
        }

        return DefaultTabController(
          key: ValueKey(ids.join(',')),
          length: ids.length,
          initialIndex: (initial2 != null && ids.contains(initial2)) ? ids.indexOf(initial2) : 0,
          child: AmbScaffold(kind: 'media', 
            backgroundColor: ambBg(p),
            appBar: AppBar(
              title: Text(tx('Medya')),
              bottom: TabBar(tabs: [for (final id in ids) tab(id)]),
            ),
            body: Column(
              children: [
                Expanded(
                  child: TabBarView(children: [
                    for (final id in ids)
                      Column(children: [
                        DockSwitch(id: id),
                        Expanded(child: view(id)),
                      ]),
                  ]),
                ),
                const NowBar(),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------- Alttaki çalan parça çubuğu ----------
class NowBar extends StatelessWidget {
  final bool showClose; // ana ekran panelinde şeritte zaten ✕ var; orada false
  const NowBar({super.key, this.showClose = true});

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
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          // radyoda yukarı kaydır: sonraki istasyon, aşağı kaydır: önceki
          onVerticalDragEnd: media.isRadio
              ? (d) {
                  final v = d.primaryVelocity ?? 0;
                  if (v < -400) {
                    HapticFeedback.selectionClick();
                    media.radioStep(1);
                  } else if (v > 400) {
                    HapticFeedback.selectionClick();
                    media.radioStep(-1);
                  }
                }
              : null,
          child: Container(
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
                    if (showClose)
                      IconButton(
                          tooltip: tx('Durdur'),
                          onPressed: media.stop,
                          icon: const Icon(Icons.close_rounded)),
                  ],
                ),
                if (media.isRadio || media.isSong || media.isOnline)
                  const SongInfoBlock(),
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
                    if (media.isRadio)
                      IconButton(
                          tooltip: tx('Önceki istasyon'),
                          onPressed: () => media.radioStep(-1),
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
                    if (media.isRadio)
                      IconButton(
                          tooltip: tx('Sonraki istasyon'),
                          onPressed: () => media.radioStep(1),
                          icon: const Icon(Icons.skip_next_rounded, size: 32)),
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
          ),
        );
      },
    );
  }
}


String _repLabel(int m) {
  switch (m) {
    case 1:
      return tx('Sürekli tekrar');
    case 2:
      return tx('Tek parça tekrar');
    default:
      return tx('Tekrar kapalı');
  }
}

/// Ana ekran şeridinin ⌄ paneli: başlık / şarkı yazısı YOK (şeritte zaten yazıyor), ayrı kutu ve
/// zemin YOK (şeritle aynı zeminde, bütünleşik). Yalnız kontroller; radyoda Shazam ve ♥ aynı satırda.
class EmbeddedPlayer extends StatelessWidget {
  const EmbeddedPlayer({super.key});

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
        final songish = media.isSong || media.isOnline;
        final hasSong = media.nowSong.$2.isNotEmpty;
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (media.error != null)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8),
                    child: Text(media.error!,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error, fontSize: 12.5)),
                  ),
                ),
              if (media.isRadio && !hasSong)
                Align(
                  alignment: Alignment.centerLeft,
                  child: Padding(
                    padding: const EdgeInsets.only(left: 8, bottom: 2),
                    child: Text(icyStatusLine(),
                        style: TextStyle(color: p.soft, fontSize: 12)),
                  ),
                ),
              if (!media.isRadio)
                StreamBuilder<Duration>(
                  stream: media.player.positionStream,
                  builder: (context, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final dur = media.player.duration ?? Duration.zero;
                    final maxMs = dur.inMilliseconds.toDouble();
                    final v = pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble();
                    return Row(
                      children: [
                        const SizedBox(width: 8),
                        Text(mmss(pos), style: TextStyle(color: p.soft, fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: v,
                            max: maxMs > 0 ? maxMs : 1,
                            onChanged: maxMs > 0
                                ? (x) => media.player.seek(Duration(milliseconds: x.round()))
                                : null,
                          ),
                        ),
                        Text(mmss(dur), style: TextStyle(color: p.soft, fontSize: 12)),
                        const SizedBox(width: 8),
                      ],
                    );
                  },
                ),
              FittedBox(
                fit: BoxFit.scaleDown,
                child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  if (media.isRadio || songish) const ShazamButton(),
                  if (songish)
                    IconButton(
                      tooltip: _repLabel(rep),
                      onPressed: () => store.setRepeat((rep + 1) % 3),
                      icon: Icon(
                          rep == 2 ? Icons.repeat_one_rounded : Icons.repeat_rounded,
                          color: rep == 0 ? p.soft : tone),
                    ),
                  if (songish)
                    IconButton(
                        tooltip: tx('Önceki'),
                        onPressed: media.isOnline
                            ? () => media.nextOnline(step: -1)
                            : media.prev,
                        icon: const Icon(Icons.skip_previous_rounded, size: 30)),
                  if (media.isRadio)
                    IconButton(
                        tooltip: tx('Önceki istasyon'),
                        onPressed: () => media.radioStep(-1),
                        icon: const Icon(Icons.skip_previous_rounded, size: 30)),
                  if (media.isPod)
                    IconButton(
                        tooltip: tx('10 sn geri'),
                        onPressed: () => media.skipBy(-10),
                        icon: const Icon(Icons.replay_10_rounded, size: 28)),
                  media.loading
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 26,
                              height: 26,
                              child: CircularProgressIndicator(strokeWidth: 3)),
                        )
                      : IconButton(
                          tooltip: media.playing ? tx('Duraklat') : tx('Çal'),
                          onPressed: media.toggle,
                          icon: Icon(
                              media.playing
                                  ? Icons.pause_circle_filled_rounded
                                  : Icons.play_circle_fill_rounded,
                              size: 44)),
                  if (media.isRadio)
                    IconButton(
                        tooltip: tx('Sonraki istasyon'),
                        onPressed: () => media.radioStep(1),
                        icon: const Icon(Icons.skip_next_rounded, size: 30)),
                  if (songish)
                    IconButton(
                        tooltip: tx('Sonraki'),
                        onPressed: media.isOnline ? () => media.nextOnline() : media.next,
                        icon: const Icon(Icons.skip_next_rounded, size: 30)),
                  if (songish)
                    IconButton(
                      tooltip: tx('Karışık'),
                      onPressed: () => store.setShuffle(!shuf),
                      icon: Icon(Icons.shuffle_rounded, color: shuf ? tone : p.soft),
                    ),
                  if (media.isPod)
                    IconButton(
                        tooltip: tx('30 sn ileri'),
                        onPressed: () => media.skipBy(30),
                        icon: const Icon(Icons.forward_30_rounded, size: 28)),
                  if (media.isRadio || songish) const WishButton(),
                ],
              )),
            ],
          ),
        );
      },
    );
  }
}
