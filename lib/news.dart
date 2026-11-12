import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data.dart';
import 'media.dart';
import 'net.dart';
import 'newspresets.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// HABER SEKMESİ
//  - Kategoriler (aşağı açılır) > haber kaynakları (RSS, ≡ ile sıralanır)
//  - Kaynağa dokun: başlıklar ve özetler aşağı açılır
//  - "Özeti oku": telefonun Türkçe sesiyle başlıkları ve özetleri okur
// ---------------------------------------------------------------

final Map<String, Future<List<NewsItem>>> _newsCache = {};

Future<List<NewsItem>> _news(String url, {bool fresh = false}) {
  if (fresh) _newsCache.remove(url);
  return _newsCache.putIfAbsent(url, () => fetchNews(url));
}

// ---------- Sesli okuma ----------
class NewsBatch {
  final String name;
  final List<String> items;
  NewsBatch(this.name, this.items);
}

class NewsReader extends ChangeNotifier {
  FlutterTts? _tts;
  bool reading = false;
  bool paused = false;
  String label = '';
  final List<String> _texts = [];
  final List<int> _srcOf = [];
  final List<bool> _head = [];
  final List<String> _names = [];
  int _idx = 0;
  int _gen = 0;

  Future<FlutterTts> _engine() async {
    final t = _tts ?? FlutterTts();
    if (_tts == null) {
      _tts = t;
      try {
        await t.setLanguage('tr-TR');
        await t.awaitSpeakCompletion(true);
      } catch (_) {}
    }
    try {
      await t.setSpeechRate(store.ttsRate);
    } catch (_) {}
    final v = store.ttsVoice;
    if (v.isNotEmpty) {
      final p = v.split('|');
      if (p.length == 2) {
        try {
          await t.setVoice({'name': p[0], 'locale': p[1]});
        } catch (_) {}
      }
    }
    return t;
  }

  /// Telefondaki Türkçe sesler: (ad, dil)
  Future<List<(String, String)>> turkishVoices() async {
    final out = <(String, String)>[];
    try {
      final t = await _engine();
      final v = await t.getVoices;
      if (v is List) {
        for (final e in v) {
          if (e is! Map) continue;
          final name = (e['name'] ?? '').toString();
          final loc = (e['locale'] ?? '').toString();
          if (name.isEmpty) continue;
          if (loc.toLowerCase().replaceAll('_', '-').startsWith('tr')) {
            out.add((name, loc));
          }
        }
      }
    } catch (_) {}
    out.sort((a, b) => a.$1.compareTo(b.$1));
    return out;
  }

  /// Bir sesi kısa bir cümleyle dener
  Future<void> testVoice(String name, String locale) async {
    try {
      await _tts?.stop();
      final t = await _engine();
      if (name.isNotEmpty) {
        await t.setVoice({'name': name, 'locale': locale});
      }
      await t.speak('Merhaba, haberleri bu sesle okuyabilirim.');
    } catch (_) {}
  }

  Future<void> stop({bool keepMedia = false}) async {
    _gen++;
    final was = reading;
    reading = false;
    paused = false;
    notifyListeners();
    try {
      await _tts?.stop();
    } catch (_) {}
    if (was && !keepMedia && media.isNews) await media.stop();
  }

  /// Kaynakları sırayla okur: her kaynak için "Şimdi {ad}" ve haberler
  Future<void> readBatches(String name, List<NewsBatch> bs) async {
    _texts.clear();
    _srcOf.clear();
    _head.clear();
    _names.clear();
    for (final b in bs) {
      if (b.items.isEmpty) continue;
      final si = _names.length;
      _names.add(b.name);
      _texts.add(tx('Şimdi {0}', [b.name]));
      _srcOf.add(si);
      _head.add(true);
      for (final it in b.items) {
        _texts.add(it);
        _srcOf.add(si);
        _head.add(false);
      }
    }
    if (_texts.isEmpty) return;
    await stop(keepMedia: true);
    if (media.playing && !media.isNews) await media.stop();
    reading = true;
    paused = false;
    label = name;
    _idx = 0;
    notifyListeners();
    await media.startNewsSession(tx('Haber okuma'));
    _go();
  }

  void _go() {
    final g = ++_gen;
    _run(g);
  }

