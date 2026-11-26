import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import 'ambient.dart';
import 'data.dart';
import 'media.dart';
import 'music.dart' show musicSub;
import 'shortcuts.dart' show AppsChannel;
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// ÇALAN ŞARKI BİLGİSİ, SHAZAM DÜĞMESİ VE "İSTEKLERİM" LİSTESİ
//  - Radyo yayını şarkı adını (StreamTitle) gönderiyorsa gösterilir; kapak varsa yanında.
//  - Shazam telefonda kuruluysa düğme çıkar ve Shazam'ı açar; kurulu değilse hiç görünmez.
//  - İsteklerim: duyduğun şarkıyı kaydet; sonra YouTube / Spotify / Amazon Music'te ara ya da
//    telefondaki dosyası varsa çal.
// ---------------------------------------------------------------
const String _kShazam = 'com.shazam.android';

bool? _shazamOk;
Future<bool>? _shazamQ;

Future<bool> shazamInstalled() {
  if (_shazamOk != null) return Future.value(_shazamOk!);
  return _shazamQ ??= AppsChannel.list().then((l) {
    _shazamOk = l.any((e) => e.$2 == _kShazam);
    return _shazamOk!;
  });
}

Future<Uint8List?>? _shazamIcon;

/// Shazam düğmesi: telefondaki gerçek Shazam simgesi; kurulu değilse hiçbir şey çizmez
class ShazamButton extends StatelessWidget {
  final double size;
  const ShazamButton({super.key, this.size = 26});

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: shazamInstalled(),
      builder: (context, snap) {
        if (snap.data != true) return const SizedBox.shrink();
        _shazamIcon ??= AppsChannel.icon(_kShazam);
        return FutureBuilder<Uint8List?>(
          future: _shazamIcon,
          builder: (context, ic) {
            final b = ic.data;
            return IconButton(
              tooltip: 'Shazam',
              visualDensity: VisualDensity.compact,
              onPressed: () => AppsChannel.launch(_kShazam),
              icon: b == null
                  ? Icon(Icons.graphic_eq_rounded, size: size)
                  : ClipRRect(
                      borderRadius: BorderRadius.circular(size / 4),
                      child: Image.memory(b,
                          width: size, height: size, fit: BoxFit.cover),
                    ),
            );
          },
        );
      },
    );
  }
}

Future<void> _open(String url) async {
  try {
    await launchUrl(Uri.parse(url), mode: LaunchMode.externalApplication);
  } catch (_) {}
}

String _q(String s) => Uri.encodeComponent(s);

void searchYoutube(String q) =>
    _open('https://www.youtube.com/results?search_query=${_q(q)}');
void searchYoutubeMusic(String q) =>
    _open('https://music.youtube.com/search?q=${_q(q)}');
void searchSpotify(String q) => _open('https://open.spotify.com/search/${_q(q)}');
void searchAmazon(String q) => _open('https://music.amazon.com/search/${_q(q)}');

/// Telefondaki şarkılar arasında ada göre eşleşeni çalar; bulunamazsa false
Future<bool> playLocalMatch(String title, String artist) async {
  String n(String s) => s.toLowerCase().replaceAll(RegExp(r'[^a-z0-9çğıöşüâî ]'), ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
  final t = n(title);
  if (t.isEmpty) return false;
  for (final pl in store.playlists) {
    for (final s in pl.songs) {
      final st = n(s.title);
      if (st.contains(t) || (st.length > 3 && t.contains(st))) {
        await media.playSong(pl, s);
        return true;
      }
    }
  }
  return false;
}

/// Radyoda şarkı adı gelmediğinde gösterilen kısa durum yazısı
String icyStatusLine() => media.icyState == 'none'
    ? tx('Bu istasyon şarkı bilgisi göndermiyor')
    : media.icyState == 'empty'
        ? tx('Yayında şarkı adı yok')
        : media.icyState == 'err'
            ? tx('Şarkı bilgisi alınamadı, tekrar denenecek')
            : tx('Şarkı bilgisi aranıyor...');

/// Çalan şarkıyı İsteklerim'e ekler; mesajdaki "Listeyi aç" Müzik > İsteklerim'e götürür
void addWishNow(BuildContext context) {
  final (artist, title) = media.nowSong;
  if (title.isEmpty) return;
  final from = media.isRadio ? media.nowTitle : tx('Müzik');
  final added = store.addWish(title, artist, from);
  final m = ScaffoldMessenger.of(context);
  m.clearSnackBars();
  m.showSnackBar(SnackBar(
    duration: const Duration(milliseconds: 2400),
    content: Text(added ? tx('İsteklerime eklendi.') : tx('Bu şarkı zaten İsteklerimde.')),
    action: SnackBarAction(
      label: tx('Listeyi aç'),
      onPressed: () {
        musicSub.value = 2;
        Navigator.of(context).push(slideFromRight(const MediaPage(initial: 'music')));
      },
    ),
  ));
}

/// "İsteklerime ekle" kalbi (ana ekran panelinde)
class WishButton extends StatelessWidget {
  const WishButton({super.key});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([media, store]),
      builder: (context, _) {
        final (artist, title) = media.nowSong;
        if (title.isEmpty) return const SizedBox.shrink();
        final has = store.hasWish(title, artist);
        return IconButton(
          tooltip: has ? tx('İsteklerimde') : tx('İsteklerime ekle'),
          onPressed: () => addWishNow(context),
          icon: Icon(has ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: has ? Colors.redAccent : p.soft),
        );
      },
    );
  }
}

/// Çalma çubuğunda: kapak + şarkı adı + Shazam ve "İsteklerime ekle" düğmeleri
class SongInfoBlock extends StatelessWidget {
  const SongInfoBlock({super.key});

