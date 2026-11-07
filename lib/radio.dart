import 'package:flutter/material.dart';
import 'data.dart';
import 'media.dart';
import 'net.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// RADYO SEKMESİ
//  - Kategoriler (Genel, Haber...) aşağı doğru açılır
//  - Soldaki ≡ ile radyolar sürüklenip sıralanır
//  - "Radyo ekle": radyo rehberinde ada / ülkeye / türe göre ara, dinleyip ekle
//  - "Elle ekle": rehberde olmayan radyo için ad + yayın adresi
// ---------------------------------------------------------------

class StationInput {
  final String catId;
  final String name;
  final String url;
  StationInput(this.catId, this.name, this.url);
}

Future<StationInput?> showStationDialog(BuildContext context,
    {Station? station, required String catId}) {
  return showDialog<StationInput>(
    context: context,
    builder: (_) => _StationDialog(station: station, catId: catId),
  );
}

/// Radyo sekmesi: false = hepsi (kategoriler), true = sadece favoriler
final ValueNotifier<bool> radFavOnly = ValueNotifier<bool>(false);

class RadioTab extends StatelessWidget {
  const RadioTab({super.key});

  void _browse(BuildContext context, String catId) {
    Navigator.of(context).push(
        MaterialPageRoute<void>(builder: (_) => RadioBrowserPage(catId: catId)));
  }

  String _firstCat() => store.radCats.isEmpty ? '' : store.radCats.first.id;

  Future<void> _addCat(BuildContext context) async {
    final n = await askText(context, tx('Kategori adı'));
    if (n == null || n.trim().isEmpty) return;
    store.addRadCat(n.trim());
  }

  Future<void> _renameCat(BuildContext context, RadioCat c) async {
    final n = await askText(context, tx('Kategori adı'), initial: c.name);
    if (n == null || n.trim().isEmpty) return;
    store.renameRadCat(c.id, n.trim());
  }

  Future<void> _removeCat(BuildContext context, RadioCat c) async {
    final messenger = ScaffoldMessenger.of(context);
    if (store.radCats.length < 2) {
      messenger.showSnackBar(
          SnackBar(content: Text(tx('En az bir kategori kalmalı.'))));
      return;
    }
    final ok = await confirmDialog(
      context,
      tx('Kategori silinsin mi?'),
      tx('"{0}" silinir; içindeki radyolar ilk kategoriye geçer.', [c.name]),
      okLabel: tx('Sil'),
    );
    if (!ok) return;
    store.removeRadCat(c.id);
  }

  Future<void> _manual(BuildContext context, String catId) async {
    final r = await showStationDialog(context, catId: catId);
    if (r == null) return;
    store.saveStation(r.catId, null, r.name, r.url);
  }

  Future<void> _editStation(
      BuildContext context, RadioCat c, Station s) async {
    final r = await showStationDialog(context, station: s, catId: c.id);
    if (r == null) return;
    store.saveStation(r.catId, s.id, r.name, r.url);
  }

  /// Radyoyu sormadan siler; altta "Geri al" çıkar
  Future<void> _removeStation(
      BuildContext context, RadioCat c, Station s) async {
    final index = c.stations.indexWhere((x) => x.id == s.id);
    if (media.nowId == s.id && media.isRadio) await media.stop();
    store.removeStation(c.id, s.id);
    if (!context.mounted) return;
    showUndo(context, tx('"{0}" silindi.', [s.name]),
        () => store.restoreStation(c.id, s, index));
  }

