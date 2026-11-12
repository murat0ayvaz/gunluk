import 'dart:typed_data' show Int32List;
import 'package:flutter/foundation.dart' show ValueNotifier;
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:timezone/data/latest.dart' as tzdata;
import 'package:timezone/timezone.dart' as tz;
import 'data.dart';
import 'strings.dart';

// ---------------------------------------------------------------
// BİLDİRİMLER: hatırlatıcılar ve yapılacak maddesi hatırlatmaları.
// Zamanlar UTC olarak planlanır (saat dilimi eklentisi gerekmez).
// Bildirim numarası = nid*100 + sıra  (her kayıt en çok 99 bildirim)
// ---------------------------------------------------------------

class PermState {
  final bool notifications; // bildirim izni
  final bool exact; // tam zamanlı alarm izni
  const PermState(this.notifications, this.exact);
}

class Notifier {
  static final FlutterLocalNotificationsPlugin _p =
      FlutterLocalNotificationsPlugin();
  static bool _ready = false;

  static AndroidFlutterLocalNotificationsPlugin? get _android => _p
      .resolvePlatformSpecificImplementation<
          AndroidFlutterLocalNotificationsPlugin>();

  /// Bildirime dokunulunca gelen yük (ör. 'launch:<id>'); uygulama açıkken dinlenir
  static final ValueNotifier<String?> tapped = ValueNotifier<String?>(null);

  /// Uygulama kapalıyken bildirime dokunularak açıldıysa o bildirimin yükü
  static Future<String?> coldStartPayload() async {
    try {
      await init();
      final d = await _p.getNotificationAppLaunchDetails();
      if (d != null && d.didNotificationLaunchApp) {
        final pl = d.notificationResponse?.payload;
        if (pl != null && pl.isNotEmpty) return pl;
      }
    } catch (_) {}
    return null;
  }

  static Future<void> init() async {
    if (_ready) return;
    tzdata.initializeTimeZones();
    const settings = InitializationSettings(
      android: AndroidInitializationSettings('@mipmap/ic_launcher'),
    );
    await _p.initialize(
      settings,
      onDidReceiveNotificationResponse: (r) {
        final pl = r.payload;
        if (pl != null && pl.isNotEmpty) tapped.value = pl;
      },
    );
    _ready = true;
  }

  /// İzin durumu; request=true ise eksik izinleri ister
  static Future<PermState> permissions({bool request = false}) async {
    try {
      await init();
      final a = _android;
      if (a == null) return const PermState(true, true);
      var n = await a.areNotificationsEnabled() ?? false;
      var e = await a.canScheduleExactNotifications() ?? false;
      if (request) {
        if (!n) n = await a.requestNotificationsPermission() ?? false;
        if (!e) {
          await a.requestExactAlarmsPermission();
          e = await a.canScheduleExactNotifications() ?? false;
        }
      }
      return PermState(n, e);
    } catch (_) {
      return const PermState(false, false);
    }
  }

  static NotificationDetails get _details => NotificationDetails(
        android: AndroidNotificationDetails(
          'reminders',
          tx('Hatırlatıcılar'),
          channelDescription: tx('Hatırlatıcı bildirimleri'),
          importance: Importance.high,
          priority: Priority.high,
        ),
      );

  /// Alarm: alarm sesi akışında, kapatılana kadar tekrarlayan ses
  static NotificationDetails get _alarmDetails => NotificationDetails(
        android: AndroidNotificationDetails(
          'alarm',
          tx('Alarm'),
          channelDescription: tx('Alarm bildirimleri'),
          importance: Importance.max,
          priority: Priority.max,
          category: AndroidNotificationCategory.alarm,
          audioAttributesUsage: AudioAttributesUsage.alarm,
          additionalFlags: Int32List.fromList(<int>[4]), // FLAG_INSISTENT
        ),
      );

  static Future<void> _plan(int baseId, String body, List<DateTime> times,
      {String? payload, NotificationDetails? details}) async {
    final a = _android;
    final exact = a == null ? true : (await a.canScheduleExactNotifications() ?? false);
    final mode = exact
        ? AndroidScheduleMode.exactAllowWhileIdle
        : AndroidScheduleMode.inexactAllowWhileIdle;
    for (var i = 0; i < times.length && i < 99; i++) {
      final when = tz.TZDateTime.fromMillisecondsSinceEpoch(
          tz.UTC, times[i].millisecondsSinceEpoch);
      await _p.zonedSchedule(
        baseId * 100 + i,
        'Daily Routine',
        body,
        when,
        details ?? _details,
        androidScheduleMode: mode,
        payload: payload,
      );
    }
  }

