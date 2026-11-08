import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'data.dart';
import 'media.dart' show slideFromRight;
import 'strings.dart';
import 'theme.dart' show Pal;
import 'studydata.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// DERS ÇALIŞMA
// Sekmeler: LGS / Yabancı dil. Ders -> konu -> kartlar.
// Kartlar: ön yüz (kelime, deyim...), açıklama, örnek cümle.
// "Tekrar et": Biliyorum -> kart 1, 3, 7, 14 gün sonra tekrar gelir.
//              Bilmiyorum -> açıklama ve örnek gösterilir, kart sıfırlanır.
// ---------------------------------------------------------------

class _Item {
  final String id; // hazır: '<konuId>#<sıra>', kullanıcı: kart kimliği
  final String topic;
  final String front;
  final String exp;
  final String ex;
  final bool builtin;
  const _Item(this.id, this.topic, this.front, this.exp, this.ex, this.builtin);
}

StudySubjectDef? _subj(String id) {
  for (final s in studySubjects) {
    if (s.id == id) return s;
  }
  return null;
}

class _TopicRef {
  final String id;
  final String name;
  final bool custom;
  const _TopicRef(this.id, this.name, this.custom);
}

List<_TopicRef> _topicsOf(StudySubjectDef s) => [
      for (final t in s.topics) _TopicRef(t.id, t.name, false),
      for (final t in store.studyTopics)
        if (t.subj == s.id) _TopicRef(t.id, t.name, true),
    ];

List<_Item> _itemsOf(String topicId) {
  final out = <_Item>[];
  final sid = topicId.startsWith('u:') ? null : topicId.split('.').first;
  if (sid != null) {
    final s = _subj(sid);
    if (s != null) {
      for (final t in s.topics) {
        if (t.id != topicId) continue;
        for (var i = 0; i < t.cards.length; i++) {
          final id = '$topicId#$i';
          if (store.studyHid.contains(id)) continue;
          final c = t.cards[i];
          out.add(_Item(id, topicId, c[0], c[1], c[2], true));
        }
      }
    }
  }
  for (final c in store.studyCards) {
    if (c.topic == topicId) {
      out.add(_Item(c.id, topicId, c.front, c.exp, c.ex, false));
    }
  }
  return out;
}

List<_Item> _itemsOfSubject(StudySubjectDef s) =>
    [for (final t in _topicsOf(s)) ..._itemsOf(t.id)];

int _dueCount(List<_Item> l) => l.where((i) => store.studyIsDue(i.id)).length;

// ---------------------------------------------------------------
// Ana sayfa: sekmeler ve dersler
// ---------------------------------------------------------------
class StudyPage extends StatelessWidget {
  const StudyPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        final tab = store.studyTab == 'dil' ? 'dil' : 'lgs';
        final list = studySubjects.where((s) => s.group == tab).toList();
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(title: Text(tx('Ders çalışma'))),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              SegmentedButton<String>(
                segments: [
                  ButtonSegment(value: 'lgs', label: Text(tx('LGS'))),
                  ButtonSegment(value: 'dil', label: Text(tx('Yabancı dil'))),
                ],
                selected: {tab},
                showSelectedIcon: false,
                onSelectionChanged: (s) => store.setStudyTab(s.first),
              ),
              const SizedBox(height: 10),
              for (final s in list) _subjectCard(context, p, s),
              const SizedBox(height: 12),
              Text(
                tx('Hazır içerikler yardımcı notlardır; kaynaklarla tek tek doğrulanmamıştır. Düzenleyebilir, silebilir ve kendi kartlarını ekleyebilirsin.'),
                style: TextStyle(color: p.soft, fontSize: 12, height: 1.4),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _subjectCard(BuildContext context, Pal p, StudySubjectDef s) {
    final all = _itemsOfSubject(s);
    final due = _dueCount(all);
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: () =>
              Navigator.of(context).push(slideFromRight(_SubjectPage(s.id))),
          child: Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: p.line),
            ),
            child: Row(
              children: [
                CircleAvatar(
                  backgroundColor: p.accent.withOpacity(0.15),
                  child: Icon(
                      s.group == 'dil'
                          ? Icons.translate_rounded
                          : Icons.menu_book_rounded,
                      color: p.accent),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(s.name,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: p.ink)),
                      const SizedBox(height: 2),
                      Text(
                          tx('{0} kart • {1} tekrar bekliyor',
                              ['${all.length}', '$due']),
                          style: TextStyle(color: p.soft, fontSize: 12.5)),
                    ],
                  ),
                ),
                const Icon(Icons.chevron_right_rounded),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Ders: konu başlıkları
