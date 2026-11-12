import 'dart:math' show Random;
import 'package:flutter/material.dart';
import 'data.dart';
import 'media.dart' show slideFromRight;
import 'notify.dart';
import 'reminders.dart' show dtLabel, permissionMessage;
import 'strings.dart';
import 'theme.dart' show Pal;
import 'studydata.dart';
import 'studysum.dart';
import 'ui.dart';
import 'voice.dart';

// ---------------------------------------------------------------
// DERS ÇALIŞMA
// Sekmeler: LGS / Yabancı dil. Paketler isteğe bağlı yüklenir / silinir.
// Ders -> iki bölüm:
//   Ders çalış : konular; her konuda bilgi parçaları, notlar, ses kayıtları.
//                Bilginin yanındaki "Tekrar et" düğmesi onu tekrar listesine ekler.
//   Tekrar et  : tekrar listesindeki kartlar; Biliyorum -> 1, 3, 7, 14 gün sonra.
// Haftalık çalışma programı: gün + ders + saat aralığı (isteğe bağlı hatırlatma).
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
  final String grp;
  const _TopicRef(this.id, this.name, this.custom, [this.grp = '']);
}

// Hazır kart setleri, ilgili ünite/konunun içine taşınır (kart kimlikleri değişmez)
const _under = <String, String>{
  'lgs_tr.0': 'lgs_tr.s8', 'lgs_tr.1': 'lgs_tr.s8',
  'lgs_tr.2': 'lgs_tr.s10', 'lgs_tr.8': 'lgs_tr.s10',
  'lgs_tr.3': 'lgs_tr.s9', 'lgs_tr.4': 'lgs_tr.s4', 'lgs_tr.5': 'lgs_tr.s4',
  'lgs_tr.6': 'lgs_tr.s4', 'lgs_tr.7': 'lgs_tr.s4', 'lgs_tr.9': 'lgs_tr.s11',
  'lgs_mat.0': 'lgs_mat.s1', 'lgs_mat.1': 'lgs_mat.s5',
  'lgs_mat.2': 'lgs_mat.s7', 'lgs_mat.3': 'lgs_mat.s4',
  'lgs_fen.0': 'lgs_fen.s0', 'lgs_fen.1': 'lgs_fen.s1',
  'lgs_fen.2': 'lgs_fen.s2', 'lgs_fen.3': 'lgs_fen.s3',
  'lgs_fen.4': 'lgs_fen.s6',
  'lgs_ink.2': 'lgs_ink.s3',
  'lgs_din.0': 'lgs_din.s0', 'lgs_din.1': 'lgs_din.s3', 'lgs_din.2': 'lgs_din.s2',
  'lgs_ing.3': 'lgs_ing.s1', 'lgs_ing.4': 'lgs_ing.s1',
  'lgs_ing.5': 'lgs_ing.s2', 'lgs_ing.6': 'lgs_ing.s2',
  'lgs_ing.7': 'lgs_ing.s3', 'lgs_ing.8': 'lgs_ing.s3',
  'lgs_ing.9': 'lgs_ing.s4', 'lgs_ing.10': 'lgs_ing.s4',
  'lgs_ing.11': 'lgs_ing.s5', 'lgs_ing.12': 'lgs_ing.s5',
  'lgs_ing.13': 'lgs_ing.s6', 'lgs_ing.14': 'lgs_ing.s6',
  'lgs_ing.15': 'lgs_ing.s7', 'lgs_ing.16': 'lgs_ing.s7',
  'lgs_ing.17': 'lgs_ing.s8', 'lgs_ing.18': 'lgs_ing.s8',
  'lgs_ing.19': 'lgs_ing.s9', 'lgs_ing.20': 'lgs_ing.s9',
  'lgs_ing.21': 'lgs_ing.s10', 'lgs_ing.22': 'lgs_ing.s10',
};