  Future<void> _run(int g) async {
    try {
      final t = await _engine();
      while (g == _gen && _idx < _texts.length) {
        label = _names[_srcOf[_idx]];
        notifyListeners();
        media.newsIgnoreUntil =
            DateTime.now().add(const Duration(milliseconds: 1500));
        await t.speak(_texts[_idx]);
        if (g != _gen) return;
        _idx++;
      }
    } catch (_) {}
    if (g == _gen) await _finish();
  }

  Future<void> _finish() async {
    _gen++;
    reading = false;
    paused = false;
    notifyListeners();
    if (media.isNews) await media.stop();
  }

  Future<void> pause({bool fromMedia = false}) async {
    if (!reading || paused) return;
    paused = true;
    _gen++;
    notifyListeners();
    try {
      await _tts?.stop();
    } catch (_) {}
    if (!fromMedia) media.player.pause();
  }

  void resume({bool fromMedia = false}) {
    if (!reading || !paused) return;
    paused = false;
    notifyListeners();
    if (!fromMedia) media.player.play();
    _go();
  }

  void togglePause() {
    if (paused) {
      resume();
    } else {
      pause();
    }
  }

  void _jump(int i) {
    if (!reading || _texts.isEmpty) return;
    _idx = i.clamp(0, _texts.length - 1).toInt();
    label = _names[_srcOf[_idx]];
    _gen++;
    notifyListeners();
    try {
      _tts?.stop();
    } catch (_) {}
    if (!paused) _go();
  }

  void nextItem() {
    if (!reading) return;
    if (_idx + 1 >= _texts.length) {
      _finish();
      return;
    }
    _jump(_idx + 1);
  }

  void prevItem() => _jump(_idx - 1);

  void nextSource() {
    if (!reading) return;
    for (var j = _idx + 1; j < _texts.length; j++) {
      if (_head[j]) {
        _jump(j);
        return;
      }
    }
    _finish();
  }

  void prevSource() {
    if (!reading) return;
    var k = _idx;
    while (k > 0 && !_head[k]) {
      k--;
    }
    if (_idx - k > 1 || k == 0) {
      _jump(k);
      return;
    }
    var j = k - 1;
    while (j > 0 && !_head[j]) {
      j--;
    }
    _jump(j);
  }
}

final newsReader = NewsReader();

String _speakText(NewsItem n) =>
    n.summary.isEmpty || n.summary == n.title ? n.title : '${n.title}. ${n.summary}';

class NewsTab extends StatelessWidget {
  const NewsTab({super.key});

  Future<void> _addCat(BuildContext context) async {
    final n = await askText(context, tx('Kategori adı'));
    if (n == null || n.trim().isEmpty) return;
    store.addNewsCat(n.trim());
  }

  Future<void> _renameCat(BuildContext context, NewsCat c) async {
    final n = await askText(context, tx('Kategori adı'), initial: c.name);
    if (n == null || n.trim().isEmpty) return;
    store.renameNewsCat(c.id, n.trim());
  }

  Future<void> _removeCat(BuildContext context, NewsCat c) async {
    final messenger = ScaffoldMessenger.of(context);
    if (store.newsCats.length < 2) {
      messenger.showSnackBar(
          SnackBar(content: Text(tx('En az bir kategori kalmalı.'))));
      return;
    }
    final ok = await confirmDialog(
      context,
      tx('Kategori silinsin mi?'),
      tx('"{0}" silinir; içindeki kaynaklar ilk kategoriye geçer.', [c.name]),
      okLabel: tx('Sil'),
    );
    if (!ok) return;
    store.removeNewsCat(c.id);
  }

  Future<void> _editSrc(BuildContext context, String catId, NewsSrc? s) async {
    final r = await showDialog<_SrcInput>(
        context: context,
        builder: (_) => _SrcDialog(src: s, catId: catId));
    if (r == null) return;
    if (r.presets) {
      if (context.mounted) await showNewsPresets(context);
      return;
    }
    store.saveNewsSrc(r.catId, s?.id, r.name, r.url);
  }

  /// Kaynağı sormadan siler; altta "Geri al" çıkar
  void _removeSrc(BuildContext context, NewsCat c, NewsSrc s) {
    final index = c.srcs.indexWhere((x) => x.id == s.id);
    store.removeNewsSrc(s.id);
    showUndo(context, tx('"{0}" silindi.', [s.name]),
        () => store.restoreNewsSrc(c.id, s, index));
  }

