import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:video_player/video_player.dart';
import 'package:wakelock_plus/wakelock_plus.dart';
import 'data.dart';
import 'media.dart';
import 'net.dart';
import 'ambient.dart';
import 'strings.dart';
import 'theme.dart';
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

/// Favoriler üstte, sonra eklenme sırası (sesli komut aramasında kullanılır)
List<TvChan> tvSorted() {
  final l = List<TvChan>.of(store.tvChans);
  final fav = [for (final c in l) if (c.fav) c];
  final rest = [for (final c in l) if (!c.fav) c];
  return [...fav, ...rest];
}

/// Hazır kanalın kategorisi (adından)
String _presetCat(String name) {
  final n = name.toLowerCase();
  if (n.contains('haber')) return tx('Haber');
  if (n.contains('spor')) return tx('Spor');
  if (n.contains('çocuk')) return tx('Çocuk');
  if (n.contains('belgesel')) return tx('Belgesel');
  if (n.contains('müzik')) return tx('Müzik');
  return tx('Genel');
}

/// Dizindeki grup / kanal adından kategori önerisi
String tvSuggestCat(String group, String name) {
  final n = '$group $name'.toLowerCase();
  bool has(List<String> k) => k.any((x) => n.contains(x));
  if (has(['news', 'haber'])) return tx('Haber');
  if (has(['sport', 'spor'])) return tx('Spor');
  if (has(['kids', 'child', 'çocuk', 'cocuk', 'animation', 'cartoon'])) {
    return tx('Çocuk');
  }
  if (has(['documentary', 'belgesel', 'science', 'nature'])) {
    return tx('Belgesel');
  }
  if (has(['music', 'müzik', 'muzik'])) return tx('Müzik');
  return tx('Genel');
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

/// TV sekmesi: false = hepsi (kategoriler), true = sadece favoriler
final ValueNotifier<bool> tvFavOnly = ValueNotifier<bool>(false);

/// Dizinden eklerken kategori seçtirir. [suggest] önerilen kategori adıdır;
/// listede yoksa "yeni kategori" olarak sunulur. Seçilen kategori kimliğini döndürür.
Future<String?> pickTvCat(BuildContext context, String suggest) async {
  final cats = store.tvCats;
  final sugg = suggest.trim().toLowerCase();
  final existing = [
    for (final c in cats)
      if (c.name.trim().toLowerCase() == sugg) c
  ];
  final res = await showModalBottomSheet<String>(
    context: context,
    isScrollControlled: true,
    builder: (ctx) => SafeArea(
      child: ConstrainedBox(
        constraints:
            BoxConstraints(maxHeight: MediaQuery.of(ctx).size.height * 0.7),
        child: ListView(
          shrinkWrap: true,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 16, 20, 6),
              child: Text(tx('Hangi kategoriye eklensin?'),
                  style: const TextStyle(
                      fontSize: 17, fontWeight: FontWeight.w700)),
            ),
            if (existing.isEmpty && suggest.trim().isNotEmpty)
              ListTile(
                leading: const Icon(Icons.create_new_folder_outlined),
                title: Text(tx('Yeni kategori: {0}', [suggest.trim()])),
                subtitle: Text(tx('Önerilen')),
                onTap: () => Navigator.pop(ctx, '__new__'),
              ),
            for (final c in cats)
              ListTile(
                leading: Icon(
                    existing.contains(c)
                        ? Icons.star_rounded
                        : Icons.folder_outlined,
                    color: existing.contains(c) ? const Color(0xFFE9A23B) : null),
                title: Text(c.name),
                subtitle: existing.contains(c) ? Text(tx('Önerilen')) : null,
                onTap: () => Navigator.pop(ctx, c.id),
              ),
          ],
        ),
      ),
    ),
  );
  if (res == null) return null;
  if (res == '__new__') return store.tvCatByName(suggest);
  return res;
}

class TvTab extends StatelessWidget {
  const TvTab({super.key});

  Future<void> _addCat(BuildContext context) async {
    final n = await askText(context, tx('Kategori adı'));
    if (n == null || n.trim().isEmpty) return;
    store.addTvCat(n.trim());
  }

