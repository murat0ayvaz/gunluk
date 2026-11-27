import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'ambient.dart';
import 'data.dart';
import 'notify.dart';
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// NOTLAR (Araçlar > Kişisel > Notlar): iki sütunlu kartlar, etiket / klasör çubuğu, arama, sabitleme,
// fotoğraf (isteğe bağlı), kontrol listesi, hatırlatma. Ana ekrana bölüm olarak eklenebilir
// (prof 'memohome'). Fotoğraflar voice/ klasöründe "memo_" ile saklanır (yedeğe ses kayıtlarıyla girer).
// İçe aktarma: Google Keep (Takeout zip / json), metin / html / md dosyaları (ör. Mi Notlar dışa aktarımı).
// ---------------------------------------------------------------

String _memoDir = ''; // fotoğrafların klasörü (ilk açılışta bulunur)

Future<void> _ensureDir() async {
  if (_memoDir.isNotEmpty) return;
  try {
    _memoDir = (await store.voiceDir()).path;
  } catch (_) {}
}

Widget _memoImg(String name, {double? h, BoxFit fit = BoxFit.cover}) {
  if (_memoDir.isEmpty) return SizedBox(height: h);
  return Image.file(File('$_memoDir/$name'),
      height: h,
      width: double.infinity,
      fit: fit,
      errorBuilder: (_, __, ___) => SizedBox(height: h));
}

String memoTitleOf(MemoItem m) {
  if (m.title.trim().isNotEmpty) return m.title.trim();
  if (m.isList) {
    for (final c in m.checks) {
      if (c.t.trim().isNotEmpty) return c.t.trim();
    }
  } else {
    for (final l in m.text.split('\n')) {
      if (l.trim().isNotEmpty) return l.trim();
    }
  }
  return m.images.isNotEmpty ? tx('Fotoğraf') : tx('Boş not');
}

String memoPreviewOf(MemoItem m) {
  if (m.isList) {
    final l = [
      for (final c in m.checks)
        if (c.t.trim().isNotEmpty) '${c.d ? '☑' : '☐'} ${c.t.trim()}'
    ];
    return l.take(5).join('\n');
  }
  if (m.title.trim().isEmpty) {
    // başlık yoksa ilk satır başlık olarak kullanıldı: önizleme geri kalanı
    final ls = m.text.split('\n').where((x) => x.trim().isNotEmpty).toList();
    return ls.length > 1 ? ls.sublist(1).join('\n') : '';
  }
  return m.text.trim();
}

String memoDateText(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${d.day} ${monName(d.month)}, ${d.year}';
}

Future<void> openMemoEditor(BuildContext context, [MemoItem? m]) async {
  await _ensureDir();
  if (!context.mounted) return;
  await Navigator.of(context)
      .push(MaterialPageRoute<void>(builder: (_) => MemoEditor(item: m)));
}

void _syncMemoRemind(MemoItem m) {
  Notifier.syncMemo(m);
}

// ---------------------------------------------------------------
// NOTLAR SAYFASI
// ---------------------------------------------------------------
class MemoPage extends StatefulWidget {
  const MemoPage({super.key});

  @override
  State<MemoPage> createState() => _MemoPageState();
}

class _MemoPageState extends State<MemoPage> {
  String _tag = '';
  String _q = '';
  bool _search = false;

  @override
  void initState() {
    super.initState();
    _ensureDir().then((_) {
      if (mounted) setState(() {});
    });
  }

  void _delete(MemoItem m) {
    store.memoDelete(m.id);
    Notifier.cancelOnce(m.nid * 100);
    showUndo(context, tx('Not silindi'), () {
      store.memoRestore(m);
      _syncMemoRemind(m);
    });
  }

