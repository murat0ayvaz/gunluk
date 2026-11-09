import 'package:flutter/material.dart';
import 'data.dart';
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// SATIR DÜZENLE (ana ekranda sağa kaydırınca) ve ZİL (rutin hatırlatması)
//  - Günün verisi girilir / değiştirilir / silinir
//  - Rutinse: hangi günlerde görüneceği ve günlük hatırlatma saati
// ---------------------------------------------------------------

String _hm(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

Future<TimeOfDay?> _pickTime(BuildContext context, int h, int m) =>
    showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h < 0 ? 9 : h, minute: m),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

class RowEditResult {
  final double? value; // null: veri değişmez
  final bool deleteEntry; // o günün verisini sil
  final Set<int> days;
  final int rh; // -1: hatırlatma yok
  final int rm;
  final double? goal; // yeni hedef (goalSet true ise geçerli)
  final bool goalSet;
  final bool openSub; // "Alt kategoriyi düzenle" istendi
  const RowEditResult(this.value, this.deleteEntry, this.days, this.rh, this.rm,
      {this.goal, this.goalSet = false, this.openSub = false});
}

Future<RowEditResult?> showRowEditDialog(BuildContext context,
    {required SubCat sub, Entry? entry}) {
  return showDialog<RowEditResult>(
    context: context,
    builder: (_) => _RowEditDialog(sub: sub, entry: entry),
  );
}

class _RowEditDialog extends StatefulWidget {
  final SubCat sub;
  final Entry? entry;
  const _RowEditDialog({required this.sub, required this.entry});

  @override
  State<_RowEditDialog> createState() => _RowEditDialogState();
}

class _RowEditDialogState extends State<_RowEditDialog> {
  late final TextEditingController _c = TextEditingController(
      text: widget.entry == null ? '' : plain(widget.entry!.value));
  late Set<int> _days = Set<int>.from(widget.sub.days);
  late int _rh = widget.sub.rh;
  late int _rm = widget.sub.rm;
  late final TextEditingController _g = TextEditingController(
      text: widget.sub.goal == null ? '' : plain(widget.sub.goal!));
  String? _err;
  String? _gerr;

  @override
  void dispose() {
    _c.dispose();
    _g.dispose();
    super.dispose();
  }

  void _ok() {
    double? v;
    if (_c.text.trim().isNotEmpty) {
      v = parseNum(_c.text);
      if (v == null || v < 0) {
        setState(() => _err = tx('Geçerli bir sayı gir'));
        return;
      }
    }
    double? g;
    if (widget.sub.routine) {
      if (_g.text.trim().isNotEmpty) {
        g = parseNum(_g.text);
        if (g == null || g < 0) {
          setState(() => _gerr = tx('Geçerli bir sayı gir'));
          return;
        }
      }
    }
    Navigator.pop(
        context,
        RowEditResult(v, false, _days, _rh, _rm,
            goal: g, goalSet: widget.sub.routine));
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final sub = widget.sub;
    return AlertDialog(
      title: Text(tx('{0} verisi', [sub.name])),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _c,
              autofocus: true,
              keyboardType: numberKeyboard,
              inputFormatters: numberFormatters,
              decoration: InputDecoration(
                labelText: tx('Veri'),
                suffixText: sub.unit,
                errorText: _err,
              ),
              onSubmitted: (_) => _ok(),
            ),
            if (sub.routine) ...[
              const SizedBox(height: 12),
              TextField(
                controller: _g,
                keyboardType: numberKeyboard,
                inputFormatters: numberFormatters,
                decoration: InputDecoration(
                  labelText: tx('Hedef'),
                  suffixText: sub.unit,
                  errorText: _gerr,
                ),
              ),
              const SizedBox(height: 16),
              Text(tx('Hangi günler?'),
                  style: TextStyle(fontSize: 12.5, color: p.soft)),
              const SizedBox(height: 6),
              WeekdayChips(
                selected: _days,
                onChanged: (v) => setState(() => _days = v),
              ),
              const SizedBox(height: 14),
              Text(tx('Günlük hatırlatma saati'),
                  style: TextStyle(fontSize: 12.5, color: p.soft)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final t = await _pickTime(context, _rh, _rm);
                        if (t != null) {
                          setState(() {
                            _rh = t.hour;
                            _rm = t.minute;
                          });
                        }
                      },
                      icon: const Icon(Icons.notifications_none_rounded,
                          size: 18),
                      label: Text(_rh >= 0
                          ? _hm(_rh, _rm)
                          : tx('Hatırlatma ekle')),
                    ),
                  ),
                  if (_rh >= 0)
                    IconButton(
                      tooltip: tx('Kaldır'),
                      onPressed: () => setState(() => _rh = -1),
                      icon: const Icon(Icons.close_rounded),
                    ),
                ],
              ),
            ],
            const SizedBox(height: 10),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: () => Navigator.pop(
                    context,
                    RowEditResult(null, false, _days, _rh, _rm,
                        openSub: true)),
                icon: const Icon(Icons.tune_rounded, size: 18),
                label: Text(tx('Alt kategoriyi düzenle')),
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (widget.entry != null)
          TextButton(
            onPressed: () => Navigator.pop(
                context, RowEditResult(null, true, _days, _rh, _rm)),
            child: Text(tx('Veriyi sil'),
                style: const TextStyle(color: Color(0xFFC0504D))),
          ),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tx('Vazgeç'))),
        FilledButton(onPressed: _ok, child: Text(tx('Kaydet'))),
      ],
    );
  }
}

/// Satırdaki zil: rutinin günlük hatırlatma saatini ayarlar.
/// Dönen değer: (saat, dakika); saat -1 ise hatırlatma kaldırıldı; null: değişmedi.
Future<(int, int)?> showRoutineBell(BuildContext context, SubCat sub) {
  return showDialog<(int, int)>(
    context: context,
    builder: (_) => _BellDialog(sub: sub),
  );
}

class _BellDialog extends StatefulWidget {
  final SubCat sub;
  const _BellDialog({required this.sub});

  @override
  State<_BellDialog> createState() => _BellDialogState();
}

class _BellDialogState extends State<_BellDialog> {
  late int _h = widget.sub.rh < 0 ? 9 : widget.sub.rh;
  late int _m = widget.sub.rm;

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return AlertDialog(
      title: Text(tx('{0} hatırlatması', [widget.sub.name])),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(tx('Rutinin görüneceği günlerde bu saatte bildirim gelir.'),
              style: TextStyle(fontSize: 13, color: p.soft)),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: () async {
              final t = await _pickTime(context, _h, _m);
              if (t != null) {
                setState(() {
                  _h = t.hour;
                  _m = t.minute;
                });
              }
            },
            icon: const Icon(Icons.schedule_rounded, size: 18),
            label: Text(_hm(_h, _m)),
          ),
        ],
      ),
      actions: [
        if (widget.sub.rh >= 0)
          TextButton(
              onPressed: () => Navigator.pop(context, (-1, 0)),
              child: Text(tx('Kaldır'))),
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(tx('Vazgeç'))),
        FilledButton(
            onPressed: () => Navigator.pop(context, (_h, _m)),
            child: Text(tx('Kaydet'))),
      ],
    );
  }
}