// Taşınmayan kart setlerinin grubu
const _cardGrp = <String, String>{
  'lgs_ink.0': 'Genel tekrar', 'lgs_ink.1': 'Genel tekrar',
  'lgs_ing.0': 'Genel tekrar', 'lgs_ing.1': 'Gramer ve kalıplar',
  'lgs_ing.2': 'Gramer ve kalıplar',
  'lgs_ing.23': 'LGS sınav dili', 'lgs_ing.24': 'LGS sınav dili',
  'dil_en.0': 'Kelime ve deyimler', 'dil_en.3': 'Kelime ve deyimler',
  'dil_en.1': 'Gramer ve kalıplar', 'dil_en.2': 'Gramer ve kalıplar',
  'dil_en.4': 'Gramer ve kalıplar', 'dil_en.5': 'Gramer ve kalıplar',
  'dil_en.6': 'Gramer ve kalıplar', 'dil_en.7': 'Gramer ve kalıplar',
  'dil_en.8': 'Gramer ve kalıplar', 'dil_en.9': 'Gramer ve kalıplar',
};

List<String> _underOf(String sumId) =>
    [for (final e in _under.entries) if (e.value == sumId) e.key];

bool _isSum(String topicId) {
  final i = topicId.indexOf('.');
  return i > 0 && topicId.startsWith('s', i + 1);
}

List<_TopicRef> _topicsOf(StudySubjectDef s) {
  final raw = <_TopicRef>[
    for (final t in studySummaries)
      if (t.subj == s.id ||
          (s.id == 'dil_en' &&
              t.subj == 'lgs_ing' &&
              (t.grp == 'Gramer ve kalıplar' ||
                  t.grp.startsWith('Okuma'))))
        _TopicRef(t.id, t.name, false, t.grp),
    for (final t in s.topics)
      if (!_under.containsKey(t.id))
        _TopicRef(t.id, t.name, false, _cardGrp[t.id] ?? 'Diğer'),
  ];
  // gruplar ilk görüldükleri sırayla; grup içinde özgün sıra korunur
  final order = <String>[];
  for (final r in raw) {
    if (!order.contains(r.grp)) order.add(r.grp);
  }
  final out = <_TopicRef>[
    for (final g in order)
      for (final r in raw)
        if (r.grp == g) r,
  ];
  for (final t in store.studyTopics) {
    if (t.subj == s.id) out.add(_TopicRef(t.id, t.name, true, 'Kendi konuların'));
  }
  return out;
}

