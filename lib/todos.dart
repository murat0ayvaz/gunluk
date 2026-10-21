import 'package:flutter/material.dart';
import 'data.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// YAPILACAKLAR: checkbox'lı basit liste (tarihten bağımsız)
//  - Üstteki kutudan madde ekle
//  - Checkbox ile işaretle: tamamlananlar üstü çizili olarak alta iner
//  - Sola kaydırarak sil (Geri al ile)
//  - Sağ üstten "Tamamlananları temizle"
// ---------------------------------------------------------------
class TodosPage extends StatefulWidget {
  const TodosPage({super.key});

  @override
  State<TodosPage> createState() => _TodosPageState();
}

class _TodosPageState extends State<TodosPage> {
  final _c = TextEditingController();

  @override
  void dispose() {
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

  void _delete(Todo t) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    store.deleteTodo(t.id);
    messenger.showSnackBar(SnackBar(
      content: Text(tx('Madde silindi')),
      action: SnackBarAction(
          label: tx('Geri al'), onPressed: () => store.restoreTodo(t)),
    ));
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

        return Scaffold(
          appBar: AppBar(
            backgroundColor: p.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(tx('Yapılacaklar')),
            actions: [
              if (done.isNotEmpty)
                TextButton(
                  onPressed: () => _clearDone(done.length),
                  child: Text(tx('Tamamlananları temizle')),
                ),
            ],
          ),
          body: Column(
            children: [
              // ----- Madde ekleme kutusu -----
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
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
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
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
                                    child: const Icon(
                                        Icons.delete_outline_rounded),
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
            ],
          ),
        );
      },
    );
  }
}
