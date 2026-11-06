import 'dart:io';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'data.dart';
import 'media.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// MÜZİK SEKMESİ
//  - "Oynatma listesi ekle": ad ver, yeni liste açılır
//  - Listeye dokun: aşağı doğru açılır, şarkılar görünür
//  - Şarkı ekle: telefondan şarkı seç (uygulamanın kendi alanına kopyalanır)
//  - Soldaki ≡ tutamacı ile şarkıları sürükleyip sırala
//  - Çalma stili düğmesi alttaki çalma çubuğundadır
// ---------------------------------------------------------------
class MusicTab extends StatelessWidget {
  const MusicTab({super.key});

  Future<void> _addList(BuildContext context) async {
    final n = await askText(context, tx('Oynatma listesi adı'));
    if (n == null || n.trim().isEmpty) return;
    store.addPlaylist(n.trim());
  }

  Future<void> _renameList(BuildContext context, Playlist pl) async {
    final n = await askText(context, tx('Oynatma listesi adı'),
        initial: pl.name);
    if (n == null || n.trim().isEmpty) return;
    store.renamePlaylist(pl.id, n.trim());
  }

  Future<void> _removeList(BuildContext context, Playlist pl) async {
    if (store.playlists.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tx('En az bir liste kalmalı.'))));
      return;
    }
    final ok = await confirmDialog(
      context,
      tx('Oynatma listesi silinsin mi?'),
      tx('"{0}" ve içindeki {1} şarkı silinecek.', [pl.name, pl.songs.length]),
      okLabel: tx('Sil'),
    );
    if (!ok) return;
    if (media.curListId == pl.id && media.isSong) await media.stop();
    store.removePlaylist(pl.id);
  }

  Future<void> _addSongs(BuildContext context, Playlist pl) async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await FilePicker.platform
          .pickFiles(type: FileType.audio, allowMultiple: true);
      if (res == null) return;
      final dir = await store.musicDir();
      var n = 0;
      for (final f in res.files) {
        final src = f.path;
        if (src == null) continue;
        final name = f.name;
        final dot = name.lastIndexOf('.');
        final ext = dot > 0 ? name.substring(dot) : '';
        final title = dot > 0 ? name.substring(0, dot) : name;
        final dest = '${dir.path}/${store.newId()}$ext';
        await File(src).copy(dest);
        // Seçici geçici kopya bıraktıysa onu temizle (yer kaplamasın)
        if (src.contains('/cache/')) {
          try {
            await File(src).delete();
          } catch (_) {}
        }
        store.addSong(pl.id, title, dest);
        n++;
      }
      messenger
          .showSnackBar(SnackBar(content: Text(tx('{0} şarkı eklendi.', [n]))));
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(tx('Şarkı eklenemedi: {0}', ['$e']))));
    }
  }

  /// Şarkıyı sormadan siler; altta "Geri al" çıkar
  Future<void> _removeSong(BuildContext context, Playlist pl, Song s) async {
    final index = pl.songs.indexWhere((x) => x.id == s.id);
    if (media.nowId == s.id && media.isSong) await media.stop();
    store.removeSong(pl.id, s.id);
    if (!context.mounted) return;
    showUndo(context, tx('"{0}" silindi.', [s.title]),
        () => store.restoreSong(pl.id, s, index));
  }

  Future<void> _renameSong(BuildContext context, Playlist pl, Song s) async {
    final t = await askText(context, tx('Şarkı adı'), initial: s.title);
    if (t == null || t.trim().isEmpty) return;
    store.renameSong(pl.id, s.id, t.trim());
  }

  Widget _songs(BuildContext context, Playlist pl) {
    final p = palOf(context);
    if (pl.songs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(tx('Bu listede şarkı yok.'),
              style: TextStyle(color: p.soft, fontSize: 13)),
        ),
      );
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: pl.songs.length,
      onReorder: (a, b) {
        var to = b;
        if (to > a) to -= 1;
        store.moveSong(pl.id, a, to);
      },
      itemBuilder: (context, i) {
        final s = pl.songs[i];
        final cur = media.nowId == s.id && media.isSong;
        return SwipeRow(
          key: ValueKey(s.id),
          tag: 'sg_${s.id}',
          onEdit: () => _renameSong(context, pl, s),
          onDelete: () => _removeSong(context, pl, s),
          child: ColoredBox(
            color: palOf(context).card,
            child: ListTile(
          dense: true,
          contentPadding: const EdgeInsets.only(left: 8, right: 0),
          leading: ReorderableDragStartListener(
            index: i,
            child: Padding(
              padding: const EdgeInsets.all(8),
              child: Icon(Icons.drag_handle_rounded, color: p.soft),
            ),
          ),
          title: Text(s.title,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: cur ? FontWeight.w700 : FontWeight.w400)),
          onTap: () => media.playSong(pl, s),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cur)
                Icon(media.playing ? Icons.graphic_eq_rounded : Icons.pause_rounded,
                    color: p.ink, size: 20),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'rename') _renameSong(context, pl, s);
                  if (v == 'delete') _removeSong(context, pl, s);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(
                      value: 'rename', child: Text(tx('Adı değiştir'))),
                  PopupMenuItem(value: 'delete', child: Text(tx('Sil'))),
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

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([store, media]),
      builder: (context, _) {
        final lists = store.playlists;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _addList(context),
                      icon: const Icon(Icons.playlist_add_rounded),
                      label: Text(tx('Oynatma listesi ekle')),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: lists.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          tx('Henüz oynatma listesi yok. "Oynatma listesi ekle" ile başla, sonra listeye telefonundan şarkı ekle.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.soft, height: 1.4),
                        ),
                      ),
                    )
                  : ReorderableListView.builder(
                      padding: const EdgeInsets.only(bottom: 12),
                      buildDefaultDragHandles: false,
                      itemCount: lists.length,
                      onReorder: (o, n) {
                        if (n > o) n -= 1;
                        store.movePlaylist(o, n);
                      },
                      itemBuilder: (context, i) {
                        final pl = lists[i];
                        return SwipeRow(
                          key: ValueKey(pl.id),
                          tag: 'pl_${pl.id}',
                          padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                          radius: 14,
                          onEdit: () => _renameList(context, pl),
                          onDelete: () => _removeList(context, pl),
                          child: MediaGroup(
                            colorSeed: pl.id,
                            title: pl.name,
                            info: '${pl.songs.length}',
                            open: pl.open,
                            margin: EdgeInsets.zero,
                            handle: ReorderableDragStartListener(
                              index: i,
                              child: Padding(
                                padding: const EdgeInsets.all(8),
                                child: Icon(Icons.drag_handle_rounded,
                                    color: p.soft),
                              ),
                            ),
                            onToggle: () => store.togglePlaylist(pl.id),
                            menu: PopupMenuButton<String>(
                              onSelected: (v) {
                                if (v == 'rename') _renameList(context, pl);
                                if (v == 'delete') _removeList(context, pl);
                              },
                              itemBuilder: (_) => [
                                PopupMenuItem(
                                    value: 'rename',
                                    child: Text(tx('Adı değiştir'))),
                                PopupMenuItem(
                                    value: 'delete', child: Text(tx('Sil'))),
                              ],
                            ),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                _songs(context, pl),
                                Align(
                                  alignment: Alignment.centerLeft,
                                  child: Padding(
                                    padding: const EdgeInsets.fromLTRB(
                                        8, 0, 8, 6),
                                    child: TextButton.icon(
                                      onPressed: () => _addSongs(context, pl),
                                      icon: const Icon(Icons.add_rounded),
                                      label: Text(tx('Şarkı ekle')),
                                    ),
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
            ),
          ],
        );
      },
    );
  }
}