  Future<void> _pickTag(MemoItem m) async {
    final p = palOf(context);
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: p.card,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.label_off_outlined),
              title: Text(tx('Etiketsiz')),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final t in store.memoTags)
              ListTile(
                leading: const Icon(Icons.label_outline_rounded),
                title: Text(t),
                trailing: m.tag == t ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(ctx, t),
              ),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: Text(tx('Yeni etiket')),
              onTap: () => Navigator.pop(ctx, '\u0000new'),
            ),
          ],
        ),
      ),
    );
    if (pick == null) return;
    var t = pick;
    if (pick == '\u0000new') {
      if (!mounted) return;
      final n = await askText(context, tx('Yeni etiket'), label: tx('Etiket adı'));
      if (n == null) return;
      t = n;
    }
    m.tag = t;
    store.memoSave(m);
  }

  Future<void> _menu(MemoItem m) async {
    final p = palOf(context);
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: p.card,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: Icon(m.pinned ? Icons.push_pin : Icons.push_pin_outlined),
              title: Text(m.pinned ? tx('Sabitlemeyi kaldır') : tx('Sabitle')),
              onTap: () {
                Navigator.pop(ctx);
                m.pinned = !m.pinned;
                store.memoSave(m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.label_outline_rounded),
              title: Text(tx('Etiket')),
              onTap: () {
                Navigator.pop(ctx);
                _pickTag(m);
              },
            ),
            ListTile(
              leading: const Icon(Icons.delete_outline_rounded),
              title: Text(tx('Sil')),
              onTap: () {
                Navigator.pop(ctx);
                _delete(m);
              },
            ),
          ],
        ),
      ),
    );
  }

  Widget _card(Pal p, MemoItem m) {
    final prev = memoPreviewOf(m);
    return GestureDetector(
      onTap: () => openMemoEditor(context, m),
      onLongPress: () => _menu(m),
      child: Container(
        clipBehavior: Clip.antiAlias,
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: p.line),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (m.images.isNotEmpty)
              SizedBox(
                  height: 120,
                  width: double.infinity,
                  child: _memoImg(m.images.first, h: 120)),
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 12, 14, 10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(memoTitleOf(m),
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(
                          color: p.ink, fontSize: 16, fontWeight: FontWeight.w700)),
                  if (prev.isNotEmpty) ...[
                    const SizedBox(height: 6),
                    Text(prev,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.soft, fontSize: 14, height: 1.3)),
                  ],
                  const SizedBox(height: 8),
                  Row(children: [
                    Expanded(
                      child: Text(memoDateText(m.updated),
                          style: TextStyle(color: p.soft, fontSize: 12)),
                    ),
                    if (m.tag.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.label_outline_rounded, size: 14, color: p.soft),
                      ),
                    if (m.remindMs > 0)
                      Padding(
                        padding: const EdgeInsets.only(right: 4),
                        child: Icon(Icons.notifications_active_outlined, size: 14, color: p.soft),
                      ),
                    if (m.pinned) Icon(Icons.push_pin, size: 14, color: p.accent),
                  ]),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _grid(Pal p, List<MemoItem> list) {
    final cols = <List<Widget>>[[], []];
    final hs = [0.0, 0.0];
    for (final m in list) {
      final prev = memoPreviewOf(m);
      final est = 90.0 +
          (m.images.isNotEmpty ? 120.0 : 0.0) +
          (prev.length / 26).clamp(0, 5).toDouble() * 19.0;
      final i = hs[0] <= hs[1] ? 0 : 1;
      cols[i].add(Padding(padding: const EdgeInsets.only(bottom: 10), child: _card(p, m)));
      hs[i] += est;
    }
    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(14, 6, 14, 100),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Column(children: cols[0])),
          const SizedBox(width: 10),
          Expanded(child: Column(children: cols[1])),
        ],
      ),
    );
  }

  Widget _tagBar(Pal p) {
    return SizedBox(
      height: 46,
      child: ListView(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 14),
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              label: Text(tx('Tümü')),
              selected: _tag.isEmpty,
              onSelected: (_) => setState(() => _tag = ''),
            ),
          ),
          for (final t in store.memoTags)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onLongPress: () async {
                  final ok = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: Text(tx('"{0}" etiketi silinsin mi?', [t])),
                      content: Text(tx('Notlar silinmez, etiketsiz kalır.')),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, false),
                            child: Text(tx('Vazgeç'))),
                        TextButton(
                            onPressed: () => Navigator.pop(ctx, true),
                            child: Text(tx('Sil'))),
                      ],
                    ),
                  );
                  if (ok == true) {
                    if (_tag == t) _tag = '';
                    store.memoRemoveTag(t);
                  }
                },
                child: ChoiceChip(
                  label: Text(t),
                  selected: _tag == t,
                  onSelected: (_) => setState(() => _tag = t),
                ),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.create_new_folder_outlined, size: 18),
            label: Text(tx('Etiket')),
            onPressed: () async {
              final n = await askText(context, tx('Yeni etiket'), label: tx('Etiket adı'));
              if (n != null) store.memoAddTag(n);
            },
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        var list = store.memosSorted(_tag);
        final q = _q.trim().toLowerCase();
        if (q.isNotEmpty) {
          list = [
            for (final m in list)
              if (memoTitleOf(m).toLowerCase().contains(q) ||
                  m.text.toLowerCase().contains(q) ||
                  m.checks.any((c) => c.t.toLowerCase().contains(q)))
                m
          ];
        }
        return AmbScaffold(
          kind: 'settings',
          backgroundColor: ambBg(p),
          appBar: AppBar(
            backgroundColor: ambBg(p),
            elevation: 0,
            scrolledUnderElevation: 0,
            title: _search
                ? TextField(
                    autofocus: true,
                    decoration: InputDecoration(
                        hintText: tx('Notlarda ara'), border: InputBorder.none),
                    onChanged: (v) => setState(() => _q = v),
                  )
                : Text(tx('Notlar')),
            actions: [
              IconButton(
                icon: Icon(_search ? Icons.close_rounded : Icons.search_rounded),
                onPressed: () => setState(() {
                  _search = !_search;
                  if (!_search) _q = '';
                }),
              ),
              PopupMenuButton<int>(
                onSelected: (v) {
                  if (v == 0) importMemos(context);
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 0, child: Text(tx('İçe aktar (Keep, Mi Notlar, dosya)'))),
                ],
              ),
            ],
          ),
          floatingActionButton: FloatingActionButton(
            onPressed: () => openMemoEditor(context),
            child: const Icon(Icons.add_rounded),
          ),
          body: Column(
            children: [
              SwitchListTile(
                dense: true,
                contentPadding: const EdgeInsets.symmetric(horizontal: 18),
                secondary: const Icon(Icons.home_rounded),
                title: Text(tx('Ana ekrana ekle')),
                value: store.pBool('memohome', false),
                onChanged: (v) => store.setProf('memohome', v),
              ),
              _tagBar(p),
              Expanded(
                child: list.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                              store.memos.isEmpty
                                  ? tx('Henüz not yok. + ile ekle ya da ⋮ menüsünden içe aktar.')
                                  : tx('Bu filtreye uyan not yok.'),
                              textAlign: TextAlign.center,
                              style: TextStyle(color: p.soft)),
                        ),
                      )
                    : _grid(p, list),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------