  // Not: Bu pencere "const" olarak kullanıldığı için üst widget yenilense de yeniden çizilmez.
  // Bu yüzden kendi dinleyicisi var: yayında şarkı değişince burası da güncellenir.
  @override
  Widget build(BuildContext context) => ListenableBuilder(
        listenable: Listenable.merge([media, store]),
        builder: (context, _) => _build(context),
      );

  Widget _build(BuildContext context) {
    final p = palOf(context);
    final (artist, title) = media.nowSong;
    final art = media.nowArt;
    final isRadio = media.isRadio;
    final showSong = title.isNotEmpty;
    if (!showSong && art.isEmpty && !(isRadio || media.isSong || media.isOnline)) {
      return const SizedBox.shrink();
    }
    final has = showSong && store.hasWish(title, artist);
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          if (art.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 10),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: Image.network(art,
                    width: 44,
                    height: 44,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => const SizedBox(width: 44, height: 44)),
              ),
            ),
          Expanded(
            child: showSong
                ? Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: p.ink, fontSize: 14, fontWeight: FontWeight.w600)),
                      if (artist.isNotEmpty)
                        Text(artist,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(color: p.soft, fontSize: 12.5)),
                    ],
                  )
                : Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          isRadio ? icyStatusLine() : '',
                          style: TextStyle(color: p.soft, fontSize: 12.5)),
                      if (isRadio && media.icyDiag.isNotEmpty)
                        Text(media.icyDiag,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                                color: p.soft.withOpacity(0.7), fontSize: 10.5)),
                    ],
                  ),
          ),
          const ShazamButton(),
          if (showSong)
            IconButton(
              tooltip: has ? tx('İsteklerimde') : tx('İsteklerime ekle'),
              visualDensity: VisualDensity.compact,
              onPressed: () => addWishNow(context),
              icon: Icon(has ? Icons.favorite_rounded : Icons.favorite_border_rounded,
                  color: has ? Colors.redAccent : p.soft),
            ),
        ],
      ),
    );
  }
}

/// İsteklerim sayfası
class WishesPage extends StatelessWidget {
  const WishesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return AmbScaffold(
      kind: 'media',
      backgroundColor: ambBg(p),
      appBar: AppBar(title: Text(tx('İsteklerim'))),
      body: const WishesList(),
    );
  }
}

/// İsteklerim listesi (Medya > Müzik > İsteklerim içinde gösterilir)
class WishesList extends StatelessWidget {
  const WishesList({super.key});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
        listenable: store,
        builder: (context, _) {
          if (store.wishes.isEmpty) {
            return Center(
              child: Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                    tx('Henüz şarkı yok. Radyoda ya da çalarda çalan şarkının yanındaki kalbe dokununca buraya eklenir.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.soft)),
              ),
            );
          }
          return ListView.builder(
            padding: const EdgeInsets.fromLTRB(12, 4, 12, 24),
            itemCount: store.wishes.length,
            itemBuilder: (context, i) {
              final w = store.wishes[i];
              return Dismissible(
                key: ValueKey(w.id),
                direction: DismissDirection.endToStart,
                background: Container(
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.only(right: 20),
                  color: Colors.redAccent.withOpacity(0.8),
                  child: const Icon(Icons.delete_outline_rounded, color: Colors.white),
                ),
                onDismissed: (_) {
                  final idx = i;
                  store.removeWish(w.id);
                  final m = ScaffoldMessenger.of(context);
                  m.clearSnackBars();
                  m.showSnackBar(SnackBar(
                    content: Text(tx('Kaldırıldı.')),
                    action: SnackBarAction(
                        label: tx('Geri al'), onPressed: () => store.restoreWish(w, idx)),
                  ));
                },
                child: Container(
                  margin: const EdgeInsets.only(top: 6),
                  padding: const EdgeInsets.fromLTRB(2, 0, 0, 0),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.line),
                  ),
                  // Tek satır, ince: [▶]  Şarkı – Sanatçı · Kaynak  [⋮]
                  child: Row(
                    children: [
                      IconButton(
                        visualDensity: VisualDensity.compact,
                        tooltip: tx('Çal'),
                        icon: Icon(Icons.play_arrow_rounded, color: p.accent),
                        onPressed: () async {
                          final ok = await playLocalMatch(w.title, w.artist);
                          if (!ok) searchYoutubeMusic(w.query);
                        },
                      ),
                      Expanded(
                        child: Text.rich(
                          TextSpan(children: [
                            TextSpan(
                                text: w.title,
                                style: TextStyle(
                                    color: p.ink,
                                    fontSize: 14,
                                    fontWeight: FontWeight.w700)),
                            if (w.artist.isNotEmpty)
                              TextSpan(
                                  text: ' – ${w.artist}',
                                  style: TextStyle(color: p.soft, fontSize: 13)),
                            if (w.from.isNotEmpty)
                              TextSpan(
                                  text: ' · ${w.from}',
                                  style: TextStyle(color: p.soft, fontSize: 11.5)),
                          ]),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      PopupMenuButton<int>(
                        padding: EdgeInsets.zero,
                        icon: Icon(Icons.more_vert_rounded, color: p.soft),
                        onSelected: (v) {
                          if (v == 0) searchYoutube(w.query);
                          if (v == 1) searchSpotify(w.query);
                          if (v == 2) searchAmazon(w.query);
                        },
                        itemBuilder: (_) => const [
                          PopupMenuItem(value: 0, child: Text('YouTube')),
                          PopupMenuItem(value: 1, child: Text('Spotify')),
                          PopupMenuItem(value: 2, child: Text('Amazon Music')),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            },
          );
        },
    );
  }
}
