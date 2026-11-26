import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ambient.dart';
import 'data.dart';
import 'media.dart';
import 'news.dart' show newsReader, startNewsReading;
import 'radio.dart' show radFavOnly;
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';
import 'tvpop.dart';

// ---------------------------------------------------------------
// ANA EKRAN: ÇALMA ŞERİTLERİ
//  Her medya sayfasının (Müzik, Radyo, TV, Podcast, Haber, Online) üstünde "Ana ekrana arayüz ekle"
//  anahtarı vardır. Anahtarı açık sayfanın şeridi, üstteki program simgelerinin hemen altında görünür.
//  - Düzen: solda ⌄ (aşağı açar: çalma kontrolleri + favoriler) ve oynat-duraklat, ortada şarkı/başlık,
//    sağda ✕. ✕ çalanı durdurur (TV'de pop-up'ı kapatır) ve şeridi ana ekrandan kaldırır
//    ("Geri al" ile geri gelir; ya da sayfadaki anahtarla yeniden eklenir).
//  - O sayfadan bir şey çalıyorsa: canlı şerit. Radyoda yukarı/aşağı kaydırma: sonraki/önceki
//    istasyon; dokununca sayfa açılır.
//  - Çalmıyorsa: son çalınan öğe görünür; ▶ onu başlatır (TV'de pop-up, Haber'de sesli okuma,
//    Podcast'te kaldığın bölüm, Müzik'te son şarkı ya da online parça).
//  - Anahtarı kapalı sayfanın şeridi çıkmaz.
//  Radyo varsayılan olarak açıktır, diğerleri kapalı.
// ---------------------------------------------------------------
bool dockOn(String id) => store.pBool('dock_$id', id == 'radio');
void dockSet(String id, bool v) => store.setProf('dock_$id', v);

(IconData, String) dockTab(String id) {
  switch (id) {
    case 'music':
      return (Icons.music_note_rounded, tx('Müzik'));
    case 'radio':
      return (Icons.radio_rounded, tx('Radyo'));
    case 'tv':
      return (Icons.live_tv_rounded, tx('TV'));
    case 'podcast':
      return (Icons.podcasts_rounded, tx('Podcast'));
    case 'news':
      return (Icons.newspaper_rounded, tx('Haber'));
    default:
      return (Icons.cloud_queue_rounded, tx('Online'));
  }
}

void _openTab(BuildContext context, String id) {
  Navigator.of(context).push(slideFromRight(MediaPage(initial: id)));
}

/// Sekmenin en son çalınan öğesinin adı; yoksa ''
String dockLastTitle(String id) {
  if (id == 'radio') {
    for (final c in store.radCats) {
      for (final st in c.stations) {
        if (st.id == store.lastRadioId) return st.name;
      }
    }
  } else if (id == 'music') {
    if (store.pStr('lmus') == 'online') {
      final o = _lastOnline();
      if (o != null) return o.title;
    }
    final pid = store.pStr('lspl'), sid = store.pStr('lsong');
    for (final pl in store.playlists) {
      if (pl.id != pid) continue;
      for (final s in pl.songs) {
        if (s.id == sid) return s.title;
      }
    }
    final o = _lastOnline();
    if (o != null) return o.title;
  } else if (id == 'podcast') {
    final m = _lastPod();
    if (m != null) return (m['t'] ?? '').toString();
  } else if (id == 'tv') {
    final tid = store.pStr('ltv');
    for (final c in store.tvChans) {
      if (c.id == tid) return c.name;
    }
  }
  return '';
}

/// Son çalınan online parça (yoksa null)
OnTrack? _lastOnline() {
  try {
    final raw = store.pStr('lonl');
    if (raw.isEmpty) return null;
    final t = OnTrack.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    return t.url.isEmpty ? null : t;
  } catch (_) {
    return null;
  }
}

