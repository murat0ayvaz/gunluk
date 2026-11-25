import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'ambient.dart';
import 'data.dart';
import 'media.dart';
import 'radio.dart' show radFavOnly;
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';
import 'tvpop.dart';

// ---------------------------------------------------------------
// ANA EKRAN: ÇALMA ŞERİDİ VE KISAYOL ÇUBUĞU
//  Üstteki program simgelerinin hemen altında, tam genişlikte, onlara bitişik görünür.
//  - Bir şey çalıyorsa: şerit. Solda ⌄ (aşağı açar: çalma kontrolleri), ortada şarkı/başlık,
//    oynat-duraklat, sağda ✕ (durdur). Radyoda yukarı/aşağı kaydırma: sonraki/önceki istasyon;
//    dokununca Radyo sekmesi Favoriler görünümüyle açılır.
//  - Çalmıyorsa ve sabitliyse: kısayol çubuğu (Müzik, Radyo, TV ... + 📌).
//  - Kulaklık simgesine uzun basınca: sekmelerin menüsü; hangisine basarsan o ana ekrana gelir.
// ---------------------------------------------------------------
bool dockPinned() => store.pBool('dockpin', false);
void dockSetPin(bool v) => store.setProf('dockpin', v);

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
  } else if (id == 'tv') {
    final tid = store.pStr('ltv');
    for (final c in store.tvChans) {
      if (c.id == tid) {
        tvPop.show(c);
        return;
      }
    }
  }
  if (context.mounted) _openTab(context, id);
}

/// Kulaklık simgesine uzun basınca açılan menü
Future<void> showDockMenu(BuildContext context) async {
  final box = context.findRenderObject() as RenderBox?;
  final overlay = Overlay.of(context).context.findRenderObject() as RenderBox?;
  if (box == null || overlay == null) return;
  final tl = box.localToGlobal(Offset.zero, ancestor: overlay);
  final rect = RelativeRect.fromLTRB(
      tl.dx, tl.dy + box.size.height, overlay.size.width - tl.dx - box.size.width, 0);
  final ids = mediaTabIds();
  HapticFeedback.mediumImpact();
  final v = await showMenu<String>(
    context: context,
    position: rect,
    items: [
      for (final id in ids)
        PopupMenuItem<String>(
          value: id,
          child: Row(children: [
            Icon(dockTab(id).$1, size: 22),
            const SizedBox(width: 12),
            Text(dockTab(id).$2),
          ]),
        ),
      const PopupMenuDivider(),
      PopupMenuItem<String>(
        value: '_pin',
        child: Row(children: [
          Icon(dockPinned() ? Icons.push_pin_rounded : Icons.push_pin_outlined, size: 22),
          const SizedBox(width: 12),
          Text(dockPinned() ? tx('Kısayol çubuğunu kaldır') : tx('Kısayol çubuğunu sabitle')),
        ]),
      ),
    ],
  );
  if (v == null || !context.mounted) return;
  if (v == '_pin') {
    dockSetPin(!dockPinned());
  } else {
    dockLaunch(context, v);
  }
}

String _kindTab() {
  if (media.isRadio) return 'radio';
  if (media.isSong) return 'music';
  if (media.isPod) return 'podcast';
  if (media.isNews) return 'news';
  if (media.isOnline) return 'online';
  return '';
}

class HomeDock extends StatefulWidget {
  const HomeDock({super.key});

  @override
  State<HomeDock> createState() => _HomeDockState();
}

class _HomeDockState extends State<HomeDock> {
  bool _open = false; // ⌄ ile açılan kontrol paneli

  Widget _shell(Pal p, Color tone, Widget child) => Container(
        decoration: BoxDecoration(
          color: ambBg(p) == Colors.transparent
              ? Colors.transparent
              : Color.alphaBlend(tone.withOpacity(0.10), ambBg(p)),
          border: Border(bottom: BorderSide(color: p.line)),
        ),
        child: child,
      );

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([media, store]),
      builder: (context, _) {
        if (media.nowId == null) {
          _open = false;
          if (!dockPinned()) return const SizedBox.shrink();
          return _shell(
            p,
            p.accent,
            SizedBox(
              height: 40,
              child: Row(children: [
                const SizedBox(width: 8),
                for (final id in mediaTabIds())
                  IconButton(
                    tooltip: dockTab(id).$2,
                    visualDensity: VisualDensity.compact,
                    onPressed: () => dockLaunch(context, id),
                    icon: Icon(dockTab(id).$1, size: 22, color: p.accent),
                  ),
                const Spacer(),
                IconButton(
                  tooltip: tx('Kısayol çubuğunu kaldır'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () => dockSetPin(false),
                  icon: Icon(Icons.push_pin_rounded, size: 20, color: p.soft),
                ),
              ]),
            ),
          );
        }
        final tone = tagTone(media.nowId ?? '');
        final tab = _kindTab();
        String title = media.nowTitle;
        if (media.isRadio && media.icyTitle.isNotEmpty) {
          title = '${media.icyTitle} · ${media.nowTitle}';
        }
        void openTab() {
          if (tab.isEmpty) return;
          if (media.isRadio) {
            var fav = false;
            for (final c in store.radCats) {
              for (final st in c.stations) {
                if (st.id == media.nowId) fav = fav || st.fav;
              }
            }
            radFavOnly.value = fav; // favorideyse Favoriler, değilse Hepsi
          }
          _openTab(context, tab);
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
                  height: 40,
                  child: Row(children: [
                    IconButton(
                      tooltip: _open ? tx('Kapat') : tx('Aç'),
                      visualDensity: VisualDensity.compact,
                      onPressed: () => setState(() => _open = !_open),
                      icon: Icon(
                          _open
                              ? Icons.keyboard_arrow_up_rounded
                              : Icons.keyboard_arrow_down_rounded,
                          color: p.ink),
                    ),
                    Icon(tab.isEmpty ? Icons.graphic_eq_rounded : dockTab(tab).$1,
                        size: 18, color: tone),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                          media.playing ? title : '${tx('Duraklatıldı')} · $title',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 13, fontWeight: FontWeight.w600, color: p.ink)),
                    ),
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
                                media.playing
                                    ? Icons.pause_rounded
                                    : Icons.play_arrow_rounded,
                                color: p.ink),
                          ),
                    IconButton(
                      tooltip: tx('Durdur'),
                      visualDensity: VisualDensity.compact,
                      onPressed: media.stop,
                      icon: Icon(Icons.close_rounded, color: p.ink),
                    ),
                  ]),
                ),
              ),
              AnimatedSize(
                duration: const Duration(milliseconds: 180),
                alignment: Alignment.topCenter,
                child: _open ? const NowBar() : const SizedBox(width: double.infinity),
              ),
            ],
          ),
        );
      },
    );
  }
}
