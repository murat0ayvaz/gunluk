import 'dart:async';
import 'dart:ui' show FontFeature;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'media.dart';
import 'net.dart' show fetchEpisodes;
import 'notify.dart';
import 'reminders.dart' show permissionMessage;
import 'strings.dart';
import 'theme.dart' show Pal;
import 'tools.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// ZAMANLAMA (Araçlar menüsü)
//  - Uyku zamanlayıcısı: süre dolunca ses durur (isteğe bağlı uygulama da kapanır)
//  - Alarm: seçili saat ve günlerde çalar
//  - Başlatıcı: saati gelince bildirim gelir; dokununca uygulamadaki seçili şey
//    (meditasyon, pomodoro, nefes, radyo, müzik, podcast) başlar.
//    Android, uygulamayı bildirime dokunulmadan arka planda açmaya izin vermez.
// ---------------------------------------------------------------

String _hm(int h, int m) =>
    '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

String _daysText(Set<int> d) {
  if (d.isEmpty || d.length == 7) return tx('Her gün');
  final l = d.toList()..sort();
  return l.map(wdName).join(', ');
}

Future<TimeOfDay?> _pickT(BuildContext context, int h, int m) => showTimePicker(
      context: context,
      initialTime: TimeOfDay(hour: h, minute: m),
      builder: (ctx, child) => MediaQuery(
        data: MediaQuery.of(ctx).copyWith(alwaysUse24HourFormat: true),
        child: child!,
      ),
    );

// ---------------------------------------------------------------
// Uyku zamanlayıcısı
// ---------------------------------------------------------------
class SleepTimerCtl extends ChangeNotifier {
  DateTime? _end;
  Timer? _t;
  String action = 'sound'; // sound | close
  int totalSec = 0;

  bool get running => _end != null;

  int get left {
    final e = _end;
    if (e == null) return 0;
    final d = e.difference(DateTime.now()).inSeconds + 1;
    return d < 0 ? 0 : d;
  }

  void start(int minutes, String act) {
    cancel();
    action = act;
    totalSec = minutes * 60;
    _end = DateTime.now().add(Duration(minutes: minutes));
    _t = Timer.periodic(const Duration(seconds: 1), (_) {
      final l = left;
      if (l <= 0) {
        _fire();
      } else {
        if (l <= 10) {
          // son 10 saniyede ses yavaşça kısılır
          try {
            media.player.setVolume(l / 10);
          } catch (_) {}
        }
        notifyListeners();
      }
    });
    notifyListeners();
  }

  void cancel() {
    final was = _end != null;
    _end = null;
    _t?.cancel();
    if (was) {
      try {
        media.player.setVolume(1);
      } catch (_) {}
    }
    notifyListeners();
  }

  Future<void> _fire() async {
    final act = action;
    _end = null;
    _t?.cancel();
    notifyListeners();
    try {
      await media.stop();
    } catch (_) {}
    try {
      await media.player.setVolume(1);
    } catch (_) {}
    if (act == 'close') {
      await Future<void>.delayed(const Duration(milliseconds: 400));
      await SystemNavigator.pop();
    }
  }
}

final sleepTimer = SleepTimerCtl();

Widget _toolScaffold(BuildContext context, String title, Widget body,
    {Widget? fab}) {
  final p = palOf(context);
  return Scaffold(
    backgroundColor: p.bg,
    appBar: AppBar(title: Text(title), actions: const [ToolsButton()]),
    endDrawer: const ToolsDrawer(replace: true),
    floatingActionButton: fab,
    body: body,
  );
}

class SleepTimerPage extends StatefulWidget {
  const SleepTimerPage({super.key});

  @override
  State<SleepTimerPage> createState() => _SleepTimerPageState();
}

class _SleepTimerPageState extends State<SleepTimerPage> {
  int _min = 30;
  bool _custom = false;
  String _act = sleepTimer.action;

  String _fmt(int s) {
    final h = s ~/ 3600;
    final m = (s % 3600) ~/ 60;
    final ss = s % 60;
    final mm = m.toString().padLeft(2, '0');
    final sx = ss.toString().padLeft(2, '0');
    return h > 0 ? '$h:$mm:$sx' : '$mm:$sx';
  }

