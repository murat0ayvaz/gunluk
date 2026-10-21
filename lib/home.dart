import 'package:flutter/material.dart';
import 'add_sheet.dart';
import 'data.dart';
import 'drawer.dart';
import 'notes.dart';
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// ANA EKRAN: seçili günün rutinleri, girilen verileri ve günün notu
//  - Üstte gün seçici (geçmiş güne de veri / not girilebilir)
//  - Günün notu kutusu (dokununca yazma ekranı açılır)
//  - Rutin satırında yanında veri giriş kutusu
//  - Hedefe ulaşılınca satır pastel yeşile döner
//  - Sola kaydır: o günün veriyi sil  |  Sağa kaydır: düzenle
//  - Altta "Ekle" butonu
// ---------------------------------------------------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _RowData {
  final Category cat;
  final SubCat sub;
  final Entry? entry;
  _RowData(this.cat, this.sub, this.entry);
}

class _HomePageState extends State<HomePage> {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime day = dayOnly(DateTime.now());

  void _shift(int n) =>
      setState(() => day = DateTime(day.year, day.month, day.day + n));

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => day = dayOnly(d));
  }

  String _label() {
    final now = DateTime.now();
    final today = dKey(dayOnly(now));
    final yesterday = dKey(DateTime(now.year, now.month, now.day - 1));
    final tomorrow = dKey(DateTime(now.year, now.month, now.day + 1));
    final k = dKey(day);
    final s = dateLabel(day);
    if (k == today) return tx('Bugün • {0}', [s]);
    if (k == yesterday) return tx('Dün • {0}', [s]);
    if (k == tomorrow) return tx('Yarın • {0}', [s]);
    return '$s ${day.year}';
  }

  void _openAdd() {
    final p = palOf(context);
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      backgroundColor: p.bg,
      builder: (_) => AddSheet(date: dKey(day)),
    );
  }

  /// Günün notu yazma ekranını açar; dönünce kutudaki özet güncellenir
  Future<void> _openNote() async {
    await Navigator.of(context).push(MaterialPageRoute<void>(
      builder: (_) => NotePage(date: dKey(day), title: _label()),
    ));
    if (mounted) setState(() {});
  }

  Future<void> _editEntry(SubCat s, Entry? e) async {
    final v = await askNumber(context,
        title: tx('{0} verisi', [s.name]), unit: s.unit, initial: e?.value);
    if (v == null) return;
    store.setEntry(s.id, dKey(day), v);
  }

  void _deleteEntry(SubCat s, Entry? e) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    if (e == null) {
      messenger.showSnackBar(
          SnackBar(content: Text(tx('Bu gün için silinecek veri yok'))));
      return;
    }
    store.deleteEntry(e.id);
    messenger.showSnackBar(SnackBar(
      content: Text(tx('{0} verisi silindi', [s.name])),
      action: SnackBarAction(
          label: tx('Geri al'), onPressed: () => store.restoreEntry(e)),
    ));
  }

  /// Gün seçicinin altındaki "Günün notu" kutusu
  Widget _noteCard(Pal p, String date) {
    final note = store.noteOf(date);
    final empty = note.isEmpty;
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: InkWell(
        onTap: _openNote,
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.line),
          ),
          child: Row(
            children: [
              Icon(Icons.edit_note_rounded, color: p.soft),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  empty ? tx('Bu günün notunu yaz…') : note,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(color: empty ? p.soft : p.ink, height: 1.3),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        final date = dKey(day);

        // Rutinler her gün listede; rutin olmayanlar sadece verisi varsa
        final routines = <_RowData>[];
        final others = <_RowData>[];
        for (final c in store.cats) {
          for (final s in c.subs) {
            final e = store.entryFor(s.id, date);
            if (s.routine) {
              routines.add(_RowData(c, s, e));
            } else if (e != null) {
              others.add(_RowData(c, s, e));
            }
          }
        }

        Widget rowOf(_RowData r) => _DayRow(
              key: ValueKey('${r.sub.id}|$date'),
              cat: r.cat,
              sub: r.sub,
              entry: r.entry,
              date: date,
              onEdit: () => _editEntry(r.sub, r.entry),
              onDelete: () => _deleteEntry(r.sub, r.entry),
            );

        final children = <Widget>[
          for (final r in routines) rowOf(r),
          if (routines.isNotEmpty && others.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Text(tx('Diğer kayıtlar'), style: TextStyle(color: p.soft)),
            ),
          for (final r in others) rowOf(r),
        ];

        return Scaffold(
          key: _scaffoldKey,
          drawer: AppDrawer(
            onToday: () => setState(() => day = dayOnly(DateTime.now())),
          ),
          appBar: AppBar(
            backgroundColor: p.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            leading: IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            // "Günlük" yazısına dokununca soldaki menü açılır
            title: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Text(tx('Günlük'),
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: p.ink)),
            ),
          ),
          body: Column(
            children: [
              if (store.storageError != null)
                Container(
                  width: double.infinity,
                  margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                      color: p.delBg, borderRadius: BorderRadius.circular(12)),
                  child: Text(store.storageError!,
                      style: TextStyle(color: p.ink, fontSize: 13)),
                ),
              // ----- Gün seçici -----
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                      onPressed: () => _shift(-1),
                      icon: const Icon(Icons.chevron_left_rounded)),
                  Flexible(
                    child: TextButton(
                      onPressed: _pickDate,
                      child: Text(_label(),
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: p.ink)),
                    ),
                  ),
                  IconButton(
                      onPressed: () => _shift(1),
                      icon: const Icon(Icons.chevron_right_rounded)),
                ],
              ),
              // ----- Günün notu -----
              _noteCard(p, date),
              Expanded(
                child: children.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            tx('Bu gün için kayıt yok.\nAşağıdaki Ekle düğmesiyle rutin veya kayıt ekleyebilirsin.'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.soft, height: 1.4),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
                        children: children,
                      ),
              ),
            ],
          ),
          // ----- Altta Ekle butonu -----
          bottomNavigationBar: SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: SizedBox(
                height: 52,
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: _openAdd,
                  icon: const Icon(Icons.add_rounded),
                  label: Text(tx('Ekle')),
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------
// TEK SATIR: bir rutin / kayıt
// ---------------------------------------------------------------
class _DayRow extends StatefulWidget {
  final Category cat;
  final SubCat sub;
  final Entry? entry;
  final String date;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _DayRow({
    super.key,
    required this.cat,
    required this.sub,
    required this.entry,
    required this.date,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  State<_DayRow> createState() => _DayRowState();
}

class _DayRowState extends State<_DayRow> {
  final _ctrl = TextEditingController();

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  // Satırın yanındaki kutudan hızlı veri girişi
  void _submit() {
    final v = parseNum(_ctrl.text);
    if (v == null || v < 0) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tx('Geçerli bir sayı gir'))));
      return;
    }
    store.setEntry(widget.sub.id, widget.date, v);
    _ctrl.clear();
    FocusScope.of(context).unfocus();
  }

  Widget _swipeBg(Color color, IconData icon, Alignment align) => Container(
        color: color,
        alignment: align,
        padding: const EdgeInsets.symmetric(horizontal: 22),
        child: Icon(icon),
      );

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final sub = widget.sub;
    final e = widget.entry;
    final g = sub.goal;
    final unit = sub.unit;

    final met = e != null && goalMet(sub, e.value);

    // Alt satırda kategori ve hedef bilgisi
    var info = widget.cat.name;
    if (g != null) {
      final label = !sub.summable
          ? tx('hedef')
          : (sub.isMax ? tx('en fazla') : tx('hedef'));
      info += ' • $label ${fmt(g)} $unit';
    }

    // Veri girilmişse kalan / aşım bilgisi
    String? remain;
    if (e != null && g != null && sub.summable) {
      final diff = g - e.value;
      if (sub.isMax) {
        remain = diff >= 0
            ? tx('{0} {1} kaldı', [fmt(diff), unit])
            : tx('{0} {1} aşıldı', [fmt(-diff), unit]);
      } else {
        remain = diff > 0
            ? tx('{0} {1} kaldı', [fmt(diff), unit])
            : tx('Hedef tamam');
      }
    }

    final content = Container(
      decoration: BoxDecoration(
        color: met ? p.okBg : p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub.name,
                    style: TextStyle(
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                        color: p.ink)),
                const SizedBox(height: 2),
                Text(info,
                    style: TextStyle(fontSize: 12.5, color: p.soft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          const SizedBox(width: 8),
          if (e != null)
            // Veri varsa: değer + kalan bilgisi (dokununca düzenlenir)
            InkWell(
              onTap: widget.onEdit,
              borderRadius: BorderRadius.circular(8),
              child: Padding(
                padding: const EdgeInsets.all(4),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.end,
                  children: [
                    Text('${fmt(e.value)} $unit',
                        style: TextStyle(
                            fontSize: 17,
                            fontWeight: FontWeight.w700,
                            color: p.ink)),
                    if (remain != null)
                      Text(remain,
                          style: TextStyle(fontSize: 12, color: p.soft)),
                  ],
                ),
              ),
            )
          else ...[
            // Veri yoksa: satırın yanında giriş kutusu
            SizedBox(
              width: 84,
              child: TextField(
                controller: _ctrl,
                keyboardType: numberKeyboard,
                inputFormatters: numberFormatters,
                textAlign: TextAlign.center,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: unit.isEmpty ? '0' : unit,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            IconButton(
              onPressed: _submit,
              icon: const Icon(Icons.check_circle_rounded),
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Dismissible(
          key: ValueKey('dm_${sub.id}_${widget.date}'),
          background:
              _swipeBg(p.editBg, Icons.edit_rounded, Alignment.centerLeft),
          secondaryBackground: _swipeBg(
              p.delBg, Icons.delete_outline_rounded, Alignment.centerRight),
          // Satır ağaçtan kalkmaz: işlem yapılır, satır yerine döner
          confirmDismiss: (dir) async {
            if (dir == DismissDirection.startToEnd) {
              widget.onEdit(); // sağa kaydır: düzenle
            } else {
              widget.onDelete(); // sola kaydır: o günün veriyi sil
            }
            return false;
          },
          child: content,
        ),
      ),
    );
  }
}