// NOT DÜZENLEYİCİ: yazdıkça otomatik kaydeder
// ---------------------------------------------------------------
class MemoEditor extends StatefulWidget {
  final MemoItem? item;
  const MemoEditor({super.key, this.item});

  @override
  State<MemoEditor> createState() => _MemoEditorState();
}

class _MemoEditorState extends State<MemoEditor> {
  late final MemoItem m = widget.item ?? MemoItem(store.newId());
  late final TextEditingController _title = TextEditingController(text: m.title);
  late final TextEditingController _text = TextEditingController(text: m.text);
  final List<TextEditingController> _cc = [];
  final List<bool> _cd = [];
  Timer? _t;

  @override
  void initState() {
    super.initState();
    for (final c in m.checks) {
      _cc.add(TextEditingController(text: c.t));
      _cd.add(c.d);
    }
    if (m.isList && _cc.isEmpty) _addRow('');
  }

  @override
  void dispose() {
    _t?.cancel();
    if (!_deleted) {
      m.title = _title.text;
      m.text = _text.text;
      m.checks = [
        for (var i = 0; i < _cc.length; i++) MemoCheck(_cc[i].text, _cd[i])
      ];
      // kapanma sırasında dinleyicileri tetiklememek için bir sonraki döngüde kaydet
      Future.microtask(() {
        store.memoSave(m);
        _syncMemoRemind(m);
      });
    }
    _title.dispose();
    _text.dispose();
    for (final c in _cc) {
      c.dispose();
    }
    super.dispose();
  }

  void _addRow(String t) {
    _cc.add(TextEditingController(text: t));
    _cd.add(false);
  }

