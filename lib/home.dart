import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'about.dart';
import 'add_sheet.dart';
import 'data.dart';
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
import 'prayer.dart';
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
  bool _wxOpen = false; // saatlik hava paneli açık mı
  // Rutinlerin altındaki açılır başlıklar ('todo', 'note', 'rem')
  final Set<String> _openSec = {};
  String? _catFilter; // null: tüm kategoriler, aksi halde seçili kategori kimliği

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    weather.ensure(); // hava durumu açıksa verisini yükle
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
    setState(() {
      day = dayOnly(DateTime.now());
      _wxOpen = false;
      _openSec.clear();
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

  /// Ekle paneli: sağ alttaki DR düğmesinin üstünde, ekranın yarısına kadar açılır.
  /// DR düğmesi görünür kalır; tekrar basınca panel kapanır.
  void _openAdd() {
    final p = palOf(context);
    final date = dKey(day);
    Navigator.of(context).push(PageRouteBuilder<void>(
      opaque: false,
      barrierDismissible: true,
      barrierLabel: tx('Kapat'),
      barrierColor: Colors.black38,
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (ctx, a, b) {
        final m = MediaQuery.of(ctx);
        final kb = m.viewInsets.bottom; // klavye açıksa panel yukarı kayar
        final keyboard = kb > 0;
        // DR düğmesinin yüksekliği (56) + kenar boşlukları
        final btnBottom = 16 + m.padding.bottom;
        final panelBottom = keyboard ? kb + 8 : btnBottom + 56 + 10;
        final panelH = keyboard
            ? (m.size.height - kb - m.padding.top - 20)
            : m.size.height * 0.5;
        final scale = CurvedAnimation(
            parent: a,
            curve: Curves.easeOutCubic,
            reverseCurve: Curves.easeInCubic);
        return Stack(
          children: [
            Positioned(
              left: 10,
              right: 10,
              bottom: panelBottom,
              height: panelH,
              child: ScaleTransition(
                scale: scale,
                alignment: Alignment.bottomRight,
                child: FadeTransition(
                  opacity: scale,
                  child: Material(
                    color: p.bg,
                    elevation: 10,
                    borderRadius: BorderRadius.circular(24),
                    clipBehavior: Clip.antiAlias,
                    child: Column(
                      children: [
                        Container(
                          margin: const EdgeInsets.only(top: 8, bottom: 2),
                          width: 40,
                          height: 4,
                          decoration: BoxDecoration(
                              color: p.line,
                              borderRadius: BorderRadius.circular(2)),
                        ),
                        Expanded(child: AddSheet(date: date)),
                      ],
                    ),
                  ),
                ),
              ),
            ),
            // DR düğmesi panelin altında görünür kalır; basınca panel kapanır
            if (!keyboard)
              Positioned(
                right: 16,
                bottom: btnBottom,
                child: _CornerBtn(
                  letter: 'DR',
                  tooltip: 'Daily Routine',
                  active: true,
                  onTap: () => Navigator.of(ctx).pop(),
                ),
              ),
          ],
        );
      },
    ));
  }

  // ----- Satır işlemleri -----

  /// Sağa kaydırma: veriyi, rutin günlerini ve hatırlatma saatini düzenler
  Future<void> _editRow(_RowData r) async {
    final sub = r.sub!;
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
    if (sub.routine) {
      store.setRoutineOptions(sub.id, days: res.days, rh: res.rh, rm: res.rm);
      if (res.rh >= 0) await permissionMessage();
      await Notifier.syncSub(sub);
    }
  }

  /// Zil: rutinin günlük hatırlatma saati
  Future<void> _bell(SubCat sub) async {
    final r = await showRoutineBell(context, sub);
    if (r == null) return;
    store.setRoutineOptions(sub.id, days: sub.days, rh: r.$1, rm: r.$2);
    if (r.$1 >= 0) {
      final messenger = ScaffoldMessenger.of(context);
      final msg = await permissionMessage();
      if (msg != null) messenger.showSnackBar(SnackBar(content: Text(msg)));
    }
    await Notifier.syncSub(sub);
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
            onBell: () => _bell(r.sub!),
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
        final children = <Widget>[
          if (routinesTotal > 0)
            _HomeSection(
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
          if (othersTotal > 0)
            _HomeSection(
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
        ];

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
                    if (children.isEmpty)
                      Padding(
                        padding: const EdgeInsets.fromLTRB(16, 20, 16, 12),
                        child: Text(
                          tx('Bu gün için kayıt yok.\nSağ alttaki DR düğmesine dokunarak rutin veya kayıt ekleyebilirsin.'),
                          textAlign: TextAlign.center,
                          style: TextStyle(color: p.soft, height: 1.4),
                        ),
                      ),
                    const SizedBox(height: 10),
                    // ----- Açılır başlıklar: Yapılacaklar / Günlük / Hatırlatıcı -----
                    _HomeSection(
                      icon: Icons.task_alt_rounded,
                      title: tx('Yapılacaklar'),
                      tone: const Color(0xFF2FB38A),
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
                    _HomeSection(
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
                    _HomeSection(
                      icon: Icons.notifications_active_outlined,
                      title: tx('Hatırlatıcı'),
                      tone: const Color(0xFFF08A3C),
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

        final scaffold = Scaffold(
          key: _scaffoldKey,
          drawer: const AppDrawer(),
          endDrawer: const ToolsDrawer(),
          endDrawerEnableOpenDragGesture: false, // günler arası kaydırmayla karışmasın
          appBar: AppBar(
            backgroundColor: p.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            centerTitle: true,
            titleSpacing: 0,
            leadingWidth: 92,
            leading: Row(
              children: [
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  icon: const Icon(Icons.menu_rounded),
                  onPressed: () => _scaffoldKey.currentState?.openDrawer(),
                ),
                IconButton(
                  visualDensity: VisualDensity.compact,
                  padding: EdgeInsets.zero,
                  constraints: const BoxConstraints(minWidth: 44, minHeight: 44),
                  tooltip: tx('Ders çalışma'),
                  icon: const Icon(Icons.menu_book_rounded),
                  onPressed: () => Navigator.of(context)
                      .push(slideFromRight(const StudyPage())),
                ),
              ],
            ),
            // Tarih seçici en üstte: < Bugün • 3 Kasım >
            title: Row(
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
                    child: Text(_label(),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 15.5,
                            fontWeight: FontWeight.w600,
                            color: p.ink)),
                  ),
                ),
                // Hava durumu: bugün = şimdiki, diğer günler = günlük simge
                WxChip(
                  date: date,
                  open: _wxOpen,
                  onTap: () => setState(() => _wxOpen = !_wxOpen),
                ),
                IconButton(
                    visualDensity: VisualDensity.compact,
                    padding: EdgeInsets.zero,
                    constraints:
                        const BoxConstraints(minWidth: 32, minHeight: 40),
                    onPressed: () => _shift(1),
                    icon: const Icon(Icons.chevron_right_rounded)),
              ],
            ),
            actions: [
              // Sağdan açılan Araçlar menüsü
              IconButton(
                tooltip: tx('Araçlar'),
                onPressed: () => _scaffoldKey.currentState?.openEndDrawer(),
                icon: const Icon(Icons.handyman_outlined),
              ),
              // Sağdan açılan Müzik ve Radyo sayfası
              ListenableBuilder(
                listenable: media,
                builder: (context, _) => IconButton(
                  tooltip: tx('Müzik ve Radyo'),
                  onPressed: () =>
                      Navigator.of(context).push(slideFromRight(const MediaPage())),
                  icon: Icon(media.nowId != null && media.playing
                      ? Icons.graphic_eq_rounded
                      : Icons.headphones_rounded),
                ),
              ),
            ],
          ),
          body: Builder(builder: (context) {
            // Hava simgesi hava + namaz vakitleri çubuğunu açar/kapatır (sabit kalır).
            // Hava kapalıysa namaz vakitleri her zaman görünür.
            final open = _wxOpen || !store.wxOn;
            final topWx = _wxOpen && store.wxOn && store.wxPlace == 0;
            final sideWx = _wxOpen && store.wxOn && store.wxPlace == 1;
            final topPr = store.prayOn && store.prayPlace == 0 && open;
            final sidePr = store.prayOn && store.prayPlace == 1 && open;
            return Column(
              children: [
                if (topWx) WxPanel(key: ValueKey('wx_$date'), date: date),
                if (topPr) const PrayerBar(),
                Expanded(
                  child: (sideWx || sidePr)
                      ? Row(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            SizedBox(
                              width: 76,
                              child: Column(
                                children: [
                                  if (sideWx)
                                    Expanded(
                                        child: WxSide(
                                            key: ValueKey('wxs_$date'),
                                            date: date)),
                                  if (sidePr) const PrayerBar(vertical: true),
                                ],
                              ),
                            ),
                            Expanded(child: body),
                          ],
                        )
                      : body,
                ),
              ],
            );
          }),
        );

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
              // Sağ altta yuvarlak DR düğmesi: Ekle panelini açar
              Positioned(
                right: 16,
                bottom: 16 + MediaQuery.of(context).padding.bottom,
                child: _CornerBtn(
                  letter: 'DR',
                  tooltip: 'Daily Routine',
                  onTap: _openAdd,
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
  final Widget child;
  const _HomeSection({
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
    final head =
        Color.alphaBlend(tone.withOpacity(p.dark ? 0.20 : 0.13), p.card);
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: tone.withOpacity(p.dark ? 0.55 : 0.42)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: head,
            borderRadius: BorderRadius.vertical(
                top: const Radius.circular(15),
                bottom: Radius.circular(open ? 0 : 15)),
            child: InkWell(
              borderRadius: BorderRadius.circular(15),
              onTap: onToggle,
              child: Padding(
                padding: const EdgeInsets.fromLTRB(14, 12, 10, 12),
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
          AnimatedSize(
            duration: const Duration(milliseconds: 200),
            alignment: Alignment.topCenter,
            child: open
                ? child
                : const SizedBox(width: double.infinity, height: 0),
          ),
        ],
      ),
    );
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

class _DayRowState extends State<_DayRow> {
  final _ctrl = TextEditingController();
  double _prog = 0; // sola kaydırma ilerlemesi (0..1), parmak basılıyken ölçülür
  bool _down = false; // parmak şu an ekranda mı

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
          // Zil: ≡ tutamacının hemen yanında (sadece rutinlerde)
          if (sub.routine)
            IconButton(
              tooltip: tx('Hatırlatma'),
              visualDensity: VisualDensity.compact,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(minWidth: 36, minHeight: 36),
              onPressed: widget.onBell,
              icon: Icon(
                hasBell
                    ? Icons.notifications_active_rounded
                    : Icons.notifications_none_rounded,
                size: 22,
                color: hasBell
                    ? Theme.of(context).colorScheme.primary
                    : p.soft,
              ),
            ),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(sub.name,
                    style: TextStyle(
                        fontSize: 15,
                        fontWeight: FontWeight.w600,
                        color: p.ink)),
                Text(info,
                    style: TextStyle(fontSize: 11.5, color: p.soft),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
          if (e != null)
            // Veri varsa: değer + kalan bilgisi
            Padding(
              padding: const EdgeInsets.all(2),
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
            )
          else ...[
            // Veri yoksa: satırın yanında giriş kutusu
            SizedBox(
              width: 70,
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

    // Sola kaydırırken arka plan yazısı: kısa = bu gün, uzun = tüm günler
    final full = _prog >= 0.6;
    final delBg = Container(
      color: p.delBg,
      alignment: Alignment.centerRight,
      padding: const EdgeInsets.symmetric(horizontal: 18),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(full ? tx('Tüm günlerden') : tx('Sadece bu gün'),
              style: TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                  color: p.ink)),
          const SizedBox(width: 8),
          Icon(full ? Icons.delete_forever_rounded : Icons.delete_outline_rounded),
        ],
      ),
    );

    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(14),
        child: Listener(
          onPointerDown: (_) {
            _down = true;
            _prog = 0;
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
            if (d.direction == DismissDirection.endToStart && _down) {
              final f = d.progress >= 0.6;
              if (f != (_prog >= 0.6)) setState(() => _prog = d.progress);
              _prog = d.progress;
            }
          },
          background:
              _swipeBg(p.editBg, Icons.edit_rounded, Alignment.centerLeft),
          secondaryBackground: delBg,
          // Satır ağaçtan kalkmaz: işlem yapılır, satır yerine döner
          confirmDismiss: (dir) async {
            if (dir == DismissDirection.startToEnd) {
              widget.onEdit(); // sağa kaydır: düzenle
            } else {
              final f = _prog >= 0.6;
              _prog = 0;
              widget.onRemove(f); // sola kaydır: kısa = bu gün, uzun = tamamen
            }
            return false;
          },
          child: content,
          ),
        ),
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
          child: content,
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
