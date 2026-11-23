import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'about.dart';
import 'add_sheet.dart';
import 'ambient.dart';
import 'fx.dart';
import 'data.dart';
import 'profile.dart' show EntryLine;
import 'fireworks.dart';
import 'tools.dart';
import 'manage.dart' show editSubCategory;
import 'media.dart';
import 'drawer.dart';
import 'notes.dart';
import 'notify.dart';
import 'reminders.dart';
import 'rowedit.dart';
import 'study.dart';
import 'strings.dart';
import 'theme.dart';
import 'todos.dart';
import 'ui.dart';
import 'voicecmd.dart';
import 'links.dart';
import 'prayer.dart';
import 'shortcuts.dart';
import 'weather.dart';

// ---------------------------------------------------------------
// ANA EKRAN (Daily Routine)
//  - Üstte gün seçici (geçmiş güne de veri girilebilir)
//  - Özlü söz kartı (Ayarlar'dan açılıp kapatılır)
//  - Rutin satırı: yanında veri kutusu; hedefe ulaşınca pastel yeşil
//  - Satıra dokunmak bir şey yapmaz. Sağa kaydır: düzenle, sola kaydır: sil
//  - Satıra 2 saniye basılı tut: sıralama modu (sürükleyip bırak, "Bitti")
//  - Rutinlerin altında açılır başlıklar: Yapılacaklar (güne özel), Günlük,
//    Hatırlatıcı
//  - Sağ altta yuvarlak DR düğmesi: dokununca Ekle paneli düğmeden büyüyerek açılır
//  - Sağ üstteki ok simgesi: sıralama modu (2 sn basılı tutmaya alternatif)
//  - Boş yere sağa / sola kaydır: önceki / sonraki gün
// ---------------------------------------------------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _RowData {
  final Category? cat;
  final SubCat? sub;
  final Entry? entry;
  final FreeRow? free; // doluysa bu satır bir "Serbest satır"
  final int nat; // doğal sıra (eşitlikte kullanılır)
  _RowData(this.cat, this.sub, this.entry, this.nat, {this.free});

  String get id => free?.id ?? sub!.id;
  // Hedefe ulaşılmış mı (yeşil satır)? Serbest satırlarda hedef yoktur.
  bool get met => free == null && entry != null && goalMet(sub!, entry!.value);
}

/// Kaydırma arka planı (sağa = düzenle, sola = sil)
Widget _swipeBg(Color color, IconData icon, Alignment align) => Container(
      color: color,
      alignment: align,
      padding: const EdgeInsets.symmetric(horizontal: 22),
      child: Icon(icon),
    );

