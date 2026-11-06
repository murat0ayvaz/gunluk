import 'package:flutter/material.dart';
import 'data.dart';
import 'notify.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// HATIRLATICILAR: bildirim gönderen kayıtlar.
//  - Tek seferlik: seçilen tarih ve saatte bir kez
//  - Aralıklı: başlangıçtan itibaren her N dakikada, toplam M kez
//  - Her gün: her gün seçilen saatte
// Ayrıca yapılacak maddelerine tarih-saatli hatırlatma konabilir.
// Sağa kaydır = düzenle, sola kaydır = sil (5 sn geri al).
// ---------------------------------------------------------------

String _two(int n) => n.toString().padLeft(2, '0');

String hm(int h, int m) => '${_two(h)}:${_two(m)}';

String dtLabel(int ms) {
  final d = DateTime.fromMillisecondsSinceEpoch(ms);
  return '${_two(d.day)}.${_two(d.month)}.${d.year} ${hm(d.hour, d.minute)}';
}

String everyLabel(int min) {
  if (min >= 60 && min % 60 == 0) return tx('{0} saat', [min ~/ 60]);
  return tx('{0} dk', [min]);
}

Future<int?> pickDateTime(BuildContext context, {int? initialMs}) async {
  final init = initialMs != null && initialMs > 0
      ? DateTime.fromMillisecondsSinceEpoch(initialMs)
      : DateTime.now().add(const Duration(minutes: 5));
  final d = await showDatePicker(
    context: context,
    initialDate: init,
    firstDate: DateTime.now().subtract(const Duration(days: 1)),
    lastDate: DateTime.now().add(const Duration(days: 365 * 3)),
  );
  if (d == null || !context.mounted) return null;
  final t = await showTimePicker(
    context: context,
    initialTime: TimeOfDay(hour: init.hour, minute: init.minute),
    builder: (ctx, child) => MediaQuery(
      data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
      child: child!,
    ),
  );
  if (t == null) return null;
  return DateTime(d.year, d.month, d.day, t.hour, t.minute)
      .millisecondsSinceEpoch;
}

/// İzin yoksa kullanıcıya kısa uyarı metni verir (varsa null)
Future<String?> permissionMessage() async {
  final s = await Notifier.permissions(request: true);
  if (!s.notifications) {
    return tx(
        'Bildirim izni verilmedi. Telefon ayarlarından Daily Routine için bildirimleri aç.');
  }
  if (!s.exact) {
    return tx(
        'Tam zamanlı alarm izni yok; bildirimler birkaç dakika gecikebilir. Ayarlardan "Alarmlar ve hatırlatıcılar" iznini açabilirsin.');
  }
  return null;
}

void _snack(BuildContext context, String m) {
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m), duration: const Duration(seconds: 5)));
}

String _summary(Reminder r) {
  if (r.kind == 'daily') {
    return tx('Her gün {0}', [hm(r.hour, r.minute)]);
  }
  if (r.kind == 'interval') {
    return tx('{0} • her {1} • {2} kez',
        [dtLabel(r.startMs), everyLabel(r.every), r.count]);
  }
  return dtLabel(r.startMs);
}

// ===============================================================
// Liste
// ===============================================================
class RemindersBody extends StatefulWidget {
  const RemindersBody({super.key});

  @override
  State<RemindersBody> createState() => _RemindersBodyState();
}

