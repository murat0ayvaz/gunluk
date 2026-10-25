import 'package:flutter/material.dart';
import 'data.dart';
import 'strings.dart';
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

                // ----- Kategori -----
                Text(tx('Kategori'), style: TextStyle(color: p.soft)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final c in store.cats)
                    ChoiceChip(
                      label: Text(c.name),
                      selected: catId == c.id,
                      onSelected: (_) => setState(() {
                        if (catId != c.id) {
                          subId = null;
                          routine = false;
                          _goal.clear();
                        }
                        catId = c.id;
                      }),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: Text(tx('Yeni')),
                    onPressed: _newCat,
                  ),
                ]),

                // ----- Alt kategori -----
                if (cat != null) ...[
                  const SizedBox(height: 16),
                  Text(tx('Alt kategori'), style: TextStyle(color: p.soft)),
                  const SizedBox(height: 8),
                  Wrap(spacing: 8, runSpacing: 4, children: [
                    for (final s in cat.subs)
                      ChoiceChip(
                        label: Text(
                            s.unit.isEmpty ? s.name : '${s.name} (${s.unit})'),
                        selected: subId == s.id,
                        onSelected: (_) => _pickSub(s),
                      ),
                    ActionChip(
                      avatar: const Icon(Icons.add, size: 18),
                      label: Text(tx('Yeni')),
                      onPressed: () => _newSub(cat),
                    ),
                  ]),
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