  /// Kaynakların ilk [n] haberini okunacak metne çevirir
  Future<List<NewsBatch>> _collect(
      BuildContext context, List<NewsSrc> srcs, int n) async {
    final out = <NewsBatch>[];
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(tx('Haberler alınıyor...'))));
    for (final s in srcs) {
      try {
        final items = await _news(s.url);
        if (items.isEmpty) continue;
        out.add(NewsBatch(s.name, [
          for (final it in items.take(n <= 0 ? items.length : n)) _speakText(it)
        ]));
      } catch (_) {}
    }
    if (out.isEmpty) {
      messenger.showSnackBar(
          SnackBar(content: Text(tx('Haberler alınamadı. İnternetini kontrol et.'))));
    }
    return out;
  }

  Future<void> _readSrc(BuildContext context, NewsSrc s) async {
    final t = await _collect(context, [s], 8);
    await newsReader.readBatches(s.name, t);
  }

  Future<void> _readCat(BuildContext context, NewsCat c) async {
    final t = await _collect(context, c.srcs, 4);
    await newsReader.readBatches(c.name, t);
  }

  Future<void> _readAll(BuildContext context) async {
    final srcs = [for (final c in store.newsCats) ...c.srcs];
    final t = await _collect(context, srcs, store.newsN);
    await newsReader.readBatches(tx('Tüm kaynaklar'), t);
  }

  Widget _srcs(BuildContext context, NewsCat c) {
    final p = palOf(context);
    if (c.srcs.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(tx('Bu kategoride kaynak yok.'),
              style: TextStyle(color: p.soft, fontSize: 13)),
        ),
      );
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: c.srcs.length,
      onReorder: (a, b) {
        var to = b;
        if (to > a) to -= 1;
        store.moveNewsSrc(c.id, a, to);
      },
      itemBuilder: (context, i) {
        final s = c.srcs[i];
        return Column(
          key: ValueKey(s.id),
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            SwipeRow(
              tag: 'ns_${s.id}',
              onEdit: () => _editSrc(context, c.id, s),
              onDelete: () => _removeSrc(context, c, s),
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
              title: Text(s.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              onTap: () => store.toggleNewsSrc(s.id),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                      s.open
                          ? Icons.expand_less_rounded
                          : Icons.expand_more_rounded,
                      color: p.soft),
                  PopupMenuButton<String>(
                    onSelected: (v) {
                      if (v == 'read') _readSrc(context, s);
                      if (v == 'edit') _editSrc(context, c.id, s);
                      if (v == 'delete') _removeSrc(context, c, s);
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(
                          value: 'read', child: Text(tx('Özeti oku'))),
                      PopupMenuItem(
                          value: 'edit', child: Text(tx('Düzenle'))),
                      PopupMenuItem(value: 'delete', child: Text(tx('Sil'))),
                    ],
                  ),
                ],
              ),
                ),
              ),
            ),
            if (s.open) _Headlines(src: s),
          ],
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([store, newsReader]),
      builder: (context, _) {
        final cats = store.newsCats;
        return Column(
          children: [
            if (newsReader.reading)
              Container(
                color: p.card,
                padding: const EdgeInsets.fromLTRB(16, 2, 4, 2),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(top: 6),
                      child: Row(children: [
                        const Icon(Icons.record_voice_over_rounded, size: 18),
                        const SizedBox(width: 8),
                        Expanded(
                          child: Text(tx('Okunuyor: {0}', [newsReader.label]),
                              maxLines: 1, overflow: TextOverflow.ellipsis),
                        ),
                      ]),
                    ),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                      children: [
                        IconButton(
                            tooltip: tx('Önceki kaynak'),
                            onPressed: newsReader.prevSource,
                            icon: const Icon(Icons.fast_rewind_rounded)),
                        IconButton(
                            tooltip: tx('Önceki haber'),
                            onPressed: newsReader.prevItem,
                            icon: const Icon(Icons.skip_previous_rounded)),
                        IconButton(
                            tooltip: newsReader.paused
                                ? tx('Devam')
                                : tx('Duraklat'),
                            onPressed: newsReader.togglePause,
                            icon: Icon(newsReader.paused
                                ? Icons.play_arrow_rounded
                                : Icons.pause_rounded)),
                        IconButton(
                            tooltip: tx('Sonraki haber'),
                            onPressed: newsReader.nextItem,
                            icon: const Icon(Icons.skip_next_rounded)),
                        IconButton(
                            tooltip: tx('Sonraki kaynak'),
                            onPressed: newsReader.nextSource,
                            icon: const Icon(Icons.fast_forward_rounded)),
                        IconButton(
                            tooltip: tx('Durdur'),
                            onPressed: newsReader.stop,
                            icon: const Icon(Icons.stop_rounded)),
                      ],
                    ),
                  ],
                ),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: () => _readAll(context),
                      icon: const Icon(Icons.play_circle_outline_rounded),
                      label: Text(tx('Oku')),
                    ),
                  ),
                  const SizedBox(width: 8),
                  PopupMenuButton<int>(
                    tooltip: tx('Her kaynaktan kaç haber'),
                    onSelected: (v) => store.setTts(n: v),
                    itemBuilder: (_) => [
                      for (final v in [3, 5, 10, 0])
                        CheckedPopupMenuItem<int>(
                            value: v,
                            checked: store.newsN == v,
                            child: Text(v == 0
                                ? tx('Hepsi')
                                : tx('{0} haber', ['$v']))),
                    ],
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 10),
                      decoration: BoxDecoration(
                          border: Border.all(color: p.line),
                          borderRadius: BorderRadius.circular(20)),
                      child: Text(
                          store.newsN == 0
                              ? tx('Hepsi')
                              : tx('{0} haber', ['${store.newsN}']),
                          style: const TextStyle(fontWeight: FontWeight.w600)),
                    ),
                  ),
                  IconButton(
                    tooltip: tx('Ses ve hız'),
                    onPressed: () => showDialog<void>(
                        context: context,
                        builder: (_) => const _VoiceDialog()),
                    icon: const Icon(Icons.tune_rounded),
                  ),
                ],
              ),
            ),
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
                      onPressed: () => _editSrc(context,
                          cats.isEmpty ? '' : cats.first.id, null),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(tx('Kaynak ekle')),
                    ),
                  ),
                ],
              ),
            ),
            Expanded(
              child: ReorderableListView.builder(
                padding: const EdgeInsets.only(bottom: 12),
                buildDefaultDragHandles: false,
                itemCount: cats.length,
                onReorder: (o, n) {
                  if (n > o) n -= 1;
                  store.moveNewsCat(o, n);
                },
                footer: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    tx('Haberler RSS adreslerinden okunur. Adresler değişebilir; çalışmazsa kaynağı düzenleyip yeni RSS adresini yaz. Kategori menüsünden "Günün özetini oku" ile telefon sesiyle dinle.'),
                    style: TextStyle(color: p.soft, fontSize: 12.5, height: 1.4),
                  ),
                ),
                itemBuilder: (context, i) {
                  final c = cats[i];
                  return SwipeRow(
                    key: ValueKey(c.id),
                    tag: 'nc_${c.id}',
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    radius: 14,
                    onEdit: () => _renameCat(context, c),
                    onDelete: () => _removeCat(context, c),
                    child: MediaGroup(
                      colorSeed: c.id,
                      title: c.name,
                      info: '${c.srcs.length}',
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
                      onToggle: () => store.toggleNewsCat(c.id),
                      menu: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'read') _readCat(context, c);
                          if (v == 'add') _editSrc(context, c.id, null);
                          if (v == 'rename') _renameCat(context, c);
                          if (v == 'delete') _removeCat(context, c);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                              value: 'read',
                              child: Text(tx('Günün özetini oku'))),
                          PopupMenuItem(
                              value: 'add', child: Text(tx('Kaynak ekle'))),
                          PopupMenuItem(
                              value: 'rename',
                              child: Text(tx('Adı değiştir'))),
                          PopupMenuItem(
                              value: 'delete', child: Text(tx('Sil'))),
                        ],
                      ),
                      child: _srcs(context, c),
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