class _RemindersBodyState extends State<RemindersBody> {
  void _delete(Reminder r) {
    final index = store.reminders.indexWhere((x) => x.id == r.id);
    store.deleteReminder(r.id);
    Notifier.cancelReminder(r);
    showUndo(context, tx('Hatırlatıcı silindi'), () {
      store.restoreReminder(r, index: index);
      Notifier.syncReminder(r);
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        final list = store.reminders;
        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: () => showReminderSheet(context),
                      icon: const Icon(Icons.add_alert_rounded),
                      label: Text(tx('Yeni hatırlatıcı')),
                    ),
                  ),
                  IconButton(
                    tooltip: tx('Çalışmıyorsa ne yapmalı?'),
                    onPressed: () => showReminderHelp(context),
                    icon: const Icon(Icons.help_outline_rounded),
                  ),
                ],
              ),
            ),
            if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  tx('Henüz hatırlatıcı yok. Yukarıdan ekleyebilirsin.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.soft),
                ),
              )
            else
              Padding(
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                child: Column(
                  children: [
                    for (final r in list)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(12),
                          child: Dismissible(
                            key: ValueKey('rm_${r.id}'),
                            background: _bg(p.editBg, Icons.edit_rounded,
                                Alignment.centerLeft),
                            secondaryBackground: _bg(
                                p.delBg,
                                Icons.delete_outline_rounded,
                                Alignment.centerRight),
                            confirmDismiss: (dir) async {
                              if (dir == DismissDirection.startToEnd) {
                                showReminderSheet(context, edit: r);
                                return false;
                              }
                              return true;
                            },
                            onDismissed: (_) => _delete(r),
                            child: Material(
                              color: p.card,
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(12),
                                side: BorderSide(color: p.line),
                              ),
                              child: ListTile(
                                title: Text(r.text,
                                    style: TextStyle(
                                        color: r.enabled ? p.ink : p.soft)),
                                subtitle: Text(
                                  reminderFinished(r)
                                      ? tx('Tamamlandı')
                                      : _summary(r),
                                  style: TextStyle(
                                      fontSize: 12.5, color: p.soft),
                                ),
                                trailing: Switch(
                                  value: r.enabled,
                                  onChanged: (_) async {
                                    store.toggleReminder(r.id);
                                    await Notifier.syncReminder(r);
                                  },
                                ),
                              ),
                            ),
                          ),
                        ),
                      ),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: p.card,
                        borderRadius: BorderRadius.circular(12),
                        border: Border.all(color: p.line),
                      ),
                      child: Text(
                        tx('Sağa kaydır: düzenle • Sola kaydır: sil. Bildirim gelmezse sağ üstteki ? simgesine bak.'),
                        style: TextStyle(fontSize: 12.5, color: p.soft),
                      ),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _bg(Color c, IconData i, Alignment a) => Container(
        color: c,
        alignment: a,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Icon(i),
      );
}

// ===============================================================
// Yeni / düzenle formu
// ===============================================================
Future<void> showReminderSheet(BuildContext context, {Reminder? edit}) {
  return showModalBottomSheet<void>(
    context: context,
    isScrollControlled: true,
    showDragHandle: true,
    builder: (_) => _ReminderForm(edit: edit),
  );
}

class _ReminderForm extends StatefulWidget {
  final Reminder? edit;
  const _ReminderForm({this.edit});

  @override
  State<_ReminderForm> createState() => _ReminderFormState();
}

