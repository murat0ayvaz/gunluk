import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'add_sheet.dart';
import 'data.dart';
import 'drawer.dart';
import 'notes.dart';
import 'strings.dart';
import 'theme.dart';
import 'todos.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// ANA EKRAN (Daily Routine)
//  - Üstte gün seçici (geçmiş güne de veri girilebilir)
//  - Özlü söz kartı (Ayarlar'dan açılıp kapatılır)
//  - Rutin satırı: yanında veri kutusu; hedefe ulaşınca pastel yeşil
//  - Satıra dokunmak bir şey yapmaz. Sağa kaydır: düzenle, sola kaydır: sil
//  - Satıra 2 saniye basılı tut: sıralama modu (sürükleyip bırak, "Bitti")
//  - En altta "Yapılacaklar" ve "Günlük" başlıkları: dokununca yukarı doğru
//    tüm ekrana açılır (aşağı çekince ya da geri tuşuyla kapanır)
//  - Sağ altta DR düğmesi: Ekle / Sırala
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
  final int nat; // doğal sıra (eşitlikte kullanılır)
  _RowData(this.cat, this.sub, this.entry, this.nat);
}

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime day = dayOnly(DateTime.now());
  bool _fabOpen = false; // DR menüsü açık mı
  bool _reorder = false; // sıralama modu
  String? _panel; // null: kapalı, 'todo' veya 'note'
  String _lastTab = 'todo'; // kapanırken içerik kaybolmasın diye

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  // Uygulamaya geri dönülünce (özlü söz zamanı geçmiş olabilir) yeniden çiz
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) setState(() {});
  }

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

  // ----- Alt panel (Yapılacaklar / Günlük) -----

  void _openPanel(String tab) {
    setState(() {
      _panel = tab;
      _lastTab = tab;
      _fabOpen = false;
    });
  }

  void _closePanel() {
    FocusManager.instance.primaryFocus?.unfocus();
    setState(() => _panel = null);
  }

  // ----- Satır işlemleri -----

  Future<void> _editEntry(SubCat s, Entry? e) async {
    final v = await askNumber(context,
        title: tx('{0} verisi', [s.name]), unit: s.unit, initial: e?.value);
    if (v == null) return;
    store.setEntry(s.id, dKey(day), v);
  }

  /// Sola kaydırma: o günün verisini siler. "Geri al" 5 saniye durur.
  void _deleteEntry(SubCat s, Entry? e) {
    final messenger = ScaffoldMessenger.of(context);
    messenger.clearSnackBars();
    if (e == null) {
      messenger.showSnackBar(SnackBar(
        content: Text(tx('Bu gün için silinecek veri yok')),
        duration: const Duration(seconds: 3),
        persist: false,
      ));
      return;
    }
    store.deleteEntry(e.id);
    messenger.showSnackBar(SnackBar(
      content: Text(tx('{0} verisi silindi', [s.name])),
      duration: const Duration(seconds: 5),
      persist: false, // işlem düğmeli uyarı kendiliğinden kapansın
      action: SnackBarAction(
          label: tx('Geri al'), onPressed: () => store.restoreEntry(e)),
    ));
  }

  void _startReorder() {
    HapticFeedback.mediumImpact();
    setState(() {
      _reorder = true;
      _fabOpen = false;
    });
  }

  // ----- Özlü söz kartı -----

  Widget _quoteCard(Pal p) {
    final q = store.currentQuote();
    if (q == null) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: InkWell(
        onTap: store.nextQuote, // dokununca sıradaki söz
        borderRadius: BorderRadius.circular(14),
        child: Container(
          width: double.infinity,
          padding: const EdgeInsets.fromLTRB(14, 10, 4, 10),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.line),
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Padding(
                padding: const EdgeInsets.only(top: 2),
                child: Icon(Icons.format_quote_rounded, color: p.accent),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(q.text,
                        maxLines: 5,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: p.ink,
                            height: 1.35,
                            fontStyle: FontStyle.italic)),
                    if (q.ref.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(top: 4),
                        child: Text(q.ref,
                            style: TextStyle(fontSize: 12, color: p.soft)),
                      ),
                  ],
                ),
              ),
              IconButton(
                tooltip: tx('Kapat'),
                visualDensity: VisualDensity.compact,
                iconSize: 18,
                padding: const EdgeInsets.all(6),
                constraints: const BoxConstraints(),
                onPressed: store.hideQuote,
                icon: const Icon(Icons.close_rounded),
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
        final screenH = MediaQuery.of(context).size.height;

        // Rutinler her gün listede; rutin olmayanlar sadece verisi varsa.
        // Satırlar kullanıcının belirlediği sıraya göre dizilir.
        final routines = <_RowData>[];
        final others = <_RowData>[];
        var nat = 0;
        for (final c in store.cats) {
          for (final s in c.subs) {
            final e = store.entryFor(s.id, date);
            if (s.routine) {
              routines.add(_RowData(c, s, e, nat++));
            } else if (e != null) {
              others.add(_RowData(c, s, e, nat++));
            }
          }
        }
        int cmp(_RowData a, _RowData b) {
          final r = store.rankOf(a.sub.id).compareTo(store.rankOf(b.sub.id));
          return r != 0 ? r : a.nat.compareTo(b.nat);
        }

        routines.sort(cmp);
        others.sort(cmp);
        final ordered = [...routines, ...others];

        Widget rowOf(_RowData r) => _DayRow(
              key: ValueKey('${r.sub.id}|$date'),
              cat: r.cat,
              sub: r.sub,
              entry: r.entry,
              date: date,
              onEdit: () => _editEntry(r.sub, r.entry),
              onDelete: () => _deleteEntry(r.sub, r.entry),
              onLongPress: _startReorder,
            );

        // ----- Normal liste -----
        final children = <Widget>[
          if (routines.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 4, 4, 8),
              child: Text('Routine', style: TextStyle(color: p.soft)),
            ),
          for (final r in routines) rowOf(r),
          if (routines.isNotEmpty && others.isNotEmpty)
            Padding(
              padding: const EdgeInsets.fromLTRB(4, 12, 4, 8),
              child: Text(tx('Diğer kayıtlar'), style: TextStyle(color: p.soft)),
            ),
          for (final r in others) rowOf(r),
        ];

        // ----- Sıralama modu: sürükle-bırak listesi -----
        Widget reorderList() => ReorderableListView.builder(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              buildDefaultDragHandles: false,
              itemCount: ordered.length,
              onReorder: (oldI, newI) {
                if (newI > oldI) newI -= 1;
                final ids = ordered.map((r) => r.sub.id).toList();
                final id = ids.removeAt(oldI);
                ids.insert(newI, id);
                store.setHomeOrder(ids);
              },
              itemBuilder: (_, i) {
                final r = ordered[i];
                return Container(
                  key: ValueKey('ro_${r.sub.id}'),
                  margin: const EdgeInsets.only(bottom: 10),
                  padding: const EdgeInsets.fromLTRB(14, 8, 4, 8),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.line),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(r.sub.name,
                                style: TextStyle(
                                    fontSize: 16,
                                    fontWeight: FontWeight.w600,
                                    color: p.ink)),
                            Text(r.cat.name,
                                style: TextStyle(fontSize: 12.5, color: p.soft)),
                          ],
                        ),
                      ),
                      ReorderableDragStartListener(
                        index: i,
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Icon(Icons.drag_handle_rounded, color: p.soft),
                        ),
                      ),
                    ],
                  ),
                );
              },
            );

        final body = Column(
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
            if (_reorder) ...[
              // Sıralama modu başlığı
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 12, 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        tx('Sıralamak için tutamacı sürükle'),
                        style: TextStyle(color: p.soft),
                      ),
                    ),
                    FilledButton(
                      onPressed: () => setState(() => _reorder = false),
                      child: Text(tx('Bitti')),
                    ),
                  ],
                ),
              ),
              Expanded(child: reorderList()),
            ] else ...[
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
              _quoteCard(p),
              Expanded(
                child: children.isEmpty
                    ? Center(
                        child: Padding(
                          padding: const EdgeInsets.all(32),
                          child: Text(
                            tx('Bu gün için kayıt yok.\nSağ alttaki DR düğmesine dokunup Ekle’yi seçerek rutin veya kayıt ekleyebilirsin.'),
                            textAlign: TextAlign.center,
                            style: TextStyle(color: p.soft, height: 1.4),
                          ),
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                        children: children,
                      ),
              ),
            ],
          ],
        );

        final scaffold = Scaffold(
          key: _scaffoldKey,
          drawer: AppDrawer(
            onToday: () => setState(() => day = dayOnly(DateTime.now())),
            onNote: () => _openPanel('note'),
            onTodos: () => _openPanel('todo'),
          ),
          appBar: AppBar(
            backgroundColor: p.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: false,
            actions: [
              IconButton(
                tooltip: tx('Günlük'),
                icon: const Icon(Icons.edit_note_rounded),
                onPressed: () => _openPanel('note'),
              ),
            ],
            leading: IconButton(
              icon: const Icon(Icons.menu_rounded),
              onPressed: () => _scaffoldKey.currentState?.openDrawer(),
            ),
            // "Daily" yazısına dokununca soldaki menü açılır
            title: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => _scaffoldKey.currentState?.openDrawer(),
              child: Text('Daily',
                  style: TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.w700,
                      color: p.ink)),
            ),
          ),
          body: body,
          // ----- En altta Yapılacaklar / Günlük başlıkları -----
          bottomNavigationBar: _PanelBar(
            todoCount: store.todos.where((t) => !t.done).length,
            hasNote: store.noteOf(date).isNotEmpty,
            onOpen: _openPanel,
            onSwipeUp: () => _openPanel(_lastTab),
          ),
          // ----- DR düğmesi (sıralama modunda gizlenir) -----
          floatingActionButton: _reorder
              ? null
              : _DrFab(
                  open: _fabOpen,
                  onToggle: () => setState(() => _fabOpen = !_fabOpen),
                  onAdd: () {
                    setState(() => _fabOpen = false);
                    _openAdd();
                  },
                  onReorder: _startReorder,
                ),
        );

        // Geri tuşu: önce panel, sonra sıralama modu, sonra DR menüsü kapanır
        return PopScope(
          canPop: _panel == null && !_reorder && !_fabOpen,
          onPopInvokedWithResult: (didPop, result) {
            if (didPop) return;
            if (_panel != null) {
              _closePanel();
            } else if (_reorder) {
              setState(() => _reorder = false);
            } else if (_fabOpen) {
              setState(() => _fabOpen = false);
            }
          },
          child: Stack(
            children: [
              scaffold,
              // Tüm ekrana yukarı doğru açılan panel
              AnimatedPositioned(
                duration: const Duration(milliseconds: 280),
                curve: Curves.easeOutCubic,
                left: 0,
                right: 0,
                bottom: 0,
                height: _panel == null ? 0 : screenH,
                child: ClipRect(
                  child: OverflowBox(
                    alignment: Alignment.topCenter,
                    minHeight: screenH,
                    maxHeight: screenH,
                    child: _PanelFull(
                      tab: _lastTab,
                      day: day,
                      dayLabel: _label(),
                      onTab: (t) => setState(() {
                        _panel = t;
                        _lastTab = t;
                      }),
                      onClose: _closePanel,
                    ),
                  ),
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
// ALT ÇUBUK: "Yapılacaklar" ve "Günlük" başlıkları
// Dokununca (ya da yukarı kaydırınca) panel tüm ekrana açılır.
// ---------------------------------------------------------------
class _PanelBar extends StatelessWidget {
  final int todoCount;
  final bool hasNote;
  final void Function(String) onOpen;
  final VoidCallback onSwipeUp;

  const _PanelBar({
    required this.todoCount,
    required this.hasNote,
    required this.onOpen,
    required this.onSwipeUp,
  });

  Widget _btn(Pal p, IconData icon, String label, VoidCallback onTap,
          {Widget? badge}) =>
      Expanded(
        child: InkWell(
          onTap: onTap,
          child: Center(
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 21, color: p.soft),
                const SizedBox(width: 8),
                Text(label,
                    style:
                        TextStyle(fontWeight: FontWeight.w600, color: p.ink)),
                if (badge != null) ...[const SizedBox(width: 6), badge],
                const SizedBox(width: 4),
                Icon(Icons.keyboard_arrow_up_rounded, size: 20, color: p.soft),
              ],
            ),
          ),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return GestureDetector(
      onVerticalDragEnd: (d) {
        if ((d.primaryVelocity ?? 0) < -150) onSwipeUp();
      },
      child: Container(
        decoration: BoxDecoration(
          color: p.card,
          border: Border(top: BorderSide(color: p.line)),
        ),
        child: SafeArea(
          top: false,
          child: SizedBox(
            height: 58,
            child: Row(
              children: [
                _btn(
                  p,
                  Icons.task_alt_rounded,
                  tx('Yapılacaklar'),
                  () => onOpen('todo'),
                  badge: todoCount > 0
                      ? Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 7, vertical: 2),
                          decoration: BoxDecoration(
                              color: p.accent,
                              borderRadius: BorderRadius.circular(10)),
                          child: Text('$todoCount',
                              style: TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: p.onAccent)),
                        )
                      : null,
                ),
                Container(width: 1, height: 26, color: p.line),
                _btn(
                  p,
                  Icons.edit_note_rounded,
                  tx('Günlük'),
                  () => onOpen('note'),
                  badge: hasNote
                      ? Container(
                          width: 8,
                          height: 8,
                          decoration: BoxDecoration(
                              color: p.accent, shape: BoxShape.circle),
                        )
                      : null,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// TAM EKRAN PANEL: Yapılacaklar veya Günlük içeriği
// ---------------------------------------------------------------
class _PanelFull extends StatelessWidget {
  final String tab; // 'todo' veya 'note'
  final DateTime day;
  final String dayLabel;
  final void Function(String) onTab;
  final VoidCallback onClose;

  const _PanelFull({
    required this.tab,
    required this.day,
    required this.dayLabel,
    required this.onTab,
    required this.onClose,
  });

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Material(
      color: p.bg,
      borderRadius: const BorderRadius.vertical(top: Radius.circular(22)),
      clipBehavior: Clip.antiAlias,
      child: SafeArea(
        child: Padding(
          // Klavye açılınca içerik klavyenin üstünde kalsın
          padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom),
          child: Column(
            children: [
              // Başlık: aşağı çekince kapanır
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onVerticalDragEnd: (d) {
                  if ((d.primaryVelocity ?? 0) > 150) onClose();
                },
                child: Column(
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 8, bottom: 4),
                      width: 40,
                      height: 4,
                      decoration: BoxDecoration(
                          color: p.line, borderRadius: BorderRadius.circular(2)),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(12, 0, 4, 4),
                      child: Row(
                        children: [
                          ChoiceChip(
                            label: Text(tx('Yapılacaklar')),
                            selected: tab == 'todo',
                            onSelected: (_) => onTab('todo'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: Text(tx('Günlük')),
                            selected: tab == 'note',
                            onSelected: (_) => onTab('note'),
                          ),
                          const Spacer(),
                          IconButton(
                            tooltip: tx('Kapat'),
                            iconSize: 28,
                            icon: const Icon(Icons.keyboard_arrow_down_rounded),
                            onPressed: onClose,
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
              Divider(height: 1, color: p.line),
              Expanded(
                child: tab == 'todo'
                    ? const TodosBody()
                    : NoteBody(
                        key: ValueKey(dKey(day)),
                        date: dKey(day),
                        title: dayLabel,
                      ),
              ),
            ],
          ),
        ),
      ),
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
  final VoidCallback onLongPress; // 2 sn basılı tutunca sıralama modu

  const _DayRow({
    super.key,
    required this.cat,
    required this.sub,
    required this.entry,
    required this.date,
    required this.onEdit,
    required this.onDelete,
    required this.onLongPress,
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
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(
        content: Text(tx('Geçerli bir sayı gir')),
        duration: const Duration(seconds: 3),
        persist: false,
      ));
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
            // Veri varsa: değer + kalan bilgisi (dokunmak bir şey yapmaz)
            Padding(
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
                    Text(remain, style: TextStyle(fontSize: 12, color: p.soft)),
                ],
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

    // Satıra 2 saniye basılı tutunca sıralama modu açılır
    final pressable = RawGestureDetector(
      gestures: {
        LongPressGestureRecognizer:
            GestureRecognizerFactoryWithHandlers<LongPressGestureRecognizer>(
          () => LongPressGestureRecognizer(
              duration: const Duration(seconds: 2)),
          (LongPressGestureRecognizer inst) {
            inst.onLongPress = widget.onLongPress;
          },
        ),
      },
      child: content,
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
          child: pressable,
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// DR DÜĞMESİ (Daily Routine): sağ altta kısa yazılı düğme.
// Dokununca yukarı doğru yazılı seçenekler açılır: Ekle | Sırala
// ---------------------------------------------------------------
class _DrFab extends StatelessWidget {
  final bool open;
  final VoidCallback onToggle;
  final VoidCallback onAdd;
  final VoidCallback onReorder;

  const _DrFab({
    required this.open,
    required this.onToggle,
    required this.onAdd,
    required this.onReorder,
  });

  // Açılan menüdeki tek seçenek
  Widget _action(Pal p, IconData icon, String label, VoidCallback onTap) =>
      Padding(
        padding: const EdgeInsets.only(bottom: 10),
        child: FloatingActionButton.extended(
          heroTag: null, // birden çok düğme olduğu için hero animasyonu kapalı
          onPressed: onTap,
          backgroundColor: p.card,
          foregroundColor: p.ink,
          elevation: 2,
          icon: Icon(icon),
          label: Text(label),
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        if (open) ...[
          _action(p, Icons.add_rounded, tx('Ekle'), onAdd),
          _action(p, Icons.swap_vert_rounded, tx('Sırala'), onReorder),
        ],
        FloatingActionButton.extended(
          heroTag: null,
          onPressed: onToggle,
          backgroundColor: p.accent,
          foregroundColor: p.onAccent,
          icon: open ? const Icon(Icons.close_rounded) : null,
          label: Text(
            open ? tx('Kapat') : 'DR',
            style: const TextStyle(fontWeight: FontWeight.w700, letterSpacing: 1),
          ),
        ),
      ],
    );
  }
}