// ---------- Bir kaynağın başlıkları ----------
class _Headlines extends StatefulWidget {
  final NewsSrc src;
  const _Headlines({required this.src});

  @override
  State<_Headlines> createState() => _HeadlinesState();
}

class _HeadlinesState extends State<_Headlines> {
  late Future<List<NewsItem>> _f;

  @override
  void initState() {
    super.initState();
    _f = _news(widget.src.url);
  }

  void _refresh() => setState(() => _f = _news(widget.src.url, fresh: true));

  Future<void> _open(NewsItem n) async {
    final p = palOf(context);
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(n.title, style: const TextStyle(fontSize: 17)),
        content: SingleChildScrollView(
          child: Text(
              n.summary.isEmpty ? tx('Özet yok.') : n.summary,
              style: TextStyle(color: p.ink, height: 1.4)),
        ),
        actions: [
          TextButton(
              onPressed: () {
                Navigator.pop(ctx);
                newsReader.readBatches(widget.src.name, [NewsBatch(widget.src.name, [_speakText(n)])]);
              },
              child: Text(tx('Oku'))),
          if (n.link.isNotEmpty)
            TextButton(
                onPressed: () async {
                  try {
                    await launchUrl(Uri.parse(n.link),
                        mode: LaunchMode.externalApplication);
                  } catch (_) {}
                },
                child: Text(tx('Tarayıcıda aç'))),
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tx('Kapat'))),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return FutureBuilder<List<NewsItem>>(
      future: _f,
      builder: (context, snap) {
        if (snap.connectionState != ConnectionState.done) {
          return const Padding(
              padding: EdgeInsets.all(16),
              child: Center(child: CircularProgressIndicator()));
        }
        final items = snap.data;
        if (snap.hasError || items == null || items.isEmpty) {
          return Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              children: [
                Text(
                    snap.hasError
                        ? tx('Haberler alınamadı. İnternetini veya RSS adresini kontrol et.')
                        : tx('Bu kaynakta haber bulunamadı.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.soft)),
                TextButton(onPressed: _refresh, child: Text(tx('Yenile'))),
              ],
            ),
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final n in items)
              ListTile(
                dense: true,
                contentPadding: const EdgeInsets.fromLTRB(16, 0, 8, 0),
                title: Text(n.title,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(fontWeight: FontWeight.w600)),
                subtitle: Text(
                    [if (n.date.isNotEmpty) n.date, n.summary]
                        .where((x) => x.isNotEmpty)
                        .join(' · '),
                    maxLines: 3,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(color: p.soft, fontSize: 12)),
                onTap: () => _open(n),
              ),
            Center(
              child: TextButton.icon(
                  onPressed: _refresh,
                  icon: const Icon(Icons.refresh_rounded, size: 18),
                  label: Text(tx('Yenile'))),
            ),
          ],
        );
      },
    );
  }
}