/// Son dinlenen podcast bölümü (yoksa null): {k, t, u, a, r}
Map<String, dynamic>? _lastPod() {
  try {
    final raw = store.pStr('lpod');
    if (raw.isEmpty) return null;
    final m = jsonDecode(raw) as Map<String, dynamic>;
    return (m['u'] ?? '').toString().isEmpty ? null : m;
  } catch (_) {
    return null;
  }
}

/// Sekmenin son çalanını başlatır ve şerit görünür; son çalan yoksa sekmeyi açar
Future<void> dockLaunch(BuildContext context, String id) async {
  if (id == 'radio') {
    for (final c in store.radCats) {
      for (final st in c.stations) {
        if (st.id == store.lastRadioId) {
          tvPop.close();
          await media.playStation(st);
          return;
        }
      }
    }
  } else if (id == 'music') {
    final o = _lastOnline();
    if (store.pStr('lmus') == 'online' && o != null) {
      tvPop.close();
      await media.playOnline([o], 0);
      return;
    }
    final pid = store.pStr('lspl'), sid = store.pStr('lsong');
    for (final pl in store.playlists) {
      if (pl.id != pid) continue;
      for (final s in pl.songs) {
        if (s.id == sid) {
          tvPop.close();
          await media.playSong(pl, s);
          return;
        }
      }
    }
    if (o != null) {
      tvPop.close();
      await media.playOnline([o], 0);
      return;
    }
  } else if (id == 'podcast') {
    final m = _lastPod();
    if (m != null) {
      tvPop.close();
      await media.playPodRaw((m['k'] ?? '').toString(), (m['t'] ?? '').toString(),
          (m['u'] ?? '').toString(), (m['a'] ?? '').toString(), (m['r'] ?? '').toString());
      return;
    }
  } else if (id == 'news') {
    tvPop.close();
    await startNewsReading(context); // doğrudan sesli okumayı başlatır
    return;
  } else if (id == 'tv') {
    final tid = store.pStr('ltv');
    for (final c in store.tvChans) {
      if (c.id == tid) {
        tvPop.show(c);
        return;
      }
    }
    for (final c in store.tvChans) {
      if (c.fav) {
        tvPop.show(c); // son kanal yoksa ilk favori
        return;
      }
    }
  }
  if (context.mounted) _openTab(context, id);
}

String _kindTab() {
  if (media.isRadio) return 'radio';
  if (media.isSong) return 'music';
  if (media.isPod) return 'podcast';
  if (media.isNews) return 'news';
  if (media.isOnline) return 'music'; // Online artık Müzik sekmesinin içinde
  return '';
}

/// Medya sayfalarının üstündeki "Ana ekrana arayüz ekle" anahtarı
class DockSwitch extends StatelessWidget {
  final String id;
  const DockSwitch({super.key, required this.id});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final on = dockOn(id);
        return Container(
          decoration: BoxDecoration(border: Border(bottom: BorderSide(color: p.line))),
          padding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
          child: Row(children: [
            Icon(Icons.home_rounded, size: 20, color: on ? p.accent : p.soft),
            const SizedBox(width: 10),
            Expanded(
              child: Text(tx('Ana ekrana arayüz ekle'),
                  style: TextStyle(
                      fontSize: 14, fontWeight: FontWeight.w600, color: p.ink)),
            ),
            Switch(value: on, onChanged: (v) => dockSet(id, v)),
          ]),
        );
      },
    );
  }
}