List<_Item> _itemsOf(String topicId) {
  final out = <_Item>[];
  if (!topicId.startsWith('u:')) {
    if (_isSum(topicId)) {
      for (final t in studySummaries) {
        if (t.id != topicId) continue;
        for (var i = 0; i < t.pieces.length; i++) {
          final id = '$topicId#$i';
          if (store.studyHid.contains(id)) continue;
          out.add(_Item(id, topicId, t.pieces[i][0], t.pieces[i][1], '', true));
        }
      }
      for (final cid in _underOf(topicId)) {
        final s = _subj(cid.split('.').first);
        if (s == null) continue;
        for (final t in s.topics) {
          if (t.id != cid) continue;
          for (var i = 0; i < t.cards.length; i++) {
            final id = '$cid#$i';
            if (store.studyHid.contains(id)) continue;
            final c = t.cards[i];
            out.add(_Item(id, cid, c[0], c[1], c[2], true));
          }
        }
      }
    } else {
      final s = _subj(topicId.split('.').first);
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

/// Tekrar listesinde mi? Kendi kartların her zaman listededir.
bool _inRev(_Item i) => !i.builtin || store.studyInRev(i.id);

List<_Item> _revOf(StudySubjectDef s) =>
    _itemsOfSubject(s).where(_inRev).toList();

int _dueCount(List<_Item> l) => l.where((i) => store.studyIsDue(i.id)).length;

String _groupName(String g) => g == 'dil' ? tx('Yabancı dil') : tx('LGS');

// ---------------------------------------------------------------
// Ana sayfa: sekmeler ve dersler
// ---------------------------------------------------------------
class StudyPage extends StatefulWidget {
  const StudyPage({super.key});

  @override
  State<StudyPage> createState() => _StudyPageState();
}

class _StudyPageState extends State<StudyPage> {
  bool _asking = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAsk());
  }

  String get _tab => store.studyTab == 'dil' ? 'dil' : 'lgs';

  Future<void> _maybeAsk() async {
    if (!mounted || _asking) return;
    final g = _tab;
    if (store.studyAsked.contains(g)) return;
    _asking = true;
    final yes = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        title: Text(tx('{0} paketini yükleyelim mi?', [_groupName(g)])),
        content: Text(tx(
            'Konu özetleri ve kartlar yüklenir. İstediğin zaman dersleri silebilir ya da paketi yeniden yükleyebilirsin. Kendi kartların, notların ve ses kayıtların silinmez.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tx('Şimdi değil'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tx('Yükle'))),
        ],
      ),
    );
    _asking = false;
    store.studyAsk(g);
    if (yes == true) {
      store.studyInstall(
          studySubjects.where((s) => s.group == g).map((s) => s.id));
    }
  }

  void _setTab(String t) {
    store.setStudyTab(t);
    WidgetsBinding.instance.addPostFrameCallback((_) => _maybeAsk());
  }

  Future<void> _deletePackage() async {
    final g = _tab;
    final ok = await confirmDialog(
        context,
        tx('{0} paketi silinsin mi?', [_groupName(g)]),
        tx('Hazır dersler kaldırılır. Kendi kartların, notların ve ses kayıtların silinmez. İstediğin zaman yeniden yükleyebilirsin.'),
        okLabel: tx('Sil'));
    if (ok) {
      store.studyUninstall(
          studySubjects.where((s) => s.group == g).map((s) => s.id));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        final tab = _tab;
        final all = studySubjects.where((s) => s.group == tab).toList();
        final list = all.where((s) => store.studyPk.contains(s.id)).toList();
        final missing = all.where((s) => !store.studyPk.contains(s.id)).toList();
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            title: Text(tx('Ders çalışma')),
            actions: [
              PopupMenuButton<String>(
                onSelected: (v) {
                  if (v == 'del') _deletePackage();
                  if (v == 'inst') {
                    store.studyInstall(all.map((s) => s.id));
                  }
                },
                itemBuilder: (_) => [
                  if (missing.isNotEmpty)
                    PopupMenuItem(
                        value: 'inst',
                        child: Text(tx('{0} paketini yükle', [_groupName(tab)]))),
                  if (list.isNotEmpty)
                    PopupMenuItem(
                        value: 'del',
                        child: Text(tx('{0} paketini sil', [_groupName(tab)]))),
                ],
              ),
            ],
          ),
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
                onSelectionChanged: (s) => _setTab(s.first),
              ),
              const SizedBox(height: 10),
              _planCard(context, p),
              const SizedBox(height: 10),
              for (final s in list) _subjectCard(context, p, s),
              if (missing.isNotEmpty) ...[
                const SizedBox(height: 6),
                if (list.isEmpty)
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 12),
                    child: Text(
                        tx('{0} paketi yüklü değil.', [_groupName(tab)]),
                        textAlign: TextAlign.center,
                        style: TextStyle(color: p.soft)),
                  ),
                for (final s in missing)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: OutlinedButton.icon(
                      onPressed: () => store.studyInstall([s.id]),
                      icon: const Icon(Icons.download_rounded, size: 18),
                      label: Text(tx('{0} dersini yükle', [s.name])),
                    ),
                  ),
                if (missing.length > 1)
                  FilledButton.icon(
                    onPressed: () => store.studyInstall(all.map((s) => s.id)),
                    icon: const Icon(Icons.download_done_rounded),
                    label: Text(tx('{0} paketini yükle', [_groupName(tab)])),
                  ),
              ],
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

  Widget _planCard(BuildContext context, Pal p) {
    final n = store.studyPlan.length;
    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: () => Navigator.of(context).push(slideFromRight(const _PlanPage())),
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
                child: Icon(Icons.calendar_month_rounded, color: p.accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(tx('Haftalık çalışma programı'),
                        style: TextStyle(
                            fontSize: 16,
                            fontWeight: FontWeight.w600,
                            color: p.ink)),
                    const SizedBox(height: 2),
                    Text(tx('{0} ders saati', ['$n']),
                        style: TextStyle(color: p.soft, fontSize: 12.5)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
          ),
        ),
      ),
    );
  }

  Widget _subjectCard(BuildContext context, Pal p, StudySubjectDef s) {
    final rev = _revOf(s);
    final due = _dueCount(rev);
    final topics = _topicsOf(s).length;
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
            padding: const EdgeInsets.fromLTRB(14, 14, 4, 14),
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
                          tx('{0} konu • {1} tekrar bekliyor',
                              ['$topics', '$due']),
                          style: TextStyle(color: p.soft, fontSize: 12.5)),
                    ],
                  ),
                ),
                PopupMenuButton<String>(
                  onSelected: (v) async {
                    final ok = await confirmDialog(
                        context,
                        tx('{0} dersi silinsin mi?', [s.name]),
                        tx('Hazır konular kaldırılır. Kendi kartların, notların ve ses kayıtların silinmez. İstediğin zaman yeniden yükleyebilirsin.'),
                        okLabel: tx('Sil'));
                    if (ok) store.studyUninstall([s.id]);
                  },
                  itemBuilder: (_) => [
                    PopupMenuItem(value: 'del', child: Text(tx('Dersi sil'))),
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Ders: iki başlık (Ders çalış / Tekrar et)
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
        final topics = _topicsOf(s).length;
        final rev = _revOf(s);
        final due = _dueCount(rev);
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(title: Text(s.name, maxLines: 1)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              _big(context, p, Icons.auto_stories_rounded, tx('Ders çalış'),
                  tx('{0} konu', ['$topics']),
                  () => Navigator.of(context)
                      .push(slideFromRight(_TopicListPage(sid)))),
              const SizedBox(height: 12),
              _big(context, p, Icons.replay_rounded, tx('Tekrar et'),
                  tx('{0} kart • {1} tekrar bekliyor', ['${rev.length}', '$due']),
                  () => Navigator.of(context)
                      .push(slideFromRight(_RevPage(sid)))),
            ],
          ),
        );
      },
    );
  }

  Widget _big(BuildContext context, Pal p, IconData icon, String title,
      String sub, VoidCallback onTap) {
    return Material(
      color: p.card,
      borderRadius: BorderRadius.circular(18),
      child: InkWell(
        borderRadius: BorderRadius.circular(18),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(18),
            border: Border.all(color: p.line),
          ),
          child: Row(
            children: [
              CircleAvatar(
                radius: 26,
                backgroundColor: p.accent.withOpacity(0.15),
                child: Icon(icon, color: p.accent, size: 28),
              ),
              const SizedBox(width: 16),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(title,
                        style: TextStyle(
                            fontSize: 19,
                            fontWeight: FontWeight.w700,
                            color: p.ink)),
                    const SizedBox(height: 3),
                    Text(sub, style: TextStyle(color: p.soft, fontSize: 13)),
                  ],
                ),
              ),
              const Icon(Icons.chevron_right_rounded),
            ],
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
// Ders çalış: konu başlıkları
// ---------------------------------------------------------------
class _TopicListPage extends StatelessWidget {
  final String sid;
  const _TopicListPage(this.sid);

