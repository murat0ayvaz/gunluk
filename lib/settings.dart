import 'package:flutter/material.dart';
import 'data.dart';
import 'intro.dart';
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// AYARLAR: dil (Türkçe / English), tema (görünüm + vurgu rengi),
// tanıtımı tekrar göster.
// Dil değişince adı değiştirilmemiş hazır kategoriler de çevrilir.
// ---------------------------------------------------------------
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        final dark = p.dark;

        Widget title(String s) => Padding(
              padding: const EdgeInsets.only(top: 20, bottom: 10),
              child: Text(s,
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: p.ink)),
            );

        return Scaffold(
          appBar: AppBar(
            backgroundColor: p.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(tx('Ayarlar')),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
            children: [
              // ----- Dil -----
              title(tx('Dil')),
              Wrap(spacing: 8, children: [
                ChoiceChip(
                  label: const Text('Türkçe'),
                  selected: store.lang == 'tr',
                  onSelected: (_) => store.setLang('tr'),
                ),
                ChoiceChip(
                  label: const Text('English'),
                  selected: store.lang == 'en',
                  onSelected: (_) => store.setLang('en'),
                ),
              ]),
              const SizedBox(height: 8),
              Text(
                tx('Kendi eklediğin kategori ve alt kategori adları çevrilmez. Adını değiştirmediğin hazır kategoriler yeni dile çevrilir.'),
                style: TextStyle(fontSize: 12.5, color: p.soft, height: 1.4),
              ),

              // ----- Tema -----
              title(tx('Tema')),
              Text(tx('Görünüm'), style: TextStyle(color: p.soft)),
              const SizedBox(height: 8),
              Wrap(spacing: 8, children: [
                ChoiceChip(
                  label: Text(tx('Telefona uy')),
                  selected: store.themeMode == ThemeMode.system,
                  onSelected: (_) => store.setThemeMode(ThemeMode.system),
                ),
                ChoiceChip(
                  label: Text(tx('Açık')),
                  selected: store.themeMode == ThemeMode.light,
                  onSelected: (_) => store.setThemeMode(ThemeMode.light),
                ),
                ChoiceChip(
                  label: Text(tx('Koyu')),
                  selected: store.themeMode == ThemeMode.dark,
                  onSelected: (_) => store.setThemeMode(ThemeMode.dark),
                ),
              ]),
              const SizedBox(height: 18),
              Text(tx('Vurgu rengi'), style: TextStyle(color: p.soft)),
              const SizedBox(height: 10),
              Wrap(
                spacing: 12,
                runSpacing: 8,
                children: [
                  for (var i = 0; i < accentColors.length; i++)
                    GestureDetector(
                      onTap: () => store.setAccent(i),
                      child: Column(
                        children: [
                          Container(
                            width: 44,
                            height: 44,
                            decoration: BoxDecoration(
                              color: accentFor(i, dark),
                              shape: BoxShape.circle,
                              border: Border.all(
                                color: store.accent == i ? p.ink : p.line,
                                width: store.accent == i ? 2.5 : 1,
                              ),
                            ),
                            child: store.accent == i
                                ? Icon(Icons.check_rounded, color: p.onAccent)
                                : null,
                          ),
                          const SizedBox(height: 4),
                          Text(tx(accentNames[i]),
                              style: TextStyle(fontSize: 11, color: p.soft)),
                        ],
                      ),
                    ),
                ],
              ),

              // ----- Tanıtım -----
              title(tx('Tanıtım')),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.help_outline_rounded),
                title: Text(tx('Tanıtımı göster')),
                onTap: () {
                  Navigator.of(context).push(MaterialPageRoute<void>(
                    builder: (ctx) =>
                        IntroPage(onDone: () => Navigator.pop(ctx)),
                  ));
                },
              ),
            ],
          ),
        );
      },
    );
  }
}
