import 'package:flutter/material.dart';
import 'data.dart';
import 'notify.dart';
import 'reminders.dart';
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// EKLE EKRANI (alttan açılır)
// Akış: kategori seç -> alt kategori seç (veya "Yeni") ->
//       "Rutin olsun" anahtarı (açılırsa günlük hedef sorulur) -> veri
// Anahtar kapalıysa sadece o günün kaydı eklenir.
// ---------------------------------------------------------------
class AddSheet extends StatefulWidget {
  final String date; // kaydın ekleneceği gün (yyyy-MM-dd)
  const AddSheet({super.key, required this.date});

  @override
  State<AddSheet> createState() => _AddSheetState();
}

class _AddSheetState extends State<AddSheet> {
  String? catId;
  String? subId;
  bool routine = false;
  Set<int> days = {1, 2, 3, 4, 5, 6, 7}; // rutinin görüneceği günler
  final _value = TextEditingController();
  final _goal = TextEditingController();

  @override
  void dispose() {
    _value.dispose();
    _goal.dispose();
    super.dispose();
  }

  // Alt kategori seçilince mevcut rutin/hedef ayarı ekrana yansır
  void _pickSub(SubCat s) {
    setState(() {
      subId = s.id;
      routine = s.routine;
      days = Set<int>.from(s.days);
      _goal.text = s.goal == null ? '' : plain(s.goal!);
    });
  }