  Widget _stations(BuildContext context, RadioCat c) {
    final p = palOf(context);
    if (c.stations.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 4),
        child: Align(
          alignment: Alignment.centerLeft,
          child: Text(tx('Bu kategoride radyo yok.'),
              style: TextStyle(color: p.soft, fontSize: 13)),
        ),
      );
    }
    return ReorderableListView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      itemCount: c.stations.length,
      onReorder: (a, b) {
        var to = b;
        if (to > a) to -= 1;
        store.moveStation(c.id, a, to);
      },
      itemBuilder: (context, i) {
        final s = c.stations[i];
        final cur = media.nowId == s.id && media.isRadio;
        return SwipeRow(
          key: ValueKey(s.id),
          tag: 'st_${s.id}',
          onEdit: () => _editStation(context, c, s),
          onDelete: () => _removeStation(context, c, s),
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
          title: Text(s.name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                  fontWeight: cur ? FontWeight.w700 : FontWeight.w400)),
          onTap: () => media.playStation(s),
          trailing: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (cur)
                Icon(media.playing ? Icons.graphic_eq_rounded : Icons.pause_rounded,
                    color: p.ink, size: 20),
              IconButton(
                tooltip: tx('Favori'),
                visualDensity: VisualDensity.compact,
                onPressed: () => store.toggleFavStation(s.id),
                icon: Icon(
                    s.fav ? Icons.star_rounded : Icons.star_outline_rounded,
                    color: s.fav ? const Color(0xFFE9A23B) : p.soft),
              ),
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'edit') _editStation(context, c, s);
                  if (v == 'delete') _removeStation(context, c, s);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(tx('Düzenle'))),
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

  /// Favoriler görünümü: tüm kategorilerdeki yıldızlı radyolar tek listede
  Widget _favList(BuildContext context) {
    final p = palOf(context);
    final items = <MapEntry<RadioCat, Station>>[
      for (final c in store.radCats)
        for (final s in c.stations)
          if (s.fav) MapEntry(c, s),
    ];
    if (items.isEmpty) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Text(tx('Henüz favori radyo yok. Radyonun yanındaki yıldıza dokun.'),
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
            margin: const EdgeInsets.only(bottom: 6),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: tagTone(e.key.id).withOpacity(0.5)),
            ),
            child: ListTile(
              dense: true,
              title: Text(e.value.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(
                      fontWeight: media.nowId == e.value.id && media.isRadio
                          ? FontWeight.w700
                          : FontWeight.w400)),
              subtitle: Text(e.key.name,
                  style: TextStyle(color: p.soft, fontSize: 12)),
              onTap: () => media.playStation(e.value),
              trailing: IconButton(
                tooltip: tx('Favori'),
                onPressed: () => store.toggleFavStation(e.value.id),
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
      listenable: Listenable.merge([store, media, radFavOnly]),
      builder: (context, _) {
        final cats = store.radCats;
        final favOnly = radFavOnly.value;
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
                      onPressed: () => _browse(context, _firstCat()),
                      icon: const Icon(Icons.add_rounded),
                      label: Text(tx('Radyo ekle')),
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
                    onSelected: (_) => radFavOnly.value = false,
                  ),
                  const SizedBox(width: 8),
                  ChoiceChip(
                    avatar: const Icon(Icons.star_rounded,
                        size: 16, color: Color(0xFFE9A23B)),
                    label: Text(tx('Favoriler')),
                    selected: favOnly,
                    onSelected: (_) => radFavOnly.value = true,
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
                  store.moveRadCat(o, n);
                },
                footer: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                  child: Text(
                    tx('Radyo internetten çalar. Adresler zamanla değişebilir; çalmazsa menüden adresi güncelle.'),
                    style: TextStyle(color: p.soft, fontSize: 12.5, height: 1.4),
                  ),
                ),
                itemBuilder: (context, i) {
                  final c = cats[i];
                  return SwipeRow(
                    key: ValueKey(c.id),
                    tag: 'rc_${c.id}',
                    padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                    radius: 14,
                    onEdit: () => _renameCat(context, c),
                    onDelete: () => _removeCat(context, c),
                    child: MediaGroup(
                      colorSeed: c.id,
                      title: c.name,
                      info: '${c.stations.length}',
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
                      onToggle: () => store.toggleRadCat(c.id),
                      menu: PopupMenuButton<String>(
                        onSelected: (v) {
                          if (v == 'add') _browse(context, c.id);
                          if (v == 'manual') _manual(context, c.id);
                          if (v == 'rename') _renameCat(context, c);
                          if (v == 'delete') _removeCat(context, c);
                        },
                        itemBuilder: (_) => [
                          PopupMenuItem(
                              value: 'add', child: Text(tx('Radyo ekle'))),
                          PopupMenuItem(
                              value: 'manual', child: Text(tx('Elle ekle'))),
                          PopupMenuItem(
                              value: 'rename',
                              child: Text(tx('Adı değiştir'))),
                          PopupMenuItem(
                              value: 'delete', child: Text(tx('Sil'))),
                        ],
                      ),
                      child: _stations(context, c),
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

// ---------- Elle ekleme / düzenleme penceresi ----------
class _StationDialog extends StatefulWidget {
  final Station? station;
  final String catId;
  const _StationDialog({this.station, required this.catId});

  @override
  State<_StationDialog> createState() => _StationDialogState();
}

class _StationDialogState extends State<_StationDialog> {
  late final TextEditingController _name;
  late final TextEditingController _url;
  late String _cat;
  String? _err;

  @override
  void initState() {
    super.initState();
    _name = TextEditingController(text: widget.station?.name ?? '');
    _url = TextEditingController(text: widget.station?.url ?? '');
    _cat = widget.catId;
    if (store.radCatById(_cat) == null && store.radCats.isNotEmpty) {
      _cat = store.radCats.first.id;
    }
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
    if (n.isEmpty) {
      setState(() => _err = tx('Radyo adı yaz.'));
      return;
    }
    if (!(u.startsWith('http://') || u.startsWith('https://'))) {
      setState(() => _err = tx('Adres http:// veya https:// ile başlamalı.'));
      return;
    }
    Navigator.pop(context, StationInput(_cat, n, u));
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
          widget.station == null ? tx('Elle ekle') : tx('Radyoyu düzenle')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              decoration: InputDecoration(labelText: tx('Radyo adı')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _url,
              keyboardType: TextInputType.url,
              decoration: InputDecoration(
                  labelText: tx('Yayın adresi'), hintText: 'https://...'),
            ),
            const SizedBox(height: 12),
            Text(tx('Kategori'), style: const TextStyle(fontSize: 12)),
            DropdownButton<String>(
              isExpanded: true,
              value: _cat,
              items: [
                for (final c in store.radCats)
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

// ---------------------------------------------------------------
// RADYO REHBERİ: ada / ülkeye / türe göre ara, dinle, ekle
// ---------------------------------------------------------------
const _tagList = <List<String>>[
  ['', 'Hepsi'],
  ['news', 'Haber'],
  ['talk', 'Konuşma'],
  ['pop', 'Pop'],
  ['rock', 'Rock'],
  ['classical', 'Klasik'],
  ['jazz', 'Caz'],
  ['folk', 'Halk müziği'],
  ['electronic', 'Elektronik'],
  ['hits', 'Hit'],
  ['oldies', 'Nostalji'],
  ['religion', 'Dini'],
  ['islamic', 'İslami'],
  ['sports', 'Spor'],
];

class RadioBrowserPage extends StatefulWidget {
  final String catId;
  const RadioBrowserPage({super.key, required this.catId});

  @override
  State<RadioBrowserPage> createState() => _RadioBrowserPageState();
}

class _RadioBrowserPageState extends State<RadioBrowserPage> {
  final _q = TextEditingController();
  late String _cat;
  String _country = 'TR';
  String _countryName = '';
  String _tag = '';
  List<RbStation> _res = [];
  bool _loading = false;
  bool _more = false;
  String? _err;
  int _offset = 0;
  int _gen = 0;

  @override
  void initState() {
    super.initState();
    _cat = widget.catId;
    if (store.radCatById(_cat) == null && store.radCats.isNotEmpty) {
      _cat = store.radCats.first.id;
    }
    _load(reset: true);
  }

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _load({required bool reset}) async {
    final g = ++_gen;
    if (reset) {
      _offset = 0;
      _res = [];
    }
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final r = await rbSearch(
          name: _q.text, country: _country, tag: _tag, offset: _offset);
      if (!mounted || g != _gen) return;
      setState(() {
        _res = [..._res, ...r];
        _offset += 30;
        _more = r.isNotEmpty;
        _loading = false;
      });
    } catch (e) {
      if (!mounted || g != _gen) return;
      setState(() {
        _loading = false;
        _more = false;
        _err = tx('Radyo rehberine bağlanılamadı. İnternetini kontrol et veya "Elle ekle"yi kullan.');
      });
    }
  }

  Future<void> _pickCountry() async {
    final c = await showModalBottomSheet<RbCountry>(
      context: context,
      isScrollControlled: true,
      builder: (_) => const _CountrySheet(),
    );
    if (c == null) return;
    setState(() {
      _country = c.code;
      _countryName = c.code.isEmpty
          ? tx('Tümü')
          : (c.code == 'TR' ? tx('Türkiye') : c.name);
    });
    _load(reset: true);
  }

  Future<void> _pickTag() async {
    final picked = await showModalBottomSheet<String>(
      context: context,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            for (final e in _tagList)
              ListTile(
                title: Text(tx(e[1])),
                trailing: _tag == e[0] ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(ctx, e[0]),
              ),
          ],
        ),
      ),
    );
    if (picked == null) return;
    setState(() => _tag = picked);
    _load(reset: true);
  }

  String _tagName() {
    for (final t in _tagList) {
      if (t[0] == _tag) return tx(t[1]);
    }
    return tx('Hepsi');
  }

  Future<void> _manual() async {
    final r = await showStationDialog(context, catId: _cat);
    if (r == null) return;
    store.saveStation(r.catId, null, r.name, r.url);
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(tx('Eklendi.'))));
    setState(() {});
  }

  void _add(RbStation r) {
    store.saveStation(_cat, null, r.name, r.url);
    ScaffoldMessenger.of(context)
      ..clearSnackBars()
      ..showSnackBar(SnackBar(
          duration: const Duration(milliseconds: 1400),
          content: Text(tx('"{0}" eklendi.', [r.name]))));
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    if (_countryName.isEmpty) _countryName = tx('Türkiye');
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: Text(tx('Radyo ekle')),
        actions: [
          TextButton(onPressed: _manual, child: Text(tx('Elle ekle'))),
        ],
      ),
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
                    onSubmitted: (_) => _load(reset: true),
                    decoration: InputDecoration(
                      hintText: tx('Radyo adı (ör. TRT, Kral, Power)'),
                      isDense: true,
                    ),
                  ),
                ),
                IconButton(
                    tooltip: tx('Ara'),
                    onPressed: () => _load(reset: true),
                    icon: const Icon(Icons.search_rounded)),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickCountry,
                    icon: const Icon(Icons.public_rounded, size: 18),
                    label: Text(tx('Ülke: {0}', [_countryName]),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickTag,
                    icon: const Icon(Icons.category_outlined, size: 18),
                    label: Text(tx('Tür: {0}', [_tagName()]),
                        maxLines: 1, overflow: TextOverflow.ellipsis),
                  ),
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 0),
            child: Row(
              children: [
                Text(tx('Eklenecek kategori:'),
                    style: TextStyle(color: p.soft, fontSize: 13)),
                const SizedBox(width: 8),
                Expanded(
                  child: DropdownButton<String>(
                    isExpanded: true,
                    value: _cat,
                    items: [
                      for (final c in store.radCats)
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
            child: ListenableBuilder(
              listenable: media,
              builder: (context, _) {
                if (_res.isEmpty) {
                  return Center(
                    child: _loading
                        ? const CircularProgressIndicator()
                        : Padding(
                            padding: const EdgeInsets.all(32),
                            child: Text(_err ?? tx('Sonuç bulunamadı.'),
                                textAlign: TextAlign.center,
                                style: TextStyle(color: p.soft, height: 1.4)),
                          ),
                  );
                }
                return ListView.builder(
                  itemCount: _res.length + 1,
                  itemBuilder: (context, i) {
                    if (i == _res.length) {
                      if (_loading) {
                        return const Padding(
                            padding: EdgeInsets.all(16),
                            child: Center(child: CircularProgressIndicator()));
                      }
                      if (_err != null) {
                        return Padding(
                            padding: const EdgeInsets.all(16),
                            child: Text(_err!,
                                style: TextStyle(color: p.soft)));
                      }
                      if (!_more) return const SizedBox(height: 12);
                      return Padding(
                        padding: const EdgeInsets.all(12),
                        child: Center(
                          child: OutlinedButton(
                              onPressed: () => _load(reset: false),
                              child: Text(tx('Daha fazla'))),
                        ),
                      );
                    }
                    final r = _res[i];
                    final previewId = 'prev:${r.url}';
                    final prev = media.nowId == previewId;
                    final have = store.hasStationUrl(r.url);
                    final sub = [
                      r.country,
                      r.tags,
                      if (r.bitrate > 0) '${r.bitrate} kbps',
                    ].where((x) => x.isNotEmpty).join(' · ');
                    return ListTile(
                      title: Text(r.name,
                          maxLines: 1, overflow: TextOverflow.ellipsis),
                      subtitle: Text(sub,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.soft, fontSize: 12)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: tx('Dinle'),
                            onPressed: () {
                              if (prev) {
                                media.toggle();
                              } else {
                                media.playStation(Station(
                                    id: previewId, name: r.name, url: r.url));
                              }
                            },
                            icon: Icon(prev && media.playing
                                ? Icons.pause_circle_outline_rounded
                                : Icons.play_circle_outline_rounded),
                          ),
                          IconButton(
                            tooltip: tx('Ekle'),
                            onPressed: have ? null : () => _add(r),
                            icon: Icon(have
                                ? Icons.check_circle_rounded
                                : Icons.add_circle_outline_rounded),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
          const NowBar(),
        ],
      ),
    );
  }
}

// ---------- Ülke seçme ekranı ----------
class _CountrySheet extends StatefulWidget {
  const _CountrySheet();

  @override
  State<_CountrySheet> createState() => _CountrySheetState();
}

class _CountrySheetState extends State<_CountrySheet> {
  late Future<List<RbCountry>> _f;
  final _q = TextEditingController();

  @override
  void initState() {
    super.initState();
    _f = rbCountries();
  }

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
                      child: Text(
                          tx('Ülke listesi alınamadı. İnternetini kontrol et.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.soft)),
                    ));
                  }
                  final q = _q.text.trim().toLowerCase();
                  final all = snap.data!
                      .where((c) =>
                          q.isEmpty || c.name.toLowerCase().contains(q))
                      .toList();
                  final tr = all.where((c) => c.code == 'TR').toList();
                  final rest = all.where((c) => c.code != 'TR').toList();
                  final list = <RbCountry>[
                    if (q.isEmpty) RbCountry('', tx('Tümü'), 0),
                    ...tr,
                    ...rest,
                  ];
                  return ListView.builder(
                    itemCount: list.length,
                    itemBuilder: (context, i) {
                      final c = list[i];
                      return ListTile(
                        title: Text(c.code == 'TR' ? tx('Türkiye') : c.name),
                        trailing: c.count > 0
                            ? Text('${c.count}',
                                style: TextStyle(color: p.soft, fontSize: 12.5))
                            : null,
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