class _HomePageState extends State<HomePage> with WidgetsBindingObserver {
  final _scaffoldKey = GlobalKey<ScaffoldState>();
  DateTime day = dayOnly(DateTime.now());
  bool get _wxOpen => store.wxBarOpen; // saatlik hava paneli açık mı
  bool _prOpen = false; // namaz vakitleri listesi açık mı
  // Rutinlerin altındaki açılır başlıklar ('todo', 'note', 'rem')
  final Set<String> _openSec = {};
  String? _catFilter; // null: tüm kategoriler, aksi halde seçili kategori kimliği
  // Sola itilip geçici gizlenen bölümler/çubuklar (veri silinmez; yenileyince geri gelir)
  final Set<String> _hidden = {};
  /// Hava / namaz çubuğu: sola kayarak gizlenir ("Gizle" zemini), sağa itince önceki gün
  Widget _bar(String id, Widget w) => _SwipeHide(
        key: ValueKey('bar_$id'),
        label: tx('Gizle'),
        inset: const EdgeInsets.fromLTRB(16, 0, 16, 8),
        radius: 16,
        onHide: () => _swipeSec(id, true),
        onRight: () => _swipeSec(id, false),
        builder: (context, wrap) => wrap(w),
      );
  void _swipeSec(String id, bool left) {
    if (left) {
      setState(() => _hidden.add(id));
    } else {
      _shift(-1); // sağa itme: önceki gün (boş ekrandaki gibi)
    }
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    weather.ensure(); // hava durumu açıksa verisini yükle
    voiceListener.ctx = context; // sürekli dinleme komutları bu ekranın üstünde çalıştırır
    voiceListener.sync();
    store.rollTodos(); // bitmeyen geçmiş maddeler bugüne taşınır
    _wasAll = store.todayGoals().all;
    store.addListener(_checkGoals);
    homeReset.addListener(_onHomeReset);
    // Güncelleme sonrası ilk açılışta "Uygulama güncellendi" penceresi
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted && store.takeUpdateNotice()) {
        showWhatsNew(context, updated: true);
      }
    });
  }

  @override
  void dispose() {
    store.removeListener(_checkGoals);
    homeReset.removeListener(_onHomeReset);
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Herhangi bir sayfada aşağı çekilince: ana ekran ilk haline döner
  void _onHomeReset() {
    if (!mounted) return;
    FocusManager.instance.primaryFocus?.unfocus(); // klavye kapanır
    store.setWxBarOpen(false); // yenilenince hava ve namaz yalnız yazı olarak kalır
    weather.ensure(force: true); // hava ve namaz verileri yenilenir
    prayer.ensure(force: true);
    setState(() {
      _prOpen = false;
      day = dayOnly(DateTime.now());
      _openSec.clear();
      _hidden.clear();
      _catFilter = null;
    });
  }

  bool _wasAll = false; // bugünün tüm hedefleri az önce tamam mıydı

  /// Son hedef tamamlanınca (önce tamam değildi, şimdi tamam) havai fişek
  void _checkGoals() {
    final all = store.todayGoals().all;
    if (all && !_wasAll && mounted) _celebrate();
    _wasAll = all;
  }

  void _celebrate() {
    final overlay = Overlay.of(context);
    late OverlayEntry entry;
    entry = OverlayEntry(
        builder: (_) => FireworksOverlay(onDone: () => entry.remove()));
    overlay.insert(entry);
  }

  // Uygulamaya geri dönülünce (özlü söz zamanı geçmiş olabilir) yeniden çiz
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed && mounted) {
      weather.ensure(); // 30 dakikadan eskiyse yeniler
      prayer.ensure(); // gün değiştiyse namaz vakitleri
      store.rollTodos(); // gün değişmiş olabilir
      setState(() {});
    }
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

  /// Üstteki tarih yazısı: Dün / Bugün / Yarın; bu haftanın diğer günleri
  /// gün adıyla (Çarşamba...); diğerleri 07.04.2026 biçiminde.
  String _label() {
    final now = DateTime.now();
    final t = DateTime.utc(now.year, now.month, now.day);
    final d = DateTime.utc(day.year, day.month, day.day);
    final diff = d.difference(t).inDays;
    if (diff == 0) return tx('Bugün');
    if (diff == -1) return tx('Dün');
    if (diff == 1) return tx('Yarın');
    final monday = t.subtract(Duration(days: t.weekday - 1));
    final sunday = monday.add(const Duration(days: 6));
    if (!d.isBefore(monday) && !d.isAfter(sunday)) return wdName(d.weekday);
    String two(int n) => n.toString().padLeft(2, '0');
    return '${two(d.day)}.${two(d.month)}.${d.year}';
  }

  /// Tarih satırı: < Bugün • 3 Kasım • hava simgesi >
  /// long = Tema 2: "Bugün 18.11.2026 Perşembe"
  Widget _dateRow(Pal p, {required bool long}) {
    final date = dKey(day);
    return Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 40),
                    onPressed: () => _shift(-1),
                    icon: const Icon(Icons.chevron_left_rounded)),
                Flexible(
                  child: TextButton(
                    onPressed: _pickDate,
                    style: TextButton.styleFrom(
                        padding: const EdgeInsets.symmetric(horizontal: 4),
                        minimumSize: const Size(0, 40)),
                    child: Text(long ? _longLabel() : _label(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: p.ink)),
                  ),
                ),
                // Hava durumu: bugün = şimdiki, diğer günler = günlük simge
                if (store.wxOn)
                  WxChip(
                    date: date,
                    open: store.linesOn,
                    onTap: () => store.setLinesOn(!store.linesOn),
                  )
                else if (store.prayOn)
                  IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 40),
                    tooltip: tx('Namaz vakitleri'),
                    onPressed: () => store.setLinesOn(!store.linesOn),
                    icon: Icon(Icons.mosque_rounded,
                        size: 20, color: store.linesOn ? p.accent : p.soft),
                  ),
                IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 40),
                    onPressed: () => _shift(1),
                    icon: const Icon(Icons.chevron_right_rounded)),
              ],
            );
  }

  String _longLabel() {
    final now = DateTime.now();
    final t = DateTime.utc(now.year, now.month, now.day);
    final d = DateTime.utc(day.year, day.month, day.day);
    final diff = d.difference(t).inDays;
    String two(int n) => n.toString().padLeft(2, '0');
    final pre = diff == 0
        ? '${tx('Bugün')} '
        : (diff == 1 ? '${tx('Yarın')} ' : (diff == -1 ? '${tx('Dün')} ' : ''));
    return '$pre${two(d.day)}.${two(d.month)}.${d.year} ${wdName(d.weekday)}';
  }

  /// Ekle paneli: Rutinler satırındaki + düğmesinden büyüyerek ekranın ortasında açılır.
  /// Dışarı dokununca veya geri tuşuyla kapanır.
  Future<void> _openAdd(Offset origin) {
    final date = dKey(day);
    return showGrow<void>(
      context,
      origin,
      (ctx) => Column(
        children: [
          Container(
            margin: const EdgeInsets.only(top: 8, bottom: 2),
            width: 40,
            height: 4,
            decoration: BoxDecoration(
                color: palOf(ctx).line, borderRadius: BorderRadius.circular(2)),
          ),
          Expanded(child: AddSheet(date: date)),
        ],
      ),
      heightFactor: 0.72,
      fixed: true,
    );
  }

  // ----- Satır işlemleri -----

  /// Sağa kaydırma. Rutinlerde: yalnız hatırlatma saati ve bağlı yer (veri girişi satırdan yapılır).
  /// Diğer satırlarda: veriyi düzenle / sil.
  Future<void> _editRow(_RowData r) async {
    final sub = r.sub!;
    if (sub.routine) {
      final b = await showRoutineBell(context, sub);
      if (b == null) return;
      if (b.$1 == -2) {
        // "Alt kategoriyi düzenle": günler, hedef vb. oradan ayarlanır
        if (!mounted) return;
        await editSubCategory(context, sub);
        return;
      }
      store.setRoutineOptions(sub.id, days: sub.days, rh: b.$1, rm: b.$2);
      if (b.$1 >= 0) {
        final messenger = ScaffoldMessenger.of(context);
        final msg = await permissionMessage();
        if (msg != null) messenger.showSnackBar(SnackBar(content: Text(msg)));
      }
      await Notifier.syncSub(sub);
      return;
    }
    final res = await showRowEditDialog(context, sub: sub, entry: r.entry);
    if (res == null) return;
    if (res.openSub) {
      if (!mounted) return;
      await editSubCategory(context, sub);
      return;
    }
    if (res.deleteEntry && r.entry != null) {
      store.deleteEntry(r.entry!.id);
    } else if (res.value != null) {
      store.setEntry(sub.id, dKey(day), res.value!);
    }
    if (res.goalSet) store.setGoal(sub.id, res.goal);
  }

  /// Sola kaydırma (kısa): rutini sadece bu güne özel gizler.
  /// Tamamen kaydırma: rutini bugünden itibaren kaldırır (uyarı sorar).
  Future<void> _removeRoutine(_RowData r, {required bool full}) async {
    final messenger = ScaffoldMessenger.of(context);
    final sub = r.sub!;
    final date = dKey(day);
    if (!sub.routine || !sub.scheduledOn(day)) {
      messenger.clearSnackBars();
      messenger.showSnackBar(SnackBar(
        content: Text(tx('Bu satır bu gün için bir rutin değil. Veriyi sağa kaydırıp silebilirsin.')),
        duration: const Duration(seconds: 4),
        persist: false,
      ));
      return;
    }
    if (full) {
      final ok = await confirmDialog(
        context,
        tx('Rutin kaldırılsın mı?'),
        tx('“{0}” bugünden itibaren tüm günlerden kalkar ve hatırlatması silinir. Geçmiş veriler korunur. Tekrar eklemek için Ekle ekranında Rutin olsun anahtarını aç.', [sub.name]),
        okLabel: tx('Kaldır'),
      );
      if (!ok) return;
      await Notifier.cancelSub(sub);
      store.setRoutineOff(sub.id);
      showUndo(context, tx('{0} rutini kaldırıldı', [sub.name]), () {
        store.setRoutineOn(sub.id);
        Notifier.syncSub(sub);
      });
    } else {
      store.skipDay(sub.id, date);
      Notifier.syncSub(sub);
      showUndo(context, tx('{0} bu gün için kaldırıldı', [sub.name]), () {
        store.unskipDay(sub.id, date);
        Notifier.syncSub(sub);
      });
    }
  }

  /// Serbest satırı düzenle (sağa kaydır)
  Future<void> _editFree(FreeRow f) async {
    final r = await showFreeRowDialog(context,
        title: f.title,
        text: f.text,
        date: f.date,
        remindMs: f.remindMs,
        isNew: false);
    if (r == null) return;
    final messenger = ScaffoldMessenger.of(context);
    final n = store.updateFree(f.id, r.title, r.text,
        date: r.date, remindMs: r.remindMs);
    if (n == null) return;
    if (n.remindMs > 0) {
      final msg = await permissionMessage();
      if (msg != null) messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
    await Notifier.syncFree(n);
  }

  /// Serbest satırı sil (sola kaydır); "Geri al" 5 saniye durur
  void _deleteFree(FreeRow f) {
    store.deleteFree(f.id);
    Notifier.cancelFree(f);
    showUndo(context, tx('Satır silindi'), () {
      store.restoreFree(f);
      Notifier.syncFree(f);
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

        // Rutinler her gün listede; rutin olmayanlar sadece verisi varsa.
        // Satırlar kullanıcının belirlediği sıraya göre dizilir.
        final routines = <_RowData>[];
        final others = <_RowData>[];
        var nat = 0;
        for (final c in store.cats) {
          for (final s in c.subs) {
            final e = store.entryFor(s.id, date);
            // Rutin sadece seçili günlerde listelenir; seçili olmayan günde
            // verisi varsa yine de "Diğer kayıtlar" altında görünür
            final scheduled = s.scheduledOn(day);
            if (scheduled) {
              routines.add(_RowData(c, s, e, nat++));
            } else if (e != null) {
              others.add(_RowData(c, s, e, nat++));
            }
          }
        }
        // Serbest satırlar (o güne ait) "Diğer kayıtlar" içinde görünür
        for (final f in store.freeRows) {
          if (f.date == date) others.add(_RowData(null, null, null, nat++, free: f));
        }
        int cmp(_RowData a, _RowData b) {
          final r = store.rankOf(a.id).compareTo(store.rankOf(b.id));
          return r != 0 ? r : a.nat.compareTo(b.nat);
        }

        // Hedefi tamamlanan (yeşil) satırlar en alta iner; diğerleri
        // kullanıcının ≡ ile belirlediği sırada durur.
        int cmpNormal(_RowData a, _RowData b) {
          if (a.met != b.met) return a.met ? 1 : -1;
          return cmp(a, b);
        }

        routines.sort(cmpNormal);
        others.sort(cmpNormal);

        // ----- Kategori süzgeci: o gün satırı olan kategoriler -----
        final catsToday = <Category>[];
        for (final c in store.cats) {
          if ([...routines, ...others].any((r) => r.cat?.id == c.id)) {
            catsToday.add(c);
          }
        }
        final filterId = (_catFilter != null &&
                catsToday.any((c) => c.id == _catFilter))
            ? _catFilter
            : null; // seçili kategorinin o gün satırı yoksa hepsi görünür
        // Başlıktaki sayılar süzgeçten bağımsız (günün tamamı)
        final routinesTotal = routines.length;
        final routinesMet = routines.where((r) => r.met).length;
        final othersTotal = others.length;
        if (filterId != null) {
          routines.removeWhere((r) => r.cat?.id != filterId);
          others.removeWhere((r) => r.cat?.id != filterId);
        }

        Widget rowOf(_RowData r, int i) {
          if (r.free != null) {
            return _FreeRowTile(
              key: ValueKey('fr_${r.free!.id}'),
              index: i,
              row: r.free!,
              onEdit: () => _editFree(r.free!),
              onDelete: () => _deleteFree(r.free!),
            );
          }
          return _DayRow(
            key: ValueKey('${r.sub!.id}|$date'),
            index: i,
            cat: r.cat!,
            sub: r.sub!,
            entry: r.entry,
            date: date,
            onEdit: () => _editRow(r),
            onRemove: (full) => _removeRoutine(r, full: full),
            onBell: () {}, // zil kaldırıldı; hatırlatma sağa kaydırınca açılan menüde
          );
        }

        // Her bölüm kendi içinde sürüklenerek sıralanır (≡ tutamacı)
        Widget section(List<_RowData> list) => ReorderableListView.builder(
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              padding: EdgeInsets.zero,
              buildDefaultDragHandles: false,
              itemCount: list.length,
              onReorder: (oldI, newI) {
                if (newI > oldI) newI -= 1;
                final ids = list.map((r) => r.id).toList();
                final id = ids.removeAt(oldI);
                ids.insert(newI, id);
                store.setHomeOrder(ids);
              },
              itemBuilder: (_, i) => rowOf(list[i], i),
            );

        final Widget chipsBar = catsToday.length > 1
            ? SizedBox(
                  height: 44,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                    children: [
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(tx('Tümü')),
                          selected: filterId == null,
                          onSelected: (_) => setState(() => _catFilter = null),
                        ),
                      ),
                      for (final c in catsToday)
                        Padding(
                          padding: const EdgeInsets.only(right: 8),
                          child: ChoiceChip(
                            label: Text(c.name),
                            selected: filterId == c.id,
                            onSelected: (_) =>
                                setState(() => _catFilter = c.id),
                          ),
                        ),
                    ],
                  ),
                )
            : const SizedBox.shrink();

        // Rutinler ve Diğer kayıtlar: açılır başlıklar (açılışta kapalı)
        final secW = <String, Widget>{
          if (!_hidden.contains('routine')) 'routine': _HomeSection(
              key: const ValueKey('sec_routine'),
              onSwipe: (l) => _swipeSec('routine', l),
              onAdd: _openAdd,
              icon: Icons.checklist_rounded,
              title: tx('Rutinler'),
              tone: const Color(0xFF4F8EF7),
              badge: '$routinesMet/$routinesTotal',
              open: _openSec.contains('routine'),
              onToggle: () => setState(() => _openSec.contains('routine')
                  ? _openSec.remove('routine')
                  : _openSec.add('routine')),
              child: Column(
                children: [
                  const SizedBox(height: 6),
                  chipsBar,
                  Padding(
                    padding: const EdgeInsets.fromLTRB(8, 0, 8, 8),
                    child: section(routines),
                  ),
                ],
              ),
            ),
          if (othersTotal > 0 && !_hidden.contains('other')) 'other': _HomeSection(
              key: const ValueKey('sec_other'),
              onSwipe: (l) => _swipeSec('other', l),
              icon: Icons.more_horiz_rounded,
              title: tx('Diğer kayıtlar'),
              tone: const Color(0xFF17A9C4),
              badge: '$othersTotal',
              open: _openSec.contains('other'),
              onToggle: () => setState(() => _openSec.contains('other')
                  ? _openSec.remove('other')
                  : _openSec.add('other')),
              child: Padding(
                padding: const EdgeInsets.fromLTRB(8, 8, 8, 8),
                child: section(others),
              ),
            ),
                    if (!store.appHidden('todo') && !_hidden.contains('todo')) 'todo': _HomeSection(
                      key: const ValueKey('sec_todo'),
                      onSwipe: (l) => _swipeSec('todo', l),
                      icon: Icons.task_alt_rounded,
                      title: tx('Yapılacaklar'),
                      tone: const Color(0xFF2FB38A),
                      onAdd: (o) async {
                        final ok = await showAddTodo(context, date, origin: o);
                        if (ok && mounted) setState(() => _openSec.add('todo'));
                      },
                      badge: () {
                        final n = store
                            .todosFor(date)
                            .where((t) => !t.done)
                            .length;
                        return n > 0 ? '$n' : '';
                      }(),
                      open: _openSec.contains('todo'),
                      onToggle: () => setState(() => _openSec.contains('todo')
                          ? _openSec.remove('todo')
                          : _openSec.add('todo')),
                      child: TodosBody(date: date),
                    ),
                    if (!store.appHidden('diary') && !_hidden.contains('note')) 'note': _HomeSection(
                      key: const ValueKey('sec_note'),
                      onSwipe: (l) => _swipeSec('note', l),
                      icon: Icons.menu_book_rounded,
                      title: tx('Günlük'),
                      tone: const Color(0xFF9A6BF0),
                      badge: store.noteOf(date).isNotEmpty ? '•' : '',
                      open: _openSec.contains('note'),
                      onToggle: () => setState(() => _openSec.contains('note')
                          ? _openSec.remove('note')
                          : _openSec.add('note')),
                      child: SizedBox(
                        height: 340,
                        child: NoteBody(
                            key: ValueKey('nb_$date'),
                            date: date,
                            title: _label()),
                      ),
                    ),
                    if (!store.appHidden('rem') && !_hidden.contains('rem')) 'rem': _HomeSection(
                      key: const ValueKey('sec_rem'),
                      onSwipe: (l) => _swipeSec('rem', l),
                      icon: Icons.notifications_active_outlined,
                      title: tx('Hatırlatıcı'),
                      tone: const Color(0xFFF08A3C),
                      onAdd: (o) => showReminderSheet(context, origin: o),
                      badge: () {
                        final n = store.reminders
                            .where((r) => r.enabled && !reminderFinished(r))
                            .length;
                        return n > 0 ? '$n' : '';
                      }(),
                      open: _openSec.contains('rem'),
                      onToggle: () => setState(() => _openSec.contains('rem')
                          ? _openSec.remove('rem')
                          : _openSec.add('rem')),
                      child: const RemindersBody(),
                    ),
        };
        // Bölüm sırası Ayarlar > Ana ekran > Ana ekran düzeni'nden gelir
        final children = <Widget>[
          for (final id in store.secOrder)
            if (secW[id] != null) secW[id]!,
        ];
        final emptyList = !secW.containsKey('routine') && !secW.containsKey('other');

        final bodyColumn = Column(
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
            ...[
              Expanded(
                child: ListView(
                  physics: const AlwaysScrollableScrollPhysics(),
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 100),
                  children: [
                    ...children,
                    if (emptyList)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 10),
                        child: Text(
                          tx('Bu gün için kayıt yok.\nSağ alttaki DR düğmesine dokunarak rutin veya kayıt ekleyebilirsin.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.soft, height: 1.4),
                        ),
                      ),
                  ],
                  ),
              ),
            ],
          ],
        );

        // Sayfanın boş yerinde sola kaydır: ertesi gün, sağa kaydır: önceki gün.
        // Satırların üzerindeki kaydırma (düzenle / sil) öncelikli kalır.
        final body = GestureDetector(
          behavior: HitTestBehavior.translucent,
          onHorizontalDragEnd: (d) {
            final v = d.primaryVelocity ?? 0;
            if (v < -250) {
              _shift(1);
            } else if (v > 250) {
              _shift(-1);
            }
          },
          child: bodyColumn,
        );

        // Üst bar simgeleri (Tema 2 ve 3'te ekran genişliğine eşit aralıkla dağılır)
        final iMenu = IconButton(
          visualDensity: VisualDensity.compact,
          padding: EdgeInsets.zero,
          constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
          icon: const Icon(Icons.menu_rounded),
          onPressed: () => _scaffoldKey.currentState?.openDrawer(),
        );
        final Widget? iStudy = (!store.appHidden('study') &&
                !(store.appHidden('study_lgs') && store.appHidden('study_dil')))
            ? IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 40, minHeight: 44),
                tooltip: tx('Ders çalışma'),
                icon: const Icon(Icons.menu_book_rounded),
                onPressed: () => Navigator.of(context)
                    .push(slideFromRight(const StudyPage())),
              )
            : null;
        final Widget? iShort = !store.appHidden('shortcuts')
            ? IconButton(
                visualDensity: VisualDensity.compact,
                padding: EdgeInsets.zero,
                constraints: const BoxConstraints(minWidth: 38, minHeight: 44),
                tooltip: tx('Kısayollar'),
                icon: const Icon(Icons.apps_rounded),
                onPressed: () => Navigator.of(context)
                    .push(slideFromRight(const ShortcutsPage())),
              )
            : null;
        final Widget? iTools = !store.appHidden('tools')
            ? IconButton(
                tooltip: tx('Araçlar'),
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                icon: const Icon(Icons.handyman_outlined),
              )
            : null;
        final Widget? iMedia =
            (!store.appHidden('media') && mediaTabIds().isNotEmpty)
                ? ListenableBuilder(
                    listenable: media,
                    builder: (context, _) => IconButton(
                      tooltip: tx('Müzik ve Radyo'),
                      onPressed: () => Navigator.of(context)
                          .push(slideFromRight(const MediaPage())),
                      icon: Icon(media.nowId != null && media.playing
                          ? Icons.graphic_eq_rounded
                          : Icons.headphones_rounded),
                    ),
                  )
                : null;
        final Widget? iMic = !store.appHidden('voice')
            ? ListenableBuilder(
                listenable: voiceListener,
                builder: (context, _) {
                  // Sürekli dinleme açıkken mikrofon renkli ve küçük bir nokta görünür
                  final on = store.voiceListen && voiceListener.listening;
                  return IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 38, minHeight: 44),
                    tooltip: on
                        ? tx('Dinliyor: "{0}" de', [store.voiceWake])
                        : tx('Sesli komut'),
                    icon: Stack(
                      clipBehavior: Clip.none,
                      children: [
                        Icon(Icons.mic_rounded, color: on ? p.accent : null),
                        if (on)
                          Positioned(
                            right: -2,
                            top: -2,
                            child: Container(
                              width: 8,
                              height: 8,
                              decoration: BoxDecoration(
                                  color: p.accent, shape: BoxShape.circle),
                            ),
                          ),
                      ],
                    ),
                    onPressed: () => voiceCommand(context),
                  );
                },
              )
            : null;
        final fixedBars = store.homeTheme >= 2; // Tema 2 ve 3
        // Simgeler kullanıcının sırasıyla; kapatılanlar ve gizli uygulamalar çıkarılır.
        // Tema 1'de ilk 3 simge solda, kalanı sağda durur.
        final iconMap = <String, Widget?>{
          'menu': iMenu,
          'study': iStudy,
          'short': iShort,
          'mic': iMic,
          'tools': iTools,
          'media': iMedia,
        };
        final icons = <(String, Widget)>[
          for (final id in store.iconOrder)
            if (iconMap[id] != null && (id == 'menu' || !store.iconOff.contains(id)))
              (id, iconMap[id]!),
        ];

        final amb = ambienceOn();
        final scaffold0 = Scaffold(
          key: _scaffoldKey,
          backgroundColor: amb ? Colors.transparent : null,
          drawer: const AppDrawer(),
          endDrawer: const ToolsDrawer(),
          endDrawerEnableOpenDragGesture: false, // günler arası kaydırmayla karışmasın
          appBar: AppBar(
            backgroundColor: amb ? Colors.transparent : p.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            titleSpacing: 0,
            automaticallyImplyLeading: false,
            leadingWidth: fixedBars ? 0 : 40.0 * icons.take(3).length,
            leading: fixedBars
                ? const SizedBox.shrink()
                : Row(children: icons.take(3).map((e) => e.$2).toList()),
            // Tema 1: tarih seçici üstte. Tema 2/3: simgeler eşit aralıkla.
            title: fixedBars
                ? Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      ...icons.where((e) => e.$1 != 'tools' || store.homeTheme != 3).map((e) => e.$2),
                    ],
                  )
                : _dateRow(p, long: false),
            actions: fixedBars
                ? const []
                : icons.skip(3).map((e) => e.$2).toList(),
          ),
          body: Builder(builder: (context) {
            // Hava ve namaz: tek satır yazı. Başlıktaki hava simgesi satırları getirir/götürür;
            // yazıya dokununca altına saatlik hava / tüm vakitler açılır.
            // Ekran yenilenince (ana ekranda aşağı çekince) açılan barlar kapanır, yazılar kalır.
            // Klavyesi olan bölümlerden biri (Rutinler, Yapılacaklar, Günlük, Hatırlatıcı)
            // açıkken hava ve namaz satırları gizlenir; hepsi kapanınca geri gelir.
            final kbSection = _openSec.any(
                (k) => k == 'routine' || k == 'todo' || k == 'note' || k == 'rem');
            final lines = store.linesOn && !kbSection;
            final wxLine = (lines && store.wxOn && !_hidden.contains('wx'))
                ? WxLine(
                    key: ValueKey('wxl_$date'),
                    date: date,
                    open: _wxOpen,
                    onTap: () => store.setWxBarOpen(!store.wxBarOpen),
                  )
                : null;
            final wxPanel = (lines && store.wxOn && _wxOpen && !_hidden.contains('wx'))
                ? WxPanel(key: ValueKey('wx_$date'), date: date)
                : null;
            final prLine = (lines && store.prayOn && !_hidden.contains('pr'))
                ? PrayerLine(
                    open: _prOpen,
                    day: day,
                    onTap: () => setState(() => _prOpen = !_prOpen),
                  )
                : null;
            final prBar =
                (lines && store.prayOn && _prOpen && !_hidden.contains('pr'))
                    ? PrayerBar(day: day)
                    : null;
            // Hava ve namaz çubukları, düzendeki sıraya göre
            final erLine = (!kbSection &&
                    !_hidden.contains('er') &&
                    store.pBool('erOn', true) &&
                    date == dKey(DateTime.now()))
                ? EntryLine(onTap: () => setState(() => _openSec.add('routine')))
                : null;
            List<Widget> bars({bool reversed = false}) {
              final wxFirst =
                  store.secOrder.indexOf('wx') < store.secOrder.indexOf('pr');
              // Tema 3'te paneller yukarı açıldığı için her grup tersine dizilir
              final wx = reversed
                  ? [if (wxPanel != null) wxPanel, if (wxLine != null) _bar('wx', wxLine)]
                  : [if (wxLine != null) _bar('wx', wxLine), if (wxPanel != null) wxPanel];
              final pr = reversed
                  ? [if (prBar != null) prBar, if (prLine != null) _bar('pr', prLine)]
                  : [if (prLine != null) _bar('pr', prLine), if (prBar != null) prBar];
              // Tema 3'te varsayılan görünüm eskisi gibi kalsın (namaz üstte, hava altta)
              final firstWx = reversed ? !wxFirst : wxFirst;
              final l = [
                if (erLine != null) _bar('er', erLine),
                ...(firstWx ? [...wx, ...pr] : [...pr, ...wx]),
              ];
              return l;
            }
            if (store.homeTheme == 3) {
              // Tema 3: tarih, hava ve namaz en altta sabit; paneller yukarı doğru açılır.
              // En alttan yukarı: Bugün satırı, hava, namaz.
              return Column(
                children: [
                  Expanded(child: body),
                  SafeArea(
                    top: false,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        // alttan yukarı: seçilen sıranın tersi (ilk sıradaki en üstte)
                        ...bars(reversed: true),
                        Padding(
                          padding: const EdgeInsets.only(top: 2, bottom: 2),
                          child: Center(child: _dateRow(p, long: true)),
                        ),
                      ],
                    ),
                  ),
                ],
              );
            }
            return Column(
              children: [
                // Tema 2: tarih satırı üst barın altında, sabit
                if (store.homeTheme == 2)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 2),
                    child: Center(child: _dateRow(p, long: true)),
                  ),
                ...bars(),
                Expanded(child: body),
              ],
            );
          }),
        );

        final scaffold = amb
            ? Stack(fit: StackFit.expand, children: [const Positioned.fill(child: AmbientBg()), scaffold0])
            : scaffold0;

        // Geri tuşu: önce menü, sonra çıkış onayı
        return PopScope(
          canPop: false,
          onPopInvokedWithResult: (didPop, result) async {
            if (didPop) return;
            if (store.locked) return; // kilit ekranı açıkken alttaki sayfa işlem yapmasın
            if (_scaffoldKey.currentState?.isDrawerOpen ?? false) {
              _scaffoldKey.currentState?.closeDrawer();
            } else {
              // Ana ekranda geri tuşu: çıkış onayı
              final ok = await confirmDialog(
                context,
                tx('Çıkış'),
                tx('Programdan çıkmak istediğinize emin misiniz?'),
                okLabel: tx('Evet'),
                cancelLabel: tx('Hayır'),
              );
              if (ok) SystemNavigator.pop();
            }
          },
          child: Stack(
            children: [
              scaffold,
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------
// AÇILIR BAŞLIK: ana ekranda rutinlerin altında (Yapılacaklar, Günlük,
// Hatırlatıcı). Başlığa dokununca altı aşağı doğru açılır.
// ---------------------------------------------------------------
class _HomeSection extends StatelessWidget {
  final IconData icon;
  final String title;
  final Color tone;
  final String badge; // sayı ya da "•"; boşsa görünmez
  final bool open;
  final VoidCallback onToggle;
  final void Function(Offset origin)? onAdd; // başlıktaki + düğmesi (konumu verir)
  final void Function(bool left)? onSwipe; // sola/sağa itme (sola: bölüm gizlenir)
  final Widget child;
  const _HomeSection({
    super.key,
    this.onAdd,
    this.onSwipe,
    required this.icon,
    required this.title,
    required this.tone,
    required this.badge,
    required this.open,
    required this.onToggle,
    required this.child,
  });

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final tone = p.tint(this.tone);
    final head =
        Color.alphaBlend(tone.withOpacity(p.dark ? 0.20 : 0.13), p.card);
    return _SwipeHide(
      label: tx('Gizle'),
      inset: const EdgeInsets.only(bottom: 10),
      radius: 16,
      onHide: onSwipe == null ? null : () => onSwipe!(true),
      onRight: onSwipe == null ? null : () => onSwipe!(false),
      builder: (context, wrap) => Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withOpacity(p.dark ? 0.55 : 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          wrap(
            Material(
            color: head,
            borderRadius: BorderRadius.vertical(
                top: const Radius.circular(15),
                bottom: Radius.circular(open ? 0 : 15)),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: onToggle,
              child: Padding(
                // + düğmesi olan başlıklarda boşluk azaltılır: tüm başlıklar aynı yükseklikte
                padding: EdgeInsets.fromLTRB(
                    14, onAdd != null ? 6 : 12, 10, onAdd != null ? 6 : 12),
                child: Row(
                  children: [
                    Icon(icon, color: tone),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(title,
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w700,
                              color: p.ink)),
                    ),
                    if (badge.isNotEmpty)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 9, vertical: 2),
                        decoration: BoxDecoration(
                            color: tone.withOpacity(0.22),
                            borderRadius: BorderRadius.circular(10)),
                        child: Text(badge,
                            style: TextStyle(
                                fontWeight: FontWeight.w700, color: p.ink)),
                      ),
                    if (onAdd != null)
                      Builder(
                        builder: (bc) => IconButton(
                          visualDensity: VisualDensity.compact,
                          padding: EdgeInsets.zero,
                          constraints:
                              const BoxConstraints(minWidth: 36, minHeight: 36),
                          tooltip: tx('Ekle'),
                          onPressed: () {
                            final rb = bc.findRenderObject() as RenderBox;
                            onAdd!(rb.localToGlobal(rb.size.center(Offset.zero)));
                          },
                          icon: Icon(Icons.add_circle_outline_rounded, color: tone),
                        ),
                      ),
                    const SizedBox(width: 4),
                    AnimatedRotation(
                      turns: open ? 0.5 : 0,
                      duration: const Duration(milliseconds: 200),
                      child: Icon(Icons.expand_more_rounded, color: tone),
                    ),
                  ],
                ),
              ),
            ),
          ),
          ),
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: open
                ? child
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    ),
    );
  }
}