class _ReminderFormState extends State<_ReminderForm> {
  late final TextEditingController _c =
      TextEditingController(text: widget.edit?.text ?? '');
  late String _kind = widget.edit?.kind ?? 'once';
  late int _start = (widget.edit != null && widget.edit!.startMs > 0)
      ? widget.edit!.startMs
      : DateTime.now().add(const Duration(minutes: 5)).millisecondsSinceEpoch;
  late int _every = widget.edit?.every ?? 15;
  late int _count = widget.edit?.count ?? 3;
  late int _hour = widget.edit?.hour ?? 9;
  late int _minute = widget.edit?.minute ?? 0;
  String? _warn;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final text = _c.text.trim();
    if (text.isEmpty) {
      setState(() => _warn = tx('Önce hatırlatıcı metnini yaz.'));
      return;
    }
    final nav = Navigator.of(context);
    final msg = await permissionMessage();
    final e = widget.edit;
    Reminder r;
    if (e != null) {
      r = e;
      r.text = text;
      r.kind = _kind;
      r.startMs = _start;
      r.every = _every;
      r.count = _kind == 'interval' ? _count : 1;
      r.hour = _hour;
      r.minute = _minute;
      r.enabled = true;
      store.updateReminder(r);
    } else {
      r = store.addReminder(Reminder(
        id: store.newId(),
        nid: store.newNid(),
        text: text,
        kind: _kind,
        startMs: _start,
        every: _every,
        count: _kind == 'interval' ? _count : 1,
        hour: _hour,
        minute: _minute,
      ));
    }
    await Notifier.syncReminder(r);
    nav.pop();
    if (msg != null && nav.context.mounted) _snack(nav.context, msg);
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final kinds = {
      'once': tx('Tek seferlik'),
      'interval': tx('Aralıklı'),
      'daily': tx('Her gün'),
    };
    return Padding(
      padding: EdgeInsets.fromLTRB(
          16, 0, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
                widget.edit == null
                    ? tx('Yeni hatırlatıcı')
                    : tx('Hatırlatıcıyı düzenle'),
                style:
                    const TextStyle(fontSize: 18, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            TextField(
              controller: _c,
              textCapitalization: TextCapitalization.sentences,
              decoration: InputDecoration(
                labelText: tx('Ne hatırlatılsın?'),
                border: const OutlineInputBorder(),
              ),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 8,
              children: [
                for (final k in kinds.entries)
                  ChoiceChip(
                    label: Text(k.value),
                    selected: _kind == k.key,
                    onSelected: (_) => setState(() => _kind = k.key),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            if (_kind != 'daily') ...[
              Text(tx('Başlangıç'), style: TextStyle(color: p.soft)),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final v = await pickDateTime(context, initialMs: _start);
                        if (v != null) setState(() => _start = v);
                      },
                      icon: const Icon(Icons.event_rounded),
                      label: Text(dtLabel(_start)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  TextButton(
                    onPressed: () => setState(() => _start = DateTime.now()
                        .add(const Duration(minutes: 1))
                        .millisecondsSinceEpoch),
                    child: Text(tx('Şimdi')),
                  ),
                ],
              ),
            ],
            if (_kind == 'interval') ...[
              const SizedBox(height: 12),
              Text(tx('Tekrar aralığı'), style: TextStyle(color: p.soft)),
              Wrap(
                spacing: 8,
                children: [
                  for (final m in const [5, 10, 15, 30, 60])
                    ChoiceChip(
                      label: Text(everyLabel(m)),
                      selected: _every == m,
                      onSelected: (_) => setState(() => _every = m),
                    ),
                ],
              ),
              const SizedBox(height: 12),
              Text(tx('Toplam kaç kez'), style: TextStyle(color: p.soft)),
              Row(
                children: [
                  IconButton(
                    onPressed:
                        _count > 1 ? () => setState(() => _count--) : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text('$_count',
                      style: const TextStyle(
                          fontSize: 18, fontWeight: FontWeight.w700)),
                  IconButton(
                    onPressed:
                        _count < 12 ? () => setState(() => _count++) : null,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
            ],
            if (_kind == 'daily') ...[
              Text(tx('Saat'), style: TextStyle(color: p.soft)),
              OutlinedButton.icon(
                onPressed: () async {
                  final t = await showTimePicker(
                    context: context,
                    initialTime: TimeOfDay(hour: _hour, minute: _minute),
                    builder: (ctx, child) => MediaQuery(
                      data: MediaQuery.of(ctx)
                          .copyWith(alwaysUse24HourFormat: true),
                      child: child!,
                    ),
                  );
                  if (t != null) {
                    setState(() {
                      _hour = t.hour;
                      _minute = t.minute;
                    });
                  }
                },
                icon: const Icon(Icons.schedule_rounded),
                label: Text(hm(_hour, _minute)),
              ),
            ],
            if (_warn != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_warn!, style: const TextStyle(color: Colors.red)),
              ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: _save,
                child: Text(tx('Kaydet')),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ===============================================================
// Yapılacak maddesi için hatırlatma penceresi
// ===============================================================
Future<void> showTodoReminderDialog(BuildContext context, Todo t) {
  return showDialog<void>(
    context: context,
    builder: (_) => _TodoRemindDialog(todo: t),
  );
}

class _TodoRemindDialog extends StatefulWidget {
  final Todo todo;
  const _TodoRemindDialog({required this.todo});

  @override
  State<_TodoRemindDialog> createState() => _TodoRemindDialogState();
}

class _TodoRemindDialogState extends State<_TodoRemindDialog> {
  late int _ms = widget.todo.remindMs > 0
      ? widget.todo.remindMs
      : DateTime.now().add(const Duration(hours: 1)).millisecondsSinceEpoch;
  late int _every = widget.todo.remindEvery;
  late int _count = widget.todo.remindCount < 2 ? 3 : widget.todo.remindCount;

  Future<void> _save() async {
    final nav = Navigator.of(context);
    final ctx = nav.context;
    final msg = await permissionMessage();
    store.setTodoReminder(widget.todo.id,
        ms: _ms, every: _every, count: _every > 0 ? _count : 1);
    final t = store.todoById(widget.todo.id);
    if (t != null) await Notifier.syncTodo(t);
    nav.pop();
    if (msg != null && ctx.mounted) _snack(ctx, msg);
  }

  Future<void> _remove() async {
    final t = widget.todo;
    await Notifier.cancelTodo(t);
    store.setTodoReminder(t.id, ms: 0);
    if (mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return AlertDialog(
      title: Text(tx('Hatırlatma')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final v = await pickDateTime(context, initialMs: _ms);
                if (v != null) setState(() => _ms = v);
              },
              icon: const Icon(Icons.event_rounded),
              label: Text(dtLabel(_ms)),
            ),
            const SizedBox(height: 12),
            Text(tx('Tekrar'), style: TextStyle(color: p.soft)),
            Wrap(
              spacing: 8,
              children: [
                ChoiceChip(
                  label: Text(tx('Tek sefer')),
                  selected: _every == 0,
                  onSelected: (_) => setState(() => _every = 0),
                ),
                for (final m in const [10, 30, 60])
                  ChoiceChip(
                    label: Text(everyLabel(m)),
                    selected: _every == m,
                    onSelected: (_) => setState(() => _every = m),
                  ),
              ],
            ),
            if (_every > 0) ...[
              const SizedBox(height: 8),
              Row(
                children: [
                  Text(tx('Toplam'), style: TextStyle(color: p.soft)),
                  IconButton(
                    onPressed:
                        _count > 2 ? () => setState(() => _count--) : null,
                    icon: const Icon(Icons.remove_circle_outline_rounded),
                  ),
                  Text('$_count',
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                  IconButton(
                    onPressed:
                        _count < 12 ? () => setState(() => _count++) : null,
                    icon: const Icon(Icons.add_circle_outline_rounded),
                  ),
                ],
              ),
            ],
          ],
        ),
      ),
      actions: [
        if (widget.todo.remindMs > 0)
          TextButton(onPressed: _remove, child: Text(tx('Kaldır'))),
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tx('Vazgeç'))),
        FilledButton(onPressed: _save, child: Text(tx('Kaydet'))),
      ],
    );
  }
}

// ===============================================================
// Yardım ve izin durumu
// ===============================================================
Future<void> showReminderHelp(BuildContext context) {
  return showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tx('Bildirim gelmiyorsa')),
      content: SingleChildScrollView(
        child: Text(tx(
            '1) Telefon Ayarlar > Uygulamalar > Daily Routine > Bildirimler açık olsun.\n2) "Alarmlar ve hatırlatıcılar" iznini aç.\n3) Pil ayarında Daily Routine için "Kısıtlama yok" seç.\n4) Xiaomi / Redmi: Ayarlar > Uygulamalar > Daily Routine > Otomatik başlat\'ı aç ve pil tasarrufunu "Kısıtlama yok" yap.\n5) Ayarlar menüsündeki "Deneme bildirimi" ile test et.')),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(tx('Tamam'))),
      ],
    ),
  );
}

Future<void> showPermissionStatus(BuildContext context) async {
  final s = await Notifier.permissions(request: true);
  if (!context.mounted) return;
  await showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tx('İzin durumu')),
      content: Text(
          '${tx('Bildirim')}: ${s.notifications ? tx('açık') : tx('kapalı')}\n'
          '${tx('Tam zamanlı alarm')}: ${s.exact ? tx('açık') : tx('kapalı')}'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(tx('Tamam'))),
      ],
    ),
  );
}

Future<void> sendTestNotification(BuildContext context) async {
  final msg = await permissionMessage();
  try {
    await Notifier.sendTest();
  } catch (e) {
    if (context.mounted) _snack(context, '$e');
    return;
  }
  if (msg != null && context.mounted) _snack(context, msg);
}
