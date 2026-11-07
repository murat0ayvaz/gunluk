import 'package:flutter/material.dart';
import 'data.dart';
import 'media.dart';
import 'net.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// PODCAST SEKMESİ
//  - "Podcast ara": Apple'ın podcast rehberinde ada göre ara, takip et
//  - Takip ettiklerin aşağı doğru açılır, bölümler internetten okunur
//  - Bölüme dokun: çalar; kaldığın yer hatırlanır, bitenler işaretlenir
// ---------------------------------------------------------------

/// Bölüm listeleri bir kez indirilip bellekte tutulur (her açışta yeniden inmesin)
final Map<String, Future<List<Episode>>> _epCache = {};

Widget _art(String url, double size) {
  if (url.isEmpty) {
    return SizedBox(
        width: size, height: size, child: const Icon(Icons.podcasts_rounded));
  }
  return ClipRRect(
    borderRadius: BorderRadius.circular(8),
    child: Image.network(
      url,
      width: size,
      height: size,
      fit: BoxFit.cover,
      errorBuilder: (context, error, stack) => SizedBox(
          width: size, height: size, child: const Icon(Icons.podcasts_rounded)),
    ),
  );
}

/// Podcast sekmesi: false = hepsi (kategoriler), true = sadece favoriler
final ValueNotifier<bool> podFavOnly = ValueNotifier<bool>(false);

class PodcastTab extends StatelessWidget {
  const PodcastTab({super.key});

  String _firstCat() => store.podCats.isEmpty ? '' : store.podCats.first.id;

  Future<void> _addCat(BuildContext context) async {
    final n = await askText(context, tx('Kategori adı'));
    if (n == null || n.trim().isEmpty) return;
    store.addPodCat(n.trim());
  }

  Future<void> _renameCat(BuildContext context, PodCat c) async {
    final n = await askText(context, tx('Kategori adı'), initial: c.name);
    if (n == null || n.trim().isEmpty) return;
    store.renamePodCat(c.id, n.trim());
  }

  Future<void> _removeCat(BuildContext context, PodCat c) async {
    final messenger = ScaffoldMessenger.of(context);
    if (store.podCats.length < 2) {
      messenger.showSnackBar(
          SnackBar(content: Text(tx('En az bir kategori kalmalı.'))));
      return;
    }
    final ok = await confirmDialog(
      context,
      tx('Kategori silinsin mi?'),
      tx('"{0}" silinir; içindeki podcast\'ler ilk kategoriye geçer.', [c.name]),
      okLabel: tx('Sil'),
    );
    if (!ok) return;
    store.removePodCat(c.id);
  }

  Future<void> _changeCat(BuildContext context, Podcast pd, String cur) async {
    final id = await pickPodCat(context, cur);
    if (id == null || id == cur) return;
    store.setPodcastCat(pd.id, id);
  }

  Future<void> _renamePod(BuildContext context, Podcast pd) async {
    final n = await askText(context, tx('Podcast adı'), initial: pd.title);
    if (n == null || n.trim().isEmpty) return;
    store.renamePodcast(pd.id, n.trim());
  }

  /// Takipten sormadan çıkarır; altta "Geri al" çıkar
  Future<void> _unfollow(BuildContext context, PodCat c, Podcast pd) async {
    final index = c.pods.indexWhere((x) => x.id == pd.id);
    if (media.isPod && (media.podKey ?? '').startsWith('${pd.id}|')) {
      await media.stop();
    }
    store.unfollowKeep(pd.id);
    if (!context.mounted) return;
    showUndo(context, tx('"{0}" takipten çıkarıldı.', [pd.title]),
        () => store.restorePodcast(c.id, pd, index));
  }