  Future<void> _addFree() async {
    final r = await showFreeRowDialog(context, date: widget.date);
    if (r == null || !mounted) return;
    final messenger = ScaffoldMessenger.of(context);
    final nav = Navigator.of(context);
    final f = store.addFree(r.date, r.title, r.text, remindMs: r.remindMs);
    nav.pop();
    if (f.remindMs > 0) {
      final msg = await permissionMessage();
      await Notifier.syncFree(f);
      if (msg != null) messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  Future<void> _newCat() async {
    final name =
        await askText(context, tx('Yeni kategori'), label: tx('Kategori adı'));
    if (name == null || !mounted) return;
    final c = store.addCategory(name);
    setState(() {
      catId = c.id;
      subId = null;
      routine = false;
      _goal.clear();
    });
  }

  Future<void> _newSub(Category cat) async {
    final d = await showSubDialog(context,
        simple: true,
        title: tx('“{0}” altına yeni alt kategori', [cat.name]));
    if (d == null || !mounted) return;
    final s = store.addSub(cat.id, d);
    _pickSub(s);
  }

  Future<void> _save() async {
    final sub = store.subById(subId!);
    if (sub == null) return;
    final goal = parseNum(_goal.text);
    final v = parseNum(_value.text);

    // 1) Rutin ayarı değiştiyse alt kategoriyi güncelle
    final daysChanged = routine && !(days.length == sub.days.length && days.containsAll(sub.days));
    if (routine != sub.routine || (routine && goal != sub.goal) || daysChanged) {
      final d = SubDraft.from(sub);
      d.routine = routine;
      if (routine) {
        d.goal = goal;
        d.days = Set<int>.from(days);
      }
      store.updateSub(sub.id, d);
      Notifier.syncSub(sub);
    }

    // 2) Veri girildiyse kaydet (günde tek veri kuralı)
    if (v != null && v >= 0) {
      final ex = store.entryFor(sub.id, widget.date);
      if (ex != null) {
        await _warnExisting(sub, ex);
        return;
      }
      store.setEntry(sub.id, widget.date, v);
    }
    if (mounted) Navigator.pop(context);
  }

  /// Aynı alt kategoriye ikinci veri girilirse uyarı çıkar
  Future<void> _warnExisting(SubCat sub, Entry ex) async {
    final edit = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tx('{0} verisi zaten var', [sub.name])),
        content: Text(tx(
            'Bu gün için {0} {1} girilmiş. Aynı alt kategoriye günde tek veri girilebilir.',
            [fmt(ex.value), sub.unit])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tx('Tamam'))),
          FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: Text(tx('Düzenle'))),
        ],
      ),
    );
    if (edit != true || !mounted) return;
    final nv = await askNumber(context,
        title: tx('{0} verisi', [sub.name]),
        unit: sub.unit,
        initial: ex.value);
    if (nv == null || !mounted) return;
    store.setEntry(sub.id, widget.date, nv);
    if (mounted) Navigator.pop(context);
  }

  /// Açılır listeyi çerçeveli kutuda gösterir
  Widget _dropBox(Pal p, {required Widget child}) => Container(
        padding: const EdgeInsets.symmetric(horizontal: 12),
        decoration: BoxDecoration(
          color: p.card,
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: p.line),
        ),
        child: child,
      );

  /// Belirgin bölüm başlığı (vurgu çizgisi + kalın yazı)
  Widget _head(Pal p, IconData icon, String text) => Row(
        children: [
          Container(
            width: 4,
            height: 22,
            decoration: BoxDecoration(
                color: p.accent, borderRadius: BorderRadius.circular(2)),
          ),
          const SizedBox(width: 10),
          Icon(icon, size: 20, color: p.ink),
          const SizedBox(width: 6),
          Text(text,
              style: TextStyle(
                  fontSize: 17, fontWeight: FontWeight.w800, color: p.ink)),
        ],
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        final cat = catId == null ? null : store.catById(catId!);
        final sub = subId == null ? null : store.subById(subId!);
        final valueOk = parseNum(_value.text) != null;
        final canSave = sub != null && (valueOk || routine || sub.routine);

        return Padding(
          padding: EdgeInsets.fromLTRB(
              16, 0, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
          child: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(tx('Ekle'),
                    style: TextStyle(
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                        color: p.ink)),
                const SizedBox(height: 16),

                // ----- Serbest satır: kategorisiz, başlığı ve verisi serbest -----
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    onPressed: _addFree,
                    icon: const Icon(Icons.edit_note_rounded),
                    label: Text(tx('Serbest satır')),
                  ),
                ),
                const SizedBox(height: 16),

                // ----- Kategori -----
                _head(p, Icons.folder_outlined, tx('Kategori')),
                const SizedBox(height: 10),
                _dropBox(
                  p,
                  child: DropdownButton<String>(
                    isExpanded: true,
                    underline: const SizedBox.shrink(),
                    hint: Text(tx('Kategori seç')),
                    value: cat?.id,
                    items: [
                      for (final c in store.cats)
                        DropdownMenuItem<String>(
                            value: c.id, child: Text(c.name)),
                      DropdownMenuItem<String>(
                          value: '__new__',
                          child: Row(children: [
                            const Icon(Icons.add, size: 18),
                            const SizedBox(width: 6),
                            Text(tx('Kategori ekle')),
                          ])),
                    ],
                    onChanged: (v) {
                      if (v == null) return;
                      if (v == '__new__') {
                        _newCat();
                        return;
                      }
                      setState(() {
                        if (catId != v) {
                          subId = null;
                          routine = false;
                          _goal.clear();
                        }
                        catId = v;
                      });
                    },
                  ),
                ),

                // ----- Alt kategori -----
                if (cat != null) ...[
                  const SizedBox(height: 18),
                  Divider(height: 1, thickness: 1.5, color: p.line),
                  const SizedBox(height: 18),
                  _head(p, Icons.subdirectory_arrow_right_rounded,
                      tx('Alt kategori')),
                  const SizedBox(height: 10),
                  _dropBox(
                    p,
                    child: DropdownButton<String>(
                      isExpanded: true,
                      underline: const SizedBox.shrink(),
                      hint: Text(tx('Alt kategori seç')),
                      value: sub?.id,
                      items: [
                        for (final s in cat.subs)
                          DropdownMenuItem<String>(
                              value: s.id,
                              child: Text(s.unit.isEmpty
                                  ? s.name
                                  : '${s.name} (${s.unit})')),
                        DropdownMenuItem<String>(
                            value: '__new__',
                            child: Row(children: [
                              const Icon(Icons.add, size: 18),
                              const SizedBox(width: 6),
                              Text(tx('Alt kategori ekle')),
                            ])),
                      ],
                      onChanged: (v) {
                        if (v == null) return;
                        if (v == '__new__') {
                          _newSub(cat);
                          return;
                        }
                        final picked = store.subById(v);
                        if (picked != null) _pickSub(picked);
                      },
                    ),
                  ),
                ],

                // ----- Rutin anahtarı, hedef ve veri -----
                if (sub != null) ...[
                  const SizedBox(height: 8),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text(tx('Rutin olsun')),
                    subtitle: Text(tx('Her gün ana ekranda listelenir')),
                    value: routine,
                    onChanged: (v) => setState(() => routine = v),
                  ),
                  if (routine) ...[
                    Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Text(tx('Hangi günler?'),
                          style: TextStyle(color: p.soft)),
                    ),
                    WeekdayChips(
                      selected: days,
                      onChanged: (v) => setState(() => days = v),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: _goal,
                      keyboardType: numberKeyboard,
                      inputFormatters: numberFormatters,
                      decoration: InputDecoration(
                        labelText: !sub.summable
                            ? tx('Hedef değer (isteğe bağlı)')
                            : (sub.isMax
                                ? tx('Günlük üst sınır (isteğe bağlı)')
                                : tx('Günlük hedef (isteğe bağlı)')),
                        suffixText: sub.unit,
                      ),
                    ),
                    const SizedBox(height: 12),
                  ],
                  TextField(
                    controller: _value,
                    keyboardType: numberKeyboard,
                    inputFormatters: numberFormatters,
                    onChanged: (_) => setState(() {}),
                    decoration: InputDecoration(
                      labelText: routine
                          ? tx('Günün verisi (isteğe bağlı)')
                          : tx('Veri'),
                      suffixText: sub.unit,
                      border: const OutlineInputBorder(),
                    ),
                  ),
                ],

                const SizedBox(height: 20),
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: FilledButton(
                    onPressed: canSave ? _save : null,
                    child: Text(tx('Kaydet')),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