// ---------- Kaynak ekle / düzenle ----------
class _SrcInput {
  final String catId;
  final String name;
  final String url;
  final bool presets; // "Hazır kaynaklardan ekle" seçildi
  _SrcInput(this.catId, this.name, this.url, {this.presets = false});
}

class _SrcDialog extends StatefulWidget {
  final NewsSrc? src;
  final String catId;
  const _SrcDialog({this.src, required this.catId});

  @override
  State<_SrcDialog> createState() => _SrcDialogState();
}

class _SrcDialogState extends State<_SrcDialog> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  late String _cat;
  String? _err;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.src?.name ?? '');
    _url = TextEditingController(text: widget.src?.url ?? '');
    _cat = store.newsCatById(widget.catId) != null
        ? widget.catId
        : (store.newsCats.isEmpty ? '' : store.newsCats.first.id);
  }

  @override
  void dispose() {
    _name.dispose();
    _url.dispose();
    super.dispose();
  }

  void _ok() {
    final n = _name.text.trim();
    final u = _url.text.trim();
    if (n.isEmpty || !u.startsWith('http')) {
      setState(() => _err = tx('Ad ve http ile başlayan RSS adresi gerekli.'));
      return;
    }
    Navigator.pop(context, _SrcInput(_cat, n, u));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.src == null ? tx('Kaynak ekle') : tx('Kaynağı düzenle')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (widget.src == null) ...[
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  onPressed: () =>
                      Navigator.pop(context, _SrcInput(_cat, '', '', presets: true)),
                  icon: const Icon(Icons.playlist_add_check_rounded),
                  label: Text(tx('Hazır kaynaklardan ekle')),
                ),
              ),
              const SizedBox(height: 12),
            ],
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: tx('Kaynak adı')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                  labelText: tx('RSS adresi'), hintText: 'https://...'),
            ),
            const SizedBox(height: 12),
            Align(
                alignment: Alignment.centerLeft,
                child: Text(tx('Kategori'), style: const TextStyle(fontSize: 12))),
            DropdownButton<String>(
              isExpanded: true,
              value: _cat,
              items: [
                for (final c in store.newsCats)
                  DropdownMenuItem<String>(value: c.id, child: Text(c.name)),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _cat = v);
              },
            ),
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_err!,
                    style:
                        TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(tx('Vazgeç'))),
        FilledButton(onPressed: _ok, child: Text(tx('Kaydet'))),
      ],
    );
  }
}