  Widget _pods(BuildContext context, PodCat c) {
    final p = palOf(context);
    if (c.pods.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(tx('Bu kategoride podcast yok.'),
              style: TextStyle(color: p.soft, fontSize: 13)),
        ),
      );
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: c.pods.length,
      onReorder: (a, b) {
        var to = b;
        if (to > a) to -= 1;
        store.movePodcast(c.id, a, to);
      },
      itemBuilder: (context, i) {
        final pd = c.pods[i];
        return Column(
          key: ValueKey(pd.id),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwipeRow(
              tag: 'pd_${pd.id}',
              onEdit: () => _renamePod(context, pd),
              onDelete: () => _unfollow(context, c, pd),
              child: ColoredBox(
                color: p.card,
                child: ListTile(
              dense: true,
              contentPadding: const EdgeInsets.only(left: 8, right: 0),
              leading: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ReorderableDragStartListener(
                    index: i,
                    child: Padding(
                      padding: const EdgeInsets.all(6),
                      child: Icon(Icons.drag_handle_rounded, color: p.soft),
                    ),
                  ),
                  _art(pd.art, 36),
                ],
              ),
              title: Text(pd.title,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => store.togglePodcast(pd.id),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    tooltip: tx('Favori'),
                    visualDensity: VisualDensity.compact,
                    onPressed: () => store.toggleFavPodcast(pd.id),
                    icon: Icon(
                        pd.fav ? Icons.star_rounded : Icons.star_outline_rounded,
                        color: pd.fav ? const Color(0xFFE9A23B) : p.soft),
                  ),
                  Icon(
                      pd.open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: p.soft),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'cat') _changeCat(context, pd, c.id);
                      if (v == 'rename') _renamePod(context, pd);
                      if (v == 'unfollow') _unfollow(context, c, pd);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'rename', child: Text(tx('Adı değiştir'))),
                      PopupMenuItem(
                          value: 'cat', child: Text(tx('Kategori değiştir'))),
                      PopupMenuItem(
                          value: 'unfollow', child: Text(tx('Takipten çık'))),
                    ],
                  ),
                ],
              ),
                ),
              ),
            ),
            if (pd.open) EpisodesView(podcast: pd),
          ],
        );
      },
    );
  }

  /// Favoriler görünümü: tüm kategorilerdeki yıldızlı podcast'ler tek listede
  Widget _favList(BuildContext context) {
    final p = palOf(context);
    final items = <MapEntry<PodCat, Podcast>>[
      for (final c in store.podCats)
        for (final pd in c.pods)
          if (pd.fav) MapEntry(c, pd),
    ];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(tx('Henüz favori podcast yok. Podcast\'in yanındaki yıldıza dokun.'),
              textAlign: TextAlign.center,
              style: TextStyle(color: p.soft, height: 1.4)),
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      children: [
        for (final e in items)
          Container(
            margin: const EdgeInsets.only(bottom: 8),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: tagTone(e.key.id).withOpacity(0.5)),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                ListTile(
                  dense: true,
                  leading: _art(e.value.art, 36),
                  title: Text(e.value.title,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                  subtitle: Text(e.key.name,
                      style: TextStyle(color: p.soft, fontSize: 12)),
                  onTap: () => store.togglePodcast(e.value.id),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        tooltip: tx('Favori'),
                        onPressed: () => store.toggleFavPodcast(e.value.id),
                        icon: const Icon(Icons.star_rounded,
                            color: Color(0xFFE9A23B)),
                      ),
                      Icon(
                          e.value.open
                              ? Icons.expand_less_rounded
                              : Icons.expand_more_rounded,
                          color: p.soft),
                    ],
                  ),
                ),
                if (e.value.open) EpisodesView(podcast: e.value),
              ],
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([store, media, podFavOnly]),
      builder: (context, _) {
        final cats = store.podCats;
        final favOnly = podFavOnly.value;
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
                      onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute<void>(
                              builder: (_) =>
                                  PodcastSearchPage(catId: _firstCat()))),
                      icon: const Icon(Icons.search_rounded),
                      label: Text(tx('Podcast ara')),
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
                    onSelected: (_) => podFavOnly.value = false,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.star_rounded,
                        size: 16, color: Color(0xFFE9A23B)),
                    label: Text(tx('Favoriler')),
                    selected: favOnly,
                    onSelected: (_) => podFavOnly.value = true,
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
                  store.movePodCat(o, n);
                },
                footer: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    tx('"Podcast ara" ile bul ve takip et; haber özeti, sohbet, eğitim gibi sesli yayınlar kategorilerde listelenir.'),
                    style: TextStyle(color: p.soft, fontSize: 12.5, height: 1.4),
                  ),
                ),
                itemBuilder: (context, i) {
                  final c = cats[i];
                  return SwipeRow(
                    key: ValueKey(c.id),
                    tag: 'pc_${c.id}',
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    radius: 14,
                    onEdit: () => _renameCat(context, c),
                    onDelete: () => _removeCat(context, c),
                    child: MediaGroup(
                      colorSeed: c.id,
                      title: c.name,
                      info: '${c.pods.length}',
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
                      onToggle: () => store.togglePodCat(c.id),
                      menu: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'add') {
                            Navigator.of(context).push(MaterialPageRoute<void>(
                                builder: (_) => PodcastSearchPage(catId: c.id)));
                          }
                          if (v == 'rename') _renameCat(context, c);
                          if (v == 'delete') _removeCat(context, c);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                              value: 'add', child: Text(tx('Podcast ara'))),
                          PopupMenuItem(
                              value: 'rename',
                              child: Text(tx('Adı değiştir'))),
                          PopupMenuItem(
                              value: 'delete', child: Text(tx('Sil'))),
                        ],
                      ),
                      child: _pods(context, c),
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

