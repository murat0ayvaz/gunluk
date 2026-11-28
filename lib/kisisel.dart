import 'package:flutter/material.dart';
import 'ambient.dart';
import 'data.dart';
import 'manage.dart';
import 'strings.dart';
import 'todos.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// Araçlar > Kişisel: Rutinler ve Yapılacaklar sayfaları.
// Ana ekrana bölüm olarak eklenip çıkarılabilir ("Ana ekrana ekle" anahtarı).
// ---------------------------------------------------------------

class RoutinesPage extends StatelessWidget {
  const RoutinesPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final date = dKey(now);
        final rows = <(String, bool)>[];
        for (final c in store.cats) {
          for (final s in c.subs) {
            if (!s.scheduledOn(now)) continue;
            final e = store.entryFor(s.id, date);
            rows.add((s.name, e != null && goalMet(s, e.value)));
          }
        }
        final met = rows.where((r) => r.$2).length;
        return AmbScaffold(
          kind: 'settings',
          backgroundColor: ambBg(p),
          appBar: AppBar(
            backgroundColor: ambBg(p),
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text('${tx('Rutinler')} $met/${rows.length}'),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              SwitchListTile(
                dense: true,
                secondary: const Icon(Icons.home_rounded),
                title: Text(tx('Ana ekrana ekle')),
                value: store.homeOn('routine'),
                onChanged: (v) => store.setHomeOn('routine', v),
              ),
              ListTile(
                leading: const Icon(Icons.tune_rounded),
                title: Text(tx('Rutinleri düzenle')),
                trailing: const Icon(Icons.chevron_right_rounded),
                onTap: () => Navigator.of(context)
                    .push(MaterialPageRoute<void>(builder: (_) => const ManagePage())),
              ),
              const Divider(),
              if (rows.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(tx('Bugün için rutin yok'), style: TextStyle(color: p.soft)),
                ),
              for (final r in rows)
                ListTile(
                  dense: true,
                  leading: Icon(
                      r.$2 ? Icons.check_circle_rounded : Icons.radio_button_unchecked_rounded,
                      color: r.$2 ? p.accent : p.soft),
                  title: Text(r.$1,
                      style: TextStyle(
                          color: r.$2 ? p.soft : p.ink,
                          decoration: r.$2 ? TextDecoration.lineThrough : null)),
                ),
            ],
          ),
        );
      },
    );
  }
}

class TodosPage extends StatelessWidget {
  const TodosPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final date = dKey(DateTime.now());
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => AmbScaffold(
        kind: 'settings',
        backgroundColor: ambBg(p),
        appBar: AppBar(
          backgroundColor: ambBg(p),
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(tx('Yapılacaklar')),
        ),
        floatingActionButton: FloatingActionButton(
          onPressed: () => showAddTodo(context, date),
          child: const Icon(Icons.add_rounded),
        ),
        body: ListView(
          padding: const EdgeInsets.only(bottom: 90),
          children: [
            SwitchListTile(
              dense: true,
              secondary: const Icon(Icons.home_rounded),
              title: Text(tx('Ana ekrana ekle')),
              value: store.homeOn('todo'),
              onChanged: (v) => store.setHomeOn('todo', v),
            ),
            TodosBody(date: date),
          ],
        ),
      ),
    );
  }
}