  Future<void> _askCustom() async {
    final v = await askNumber(context,
        title: tx('Kaç dakika?'), unit: tx('dk'), initial: _min.toDouble());
    if (v == null || v <= 0) return;
    setState(() {
      _min = v.round().clamp(1, 720);
      _custom = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: sleepTimer,
      builder: (context, _) {
        final p = palOf(context);
        final run = sleepTimer.running;
        return _toolScaffold(
          context,
          tx('Uyku zamanlayıcısı'),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
            children: [
              if (run) ...[
                const SizedBox(height: 20),
                Center(
                  child: Text(_fmt(sleepTimer.left),
                      style: TextStyle(
                          fontSize: 56,
                          fontWeight: FontWeight.w300,
                          color: p.ink,
                          fontFeatures: const [FontFeature.tabularFigures()])),
                ),
                const SizedBox(height: 6),
                Center(
                  child: Text(
                      sleepTimer.action == 'close'
                          ? tx('Süre bitince ses durur ve uygulama kapanır')
                          : tx('Süre bitince ses durur'),
                      style: TextStyle(color: p.soft)),
                ),
                const SizedBox(height: 24),
                FilledButton.icon(
                  onPressed: sleepTimer.cancel,
                  icon: const Icon(Icons.close_rounded),
                  label: Text(tx('Zamanlayıcıyı iptal et')),
                ),
              ] else ...[
                Text(tx('Süre'),
                    style: TextStyle(color: p.soft, fontSize: 12.5)),
                const SizedBox(height: 6),
                Wrap(
                  spacing: 8,
                  runSpacing: 6,
                  children: [
                    for (final m in const [15, 30, 45, 60])
                      ChoiceChip(
                        label: Text(tx('{0} dk', ['$m'])),
                        selected: !_custom && _min == m,
                        onSelected: (_) => setState(() {
                          _min = m;
                          _custom = false;
                        }),
                      ),
                    ChoiceChip(
                      label: Text(_custom
                          ? tx('{0} dk', ['$_min'])
                          : tx('Özel')),
                      selected: _custom,
                      onSelected: (_) => _askCustom(),
                    ),
                  ],
                ),
                const SizedBox(height: 18),
                Text(tx('Süre bitince ne olsun?'),
                    style: TextStyle(color: p.soft, fontSize: 12.5)),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'sound',
                  groupValue: _act,
                  title: Text(tx('Sadece ses dursun')),
                  subtitle: Text(tx('Müzik, radyo ya da podcast durur')),
                  onChanged: (v) => setState(() => _act = v!),
                ),
                RadioListTile<String>(
                  contentPadding: EdgeInsets.zero,
                  value: 'close',
                  groupValue: _act,
                  title: Text(tx('Ses dursun ve uygulama kapansın')),
                  onChanged: (v) => setState(() => _act = v!),
                ),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => sleepTimer.start(_min, _act),
                  icon: const Icon(Icons.bedtime_outlined),
                  label: Text(tx('Başlat')),
                ),
                const SizedBox(height: 14),
                Text(
                    tx('Zamanlayıcı uygulama açıkken ya da müzik arka planda çalarken işler. Son 10 saniyede ses yavaşça kısılır.'),
                    style: TextStyle(color: p.soft, fontSize: 12, height: 1.4)),
              ],
            ],
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------
// Alarm ve başlatıcı için ortak ekleme penceresi
// ---------------------------------------------------------------
class _Sched {
  final int h, m;
  final Set<int> days;
  final String label, kind, ref;
  const _Sched(this.h, this.m, this.days, this.label, this.kind, this.ref);
}

const _kinds = <String>['meditate', 'pomodoro', 'breath', 'radio', 'music', 'podcast'];

String _kindName(String k) {
  switch (k) {
    case 'meditate':
      return tx('Meditasyon');
    case 'pomodoro':
      return tx('Pomodoro');
    case 'breath':
      return tx('Nefes');
    case 'radio':
      return tx('Radyo');
    case 'music':
      return tx('Müzik');
    default:
      return tx('Podcast');
  }
}

/// Seçilebilir (id, ad) listesi
List<(String, String)> _refsOf(String kind) {
  if (kind == 'radio') {
    return [
      for (final c in store.radCats)
        for (final s in c.stations) (s.id, s.name)
    ];
  }
  if (kind == 'music') {
    return [for (final l in store.playlists) (l.id, l.name)];
  }
  if (kind == 'podcast') {
    return [for (final p in store.podcasts) (p.id, p.title)];
  }
  return const [];
}

class _SchedDialog extends StatefulWidget {
  final String title;
  final bool launch;
  final int h, m;
  final Set<int> days;
  final String label, kind, ref;
  const _SchedDialog(
      {required this.title,
      required this.launch,
      required this.h,
      required this.m,
      required this.days,
      required this.label,
      required this.kind,
      required this.ref});

  @override
  State<_SchedDialog> createState() => _SchedDialogState();
}

class _SchedDialogState extends State<_SchedDialog> {
  late int _h = widget.h;
  late int _m = widget.m;
  late Set<int> _days = Set<int>.from(widget.days);
  late final TextEditingController _l = TextEditingController(text: widget.label);
  late String _kind = widget.kind;
  late String _ref = widget.ref;
  String? _err;

  @override
  void dispose() {
    _l.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final refs = widget.launch ? _refsOf(_kind) : const <(String, String)>[];
    final needRef = widget.launch && (_kind == 'radio' || _kind == 'music' || _kind == 'podcast');
    if (needRef && !refs.any((r) => r.$1 == _ref)) {
      _ref = refs.isEmpty ? '' : refs.first.$1;
    }
    return AlertDialog(
      title: Text(widget.title),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            OutlinedButton.icon(
              onPressed: () async {
                final t = await _pickT(context, _h, _m);
                if (t != null) {
                  setState(() {
                    _h = t.hour;
                    _m = t.minute;
                  });
                }
              },
              icon: const Icon(Icons.schedule_rounded, size: 18),
              label: Text(_hm(_h, _m)),
            ),
            const SizedBox(height: 12),
            Text(tx('Hangi günler?'),
                style: TextStyle(fontSize: 12.5, color: p.soft)),
            const SizedBox(height: 6),
            WeekdayChips(
              selected: _days.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : _days,
              onChanged: (v) => setState(() => _days = v),
            ),
            if (widget.launch) ...[
              const SizedBox(height: 14),
              Text(tx('Ne başlasın?'),
                  style: TextStyle(fontSize: 12.5, color: p.soft)),
              DropdownButton<String>(
                isExpanded: true,
                value: _kind,
                items: [
                  for (final k in _kinds)
                    DropdownMenuItem(value: k, child: Text(_kindName(k))),
                ],
                onChanged: (v) => setState(() => _kind = v ?? _kind),
              ),
              if (needRef)
                refs.isEmpty
                    ? Text(tx('Önce Müzik / Radyo / Podcast bölümünde bir şey ekle.'),
                        style: TextStyle(color: p.soft, fontSize: 12.5))
                    : DropdownButton<String>(
                        isExpanded: true,
                        value: _ref,
                        items: [
                          for (final r in refs)
                            DropdownMenuItem(
                                value: r.$1,
                                child: Text(r.$2, overflow: TextOverflow.ellipsis)),
                        ],
                        onChanged: (v) => setState(() => _ref = v ?? _ref),
                      ),
            ] else ...[
              const SizedBox(height: 8),
              TextField(
                controller: _l,
                textCapitalization: TextCapitalization.sentences,
                decoration: InputDecoration(labelText: tx('Alarm adı (isteğe bağlı)')),
              ),
            ],
            if (_err != null)
              Padding(
                padding: const EdgeInsets.only(top: 8),
                child: Text(_err!, style: const TextStyle(color: Color(0xFFC0504D))),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(tx('Vazgeç'))),
        FilledButton(
          onPressed: () {
            if (needRef && _ref.isEmpty) {
              setState(() => _err = tx('Bir seçim yap.'));
              return;
            }
            Navigator.pop(
                context,
                _Sched(
                    _h,
                    _m,
                    _days.length == 7 ? <int>{} : _days,
                    widget.launch ? _launchLabel() : _l.text.trim(),
                    _kind,
                    _ref));
          },
          child: Text(tx('Kaydet')),
        ),
      ],
    );
  }

  String _launchLabel() {
    final base = _kindName(_kind);
    if (!(_kind == 'radio' || _kind == 'music' || _kind == 'podcast')) return base;
    for (final r in _refsOf(_kind)) {
      if (r.$1 == _ref) return '$base: ${r.$2}';
    }
    return base;
  }
}

Widget _rowCard(Pal p, {required Widget child}) => Container(
      margin: const EdgeInsets.only(bottom: 8),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: child,
    );

// ---------------------------------------------------------------
// Alarm
// ---------------------------------------------------------------
class AlarmPage extends StatelessWidget {
  const AlarmPage({super.key});

  Future<void> _edit(BuildContext context, AlarmItem? a) async {
    final r = await showDialog<_Sched>(
        context: context,
        builder: (_) => _SchedDialog(
            title: a == null ? tx('Yeni alarm') : tx('Alarmı düzenle'),
            launch: false,
            h: a?.h ?? 7,
            m: a?.m ?? 0,
            days: a?.days ?? <int>{},
            label: a?.label ?? '',
            kind: 'meditate',
            ref: ''));
    if (r == null) return;
    AlarmItem item;
    if (a == null) {
      item = store.addAlarm(r.h, r.m, r.days, r.label);
    } else {
      a.h = r.h;
      a.m = r.m;
      a.days = r.days;
      a.label = r.label;
      a.on = true;
      store.touchAlarm();
      item = a;
    }
    await Notifier.syncAlarm(item);
    final msg = await permissionMessage();
    if (msg != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        final list = [...store.alarms]
          ..sort((a, b) => (a.h * 60 + a.m).compareTo(b.h * 60 + b.m));
        return _toolScaffold(
          context,
          tx('Alarm'),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            children: [
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(28),
                  child: Text(tx('Henüz alarm yok. Alarm ekle düğmesine bas.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.soft)),
                ),
              for (final a in list)
                _rowCard(
                  p,
                  child: ListTile(
                    onTap: () => _edit(context, a),
                    title: Text(_hm(a.h, a.m),
                        style: TextStyle(
                            fontSize: 26,
                            fontWeight: FontWeight.w300,
                            color: a.on ? p.ink : p.soft)),
                    subtitle: Text(
                        a.label.isEmpty
                            ? _daysText(a.days)
                            : '${a.label} • ${_daysText(a.days)}',
                        style: TextStyle(color: p.soft)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: a.on,
                          onChanged: (v) async {
                            a.on = v;
                            store.touchAlarm();
                            await Notifier.syncAlarm(a);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () async {
                            final ok = await confirmDialog(context,
                                tx('Alarm silinsin mi?'), _hm(a.h, a.m));
                            if (ok) {
                              await Notifier.cancelAlarm(a);
                              store.deleteAlarm(a.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
              const SizedBox(height: 8),
              Text(
                  tx('Alarm, telefonun alarm sesiyle bildirim olarak çalar; kapatana kadar tekrarlar. Telefonun "Alarmlar ve hatırlatıcılar" iznini vermen gerekebilir.'),
                  style: TextStyle(color: p.soft, fontSize: 12, height: 1.4)),
            ],
          ),
          fab: FloatingActionButton.extended(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add_alarm_rounded),
            label: Text(tx('Alarm ekle')),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------
// Başlatıcı
// ---------------------------------------------------------------
class LauncherPage extends StatelessWidget {
  const LauncherPage({super.key});

  Future<void> _edit(BuildContext context, LaunchItem? a) async {
    final r = await showDialog<_Sched>(
        context: context,
        builder: (_) => _SchedDialog(
            title: a == null ? tx('Yeni başlatıcı') : tx('Başlatıcıyı düzenle'),
            launch: true,
            h: a?.h ?? 7,
            m: a?.m ?? 0,
            days: a?.days ?? <int>{},
            label: a?.label ?? '',
            kind: a?.kind ?? 'meditate',
            ref: a?.ref ?? ''));
    if (r == null) return;
    LaunchItem item;
    if (a == null) {
      item = store.addLauncher(r.h, r.m, r.days, r.kind, r.ref, r.label);
    } else {
      a.h = r.h;
      a.m = r.m;
      a.days = r.days;
      a.kind = r.kind;
      a.ref = r.ref;
      a.label = r.label;
      a.on = true;
      store.touchLauncher();
      item = a;
    }
    await Notifier.syncLauncher(item);
    final msg = await permissionMessage();
    if (msg != null && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
    }
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        final list = [...store.launchers]
          ..sort((a, b) => (a.h * 60 + a.m).compareTo(b.h * 60 + b.m));
        return _toolScaffold(
          context,
          tx('Başlatıcı'),
          ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            children: [
              Padding(
                padding: const EdgeInsets.only(bottom: 10),
                child: Text(
                    tx('Saati gelince bildirim gelir. Bildirime dokununca Daily Routine açılır ve seçtiğin şey başlar.'),
                    style: TextStyle(color: p.soft, fontSize: 13, height: 1.4)),
              ),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(tx('Henüz başlatıcı yok.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.soft)),
                ),
              for (final a in list)
                _rowCard(
                  p,
                  child: ListTile(
                    onTap: () => _edit(context, a),
                    title: Text('${_hm(a.h, a.m)}  ${a.label}',
                        style: TextStyle(
                            color: a.on ? p.ink : p.soft,
                            fontWeight: FontWeight.w600)),
                    subtitle: Text(_daysText(a.days),
                        style: TextStyle(color: p.soft)),
                    trailing: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Switch(
                          value: a.on,
                          onChanged: (v) async {
                            a.on = v;
                            store.touchLauncher();
                            await Notifier.syncLauncher(a);
                          },
                        ),
                        IconButton(
                          icon: const Icon(Icons.delete_outline_rounded),
                          onPressed: () async {
                            final ok = await confirmDialog(context,
                                tx('Başlatıcı silinsin mi?'), a.label);
                            if (ok) {
                              await Notifier.cancelLauncher(a);
                              store.deleteLauncher(a.id);
                            }
                          },
                        ),
                      ],
                    ),
                  ),
                ),
            ],
          ),
          fab: FloatingActionButton.extended(
            onPressed: () => _edit(context, null),
            icon: const Icon(Icons.add_rounded),
            label: Text(tx('Başlatıcı ekle')),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------
// Bildirime dokunulunca
// ---------------------------------------------------------------
Future<void> handleNotifPayload(NavigatorState nav, String payload) async {
  if (!payload.startsWith('launch:')) return;
  final id = payload.substring(7);
  LaunchItem? a;
  for (final x in store.launchers) {
    if (x.id == id) a = x;
  }
  if (a == null) return;
  switch (a.kind) {
    case 'meditate':
      nav.push(MaterialPageRoute<void>(
          builder: (_) => const MeditatePage(autoStart: true)));
      break;
    case 'pomodoro':
      nav.push(MaterialPageRoute<void>(
          builder: (_) => const PomodoroPage(autoStart: true)));
      break;
    case 'breath':
      nav.push(MaterialPageRoute<void>(
          builder: (_) => const BreathPage(autoStart: true)));
      break;
    case 'radio':
      for (final c in store.radCats) {
        for (final s in c.stations) {
          if (s.id == a.ref) {
            nav.push(slideFromRight(const MediaPage()));
            await media.playStation(s);
            return;
          }
        }
      }
      break;
    case 'music':
      for (final l in store.playlists) {
        if (l.id == a.ref && l.songs.isNotEmpty) {
          nav.push(slideFromRight(const MediaPage()));
          await media.playSong(l, l.songs.first);
          return;
        }
      }
      break;
    case 'podcast':
      for (final p in store.podcasts) {
        if (p.id != a.ref) continue;
        nav.push(slideFromRight(const MediaPage()));
        try {
          final eps = await fetchEpisodes(p.id, p.feed);
          if (eps.isEmpty) return;
          var pick = eps.first;
          for (final e in eps) {
            if (!store.epDone.contains(e.key)) {
              pick = e;
              break;
            }
          }
          await media.playEpisode(p, pick);
        } catch (_) {}
        return;
      }
      break;
  }
}
