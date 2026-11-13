import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'reminders.dart';
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

// ---------- Serbest satır penceresi (başlık + serbest metin + tarih + hatırlatma) ----------

class FreeRowResult {
  final String title;
  final String text;
  final String date; // yyyy-MM-dd (satırın görüneceği gün)
  final int remindMs; // 0 = hatırlatma yok
  const FreeRowResult(this.title, this.text, this.date, this.remindMs);
}

Future<FreeRowResult?> showFreeRowDialog(BuildContext context,
    {String title = '',
    String text = '',
    required String date,
    int remindMs = 0,
    bool isNew = true}) {
  return showDialog<FreeRowResult>(
    context: context,
    builder: (_) => _FreeRowDialog(
        title: title, text: text, date: date, remindMs: remindMs, isNew: isNew),
  );
}

class _FreeRowDialog extends StatefulWidget {
  final String title;
  final String text;
  final String date;
  final int remindMs;
  final bool isNew;
  const _FreeRowDialog(
      {required this.title,
      required this.text,
      required this.date,
      required this.remindMs,
      required this.isNew});

  @override
  State<_FreeRowDialog> createState() => _FreeRowDialogState();
}

class _FreeRowDialogState extends State<_FreeRowDialog> {
  late final TextEditingController _t = TextEditingController(text: widget.title);
  late final TextEditingController _v = TextEditingController(text: widget.text);
  late String _date = widget.date;
  late int _remind = widget.remindMs;

  @override
  void dispose() {
    _t.dispose();
    _v.dispose();
    super.dispose();
  }

  void _ok() {
    final t = _t.text.trim();
    if (t.isEmpty) return;
    Navigator.pop(context, FreeRowResult(t, _v.text.trim(), _date, _remind));
  }

  Future<void> _pickDay() async {
    final cur = parseKey(_date);
    final d = await showDatePicker(
      context: context,
      initialDate: cur,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => _date = dKey(dayOnly(d)));
  }

  Future<void> _pickRemind() async {
    final v = await pickDateTime(context, initialMs: _remind);
    if (v != null) setState(() => _remind = v);
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final d = parseKey(_date);
    final dayText =
        '${d.day.toString().padLeft(2, '0')}.${d.month.toString().padLeft(2, '0')}.${d.year}';
    return AlertDialog(
      title: Text(widget.isNew ? tx('Serbest satır') : tx('Satırı düzenle')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _t,
              autofocus: true,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(labelText: tx('Başlık')),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: _v,
              decoration: InputDecoration(labelText: tx('Serbest veri')),
            ),
            const SizedBox(height: 14),
            Text(tx('Hangi günde görünsün?'),
                style: TextStyle(fontSize: 12.5, color: p.soft)),
            OutlinedButton.icon(
              onPressed: _pickDay,
              icon: const Icon(Icons.calendar_today_rounded, size: 18),
              label: Text(dayText),
            ),
            const SizedBox(height: 10),
            Text(tx('Hatırlatma (isteğe bağlı)'),
                style: TextStyle(fontSize: 12.5, color: p.soft)),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _pickRemind,
                    icon: const Icon(Icons.notifications_none_rounded, size: 18),
                    label: Text(_remind > 0 ? dtLabel(_remind) : tx('Hatırlatma ekle')),
                  ),
                ),
                if (_remind > 0)
                  IconButton(
                    tooltip: tx('Kaldır'),
                    onPressed: () => setState(() => _remind = 0),
                    icon: const Icon(Icons.close_rounded),
                  ),
              ],
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
// ORTAK KAYDIRMA SATIRI: sağa kaydır = düzenle, sola kaydır = sil.
// İkisi de eylemi çağırır; satır yerinde kalır (silme/onay çağıranın işidir).
// ---------------------------------------------------------------
class SwipeRow extends StatelessWidget {
  final String tag; // benzersiz kimlik (Dismissible anahtarı için)
  final Widget child;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final EdgeInsetsGeometry padding;
  final double radius;
  const SwipeRow({
    super.key,
    required this.tag,
    required this.child,
    required this.onEdit,
    required this.onDelete,
    this.padding = EdgeInsets.zero,
    this.radius = 0,
  });

  Widget _bg(Color c, IconData i, Alignment a) => Container(
        color: c,
        alignment: a,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Icon(i),
      );

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Padding(
      padding: padding,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(radius),
        child: Dismissible(
          key: ValueKey('swp_$tag'),
          background: _bg(p.editBg, Icons.edit_rounded, Alignment.centerLeft),
          secondaryBackground:
              _bg(p.delBg, Icons.delete_outline_rounded, Alignment.centerRight),
          confirmDismiss: (dir) async {
            if (dir == DismissDirection.startToEnd) {
              onEdit();
            } else {
              onDelete();
            }
            return false;
          },
          child: child,
        ),
      ),
    );
  }
}

