import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'about.dart';
import 'intro.dart';
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';
import 'version.dart';

// ---------------------------------------------------------------
// AYARLAR: dil (Türkçe / English), tema (görünüm + vurgu rengi),
// tanıtımı tekrar göster.
// Dil değişince adı değiştirilmemiş hazır kategoriler de çevrilir.
// ---------------------------------------------------------------
class SettingsPage extends StatelessWidget {
  const SettingsPage({super.key});

  void _snack(BuildContext context, String msg) {
    final m = ScaffoldMessenger.of(context);
    m.clearSnackBars();
    m.showSnackBar(SnackBar(
      content: Text(msg),
      duration: const Duration(seconds: 5),
      persist: false,
    ));
  }

  /// Tüm veriyi metin olarak panoya kopyalar
  Future<void> _copyBackup(BuildContext context) async {
    await Clipboard.setData(ClipboardData(text: store.exportBackup()));
    if (!context.mounted) return;
    _snack(context,
        tx('Yedek panoya kopyalandı. Güvenli bir yere yapıştırıp sakla.'));
  }

  /// Yapıştırılan yedek metniyle tüm veriyi değiştirir
  Future<void> _restore(BuildContext context) async {
    final text = await showDialog<String>(
      context: context,
      builder: (_) => const _RestoreDialog(),
    );
    if (text == null || !context.mounted) return;
    final ok = await confirmDialog(
      context,
      tx('Geri yüklensin mi?'),
      tx('Mevcut verilerin yedekteki verilerle değiştirilecek. Devam edilsin mi?'),
      okLabel: tx('Geri yükle'),
    );
    if (!ok || !context.mounted) return;
    final err = store.importBackup(text);
    if (!context.mounted) return;
    _snack(context, err ?? tx('Yedek geri yüklendi.'));
  }

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

