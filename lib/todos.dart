import 'package:flutter/material.dart';
import 'data.dart';
import 'notify.dart';
import 'reminders.dart';
import 'strings.dart';
import 'ui.dart';
import 'voice.dart';

// ---------------------------------------------------------------
// YAPILACAKLAR: checkbox'lı basit liste, GÜNE ÖZEL.
// Ana ekranda rutinlerin altındaki "Yapılacaklar" başlığında açılır.
//  - Üstteki kutudan (seçili güne) madde ekle, mikrofonla sesli ekle
//  - Checkbox ile işaretle: tamamlananlar üstü çizili olarak alta iner
//  - Sağa AZ kaydır: maddeyi düzenle
//  - Sağa TAM kaydır (satırın ~%60'ı): maddeyi ertesi güne gönder
//  - Sola kaydır: sil ("Geri al" çubuğu çıkar)
//  - Sağdaki ≡ tutamacı ile sürükleyip sırala; zil: hatırlatma
//  - Bitmeyen geçmiş maddeler her gün bugüne taşınır
// ---------------------------------------------------------------
class TodosBody extends StatefulWidget {
  final String date; // yyyy-MM-dd (ana ekrandaki seçili gün)
  const TodosBody({super.key, required this.date});

  @override
  State<TodosBody> createState() => _TodosBodyState();
}

class _TodosBodyState extends State<TodosBody> {
  final _c = TextEditingController();

  // Sağa kaydırma: bırakıldığı andaki ilerleme (0..1)
  final ValueNotifier<double> _swipe = ValueNotifier<double>(0);
  bool _released = false;
  static const _tomorrowAt = 0.6;

  @override
  void dispose() {
    _swipe.dispose();
    _c.dispose();
    super.dispose();
  }

  void _add() {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    store.addTodo(t, day: widget.date);
    _c.clear();
  }

  /// Sesle madde ekle: önce kayıt, sonra başlık sorulur
  Future<void> _addVoice() async {
    final name = await recordVoice(context);
    if (name == null || !mounted) return;
    final n = DateTime.now();
    final def =
        '${tx('Ses kaydı')} ${n.hour.toString().padLeft(2, '0')}:${n.minute.toString().padLeft(2, '0')}';
    final t = await askText(context, tx('Başlık'),
        initial: def, label: tx('Madde başlığı'));
    final title = (t == null || t.trim().isEmpty) ? def : t.trim();
    store.addTodo(title, voice: name, day: widget.date);
  }

  Future<void> _clearDone(int count) async {
    final ok = await confirmDialog(
      context,
      tx('Tamamlananlar silinsin mi?'),
      tx('{0} madde silinecek.', [count]),
      okLabel: tx('Sil'),
    );
    if (ok) store.clearDoneTodos(day: widget.date);
  }

  /// Maddeyi siler ve "Geri al" çubuğunu gösterir
  void _delete(Todo t) {
    final index = store.indexOfTodo(t.id);
    Notifier.cancelTodo(t);
    store.deleteTodo(t.id);
    showUndo(context, tx('Madde silindi'), () {
      store.restoreTodo(t, index: index);
      Notifier.syncTodo(t);
    });
  }

  /// Maddeyi ertesi güne gönderir (hatırlatma saati de bir gün kayar)
  void _tomorrow(Todo t) {
    final oldDay = t.day;
    final oldRemind = t.remindMs;
    final d = parseKey(t.day);
    final next = dKey(DateTime(d.year, d.month, d.day + 1));
    final id = t.id;
    store.moveTodo(id, next);
    final n = store.todoById(id);
    if (n != null) Notifier.syncTodo(n);
    showUndo(context, tx('Yarına gönderildi'), () {
      store.moveTodo(id, oldDay, remindMs: oldRemind);
      final b = store.todoById(id);
      if (b != null) Notifier.syncTodo(b);
    });
  }

  Future<void> _edit(Todo t) async {
    final v = await askText(context, tx('Maddeyi düzenle'), initial: t.text);
    if (v != null) {
      store.editTodo(t.id, v);
      final n = store.todoById(t.id);
      if (n != null) Notifier.syncTodo(n);
    }
  }

  void _reorder(List<Todo> all, int oldI, int newI) {
    if (newI > oldI) newI -= 1;
    final ids = [for (final t in all) t.id];
    final id = ids.removeAt(oldI);
    ids.insert(newI, id);
    store.setTodoOrder(ids);
  }

