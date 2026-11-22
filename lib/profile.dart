import 'dart:async';
import 'package:flutter/material.dart';
import 'data.dart';
import 'notify.dart';
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// KİŞİSEL PROFİL, GİRİŞ HATIRLATMASI, SPOR HATIRLATMASI
//  Veriler yalnız telefonda durur (store.prof). Öneriler kural tabanlıdır.
//  - Rutin giriş hatırlatması: son veri girişinden beri süre geçtiyse (uyanık saatlerde)
//    ana ekranda uyarı satırı + telefon bildirimi. Mesai saatinde süre 2 katıdır.
//  - Spor hatırlatması: haftalık hedef tutmayacak gibiyse akşam bildirimi.
// ---------------------------------------------------------------
const _erId = 790001; // 790001..790006
const _spId = 790011; // 790011..790017

int _wake() => store.pInt('wake', 480);
int _sleepAt() => store.pInt('sleep', 1320);

/// Verilen an uyanık saatler içinde mi?
bool inActive(DateTime t) {
  final m = t.hour * 60 + t.minute;
  final w = _wake(), s = _sleepAt();
  return w <= s ? (m >= w && m < s) : (m >= w || m < s);
}

List<int> _workDays() {
  final r = store.prof['wkDays'];
  if (r is List && r.isNotEmpty) return r.map((e) => (e as num).toInt()).toList();
  return [1, 2, 3, 4, 5];
}

bool inWork(DateTime t) {
  if (!store.pBool('wkOn', false)) return false;
  if (!_workDays().contains(t.weekday)) return false;
  final m = t.hour * 60 + t.minute;
  return m >= store.pInt('wkS', 480) && m < store.pInt('wkE', 1020);
}

Duration entryInterval(DateTime t) =>
    Duration(minutes: store.pInt('erHrs', 1) * 60 * (inWork(t) ? 2 : 1));

/// Uyanık değilse bir sonraki uyanma saatine taşır
DateTime nextActive(DateTime t) {
  if (inActive(t)) return t;
  var c = DateTime(t.year, t.month, t.day, _wake() ~/ 60, _wake() % 60);
  if (!c.isAfter(t)) c = DateTime(t.year, t.month, t.day + 1, _wake() ~/ 60, _wake() % 60);
  return c;
}

DateTime entryDue() {
  final last = DateTime.fromMillisecondsSinceEpoch(
      store.lastEntryMs == 0 ? DateTime.now().millisecondsSinceEpoch : store.lastEntryMs);
  return nextActive(last.add(entryInterval(last)));
}

/// Ana ekran uyarı satırı için: giriş zamanı geldi mi?
bool entryOverdue([DateTime? now]) {
  final n = now ?? DateTime.now();
  if (!store.pBool('erOn', true) || store.lastEntryMs == 0) return false;
  return inActive(n) && !n.isBefore(entryDue());
}

bool _isSport(String name) {
  final n = name.toLowerCase();
  return n.contains('spor') || n.contains('egzersiz') || n.contains('antrenman');
}

int sportDoneThisWeek([DateTime? now]) {
  final n = now ?? DateTime.now();
  final mon = DateTime(n.year, n.month, n.day - (n.weekday - 1));
  final ids = <String>{
    for (final c in store.cats)
      for (final s in c.subs)
        if (_isSport(s.name)) s.id
  };
  final days = <String>{
    for (final e in store.entries)
      if (ids.contains(e.sub) && e.value > 0 && e.date.compareTo(dKey(mon)) >= 0) e.date
  };
  return days.length;
}

/// Giriş ve spor bildirimlerini yeniden planlar (giriş yapılınca, açılışta, ayar değişince)
Future<void> entryRemSync() async {
  try {
    for (var i = 0; i < 6; i++) {
      await Notifier.cancelOnce(_erId + i);
    }
    for (var i = 0; i < 7; i++) {
      await Notifier.cancelOnce(_spId + i);
    }
    final now = DateTime.now();
    if (store.pBool('erOn', true)) {
      if (store.lastEntryMs == 0) store.markEntryNow();
      var t = DateTime.fromMillisecondsSinceEpoch(store.lastEntryMs);
      for (var i = 0; i < 6; i++) {
        var due = nextActive(t.add(entryInterval(t)));
        if (due.isBefore(now)) due = nextActive(now.add(const Duration(minutes: 1)));
        await Notifier.scheduleOnce(
            _erId + i,
            tx('Bir süredir rutin girişi yapmadın. Birkaç dakikanı ayırır mısın?'),
            due,
            title: tx('Rutin girişi yok'));
        t = due;
      }
    }
    final goal = store.pInt('sport', 0);
    if (goal > 0 && store.pBool('spOn', true)) {
      final need = goal - sportDoneThisWeek(now);
      if (need > 0) {
        final at = (_sleepAt() - 60).clamp(0, 19 * 60).toInt();
        // bugünden pazara kadar (hafta bitince yeni hafta için yeniden planlanır)
        for (var k = 0; k <= 7 - now.weekday; k++) {
          final d = DateTime(now.year, now.month, now.day + k);
          final remaining = 8 - d.weekday; // o gün dahil haftada kalan gün
          if (need < remaining - 1) continue; // henüz vakit var
          final when = DateTime(d.year, d.month, d.day, at ~/ 60, at % 60);
          if (!when.isAfter(now)) continue;
          await Notifier.scheduleOnce(_spId + k,
              tx('Bu hafta spor hedefine {0} gün kaldı.', [need]), when,
              title: tx('Spor günü'));
        }
      }
    }
  } catch (_) {}
}