/// ⌄ panelinin altındaki favori satırı (radyo istasyonları / TV kanalları)
class _FavRow extends StatelessWidget {
  final String id;
  const _FavRow({required this.id});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final chips = <Widget>[];
    if (id == 'radio') {
      for (final c in store.radCats) {
        for (final st in c.stations) {
          if (!st.fav) continue;
          chips.add(Padding(
            padding: const EdgeInsets.only(right: 6),
            child: ChoiceChip(
              label: Text(st.name, maxLines: 1),
              selected: media.isRadio && media.nowId == st.id,
              onSelected: (_) {
                tvPop.close();
                media.playStation(st);
              },
            ),
          ));
        }
      }
    } else if (id == 'tv') {
      for (final c in store.tvChans) {
        if (!c.fav) continue;
        chips.add(Padding(
          padding: const EdgeInsets.only(right: 6),
          child: ChoiceChip(
            label: Text(c.name, maxLines: 1),
            selected: tvPop.chan?.id == c.id,
            onSelected: (_) => tvPop.show(c),
          ),
        ));
      }
    }
    final star = id == 'tv' ? tx('kanalın yanındaki yıldıza bas') : tx('istasyonun yanındaki yıldıza bas');
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 4, 8, 6),
      alignment: Alignment.centerLeft,
      child: chips.isEmpty
          ? Text(tx('Favori yok, {0}', [star]),
              style: TextStyle(color: p.soft, fontSize: 12.5))
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx('Favoriler'),
                    style: TextStyle(
                        color: p.soft, fontSize: 11.5, fontWeight: FontWeight.w600)),
                SizedBox(
                  height: 44,
                  child: ListView(scrollDirection: Axis.horizontal, children: chips),
                ),
              ],
            ),
    );
  }
}

class HomeDock extends StatefulWidget {
  const HomeDock({super.key});

  @override
  State<HomeDock> createState() => _HomeDockState();
}

class _HomeDockState extends State<HomeDock> {
  String _open = ''; // ⌄ ile açık olan şeridin sekme kimliği

  Widget _shell(Pal p, Color tone, Widget child) => Container(
        decoration: BoxDecoration(
          color: ambBg(p) == Colors.transparent
              ? Colors.transparent
              : Color.alphaBlend(tone.withOpacity(0.10), ambBg(p)),
          border: Border(bottom: BorderSide(color: p.line)),
        ),
        child: child,
      );

  bool _hasFav(String id) => id == 'radio' || id == 'tv';

  Widget _arrow(Pal p, String id, bool show) {
    if (!show) return const SizedBox(width: 40, height: 40); // ok olmayan satırlarda aynı boşluk
    final open = _open == id;
    return IconButton(
      tooltip: open ? tx('Kapat') : tx('Aç'),
      visualDensity: VisualDensity.compact,
      onPressed: () => setState(() => _open = open ? '' : id),
      icon: Icon(open ? Icons.keyboard_arrow_up_rounded : Icons.keyboard_arrow_down_rounded,
          color: p.ink),
    );
  }

