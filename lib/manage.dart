import 'package:flutter/material.dart';
import 'data.dart';
import 'notify.dart';
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// KATEGORİLERİ DÜZENLE
// Hazır liste dahil hiçbir şey kilitli değil: kategori ve alt kategori
// eklenebilir, düzenlenebilir (ad, birim, rutin, hedef...) ve silinebilir.
// Silince ilgili geçmiş kayıtlar da silinir (önce onay istenir).
// Kayıtlar kimliğe bağlı olduğu için ad değişince geçmiş bozulmaz.
// ---------------------------------------------------------------
/// Alt kategori düzenleme akışı (Kategorileri düzenle ve ana ekran satırından)
Future<void> editSubCategory(BuildContext context, SubCat s) async {
  final d = await showSubDialog(context,
      sub: s, title: tx('Alt kategoriyi düzenle'));
  if (d == null) return;
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
  Notifier.syncSub(s);
}

class ManagePage extends StatefulWidget {
  const ManagePage({super.key});

  @override
  State<ManagePage> createState() => _ManagePageState();
}

class _ManagePageState extends State<ManagePage> {
  final Set<String> _open = {}; // açık (genişlemiş) kategoriler

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

  Future<void> _editSub(BuildContext context, SubCat s) =>
      editSubCategory(context, s);

  Future<void> _deleteSub(BuildContext context, SubCat s) async {
    final count = store.entriesOf(s.id).length;
    final ok = await confirmDialog(
      context,
      tx('“{0}” silinsin mi?', [s.name]),
      tx('{0} kayıt da kalıcı olarak silinecek.', [count]),
      okLabel: tx('Sil'),
    );
    if (ok) {
      Notifier.cancelSub(s);
      store.deleteSub(s.id);
    }
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
        final cats = store.cats;
        return Scaffold(
          appBar: AppBar(
            backgroundColor: p.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(tx('Kategorileri düzenle')),
          ),
          body: cats.isEmpty
              ? Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(
                    tx('Hiç kategori yok. Aşağıdan yeni kategori ekleyebilirsin.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.soft),
                  ),
                )
              : ReorderableListView.builder(
                  padding: const EdgeInsets.fromLTRB(0, 4, 0, 24),
                  buildDefaultDragHandles: false,
                  itemCount: cats.length,
                  onReorder: (o, n) {
                    if (n > o) n -= 1;
                    store.moveCategory(o, n);
                  },
                  itemBuilder: (context, i) {
                    final c = cats[i];
                    final open = _open.contains(c.id);
                    return SwipeRow(
                      key: ValueKey(c.id),
                      tag: 'mc_${c.id}',
                      padding: const EdgeInsets.fromLTRB(12, 4, 12, 4),
                      radius: 14,
                      onEdit: () => _renameCategory(context, c),
                      onDelete: () => _deleteCategory(context, c),
                      child: Container(
                        decoration: BoxDecoration(
                          color: p.card,
                          borderRadius: BorderRadius.circular(14),
                          border: Border.all(color: p.line),
                        ),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            InkWell(
                              borderRadius: BorderRadius.circular(14),
                              onTap: () => setState(() {
                                open ? _open.remove(c.id) : _open.add(c.id);
                              }),
                              child: Padding(
                                padding:
                                    const EdgeInsets.fromLTRB(2, 6, 0, 6),
                                child: Row(
                                  children: [
                                    ReorderableDragStartListener(
                                      index: i,
                                      child: Padding(
                                        padding: const EdgeInsets.all(8),
                                        child: Icon(Icons.drag_handle_rounded,
                                            color: p.soft),
                                      ),
                                    ),
                                    Expanded(
                                      child: Text(c.name,
                                          style: TextStyle(
                                              fontSize: 16,
                                              fontWeight: FontWeight.w700,
                                              color: p.ink)),
                                    ),
                                    Text('${c.subs.length}',
                                        style: TextStyle(
                                            color: p.soft, fontSize: 12.5)),
                                    Icon(
                                        open
                                            ? Icons.expand_less_rounded
                                            : Icons.expand_more_rounded,
                                        color: p.soft),
                                    PopupMenuButton<String>(
                                      onSelected: (v) {
                                        if (v == 'add') _addSub(context, c);
                                        if (v == 'rename') {
                                          _renameCategory(context, c);
                                        }
                                        if (v == 'delete') {
                                          _deleteCategory(context, c);
                                        }
                                      },
                                      itemBuilder: (_) => [
                                        PopupMenuItem(
                                            value: 'add',
                                            child:
                                                Text(tx('Alt kategori ekle'))),
                                        PopupMenuItem(
                                            value: 'rename',
                                            child: Text(tx('Adını değiştir'))),
                                        PopupMenuItem(
                                            value: 'delete',
                                            child:
                                                Text(tx('Kategoriyi sil'))),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            ),
                            if (open) _subs(context, p, c),
                          ],
                        ),
                      ),
                    );
                  },
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

  /// Açık kategorinin alt kategorileri: sağa kaydır = düzenle, sola = sil, ≡ = sırala
  Widget _subs(BuildContext context, Pal p, Category c) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        if (c.subs.isNotEmpty)
          ReorderableListView.builder(
            shrinkWrap: true,
            physics: const NeverScrollableScrollPhysics(),
            buildDefaultDragHandles: false,
            itemCount: c.subs.length,
            onReorder: (o, n) {
              if (n > o) n -= 1;
              store.moveSub(c.id, o, n);
            },
            itemBuilder: (context, j) {
              final s = c.subs[j];
              return SwipeRow(
                key: ValueKey(s.id),
                tag: 'ms_${s.id}',
                onEdit: () => _editSub(context, s),
                onDelete: () => _deleteSub(context, s),
                child: ColoredBox(
                  color: p.card,
                  child: ListTile(
                    dense: true,
                    contentPadding: const EdgeInsets.only(left: 8, right: 0),
                    leading: ReorderableDragStartListener(
                      index: j,
                      child: Padding(
                        padding: const EdgeInsets.all(8),
                        child: Icon(Icons.drag_handle_rounded, color: p.soft),
                      ),
                    ),
                    title: Text(s.name),
                    subtitle: Text(_info(s)),
                    onTap: () => _editSub(context, s),
                    trailing: IconButton(
                      tooltip: tx('Sil'),
                      icon: const Icon(Icons.delete_outline_rounded),
                      onPressed: () => _deleteSub(context, s),
                    ),
                  ),
                ),
              );
            },
          ),
        Align(
          alignment: Alignment.centerLeft,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(8, 0, 8, 6),
            child: TextButton.icon(
              onPressed: () => _addSub(context, c),
              icon: const Icon(Icons.add_rounded),
              label: Text(tx('Alt kategori ekle')),
            ),
          ),
        ),
      ],
    );
  }
}