/// Altta kısa süre "Geri al" düğmeli bildirim gösterir
void showUndo(BuildContext context, String message, VoidCallback onUndo) {
  final m = ScaffoldMessenger.of(context);
  m.clearSnackBars();
  m.showSnackBar(SnackBar(
    duration: const Duration(seconds: 5),
    persist: false, // "Geri al" olsa da 5 saniye sonra kapansın
    // Tüm satır geri al düğmesi: satırın herhangi bir yerine dokununca geri alınır.
    // "Geri al" yazısı solda, mesaj yanında.
    content: InkWell(
      onTap: () {
        m.hideCurrentSnackBar();
        onUndo();
      },
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: Row(
          children: [
            Text(tx('Geri al'),
                style: const TextStyle(
                    fontWeight: FontWeight.w800, color: Color(0xFFA6D4B0))),
            const SizedBox(width: 14),
            Expanded(child: Text(message)),
          ],
        ),
      ),
    ),
  ));
}

// ---------------------------------------------------------------
// KATEGORİ RENKLERİ: her kategori/liste kimliğine göre sabit bir ton.
// Uygulamanın genel vurgu renginden bağımsızdır.
// ---------------------------------------------------------------
const _tagHues = <int>[
  0xFF4F8EF7, // mavi
  0xFF2FB38A, // yeşil
  0xFF9A6BF0, // mor
  0xFFF08A3C, // turuncu
  0xFFE95E8F, // pembe
  0xFF17A9C4, // turkuaz
  0xFFD6A21E, // hardal
  0xFF7DA23A, // zeytin
];

Color tagTone(String seed) {
  var h = 0;
  for (final u in seed.codeUnits) {
    h = (h * 31 + u) & 0x7fffffff;
  }
  return Color(_tagHues[h % _tagHues.length]);
}

// ---------------------------------------------------------------
// Her sayfada: sayfanın en üstündeyken aşağı çekip bırakınca ana sayfaya dön
// ---------------------------------------------------------------
final ValueNotifier<int> homeReset = ValueNotifier<int>(0);

class PullHome extends StatefulWidget {
  final Widget child;
  final GlobalKey<NavigatorState> navKey;
  const PullHome({super.key, required this.child, required this.navKey});

  @override
  State<PullHome> createState() => _PullHomeState();
}

class _PullHomeState extends State<PullHome> {
  static const double _need = 75; // yaklaşık 2 cm
  double _pull = 0;
  bool _active = false;
  final ValueNotifier<double> _prog = ValueNotifier<double>(0);

  bool _typing() {
    final f = FocusManager.instance.primaryFocus;
    return f?.context?.findAncestorWidgetOfExactType<EditableText>() != null;
  }

  bool _onScroll(ScrollNotification n) {
    if (n.metrics.axis != Axis.vertical) return false;
    if (n is ScrollStartNotification) {
      _pull = 0;
      _active = false;
      _prog.value = 0;
      final ctx = n.context;
      final route = ctx == null ? null : ModalRoute.of(ctx);
      // pencere / alt panel / yazı yazarken devre dışı
      _active = route is PageRoute && !_typing() && !store.locked;
    } else if (n is OverscrollNotification) {
      if (_active &&
          n.dragDetails != null &&
          n.overscroll < 0 &&
          n.metrics.pixels <= n.metrics.minScrollExtent + 0.5) {
        _pull += -n.overscroll;
        _prog.value = (_pull / _need).clamp(0.0, 1.0);
      }
    } else if (n is ScrollUpdateNotification) {
      if (n.metrics.pixels > n.metrics.minScrollExtent + 1) {
        _pull = 0;
        _prog.value = 0;
      }
    } else if (n is ScrollEndNotification) {
      final go = _active && _pull >= _need;
      _pull = 0;
      _active = false;
      _prog.value = 0;
      if (go) {
        final nav = widget.navKey.currentState;
        nav?.popUntil((r) => r.isFirst);
        homeReset.value++;
      }
    }
    return false;
  }

  @override
  void dispose() {
    _prog.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return NotificationListener<ScrollNotification>(
      onNotification: _onScroll,
      child: Stack(
        fit: StackFit.expand,
        children: [
          widget.child,
          Positioned(
            top: 56,
            left: 0,
            right: 0,
            child: IgnorePointer(
              child: ValueListenableBuilder<double>(
                valueListenable: _prog,
                builder: (context, v, _) => v <= 0.05
                    ? const SizedBox.shrink()
                    : Center(
                        child: Opacity(
                          opacity: v,
                          child: Container(
                            padding: const EdgeInsets.symmetric(
                                horizontal: 14, vertical: 8),
                            decoration: BoxDecoration(
                              color: const Color(0xFF2E3238),
                              borderRadius: BorderRadius.circular(20),
                            ),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(Icons.home_rounded,
                                    size: 18,
                                    color: v >= 1 ? p.accent : Colors.white),
                                const SizedBox(width: 6),
                                Text(
                                  v >= 1
                                      ? tx('Bırak: ana sayfa')
                                      : tx('Ana sayfa için çek'),
                                  style: const TextStyle(
                                      color: Colors.white,
                                      fontSize: 13,
                                      fontWeight: FontWeight.w600,
                                      decoration: TextDecoration.none),
                                ),
                              ],
                            ),
                          ),
                        ),
                      ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