// ---------------------------------------------------------------
// ANA EKRANDA UYARI SATIRI
// ---------------------------------------------------------------
class EntryLine extends StatefulWidget {
  final VoidCallback onTap;
  const EntryLine({super.key, required this.onTap});

  @override
  State<EntryLine> createState() => _EntryLineState();
}

class _EntryLineState extends State<EntryLine> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(minutes: 1), (_) {
      if (mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!entryOverdue()) return const SizedBox.shrink();
        final mins = DateTime.now()
            .difference(DateTime.fromMillisecondsSinceEpoch(store.lastEntryMs))
            .inMinutes;
        final h = mins ~/ 60;
        final txt = h >= 1
            ? tx('Son {0} saattir rutin girişi yok. Dokun, gir.', [h])
            : tx('Bir süredir rutin girişi yok. Dokun, gir.');
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.accent.withOpacity(0.7)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: widget.onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.edit_notifications_outlined,
                      size: 18, color: p.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(txt,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13, color: p.ink, fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------
// PROFİL SAYFASI
// ---------------------------------------------------------------
String _hm(int m) =>
    '${(m ~/ 60).toString().padLeft(2, '0')}:${(m % 60).toString().padLeft(2, '0')}';

class _Sug {
  final String name, unit;
  final double? goal;
  final bool isMax, summable;
  final Set<int> days;
  final int rh, rm;
  final String why;
  _Sug(this.name, this.unit, this.goal, this.why,
      {this.isMax = false,
      this.summable = true,
      Set<int>? days,
      this.rh = -1,
      this.rm = 0})
      : days = days ?? {1, 2, 3, 4, 5, 6, 7};
}

const _sportDays = <int, Set<int>>{
  1: {3},
  2: {2, 5},
  3: {1, 3, 5},
  4: {1, 2, 4, 6},
  5: {1, 2, 3, 4, 5},
  6: {1, 2, 3, 4, 5, 6},
  7: {1, 2, 3, 4, 5, 6, 7},
};

List<_Sug> _suggestions() {
  final out = <_Sug>[];
  final w = store.pNum('weight');
  final water = w == null ? 2.0 : ((w * 0.033) * 10).round() / 10;
  out.add(_Sug(tx('Su'), 'L', water, tx('Kilona göre günlük su hedefi.')));
  final sport = store.pInt('sport', 0);
  if (sport > 0) {
    var at = store.pBool('wkOn', false) ? store.pInt('wkE', 1020) + 30 : _sleepAt() - 180;
    at = at.clamp(0, 23 * 60 + 30).toInt();
    out.add(_Sug(tx('Spor'), tx('dk'), 30, tx('Haftada {0} gün: seçilen günlere yayıldı.', [sport]),
        days: _sportDays[sport], rh: at ~/ 60, rm: at % 60));
  }
  final dur = ((_wake() + 1440 - _sleepAt()) % 1440) / 60;
  out.add(_Sug(tx('Uyku'), tx('saat'), (dur * 2).round() / 2,
      tx('Uyku ve uyanma saatine göre hedef.'),
      rh: ((_sleepAt() - 30) % 1440) ~/ 60, rm: ((_sleepAt() - 30) % 1440) % 60));
  if (w != null) {
    final g = store.pNum('goalW');
    out.add(_Sug(tx('Kilo'), 'kg', g, tx('Haftada bir tartıl. Hedef kilon varsa hedef olarak girilir.'),
        isMax: g != null && g < w, summable: false, days: {1}));
  }
  return out;
}

bool _hasSub(String name) => store.cats.any((c) => c.subs
    .any((s) => s.name.toLowerCase() == name.toLowerCase()));

class ProfilePage extends StatefulWidget {
  const ProfilePage({super.key});

  @override
  State<ProfilePage> createState() => _ProfilePageState();
}

class _ProfilePageState extends State<ProfilePage> {
  void _set(String k, dynamic v) {
    store.setProf(k, v);
    entryRemSync();
  }

  Future<String?> _ask(String title, String initial, {String? suffix}) async {
    final c = TextEditingController(text: initial);
    final r = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          autofocus: true,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: InputDecoration(suffixText: suffix),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: Text(tx('Vazgeç'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, c.text.trim()),
              child: Text(tx('Kaydet'))),
        ],
      ),
    );
    c.dispose();
    return r;
  }

  Future<void> _num(String key, String title, {String? suffix, bool year = false}) async {
    final cur = store.pNum(key);
    final r = await _ask(title, cur == null ? '' : (cur == cur.roundToDouble() ? cur.toInt().toString() : cur.toString()),
        suffix: suffix);
    if (r == null) return;
    final v = double.tryParse(r.replaceAll(',', '.'));
    if (r.isEmpty) {
      _set(key, null);
    } else if (v != null && v > 0) {
      _set(key, year ? v.toInt() : v);
    }
  }

  Future<void> _time(String key, int def) async {
    final cur = store.pInt(key, def);
    final t = await showTimePicker(
        context: context, initialTime: TimeOfDay(hour: cur ~/ 60, minute: cur % 60));
    if (t != null) _set(key, t.hour * 60 + t.minute);
  }

  Widget _row(Pal p, IconData i, String title, String value, VoidCallback onTap) =>
      ListTile(
        contentPadding: EdgeInsets.zero,
        leading: Icon(i),
        title: Text(title),
        trailing: Text(value, style: TextStyle(color: p.soft, fontSize: 15)),
        onTap: onTap,
      );

  Widget _head(Pal p, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 18, 4, 6),
        child: Text(t,
            style: TextStyle(color: p.soft, fontWeight: FontWeight.w700, fontSize: 13)),
      );

  Widget _card(Pal p, List<Widget> kids) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: p.line),
        ),
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: kids),
      );

  void _add(_Sug s) {
    final c = store.addCategory(tx('Sağlık'));
    final sub = store.addSub(
        c.id,
        SubDraft(
            name: s.name,
            unit: s.unit,
            routine: true,
            goal: s.goal,
            isMax: s.isMax,
            summable: s.summable,
            days: s.days));
    if (s.rh >= 0) {
      store.setRoutineOptions(sub.id, days: s.days, rh: s.rh, rm: s.rm);
      Notifier.syncSub(sub);
    }
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(tx('"{0}" rutini eklendi.', [s.name]))));
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final sex = store.pStr('sex');
        final h = store.pNum('height');
        final w = store.pNum('weight');
        String bmi = '';
        if (h != null && w != null && h > 80) {
          final b = w / ((h / 100) * (h / 100));
          final lbl = b < 18.5
              ? tx('düşük')
              : b < 25
                  ? tx('normal')
                  : b < 30
                      ? tx('fazla')
                      : tx('yüksek');
          bmi = '${b.toStringAsFixed(1)} ($lbl)';
        }
        final wkOn = store.pBool('wkOn', false);
        final days = _workDays();
        final names = ['', tx('Pzt'), tx('Sal'), tx('Çar'), tx('Per'), tx('Cum'), tx('Cmt'), tx('Paz')];
        String numStr(double? v) =>
            v == null ? '—' : (v == v.roundToDouble() ? '${v.toInt()}' : '$v');
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(
            backgroundColor: p.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(tx('Beni tanı')),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text(
                    tx('Bu bilgiler yalnız telefonunda durur, hiçbir yere gönderilmez. Hepsi isteğe bağlıdır; hatırlatmalar ve öneriler buna göre şekillenir.'),
                    style: TextStyle(color: p.soft, fontSize: 12.5, height: 1.35)),
              ),
              _head(p, tx('Kişisel bilgiler')),
              _card(p, [
                const SizedBox(height: 6),
                Wrap(spacing: 8, children: [
                  for (final e in [
                    ['f', tx('Kadın')],
                    ['m', tx('Erkek')],
                    ['', tx('Belirtmek istemiyorum')],
                  ])
                    ChoiceChip(
                      label: Text(e[1]),
                      selected: sex == e[0],
                      onSelected: (_) => _set('sex', e[0].isEmpty ? null : e[0]),
                    ),
                ]),
                _row(p, Icons.cake_outlined, tx('Doğum yılı'), numStr(store.pNum('birth')),
                    () => _num('birth', tx('Doğum yılı'), year: true)),
                _row(p, Icons.height_rounded, tx('Boy'), h == null ? '—' : '${numStr(h)} cm',
                    () => _num('height', tx('Boy'), suffix: 'cm')),
                _row(p, Icons.monitor_weight_outlined, tx('Kilo'), w == null ? '—' : '${numStr(w)} kg',
                    () => _num('weight', tx('Kilo'), suffix: 'kg')),
                _row(p, Icons.flag_outlined, tx('Hedef kilo'),
                    store.pNum('goalW') == null ? '—' : '${numStr(store.pNum('goalW'))} kg',
                    () => _num('goalW', tx('Hedef kilo'), suffix: 'kg')),
                if (bmi.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Text(
                        tx('Beden kitle indeksi: {0}. Genel bir göstergedir, tıbbi tavsiye değildir.', [bmi]),
                        style: TextStyle(color: p.soft, fontSize: 12.5)),
                  ),
              ]),
              _head(p, tx('Günlük düzen')),
              _card(p, [
                _row(p, Icons.wb_twilight_rounded, tx('Uyanma saati'), _hm(_wake()),
                    () => _time('wake', 480)),
                _row(p, Icons.bedtime_outlined, tx('Uyku saati'), _hm(_sleepAt()),
                    () => _time('sleep', 1320)),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.work_outline_rounded),
                  title: Text(tx('Mesaim var')),
                  value: wkOn,
                  onChanged: (v) => _set('wkOn', v),
                ),
                if (wkOn) ...[
                  _row(p, Icons.login_rounded, tx('Mesai başlangıcı'), _hm(store.pInt('wkS', 480)),
                      () => _time('wkS', 480)),
                  _row(p, Icons.logout_rounded, tx('Mesai bitişi'), _hm(store.pInt('wkE', 1020)),
                      () => _time('wkE', 1020)),
                  Wrap(spacing: 6, children: [
                    for (var d = 1; d <= 7; d++)
                      FilterChip(
                        label: Text(names[d]),
                        selected: days.contains(d),
                        onSelected: (v) {
                          final l = List<int>.of(days);
                          v ? l.add(d) : l.remove(d);
                          if (l.isNotEmpty) _set('wkDays', l..sort());
                        },
                      ),
                  ]),
                  const SizedBox(height: 8),
                ],
              ]),
              _head(p, tx('Spor')),
              _card(p, [
                const SizedBox(height: 8),
                Text(tx('Haftada kaç gün spor yapmak istiyorsun?'),
                    style: TextStyle(color: p.soft)),
                const SizedBox(height: 6),
                Wrap(spacing: 6, children: [
                  for (var d = 0; d <= 7; d++)
                    ChoiceChip(
                      label: Text(d == 0 ? tx('Yapmıyorum') : '$d'),
                      selected: store.pInt('sport', 0) == d,
                      onSelected: (_) => _set('sport', d == 0 ? null : d),
                    ),
                ]),
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tx('Hedef tutmayacaksa akşam hatırlat')),
                  subtitle: Text(tx('"Spor" adlı rutine girdiğin günler sayılır.')),
                  value: store.pBool('spOn', true),
                  onChanged: store.pInt('sport', 0) == 0 ? null : (v) => _set('spOn', v),
                ),
              ]),
              _head(p, tx('Rutin giriş hatırlatması')),
              _card(p, [
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  secondary: const Icon(Icons.edit_notifications_outlined),
                  title: Text(tx('Giriş yapılmazsa hatırlat')),
                  subtitle: Text(tx('Uyanık olduğun saatlerde, belirlenen süre veri girilmezse ana ekranda uyarı ve telefon bildirimi çıkar. Mesai saatinde süre 2 katı olur.')),
                  value: store.pBool('erOn', true),
                  onChanged: (v) => _set('erOn', v),
                ),
                if (store.pBool('erOn', true))
                  Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: Wrap(spacing: 6, crossAxisAlignment: WrapCrossAlignment.center, children: [
                      Text(tx('Süre:'), style: TextStyle(color: p.soft)),
                      for (final h in [1, 2, 3, 4])
                        ChoiceChip(
                          label: Text(tx('{0} saat', [h])),
                          selected: store.pInt('erHrs', 1) == h,
                          onSelected: (_) => _set('erHrs', h),
                        ),
                    ]),
                  ),
              ]),
              _head(p, tx('Önerilen rutinler')),
              for (final s in _suggestions())
                Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  color: p.card,
                  child: ListTile(
                    title: Text(
                        '${s.name}${s.goal == null ? '' : ' · ${numStr(s.goal)} ${s.unit}'}',
                        style: const TextStyle(fontWeight: FontWeight.w600)),
                    subtitle: Text(s.why),
                    trailing: _hasSub(s.name)
                        ? Text(tx('Ekli'), style: TextStyle(color: p.soft))
                        : FilledButton.tonal(
                            onPressed: () => _add(s), child: Text(tx('Ekle'))),
                  ),
                ),
            ],
          ),
        );
      },
    );
  }
}
