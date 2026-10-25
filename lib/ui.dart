import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'strings.dart';
import 'theme.dart';

// ---------------------------------------------------------------
// ORTAK YARDIMCILAR: renk paleti, pencereler
// Tüm metinler tx() ile çevrilir (Türkçe metin anahtardır).
// ---------------------------------------------------------------

/// Geçerli temaya (açık/koyu) ve seçili vurgu rengine göre palet verir
Pal palOf(BuildContext context) {
  final dark = Theme.of(context).brightness == Brightness.dark;
  return Pal(dark, accentFor(store.accent, dark));
}

/// Sadece sayı, virgül ve nokta girilebilen alan filtresi
final numberFormatters = <TextInputFormatter>[
  FilteringTextInputFormatter.allow(RegExp(r'[0-9,.]')),
];

const numberKeyboard = TextInputType.numberWithOptions(decimal: true);

// ---------- Metin sorma penceresi ----------

Future<String?> askText(BuildContext context, String title,
    {String initial = '', String label = ''}) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AskDialog(title: title, initial: initial, label: label),
  );
}

class _AskDialog extends StatefulWidget {
  final String title;
  final String initial;
  final String label;
  const _AskDialog(
      {required this.title, required this.initial, required this.label});

  @override
  State<_AskDialog> createState() => _AskDialogState();
}

class _AskDialogState extends State<_AskDialog> {
  late final TextEditingController _c =
      TextEditingController(text: widget.initial);

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _ok() {
    final t = _c.text.trim();
    Navigator.pop(context, t.isEmpty ? null : t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        decoration: InputDecoration(
            labelText: widget.label.isEmpty ? null : widget.label),
        onSubmitted: (_) => _ok(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tx('Vazgeç'))),
        FilledButton(onPressed: _ok, child: Text(tx('Tamam'))),
      ],
    );
  }
}

// ---------- Sayı sorma penceresi ----------

Future<double?> askNumber(BuildContext context,
    {required String title, String unit = '', double? initial}) {
  return showDialog<double>(
    context: context,
    builder: (_) => _NumberDialog(title: title, unit: unit, initial: initial),
  );
}

class _NumberDialog extends StatefulWidget {
  final String title;
  final String unit;
  final double? initial;
  const _NumberDialog(
      {required this.title, required this.unit, required this.initial});

  @override
  State<_NumberDialog> createState() => _NumberDialogState();
}

class _NumberDialogState extends State<_NumberDialog> {
  late final TextEditingController _c = TextEditingController(
      text: widget.initial == null ? '' : plain(widget.initial!));
  String? _err;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _ok() {
    final v = parseNum(_c.text);
    if (v == null || v < 0) {
      setState(() => _err = tx('Geçerli bir sayı gir'));
      return;
    }
    Navigator.pop(context, v);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: _c,
        autofocus: true,
        keyboardType: numberKeyboard,
        inputFormatters: numberFormatters,
        decoration: InputDecoration(
          labelText: tx('Veri'),
          suffixText: widget.unit,
          errorText: _err,
        ),
        onSubmitted: (_) => _ok(),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tx('Vazgeç'))),
        FilledButton(onPressed: _ok, child: Text(tx('Kaydet'))),
      ],
    );
  }
}

// ---------- Onay penceresi ----------

Future<bool> confirmDialog(BuildContext context, String title, String message,
    {String? okLabel, String? cancelLabel}) async {
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(title),
      content: Text(message),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text(cancelLabel ?? tx('Vazgeç'))),
        FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: Text(okLabel ?? tx('Evet'))),
      ],
    ),
  );
  return r ?? false;
}

// ---------- Rutin günleri seçici (Pzt ... Paz) ----------
// En az bir gün her zaman seçili kalır.
class WeekdayChips extends StatelessWidget {
  final Set<int> selected;
  final void Function(Set<int>) onChanged;
  const WeekdayChips({super.key, required this.selected, required this.onChanged});

  @override
  Widget build(BuildContext context) {
    return Wrap(spacing: 6, runSpacing: 4, children: [
      for (var d = 1; d <= 7; d++)
        FilterChip(
          label: Text(wdShort(d)),
          selected: selected.contains(d),
          visualDensity: VisualDensity.compact,
          onSelected: (on) {
            final next = Set<int>.from(selected);
            if (on) {
              next.add(d);
            } else if (next.length > 1) {
              next.remove(d);
            }
            onChanged(next);
          },
        ),
    ]);
  }
}