// ---------- Ses ve hız ayarı ----------
class _VoiceDialog extends StatefulWidget {
  const _VoiceDialog();

  @override
  State<_VoiceDialog> createState() => _VoiceDialogState();
}

class _VoiceDialogState extends State<_VoiceDialog> {
  List<(String, String)>? _voices;

  @override
  void initState() {
    super.initState();
    newsReader.turkishVoices().then((v) {
      if (mounted) setState(() => _voices = v);
    });
  }

  /// Listedeki sıra numarasına (1'den) göre seçilen sesler: Erkek 1-2, Bayan 1-2
  static const _picks = <(int, String)>[
    (2, 'Erkek 1'),
    (10, 'Erkek 2'),
    (4, 'Bayan 1'),
    (6, 'Bayan 2'),
  ];

  /// (görünen ad, ses adı, dil) listesi; öneri sesleri yoksa tüm sesler "Ses N"
  List<(String, String, String)> _shown(List<(String, String)> v) {
    final out = <(String, String, String)>[];
    for (final k in _picks) {
      if (k.$1 <= v.length) out.add((k.$2, v[k.$1 - 1].$1, v[k.$1 - 1].$2));
    }
    if (out.isEmpty) {
      for (var i = 0; i < v.length; i++) {
        out.add((tx('Ses {0}', ['${i + 1}']), v[i].$1, v[i].$2));
      }
    }
    return out;
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final v = _voices;
        final cur = store.ttsVoice;
        return AlertDialog(
          title: Text(tx('Ses ve hız')),
          content: SizedBox(
            width: double.maxFinite,
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(tx('Okuma hızı: {0}x',
                      [(store.ttsRate * 2).toStringAsFixed(2)])),
                  Row(
                    children: [
                      IconButton(
                        tooltip: tx('Yavaşlat'),
                        icon: const Icon(Icons.remove_circle_outline_rounded),
                        onPressed: () => store.setTts(rate: store.ttsRate - 0.05),
                      ),
                      Expanded(
                        child: Slider(
                          value: store.ttsRate.clamp(0.2, 1.0).toDouble(),
                          min: 0.2,
                          max: 1.0,
                          divisions: 16,
                          onChanged: (x) => store.setTts(rate: x),
                        ),
                      ),
                      IconButton(
                        tooltip: tx('Hızlandır'),
                        icon: const Icon(Icons.add_circle_outline_rounded),
                        onPressed: () => store.setTts(rate: store.ttsRate + 0.05),
                      ),
                    ],
                  ),
                  Text(tx('Ses'),
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  ListTile(
                    dense: true,
                    contentPadding: EdgeInsets.zero,
                    leading: Icon(
                        cur.isEmpty
                            ? Icons.radio_button_checked
                            : Icons.radio_button_off,
                        color: p.accent),
                    title: Text(tx('Varsayılan')),
                    onTap: () => store.setTts(voice: ''),
                    trailing: IconButton(
                        icon: const Icon(Icons.volume_up_rounded),
                        onPressed: () => newsReader.testVoice('', '')),
                  ),
                  if (v == null)
                    const Padding(
                      padding: EdgeInsets.all(12),
                      child: Center(child: CircularProgressIndicator()),
                    )
                  else if (v.isEmpty)
                    Text(
                        tx('Telefonda ek Türkçe ses bulunamadı. Ayarlar > Metin okuma bölümünden yeni ses indirebilirsin.'),
                        style: TextStyle(color: p.soft, fontSize: 13))
                  else
                    for (final sv in _shown(v))
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: Icon(
                            cur == '${sv.$2}|${sv.$3}'
                                ? Icons.radio_button_checked
                                : Icons.radio_button_off,
                            color: p.accent),
                        title: Text(sv.$1),
                        onTap: () => store.setTts(voice: '${sv.$2}|${sv.$3}'),
                        trailing: IconButton(
                            icon: const Icon(Icons.volume_up_rounded),
                            onPressed: () => newsReader.testVoice(sv.$2, sv.$3)),
                      ),
                ],
              ),
            ),
          ),
          actions: [
            TextButton(
                onPressed: () => Navigator.pop(context),
                child: Text(tx('Kapat'))),
          ],
        );
      },
    );
  }
}