  @override
  Widget build(BuildContext context) {
    final s = _subj(sid)!;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        final topics = _topicsOf(s);
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(title: Text(tx('Ders çalış'), maxLines: 1)),
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
              for (var i = 0; i < topics.length; i++) ...[
                if (topics[i].grp.isNotEmpty &&
                    (i == 0 || topics[i - 1].grp != topics[i].grp))
                  Padding(
                    padding: EdgeInsets.fromLTRB(2, i == 0 ? 2 : 14, 2, 8),
                    child: Text(tx(topics[i].grp),
                        style: TextStyle(
                            fontSize: 21,
                            fontWeight: FontWeight.w800,
                            color: p.ink)),
                  ),
                _topicTile(context, p, topics[i]),
              ],
            ],
          ),
        );
      },
    );
  }

  Widget _topicTile(BuildContext context, Pal p, _TopicRef t) {
    final items = _itemsOf(t.id);
    final inRev = items.where(_inRev).length;
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
                          tx('{0} bilgi • {1} tekrar listesinde',
                              ['${items.length}', '$inRev']),
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

// ---------------------------------------------------------------
// Konu: bilgi parçaları + notlar + ses kayıtları
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

  Future<void> _note(BuildContext context, StudyNote? n) async {
    final t = await showDialog<String>(
        context: context, builder: (_) => _NoteDialog(text: n?.text ?? ''));
    if (t == null || t.trim().isEmpty) return;
    if (n == null) {
      store.addStudyNote(topicId, t);
    } else {
      store.editStudyNote(n.id, t);
    }
  }

  Future<void> _record(BuildContext context) async {
    final f = await recordVoice(context);
    if (f != null) store.addStudyRec(topicId, f);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        final items = _itemsOf(topicId);
        final notes = store.studyNotes.where((n) => n.topic == topicId).toList();
        final recs = store.studyRecs.where((r) => r.topic == topicId).toList();
        final hidIds = [topicId, ..._underOf(topicId)];
        final hasHidden = store.studyHid
            .any((h) => hidIds.any((t) => h.startsWith('$t#')));
        final notInRev =
            items.where((i) => i.builtin && !store.studyInRev(i.id)).toList();
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            title: Text(name, maxLines: 1),
            actions: [
              if (hasHidden)
                IconButton(
                  tooltip: tx('Silinen hazır kartları geri getir'),
                  icon: const Icon(Icons.restore_rounded),
                  onPressed: () {
                    for (final t in hidIds) {
                      store.restoreStudyHidden(t);
                    }
                  },
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
              if (notInRev.length > 1)
                Align(
                  alignment: Alignment.centerRight,
                  child: TextButton.icon(
                    onPressed: () =>
                        store.studyAddRev(notInRev.map((i) => i.id)),
                    icon: const Icon(Icons.playlist_add_rounded, size: 18),
                    label: Text(tx('Hepsini tekrar listesine ekle')),
                  ),
                ),
              if (items.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(tx('Henüz bilgi yok. Kart ekle düğmesiyle başla.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.soft)),
                ),
              for (final i in items) _piece(context, p, i),
              const SizedBox(height: 14),
              _header(p, tx('Notlar'), Icons.sticky_note_2_outlined,
                  () => _note(context, null)),
              if (notes.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(tx('Bu konuya henüz not yazılmadı.'),
                      style: TextStyle(color: p.soft, fontSize: 13)),
                ),
              for (final n in notes)
                Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: p.line),
                  ),
                  child: ListTile(
                    onTap: () => _note(context, n),
                    title: Text(n.text, style: TextStyle(color: p.ink)),
                    subtitle: Text(dtLabel(n.ms),
                        style: TextStyle(color: p.soft, fontSize: 11.5)),
                    trailing: IconButton(
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () async {
                        final ok = await confirmDialog(
                            context, tx('Not silinsin mi?'), n.text);
                        if (ok) store.deleteStudyNote(n.id);
                      },
                    ),
                  ),
                ),
              const SizedBox(height: 10),
              _header(p, tx('Ses kayıtları'), Icons.mic_none_rounded,
                  () => _record(context)),
              if (recs.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 6),
                  child: Text(tx('Bu konuya henüz ses kaydı yok.'),
                      style: TextStyle(color: p.soft, fontSize: 13)),
                ),
              for (final r in recs)
                VoiceTile(
                  name: r.file,
                  onDelete: () async {
                    final ok = await confirmDialog(context,
                        tx('Ses kaydı silinsin mi?'), tx('Kayıt kalıcı olarak silinir.'));
                    if (ok) store.deleteStudyRec(r.id);
                  },
                ),
              if (recs.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      tx('Ses kayıtları yedek dosyasına girmez; yalnız bu telefonda durur.'),
                      style: TextStyle(color: p.soft, fontSize: 11.5)),
                ),
            ],
          ),
        );
      },
    );
  }

  Widget _header(Pal p, String text, IconData icon, VoidCallback onAdd) => Row(
        children: [
          Icon(icon, size: 20, color: p.accent),
          const SizedBox(width: 8),
          Expanded(
              child: Text(text,
                  style: TextStyle(
                      fontSize: 20, fontWeight: FontWeight.w800, color: p.ink))),
          TextButton.icon(
              onPressed: onAdd,
              icon: Icon(
                  icon == Icons.mic_none_rounded
                      ? Icons.fiber_manual_record_rounded
                      : Icons.add_rounded,
                  size: 18),
              label: Text(icon == Icons.mic_none_rounded
                  ? tx('Kaydet')
                  : tx('Not ekle'))),
        ],
      );

  Widget _piece(BuildContext context, Pal p, _Item i) {
    final inRev = _inRev(i);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.fromLTRB(14, 12, 6, 6),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.only(top: 2, right: 6),
                  child: Text(i.front,
                      style: TextStyle(
                          color: p.ink,
                          fontWeight: FontWeight.w700,
                          fontSize: 15)),
                ),
              ),
              PopupMenuButton<String>(
                padding: EdgeInsets.zero,
                onSelected: (v) async {
                  if (v == 'edit') {
                    _edit(context, i);
                  } else {
                    final ok = await confirmDialog(
                        context, tx('Kart silinsin mi?'), i.front);
                    if (ok) store.deleteStudyCard(i.id);
                  }
                },
                itemBuilder: (_) => [
                  PopupMenuItem(value: 'edit', child: Text(tx('Düzenle'))),
                  PopupMenuItem(value: 'del', child: Text(tx('Sil'))),
                ],
              ),
            ],
          ),
          if (i.exp.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 2),
              child: i.exp.contains('||')
                  ? _Reveal(
                      key: ValueKey('rv_${i.id}'),
                      text: i.exp.split('||').first.trim(),
                      answer: i.exp.substring(i.exp.indexOf('||') + 2).trim())
                  : Text(i.exp,
                      style: TextStyle(color: p.ink, fontSize: 14, height: 1.4)),
            ),
          if (i.ex.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 8, top: 4),
              child: Text(i.ex,
                  style: TextStyle(
                      color: p.soft,
                      fontSize: 13,
                      fontStyle: FontStyle.italic,
                      height: 1.4)),
            ),
          Align(
            alignment: Alignment.centerRight,
            child: i.builtin
                ? TextButton.icon(
                    onPressed: () => store.studyToggleRev(i.id),
                    icon: Icon(
                        inRev
                            ? Icons.check_circle_rounded
                            : Icons.replay_rounded,
                        size: 18),
                    label: Text(inRev ? tx('Tekrar listesinde') : tx('Tekrar et')),
                  )
                : Padding(
                    padding: const EdgeInsets.only(right: 8, bottom: 6),
                    child: Text(tx('Kendi kartın • tekrar listesinde'),
                        style: TextStyle(color: p.soft, fontSize: 11.5)),
                  ),
          ),
        ],
      ),
    );
  }
}