// ---------- Alt kategori oluştur / düzenle penceresi ----------
// simple = true: sadece ad + birim sorulur (Ekle ekranındaki "Yeni" için)
// simple = false: rutin, hedef, üst sınır, toplanır ayarları da gelir

Future<SubDraft?> showSubDialog(BuildContext context,
    {SubCat? sub, bool simple = false, String? title}) {
  return showDialog<SubDraft>(
    context: context,
    builder: (_) => _SubDialog(sub: sub, simple: simple, title: title),
  );
}

class _SubDialog extends StatefulWidget {
  final SubCat? sub;
  final bool simple;
  final String? title;
  const _SubDialog(
      {required this.sub, required this.simple, required this.title});

  @override
  State<_SubDialog> createState() => _SubDialogState();
}

class _SubDialogState extends State<_SubDialog> {
  late final TextEditingController _name;
  late final TextEditingController _unit;
  late final TextEditingController _goal;
  late bool _routine;
  late bool _isMax;
  late bool _summable;
  late Set<int> _days;
  String? _err;

  @override
  void initState() {
    super.initState();
    final s = widget.sub;
    _name = TextEditingController(text: s?.name ?? '');
    _unit = TextEditingController(text: s?.unit ?? '');
    _goal = TextEditingController(
        text: (s == null || s.goal == null) ? '' : plain(s.goal!));
    _routine = s?.routine ?? false;
    _isMax = s?.isMax ?? false;
    _summable = s?.summable ?? true;
    _days = Set<int>.from(s?.days ?? {1, 2, 3, 4, 5, 6, 7});
  }

  @override
  void dispose() {
    _name.dispose();
    _unit.dispose();
    _goal.dispose();
    super.dispose();
  }

  // Hedef alanı: rutinse veya toplanmayan (ör. kilo) veriyse görünür
  bool get _showGoal => !widget.simple && (_routine || !_summable);

  void _ok() {
    final name = _name.text.trim();
    if (name.isEmpty) {
      setState(() => _err = tx('Ad boş olamaz'));
      return;
    }
    double? goal;
    if (_showGoal && _goal.text.trim().isNotEmpty) {
      goal = parseNum(_goal.text);
      if (goal == null || goal < 0) {
        setState(() => _err = tx('Hedef geçerli bir sayı olmalı'));
        return;
      }
    }
    Navigator.pop(
      context,
      SubDraft(
        name: name,
        unit: _unit.text.trim(),
        routine: widget.simple ? false : _routine,
        goal: goal,
        isMax: _showGoal && _routine && _summable && _isMax,
        summable: widget.simple ? true : _summable,
        days: _days,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title ?? tx('Alt kategori')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _name,
              autofocus: widget.sub == null,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tx('Ad (ör. Su)')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _unit,
              onChanged: (_) => setState(() {}),
              decoration:
                  InputDecoration(labelText: tx('Birim (ör. lt, adım, soru)')),
            ),
            if (!widget.simple) ...[
              const SizedBox(height: 4),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tx('Rutin (her gün listede)')),
                value: _routine,
                onChanged: (v) => setState(() => _routine = v),
              ),
              if (_routine) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 4, bottom: 6),
                  child: Text(tx('Hangi günler?'),
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                WeekdayChips(
                  selected: _days,
                  onChanged: (v) => setState(() => _days = v),
                ),
                const SizedBox(height: 8),
              ],
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tx('Değerler toplanır')),
                subtitle:
                    Text(tx('Su, adım gibi. Kilo gibi veriler için kapat.')),
                value: _summable,
                onChanged: (v) => setState(() => _summable = v),
              ),
              if (_showGoal)
                TextField(
                  controller: _goal,
                  keyboardType: numberKeyboard,
                  inputFormatters: numberFormatters,
                  decoration: InputDecoration(
                    labelText:
                        _summable ? tx('Günlük hedef') : tx('Hedef değer'),
                    suffixText: _unit.text,
                  ),
                ),
              if (_routine && _summable)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(tx('Hedef üst sınırdır')),
                  subtitle:
                      Text(tx('Kalori gibi aşılmaması gereken veriler için.')),
                  value: _isMax,
                  onChanged: (v) => setState(() => _isMax = v),
                ),
            ],
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_err!,
                    style: TextStyle(color: Theme.of(context).colorScheme.error)),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tx('Vazgeç'))),
        FilledButton(onPressed: _ok, child: Text(tx('Kaydet'))),
      ],
    );
  }
}