  Widget _bg(Color c, IconData i, String label, Alignment a) => Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration:
            BoxDecoration(color: c, borderRadius: BorderRadius.circular(12)),
        alignment: a,
        padding: const EdgeInsets.symmetric(horizontal: 18),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (a == Alignment.centerLeft) Icon(i),
            if (label.isNotEmpty) ...[
              const SizedBox(width: 6),
              Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(width: 6),
            ],
            if (a != Alignment.centerLeft) Icon(i),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);

        // Seçili günün maddeleri; tamamlananlar altta
        final day = store.todosFor(widget.date);
        final open = day.where((t) => !t.done).toList();
        final done = day.where((t) => t.done).toList();
        final all = [...open, ...done];
        final tomBg = p.dark ? const Color(0xFF5E4A2E) : const Color(0xFFF8E3C2);

        return Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // ----- Madde ekleme kutusu -----
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 4, 4, 4),
              child: Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: _c,
                      textCapitalization: TextCapitalization.sentences,
                      textInputAction: TextInputAction.done,
                      onSubmitted: (_) => _add(),
                      decoration: InputDecoration(
                        hintText: tx('Yeni madde ekle'),
                        isDense: true,
                        filled: true,
                        fillColor: p.card,
                        contentPadding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 12),
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(12),
                          borderSide: BorderSide(color: p.line),
                        ),
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: tx('Sesle ekle'),
                    onPressed: _addVoice,
                    icon: const Icon(Icons.mic_rounded, size: 28),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                  IconButton(
                    onPressed: _add,
                    icon: const Icon(Icons.add_circle_rounded, size: 30),
                    color: Theme.of(context).colorScheme.primary,
                  ),
                ],
              ),
            ),
            if (done.isNotEmpty)
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => _clearDone(done.length),
                  child: Text(tx('Tamamlananları temizle')),
                ),
              ),
            if (all.isEmpty)
              Padding(
                padding: const EdgeInsets.all(20),
                child: Text(
                  tx('Bu gün için madde yok. Yukarıdan ekleyebilirsin.'),
                  textAlign: TextAlign.center,
                  style: TextStyle(color: p.soft),
                ),
              )
            else
              ReorderableListView.builder(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                padding: const EdgeInsets.fromLTRB(8, 4, 8, 8),
                buildDefaultDragHandles: false,
                itemCount: all.length,
                onReorder: (o, n) => _reorder(all, o, n),
                itemBuilder: (context, i) {
                  final t = all[i];
                  return Dismissible(
                    key: ValueKey('td_${t.id}'),
                    dismissThresholds: const {
                      DismissDirection.startToEnd: 0.25,
                      DismissDirection.endToStart: 0.4,
                    },
                    onUpdate: (d) {
                      // Bırakıldıktan sonraki animasyonu sayma
                      if (!_released && d.direction == DismissDirection.startToEnd) {
                        _swipe.value = d.progress;
                      }
                    },
                    background: ValueListenableBuilder<double>(
                      valueListenable: _swipe,
                      builder: (_, v, __) => v >= _tomorrowAt
                          ? _bg(tomBg, Icons.event_rounded, tx('Yarına'),
                              Alignment.centerLeft)
                          : _bg(p.editBg, Icons.edit_rounded, tx('Düzenle'),
                              Alignment.centerLeft),
                    ),
                    secondaryBackground: _bg(
                        p.delBg, Icons.delete_outline_rounded, '',
                        Alignment.centerRight),
                    confirmDismiss: (dir) async {
                      if (dir == DismissDirection.startToEnd) {
                        final full = _swipe.value >= _tomorrowAt;
                        _swipe.value = 0;
                        if (full) {
                          _tomorrow(t);
                        } else {
                          _edit(t);
                        }
                        return false;
                      }
                      return true;
                    },
                    onDismissed: (_) => _delete(t),
                    child: Listener(
                      behavior: HitTestBehavior.translucent,
                      onPointerDown: (_) {
                        _released = false;
                        _swipe.value = 0;
                      },
                      onPointerUp: (_) => _released = true,
                      onPointerCancel: (_) => _released = true,
                      child: Padding(
                        padding: const EdgeInsets.only(bottom: 8),
                        child: Material(
                          color: t.done ? p.bg : p.card,
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(12),
                            side: BorderSide(color: p.line),
                          ),
                          clipBehavior: Clip.antiAlias,
                          child: Row(
                            children: [
                              Expanded(
                                child: CheckboxListTile(
                                  value: t.done,
                                  onChanged: (_) {
                                    store.toggleTodo(t.id);
                                    final n = store.todoById(t.id);
                                    if (n != null) Notifier.syncTodo(n);
                                  },
                                  controlAffinity:
                                      ListTileControlAffinity.leading,
                                  title: Text.rich(
                                    TextSpan(children: [
                                      TextSpan(text: t.text),
                                      if (t.voice.isNotEmpty)
                                        WidgetSpan(
                                          alignment:
                                              PlaceholderAlignment.middle,
                                          child: Padding(
                                            padding:
                                                const EdgeInsets.only(left: 6),
                                            child: Icon(Icons.mic_rounded,
                                                size: 16, color: p.soft),
                                          ),
                                        ),
                                    ]),
                                    style: TextStyle(
                                      color: t.done ? p.soft : p.ink,
                                      decoration: t.done
                                          ? TextDecoration.lineThrough
                                          : null,
                                    ),
                                  ),
                                  subtitle: t.remindMs > 0 && !t.done
                                      ? Text(
                                          '🔔 ${dtLabel(t.remindMs)}',
                                          style: TextStyle(
                                              fontSize: 12, color: p.soft),
                                        )
                                      : null,
                                ),
                              ),
                              if (t.voice.isNotEmpty)
                                VoicePlayButton(name: t.voice, title: t.text),
                              IconButton(
                                visualDensity: VisualDensity.compact,
                                onPressed: () =>
                                    showTodoReminderDialog(context, t),
                                icon: Icon(
                                  t.remindMs > 0
                                      ? Icons.notifications_active_rounded
                                      : Icons.notifications_none_rounded,
                                  size: 22,
                                  color: t.remindMs > 0
                                      ? Theme.of(context).colorScheme.primary
                                      : p.soft,
                                ),
                              ),
                              ReorderableDragStartListener(
                                index: i,
                                child: Padding(
                                  padding:
                                      const EdgeInsets.fromLTRB(4, 8, 12, 8),
                                  child: Icon(Icons.drag_handle_rounded,
                                      color: p.soft),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  );
                },
              ),
          ],
        );
      },
    );
  }
}