/// Kategori seçme penceresi; seçilen kategorinin kimliğini döndürür
Future<String?> pickPodCat(BuildContext context, String current) {
  return showDialog<String>(
    context: context,
    builder: (ctx) => SimpleDialog(
      title: Text(tx('Kategori')),
      children: [
        for (final c in store.podCats)
          SimpleDialogOption(
            onPressed: () => Navigator.pop(ctx, c.id),
            child: Row(
              children: [
                Expanded(child: Text(c.name)),
                if (c.id == current) const Icon(Icons.check_rounded, size: 18),
              ],
            ),
          ),
      ],
    ),
  );
}

// ---------- Bir podcast'in bölümleri ----------
class EpisodesView extends StatefulWidget {
  final Podcast podcast;
  const EpisodesView({super.key, required this.podcast});

  @override
  State<EpisodesView> createState() => _EpisodesViewState();
}

class _EpisodesViewState extends State<EpisodesView> {
  late Future<List<Episode>> _f;
  int _shown = 30;

  @override
  void initState() {
    super.initState();
    _f = _load();
  }

  Future<List<Episode>> _load() {
    final pd = widget.podcast;
    return _epCache.putIfAbsent(pd.id, () => fetchEpisodes(pd.id, pd.feed));
  }

  void _refresh() {
    _epCache.remove(widget.podcast.id);
    setState(() => _f = _load());
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final pd = widget.podcast;
    return FutureBuilder<List<Episode>>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
              padding: EdgeInsets.all(20),
              child: Center(child: CircularProgressIndicator()));
        }
        if (snap.hasError || snap.data == null) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                Text(tx('Bölümler alınamadı. İnternetini kontrol et.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.soft)),
                TextButton(onPressed: _refresh, child: Text(tx('Yenile'))),
              ],
            ),
          );
        }
        final eps = snap.data!;
        if (eps.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(16),
            child: Text(tx('Bu podcast için bölüm bulunamadı.'),
                style: TextStyle(color: p.soft)),
          );
        }
        final count = eps.length < _shown ? eps.length : _shown;
        return ListenableBuilder(
          listenable: Listenable.merge([store, media]),
          builder: (context, _) {
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (var i = 0; i < count; i++) _tile(context, pd, eps[i]),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    if (eps.length > count)
                      TextButton(
                          onPressed: () => setState(() => _shown += 30),
                          child: Text(tx('Daha fazla'))),
                    TextButton.icon(
                        onPressed: _refresh,
                        icon: const Icon(Icons.refresh_rounded, size: 18),
                        label: Text(tx('Yenile'))),
                  ],
                ),
              ],
            );
          },
        );
      },
    );
  }

  Widget _tile(BuildContext context, Podcast pd, Episode e) {
    final p = palOf(context);
    final done = store.epDone.contains(e.key);
    final pos = store.epPos[e.key] ?? 0;
    final cur = media.nowId == e.key && media.isPod;
    final sub = [
      e.date,
      e.dur,
      if (pos > 0 && !done)
        tx('Kaldığın yer: {0}', [mmss(Duration(milliseconds: pos))]),
    ].where((x) => x.isNotEmpty).join(' · ');
    return ListTile(
      dense: true,
      contentPadding: const EdgeInsets.only(left: 12, right: 0),
      leading: Icon(
          cur && media.playing
              ? Icons.graphic_eq_rounded
              : (done ? Icons.check_rounded : Icons.play_arrow_rounded),
          color: cur ? p.ink : p.soft),
      title: Text(e.title,
          maxLines: 2,
          overflow: TextOverflow.ellipsis,
          style: TextStyle(
              fontWeight: cur ? FontWeight.w700 : FontWeight.w400,
              color: done && !cur ? p.soft : p.ink)),
      subtitle: sub.isEmpty
          ? null
          : Text(sub, style: TextStyle(color: p.soft, fontSize: 12)),
      onTap: () => media.playEpisode(pd, e),
      trailing: IconButton(
        tooltip: done ? tx('Dinlenmedi olarak işaretle') : tx('Dinlendi olarak işaretle'),
        onPressed: () => store.setEpDone(e.key, !done),
        icon: Icon(
            done ? Icons.check_circle_rounded : Icons.check_circle_outline_rounded,
            size: 22),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Podcast arama ekranı
// ---------------------------------------------------------------
class PodcastSearchPage extends StatefulWidget {
  final String catId;
  const PodcastSearchPage({super.key, required this.catId});

  @override
  State<PodcastSearchPage> createState() => _PodcastSearchPageState();
}

class _PodcastSearchPageState extends State<PodcastSearchPage> {
  final _q = TextEditingController();
  List<PodResult> _res = [];
  bool _loading = false;
  bool _turkey = true;
  String _src = 'itunes'; // itunes | idx | spreaker | archive | rss
  bool _searched = false;
  String? _err;
  int _gen = 0;
  late String _cat;

  @override
  void initState() {
    super.initState();
    _cat = store.podCatById(widget.catId) != null
        ? widget.catId
        : (store.podCats.isEmpty ? '' : store.podCats.first.id);
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final term = _q.text.trim();
    if (term.isEmpty) return;
    final g = ++_gen;
    setState(() {
      _loading = true;
      _err = null;
      _searched = true;
    });
    try {
      List<PodResult> r;
      if (_src == 'idx') {
        if (store.pIdxKey.isEmpty || store.pIdxSecret.isEmpty) {
          await _askIdxKey();
          if (store.pIdxKey.isEmpty || store.pIdxSecret.isEmpty) {
            if (!mounted || g != _gen) return;
            setState(() {
              _res = [];
              _loading = false;
              _err = tx('Podcast Index için anahtar gerekli (podcastindex.org\'da ücretsiz kayıt).');
            });
            return;
          }
        }
        r = await podSearchIdx(term, store.pIdxKey, store.pIdxSecret);
      } else if (_src == 'spreaker') {
        r = await podSearchSpreaker(term);
      } else if (_src == 'archive') {
        r = await podSearchArchive(term);
      } else if (_src == 'rss') {
        r = [await podFeedInfo(term)];
      } else {
        r = await podSearch(term, turkey: _turkey);
      }
      if (!mounted || g != _gen) return;
      setState(() {
        _res = r;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || g != _gen) return;
      setState(() {
        _res = [];
        _loading = false;
        _err = _src == 'rss'
            ? tx('Bu adreste podcast RSS\'i bulunamadı.')
            : tx('Podcast rehberine bağlanılamadı. İnternetini kontrol et.');
      });
    }
  }

  /// Podcast Index anahtarı (ücretsiz kayıtla alınır); bir kez girilir
  Future<void> _askIdxKey() async {
    final k = await askText(context, tx('Podcast Index API anahtarı'),
        initial: store.pIdxKey);
    if (k == null || k.trim().isEmpty || !mounted) return;
    final sec = await askText(context, tx('Podcast Index gizli anahtarı'),
        initial: store.pIdxSecret);
    if (sec == null || sec.trim().isEmpty) return;
    store.setPIdx(k, sec);
  }

  void _follow(PodResult r) {
    store.addPodcast(_cat, r.title, r.author, r.feed, r.art);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
          duration: const Duration(milliseconds: 1400),
          content: Text(tx('"{0}" takip ediliyor.', [r.title]))));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(title: Text(tx('Podcast ara'))),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                      hintText: _src == 'rss'
                          ? tx('RSS adresi (https://...)')
                          : tx('Podcast adı veya konu (ör. haber özeti)'),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                    tooltip: tx('Ara'),
                    onPressed: _search,
                    icon: const Icon(Icons.search_rounded)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Align(
              alignment: Alignment.centerLeft,
              child: Wrap(
                spacing: 8,
                children: [
                  for (final x in const [
                    ['itunes', 'iTunes'],
                    ['idx', 'Podcast Index'],
                    ['spreaker', 'Spreaker'],
                    ['archive', 'Internet Archive'],
                    ['rss', 'RSS'],
                  ])
                    ChoiceChip(
                      label: Text(x[1]),
                      selected: _src == x[0],
                      onSelected: (_) {
                        setState(() {
                          _src = x[0];
                          _res = [];
                          _err = null;
                          _searched = false;
                        });
                      },
                    ),
                  if (_src == 'idx')
                    ActionChip(
                      avatar: const Icon(Icons.key_rounded, size: 16),
                      label: Text(tx('Anahtar')),
                      onPressed: _askIdxKey,
                    ),
                ],
              ),
            ),
          ),
          if (_src == 'itunes')
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                ChoiceChip(
                  label: Text(tx('Türkiye')),
                  selected: _turkey,
                  onSelected: (_) {
                    setState(() => _turkey = true);
                    _search();
                  },
                ),
                const SizedBox(width: 8),
                ChoiceChip(
                  label: Text(tx('Dünya')),
                  selected: !_turkey,
                  onSelected: (_) {
                    setState(() => _turkey = false);
                    _search();
                  },
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 0),
            child: Row(
              children: [
                Text(tx('Kategori'), style: TextStyle(color: p.soft)),
                const SizedBox(width: 12),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _cat,
                    items: [
                      for (final c in store.podCats)
                        DropdownMenuItem<String>(
                            value: c.id, child: Text(c.name)),
                    ],
                    onChanged: (v) {
                      if (v != null) setState(() => _cat = v);
                    },
                  ),
                ),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : (_res.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                              _err ??
                                  (_searched
                                      ? tx('Sonuç bulunamadı.')
                                      : tx('Aramak istediğin podcast adını veya konuyu yaz.')),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: p.soft, height: 1.4)),
                        ),
                      )
                    : ListView.builder(
                        itemCount: _res.length,
                        itemBuilder: (context, i) {
                          final r = _res[i];
                          final have = store.isFollowing(r.feed);
                          return ListTile(
                            leading: _art(r.art, 44),
                            title: Text(r.title,
                                maxLines: 2, overflow: TextOverflow.ellipsis),
                            subtitle: Text(r.author,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: TextStyle(color: p.soft, fontSize: 12)),
                            trailing: IconButton(
                              tooltip: tx('Takip et'),
                              onPressed: have ? null : () => _follow(r),
                              icon: Icon(have
                                  ? Icons.check_circle_rounded
                                  : Icons.add_circle_outline_rounded),
                            ),
                          );
                        },
                      )),
          ),
        ],
      ),
    );
  }
}
