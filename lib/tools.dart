import 'dart:async';
import 'dart:math' show cos, pi;
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'notify.dart';
import 'package:audioplayers/audioplayers.dart';
import 'package:file_picker/file_picker.dart';
import 'package:just_audio/just_audio.dart' show LoopMode;
import 'media.dart';
import 'online.dart';
import 'podcast.dart';
import 'reminders.dart' show dtLabel;
import 'theme.dart' show Pal;
import 'strings.dart';
import 'timing.dart';
import 'ui.dart';
import 'wxdetail.dart';

// ---------------------------------------------------------------
// ARAÇLAR (ana ekranın sağ üstündeki simgeden açılan sağ menü)
//  Kronometre, Sayaç (geri sayım), Pomodoro, Nefes, Zikirmatik,
//  Su sayacı, Uyku. Sonuçlar bir rutine (örn. Meditasyon, Su, Uyku)
//  bugünün değeri olarak EKLENİR; rutin yoksa "Diğer kayıtlar"a
//  serbest satır olarak yazılır. Her kayıtta "Geri al" çıkar.
// ---------------------------------------------------------------

class _ToolInfo {
  final String id;
  final IconData icon;
  final String name;
  final Color tone;
  final Widget Function() page;
  final String group; // grup kimliği: health | time | weather
  const _ToolInfo(this.id, this.icon, this.name, this.tone, this.page,
      {required this.group});
}

String _groupTitle(String g) {
  switch (g) {
    case 'health':
      return tx('Sağlık ve denge');
    case 'time':
      return tx('Zaman ve sayaçlar');
    default:
      return tx('Hava durumu');
  }
}

const _defaultGroupOrder = ['health', 'time', 'weather'];

// Kapalı (daraltılmış) gruplar; çekmece kapanıp açılınca da hatırlanır
final Set<String> _closedGroups = {};

/// Hazır sıra (varsayılan); kullanıcının sıralaması bunun üstüne uygulanır
List<_ToolInfo> _allTools() => [
      _ToolInfo('meditate', Icons.self_improvement_rounded, tx('Meditasyon'),
          const Color(0xFF8E6CEF), () => const MeditatePage(),
          group: 'health'),
      _ToolInfo('breath', Icons.air_rounded, tx('Nefes'),
          const Color(0xFF2BA7C9), () => const BreathPage(),
          group: 'health'),
      _ToolInfo('water', Icons.water_drop_outlined, tx('Su sayacı'),
          const Color(0xFF3BA3E8), () => const WaterPage(),
          group: 'health'),
      _ToolInfo('timer', Icons.hourglass_bottom_rounded, tx('Sayaç'),
          const Color(0xFFE9A23B), () => const TimerPage(),
          group: 'time'),
      _ToolInfo('pomodoro', Icons.local_fire_department_outlined,
          tx('Pomodoro'), const Color(0xFFE8674A), () => const PomodoroPage(),
          group: 'time'),
      _ToolInfo('stopwatch', Icons.timer_outlined, tx('Kronometre'),
          const Color(0xFF4F8EF7), () => const StopwatchPage(),
          group: 'time'),
      _ToolInfo('zikir', Icons.touch_app_outlined, tx('Zikirmatik'),
          const Color(0xFF2FB38A), () => const ZikirPage(),
          group: 'time'),
      _ToolInfo('zamanlama', Icons.alarm_rounded, tx('Zamanlama'),
          const Color(0xFF7E57C2), () => const ZamanlamaPage(),
          group: 'time'),
      _ToolInfo('wx', Icons.wb_sunny_outlined, tx('Hava durumu'),
          const Color(0xFF3E9FD6), () => const WxDetailPage(),
          group: 'weather'),
    ];

/// Kullanıcının sıralamasına göre gruplar ve içindeki araçlar
List<(String, List<_ToolInfo>)> _grouped() {
  final all = _allTools();
  final gOrder = [
    ...store.toolGroupOrder.where(_defaultGroupOrder.contains),
    ..._defaultGroupOrder.where((g) => !store.toolGroupOrder.contains(g)),
  ];
  int rank(_ToolInfo t) {
    final i = store.toolOrder.indexOf(t.id);
    return i < 0 ? 1000 + all.indexOf(t) : i;
  }

  return [
    for (final g in gOrder)
      (
        g,
        (all.where((t) => t.group == g).toList()
          ..sort((a, b) => rank(a).compareTo(rank(b))))
      ),
  ];
}

/// Yumuşak geçişli sayfa (solarak + hafif yukarı kayarak)
Route<void> _route(Widget page) => PageRouteBuilder<void>(
      transitionDuration: const Duration(milliseconds: 320),
      reverseTransitionDuration: const Duration(milliseconds: 240),
      pageBuilder: (_, __, ___) => page,
      transitionsBuilder: (_, anim, __, child) {
        final c = CurvedAnimation(parent: anim, curve: Curves.easeOutCubic);
        return FadeTransition(
          opacity: c,
          child: SlideTransition(
            position:
                Tween<Offset>(begin: const Offset(0, 0.04), end: Offset.zero)
                    .animate(c),
            child: child,
          ),
        );
      },
    );

/// Araç sayfalarının sağ üstündeki Araçlar simgesi: menüyü açar
class ToolsButton extends StatelessWidget {
  const ToolsButton({super.key});

  @override
  Widget build(BuildContext context) => Builder(
        builder: (ctx) => IconButton(
          tooltip: tx('Araçlar'),
          onPressed: () => Scaffold.of(ctx).openEndDrawer(),
          icon: const Icon(Icons.handyman_outlined),
        ),
      );
}

class ToolsDrawer extends StatefulWidget {
  /// replace: bir araç sayfasının içinden açıldı; seçilen araç bu sayfanın yerine geçer
  final bool replace;
  const ToolsDrawer({super.key, this.replace = false});

  @override
  State<ToolsDrawer> createState() => _ToolsDrawerState();
}

class _ToolsDrawerState extends State<ToolsDrawer> {
  bool _edit = false; // sıralama kipi

  void _open(_ToolInfo t) {
    final nav = Navigator.of(context);
    nav.pop(); // menüyü kapat
    if (widget.replace) {
      nav.pushReplacement(_route(t.page()));
    } else {
      nav.push(_route(t.page()));
    }
  }