  Future<void> _renameCat(BuildContext context, TvCat c) async {
    final n = await askText(context, tx('Kategori adı'), initial: c.name);
    if (n == null || n.trim().isEmpty) return;
    store.renameTvCat(c.id, n.trim());
  }

  Future<void> _removeCat(BuildContext context, TvCat c) async {
    final messenger = ScaffoldMessenger.of(context);
    if (store.tvCats.length < 2) {
      messenger.showSnackBar(
          SnackBar(content: Text(tx('En az bir kategori kalmalı.'))));
      return;
    }
    final ok = await confirmDialog(
      context,
      tx('Kategori silinsin mi?'),
      tx('"{0}" silinir; içindeki kanallar ilk kategoriye geçer.', [c.name]),
      okLabel: tx('Sil'),
    );
    if (!ok) return;
    store.removeTvCat(c.id);
  }

  Future<void> _edit(BuildContext context, TvChan? c, {String? catId}) async {
    final name = TextEditingController(text: c?.name ?? '');
    final url = TextEditingController(text: c?.url ?? '');
    String? err;
    var cid = c?.cat ?? catId ?? store.tvCats.first.id;
    if (store.tvCatById(cid) == null) cid = store.tvCats.first.id;
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, set) => AlertDialog(
          title: Text(c == null ? tx('Kanal ekle') : tx('Kanalı düzenle')),
          content: SingleChildScrollView(
            child: Column(
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
                const SizedBox(height: 8),
                DropdownButton<String>(
                  isExpanded: true,
                  value: cid,
                  items: [
                    for (final k in store.tvCats)
                      DropdownMenuItem<String>(value: k.id, child: Text(k.name)),
                  ],
                  onChanged: (v) {
                    if (v != null) set(() => cid = v);
                  },
                ),
              ],
            ),
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
      store.addTvChan(n, u, catId: cid);
    } else {
      store.updateTvChan(c, n, u, catId: cid);
    }
  }

  // "Kanal ekle": dizinde ara (iptv-org) ya da elle ekle
  void _addMenu(BuildContext context, String? catId) {
    showModalBottomSheet<void>(
      context: context,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.travel_explore_rounded),
              title: Text(tx('Dizinde ara')),
              subtitle: Text(tx('Ülkeye ve ada göre herkese açık kanalları bul.')),
              onTap: () {
                Navigator.pop(ctx);
                Navigator.of(context)
                    .push(slideFromRight(TvBrowserPage(catId: catId)));
              },
            ),
            ListTile(
              leading: const Icon(Icons.edit_outlined),
              title: Text(tx('Elle ekle')),
              subtitle: Text(tx('Kanal adı ve yayın adresini kendin yaz.')),
              onTap: () {
                Navigator.pop(ctx);
                _edit(context, null, catId: catId);
              },
            ),
          ],
        ),
      ),
    );
  }

  /// Kanalı sormadan kaldırır; altta "Geri al" çıkar
  void _remove(BuildContext context, TvChan c) {
    final i = store.tvChans.indexOf(c);
    store.removeTvChan(c);
    showUndo(context, tx('"{0}" silindi.', [c.name]),
        () => store.restoreTvChan(c, i));
  }

  void _presets(BuildContext context) {
    final n = store.addTvPresets([
      for (final p in kTvPresets) (p.$1, p.$2, _presetCat(p.$1)),
    ]);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(
          content: Text(n > 0
              ? tx('{0} kanal eklendi. Çalışmayan olursa adresini düzenle.', [n])
              : tx('Hazır kanalların hepsi zaten listede.'))));
  }

  Widget _chans(BuildContext context, TvCat cat) {
    final p = palOf(context);
    final items = store.tvIn(cat.id);
    if (items.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(tx('Bu kategoride kanal yok.'),
              style: TextStyle(color: p.soft, fontSize: 13)),
        ),
      );
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: items.length,
      onReorder: (a, b) {
        var to = b;
        if (to > a) to -= 1;
        store.moveTvChan(cat.id, a, to);
      },
      itemBuilder: (context, i) {
        final c = items[i];
        return SwipeRow(
          key: ValueKey(c.id),
          tag: 'tv_${c.id}',
          onEdit: () => _edit(context, c),
          onDelete: () => _remove(context, c),
          child: ColoredBox(
            color: p.card,
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
              title: Text(c.name,
                  maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(Uri.tryParse(c.url)?.host ?? c.url,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: p.soft, fontSize: 12)),
              onTap: () => openTvChannel(context, c),
              trailing: IconButton(
                tooltip: tx('Favori'),
                visualDensity: VisualDensity.compact,
                onPressed: () => store.toggleTvFav(c),
                icon: Icon(
                    c.fav ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: c.fav ? const Color(0xFFE9A23B) : p.soft),
              ),
            ),
          ),
        );
      },
    );
  }

  /// Favoriler görünümü: tüm kategorilerdeki yıldızlı kanallar tek listede
  Widget _favList(BuildContext context) {
    final p = palOf(context);
    final items = [for (final c in store.tvChans) if (c.fav) c];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(tx('Henüz favori kanal yok. Kanalın yanındaki yıldıza dokun.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: p.soft, height: 1.4)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      children: [
        for (final c in items)
          Container(
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tagTone(c.cat).withOpacity(0.5)),
            ),
            child: ListTile(
              dense: true,
              title: Text(c.name, maxLines: 1, overflow: TextOverflow.ellipsis),
              subtitle: Text(store.tvCatById(c.cat)?.name ?? '',
                  style: TextStyle(color: p.soft, fontSize: 12)),
              onTap: () => openTvChannel(context, c),
              trailing: IconButton(
                tooltip: tx('Favori'),
                onPressed: () => store.toggleTvFav(c),
                icon: const Icon(Icons.star_rounded, color: Color(0xFFE9A23B)),
              ),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([store, tvFavOnly]),
      builder: (context, _) {
        store.tvReady();
        final cats = store.tvCats;
        final favOnly = tvFavOnly.value;
        return Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () => _addCat(context),
                      icon: const Icon(Icons.create_new_folder_outlined),
                      label: Text(tx('Kategori ekle')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => _addMenu(context, null),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(tx('Kanal ekle')),
                    ),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 2, 16, 2),
              child: Row(
                children: [
                  ChoiceChip(
                    label: Text(tx('Hepsi')),
                    selected: !favOnly,
                    onSelected: (_) => tvFavOnly.value = false,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.star_rounded,
                        size: 16, color: Color(0xFFE9A23B)),
                    label: Text(tx('Favoriler')),
                    selected: favOnly,
                    onSelected: (_) => tvFavOnly.value = true,
                  ),
                ],
              ),
            ),
            if (favOnly)
              Expanded(child: _favList(context))
            else
              Expanded(
                child: ReorderableListView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  buildDefaultDragHandles: false,
                  itemCount: cats.length,
                  onReorder: (o, n) {
                    if (n > o) n -= 1;
                    store.moveTvCat(o, n);
                  },
                  footer: Padding(
                    padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        OutlinedButton.icon(
                          onPressed: () => _presets(context),
                          icon: const Icon(Icons.playlist_add_rounded),
                          label: Text(tx('Hazır kanalları ekle')),
                        ),
                        const SizedBox(height: 10),
                        Text(
                          tx('Yayın adresleri zamanla değişebilir; çalışmayan kanalın adresini kaydırarak düzenle.'),
                          style: TextStyle(
                              color: p.soft, fontSize: 12.5, height: 1.4),
                        ),
                      ],
                    ),
                  ),
                  itemBuilder: (context, i) {
                    final c = cats[i];
                    return SwipeRow(
                      key: ValueKey(c.id),
                      tag: 'tc_${c.id}',
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                      radius: 14,
                      onEdit: () => _renameCat(context, c),
                      onDelete: () => _removeCat(context, c),
                      child: MediaGroup(
                        colorSeed: c.id,
                        title: c.name,
                        info: '${store.tvIn(c.id).length}',
                        open: c.open,
                        margin: EdgeInsets.zero,
                        handle: ReorderableDragStartListener(
                          index: i,
                          child: Padding(
                            padding: const EdgeInsets.all(8),
                            child:
                                Icon(Icons.drag_handle_rounded, color: p.soft),
                          ),
                        ),
                        onToggle: () => store.toggleTvCat(c.id),
                        menu: PopupMenuButton<String>(
                          onSelected: (v) {
                            if (v == 'add') _addMenu(context, c.id);
                            if (v == 'rename') _renameCat(context, c);
                            if (v == 'delete') _removeCat(context, c);
                          },
                          itemBuilder: (_) => [
                            PopupMenuItem(
                                value: 'add', child: Text(tx('Kanal ekle'))),
                            PopupMenuItem(
                                value: 'rename',
                                child: Text(tx('Adı değiştir'))),
                            PopupMenuItem(
                                value: 'delete', child: Text(tx('Sil'))),
                          ],
                        ),
                        child: _chans(context, c),
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


// ---------------------------------------------------------------
// TV DİZİNİ (iptv-org): ülke listesinden kanal bul, dene, ekle
//  Adres: https://iptv-org.github.io/iptv/countries/<ülke kodu>.m3u
//  Topluluk listesidir; bazı yayınlar çalışmayabilir ya da bölge kısıtlı olabilir.
// ---------------------------------------------------------------
class TvFound {
  final String name, url, group;
  TvFound(this.name, this.url, this.group);
}

final Map<String, List<TvFound>> _tvDirCache = {};

Future<List<TvFound>> tvDirectory(String cc) async {
  final key = cc.toLowerCase();
  final c = _tvDirCache[key];
  if (c != null) return c;
  final txt = await httpGetText(
      Uri.parse('https://iptv-org.github.io/iptv/countries/$key.m3u'),
      seconds: 20,
      maxBytes: 8000000);
  final out = <TvFound>[];
  String? name;
  var group = '';
  for (var l in txt.split(RegExp(r'\r?\n'))) {
    l = l.trim();
    if (l.startsWith('#EXTINF')) {
      final i = l.lastIndexOf(',');
      name = i >= 0 ? l.substring(i + 1).trim() : '';
      group = RegExp(r'group-title="([^"]*)"').firstMatch(l)?.group(1) ?? '';
    } else if (l.isNotEmpty && !l.startsWith('#')) {
      if (name != null &&
          name.isNotEmpty &&
          l.startsWith('http') &&
          !group.toUpperCase().contains('XXX')) {
        out.add(TvFound(name, l, group));
      }
      name = null;
    }
  }
  _tvDirCache[key] = out;
  return out;
}

class TvBrowserPage extends StatefulWidget {
  final String? catId; // doluysa kanallar doğrudan bu kategoriye eklenir
  const TvBrowserPage({super.key, this.catId});

  @override
  State<TvBrowserPage> createState() => _TvBrowserPageState();
}

class _TvBrowserPageState extends State<TvBrowserPage> {
  final _q = TextEditingController();
  String _cc = 'TR';
  String _ccName = '';
  List<TvFound> _all = [];
  bool _loading = false;
  String? _err;

  @override
  void initState() {
    super.initState();
    _ccName = tx('Türkiye');
    _load();
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final r = await tvDirectory(_cc);
      if (!mounted) return;
      setState(() {
        _all = r;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _loading = false;
        _all = [];
        _err = tx('TV rehberine bağlanılamadı ya da bu ülke için liste yok. İnternetini kontrol et.');
      });
    }
  }

  Future<void> _pickCountry() async {
    final c = await showModalBottomSheet<RbCountry>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _TvCountrySheet(),
    );
    if (c == null) return;
    setState(() {
      _cc = c.code;
      _ccName = c.code == 'TR' ? tx('Türkiye') : c.name;
    });
    _load();
  }

  Future<void> _add(TvFound f) async {
    // kategori seçtir; önerilen, dizindeki gruba göre
    final cid = widget.catId ??
        await pickTvCat(context, tvSuggestCat(f.group, f.name));
    if (cid == null || !mounted) return;
    store.addTvChan(f.name, f.url, catId: cid);
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tx('"{0}" eklendi.', [f.name]))));
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final q = _q.text.trim().toLowerCase();
        final list = [
          for (final f in _all)
            if (q.isEmpty ||
                f.name.toLowerCase().contains(q) ||
                f.group.toLowerCase().contains(q))
              f
        ];
        final have = {for (final c in store.tvChans) c.url};
        return AmbScaffold(
          kind: 'media',
          appBar: AppBar(
            backgroundColor: ambBg(p),
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(tx('TV rehberi')),
            actions: [
              TextButton.icon(
                onPressed: _pickCountry,
                icon: const Icon(Icons.public_rounded, size: 18),
                label: Text(_ccName),
              ),
            ],
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 16, 6),
                child: TextField(
                  controller: _q,
                  onChanged: (_) => setState(() {}),
                  decoration: InputDecoration(
                      hintText: tx('Kanal ya da tür ara'),
                      prefixIcon: const Icon(Icons.search_rounded),
                      isDense: true),
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                child: Text(
                    tx('Herkese açık topluluk listesi (iptv-org). Bazı yayınlar çalışmayabilir; eklemeden önce oynatıp deneyebilirsin.'),
                    style: TextStyle(color: p.soft, fontSize: 12, height: 1.3)),
              ),
              Expanded(
                child: _loading
                    ? const Center(child: CircularProgressIndicator())
                    : _err != null
                        ? Center(
                            child: Padding(
                              padding: const EdgeInsets.all(24),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(_err!,
                                      textAlign: TextAlign.center,
                                      style: TextStyle(color: p.soft)),
                                  const SizedBox(height: 12),
                                  OutlinedButton(
                                      onPressed: _load, child: Text(tx('Yeniden dene'))),
                                ],
                              ),
                            ),
                          )
                        : ListView.builder(
                            padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                            itemCount: list.length,
                            itemBuilder: (context, i) {
                              final f = list[i];
                              final added = have.contains(f.url);
                              return Card(
                                margin: const EdgeInsets.only(bottom: 6),
                                color: p.card,
                                child: ListTile(
                                  leading: IconButton(
                                    tooltip: tx('Dene'),
                                    icon: Icon(Icons.play_circle_outline_rounded,
                                        color: p.accent),
                                    onPressed: () => openTvChannel(
                                        context, TvChan('', f.name, f.url)),
                                  ),
                                  title: Text(f.name,
                                      maxLines: 1, overflow: TextOverflow.ellipsis),
                                  subtitle: f.group.isEmpty ? null : Text(f.group),
                                  trailing: added
                                      ? TextButton(
                                          onPressed: () =>
                                              store.removeTvChanByUrl(f.url),
                                          child: Text(tx('Kaldır')),
                                        )
                                      : FilledButton.tonal(
                                          onPressed: () => _add(f),
                                          child: Text(tx('Ekle')),
                                        ),
                                ),
                              );
                            },
                          ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _TvCountrySheet extends StatefulWidget {
  const _TvCountrySheet();

  @override
  State<_TvCountrySheet> createState() => _TvCountrySheetState();
}

class _TvCountrySheetState extends State<_TvCountrySheet> {
  late Future<List<RbCountry>> _f = rbCountries();
  final _q = TextEditingController();

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return SafeArea(
      child: SizedBox(
        height: MediaQuery.of(context).size.height * 0.8,
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: TextField(
                controller: _q,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                    hintText: tx('Ülke ara'),
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true),
              ),
            ),
            Expanded(
              child: FutureBuilder<List<RbCountry>>(
                future: _f,
                builder: (context, snap) {
                  if (snap.connectionState != ConnectionState.done) {
                    return const Center(child: CircularProgressIndicator());
                  }
                  if (snap.hasError || snap.data == null) {
                    return Center(
                        child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Text(tx('Ülke listesi alınamadı. İnternetini kontrol et.'),
                          textAlign: TextAlign.center, style: TextStyle(color: p.soft)),
                    ));
                  }
                  final q = _q.text.trim().toLowerCase();
                  final all = snap.data!
                      .where((c) => q.isEmpty || c.name.toLowerCase().contains(q))
                      .toList();
                  final tr = all.where((c) => c.code == 'TR').toList();
                  final rest = all.where((c) => c.code != 'TR').toList();
                  final list = [...tr, ...rest];
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final c = list[i];
                      return ListTile(
                        title: Text(c.code == 'TR' ? tx('Türkiye') : c.name),
                        onTap: () => Navigator.pop(context, c),
                      );
                    },
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}