// ---------------------------------------------------------------
// KAYDIRARAK GİZLE
//  Çocuk (bölüm ya da çubuk) parmakla birlikte sola kayar, arkasında "Gizle" zemini
//  görünür. Yeterince kaydırılırsa tamamen çıkar ve [onHide] çağrılır, yoksa yerine döner.
//  wrap(...) ile sarılan alan kaydırmayı başlatır (bölümlerde yalnız başlık: satırların
//  kendi sil/düzenle kaydırması karışmasın). Sağa hızlı itme: [onRight] (önceki gün).
// ---------------------------------------------------------------
class _SwipeHide extends StatefulWidget {
  final Widget Function(BuildContext context, Widget Function(Widget) wrap)
      builder;
  final VoidCallback? onHide;
  final VoidCallback? onRight;
  final String label;
  final double radius;
  final EdgeInsets inset; // zeminin çocuktan içeri payı (kenar boşlukları)
  const _SwipeHide({
    super.key,
    required this.builder,
    required this.label,
    this.onHide,
    this.onRight,
    this.radius = 16,
    this.inset = EdgeInsets.zero,
  });

  @override
  State<_SwipeHide> createState() => _SwipeHideState();
}

class _SwipeHideState extends State<_SwipeHide>
    with SingleTickerProviderStateMixin {
  late final AnimationController _a = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 200));
  double _dx = 0;
  double _from = 0;
  double _to = 0;
  double _w = 0;

  @override
  void initState() {
    super.initState();
    _a.addListener(() {
      setState(() =>
          _dx = _from + (_to - _from) * Curves.easeOutCubic.transform(_a.value));
    });
  }

  @override
  void dispose() {
    _a.dispose();
    super.dispose();
  }

  void _animate(double to, {VoidCallback? done}) {
    _from = _dx;
    _to = to;
    _a.forward(from: 0).whenComplete(() {
      if (mounted) done?.call();
    });
  }

  Widget _wrap(Widget w) => GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) {
          if (widget.onHide == null || _w <= 0) return;
          if (_a.isAnimating) _a.stop();
          setState(() => _dx = (_dx + d.delta.dx).clamp(-_w, 0.0).toDouble());
        },
        onHorizontalDragEnd: (d) {
          final v = d.primaryVelocity ?? 0;
          if (widget.onHide != null &&
              _dx < -8 &&
              (_dx < -_w * 0.3 || v < -700)) {
            _animate(-_w, done: widget.onHide);
          } else {
            if (v > 250 && _dx > -8) widget.onRight?.call();
            _animate(0);
          }
        },
        onHorizontalDragCancel: () => _animate(0),
        child: w,
      );

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return LayoutBuilder(builder: (context, c) {
      _w = c.maxWidth.isFinite ? c.maxWidth : 0;
      return Stack(
        children: [
          if (_dx < -0.5)
            Positioned.fill(
              child: Padding(
                padding: widget.inset,
                child: Container(
                  decoration: BoxDecoration(
                      color: p.editBg,
                      borderRadius: BorderRadius.circular(widget.radius)),
                  alignment: Alignment.centerRight,
                  padding: const EdgeInsets.symmetric(horizontal: 20),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(widget.label,
                          style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                              color: p.ink)),
                      const SizedBox(width: 8),
                      Icon(Icons.visibility_off_outlined, color: p.ink),
                    ],
                  ),
                ),
              ),
            ),
          Transform.translate(
            offset: Offset(_dx, 0),
            child: widget.builder(context, _wrap),
          ),
        ],
      );
    });
  }
}

