import 'package:flutter/material.dart';
import 'ambient.dart';
import 'data.dart';
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// ANA EKRAN DÜZENİ
//  Bölümleri (hava, namaz, Rutinler, Yapılacaklar, Günlük, Hatırlatıcı, Diğer kayıtlar)
//  ve üst bardaki simgeleri tutup sürükleyerek sırala. Simgeler açılıp kapatılabilir.
//  Tema 3'te hava ve namaz alttadır; bunların sırası kendi aralarında değişir.
// ---------------------------------------------------------------
const _secNames = {
  'wx': ('Hava durumu', Icons.wb_sunny_outlined),
  'pr': ('Namaz vakitleri', Icons.mosque_rounded),
  'routine': ('Rutinler', Icons.checklist_rounded),
  'todo': ('Yapılacaklar', Icons.task_alt_rounded),
  'note': ('Günlük', Icons.menu_book_rounded),
  'rem': ('Hatırlatıcı', Icons.notifications_active_outlined),
  'memo': ('Notlar', Icons.sticky_note_2_outlined),
  'other': ('Diğer kayıtlar', Icons.more_horiz_rounded),
};

const _iconNames = {
  'menu': ('Menü', Icons.menu_rounded),
  'study': ('Ders çalışma', Icons.menu_book_rounded),
  'short': ('Kısayollar', Icons.apps_rounded),
  'mic': ('Mikrofon', Icons.mic_none_rounded),
  'tools': ('Araçlar', Icons.handyman_outlined),
  'media': ('Medya', Icons.play_circle_rounded),
};

class HomeLayoutPage extends StatelessWidget {
  const HomeLayoutPage({super.key});

  Widget _head(Pal p, String t) => Padding(
        padding: const EdgeInsets.fromLTRB(4, 16, 4, 6),
        child: Text(t,
            style: TextStyle(
                color: p.soft, fontWeight: FontWeight.w700, fontSize: 13)),
      );

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => AmbScaffold(kind: 'settings', 
        backgroundColor: ambBg(p),
        appBar: AppBar(
          backgroundColor: ambBg(p),
          elevation: 0,
          scrolledUnderElevation: 0,
          title: Text(tx('Ana ekran düzeni')),
          actions: [
            TextButton(
              onPressed: store.resetHomeLayout,
              child: Text(tx('Sıfırla')),
            ),
          ],
        ),
        body: ListView(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
          children: [
            _head(p, tx('Üst bar simgeleri')),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              buildDefaultDragHandles: true,
              onReorder: (o, n) {
                final l = List<String>.of(store.iconOrder);
                if (n > o) n -= 1;
                l.insert(n, l.removeAt(o));
                store.setIconOrder(l);
              },
              children: [
                for (final id in store.iconOrder)
                  Card(
                    key: ValueKey('ic_$id'),
                    margin: const EdgeInsets.only(bottom: 6),
                    color: p.card,
                    child: SwitchListTile(
                      secondary: Icon(_iconNames[id]!.$2),
                      title: Text(tx(_iconNames[id]!.$1)),
                      // menü simgesi kapatılamaz (uygulamaya giriş yolu)
                      value: id == 'menu' || !store.iconOff.contains(id),
                      onChanged:
                          id == 'menu' ? null : (v) => store.setIconOn(id, v),
                    ),
                  ),
              ],
            ),
            _head(p, tx('Ana ekran bölümleri')),
            ReorderableListView(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              onReorder: (o, n) {
                final l = List<String>.of(store.secOrder);
                if (n > o) n -= 1;
                l.insert(n, l.removeAt(o));
                store.setSecOrder(l);
              },
              children: [
                for (final id in store.secOrder)
                  Card(
                    key: ValueKey('sc_$id'),
                    margin: const EdgeInsets.only(bottom: 6),
                    color: p.card,
                    child: ListTile(
                      leading: Icon(_secNames[id]!.$2),
                      title: Text(tx(_secNames[id]!.$1)),
                      trailing: (id == 'wx' || id == 'pr' || id == 'other')
                          ? null
                          : Switch(
                              value: store.homeOn(id),
                              onChanged: (v) => store.setHomeOn(id, v),
                            ),
                    ),
                  ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.only(top: 8),
              child: Text(
                  tx('Anahtar: bölümü ana ekranda göster / gizle (veriler silinmez). Tutup sürükleyerek sırala. Hava ve namaz satırları sabit çubuktur: yalnız kendi aralarındaki sırası değişir (Tema 3\'te altta).'),
                  style: TextStyle(color: p.soft, fontSize: 12.5, height: 1.35)),
            ),
          ],
        ),
      ),
    );
  }
}
