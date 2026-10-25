import 'package:flutter/material.dart';
import 'data.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// KATEGORİLERİ DÜZENLE
// Hazır liste dahil hiçbir şey kilitli değil: kategori ve alt kategori
// eklenebilir, düzenlenebilir (ad, birim, rutin, hedef...) ve silinebilir.
// Silince ilgili geçmiş kayıtlar da silinir (önce onay istenir).
// Kayıtlar kimliğe bağlı olduğu için ad değişince geçmiş bozulmaz.
// ---------------------------------------------------------------
class ManagePage extends StatelessWidget {
  const ManagePage({super.key});

  // ----- Kategori işlemleri -----

  Future<void> _addCategory(BuildContext context) async {
    final name =
        await askText(context, tx('Yeni kategori'), label: tx('Kategori adı'));
    if (name == null) return;
    store.addCategory(name);
  }

  Future<void> _renameCategory(BuildContext context, Category c) async {
    final name = await askText(context, tx('Kategori adı'),
        initial: c.name, label: tx('Kategori adı'));
    if (name == null) return;
    store.renameCategory(c.id, name);
  }

  Future<void> _deleteCategory(BuildContext context, Category c) async {
    final count = store.categoryEntryCount(c.id);
    final ok = await confirmDialog(
      context,
      tx('“{0}” silinsin mi?', [c.name]),
      tx('Bu kategorideki {0} alt kategori ve {1} kayıt kalıcı olarak silinecek.',
          [c.subs.length, count]),
      okLabel: tx('Sil'),
    );
    if (ok) store.deleteCategory(c.id);
  }

  // ----- Alt kategori işlemleri -----

  Future<void> _addSub(BuildContext context, Category c) async {
    final d = await showSubDialog(context,
        title: tx('“{0}” altına alt kategori', [c.name]));
    if (d == null) return;
    store.addSub(c.id, d);
  }

  Future<void> _editSub(BuildContext context, SubCat s) async {
    final d = await showSubDialog(context,
        sub: s, title: tx('Alt kategoriyi düzenle'));
    if (d == null) return;

    // Birim değişirse eski sayılar çevrilmez: önce uyar
    final count = store.entriesOf(s.id).length;
    if (d.unit.trim() != s.unit && count > 0) {
      if (!context.mounted) return;
      final ok = await confirmDialog(
        context,
        tx('Birim değişiyor'),
        tx('Eski kayıtlar çevrilmez. Örneğin “3 lt” olarak girilmiş bir kayıt, yeni birimle “3 {0}” olarak görünür. Devam edilsin mi?',
            [d.unit.trim()]),
        okLabel: tx('Devam'),
      );
      if (!ok) return;
    }
    store.updateSub(s.id, d);
  }

  Future<void> _deleteSub(BuildContext context, SubCat s) async {
    final count = store.entriesOf(s.id).length;
    final ok = await confirmDialog(
      context,
      tx('“{0}” silinsin mi?', [s.name]),
      tx('{0} kayıt da kalıcı olarak silinecek.', [count]),
      okLabel: tx('Sil'),
    );
    if (ok) store.deleteSub(s.id);
  }

  /// Alt satırda gösterilen kısa özet: birim • rutin • hedef
  String _info(SubCat s) {
    final parts = <String>[];
    if (s.unit.isNotEmpty) parts.add(s.unit);
    if (s.routine) {
      parts.add(tx('rutin'));
      if (s.days.length < 7) {
        final ds = (s.days.toList()..sort()).map(wdShort).join(', ');
        parts.add(ds);
      }
    }
    final g = s.goal;
    if (g != null) {
      if (!s.summable) {
        parts.add(tx('hedef değer {0}', [fmt(g)]));
      } else if (s.isMax) {
        parts.add(tx('üst sınır {0}', [fmt(g)]));
      } else {
        parts.add(tx('hedef {0}', [fmt(g)]));
      }
    }
    if (!s.summable) parts.add(tx('toplanmaz'));
    return parts.isEmpty ? tx('Ek ayar yok') : parts.join(' • ');
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
            title: Text(tx('Kategorileri düzenle')),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
            children: [
              if (store.cats.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    tx('Hiç kategori yok. Aşağıdan yeni kategori ekleyebilirsin.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.soft),
                  ),
                ),
              for (final c in store.cats)
                Container(
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(16),
                    border: Border.all(color: p.line),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      // Kategori başlığı: ad değiştir / sil
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 8, 4, 0),
                        child: Row(
                          children: [
                            Expanded(
                              child: Text(c.name,
                                  style: TextStyle(
                                      fontSize: 17,
                                      fontWeight: FontWeight.w700,
                                      color: p.ink)),
                            ),
                            IconButton(
                              tooltip: tx('Adını değiştir'),
                              icon: const Icon(Icons.edit_outlined),
                              onPressed: () => _renameCategory(context, c),
                            ),
                            IconButton(
                              tooltip: tx('Kategoriyi sil'),
                              icon: const Icon(Icons.delete_outline_rounded),
                              onPressed: () => _deleteCategory(context, c),
                            ),
                          ],
                        ),
                      ),
                      // Alt kategoriler
                      for (final s in c.subs)
                        ListTile(
                          title: Text(s.name),
                          subtitle: Text(_info(s)),
                          trailing: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              IconButton(
                                tooltip: tx('Düzenle'),
                                icon: const Icon(Icons.edit_outlined),
                                onPressed: () => _editSub(context, s),
                              ),
                              IconButton(
                                tooltip: tx('Sil'),
                                icon: const Icon(Icons.delete_outline_rounded),
                                onPressed: () => _deleteSub(context, s),
                              ),
                            ],
                          ),
                        ),
                      Padding(
                        padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
                        child: TextButton.icon(
                          onPressed: () => _addSub(context, c),
                          icon: const Icon(Icons.add_rounded),
                          label: Text(tx('Alt kategori ekle')),
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: () => _addCategory(context),
                  icon: const Icon(Icons.add_rounded),
                  label: Text(tx('Kategori ekle')),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
