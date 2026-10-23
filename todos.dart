import 'dart:async';
import 'package:flutter/material.dart';
import 'data.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// YAPILACAKLAR: checkbox'lı basit liste (tarihten bağımsız)
// Ana ekranın altındaki panelde "Yapılacaklar" başlığına dokununca açılır.
//  - Üstteki kutudan madde ekle
//  - Checkbox ile işaretle: tamamlananlar üstü çizili olarak alta iner
//  - Sola kaydırarak sil: "Geri al" çubuğu 5 saniye durur, sonra kaybolur
//  - Sağdaki "Tamamlananları temizle" ile işaretlileri toplu sil
// ---------------------------------------------------------------
class TodosBody extends StatefulWidget {
  const TodosBody({super.key});

  @override
  State<TodosBody> createState() => _TodosBodyState();
}

class _TodosBodyState extends State<TodosBody> {
  final _c = TextEditingController();
  Todo? _deleted; // geri alınabilecek son silinen madde
  Timer? _timer;

  @override
  void dispose() {
    _timer?.cancel();
    _c.dispose();
    super.dispose();
  }

  void _add() {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    store.addTodo(t);
    _c.clear();
  }

  Future<void> _clearDone(int count) async {
    final ok = await confirmDialog(
      context,
      tx('Tamamlananlar silinsin mi?'),
      tx('{0} madde silinecek.', [count]),
      okLabel: tx('Sil'),
    );
    if (ok) store.clearDoneTodos();
  }

  /// Maddeyi siler ve 5 saniyelik "Geri al" çubuğunu gösterir
  void _delete(Todo t) {
    store.deleteTodo(t.id);
    _timer?.cancel();
    setState(() => _deleted = t);
    _timer = Timer(const Duration(seconds: 5), () {
      if (mounted) setState(() => _deleted = null);
    });
  }

  void _undo() {
    final t = _deleted;
    if (t == null) return;
    _timer?.cancel();
    store.restoreTodo(t);
    setState(() => _deleted = null);
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);

        // Yapılmayanlar eklenme sırasıyla, tamamlananlar altta
        final open = store.todos.where((t) => !t.done).toList()
          ..sort((a, b) => a.created.compareTo(b.created));
        final done = store.todos.where((t) => t.done).toList()
          ..sort((a, b) => a.created.compareTo(b.created));
        final all = [...open, ...done];

        return Column(
          children: [
            // ----- Madde ekleme kutusu -----
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
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
                child: Padding(
                  padding: const EdgeInsets.only(right: 8),
                  child: TextButton(
                    onPressed: () => _clearDone(done.length),
                    child: Text(tx('Tamamlananları temizle')),
                  ),
                ),
              ),
            Expanded(
              child: all.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.all(32),
                        child: Text(
                          tx('Henüz madde yok. Yukarıdan ekleyebilirsin.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.soft),
                        ),
                      ),
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
                      children: [
                        for (final t in all)
                          Padding(
                            padding: const EdgeInsets.only(bottom: 8),
                            child: ClipRRect(
                              borderRadius: BorderRadius.circular(12),
                              child: Dismissible(
                                key: ValueKey('td_${t.id}'),
                                direction: DismissDirection.endToStart,
                                background: Container(
                                  color: p.delBg,
                                  alignment: Alignment.centerRight,
                                  padding:
                                      const EdgeInsets.symmetric(horizontal: 22),
                                  child:
                                      const Icon(Icons.delete_outline_rounded),
                                ),
                                onDismissed: (_) => _delete(t),
                                child: Material(
                                  color: t.done ? p.bg : p.card,
                                  shape: RoundedRectangleBorder(
                                    borderRadius: BorderRadius.circular(12),
                                    side: BorderSide(color: p.line),
                                  ),
                                  clipBehavior: Clip.antiAlias,
                                  child: CheckboxListTile(
                                    value: t.done,
                                    onChanged: (_) => store.toggleTodo(t.id),
                                    controlAffinity:
                                        ListTileControlAffinity.leading,
                                    title: Text(
                                      t.text,
                                      style: TextStyle(
                                        color: t.done ? p.soft : p.ink,
                                        decoration: t.done
                                            ? TextDecoration.lineThrough
                                            : null,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                      ],
                    ),
            ),
            // ----- 5 saniyelik "Geri al" çubuğu -----
            if (_deleted != null)
              Container(
                margin: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 4),
                decoration: BoxDecoration(
                  color:
                      p.dark ? const Color(0xFF3A3E45) : const Color(0xFF33363B),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(tx('Madde silindi'),
                          style: const TextStyle(color: Colors.white)),
                    ),
                    TextButton(
                      onPressed: _undo,
                      child: Text(tx('Geri al'),
                          style: const TextStyle(color: Color(0xFFA6D4B0))),
                    ),
                  ],
                ),
              ),
          ],
        );
      },
    );
  }
}