// ---------------------------------------------------------------
class _SubjectPage extends StatelessWidget {
  final String sid;
  const _SubjectPage(this.sid);

  @override
  Widget build(BuildContext context) {
    final s = _subj(sid)!;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        final topics = _topicsOf(s);
        final all = _itemsOfSubject(s);
        final due = _dueCount(all);
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(title: Text(s.name, maxLines: 1)),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () async {
              final n = await askText(context, tx('Yeni konu'),
                  label: tx('Konu başlığı'));
              if (n != null && n.trim().isNotEmpty) {
                store.addStudyTopic(s.id, n);
              }
            },
            icon: const Icon(Icons.add_rounded),
            label: Text(tx('Konu ekle')),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            children: [
              FilledButton.icon(
                onPressed: all.isEmpty
                    ? null
                    : () => _startReview(context, s.name, all),
                icon: const Icon(Icons.replay_rounded),
                label: Text(tx('Tüm konuları tekrar et ({0})', ['$due'])),
              ),
              const SizedBox(height: 10),
              for (final t in topics) _topicTile(context, p, t),
            ],
          ),
        );
      },
    );
  }

  Widget _topicTile(BuildContext context, Pal p, _TopicRef t) {
    final items = _itemsOf(t.id);
    final due = _dueCount(items);
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context)
              .push(slideFromRight(_TopicPage(sid, t.id, t.name))),
          child: Container(
            padding: const EdgeInsets.fromLTRB(14, 12, 6, 12),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.line),
            ),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(t.name,
                          style: TextStyle(
                              fontSize: 15.5,
                              fontWeight: FontWeight.w600,
                              color: p.ink)),
                      const SizedBox(height: 2),
                      Text(
                          tx('{0} kart • {1} tekrar bekliyor',
                              ['${items.length}', '$due']),
                          style: TextStyle(color: p.soft, fontSize: 12)),
                    ],
                  ),
                ),
                if (t.custom)
                  PopupMenuButton<String>(
                    onSelected: (v) async {
                      if (v == 'ren') {
                        final n = await askText(context, tx('Konu adı'),
                            initial: t.name, label: tx('Konu başlığı'));
                        if (n != null && n.trim().isNotEmpty) {
                          store.renameStudyTopic(t.id, n);
                        }
                      } else {
                        final ok = await confirmDialog(
                            context,
                            tx('Konu silinsin mi?'),
                            tx('Bu konudaki tüm kartların da silinir.'));
                        if (ok) store.deleteStudyTopic(t.id);
                      }
                    },
                    itemBuilder: (_) => [
                      PopupMenuItem(value: 'ren', child: Text(tx('Adını değiştir'))),
                      PopupMenuItem(value: 'del', child: Text(tx('Sil'))),
                    ],
                  )
                else
                  const Padding(
                    padding: EdgeInsets.only(right: 8),
                    child: Icon(Icons.chevron_right_rounded),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

void _startReview(BuildContext context, String title, List<_Item> items,
    {bool all = false}) {
  final now = items.where((i) => store.studyIsDue(i.id)).toList();
  final use = all || now.isEmpty ? items : now;
  if (use.isEmpty) return;
  Navigator.of(context).push(slideFromRight(_ReviewPage(title, use)));
}

// ---------------------------------------------------------------
// Konu: kart listesi
// ---------------------------------------------------------------
class _TopicPage extends StatelessWidget {
  final String sid;
  final String topicId;
  final String name;
  const _TopicPage(this.sid, this.topicId, this.name);

  Future<void> _edit(BuildContext context, _Item? it) async {
    final r = await showDialog<List<String>>(
        context: context,
        builder: (_) => _CardDialog(
            front: it?.front ?? '', exp: it?.exp ?? '', ex: it?.ex ?? ''));
    if (r == null) return;
    if (it == null) {
      store.addStudyCard(topicId, r[0], r[1], r[2]);
    } else if (it.builtin) {
      store.editBuiltinCard(it.id, topicId, r[0], r[1], r[2]);
    } else {
      store.editStudyCard(it.id, r[0], r[1], r[2]);
    }
  }

  String _status(_Item i) {
    final b = store.studyBox(i.id);
    if (b == 0) return tx('Yeni');
    return store.studyIsDue(i.id) ? tx('Tekrar zamanı') : tx('Öğrenildi');
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        final items = _itemsOf(topicId);
        final due = _dueCount(items);
        final hasHidden =
            store.studyHid.any((h) => h.startsWith('$topicId#'));
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            title: Text(name, maxLines: 1),
            actions: [
              if (hasHidden)
                IconButton(
                  tooltip: tx('Silinen hazır kartları geri getir'),
                  icon: const Icon(Icons.restore_rounded),
                  onPressed: () => store.restoreStudyHidden(topicId),
                ),
            ],
          ),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add_rounded),
            label: Text(tx('Kart ekle')),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            children: [
              FilledButton.icon(
                onPressed:
                    items.isEmpty ? null : () => _startReview(context, name, items),
                icon: const Icon(Icons.replay_rounded),
                label: Text(due > 0
                    ? tx('Tekrar et ({0})', ['$due'])
                    : tx('Hepsini yeniden çalış')),
              ),
              if (items.isNotEmpty && due == 0)
                Padding(
                  padding: const EdgeInsets.only(top: 6),
                  child: Text(tx('Şimdilik tekrar bekleyen kart yok.'),
                      style: TextStyle(color: p.soft, fontSize: 12.5)),
                ),
              const SizedBox(height: 10),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(tx('Henüz kart yok. Kart ekle düğmesiyle başla.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.soft)),
                ),
              for (final i in items)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.line),
                  ),
                  child: ListTile(
                    onTap: () => _edit(context, i),
                    title: Text(i.front,
                        style: TextStyle(
                            color: p.ink, fontWeight: FontWeight.w600)),
                    subtitle: Text(
                        '${i.exp}\n${_status(i)}${i.builtin ? ' • ${tx('hazır')}' : ''}',
                        maxLines: 3,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(color: p.soft, fontSize: 12.5)),
                    isThreeLine: true,
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        final ok = await confirmDialog(context,
                            tx('Kart silinsin mi?'), i.front);
                        if (ok) store.deleteStudyCard(i.id);
                      },
                    ),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}