  Widget _tile(Pal p, _ToolInfo t, {Widget? handle}) {
    return Padding(
      key: ValueKey('t_${t.id}'),
      padding: const EdgeInsets.fromLTRB(14, 5, 14, 5),
      child: Material(
        color: Color.alphaBlend(t.tone.withOpacity(p.dark ? 0.22 : 0.14), p.card),
        borderRadius: BorderRadius.circular(16),
        child: InkWell(
          borderRadius: BorderRadius.circular(16),
          onTap: _edit ? null : () => _open(t),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
            child: Row(
              children: [
                Container(
                  width: 42,
                  height: 42,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    gradient: LinearGradient(
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                      colors: [t.tone, t.tone.withOpacity(0.65)],
                    ),
                  ),
                  child: Icon(t.icon, color: Colors.white, size: 22),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: Text(t.name,
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                          color: p.ink)),
                ),
                handle ?? Icon(Icons.chevron_right_rounded, color: t.tone),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _groupHeader(Pal p, String g, int i, int n) {
    final closed = _closedGroups.contains(g) && !_edit;
    return InkWell(
      onTap: _edit
          ? null
          : () => setState(() {
                if (!_closedGroups.remove(g)) _closedGroups.add(g);
              }),
      child: Padding(
      padding: const EdgeInsets.fromLTRB(20, 14, 8, 6),
      child: Row(
        children: [
          Expanded(
            child: Text(_groupTitle(g),
                style: TextStyle(
                    fontSize: 21,
                    fontWeight: FontWeight.w800,
                    color: p.ink)),
          ),
          if (!_edit)
            Icon(closed ? Icons.expand_more_rounded : Icons.expand_less_rounded,
                color: p.soft),
          if (_edit) ...[
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: tx('Yukarı'),
              onPressed: i == 0 ? null : () => _moveGroup(i, i - 1),
              icon: const Icon(Icons.keyboard_arrow_up_rounded),
            ),
            IconButton(
              visualDensity: VisualDensity.compact,
              tooltip: tx('Aşağı'),
              onPressed: i >= n - 1 ? null : () => _moveGroup(i, i + 1),
              icon: const Icon(Icons.keyboard_arrow_down_rounded),
            ),
          ],
        ],
      ),
      ),
    );
  }

  void _moveGroup(int from, int to) {
    final ids = [for (final g in _grouped()) g.$1];
    final x = ids.removeAt(from);
    ids.insert(to, x);
    store.setToolGroupOrder(ids);
  }

  void _moveTool(String group, int oldI, int newI) {
    final list = [for (final t in _grouped().firstWhere((g) => g.$1 == group).$2) t.id];
    if (newI > oldI) newI -= 1;
    final x = list.removeAt(oldI);
    list.insert(newI, x);
    // diğer gruplardaki sıra korunur; bu grubun sırası yenilenir
    final rest = [
      for (final g in _grouped())
        if (g.$1 != group)
          for (final t in g.$2) t.id
    ];
    store.setToolOrder([...rest, ...list]);
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Drawer(
      backgroundColor: p.bg,
      child: SafeArea(
        child: ListenableBuilder(
          listenable: store,
          builder: (context, _) {
            final groups = _grouped();
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 16, 8, 0),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(tx('Araçlar'),
                            style: TextStyle(
                                fontSize: 22,
                                fontWeight: FontWeight.w700,
                                color: p.ink)),
                      ),
                      TextButton.icon(
                        onPressed: () => setState(() => _edit = !_edit),
                        icon: Icon(
                            _edit ? Icons.check_rounded : Icons.swap_vert_rounded,
                            size: 18),
                        label: Text(_edit ? tx('Tamam') : tx('Sırala')),
                      ),
                    ],
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 0, 20, 4),
                  child: Text(
                      _edit
                          ? tx('Araçları tutup sürükle; grupları oklarla taşı.')
                          : tx('Süre ve sayıları tek dokunuşla rutinlerine ekle.'),
                      style: TextStyle(color: p.soft, fontSize: 13)),
                ),
                Expanded(
                  child: ListView(
                    padding: EdgeInsets.zero,
                    children: [
                      for (var gi = 0; gi < groups.length; gi++) ...[
                        _groupHeader(p, groups[gi].$1, gi, groups.length),
                        if (_edit)
                          ReorderableListView(
                            shrinkWrap: true,
                            physics: const NeverScrollableScrollPhysics(),
                            buildDefaultDragHandles: false,
                            onReorder: (o, n) => _moveTool(groups[gi].$1, o, n),
                            children: [
                              for (var i = 0; i < groups[gi].$2.length; i++)
                                _tile(p, groups[gi].$2[i],
                                    handle: ReorderableDragStartListener(
                                        index: i,
                                        child: Icon(Icons.drag_handle_rounded,
                                            color: groups[gi].$2[i].tone))),
                            ],
                          )
                        else if (!_closedGroups.contains(groups[gi].$1))
                          for (final t in groups[gi].$2) _tile(p, t),
                      ],
                      const SizedBox(height: 16),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Rutine yazma (ortak)
// ---------------------------------------------------------------

/// kind: 'min' (dakika), 'hr' (saat), 'lt' (litre), 'cnt' (adet)
double _convert(String kind, double v, String unit) {
  final u = unit.toLowerCase().trim();
  final isMin = u == 'dk' || u == 'min';
  final isHr = u == 'saat' || u == 'hours' || u == 'hour';
  final isLt = u == 'lt' || u == 'l';
  double r = v;
  if (kind == 'min') {
    if (isHr) r = v / 60;
  } else if (kind == 'hr') {
    if (isMin) r = v * 60;
  } else if (kind == 'lt') {
    if (u == 'ml') r = v * 1000;
    if (isLt) r = v;
  }
  return double.parse(r.toStringAsFixed(2));
}

bool _fits(String kind, SubCat s) {
  final u = s.unit.toLowerCase().trim();
  switch (kind) {
    case 'min':
    case 'hr':
      return u == 'dk' || u == 'min' || u == 'saat' || u == 'hours';
    case 'lt':
      return u == 'lt' || u == 'l' || u == 'ml';
    default:
      return true;
  }
}

String _kindUnit(String kind) {
  switch (kind) {
    case 'min':
      return tx('dk');
    case 'hr':
      return tx('saat');
    case 'lt':
      return tx('lt');
    default:
      return '';
  }
}

const _presetKeys = <String, List<String>>{
  'breath': ['meditate'],
  'meditate': ['meditate'],
  'water': ['water'],
  'sleep': ['sleep'],
};

/// Aracın bağlı rutini: önce seçilen, yoksa hazır eşleşme
SubCat? defaultSubFor(String tool) {
  final l = store.toolLinks[tool];
  if (l != null) {
    final s = store.subById(l);
    if (s != null) return s;
  }
  final keys = _presetKeys[tool];
  if (keys == null) return null;
  for (final c in store.cats) {
    for (final s in c.subs) {
      if (s.key != null && keys.contains(s.key)) return s;
    }
  }
  return null;
}

class _Choice {
  final String? subId; // null = serbest satır
  final bool remember;
  _Choice(this.subId, this.remember);
}

class _SaveDialog extends StatefulWidget {
  final String tool;
  final String kind;
  final double value;
  const _SaveDialog(
      {required this.tool, required this.kind, required this.value});

  @override
  State<_SaveDialog> createState() => _SaveDialogState();
}

class _SaveDialogState extends State<_SaveDialog> {
  late String _sel;
  bool _remember = true;
  late final List<MapEntry<Category, SubCat>> _subs;

  @override
  void initState() {
    super.initState();
    final all = <MapEntry<Category, SubCat>>[
      for (final c in store.cats)
        for (final s in c.subs)
          if (s.summable) MapEntry(c, s),
    ];
    final fit = all.where((e) => _fits(widget.kind, e.value)).toList();
    _subs = fit.isEmpty ? all : fit;
    // İlk açılışta Serbest satır seçili; "Bu araç için hatırla" ile bir rutin
    // seçildiyse o rutin seçili gelir.
    final linkId = store.toolLinks[widget.tool];
    if (linkId != null && _subs.any((e) => e.value.id == linkId)) {
      _sel = linkId;
    } else {
      _sel = '__free__';
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = _kindUnit(widget.kind);
    return AlertDialog(
      title: Text(tx('Rutine kaydet')),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('${fmt(widget.value)} $unit'.trim(),
                style:
                    const TextStyle(fontSize: 22, fontWeight: FontWeight.w700)),
            const SizedBox(height: 12),
            DropdownButton<String>(
              isExpanded: true,
              value: _sel,
              items: [
                for (final e in _subs)
                  DropdownMenuItem<String>(
                      value: e.value.id,
                      child: Text(
                          '${e.key.name} • ${e.value.name}${e.value.unit.isEmpty ? '' : ' (${e.value.unit})'}',
                          overflow: TextOverflow.ellipsis)),
                DropdownMenuItem<String>(
                    value: '__free__',
                    child: Text(tx('Diğer kayıtlara (serbest satır)'))),
              ],
              onChanged: (v) {
                if (v != null) setState(() => _sel = v);
              },
            ),
            if (_sel != '__free__')
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                controlAffinity: ListTileControlAffinity.leading,
                value: _remember,
                onChanged: (v) => setState(() => _remember = v ?? true),
                title: Text(tx('Bu araç için hatırla')),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context),
            child: Text(tx('Vazgeç'))),
        FilledButton(
            onPressed: () => Navigator.pop(
                context,
                _Choice(_sel == '__free__' ? null : _sel,
                    _sel != '__free__' && _remember)),
            child: Text(tx('Kaydet'))),
      ],
    );
  }
}

/// Değeri bir rutine ekler (ya da serbest satır yazar). Eklendiyse true.
/// ask=false ve bağlı rutin varsa soru sormadan ekler (su sayacı gibi).
Future<bool> saveToRoutine(
  BuildContext context, {
  required String tool,
  required String title,
  required double value,
  required String kind,
  bool ask = true,
  bool quiet = false,
}) async {
  SubCat? sub = defaultSubFor(tool);
  bool free = false;
  if (sub == null || ask) {
    final c = await showDialog<_Choice>(
        context: context,
        builder: (_) => _SaveDialog(tool: tool, kind: kind, value: value));
    if (c == null) return false;
    if (c.subId == null) {
      free = true;
    } else {
      sub = store.subById(c.subId!);
      if (c.remember) store.setToolLink(tool, c.subId);
    }
  }
  if (!context.mounted) return false;
  final today = dKey(DateTime.now());
  if (free || sub == null) {
    final f = store.addFree(
        today, title, '${fmt(value)} ${_kindUnit(kind)}'.trim());
    if (!quiet) {
      showUndo(context, tx('Diğer kayıtlara eklendi.'),
          () => store.deleteFree(f.id));
    }
    return true;
  }
  final s = sub;
  final add = _convert(kind, value, s.unit);
  final prev = store.entryFor(s.id, today);
  final prevVal = prev?.value;
  store.setEntry(s.id, today, (prevVal ?? 0) + add);
  if (quiet) return true;
  showUndo(
      context,
      tx('{0}: {1} {2} eklendi.', [s.name, fmt(add), s.unit]).trim(),
      () {
    if (prevVal == null) {
      final e = store.entryFor(s.id, today);
      if (e != null) store.deleteEntry(e.id);
    } else {
      store.setEntry(s.id, today, prevVal);
    }
  });
  return true;
}

// ---------------------------------------------------------------
// Ortak görünüm yardımcıları
// ---------------------------------------------------------------
String _clock(int totalSec) {
  final h = totalSec ~/ 3600;
  final m = (totalSec % 3600) ~/ 60;
  final s = totalSec % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$mm:$ss';
}

Widget _bigBtn(String label, IconData icon, VoidCallback? onTap,
        {bool filled = true}) =>
    SizedBox(
      height: 52,
      child: filled
          ? FilledButton.icon(
              onPressed: onTap, icon: Icon(icon), label: Text(label))
          : OutlinedButton.icon(
              onPressed: onTap, icon: Icon(icon), label: Text(label)),
    );

Widget _page(BuildContext context, String title, Widget body,
    {Color? tone}) {
  final p = palOf(context);
  return AnimatedContainer(
    duration: const Duration(milliseconds: 700),
    curve: Curves.easeInOut,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [
          tone == null
              ? p.bg
              : Color.alphaBlend(tone.withOpacity(p.dark ? 0.30 : 0.22), p.bg),
          p.bg,
        ],
      ),
    ),
    child: Scaffold(
      backgroundColor: Colors.transparent,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(title),
        actions: const [ToolsButton()],
      ),
      endDrawer: const ToolsDrawer(replace: true),
      body: SafeArea(child: body),
    ),
  );
}

// ---------------------------------------------------------------
// Geri sayım (Sayaç ve Pomodoro ortak kullanır)
// ---------------------------------------------------------------
class _Countdown extends ChangeNotifier {
  final int notifId;
  final String doneText;
  _Countdown(this.notifId, this.doneText);

  DateTime? _end;
  int total = 0; // saniye
  int _pausedLeft = 0;
  Timer? _t;
  VoidCallback? onFinish;

  bool get running => _end != null;
  int get left {
    final e = _end;
    if (e == null) return _pausedLeft;
    final d = e.difference(DateTime.now()).inSeconds + 1;
    return d < 0 ? 0 : d;
  }

  bool get idle => !running && _pausedLeft == total;

  void set(int sec) {
    stop();
    total = sec;
    _pausedLeft = sec;
    notifyListeners();
  }

  void start() {
    if (running || _pausedLeft <= 0) return;
    _end = DateTime.now().add(Duration(seconds: _pausedLeft));
    Notifier.scheduleOnce(notifId, doneText, _end!);
    _t?.cancel();
    _t = Timer.periodic(const Duration(milliseconds: 300), (_) {
      if (left <= 0) {
        _finish();
      } else {
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void pause() {
    if (!running) return;
    _pausedLeft = left;
    _end = null;
    _t?.cancel();
    Notifier.cancelOnce(notifId);
    notifyListeners();
  }

  void stop() {
    _end = null;
    _t?.cancel();
    Notifier.cancelOnce(notifId);
  }

  void reset() {
    stop();
    _pausedLeft = total;
    notifyListeners();
  }

  void _finish() {
    _end = null;
    _t?.cancel();
    _pausedLeft = 0;
    SystemSound.play(SystemSoundType.alert);
    HapticFeedback.heavyImpact();
    notifyListeners();
    onFinish?.call();
  }
}

// ---------------------------------------------------------------
// 1) Kronometre
// ---------------------------------------------------------------
final Stopwatch _sw = Stopwatch();
final List<Duration> _laps = [];

class StopwatchPage extends StatefulWidget {
  const StopwatchPage({super.key});

  @override
  State<StopwatchPage> createState() => _StopwatchPageState();
}

class _StopwatchPageState extends State<StopwatchPage> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(milliseconds: 50), (_) {
      if (_sw.isRunning && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    _sw.stop(); // sayfadan çıkınca duraklar
    super.dispose();
  }

  String _fmtD(Duration d) {
    final cs = (d.inMilliseconds % 1000) ~/ 10;
    return '${_clock(d.inSeconds)}.${cs.toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final e = _sw.elapsed;
    final stopped = !_sw.isRunning && e.inMilliseconds > 0;
    return _page(
      context,
      tx('Kronometre'),
      Column(
        children: [
          const SizedBox(height: 32),
          Text(_fmtD(e),
              style: TextStyle(
                  fontSize: 54,
                  fontWeight: FontWeight.w300,
                  color: p.ink,
                  fontFeatures: const [FontFeature.tabularFigures()])),
          const SizedBox(height: 24),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            alignment: WrapAlignment.center,
            children: [
              _bigBtn(_sw.isRunning ? tx('Durdur') : tx('Başlat'),
                  _sw.isRunning ? Icons.pause_rounded : Icons.play_arrow_rounded,
                  () => setState(() {
                        _sw.isRunning ? _sw.stop() : _sw.start();
                      })),
              if (_sw.isRunning)
                _bigBtn(tx('Tur'), Icons.flag_outlined,
                    () => setState(() => _laps.insert(0, _sw.elapsed)),
                    filled: false),
              if (stopped)
                _bigBtn(tx('Sıfırla'), Icons.restart_alt_rounded, () {
                  setState(() {
                    _sw.reset();
                    _laps.clear();
                  });
                }, filled: false),
            ],
          ),
          if (stopped && e.inSeconds >= 1) ...[
            const SizedBox(height: 10),
            _bigBtn(tx('Rutine kaydet'), Icons.add_task_rounded, () async {
              final min = double.parse((e.inSeconds / 60).toStringAsFixed(1));
              final ok = await saveToRoutine(context,
                  tool: 'stopwatch',
                  title: tx('Kronometre'),
                  value: min,
                  kind: 'min');
              if (ok) {
                setState(() {
                  _sw.reset();
                  _laps.clear();
                });
              }
            }),
          ],
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              itemCount: _laps.length,
              itemBuilder: (_, i) {
                final n = _laps.length - i;
                final prev = i + 1 < _laps.length ? _laps[i + 1] : Duration.zero;
                return ListTile(
                  dense: true,
                  leading: Text('$n', style: TextStyle(color: p.soft)),
                  title: Text(_fmtD(_laps[i] - prev)),
                  trailing: Text(_fmtD(_laps[i]),
                      style: TextStyle(color: p.soft)),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// 2) Sayaç (geri sayım)
// ---------------------------------------------------------------
final _Countdown _timerCtl = _Countdown(888801, tx('Sayaç bitti.'));

class TimerPage extends StatefulWidget {
  const TimerPage({super.key});

  @override
  State<TimerPage> createState() => _TimerPageState();
}

class _TimerPageState extends State<TimerPage> {
  @override
  void initState() {
    super.initState();
    _timerCtl.addListener(_u);
    _timerCtl.onFinish = _done;
    if (_timerCtl.total == 0) _timerCtl.set(5 * 60);
  }

  @override
  void dispose() {
    _timerCtl.removeListener(_u);
    _timerCtl.pause(); // sayfadan çıkınca duraklar, bildirimi iptal olur
    super.dispose();
  }

  void _u() {
    if (mounted) setState(() {});
  }

  void _done() {
    if (!mounted) return;
    showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tx('Sayaç bitti.')),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tx('Tamam'))),
        ],
      ),
    );
  }

  Future<void> _custom() async {
    final v = await askNumber(context,
        title: tx('Kaç dakika?'), unit: tx('dk'), initial: 10);
    if (v == null || v <= 0) return;
    _timerCtl.set((v * 60).round());
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final c = _timerCtl;
    final frac = c.total == 0 ? 0.0 : c.left / c.total;
    final usedMin = double.parse(
        ((c.total - c.left) / 60).toStringAsFixed(1));
    return _page(
      context,
      tx('Sayaç'),
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            const SizedBox(height: 16),
            SizedBox(
              width: 220,
              height: 220,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 220,
                    height: 220,
                    child: CircularProgressIndicator(
                      value: frac,
                      strokeWidth: 10,
                      backgroundColor: p.line,
                    ),
                  ),
                  Text(_clock(c.left),
                      style: TextStyle(
                          fontSize: 46,
                          fontWeight: FontWeight.w300,
                          color: p.ink)),
                ],
              ),
            ),
            const SizedBox(height: 20),
            if (!c.running)
              Wrap(
                spacing: 8,
                children: [
                  for (final m in [1, 5, 10, 15, 25, 45])
                    ChoiceChip(
                      label: Text('$m ${tx('dk')}'),
                      selected: c.total == m * 60,
                      onSelected: (_) => c.set(m * 60),
                    ),
                  ActionChip(
                      avatar: const Icon(Icons.edit_outlined, size: 16),
                      label: Text(tx('Özel')),
                      onPressed: _custom),
                ],
              ),
            const SizedBox(height: 20),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _bigBtn(c.running ? tx('Duraklat') : tx('Başlat'),
                    c.running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    c.left <= 0 ? null : (c.running ? c.pause : c.start)),
                _bigBtn(tx('Sıfırla'), Icons.restart_alt_rounded, c.reset,
                    filled: false),
              ],
            ),
            if (!c.running && usedMin >= 0.5) ...[
              const SizedBox(height: 10),
              _bigBtn(tx('Rutine kaydet'), Icons.add_task_rounded, () async {
                final ok = await saveToRoutine(context,
                    tool: 'timer',
                    title: tx('Sayaç'),
                    value: usedMin,
                    kind: 'min');
                if (ok) c.reset();
              }),
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(tx('Geçen süre: {0} dk', [fmt(usedMin)]),
                    style: TextStyle(color: p.soft, fontSize: 12.5)),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// 3) Pomodoro: çalışma / mola
// ---------------------------------------------------------------
final _Countdown _pomoCtl = _Countdown(888802, tx('Pomodoro: süre doldu.'));
int _pomoRound = 1; // kaçıncı çalışma turu (1..4)
bool _pomoIsWork = true;
int _pomoFocusSec = 0; // tamamlanan çalışma süresi (saniye)
int _pomoStartLeft = 0; // bu çalışma turunun başındaki kalan (kısmi sayım için)

class PomodoroPage extends StatefulWidget {
  final bool autoStart;
  const PomodoroPage({super.key, this.autoStart = false});

  @override
  State<PomodoroPage> createState() => _PomodoroPageState();
}

class _PomodoroPageState extends State<PomodoroPage> {
  @override
  void initState() {
    super.initState();
    _pomoCtl.addListener(_u);
    _pomoCtl.onFinish = _next;
    if (_pomoCtl.total == 0) _prepare();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_pomoCtl.running) _pomoCtl.start();
      });
    }
  }

  @override
  void dispose() {
    _pomoCtl.removeListener(_u);
    _pomoCtl.pause();
    super.dispose();
  }

  void _u() {
    if (mounted) setState(() {});
  }

  void _prepare() {
    final m = _pomoIsWork
        ? store.pomoWork
        : (_pomoRound >= 4 ? store.pomoLong : store.pomoShort);
    _pomoCtl.set(m * 60);
    _pomoStartLeft = m * 60;
  }

  /// Süre dolunca: çalışma süresini topla, sıradaki aşamayı hazırla (duraklı)
  void _next() {
    // Süre bitti: çalışma bitişi derin gong, mola bitişi daha açık zil + titreşim
    if (store.pomoSound) {
      if (_pomoIsWork) {
        _snd.gong();
      } else {
        _snd.bell();
      }
    }
    if (store.pomoVibe) {
      HapticFeedback.heavyImpact();
      Future.delayed(const Duration(milliseconds: 350), HapticFeedback.heavyImpact);
      if (_pomoIsWork) {
        Future.delayed(const Duration(milliseconds: 700), HapticFeedback.heavyImpact);
      }
    }
    if (_pomoIsWork) {
      _pomoFocusSec += store.pomoWork * 60;
      _pomoIsWork = false;
    } else {
      _pomoIsWork = true;
      _pomoRound = _pomoRound >= 4 ? 1 : _pomoRound + 1;
    }
    _prepare();
    if (mounted) setState(() {});
  }

  /// Çalışma / kısa mola / uzun mola sürelerini (dakika) kendin belirle
  Future<void> _editTimes() async {
    final w = await askNumber(context,
        title: tx('Çalışma süresi'),
        unit: tx('dk'),
        initial: store.pomoWork.toDouble());
    if (w == null || !mounted) return;
    final sh = await askNumber(context,
        title: tx('Kısa mola'),
        unit: tx('dk'),
        initial: store.pomoShort.toDouble());
    if (sh == null || !mounted) return;
    final lg = await askNumber(context,
        title: tx('Uzun mola (4 turda bir)'),
        unit: tx('dk'),
        initial: store.pomoLong.toDouble());
    if (lg == null) return;
    setState(() => _preset(w.round(), sh.round(), lg.round()));
  }

  /// O ana kadar odaklanılan toplam süre (tamamlananlar + yarım tur)
  int get _focusNow {
    var s = _pomoFocusSec;
    if (_pomoIsWork) s += _pomoStartLeft - _pomoCtl.left;
    return s;
  }

  void _preset(int w, int s, int l) {
    store.setPomo(work: w, short: s, long: l);
    _pomoIsWork = true;
    _pomoRound = 1;
    _pomoFocusSec = 0;
    _prepare();
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final c = _pomoCtl;
    final frac = c.total == 0 ? 0.0 : c.left / c.total;
    final focusMin = double.parse((_focusNow / 60).toStringAsFixed(1));
    final tone =
        _pomoIsWork ? const Color(0xFFE8674A) : const Color(0xFF3E9E6A);
    return _page(
      context,
      tx('Pomodoro'),
      tone: tone,
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              decoration: BoxDecoration(
                  color: tone.withOpacity(0.18),
                  borderRadius: BorderRadius.circular(20)),
              child: Text(
                  _pomoIsWork
                      ? tx('Çalışma • tur {0}/4', [_pomoRound])
                      : tx('Mola'),
                  style: TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700, color: p.ink)),
            ),
            const SizedBox(height: 18),
            AnimatedContainer(
              duration: const Duration(milliseconds: 500),
              width: 240,
              height: 240,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(colors: [
                  tone.withOpacity(c.running ? 0.30 : 0.16),
                  tone.withOpacity(0.04),
                ]),
                boxShadow: [
                  BoxShadow(
                      color: tone.withOpacity(c.running ? 0.35 : 0.12),
                      blurRadius: c.running ? 36 : 16,
                      spreadRadius: c.running ? 4 : 0),
                ],
              ),
              child: Stack(
                alignment: Alignment.center,
                children: [
                  SizedBox(
                    width: 214,
                    height: 214,
                    child: TweenAnimationBuilder<double>(
                      tween: Tween<double>(begin: frac, end: frac),
                      duration: const Duration(milliseconds: 350),
                      builder: (_, v, __) => CircularProgressIndicator(
                        value: v,
                        strokeWidth: 12,
                        backgroundColor: tone.withOpacity(0.15),
                        color: tone,
                      ),
                    ),
                  ),
                  Text(_clock(c.left),
                      style: TextStyle(
                          fontSize: 48,
                          fontWeight: FontWeight.w300,
                          color: p.ink,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ],
              ),
            ),
            const SizedBox(height: 16),
            if (!c.running && _pomoFocusSec == 0 && c.idle)
              Wrap(
                spacing: 8,
                children: [
                  for (final t in const [
                    [25, 5, 15],
                    [50, 10, 30],
                    [15, 3, 10]
                  ])
                    ChoiceChip(
                      label: Text('${t[0]} / ${t[1]}'),
                      selected: store.pomoWork == t[0] &&
                          store.pomoShort == t[1] &&
                          store.pomoLong == t[2],
                      onSelected: (_) => setState(() => _preset(t[0], t[1], t[2])),
                    ),
                  ActionChip(
                    avatar: const Icon(Icons.tune_rounded, size: 16),
                    label: Text(tx('Süreleri ayarla')),
                    onPressed: _editTimes,
                  ),
                ],
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  avatar: const Icon(Icons.notifications_active_outlined,
                      size: 18),
                  label: Text(tx('Gong')),
                  selected: store.pomoSound,
                  onSelected: (v) {
                    store.setPomoSound(v);
                    setState(() {});
                  },
                ),
                FilterChip(
                  avatar: const Icon(Icons.vibration_rounded, size: 18),
                  label: Text(tx('Titreşim')),
                  selected: store.pomoVibe,
                  onSelected: (v) {
                    store.setPomoVibe(v);
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _bigBtn(c.running ? tx('Duraklat') : tx('Başlat'),
                    c.running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                    c.running ? c.pause : c.start),
                _bigBtn(tx('Atla'), Icons.skip_next_rounded, () {
                  c.stop();
                  // Yarım kalan çalışma turunun geçen süresi de sayılsın
                  if (_pomoIsWork) {
                    _pomoFocusSec += _pomoStartLeft - c.left;
                  }
                  _pomoIsWork = !_pomoIsWork;
                  if (_pomoIsWork) {
                    _pomoRound = _pomoRound >= 4 ? 1 : _pomoRound + 1;
                  }
                  _prepare();
                  setState(() {});
                }, filled: false),
                _bigBtn(tx('Sıfırla'), Icons.restart_alt_rounded, () {
                  _preset(store.pomoWork, store.pomoShort, store.pomoLong);
                  setState(() {});
                }, filled: false),
              ],
            ),
            const SizedBox(height: 16),
            Text(tx('Odaklanılan süre: {0} dk', [fmt(focusMin)]),
                style: TextStyle(color: p.soft)),
            if (focusMin >= 0.5) ...[
              const SizedBox(height: 10),
              _bigBtn(tx('Rutine kaydet'), Icons.add_task_rounded, () async {
                final ok = await saveToRoutine(context,
                    tool: 'pomodoro',
                    title: tx('Pomodoro'),
                    value: focusMin,
                    kind: 'min');
                if (ok) {
                  _preset(store.pomoWork, store.pomoShort, store.pomoLong);
                  setState(() {});
                }
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// 4) Nefes egzersizi
// ---------------------------------------------------------------
class _Pattern {
  final String name;
  final int inh;
  final int hold1;
  final int exh;
  final int hold2;
  const _Pattern(this.name, this.inh, this.hold1, this.exh, this.hold2);
}

const _patterns = [
  _Pattern('4-7-8', 4, 7, 8, 0),
  _Pattern('Kutu 4-4-4-4', 4, 4, 4, 4),
  _Pattern('5-5', 5, 0, 5, 0),
  _Pattern('4-6', 4, 0, 6, 0),
];

class BreathPage extends StatefulWidget {
  final bool autoStart;
  const BreathPage({super.key, this.autoStart = false});

  @override
  State<BreathPage> createState() => _BreathPageState();
}

class _BreathPageState extends State<BreathPage> {
  int _pi = 0;
  bool _on = false;
  Timer? _t;
  int _phase = 0; // 0 al, 1 tut, 2 ver, 3 tut
  double _inPhase = 0; // aşamada geçen saniye
  double _total = 0; // toplam saniye
  double _scale = 0; // 0..1 daire büyüklüğü

  @override
  void initState() {
    super.initState();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_on) _start();
      });
    }
  }

  _Pattern get _p => _patterns[_pi];

  int _dur(int ph) =>
      [_p.inh, _p.hold1, _p.exh, _p.hold2][ph];

  @override
  void dispose() {
    _t?.cancel(); // sayfadan çıkınca duraklar
    _snd.stopAll();
    super.dispose();
  }

  void _start() {
    _on = true;
    _phase = 0;
    _inPhase = 0;
    _scale = 0;
    if (store.medVibe) HapticFeedback.lightImpact();
    _t?.cancel();
    if (store.medSound) {
      // Başlangıç gongu + sessiz başlayan hava sesi
      _snd.gong();
      Timer(const Duration(milliseconds: 2200), () {
        if (mounted && _on) _snd.tone();
      });
      Timer(const Duration(milliseconds: 1500), () {
        if (mounted) _snd.report(context);
      });
    }
    _t = Timer.periodic(const Duration(milliseconds: 50), (_) => _tick());
    setState(() {});
  }

  void _stop() {
    _on = false;
    _t?.cancel();
    _snd.breathStop();
    // Bitişte gong (en az birkaç saniye yapıldıysa)
    if (store.medSound && _total > 3) _snd.gong();
    setState(() {});
  }

  void _tick() {
    _inPhase += 0.05;
    _total += 0.05;
    // Süresi 0 olan aşamaları atla
    while (_dur(_phase) == 0 || _inPhase >= _dur(_phase)) {
      _inPhase = 0;
      _phase = (_phase + 1) % 4;
      if (store.medVibe) {
        if (_phase == 0 || _phase == 2) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      }
      if (store.medSound && (_phase == 0 || _phase == 2) && _total > 1) {
        _snd.tone();
      }
    }
    final f = _inPhase / _dur(_phase);
    if (_phase == 0) _scale = Curves.easeInOut.transform(f);
    if (_phase == 1) _scale = 1;
    if (_phase == 2) _scale = 1 - Curves.easeInOut.transform(f);
    if (_phase == 3) _scale = 0;
    if (mounted) setState(() {});
  }

  String _label() {
    switch (_phase) {
      case 0:
        return tx('Nefes al');
      case 1:
      case 3:
        return tx('Tut');
      default:
        return tx('Nefes ver');
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final size = 120 + 120 * _scale;
    final tone = !_on
        ? const Color(0xFF2BA7C9)
        : (_phase == 0
            ? const Color(0xFF2BA7C9)
            : (_phase == 2 ? const Color(0xFF2FB38A) : const Color(0xFF8E6CEF)));
    final min = double.parse((_total / 60).toStringAsFixed(1));
    return _page(
      context,
      tx('Nefes'),
      tone: tone,
      SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            if (!_on)
              Wrap(
                spacing: 8,
                children: [
                  for (var i = 0; i < _patterns.length; i++)
                    ChoiceChip(
                      label: Text(_patterns[i].name),
                      selected: _pi == i,
                      onSelected: (_) => setState(() => _pi = i),
                    ),
                ],
              ),
            const SizedBox(height: 10),
            Wrap(
              spacing: 8,
              children: [
                FilterChip(
                  avatar: const Icon(Icons.volume_up_rounded, size: 18),
                  label: Text(tx('Nefes sesi')),
                  selected: store.medSound,
                  onSelected: (v) {
                    store.setMedSound(v);
                    if (!v) _snd.stopAll();
                    setState(() {});
                  },
                ),
                FilterChip(
                  avatar: const Icon(Icons.vibration_rounded, size: 18),
                  label: Text(tx('Titreşim')),
                  selected: store.medVibe,
                  onSelected: (v) {
                    store.setMedVibe(v);
                    setState(() {});
                  },
                ),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              height: 290,
              child: Center(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    // dış hale (nefesle birlikte genişler)
                    Container(
                      width: size + 34,
                      height: size + 34,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color: tone.withOpacity(0.10 + 0.08 * _scale),
                      ),
                    ),
                    Container(
                      width: size,
                      height: size,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: RadialGradient(colors: [
                          tone.withOpacity(0.55),
                          tone.withOpacity(0.22),
                        ]),
                        boxShadow: [
                          BoxShadow(
                              color: tone.withOpacity(0.30 + 0.25 * _scale),
                              blurRadius: 18 + 24 * _scale),
                        ],
                        border: Border.all(color: tone, width: 3),
                      ),
                      alignment: Alignment.center,
                      child: Text(_on ? _label() : tx('Hazır'),
                          style: TextStyle(
                              fontSize: 20,
                              fontWeight: FontWeight.w700,
                              color: p.ink)),
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 12),
            Text(_clock(_total.round()), style: TextStyle(color: p.soft)),
            const SizedBox(height: 16),
            Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _bigBtn(_on ? tx('Durdur') : tx('Başlat'),
                    _on ? Icons.stop_rounded : Icons.play_arrow_rounded,
                    _on ? _stop : _start),
                if (!_on && _total > 0)
                  _bigBtn(tx('Sıfırla'), Icons.restart_alt_rounded,
                      () => setState(() => _total = 0),
                      filled: false),
              ],
            ),
            if (!_on && min >= 0.5) ...[
              const SizedBox(height: 10),
              _bigBtn(tx('Rutine kaydet'), Icons.add_task_rounded, () async {
                final ok = await saveToRoutine(context,
                    tool: 'breath',
                    title: tx('Nefes'),
                    value: min,
                    kind: 'min');
                if (ok) setState(() => _total = 0);
              }),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// 5) Zikirmatik / sayaç
// ---------------------------------------------------------------
class ZikirPage extends StatefulWidget {
  const ZikirPage({super.key});

  @override
  State<ZikirPage> createState() => _ZikirPageState();
}

class _ZikirPageState extends State<ZikirPage> {
  Future<void> _customTarget() async {
    final v = await askNumber(context,
        title: tx('Hedef sayı'), initial: store.zikirTarget.toDouble());
    if (v == null || v < 1) return;
    setState(() => store.setZikir(store.zikirCount, target: v.round()));
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final n = store.zikirCount;
    final tg = store.zikirTarget;
    return _page(
      context,
      tx('Zikirmatik'),
      Column(
        children: [
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            children: [
              for (final t in [33, 99, 100])
                ChoiceChip(
                  label: Text('$t'),
                  selected: tg == t,
                  onSelected: (_) =>
                      setState(() => store.setZikir(n, target: t)),
                ),
              ActionChip(
                  avatar: const Icon(Icons.edit_outlined, size: 16),
                  label: Text(tg == 33 || tg == 99 || tg == 100
                      ? tx('Özel')
                      : '$tg'),
                  onPressed: _customTarget),
            ],
          ),
          Expanded(
            child: Center(
              child: GestureDetector(
                onTap: () {
                  final c = store.zikirCount + 1;
                  setState(() => store.setZikir(c));
                  if (c % store.zikirTarget == 0) {
                    HapticFeedback.heavyImpact();
                  } else {
                    HapticFeedback.selectionClick();
                  }
                },
                child: Container(
                  width: 240,
                  height: 240,
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: p.accent.withOpacity(0.2),
                    border: Border.all(color: p.accent, width: 4),
                  ),
                  alignment: Alignment.center,
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text('$n',
                          style: TextStyle(
                              fontSize: 64,
                              fontWeight: FontWeight.w700,
                              color: p.ink)),
                      Text('/ $tg',
                          style: TextStyle(fontSize: 16, color: p.soft)),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _bigBtn(tx('Geri al'), Icons.remove_rounded, n > 0
                    ? () => setState(() => store.setZikir(n - 1))
                    : null,
                    filled: false),
                _bigBtn(tx('Sıfırla'), Icons.restart_alt_rounded, n > 0
                    ? () => setState(() => store.setZikir(0))
                    : null,
                    filled: false),
                _bigBtn(tx('Rutine kaydet'), Icons.add_task_rounded, n > 0
                    ? () async {
                        final ok = await saveToRoutine(context,
                            tool: 'zikir',
                            title: tx('Zikirmatik'),
                            value: n.toDouble(),
                            kind: 'cnt');
                        if (ok) setState(() => store.setZikir(0));
                      }
                    : null),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// 6) Su sayacı: her dokunuş bir bardak ekler
// ---------------------------------------------------------------
class WaterPage extends StatefulWidget {
  const WaterPage({super.key});

  @override
  State<WaterPage> createState() => _WaterPageState();
}

class _WaterPageState extends State<WaterPage> {
  double _todayL(SubCat? s) {
    if (s == null) return 0;
    final e = store.entryFor(s.id, dKey(DateTime.now()));
    return e?.value ?? 0;
  }

  Future<void> _add(double liters) async {
    await saveToRoutine(context,
        tool: 'water',
        title: tx('Su'),
        value: liters,
        kind: 'lt',
        quiet: true,
        ask: defaultSubFor('water') == null);
    if (mounted) setState(() {});
  }

  /// Yuvarlağın doluluk oranı: hedef varsa hedefe göre, yoksa 2 litreye göre
  double _fill(double total, double? goal) {
    final g = (goal != null && goal > 0) ? goal : 2.0;
    return (total / g).clamp(0.0, 1.0);
  }

  Future<void> _sub(SubCat s, double liters) async {
    final today = dKey(DateTime.now());
    final e = store.entryFor(s.id, today);
    if (e == null) return;
    final add = _convert('lt', liters, s.unit);
    final v = e.value - add;
    if (v <= 0) {
      store.deleteEntry(e.id);
    } else {
      store.setEntry(s.id, today, v);
    }
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final s = defaultSubFor('water');
    final glassL = store.glassMl / 1000;
    final total = _todayL(s);
    final goal = s?.goal;
    return _page(
      context,
      tx('Su sayacı'),
      Column(
        children: [
          const SizedBox(height: 12),
          // Miktar: tek alan, solda − sağda +, 25 ml adım; ortaya dokununca elle yazılır
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              IconButton.filledTonal(
                tooltip: '-25 ml',
                onPressed: store.glassMl > 25
                    ? () => setState(() => store.setGlassMl(store.glassMl - 25))
                    : null,
                icon: const Icon(Icons.remove_rounded),
              ),
              const SizedBox(width: 10),
              InkWell(
                borderRadius: BorderRadius.circular(14),
                onTap: () async {
                  final v = await askNumber(context,
                      title: tx('Miktar'),
                      unit: 'ml',
                      initial: store.glassMl.toDouble());
                  if (v != null && v >= 1) {
                    setState(() => store.setGlassMl(v.round().clamp(1, 5000)));
                  }
                },
                child: Container(
                  width: 130,
                  padding: const EdgeInsets.symmetric(vertical: 10),
                  decoration: BoxDecoration(
                    color: p.card,
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(color: p.line),
                  ),
                  alignment: Alignment.center,
                  child: Text('${store.glassMl} ml',
                      style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w600,
                          color: p.ink)),
                ),
              ),
              const SizedBox(width: 10),
              IconButton.filledTonal(
                tooltip: '+25 ml',
                onPressed: () => setState(
                    () => store.setGlassMl((store.glassMl + 25).clamp(1, 5000))),
                icon: const Icon(Icons.add_rounded),
              ),
            ],
          ),
          Expanded(
            child: Center(
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                        s == null
                            ? tx('Henüz bir su rutini seçilmedi')
                            : '${fmt(total)} ${s.unit}',
                        style: TextStyle(
                            fontSize: 44,
                            fontWeight: FontWeight.w300,
                            color: p.ink)),
                    if (s != null && goal != null)
                      Padding(
                        padding: const EdgeInsets.only(top: 6),
                        child: Text(
                            tx('Hedef: {0} {1}', [fmt(goal), s.unit]),
                            style: TextStyle(color: p.soft)),
                      ),
                    const SizedBox(height: 20),
                    // Yuvarlak gösterge: üst yarıya dokun = ekle (dolar),
                    // alt yarıya dokun = çıkar (boşalır). Doluluk hedefe göre.
                    SizedBox(
                      width: 210,
                      height: 210,
                      child: Stack(
                        children: [
                          Positioned.fill(
                            child: ClipOval(
                              child: DecoratedBox(
                                decoration: BoxDecoration(
                                  color: const Color(0xFF5E9BD6)
                                      .withOpacity(0.12),
                                ),
                                child: Align(
                                  alignment: Alignment.bottomCenter,
                                  child: TweenAnimationBuilder<double>(
                                    tween: Tween<double>(
                                        begin: 0,
                                        end: _fill(total, goal)),
                                    duration:
                                        const Duration(milliseconds: 600),
                                    curve: Curves.easeOutCubic,
                                    builder: (_, f, __) => FractionallySizedBox(
                                      heightFactor: f,
                                      widthFactor: 1,
                                      child: DecoratedBox(
                                        decoration: BoxDecoration(
                                          gradient: LinearGradient(
                                            begin: Alignment.topCenter,
                                            end: Alignment.bottomCenter,
                                            colors: [
                                              const Color(0xFF7DB8EC)
                                                  .withOpacity(0.75),
                                              const Color(0xFF3E7FC0)
                                                  .withOpacity(0.85),
                                            ],
                                          ),
                                        ),
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: DecoratedBox(
                              decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                border: Border.all(
                                    color: const Color(0xFF5E9BD6), width: 4),
                              ),
                            ),
                          ),
                          Positioned.fill(
                            child: ClipOval(
                              child: Column(
                                children: [
                                  Expanded(
                                    child: InkWell(
                                      onTap: () {
                                        HapticFeedback.selectionClick();
                                        _add(glassL);
                                      },
                                      child: Center(
                                        child: Column(
                                          mainAxisSize: MainAxisSize.min,
                                          children: [
                                            const Icon(Icons.add_rounded,
                                                size: 30, color: Colors.white),
                                            Text('${store.glassMl} ml',
                                                style: const TextStyle(
                                                    fontWeight:
                                                        FontWeight.w700,
                                                    color: Colors.white,
                                                    shadows: [
                                                      Shadow(
                                                          blurRadius: 6,
                                                          color:
                                                              Colors.black45)
                                                    ])),
                                          ],
                                        ),
                                      ),
                                    ),
                                  ),
                                  Container(
                                      height: 2,
                                      color: Colors.white.withOpacity(0.55)),
                                  Expanded(
                                    child: InkWell(
                                      onTap: s != null && total > 0
                                          ? () {
                                              HapticFeedback.selectionClick();
                                              _sub(s, glassL);
                                            }
                                          : null,
                                      child: Center(
                                        child: Icon(Icons.remove_rounded,
                                            size: 30,
                                            color: p.ink.withOpacity(
                                                total > 0 ? 0.8 : 0.3)),
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(tx('Üstü ekler, altı çıkarır'),
                        style: TextStyle(color: p.soft, fontSize: 12)),
                  ],
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Wrap(
              spacing: 10,
              runSpacing: 10,
              alignment: WrapAlignment.center,
              children: [
                _bigBtn(tx('Rutin seç'), Icons.link_rounded, () async {
                  final subs = <MapEntry<Category, SubCat>>[
                    for (final c in store.cats)
                      for (final x in c.subs)
                        if (x.summable) MapEntry(c, x),
                  ];
                  final picked = await showDialog<String>(
                    context: context,
                    builder: (ctx) => SimpleDialog(
                      title: Text(tx('Su rutini')),
                      children: [
                        for (final e in subs.where((e) => _fits('lt', e.value)))
                          SimpleDialogOption(
                            onPressed: () => Navigator.pop(ctx, e.value.id),
                            child: Text(
                                '${e.key.name} • ${e.value.name} (${e.value.unit})'),
                          ),
                      ],
                    ),
                  );
                  if (picked != null) {
                    store.setToolLink('water', picked);
                    if (mounted) setState(() {});
                  }
                }, filled: false),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------
// 7) Uyku: Yattım / Kalktım
// ---------------------------------------------------------------
class SleepPage extends StatefulWidget {
  const SleepPage({super.key});

  @override
  State<SleepPage> createState() => _SleepPageState();
}

class _SleepPageState extends State<SleepPage> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      if (store.sleepStart > 0 && mounted) setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final start = store.sleepStart;
    final on = start > 0;
    final st = DateTime.fromMillisecondsSinceEpoch(start);
    final secs = on
        ? DateTime.now().difference(st).inSeconds.clamp(0, 86400 * 2).toInt()
        : 0;
    String two(int x) => x.toString().padLeft(2, '0');
    return _page(
      context,
      tx('Uyku'),
      Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(on ? Icons.bedtime_rounded : Icons.bedtime_outlined,
                  size: 72, color: p.accent),
              const SizedBox(height: 16),
              if (on) ...[
                Text(tx('Yattığın saat: {0}', ['${two(st.hour)}:${two(st.minute)}']),
                    style: TextStyle(color: p.soft)),
                const SizedBox(height: 8),
                Text(_clock(secs),
                    style: TextStyle(
                        fontSize: 48,
                        fontWeight: FontWeight.w300,
                        color: p.ink)),
              ] else
                Text(tx('Yatmadan önce "Yattım"a bas, kalkınca "Kalktım"a bas.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.soft, height: 1.4)),
              const SizedBox(height: 24),
              if (!on)
                _bigBtn(tx('Yattım'), Icons.bedtime_rounded, () {
                  store.setSleepStart(DateTime.now().millisecondsSinceEpoch);
                  setState(() {});
                })
              else
                Wrap(
                  spacing: 10,
                  runSpacing: 10,
                  alignment: WrapAlignment.center,
                  children: [
                    _bigBtn(tx('Kalktım'), Icons.wb_sunny_rounded, () async {
                      final hours = double.parse((secs / 3600).toStringAsFixed(1));
                      final ok = await saveToRoutine(context,
                          tool: 'sleep',
                          title: tx('Uyku'),
                          value: hours,
                          kind: 'hr');
                      if (ok) {
                        store.setSleepStart(0);
                        if (mounted) setState(() {});
                      }
                    }),
                    _bigBtn(tx('İptal'), Icons.close_rounded, () {
                      store.setSleepStart(0);
                      setState(() {});
                    }, filled: false),
                  ],
                ),
            ],
          ),
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// 8) Meditasyon: süre seç, yavaş nefes halkası, rehber cümleler,
//    nefes al/ver sesleri + başta/sonda gong (isteğe bağlı titreşim),
//    arka plan sesi (podcast, telefondan dosya ya da online müzik),
//    biten seanslar sayfadaki kayıt listesine yazılır (not eklenir, silinir).
// ---------------------------------------------------------------

/// Nefes havası sesi, gong ve zil. Müzik/podcast'in üstüne karışarak çalar.
/// Nefes sesi iki döngü çalardır (al: parlak hava, ver: alçak hava); ses seviyesi
/// nefes eğrisini izler: nefes alırken yükselir, verirken düşer, tutarken sessizdir.
class _Snd {
  final AudioPlayer _in = AudioPlayer();
  final AudioPlayer _gong = AudioPlayer();
  final AudioPlayer _bell = AudioPlayer();
  bool _ready = false;
  String? err; // son hata (ekranda gösterilir)

  Future<void> _init() async {
    if (_ready) return;
    _ready = true;
    try {
      // Ses odağı istenmez: çalan podcast/müzik duraklamasın
      final ctx = AudioContext(
        android: AudioContextAndroid(audioFocus: AndroidAudioFocus.none),
      );
      for (final p in [_in, _gong, _bell]) {
        await p.setAudioContext(ctx);
      }
    } catch (e) {
      err = '$e';
    }
  }

  Future<void> _once(AudioPlayer p, String asset, double vol) async {
    try {
      await _init();
      await p.setVolume(vol);
      await p.play(AssetSource(asset));
    } catch (e) {
      err = '$e';
    }
  }

  Future<void> gong() => _once(_gong, 'sounds/gong.wav', 0.7);
  Future<void> bell() => _once(_bell, 'sounds/bell.wav', 0.7);

  Future<void> _vol(AudioPlayer p, double v) async {
    try {
      await p.setVolume(v);
    } catch (_) {}
  }

  /// Nefes al/ver geçişinde çalan tını (en çok 3 sn)
  Future<void> tone() => _once(_in, 'sounds/tone.wav', 0.8);

  Future<void> breathStop() async {
    try {
      await _in.stop();
    } catch (_) {}
  }

  Future<void> stopAll() async {
    await breathStop();
    try {
      await _gong.stop();
      await _bell.stop();
    } catch (_) {}
  }

  /// Ses çalınamadıysa bir kez bildirir
  void report(BuildContext context) {
    final e = err;
    if (e == null) return;
    err = null;
    final short = e.length > 90 ? e.substring(0, 90) : e;
    ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(tx('Nefes sesi çalınamadı: {0}', [short]))));
  }
}

final _Snd _snd = _Snd();

/// Seans bitince (sayfa açık olmasa da): gong, arka plan sesini kapat, kayda yaz
void _medFinished() {
  if (store.medSound) _snd.gong();
  _medEndSound();
  final min = double.parse((_medCtl.total / 60).toStringAsFixed(1));
  if (min > 0) store.addMed(min);
  _medLoggedSec = _medCtl.total;
  _medPageHook?.call();
}

VoidCallback? _medPageHook; // açık meditasyon sayfası bitişte bunu çağırır
int _medLoggedSec = 0; // şu ana kadar kayda yazılan süre (sn)

final _Countdown _medCtl = _Countdown(888803, tx('Meditasyon bitti.'))
  ..onFinish = _medFinished;
int _medMin = 10;

const _medGuides = [
  'Rahatça otur, gözlerini yavaşça kapat.',
  'Omuzlarını gevşet.',
  'Nefesini değiştirmeye çalışma, sadece izle.',
  'Aklına düşünceler gelirse onları fark et ve bırak.',
  'Karnının yükselip alçaldığını hisset.',
  'Çeneni ve yüzünü gevşet.',
  'Her nefes verişte biraz daha sakinleş.',
  'Şu an burada olmanın tadını çıkar.',
];

/// Meditasyon sırasındaki arka plan sesini (podcast/dosya/online) kapatır
Future<void> _medEndSound() async {
  try {
    await media.player.setLoopMode(LoopMode.off);
  } catch (_) {}
  if (media.nowId != null && (media.isPod || media.isVoice || media.isOnline)) {
    await media.stop();
  }
}

bool get _medHasSound =>
    media.nowId != null && (media.isPod || media.isVoice || media.isOnline);

class _EpPickPage extends StatelessWidget {
  final Podcast pd;
  const _EpPickPage(this.pd);

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(title: Text(pd.title, maxLines: 1)),
      body: SingleChildScrollView(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 4),
              child: Text(tx('Bir bölüme dokun, çalmaya başlar.'),
                  style: TextStyle(color: p.soft)),
            ),
            EpisodesView(podcast: pd),
          ],
        ),
      ),
    );
  }
}

class MeditatePage extends StatefulWidget {
  final bool autoStart;
  const MeditatePage({super.key, this.autoStart = false});

  @override
  State<MeditatePage> createState() => _MeditatePageState();
}

class _MeditatePageState extends State<MeditatePage>
    with SingleTickerProviderStateMixin {
  // 10 sn'lik tam nefes döngüsü (5 sn al, 5 sn ver)
  late final AnimationController _br = AnimationController(
      vsync: this, duration: const Duration(seconds: 10));
  int _lastPhase = -1; // 0 nefes al, 1 nefes ver
  Timer? _startDelay;

  @override
  void initState() {
    super.initState();
    _medCtl.addListener(_u);
    _medPageHook = _finishedUi;
    _br.addListener(_cueTick);
    if (_medCtl.total == 0) _medCtl.set(_medMin * 60);
    if (_medCtl.running) _br.repeat();
    if (widget.autoStart) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && !_medCtl.running) _start();
      });
    }
  }

  @override
  void dispose() {
    _startDelay?.cancel();
    _medCtl.removeListener(_u);
    if (_medPageHook == _finishedUi) _medPageHook = null;
    _br.removeListener(_cueTick);
    _br.dispose();
    // Sayfadan çıkınca seans duraklar (geri dönünce devam edilebilir)
    _medCtl.pause();
    _snd.stopAll();
    if (_medHasSound) media.player.pause();
    super.dispose();
  }

  void _u() {
    if (mounted) setState(() {});
  }

  /// Nefes eğrisini izler: ses seviyesi (hava sesi) ve aşama değişiminde titreşim
  void _cueTick() {
    if (!_medCtl.running) return;
    final inh = _br.value < 0.5;
    final ph = inh ? 0 : 1;
    if (ph != _lastPhase) {
      _lastPhase = ph;
      if (store.medVibe) {
        if (ph == 0) {
          HapticFeedback.mediumImpact();
        } else {
          HapticFeedback.lightImpact();
        }
      }
      if (store.medSound) _snd.tone();
    }
  }

  /// Seans bitti (kayıt zaten yazıldı): sayfa açıksa özet penceresi
  Future<void> _finishedUi() async {
    _br.stop();
    _startDelay?.cancel();
    if (!mounted) return;
    HapticFeedback.heavyImpact();
    final min = double.parse((_medCtl.total / 60).toStringAsFixed(1));
    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(tx('Meditasyon bitti.')),
        content: Text(tx('Geçen süre: {0} dk', [fmt(min)])),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tx('Tamam'))),
          FilledButton(
              onPressed: () {
                Navigator.pop(ctx);
                _save();
              },
              child: Text(tx('Rutine kaydet'))),
        ],
      ),
    );
  }

  double get _elapsedMin => double.parse(
      (((_medCtl.total - _medCtl.left) / 60)).toStringAsFixed(1));

  Future<void> _save() async {
    final v = _elapsedMin;
    if (v <= 0) return;
    final ok = await saveToRoutine(context,
        tool: 'meditate', title: tx('Meditasyon'), value: v, kind: 'min');
    if (ok) {
      _reset();
    }
  }

  void _reset() {
    _medCtl.set(_medMin * 60);
    _medLoggedSec = 0;
    _snd.stopAll();
    if (mounted) setState(() {});
  }

  /// Durdurulmuş seansı kayıt listesine ekler
  void _logNow() {
    final sec = _medCtl.total - _medCtl.left;
    final m = store.addMed(_elapsedMin);
    _medLoggedSec = sec;
    setState(() {});
    showUndo(context, tx('Kayda eklendi'), () {
      store.deleteMed(m.id);
      _medLoggedSec = 0;
      if (mounted) setState(() {});
    });
  }

  void _start() {
    HapticFeedback.lightImpact();
    _medCtl.start();
    _lastPhase = -1;
    if (store.medSound) {
      // Başlangıç gongu; nefes döngüsü ve hava sesi gongdan biraz sonra başlar
      _snd.gong();
      _startDelay?.cancel();
      _startDelay = Timer(const Duration(milliseconds: 2500), () {
        if (mounted && _medCtl.running) _br.repeat();
        _snd.report(context);
      });
    } else {
      _br.repeat();
    }
    if (_medHasSound) media.player.play();
  }

  void _pause() {
    _startDelay?.cancel();
    _medCtl.pause();
    _br.stop();
    _snd.stopAll();
    if (_medHasSound) media.player.pause();
  }

  Future<void> _custom() async {
    final v = await askNumber(context,
        title: tx('Kaç dakika?'), unit: tx('dk'), initial: _medMin.toDouble());
    if (v == null || v <= 0) return;
    _medMin = v.round().clamp(1, 600);
    _medCtl.set(_medMin * 60);
    _medLoggedSec = 0;
  }

  Future<void> _soundMenu() async {
    final p = palOf(context);
    final pick = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: p.card,
      builder: (ctx) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            ListTile(
              leading: const Icon(Icons.podcasts_rounded),
              title: Text(tx('Podcast\'lerimden')),
              onTap: () => Navigator.pop(ctx, 'pod'),
            ),
            ListTile(
              leading: const Icon(Icons.cloud_queue_rounded),
              title: Text(tx('Online müzik')),
              onTap: () => Navigator.pop(ctx, 'online'),
            ),
            ListTile(
              leading: const Icon(Icons.audio_file_outlined),
              title: Text(tx('Dosyadan seç')),
              onTap: () => Navigator.pop(ctx, 'file'),
            ),
            ListTile(
              leading: const Icon(Icons.volume_off_rounded),
              title: Text(tx('Sesi kapat')),
              onTap: () => Navigator.pop(ctx, 'off'),
            ),
          ],
        ),
      ),
    );
    if (pick == null || !mounted) return;
    if (pick == 'off') {
      await _medEndSound();
    } else if (pick == 'file') {
      await _pickFile();
    } else if (pick == 'online') {
      await _pickOnline();
    } else {
      await _pickPod();
    }
  }

  Future<void> _pickFile() async {
    final messenger = ScaffoldMessenger.of(context);
    try {
      final res = await FilePicker.platform.pickFiles(type: FileType.audio);
      final f = res?.files.isEmpty ?? true ? null : res!.files.first;
      final path = f?.path;
      if (f == null || path == null) return;
      await media.playVoice(path, 'med_${f.name}', f.name);
      await media.player.setLoopMode(LoopMode.one);
    } catch (e) {
      messenger.showSnackBar(
          SnackBar(content: Text(tx('Ses seçilemedi: {0}', ['$e']))));
    }
  }

  Future<void> _pickOnline() async {
    final p = palOf(context);
    await Navigator.of(context).push(_route(Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(title: Text(tx('Online müzik'))),
      body: const OnlineTab(),
    )));
    if (!mounted) return;
    // Sayaç çalışmıyorsa seçilen müzik bekletilsin
    if (!_medCtl.running && media.isOnline) media.player.pause();
  }

  Future<void> _pickPod() async {
    final pods = store.podcasts;
    if (pods.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tx('Podcast listen boş.'))));
      return;
    }
    final p = palOf(context);
    final pd = await showModalBottomSheet<Podcast>(
      context: context,
      backgroundColor: p.card,
      isScrollControlled: true,
      builder: (ctx) => SafeArea(
        child: ConstrainedBox(
          constraints: BoxConstraints(
              maxHeight: MediaQuery.of(ctx).size.height * 0.7),
          child: ListView(
            shrinkWrap: true,
            children: [
              for (final x in pods)
                ListTile(
                  leading: const Icon(Icons.podcasts_rounded),
                  title: Text(x.title,
                      maxLines: 1, overflow: TextOverflow.ellipsis),
                  onTap: () => Navigator.pop(ctx, x),
                ),
            ],
          ),
        ),
      ),
    );
    if (pd == null || !mounted) return;
    await Navigator.of(context).push(_route(_EpPickPage(pd)));
    if (!mounted) return;
    // Sayaç çalışmıyorsa seçilen bölüm bekletilsin
    if (!_medCtl.running && media.nowId != null && media.isPod) {
      media.player.pause();
    }
  }

  /// Arka plan sesi çalarken görünen oynatıcı: ilerleme, 10 sn geri/ileri, oynat/duraklat
  Widget _playerCard(Pal p, Color tone) {
    return ListenableBuilder(
      listenable: media,
      builder: (context, _) {
        final has = _medHasSound;
        return Container(
          padding: const EdgeInsets.fromLTRB(14, 8, 6, 6),
          decoration: BoxDecoration(
              color: tone.withOpacity(0.12),
              borderRadius: BorderRadius.circular(18)),
          child: Column(
            children: [
              Row(
                children: [
                  Icon(Icons.music_note_rounded, color: tone),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(has ? media.nowTitle : tx('Ses yok'),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            color: p.ink, fontWeight: FontWeight.w600)),
                  ),
                  if (has)
                    IconButton(
                        tooltip: tx('Sesi kapat'),
                        onPressed: _medEndSound,
                        icon: const Icon(Icons.close_rounded)),
                  TextButton(onPressed: _soundMenu, child: Text(tx('Ses'))),
                ],
              ),
              if (has) ...[
                StreamBuilder<Duration>(
                  stream: media.player.positionStream,
                  builder: (context, snap) {
                    final pos = snap.data ?? Duration.zero;
                    final dur = media.player.duration ?? Duration.zero;
                    final maxMs = dur.inMilliseconds.toDouble();
                    final v =
                        pos.inMilliseconds.clamp(0, dur.inMilliseconds).toDouble();
                    return Row(
                      children: [
                        Text(mmss(pos),
                            style: TextStyle(color: p.soft, fontSize: 12)),
                        Expanded(
                          child: Slider(
                            value: v,
                            max: maxMs > 0 ? maxMs : 1,
                            onChanged: maxMs > 0
                                ? (x) => media.player
                                    .seek(Duration(milliseconds: x.round()))
                                : null,
                          ),
                        ),
                        Text(mmss(dur),
                            style: TextStyle(color: p.soft, fontSize: 12)),
                      ],
                    );
                  },
                ),
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                        tooltip: tx('10 sn geri'),
                        onPressed: () => media.skipBy(-10),
                        icon: const Icon(Icons.replay_10_rounded, size: 32)),
                    media.loading
                        ? const Padding(
                            padding: EdgeInsets.all(12),
                            child: SizedBox(
                                width: 28,
                                height: 28,
                                child:
                                    CircularProgressIndicator(strokeWidth: 3)),
                          )
                        : IconButton(
                            tooltip:
                                media.playing ? tx('Duraklat') : tx('Çal'),
                            onPressed: media.toggle,
                            icon: Icon(
                                media.playing
                                    ? Icons.pause_circle_filled_rounded
                                    : Icons.play_circle_fill_rounded,
                                size: 48)),
                    IconButton(
                        tooltip: tx('10 sn ileri'),
                        onPressed: () => media.skipBy(10),
                        icon: const Icon(Icons.forward_10_rounded, size: 32)),
                  ],
                ),
              ],
            ],
          ),
        );
      },
    );
  }

  Future<void> _editNote(MedSession m) async {
    final v = await askText(context, tx('Not'), initial: m.note);
    if (v != null) store.setMedNote(m.id, v);
  }

  void _deleteSession(MedSession m) {
    store.deleteMed(m.id);
    showUndo(context, tx('Kayıt silindi'), () => store.restoreMed(m));
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    const tone = Color(0xFF8E6CEF);
    final c = _medCtl;
    final running = c.running;
    final idle = c.idle;
    final elapsedSec = c.total - c.left;
    final guide = _medGuides[(elapsedSec ~/ 12) % _medGuides.length];
    final canLog = !running && elapsedSec >= 30 && elapsedSec >= _medLoggedSec + 30;
    return _page(
      context,
      tx('Meditasyon'),
      tone: tone,
      ListenableBuilder(
        listenable: store,
        builder: (context, _) => SingleChildScrollView(
          padding: const EdgeInsets.all(16),
          child: Column(
            children: [
              if (!running && idle)
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  alignment: WrapAlignment.center,
                  children: [
                    for (final m in const [5, 10, 20, 30])
                      ChoiceChip(
                        label: Text('$m ${tx('dk')}'),
                        selected: _medMin == m,
                        onSelected: (_) {
                          _medMin = m;
                          c.set(m * 60);
                          _medLoggedSec = 0;
                        },
                      ),
                    ActionChip(label: Text(tx('Özel')), onPressed: _custom),
                  ],
                )
              else
                const SizedBox(height: 40),
              const SizedBox(height: 10),
              SizedBox(
                height: 300,
                child: AnimatedBuilder(
                  animation: _br,
                  builder: (_, __) {
                    // 0 → 1 → 0 yumuşak nefes eğrisi
                    final v = running ? 0.5 - 0.5 * cos(_br.value * 2 * pi) : 0.0;
                    final size = 130 + 120 * v;
                    return Center(
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          Container(
                            width: size + 50,
                            height: size + 50,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tone.withOpacity(0.07 + 0.08 * v)),
                          ),
                          Container(
                            width: size + 22,
                            height: size + 22,
                            decoration: BoxDecoration(
                                shape: BoxShape.circle,
                                color: tone.withOpacity(0.12 + 0.10 * v)),
                          ),
                          Container(
                            width: size,
                            height: size,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: RadialGradient(colors: [
                                tone.withOpacity(0.70),
                                const Color(0xFF5C6BC0).withOpacity(0.35),
                              ]),
                              boxShadow: [
                                BoxShadow(
                                    color: tone.withOpacity(0.25 + 0.30 * v),
                                    blurRadius: 20 + 30 * v),
                              ],
                            ),
                            alignment: Alignment.center,
                            child: Text(
                                running
                                    ? (_br.value < 0.5
                                        ? tx('Nefes al')
                                        : tx('Nefes ver'))
                                    : tx('Hazır'),
                                style: const TextStyle(
                                    fontSize: 18,
                                    fontWeight: FontWeight.w700,
                                    color: Colors.white)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              Text(_clock(c.left),
                  style: TextStyle(
                      fontSize: 44,
                      fontWeight: FontWeight.w300,
                      color: p.ink,
                      fontFeatures: const [FontFeature.tabularFigures()])),
              const SizedBox(height: 10),
              SizedBox(
                height: 56,
                child: AnimatedSwitcher(
                  duration: const Duration(milliseconds: 900),
                  child: Text(
                    running ? tx(guide) : '',
                    key: ValueKey<int>(running ? elapsedSec ~/ 12 : -1),
                    textAlign: TextAlign.center,
                    style: TextStyle(
                        fontSize: 16,
                        height: 1.35,
                        fontStyle: FontStyle.italic,
                        color: p.soft),
                  ),
                ),
              ),
              Wrap(
                spacing: 8,
                children: [
                  FilterChip(
                    avatar: const Icon(Icons.volume_up_rounded, size: 18),
                    label: Text(tx('Nefes sesi')),
                    selected: store.medSound,
                    onSelected: store.setMedSound,
                  ),
                  FilterChip(
                    avatar: const Icon(Icons.vibration_rounded, size: 18),
                    label: Text(tx('Titreşim')),
                    selected: store.medVibe,
                    onSelected: store.setMedVibe,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              _playerCard(p, tone),
              const SizedBox(height: 18),
              Wrap(
                spacing: 10,
                runSpacing: 10,
                alignment: WrapAlignment.center,
                children: [
                  _bigBtn(running ? tx('Duraklat') : tx('Başlat'),
                      running ? Icons.pause_rounded : Icons.play_arrow_rounded,
                      running ? _pause : _start),
                  if (!running && !idle)
                    _bigBtn(tx('Sıfırla'), Icons.restart_alt_rounded, _reset,
                        filled: false),
                ],
              ),
              if (canLog) ...[
                const SizedBox(height: 10),
                _bigBtn(tx('Kayda ekle'), Icons.bookmark_add_outlined, _logNow,
                    filled: false),
              ],
              if (!running && _elapsedMin >= 0.5) ...[
                const SizedBox(height: 10),
                _bigBtn(tx('Rutine kaydet'), Icons.add_task_rounded, _save),
              ],
              const SizedBox(height: 26),
              _medHistory(p, tone),
            ],
          ),
        ),
      ),
    );
  }

  /// Geçmiş seanslar: dokununca not, çöp kutusu ile sil
  Widget _medHistory(Pal p, Color tone) {
    final list = store.medLog;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Row(
          children: [
            Icon(Icons.history_rounded, color: tone),
            const SizedBox(width: 8),
            Text(tx('Meditasyon kayıtları'),
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w700, color: p.ink)),
            const Spacer(),
            if (list.isNotEmpty)
              Text(
                  tx('{0} dk', [
                    fmt(list.fold<double>(0, (a, m) => a + m.minutes))
                  ]),
                  style: TextStyle(color: p.soft)),
          ],
        ),
        const SizedBox(height: 8),
        if (list.isEmpty)
          Padding(
            padding: const EdgeInsets.all(12),
            child: Text(tx('Henüz kayıt yok. Biten seanslar buraya eklenir.'),
                textAlign: TextAlign.center,
                style: TextStyle(color: p.soft)),
          )
        else
          for (final m in list)
            Container(
              margin: const EdgeInsets.only(bottom: 8),
              decoration: BoxDecoration(
                color: Color.alphaBlend(
                    tone.withOpacity(p.dark ? 0.14 : 0.08), p.card),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: tone.withOpacity(0.35)),
              ),
              child: ListTile(
                onTap: () => _editNote(m),
                title: Text(
                    '${dtLabel(m.ms)}  •  ${tx('{0} dk', [fmt(m.minutes)])}',
                    style: TextStyle(
                        fontWeight: FontWeight.w600, color: p.ink)),
                subtitle: Text(
                    m.note.isEmpty ? tx('Not eklemek için dokun') : m.note,
                    style: TextStyle(
                        color: p.soft,
                        fontStyle:
                            m.note.isEmpty ? FontStyle.italic : FontStyle.normal)),
                trailing: IconButton(
                    tooltip: tx('Sil'),
                    onPressed: () => _deleteSession(m),
                    icon: const Icon(Icons.delete_outline_rounded)),
              ),
            ),
      ],
    );
  }
}
