import 'package:flutter/material.dart';
import 'data.dart';
import 'manage.dart';
import 'settings.dart';
import 'stats.dart';
import 'strings.dart';
import 'todos.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// SOLDAKİ MENÜ ("Günlük" yazısına dokununca açılır)
//  - Bugün, Yapılacaklar
//  - Kategoriler -> alt kategoriye dokununca istatistik ekranı
//  - Kategorileri düzenle / Ayarlar (tema + dil)
// ---------------------------------------------------------------
class AppDrawer extends StatelessWidget {
  final VoidCallback onToday;
  const AppDrawer({super.key, required this.onToday});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        final nav = Navigator.of(context);

        return Drawer(
          backgroundColor: p.bg,
          child: SafeArea(
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
                  child: Row(
                    children: [
                      Container(
                        width: 44,
                        height: 44,
                        decoration: BoxDecoration(
                            color: p.accent, shape: BoxShape.circle),
                        child: Icon(Icons.checklist_rounded, color: p.onAccent),
                      ),
                      const SizedBox(width: 12),
                      Text(tx('Günlük'),
                          style: TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.w700,
                              color: p.ink)),
                    ],
                  ),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      ListTile(
                        leading: const Icon(Icons.today_rounded),
                        title: Text(tx('Bugün')),
                        onTap: () {
                          nav.pop();
                          onToday();
                        },
                      ),
                      ListTile(
                        leading: const Icon(Icons.task_alt_rounded),
                        title: Text(tx('Yapılacaklar')),
                        onTap: () {
                          nav.pop();
                          nav.push(MaterialPageRoute<void>(
                              builder: (_) => const TodosPage()));
                        },
                      ),
                      Divider(color: p.line),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(20, 4, 20, 4),
                        child: Text(tx('Kategoriler'),
                            style: TextStyle(color: p.soft, fontSize: 13)),
                      ),
                      for (final c in store.cats)
                        ExpansionTile(
                          shape: const Border(),
                          collapsedShape: const Border(),
                          title: Text(c.name,
                              style:
                                  const TextStyle(fontWeight: FontWeight.w600)),
                          children: [
                            if (c.subs.isEmpty)
                              Padding(
                                padding: const EdgeInsets.fromLTRB(32, 0, 16, 12),
                                child: Text(tx('Alt kategori yok'),
                                    style: TextStyle(color: p.soft)),
                              ),
                            for (final s in c.subs)
                              ListTile(
                                contentPadding:
                                    const EdgeInsets.only(left: 32, right: 20),
                                title: Text(s.name),
                                trailing: Text(s.unit,
                                    style: TextStyle(color: p.soft)),
                                onTap: () {
                                  nav.pop();
                                  nav.push(MaterialPageRoute<void>(
                                      builder: (_) => StatsPage(subId: s.id)));
                                },
                              ),
                          ],
                        ),
                      if (store.cats.isEmpty)
                        Padding(
                          padding: const EdgeInsets.all(20),
                          child: Text(
                              tx('Henüz kategori yok. “Kategorileri düzenle” veya Ekle ile oluşturabilirsin.'),
                              style: TextStyle(color: p.soft)),
                        ),
                    ],
                  ),
                ),
                Divider(color: p.line, height: 1),
                ListTile(
                  leading: const Icon(Icons.tune_rounded),
                  title: Text(tx('Kategorileri düzenle')),
                  onTap: () {
                    nav.pop();
                    nav.push(MaterialPageRoute<void>(
                        builder: (_) => const ManagePage()));
                  },
                ),
                ListTile(
                  leading: const Icon(Icons.settings_outlined),
                  title: Text(tx('Ayarlar')),
                  onTap: () {
                    nav.pop();
                    nav.push(MaterialPageRoute<void>(
                        builder: (_) => const SettingsPage()));
                  },
                ),
                const SizedBox(height: 8),
              ],
            ),
          ),
        );
      },
    );
  }
}