// ---------------------------------------------------------------
// TEK SATIR: bir rutin / kayıt
//  Solda ≡ (sürükleyip sırala), sağda zil (rutin hatırlatması).
//  Sağa kaydır: düzenle (veri, günler, hatırlatma saati).
//  Sola KISA kaydır: rutini sadece o güne özel kaldır.
//  Sola TAMAMEN kaydır: rutini bugünden itibaren tamamen kaldır (uyarı sorar).
// ---------------------------------------------------------------
class _DayRow extends StatefulWidget {
  final int index;
  final Category cat;
  final SubCat sub;
  final Entry? entry;
  final String date;
  final VoidCallback onEdit;
  final void Function(bool full) onRemove; // true: tamamen kaldır
  final VoidCallback onBell;

  const _DayRow({
    super.key,
    required this.index,
    required this.cat,
    required this.sub,
    required this.entry,
    required this.date,
    required this.onEdit,
    required this.onRemove,
    required this.onBell,
  });

  @override
  State<_DayRow> createState() => _DayRowState();
}

class _DayRowState extends State<_DayRow> with SingleTickerProviderStateMixin {
  final _ctrl = TextEditingController();
  final _pn = ValueNotifier<double>(0); // sola kaydırma dolumu (silme)
  final _pe = ValueNotifier<double>(0); // sağa kaydırma dolumu (düzenle)
  late final AnimationController _out = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 230)); // silinirken küçülüp solar
  double _prog = 0; // sola kaydırma ilerlemesi (0..1), parmak basılıyken ölçülür
  bool _down = false; // parmak şu an ekranda mı
  bool _editing = false; // değere dokunuldu: mevcut veri yeniden girilebilir
  final _fn = FocusNode();

  @override
  void initState() {
    super.initState();
    // Kutunun dışına dokunulursa düzenleme kapanır (değer değişmez)
    _fn.addListener(() {
      if (!_fn.hasFocus && _editing) {
        Future<void>.delayed(const Duration(milliseconds: 200), () {
          if (mounted && _editing && !_fn.hasFocus) setState(() => _editing = false);
        });
      }
    });
  }

  // Değere dokununca: mevcut değer kutuya yazılır ve hepsi seçilir (yazınca üzerine geçer)
  void _startEdit(double v) {
    final t = v == v.roundToDouble() ? v.toInt().toString() : v.toString().replaceAll('.', ',');
    setState(() {
      _editing = true;
      _ctrl.text = t;
      _ctrl.selection = TextSelection(baseOffset: 0, extentOffset: t.length);
    });
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _fn.requestFocus();
    });
  }

  @override
  void dispose() {
    _fn.dispose();
    _ctrl.dispose();
    _pn.dispose();
    _pe.dispose();
    _out.dispose();
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
    _editing = false;
    FocusScope.of(context).unfocus();
    if (mounted) setState(() {});
  }

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

    final hasBell = sub.routine && sub.rh >= 0;

    final content = Container(
      decoration: BoxDecoration(
        color: met ? p.okBg : p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      padding: const EdgeInsets.fromLTRB(2, 6, 8, 6),
      child: Row(
        children: [
          // ≡ sıralama tutamacı
          ReorderableDragStartListener(
            index: widget.index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Icon(Icons.drag_handle_rounded, size: 22, color: p.soft),
            ),
          ),
          Expanded(
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: sub.link.isEmpty
                  ? null
                  : () => openLink(context, sub.link),
              child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Flexible(
                      child: Text(sub.name,
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: p.ink)),
                    ),
                    if (sub.link.isNotEmpty)
                      Padding(
                        padding: const EdgeInsets.only(left: 6),
                        child: Icon(linkIcon(sub.link), size: 15, color: p.soft),
                      ),
                  ],
                ),
                Text(info,
                    style: TextStyle(fontSize: 11.5, color: p.soft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
            ),
          ),
          if (e != null && !_editing)
            // Veri varsa: değer + kalan bilgisi. Dokununca yeniden girilebilir.
            InkWell(
              borderRadius: BorderRadius.circular(8),
              onTap: () => _startEdit(e.value),
              child: Padding(
              padding: const EdgeInsets.all(6),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text('${fmt(e.value)} $unit',
                      style: TextStyle(
                          fontSize: 15.5,
                          fontWeight: FontWeight.w700,
                          color: p.ink)),
                  if (remain != null)
                    Text(remain, style: TextStyle(fontSize: 11.5, color: p.soft)),
                ],
              ),
            ),
            )
          else ...[
            // Veri yoksa: satırın yanında giriş kutusu
            SizedBox(
              width: 70,
              child: TextField(
                controller: _ctrl,
                focusNode: _fn,
                keyboardType: numberKeyboard,
                inputFormatters: numberFormatters,
                textAlign: TextAlign.center,
                onSubmitted: (_) => _submit(),
                decoration: InputDecoration(
                  isDense: true,
                  hintText: unit.isEmpty ? '0' : unit,
                  contentPadding:
                      const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(10)),
                ),
              ),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              onPressed: _submit,
              icon: const Icon(Icons.check_circle_rounded),
              color: Theme.of(context).colorScheme.primary,
            ),
          ],
        ],
      ),
    );

    // Sola kaydırırken arka plan dolar: kısa = bu gün, uzun = tüm günler
    final delBg = FxFillBg(
      prog: _pn,
      base: p.delBg,
      strong: const Color(0xFFD9534F),
      icon: Icons.delete_outline_rounded,
      hotIcon: Icons.delete_forever_rounded,
      align: Alignment.centerRight,
      label: (v) => v >= 0.6 ? tx('Tüm günlerden') : tx('Sadece bu gün'),
    );
    final editBg = FxFillBg(
      prog: _pe,
      base: p.editBg,
      strong: const Color(0xFF4F8EF7),
      icon: Icons.edit_rounded,
      align: Alignment.centerLeft,
      hot: 0.3,
    );

    final shown = Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Listener(
          onPointerDown: (_) {
            _down = true;
            _prog = 0;
            _pn.value = 0;
            _pe.value = 0;
          },
          onPointerUp: (_) => _down = false,
          onPointerCancel: (_) => _down = false,
          child: Dismissible(
          key: ValueKey('dm_${sub.id}_${widget.date}'),
          dismissThresholds: const {
            DismissDirection.startToEnd: 0.3,
            DismissDirection.endToStart: 0.25,
          },
          // Karar, parmak ekrandayken ulaşılan miktara göre verilir. Parmak
          // kalkınca Flutter satırı sonuna kadar kaydırır (progress hep 1 olur);
          // o yüzden bırakıldıktan sonraki değerler yok sayılır.
          onUpdate: (d) {
            if (_down) {
              (d.direction == DismissDirection.endToStart ? _pn : _pe).value =
                  d.progress;
            }
            if (d.direction == DismissDirection.endToStart && _down) {
              final f = d.progress >= 0.6;
              if (f != (_prog >= 0.6)) setState(() => _prog = d.progress);
              _prog = d.progress;
            }
          },
          background: editBg,
          secondaryBackground: delBg,
          // Satır ağaçtan kalkmaz: işlem yapılır, satır yerine döner
          confirmDismiss: (dir) async {
            if (dir == DismissDirection.startToEnd) {
              _pe.value = 0;
              widget.onEdit(); // sağa kaydır: düzenle
            } else {
              final f = _prog >= 0.6;
              _prog = 0;
              _pn.value = 0;
              if (fxLevel() > 0 && !f) {
                // kısa kaydırma: satır küçülüp solar, sonra o güne özel kaldırılır
                await _out.forward();
                widget.onRemove(false);
                Future<void>.delayed(const Duration(milliseconds: 500), () {
                  if (mounted) _out.reverse(); // satır hâlâ duruyorsa geri gelir
                });
              } else {
                widget.onRemove(f); // sola kaydır: kısa = bu gün, uzun = tamamen
              }
            }
            return false;
          },
          child: FxShine(
            radius: 14,
            phase: widget.index,
            met: widget.entry != null && goalMet(widget.sub, widget.entry!.value),
            flashKey: widget.entry?.value,
            child: content,
          ),
          ),
        ),
      ),
    );
    return FadeTransition(
      opacity: ReverseAnimation(_out),
      child: SizeTransition(
        sizeFactor: ReverseAnimation(_out),
        axisAlignment: -1,
        child: shown,
      ),
    );
  }
}