class _CardDialog extends StatefulWidget {
  final String front, exp, ex;
  const _CardDialog({required this.front, required this.exp, required this.ex});

  @override
  State<_CardDialog> createState() => _CardDialogState();
}

class _CardDialogState extends State<_CardDialog> {
  late final TextEditingController _f = TextEditingController(text: widget.front);
  late final TextEditingController _e = TextEditingController(text: widget.exp);
  late final TextEditingController _x = TextEditingController(text: widget.ex);

  @override
  void dispose() {
    _f.dispose();
    _e.dispose();
    _x.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.front.isEmpty && widget.exp.isEmpty
          ? tx('Yeni kart')
          : tx('Kartı düzenle')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _f,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tx('Kelime / deyim')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _e,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tx('Açıklama')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _x,
              minLines: 1,
              maxLines: 4,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tx('Örnek cümle')),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(tx('Vazgeç'))),
        FilledButton(
          onPressed: () {
            if (_f.text.trim().isEmpty) return;
            Navigator.pop(context, [_f.text, _e.text, _x.text]);
          },
          child: Text(tx('Kaydet')),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------
// Tekrar: kart gelir; Biliyorum / Bilmiyorum
// ---------------------------------------------------------------
class _ReviewPage extends StatefulWidget {
  final String title;
  final List<_Item> items;
  const _ReviewPage(this.title, this.items);

  @override
  State<_ReviewPage> createState() => _ReviewPageState();
}

class _ReviewPageState extends State<_ReviewPage> {
  late final List<_Item> _q = List.of(widget.items)..shuffle(Random());
  bool _shown = false; // Bilmiyorum -> açıklama gösteriliyor
  int _known = 0;
  late final int _total = widget.items.length;

  void _know() {
    final c = _q.removeAt(0);
    store.studyKnow(c.id);
    _known++;
    setState(() => _shown = false);
  }

  void _dontKnow() {
    store.studyForget(_q.first.id);
    setState(() => _shown = true);
  }

  void _next() {
    // Bilinmeyen kart sıranın sonuna gider; oturumda tekrar karşına çıkar
    final c = _q.removeAt(0);
    _q.add(c);
    setState(() => _shown = false);
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final done = _q.isEmpty;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(title: Text(widget.title, maxLines: 1)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: done ? _finished(p) : _card(p),
        ),
      ),
    );
  }

  Widget _finished(Pal p) => Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.check_circle_outline_rounded, size: 72, color: p.accent),
            const SizedBox(height: 12),
            Text(tx('Tekrar bitti'),
                style: TextStyle(
                    fontSize: 22, fontWeight: FontWeight.w700, color: p.ink)),
            const SizedBox(height: 6),
            Text(tx('{0} kart bilindi.', ['$_known']),
                style: TextStyle(color: p.soft)),
            const SizedBox(height: 20),
            FilledButton(
                onPressed: () => Navigator.pop(context), child: Text(tx('Tamam'))),
          ],
        ),
      );

  Widget _card(Pal p) {
    final c = _q.first;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(tx('Kalan: {0} / {1}', ['${_q.length}', '$_total']),
            textAlign: TextAlign.center,
            style: TextStyle(color: p.soft, fontSize: 12.5)),
        const SizedBox(height: 4),
        LinearProgressIndicator(value: _total == 0 ? 0 : _known / _total),
        const SizedBox(height: 16),
        Expanded(
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(22),
              border: Border.all(color: p.line),
            ),
            child: SingleChildScrollView(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const SizedBox(height: 12),
                  Text(c.front,
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.w700,
                          color: p.ink)),
                  if (_shown) ...[
                    const SizedBox(height: 22),
                    if (c.exp.isNotEmpty)
                      Text(c.exp,
                          textAlign: TextAlign.center,
                          style: TextStyle(fontSize: 17, color: p.ink, height: 1.4)),
                    if (c.ex.isNotEmpty) ...[
                      const SizedBox(height: 14),
                      Text(c.ex,
                          textAlign: TextAlign.center,
                          style: TextStyle(
                              fontSize: 15,
                              fontStyle: FontStyle.italic,
                              color: p.soft,
                              height: 1.4)),
                    ],
                  ],
                ],
              ),
            ),
          ),
        ),
        const SizedBox(height: 14),
        if (!_shown)
          Row(
            children: [
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: OutlinedButton.icon(
                    onPressed: _dontKnow,
                    icon: const Icon(Icons.close_rounded),
                    label: Text(tx('Bilmiyorum')),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: SizedBox(
                  height: 54,
                  child: FilledButton.icon(
                    onPressed: _know,
                    icon: const Icon(Icons.check_rounded),
                    label: Text(tx('Biliyorum')),
                  ),
                ),
              ),
            ],
          )
        else
          SizedBox(
            height: 54,
            child: FilledButton(onPressed: _next, child: Text(tx('Anladım, devam'))),
          ),
      ],
    );
  }
}