  static Future<void> _cancelBase(int baseId) async {
    for (var i = 0; i < 99; i++) {
      await _p.cancel(baseId * 100 + i);
    }
  }

  static Future<void> syncReminder(Reminder r) async {
    try {
      await init();
      await _cancelBase(r.nid);
      if (!r.enabled) return;
      await _plan(r.nid, r.text, reminderTimes(r, DateTime.now()));
    } catch (_) {}
  }

  static Future<void> cancelReminder(Reminder r) async {
    try {
      await init();
      await _cancelBase(r.nid);
    } catch (_) {}
  }

  static Future<void> syncTodo(Todo t) async {
    if (t.nid == 0) return;
    try {
      await init();
      await _cancelBase(t.nid);
      if (t.done || t.remindMs <= 0) return;
      await _plan(t.nid, t.text, todoRemindTimes(t, DateTime.now()));
    } catch (_) {}
  }

  static Future<void> cancelTodo(Todo t) async {
    if (t.nid == 0) return;
    try {
      await init();
      await _cancelBase(t.nid);
    } catch (_) {}
  }

  static Future<void> syncFree(FreeRow f) async {
    if (f.nid == 0) return;
    try {
      await init();
      await _cancelBase(f.nid);
      if (f.remindMs <= 0) return;
      final when = DateTime.fromMillisecondsSinceEpoch(f.remindMs);
      if (!when.isAfter(DateTime.now())) return;
      final body = f.text.isEmpty ? f.title : '${f.title}: ${f.text}';
      await _plan(f.nid, body, [when]);
    } catch (_) {}
  }

  static Future<void> cancelFree(FreeRow f) async {
    if (f.nid == 0) return;
    try {
      await init();
      await _cancelBase(f.nid);
    } catch (_) {}
  }

  /// Rutin: seçili günlerde her gün belirli saatte (önümüzdeki 14 gün)
  static Future<void> syncSub(SubCat s) async {
    if (s.nid == 0) return;
    try {
      await init();
      await _cancelBase(s.nid);
      if (!s.routine || s.rh < 0) return;
      final now = DateTime.now();
      final times = <DateTime>[];
      for (var d = 0; d < 14; d++) {
        final day = DateTime(now.year, now.month, now.day + d);
        final t = DateTime(day.year, day.month, day.day, s.rh, s.rm);
        if (t.isAfter(now) && s.scheduledOn(day)) times.add(t);
      }
      await _plan(s.nid, s.name, times);
    } catch (_) {}
  }

  static Future<void> cancelSub(SubCat s) async {
    if (s.nid == 0) return;
    try {
      await init();
      await _cancelBase(s.nid);
    } catch (_) {}
  }

  /// Haftalık çalışma programı: seçili günde başlangıç saatinde (önümüzdeki 8 hafta)
  static Future<void> syncPlan(StudyPlan r) async {
    if (r.nid == 0) return;
    try {
      await init();
      await _cancelBase(r.nid);
      if (!r.remind) return;
      final now = DateTime.now();
      final times = <DateTime>[];
      for (var d = 0; d < 56; d++) {
        final day = DateTime(now.year, now.month, now.day + d);
        if (day.weekday != r.day) continue;
        final t = DateTime(day.year, day.month, day.day, r.sh, r.sm);
        if (t.isAfter(now)) times.add(t);
      }
      final hm =
          '${r.sh.toString().padLeft(2, '0')}:${r.sm.toString().padLeft(2, '0')}';
      await _plan(r.nid, '${r.subj} • $hm', times);
    } catch (_) {}
  }

  static Future<void> cancelPlan(StudyPlan r) async {
    if (r.nid == 0) return;
    try {
      await init();
      await _cancelBase(r.nid);
    } catch (_) {}
  }

  /// Önümüzdeki 14 günde seçili günlerin belirli saatleri
  static List<DateTime> _dailyTimes(int h, int m, bool Function(int) onDay) {
    final now = DateTime.now();
    final out = <DateTime>[];
    for (var d = 0; d < 14; d++) {
      final day = DateTime(now.year, now.month, now.day + d);
      final t = DateTime(day.year, day.month, day.day, h, m);
      if (t.isAfter(now) && onDay(day.weekday)) out.add(t);
    }
    return out;
  }

  static String _hm(int h, int m) =>
      '${h.toString().padLeft(2, '0')}:${m.toString().padLeft(2, '0')}';