  Widget _panel(String id, bool live) {
    if (_open != id) return const SizedBox(width: double.infinity);
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (live) const EmbeddedPlayer(),
        if (_hasFav(id)) _FavRow(id: id),
      ],
    );
  }

  /// ✕: çalanı durdurur (TV'de pop-up'ı kapatır) ve şeridi ana ekrandan kaldırır.
  /// "Geri al" ile geri gelir; Medya sayfasındaki anahtarla da yeniden eklenir.
  Future<void> _removeStrip(BuildContext context, String id, {required bool live}) async {
    final m = ScaffoldMessenger.of(context);
    if (_open == id) setState(() => _open = '');
    if (id == 'tv') {
      tvPop.close();
    } else if (live) {
      if (media.isNews && newsReader.reading) await newsReader.stop();
      if (media.nowId != null) await media.stop();
    }
    dockSet(id, false);
    m.clearSnackBars();
    m.showSnackBar(SnackBar(
      duration: const Duration(seconds: 4),
      content: Text(tx('Ana ekrandan kaldırıldı.')),
      action: SnackBarAction(label: tx('Geri al'), onPressed: () => dockSet(id, true)),
    ));
  }

  Widget _closeBtn(BuildContext context, Pal p, String id, bool live) => IconButton(
        tooltip: tx('Ana ekrandan kaldır'),
        visualDensity: VisualDensity.compact,
        onPressed: () => _removeStrip(context, id, live: live),
        icon: Icon(Icons.close_rounded, color: p.ink),
      );

  /// Bu sekmeden bir şey çalıyor: canlı şerit
  Widget _live(BuildContext context, Pal p, String id) {
    final tone = tagTone(media.nowId ?? '');
    // Radyoda iki satır: üstte radyo adı, altında "Sanatçı - Şarkı"; diğerlerinde tek satır başlık
    final title = media.nowTitle;
    var sub = '';
    if (media.isRadio) {
      final (artist, song) = media.nowSong;
      sub = song.isEmpty
          ? media.icyTitle
          : (artist.isEmpty ? song : '$artist - $song');
    }
    void openTab() {
      if (media.isRadio) {
        var fav = false;
        for (final c in store.radCats) {
          for (final st in c.stations) {
            if (st.id == media.nowId) fav = fav || st.fav;
          }
        }
        radFavOnly.value = fav; // favorideyse Favoriler, değilse Hepsi
      }
      _openTab(context, id);
    }

    return _shell(
      p,
      tone,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: openTab,
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
            child: SizedBox(
              height: (media.isRadio && sub.isNotEmpty) ? 54 : 40,
              child: Row(children: [
                media.loading
                    ? const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 10),
                        child: SizedBox(
                            width: 20,
                            height: 20,
                            child: CircularProgressIndicator(strokeWidth: 2.2)),
                      )
                    : IconButton(
                        tooltip: media.playing ? tx('Duraklat') : tx('Çal'),
                        visualDensity: VisualDensity.compact,
                        onPressed: media.toggle,
                        icon: Icon(
                            media.playing ? Icons.pause_rounded : Icons.play_arrow_rounded,
                            color: p.ink),
                      ),
                _arrow(p, id, true),
                Icon(dockTab(id).$1, size: 18, color: tone),
                const SizedBox(width: 8),
                Expanded(
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(title,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w700, color: p.ink)),
                      if (sub.isNotEmpty)
                        Text(sub,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(fontSize: 12, color: p.soft)),
                    ],
                  ),
                ),
                _closeBtn(context, p, id, true),
              ]),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: _panel(id, true),
          ),
        ],
      ),
    );
  }

  /// Çalmıyor: son çalınan öğe + ▶ (TV'de pop-up açıksa pop-up'ın adı ve kapat)
  Widget _idle(BuildContext context, Pal p, String id) {
    final popping = id == 'tv' && tvPop.chan != null;
    final last = popping ? tvPop.chan!.name : dockLastTitle(id);
    final label = last.isEmpty ? dockTab(id).$2 : '${dockTab(id).$2} · $last';
    return _shell(
      p,
      p.accent,
      Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onTap: () => _openTab(context, id),
            child: SizedBox(
              height: 40,
              child: Row(children: [
                if (popping)
                  IconButton(
                    tooltip: tx('Durdur'),
                    visualDensity: VisualDensity.compact,
                    onPressed: tvPop.close,
                    icon: Icon(Icons.pause_rounded, color: p.ink),
                  )
                else
                  IconButton(
                    tooltip: tx('Çal'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => dockLaunch(context, id),
                    icon: Icon(Icons.play_arrow_rounded, color: p.ink),
                  ),
                _arrow(p, id, _hasFav(id)),
                Icon(dockTab(id).$1, size: 18, color: p.accent),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(label,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          fontSize: 13, fontWeight: FontWeight.w600, color: p.soft)),
                ),
                _closeBtn(context, p, id, false),
              ]),
            ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 180),
            alignment: Alignment.topCenter,
            child: _panel(id, false),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([media, store, tvPop]),
      builder: (context, _) {
        final ids = [
          for (final id in mediaTabIds())
            if (dockOn(id)) id
        ];
        if (ids.isEmpty) return const SizedBox.shrink();
        if (_open.isNotEmpty && !ids.contains(_open)) _open = '';
        final playing = media.nowId == null ? '' : _kindTab();
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            for (final id in ids)
              id == playing ? _live(context, p, id) : _idle(context, p, id),
          ],
        );
      },
    );
  }
}