              // ----- Özlü sözler -----
              title(tx('Özlü sözler')),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(tx('Ana ekranda özlü söz göster')),
                value: store.quotesOn,
                onChanged: store.setQuotesOn,
              ),
              if (store.quotesOn) ...[
                const SizedBox(height: 4),
                Text(tx('Türler'), style: TextStyle(color: p.soft)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final k in [
                    ['motivation', tx('Motivasyon')],
                    ['ayet', tx('Ayet')],
                    ['hadis', tx('Hadis')],
                    ['custom', tx('Kendi sözlerim')],
                  ])
                    FilterChip(
                      label: Text(k[1]),
                      selected: store.quoteKinds.contains(k[0]),
                      onSelected: (_) => store.toggleQuoteKind(k[0]),
                    ),
                ]),
                const SizedBox(height: 16),
                Text(tx('Ne sıklıkla değişsin?'),
                    style: TextStyle(color: p.soft)),
                const SizedBox(height: 8),
                Wrap(spacing: 8, runSpacing: 4, children: [
                  for (final h in [
                    [0, tx('Her açılışta')],
                    [1, tx('Saatte bir')],
                    [3, tx('3 saatte bir')],
                    [6, tx('6 saatte bir')],
                    [12, tx('12 saatte bir')],
                    [24, tx('Günde bir')],
                  ])
                    ChoiceChip(
                      label: Text(h[1] as String),
                      selected: store.quoteHours == h[0],
                      onSelected: (_) => store.setQuoteHours(h[0] as int),
                    ),
                ]),
                const SizedBox(height: 8),
                ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.edit_outlined),
                  title: Text(tx('Kendi sözlerimi yönet')),
                  trailing: Text('${store.customQuotes.length}',
                      style: TextStyle(color: p.soft)),
                  onTap: () {
                    Navigator.of(context).push(MaterialPageRoute<void>(
                        builder: (_) => const CustomQuotesPage()));
                  },
                ),
                Text(
                  tx('Ayet ve hadisler kısa meâl / anlam özetleridir; kaynak numaraları baskıya göre değişebilir. Önemli bir yerde kullanmadan önce kaynağından doğrulamanı öneririz.'),
                  style: TextStyle(fontSize: 12.5, color: p.soft, height: 1.4),
                ),
              ],

              // ----- Yedek -----
              title(tx('Yedek')),
              Text(
                tx('Uygulamayı kaldırırsan tüm verilerin silinir. Kaldırmadan önce yedek al: yedek metin olarak panoya kopyalanır; bir not uygulamasına ya da kendine mesaj olarak yapıştırıp sakla. Yedek, günlük notların dahil tüm verini içerir; sakladığın yeri başkalarıyla paylaşma.'),
                style: TextStyle(fontSize: 12.5, color: p.soft, height: 1.4),
              ),
              const SizedBox(height: 10),
              Wrap(spacing: 8, runSpacing: 8, children: [
                FilledButton.icon(
                  onPressed: () => _copyBackup(context),
                  icon: const Icon(Icons.copy_rounded),
                  label: Text(tx('Yedeği kopyala')),
                ),
                OutlinedButton.icon(
                  onPressed: () => _restore(context),
                  icon: const Icon(Icons.restore_rounded),
                  label: Text(tx('Yedeği geri yükle')),
                ),
              ]),

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

              // ----- Hakkında -----
              title(tx('Hakkında')),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.new_releases_outlined),
                title: Text(tx('Yenilikler')),
                onTap: () => showWhatsNew(context),
              ),
              ListTile(
                contentPadding: EdgeInsets.zero,
                leading: const Icon(Icons.info_outline_rounded),
                title: Text(tx('Sürüm')),
                trailing: Text('$appVersion ($appBuild)',
                    style: TextStyle(color: p.soft)),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------
// KENDİ SÖZLERİM: kendi özlü sözlerini ekle / sil
// ("Kendi sözlerim" türü açıkken ana ekranda diğerleriyle birlikte döner)
// ---------------------------------------------------------------
class CustomQuotesPage extends StatefulWidget {
  const CustomQuotesPage({super.key});

  @override
  State<CustomQuotesPage> createState() => _CustomQuotesPageState();
}

class _CustomQuotesPageState extends State<CustomQuotesPage> {
  final _c = TextEditingController();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  void _add() {
    final t = _c.text.trim();
    if (t.isEmpty) return;
    store.addCustomQuote(t);
    _c.clear();
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        return Scaffold(
          appBar: AppBar(
            backgroundColor: p.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(tx('Kendi sözlerim')),
          ),
          body: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 4, 8, 8),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _c,
                        textCapitalization: TextCapitalization.sentences,
                        minLines: 1,
                        maxLines: 4,
                        decoration: InputDecoration(
                          hintText: tx('Yeni söz yaz'),
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
                child: store.customQuotes.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            tx('Henüz kendi sözün yok. Yukarıdan ekleyebilirsin.'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.soft),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
                        children: [
                          for (var i = 0; i < store.customQuotes.length; i++)
                            Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.fromLTRB(14, 6, 4, 6),
                              decoration: BoxDecoration(
                                color: p.card,
                                borderRadius: BorderRadius.circular(12),
                                border: Border.all(color: p.line),
                              ),
                              child: Row(
                                children: [
                                  Expanded(
                                    child: Text(store.customQuotes[i],
                                        style: TextStyle(
                                            color: p.ink, height: 1.35)),
                                  ),
                                  IconButton(
                                    tooltip: tx('Sil'),
                                    icon: const Icon(
                                        Icons.delete_outline_rounded),
                                    onPressed: () => store.deleteCustomQuote(i),
                                  ),
                                ],
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

// ---------------------------------------------------------------
// YEDEĞİ GERİ YÜKLE penceresi: yedek metni buraya yapıştırılır
// ---------------------------------------------------------------
class _RestoreDialog extends StatefulWidget {
  const _RestoreDialog();

  @override
  State<_RestoreDialog> createState() => _RestoreDialogState();
}

class _RestoreDialogState extends State<_RestoreDialog> {
  final _c = TextEditingController();
  String? _err;

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  Future<void> _paste() async {
    final d = await Clipboard.getData(Clipboard.kTextPlain);
    if (d?.text != null && mounted) {
      setState(() {
        _c.text = d!.text!;
        _err = null;
      });
    }
  }

  void _ok() {
    final t = _c.text.trim();
    if (t.isEmpty) {
      setState(() => _err = tx('Yedek metni boş'));
      return;
    }
    Navigator.pop(context, t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(tx('Yedeği geri yükle')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          TextField(
            controller: _c,
            minLines: 4,
            maxLines: 6,
            decoration: InputDecoration(
              hintText: tx('Yedek metnini buraya yapıştır'),
              errorText: _err,
              border: const OutlineInputBorder(),
            ),
          ),
          const SizedBox(height: 8),
          TextButton.icon(
            onPressed: _paste,
            icon: const Icon(Icons.content_paste_rounded),
            label: Text(tx('Panodan yapıştır')),
          ),
        ],
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tx('Vazgeç'))),
        FilledButton(onPressed: _ok, child: Text(tx('Geri yükle'))),
      ],
    );
  }
}