class _NoteDialog extends StatefulWidget {
  final String text;
  const _NoteDialog({required this.text});

  @override
  State<_NoteDialog> createState() => _NoteDialogState();
}

class _NoteDialogState extends State<_NoteDialog> {
  late final TextEditingController _c = TextEditingController(text: widget.text);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.text.isEmpty ? tx('Yeni not') : tx('Notu düzenle')),
      content: TextField(
        controller: _c,
        autofocus: true,
        minLines: 3,
        maxLines: 8,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(labelText: tx('Not')),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(tx('Vazgeç'))),
        FilledButton(
            onPressed: () => Navigator.pop(context, _c.text),
            child: Text(tx('Kaydet'))),
      ],
    );
  }
}

// ---------------------------------------------------------------
// Tekrar et: tekrar listesindeki kartlar
// ---------------------------------------------------------------
class _RevPage extends StatelessWidget {
  final String sid;
  const _RevPage(this.sid);

  String _status(_Item i) {
    final b = store.studyBox(i.id);
    if (b == 0) return tx('Yeni');
    return store.studyIsDue(i.id) ? tx('Tekrar zamanı') : tx('Öğrenildi');
  }

  @override
  Widget build(BuildContext context) {
    final s = _subj(sid)!;
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        final items = _revOf(s);
        final due = _dueCount(items);
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(title: Text(tx('Tekrar et'), maxLines: 1)),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              FilledButton.icon(
                onPressed:
                    items.isEmpty ? null : () => _startReview(context, s.name, items),
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
                  child: Text(
                      tx('Tekrar listesi boş. Ders çalış bölümünde bir bilginin yanındaki Tekrar et düğmesine bas.'),
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
                    title: Text(i.front,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: p.ink, fontWeight: FontWeight.w600)),
                    subtitle: Text(_status(i),
                        style: TextStyle(color: p.soft, fontSize: 12.5)),
                    trailing: IconButton(
                      tooltip: tx('Listeden çıkar'),
                      icon: const Icon(Icons.close_rounded),
                      onPressed: () async {
                        if (i.builtin) {
                          store.studyRemoveRev(i.id);
                        } else {
                          final ok = await confirmDialog(context,
                              tx('Kart silinsin mi?'), i.front);
                          if (ok) store.deleteStudyCard(i.id);
                        }
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

// ---------------------------------------------------------------
// Haftalık çalışma programı
// ---------------------------------------------------------------
String _hm2(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

Future<TimeOfDay?> _pick(BuildContext context, int h, int m) => showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h, minute: m),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

class _PlanPage extends StatelessWidget {
  const _PlanPage();

  Future<void> _edit(BuildContext context, StudyPlan? row, {int day = 1}) async {
    final r = await showDialog<StudyPlan>(
        context: context, builder: (_) => _PlanDialog(row: row, day: day));
    if (r == null) return;
    if (row == null) {
      final n = store.addStudyPlan(
          r.day, r.subj, r.sh, r.sm, r.eh, r.em, r.remind);
      await Notifier.syncPlan(n);
    } else {
      store.updateStudyPlan(row,
          day: r.day,
          subj: r.subj,
          sh: r.sh,
          sm: r.sm,
          eh: r.eh,
          em: r.em,
          remind: r.remind);
      await Notifier.syncPlan(row);
    }
    if (r.remind) await permissionMessage();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(title: Text(tx('Haftalık çalışma programı'))),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add_rounded),
            label: Text(tx('Ders ekle')),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            children: [
              for (var d = 1; d <= 7; d++) ..._day(context, p, d),
              const SizedBox(height: 8),
              Text(
                  tx('Hatırlatma isteğe bağlıdır; açık olan derslerin başlangıç saatinde bildirim gelir.'),
                  style: TextStyle(color: p.soft, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  List<Widget> _day(BuildContext context, Pal p, int d) {
    final rows = store.studyPlan.where((r) => r.day == d).toList()
      ..sort((a, b) => (a.sh * 60 + a.sm).compareTo(b.sh * 60 + b.sm));
    return [
      Padding(
        padding: const EdgeInsets.only(top: 16, bottom: 4),
        child: Row(
          children: [
            Expanded(
              child: Text(wdName(d),
                  style: TextStyle(
                      color: p.ink,
                      fontWeight: FontWeight.w800,
                      fontSize: 22)),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: tx('Ders ekle'),
              icon: const Icon(Icons.add_circle_outline_rounded),
              onPressed: () => _edit(context, null, day: d),
            ),
          ],
        ),
      ),
      if (rows.isEmpty)
        Text('—', style: TextStyle(color: p.soft)),
      for (final r in rows)
        Container(
          margin: const EdgeInsets.only(bottom: 6),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(12),
            border: Border.all(color: p.line),
          ),
          child: ListTile(
            dense: true,
            onTap: () => _edit(context, r),
            title: Text(r.subj,
                style: TextStyle(color: p.ink, fontWeight: FontWeight.w600)),
            subtitle: Text('${_hm2(r.sh, r.sm)}–${_hm2(r.eh, r.em)}',
                style: TextStyle(color: p.soft)),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.notifications_none_rounded,
                    size: 18, color: p.soft),
                Switch(
                  value: r.remind,
                  onChanged: (v) async {
                    store.updateStudyPlan(r, remind: v);
                    await Notifier.syncPlan(r);
                    if (v) await permissionMessage();
                  },
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  icon: const Icon(Icons.delete_outline_rounded),
                  onPressed: () async {
                    final ok = await confirmDialog(context,
                        tx('Satır silinsin mi?'), '${wdName(r.day)} ${r.subj}');
                    if (ok) {
                      await Notifier.cancelPlan(r);
                      store.deleteStudyPlan(r.id);
                    }
                  },
                ),
              ],
            ),
          ),
        ),
    ];
  }
}

class _PlanDialog extends StatefulWidget {
  final StudyPlan? row;
  final int day;
  const _PlanDialog({required this.row, required this.day});

  @override
  State<_PlanDialog> createState() => _PlanDialogState();
}

class _PlanDialogState extends State<_PlanDialog> {
  late int _day = widget.row?.day ?? widget.day;
  late final TextEditingController _s =
      TextEditingController(text: widget.row?.subj ?? '');
  late int _sh = widget.row?.sh ?? 18;
  late int _sm = widget.row?.sm ?? 0;
  late int _eh = widget.row?.eh ?? 18;
  late int _em = widget.row?.em ?? 45;
  late bool _rem = widget.row?.remind ?? false;

  @override
  void dispose() {
    _s.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return AlertDialog(
      title: Text(widget.row == null ? tx('Ders ekle') : tx('Dersi düzenle')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Wrap(
              spacing: 6,
              children: [
                for (var d = 1; d <= 7; d++)
                  ChoiceChip(
                    label: Text(wdName(d)),
                    selected: _day == d,
                    onSelected: (_) => setState(() => _day = d),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _s,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tx('Ders')),
            ),
            const SizedBox(height: 6),
            Wrap(
              spacing: 6,
              children: [
                for (final s in studySubjects)
                  ActionChip(
                    label: Text(s.name, style: const TextStyle(fontSize: 12)),
                    onPressed: () => setState(() => _s.text = s.name),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await _pick(context, _sh, _sm);
                      if (t != null) {
                        setState(() {
                          _sh = t.hour;
                          _sm = t.minute;
                        });
                      }
                    },
                    child: Text(_hm2(_sh, _sm)),
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 8),
                  child: Text('–', style: TextStyle(color: p.soft)),
                ),
                Expanded(
                  child: OutlinedButton(
                    onPressed: () async {
                      final t = await _pick(context, _eh, _em);
                      if (t != null) {
                        setState(() {
                          _eh = t.hour;
                          _em = t.minute;
                        });
                      }
                    },
                    child: Text(_hm2(_eh, _em)),
                  ),
                ),
              ],
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tx('Başlangıçta hatırlat')),
              value: _rem,
              onChanged: (v) => setState(() => _rem = v),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(tx('Vazgeç'))),
        FilledButton(
          onPressed: () {
            if (_s.text.trim().isEmpty) return;
            Navigator.pop(
                context,
                StudyPlan('', _day, _s.text.trim(), _sh, _sm, _eh, _em, _rem, 0));
          },
          child: Text(tx('Kaydet')),
        ),
      ],
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

  /// Konu özeti parçası ve soru-cevap değil: içerik baştan görünür
  bool _plain(_Item c) => _isSum(c.topic) && !c.exp.contains('||');

  void _dontKnow() {
    store.studyForget(_q.first.id);
    if (_plain(_q.first)) {
      _next(); // içerik zaten görünüyordu; kart sona gider
    } else {
      setState(() => _shown = true);
    }
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
                          fontSize: _isSum(c.topic) ? 21 : 26,
                          fontWeight: FontWeight.w700,
                          color: p.ink)),
                  if (_plain(c)) ...[
                    const SizedBox(height: 18),
                    Text(c.exp,
                        style: TextStyle(fontSize: 17, color: p.ink, height: 1.5)),
                  ] else if (_isSum(c.topic)) ...[
                    const SizedBox(height: 18),
                    Text(c.exp.split('||').first.trim(),
                        style: TextStyle(fontSize: 18, color: p.ink, height: 1.5)),
                    if (_shown) ...[
                      const SizedBox(height: 18),
                      Container(
                        width: double.infinity,
                        padding: const EdgeInsets.all(12),
                        decoration: BoxDecoration(
                          color: p.accent.withOpacity(0.12),
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: Text(
                            c.exp.substring(c.exp.indexOf('||') + 2).trim(),
                            style: TextStyle(
                                fontSize: 17,
                                fontWeight: FontWeight.w600,
                                color: p.ink,
                                height: 1.45)),
                      ),
                    ],
                  ] else if (_shown) ...[
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


/// Soru + dokununca açılan cevap ("soru || cevap" biçimindeki bilgiler)
class _Reveal extends StatefulWidget {
  final String text;
  final String answer;
  const _Reveal({super.key, required this.text, required this.answer});

  @override
  State<_Reveal> createState() => _RevealState();
}

class _RevealState extends State<_Reveal> {
  bool _open = false;

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(widget.text,
            style: TextStyle(color: p.ink, fontSize: 14, height: 1.4)),
        const SizedBox(height: 4),
        if (_open)
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: p.accent.withOpacity(0.12),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(widget.answer,
                style: TextStyle(
                    color: p.ink,
                    fontSize: 14,
                    height: 1.4,
                    fontWeight: FontWeight.w600)),
          )
        else
          TextButton(
            style: TextButton.styleFrom(
                padding: EdgeInsets.zero,
                minimumSize: const Size(0, 30),
                alignment: Alignment.centerLeft),
            onPressed: () => setState(() => _open = true),
            child: Text(tx('Cevabı göster')),
          ),
      ],
    );
  }
}