  void _changed() {
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 700), _flush);
  }

  void _flush() {
    if (_deleted) return;
    m.title = _title.text;
    m.text = _text.text;
    m.checks = [
      for (var i = 0; i < _cc.length; i++) MemoCheck(_cc[i].text, _cd[i])
    ];
    store.memoSave(m);
    _syncMemoRemind(m);
  }

  void _toggleList() {
    setState(() {
      if (!m.isList) {
        // metin -> liste: her satır bir madde
        for (final c in _cc) {
          c.dispose();
        }
        _cc.clear();
        _cd.clear();
        for (final l in _text.text.split('\n')) {
          if (l.trim().isNotEmpty) _addRow(l.trim());
        }
        if (_cc.isEmpty) _addRow('');
        m.isList = true;
      } else {
        // liste -> metin
        _text.text = [
          for (final c in _cc)
            if (c.text.trim().isNotEmpty) c.text.trim()
        ].join('\n');
        m.isList = false;
      }
    });
    _changed();
  }

  Future<void> _addImages() async {
    try {
      final r = await FilePicker.platform
          .pickFiles(type: FileType.image, allowMultiple: true, withData: true);
      if (r == null) return;
      for (final f in r.files) {
        final b = f.bytes;
        if (b == null) continue;
        final n = await store.memoSaveImage(b, f.extension ?? 'jpg');
        if (n != null) m.images.add(n);
      }
      await _ensureDir();
      if (mounted) setState(() {});
      _changed();
    } catch (_) {}
  }

  Future<void> _remind() async {
    final now = DateTime.now();
    final d = await showDatePicker(
      context: context,
      initialDate: m.remindMs > 0
          ? DateTime.fromMillisecondsSinceEpoch(m.remindMs)
          : now,
      firstDate: DateTime(now.year, now.month, now.day),
      lastDate: DateTime(now.year + 5),
    );
    if (d == null || !mounted) return;
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay(hour: now.hour, minute: now.minute));
    if (t == null) return;
    final w = DateTime(d.year, d.month, d.day, t.hour, t.minute);
    setState(() {
      m.remindMs = w.millisecondsSinceEpoch;
      if (m.nid == 0) m.nid = store.newNid();
    });
    _changed();
  }

  void _clearRemind() {
    setState(() => m.remindMs = 0);
    _changed();
  }

  Future<void> _tag() async {
    final p = palOf(context);
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: p.card,
      builder: (ctx) => SafeArea(
        child: ListView(
          shrinkWrap: true,
          children: [
            ListTile(
              leading: const Icon(Icons.label_off_outlined),
              title: Text(tx('Etiketsiz')),
              onTap: () => Navigator.pop(ctx, ''),
            ),
            for (final t in store.memoTags)
              ListTile(
                leading: const Icon(Icons.label_outline_rounded),
                title: Text(t),
                trailing: m.tag == t ? const Icon(Icons.check_rounded) : null,
                onTap: () => Navigator.pop(ctx, t),
              ),
            ListTile(
              leading: const Icon(Icons.add_rounded),
              title: Text(tx('Yeni etiket')),
              onTap: () => Navigator.pop(ctx, '\u0000new'),
            ),
          ],
        ),
      ),
    );
    if (pick == null) return;
    var t = pick;
    if (pick == '\u0000new') {
      if (!mounted) return;
      final n = await askText(context, tx('Yeni etiket'), label: tx('Etiket adı'));
      if (n == null) return;
      t = n;
    }
    setState(() => m.tag = t);
    if (t.isNotEmpty && !store.memoTags.contains(t)) store.memoAddTag(t);
    _changed();
  }

  void _delete() {
    _t?.cancel();
    final copy = m;
    // düzenleyici kapanırken _flush yeniden kaydetmesin
    store.memoDelete(m.id);
    Notifier.cancelOnce(m.nid * 100);
    final nav = Navigator.of(context);
    final messenger = ScaffoldMessenger.of(context);
    _deleted = true;
    nav.pop();
    messenger.clearSnackBars();
    messenger.showSnackBar(SnackBar(
      content: Text(tx('Not silindi')),
      action: SnackBarAction(
        label: tx('Geri al'),
        onPressed: () {
          store.memoRestore(copy);
          _syncMemoRemind(copy);
        },
      ),
    ));
  }

  bool _deleted = false;

  void _view(String name) {
    showDialog<void>(
      context: context,
      builder: (ctx) => Dialog(
        backgroundColor: Colors.black,
        insetPadding: const EdgeInsets.all(8),
        child: InteractiveViewer(child: _memoImg(name, fit: BoxFit.contain)),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final remind = m.remindMs > 0
        ? DateTime.fromMillisecondsSinceEpoch(m.remindMs)
        : null;
    String two(int n) => n.toString().padLeft(2, '0');
    return Scaffold(
        backgroundColor: p.bg,
        appBar: AppBar(
          backgroundColor: p.bg,
          elevation: 0,
          scrolledUnderElevation: 0,
          actions: [
            IconButton(
              tooltip: tx('Sabitle'),
              icon: Icon(m.pinned ? Icons.push_pin : Icons.push_pin_outlined),
              onPressed: () {
                setState(() => m.pinned = !m.pinned);
                _changed();
              },
            ),
            IconButton(
              tooltip: tx('Kontrol listesi'),
              icon: Icon(m.isList ? Icons.notes_rounded : Icons.checklist_rounded),
              onPressed: _toggleList,
            ),
            IconButton(
              tooltip: tx('Fotoğraf ekle'),
              icon: const Icon(Icons.image_outlined),
              onPressed: _addImages,
            ),
            IconButton(
              tooltip: tx('Hatırlatma'),
              icon: Icon(m.remindMs > 0
                  ? Icons.notifications_active_rounded
                  : Icons.notifications_none_rounded),
              onPressed: _remind,
            ),
            PopupMenuButton<int>(
              onSelected: (v) {
                if (v == 0) _tag();
                if (v == 1) _delete();
              },
              itemBuilder: (_) => [
                PopupMenuItem(value: 0, child: Text(tx('Etiket'))),
                PopupMenuItem(value: 1, child: Text(tx('Sil'))),
              ],
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(18, 0, 18, 60),
          children: [
            TextField(
              controller: _title,
              onChanged: (_) => _changed(),
              style: TextStyle(color: p.ink, fontSize: 22, fontWeight: FontWeight.w700),
              decoration: InputDecoration(
                  hintText: tx('Başlık'),
                  hintStyle: TextStyle(color: p.soft),
                  border: InputBorder.none),
            ),
            if (m.tag.isNotEmpty || remind != null)
              Wrap(spacing: 8, children: [
                if (m.tag.isNotEmpty)
                  InputChip(
                    avatar: const Icon(Icons.label_outline_rounded, size: 16),
                    label: Text(m.tag),
                    onPressed: _tag,
                    onDeleted: () {
                      setState(() => m.tag = '');
                      _changed();
                    },
                  ),
                if (remind != null)
                  InputChip(
                    avatar: const Icon(Icons.notifications_active_outlined, size: 16),
                    label: Text(
                        '${remind.day} ${monName(remind.month)} ${two(remind.hour)}:${two(remind.minute)}'),
                    onPressed: _remind,
                    onDeleted: _clearRemind,
                  ),
              ]),
            if (m.images.isNotEmpty) ...[
              const SizedBox(height: 8),
              SizedBox(
                height: 110,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  children: [
                    for (final n in m.images)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: Stack(children: [
                          GestureDetector(
                            onTap: () => _view(n),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: SizedBox(
                                  width: 110, height: 110, child: _memoImg(n, h: 110)),
                            ),
                          ),
                          Positioned(
                            right: 0,
                            top: 0,
                            child: InkWell(
                              onTap: () {
                                setState(() => m.images.remove(n));
                                _changed();
                              },
                              child: const CircleAvatar(
                                  radius: 12,
                                  backgroundColor: Colors.black54,
                                  child: Icon(Icons.close_rounded, size: 16, color: Colors.white)),
                            ),
                          ),
                        ]),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 8),
            ],
            if (!m.isList)
              TextField(
                controller: _text,
                onChanged: (_) => _changed(),
                maxLines: null,
                minLines: 12,
                style: TextStyle(color: p.ink, fontSize: 16, height: 1.4),
                decoration: InputDecoration(
                    hintText: tx('Not'),
                    hintStyle: TextStyle(color: p.soft),
                    border: InputBorder.none),
              )
            else ...[
              for (var i = 0; i < _cc.length; i++)
                Row(children: [
                  Checkbox(
                    value: _cd[i],
                    onChanged: (v) {
                      setState(() => _cd[i] = v ?? false);
                      _changed();
                    },
                  ),
                  Expanded(
                    child: TextField(
                      controller: _cc[i],
                      onChanged: (_) => _changed(),
                      style: TextStyle(
                          color: _cd[i] ? p.soft : p.ink,
                          fontSize: 16,
                          decoration: _cd[i] ? TextDecoration.lineThrough : null),
                      decoration: const InputDecoration(border: InputBorder.none),
                    ),
                  ),
                  IconButton(
                    icon: Icon(Icons.close_rounded, size: 18, color: p.soft),
                    onPressed: () {
                      setState(() {
                        _cc.removeAt(i).dispose();
                        _cd.removeAt(i);
                        if (_cc.isEmpty) _addRow('');
                      });
                      _changed();
                    },
                  ),
                ]),
              TextButton.icon(
                onPressed: () => setState(() => _addRow('')),
                icon: const Icon(Icons.add_rounded),
                label: Text(tx('Madde ekle')),
              ),
            ],
          ],
        ),
    );
  }
}

// ---------------------------------------------------------------
// ANA EKRAN BÖLÜMÜ: son notlar (sabitlenenler önde)
// ---------------------------------------------------------------
class MemoHomeBody extends StatefulWidget {
  const MemoHomeBody({super.key});

  @override
  State<MemoHomeBody> createState() => _MemoHomeBodyState();
}

class _MemoHomeBodyState extends State<MemoHomeBody> {
  @override
  void initState() {
    super.initState();
    _ensureDir();
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final l = store.memosSorted().take(5).toList();
        return Padding(
          padding: const EdgeInsets.fromLTRB(8, 6, 8, 8),
          child: Column(
            children: [
              if (l.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(12),
                  child: Text(tx('Henüz not yok. Başlıktaki ⊕ ile ekle.'),
                      style: TextStyle(color: p.soft)),
                ),
              for (final m in l)
                ListTile(
                  dense: true,
                  leading: Icon(
                      m.images.isNotEmpty
                          ? Icons.image_outlined
                          : (m.isList
                              ? Icons.checklist_rounded
                              : Icons.sticky_note_2_outlined),
                      color: p.soft),
                  title: Text(memoTitleOf(m),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TextStyle(color: p.ink, fontWeight: FontWeight.w600)),
                  subtitle: memoPreviewOf(m).isEmpty
                      ? null
                      : Text(memoPreviewOf(m).split('\n').first,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(color: p.soft)),
                  trailing: m.pinned ? Icon(Icons.push_pin, size: 16, color: p.accent) : null,
                  onTap: () => openMemoEditor(context, m),
                ),
              TextButton(
                onPressed: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const MemoPage())),
                child: Text(tx('Tüm notlar')),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------
// İÇE AKTARMA: Google Keep (Takeout zip / json), metin / md / html dosyaları (Mi Notlar dışa aktarımı vb.)
// ---------------------------------------------------------------
String _htmlToText(String h) {
  var s = h.replaceAll(
      RegExp(r'<(script|style)[\s\S]*?</\1>', caseSensitive: false), '');
  s = s.replaceAll(RegExp(r'<br\s*/?>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'</(p|div|li|h[1-6]|tr)>', caseSensitive: false), '\n');
  s = s.replaceAll(RegExp(r'<[^>]+>'), '');
  s = s
      .replaceAll('&nbsp;', ' ')
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&#39;', "'");
  s = s.replaceAll(RegExp(r'\n{3,}'), '\n\n');
  return s.trim();
}

String _baseName(String path) => path.split('/').last.split('\\').last;
String _stem(String f) {
  final i = f.lastIndexOf('.');
  return i <= 0 ? f : f.substring(0, i);
}

String _ext(String f) {
  final i = f.lastIndexOf('.');
  return i < 0 ? '' : f.substring(i + 1).toLowerCase();
}

String _dec(List<int> b) => utf8.decode(b, allowMalformed: true);

/// Aynı not iki kez eklenmesin
bool _dupMemo(String title, String text, int created) {
  for (final x in store.memos) {
    if (x.title == title && x.text == text && (x.created == created || created == 0)) {
      return true;
    }
  }
  return false;
}

Future<int> _fromKeep(Map<String, dynamic> j, Map<String, List<int>> files) async {
  if (j['isTrashed'] == true) return 0;
  final title = (j['title'] ?? '').toString();
  final text = (j['textContent'] ?? '').toString();
  final list = (j['listContent'] as List?) ?? const [];
  final att = (j['attachments'] as List?) ?? const [];
  if (title.trim().isEmpty && text.trim().isEmpty && list.isEmpty && att.isEmpty) {
    return 0;
  }
  final created = ((j['createdTimestampUsec'] as num?)?.toInt() ?? 0) ~/ 1000;
  final edited = ((j['userEditedTimestampUsec'] as num?)?.toInt() ?? 0) ~/ 1000;
  final checks = <MemoCheck>[
    for (final e in list)
      if (e is Map) MemoCheck((e['text'] ?? '').toString(), e['isChecked'] == true)
  ];
  final isList = checks.isNotEmpty;
  if (!isList && _dupMemo(title, text, created)) return 0;
  final m = MemoItem(store.newId(),
      title: title,
      text: isList ? '' : text,
      pinned: j['isPinned'] == true,
      created: created > 0 ? created : null,
      updated: edited > 0 ? edited : (created > 0 ? created : null),
      checks: checks,
      isList: isList);
  final labels = (j['labels'] as List?) ?? const [];
  if (labels.isNotEmpty && labels.first is Map) {
    m.tag = ((labels.first as Map)['name'] ?? '').toString();
  }
  for (final a in att) {
    if (a is! Map) continue;
    final mime = (a['mimetype'] ?? '').toString();
    final fp = _baseName((a['filePath'] ?? '').toString());
    final data = files[fp];
    if (data != null && mime.startsWith('image/')) {
      final n = await store.memoSaveImage(data, _ext(fp));
      if (n != null) m.images.add(n);
    }
  }
  store.memoSave(m, touch: false);
  return 1;
}

Future<int> _fromText(String name, String body) async {
  final isHtml = _ext(name) == 'html' || _ext(name) == 'htm';
  final text = isHtml ? _htmlToText(body) : body.trim();
  if (text.isEmpty) return 0;
  final title = _stem(name);
  if (_dupMemo(title, text, 0)) return 0;
  final m = MemoItem(store.newId(), title: title, text: text);
  store.memoSave(m, touch: false);
  return 1;
}

Future<int> _importOne(String name, List<int> bytes) async {
  final e = _ext(name);
  var n = 0;
  if (e == 'zip') {
    final a = ZipDecoder().decodeBytes(bytes);
    final files = <String, List<int>>{};
    final jsons = <String, String>{};
    final texts = <String, String>{};
    for (final f in a) {
      if (!f.isFile) continue;
      final b = List<int>.from(f.content as List);
      final base = _baseName(f.name);
      final x = _ext(base);
      if (x == 'json') {
        jsons[f.name] = _dec(b);
      } else if (x == 'txt' || x == 'md' || x == 'html' || x == 'htm') {
        texts[f.name] = _dec(b);
        files[base] = b;
      } else {
        files[base] = b;
      }
    }
    final keepStems = <String>{};
    for (final en in jsons.entries) {
      try {
        final j = jsonDecode(en.value);
        if (j is Map<String, dynamic> &&
            (j.containsKey('textContent') || j.containsKey('listContent'))) {
          n += await _fromKeep(j, files);
          keepStems.add(_stem(_baseName(en.key)));
        }
      } catch (_) {}
    }
    for (final en in texts.entries) {
      final base = _baseName(en.key);
      if (keepStems.contains(_stem(base))) continue; // Keep'in html / metin kopyası
      if (base.toLowerCase() == 'labels.txt') continue;
      n += await _fromText(base, en.value);
    }
    return n;
  }
  if (e == 'json') {
    try {
      final j = jsonDecode(_dec(bytes));
      if (j is Map<String, dynamic>) {
        return await _fromKeep(j, {});
      }
      if (j is List) {
        for (final x in j) {
          if (x is Map<String, dynamic>) n += await _fromKeep(x, {});
        }
      }
    } catch (_) {}
    return n;
  }
  return _fromText(name, _dec(bytes));
}

Future<void> importMemos(BuildContext context) async {
  final m = ScaffoldMessenger.of(context);
  try {
    final r = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['zip', 'json', 'txt', 'md', 'html', 'htm'],
      allowMultiple: true,
      withData: true,
    );
    if (r == null) return;
    var n = 0;
    for (final f in r.files) {
      final b = f.bytes;
      if (b == null) continue;
      try {
        n += await _importOne(f.name, b);
      } catch (_) {}
    }
    await _ensureDir();
    m.clearSnackBars();
    m.showSnackBar(SnackBar(
        content: Text(n > 0
            ? tx('{0} not aktarıldı.', ['$n'])
            : tx('Aktarılacak not bulunamadı.'))));
  } catch (e) {
    m.showSnackBar(SnackBar(content: Text(tx('İçe aktarılamadı: {0}', ['$e']))));
  }
}
