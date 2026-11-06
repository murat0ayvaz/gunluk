import 'package:flutter/material.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:url_launcher/url_launcher.dart';
import 'data.dart';
import 'media.dart';
import 'net.dart';
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
class NewsReader extends ChangeNotifier {
  FlutterTts? _tts;
  bool reading = false;
  String label = '';
  int _gen = 0;

  Future<FlutterTts> _engine() async {
    final t = _tts ?? FlutterTts();
    if (_tts == null) {
      _tts = t;
      try {
        await t.setLanguage('tr-TR');
        await t.setSpeechRate(0.5);
        await t.awaitSpeakCompletion(true);
      } catch (_) {}
    }
    return t;
  }

  Future<void> stop() async {
    _gen++;
    reading = false;
    notifyListeners();
    try {
      await _tts?.stop();
    } catch (_) {}
  }

  /// Metinleri sırayla okur (örn. her haber için "başlık. özet")
  Future<void> read(String name, List<String> texts) async {
    if (texts.isEmpty) return;
    await stop();
    if (media.playing) await media.stop();
    final g = ++_gen;
    reading = true;
    label = name;
    notifyListeners();
    try {
      final t = await _engine();
      for (final s in texts) {
        if (g != _gen) return;
        await t.speak(s);
      }
    } catch (_) {}
    if (g == _gen) {
      reading = false;
      notifyListeners();
    }
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
    store.saveNewsSrc(r.catId, s?.id, r.name, r.url);
  }

  /// Kaynağı sormadan siler; altta "Geri al" çıkar
  void _removeSrc(BuildContext context, NewsCat c, NewsSrc s) {
    final index = c.srcs.indexWhere((x) => x.id == s.id);
    store.removeNewsSrc(s.id);
    showUndo(context, tx('"{0}" silindi.', [s.name]),
        () => store.restoreNewsSrc(c.id, s, index));
  }

  /// Bir kaynağın ilk [n] haberini okunacak metne çevirir
  Future<List<String>> _collect(
      BuildContext context, List<NewsSrc> srcs, int n) async {
    final texts = <String>[];
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
        duration: const Duration(seconds: 2),
        content: Text(tx('Haberler alınıyor...'))));
    for (final s in srcs) {
      try {
        final items = await _news(s.url);
        if (items.isEmpty) continue;
        texts.add(s.name);
        for (final it in items.take(n)) {
          texts.add(_speakText(it));
        }
      } catch (_) {}
    }
    if (texts.isEmpty) {
      messenger.showSnackBar(
          SnackBar(content: Text(tx('Haberler alınamadı. İnternetini kontrol et.'))));
    }
    return texts;
  }

  Future<void> _readSrc(BuildContext context, NewsSrc s) async {
    final t = await _collect(context, [s], 8);
    await newsReader.read(s.name, t);
  }

  Future<void> _readCat(BuildContext context, NewsCat c) async {
    final t = await _collect(context, c.srcs, 4);
    await newsReader.read(c.name, t);
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
                padding: const EdgeInsets.fromLTRB(16, 4, 4, 4),
                child: Row(
                  children: [
                    const Icon(Icons.record_voice_over_rounded, size: 20),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(tx('Okunuyor: {0}', [newsReader.label]),
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                    ),
                    TextButton.icon(
                      onPressed: newsReader.stop,
                      icon: const Icon(Icons.stop_rounded),
                      label: Text(tx('Durdur')),
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
                newsReader.read(widget.src.name, [_speakText(n)]);
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
  _SrcInput(this.catId, this.name, this.url);
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