  static Future<void> syncAlarm(AlarmItem a) async {
    if (a.nid == 0) return;
    try {
      await init();
      await _cancelBase(a.nid);
      if (!a.on) return;
      final body = a.label.isEmpty ? _hm(a.h, a.m) : '${a.label} • ${_hm(a.h, a.m)}';
      await _plan(a.nid, body, _dailyTimes(a.h, a.m, a.onDay),
          details: _alarmDetails, payload: 'alarm:${a.id}');
    } catch (_) {}
  }

  static Future<void> cancelAlarm(AlarmItem a) async {
    if (a.nid == 0) return;
    try {
      await init();
      await _cancelBase(a.nid);
    } catch (_) {}
  }

  static Future<void> syncLauncher(LaunchItem a) async {
    if (a.nid == 0) return;
    try {
      await init();
      await _cancelBase(a.nid);
      if (!a.on) return;
      await _plan(a.nid, '${a.label} • ${tx('başlatmak için dokun')}',
          _dailyTimes(a.h, a.m, a.onDay),
          payload: 'launch:${a.id}');
    } catch (_) {}
  }

  static Future<void> cancelLauncher(LaunchItem a) async {
    if (a.nid == 0) return;
    try {
      await init();
      await _cancelBase(a.nid);
    } catch (_) {}
  }

  /// Açılışta ve yedek yüklenince hepsini yeniden planlar
  static Future<void> rescheduleAll() async {
    try {
      await init();
      await _p.cancelAll();
      for (final r in store.reminders) {
        if (r.enabled) await _plan(r.nid, r.text, reminderTimes(r, DateTime.now()));
      }
      for (final f in store.freeRows) {
        if (f.nid != 0 && f.remindMs > 0) await syncFree(f);
      }
      for (final c in store.cats) {
        for (final s in c.subs) {
          if (s.nid != 0 && s.routine && s.rh >= 0) await syncSub(s);
        }
      }
      for (final t in store.todos) {
        if (t.nid != 0 && !t.done && t.remindMs > 0) {
          await _plan(t.nid, t.text, todoRemindTimes(t, DateTime.now()));
        }
      }
      for (final r in store.studyPlan) {
        if (r.remind && r.nid != 0) await syncPlan(r);
      }
      for (final a in store.alarms) {
        if (a.on) await syncAlarm(a);
      }
      for (final a in store.launchers) {
        if (a.on) await syncLauncher(a);
      }
      for (final d in store.wdebts) {
        if (d.remind && !d.done) await syncDebt(d);
      }
    } catch (_) {}
  }

  /// Cüzdan: borç / alacak vade günü sabah 09:00 bildirimi
  static Future<void> syncDebt(WalletDebt d) async {
    try {
      await init();
      await cancelOnce(d.nid * 100);
      if (!d.remind || d.nid == 0 || d.dueMs <= 0 || d.done) return;
      final day = DateTime.fromMillisecondsSinceEpoch(d.dueMs);
      final when = DateTime(day.year, day.month, day.day, 9);
      if (when.isBefore(DateTime.now())) return;
      final body = d.theirs
          ? tx('{0}: alacak vadesi bugün', [d.person])
          : tx('{0}: borç vadesi bugün', [d.person]);
      await scheduleOnce(d.nid * 100, body, when);
    } catch (_) {}
  }

  static Future<void> cancelDebt(WalletDebt d) async {
    try {
      await init();
      await cancelOnce(d.nid * 100);
    } catch (_) {}
  }

  /// Tek seferlik bildirim (sayaç / pomodoro bitişi için)
  static Future<void> scheduleOnce(int id, String body, DateTime when) async {
    try {
      await init();
      final a = _android;
      final exact =
          a == null ? true : (await a.canScheduleExactNotifications() ?? false);
      await _p.zonedSchedule(
        id,
        'Daily Routine',
        body,
        tz.TZDateTime.fromMillisecondsSinceEpoch(
            tz.UTC, when.millisecondsSinceEpoch),
        _details,
        androidScheduleMode: exact
            ? AndroidScheduleMode.exactAllowWhileIdle
            : AndroidScheduleMode.inexactAllowWhileIdle,
      );
    } catch (_) {}
  }

  static Future<void> cancelOnce(int id) async {
    try {
      await init();
      await _p.cancel(id);
    } catch (_) {}
  }

  static Future<void> sendTest() async {
    await init();
    await _p.show(
      999999,
      'Daily Routine',
      tx('Deneme bildirimi: çalışıyor!'),
      _details,
    );
  }
}