// ---------------------------------------------------------------
// SERBEST SATIR: başlığı ve verisi serbest metin olan satır
// ---------------------------------------------------------------
class _FreeRowTile extends StatelessWidget {
  final int index;
  final FreeRow row;
  final VoidCallback onEdit;
  final VoidCallback onDelete;

  const _FreeRowTile({
    super.key,
    required this.index,
    required this.row,
    required this.onEdit,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final content = Container(
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      padding: const EdgeInsets.fromLTRB(2, 6, 12, 6),
      child: Row(
        children: [
          ReorderableDragStartListener(
            index: index,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 8),
              child: Icon(Icons.drag_handle_rounded, size: 22, color: p.soft),
            ),
          ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(row.title,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p.ink)),
                if (row.remindMs > 0)
                  Text('🔔 ${dtLabel(row.remindMs)}',
                      style: TextStyle(fontSize: 11.5, color: p.soft)),
              ],
            ),
          ),
          if (row.text.isNotEmpty) ...[
            const SizedBox(width: 8),
            Flexible(
              child: Text(row.text,
                  textAlign: TextAlign.right,
                  maxLines: 3,
                  overflow: TextOverflow.ellipsis,
                  style: TextStyle(fontSize: 14, color: p.ink)),
            ),
          ],
        ],
      ),
    );
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Dismissible(
          key: ValueKey('dmf_${row.id}'),
          background:
              _swipeBg(p.editBg, Icons.edit_rounded, Alignment.centerLeft),
          secondaryBackground: _swipeBg(
              p.delBg, Icons.delete_outline_rounded, Alignment.centerRight),
          confirmDismiss: (dir) async {
            if (dir == DismissDirection.startToEnd) {
              onEdit();
            } else {
              onDelete();
            }
            return false;
          },
          child: FxShine(radius: 14, phase: index, child: content),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// KÖŞE DÜĞMESİ: sağ altta yuvarlak DR (Daily Routine)
// ---------------------------------------------------------------
class _CornerBtn extends StatelessWidget {
  final String letter;
  final String tooltip;
  final bool active;
  final VoidCallback onTap;
  const _CornerBtn(
      {required this.letter,
      required this.tooltip,
      required this.onTap,
      this.active = false});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return FloatingActionButton(
      heroTag: null,
      tooltip: tooltip,
      onPressed: onTap,
      backgroundColor: p.accent,
      foregroundColor: p.onAccent,
      shape: const CircleBorder(),
      elevation: active ? 1 : 4,
      child: Text(letter,
          style: const TextStyle(
              fontSize: 20, fontWeight: FontWeight.w800, letterSpacing: 0.5)),
    );
  }
}
