import 'dart:async';
import 'dart:convert';
import 'net.dart' show HourW;
import 'holidays.dart' show holidayBanner;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'dock.dart' show dockLaunch, dockLastTitle, favShort;
import 'main.dart' show navKey;
import 'media.dart';
import 'pip.dart';
import 'prayer.dart' show prayer, prayerNames, prayerNextText;
import 'tvpop.dart' show tvPop;
import 'strings.dart';
import 'weather.dart';

// ---------------------------------------------------------------
// Ana ekran aracı (widget): hava durumu, radyo, TV ve rutinler.
//  - Uygulama bilgiyi buradan Android tarafına gönderir (kanal: gunluk/widget, "update").
//    Android tarafı kodu .github/workflows/build.yml içinde üretilir (GunlukWidget.kt).
//  - Araçtaki radyo düğmeleri çalan medyayı doğrudan denetler. Hiçbir şey çalmıyorsa uygulama açılır
//    ve son radyo çalınır. TV düğmesi uygulamayı açar ve TV'yi küçük pop-up olarak başlatır.
//  - Araçtan gelen istek (radyo / tv) "take" ile okunur: uygulama açılırken ve arka plandan dönerken.
// ---------------------------------------------------------------

class WidgetSvc {
  static const _ch = MethodChannel('gunluk/widget');
  Timer? _t;
  String _last = '';
  bool _started = false;

  /// Dinleyicileri kurar (bir kez) ve ilk bilgiyi gönderir
  void init() {
    if (_started) return;
    _started = true;
    store.addListener(_soon);
    media.addListener(_soon);
    weather.addListener(_soon);
    prayer.addListener(_soon);
    prayer.ensure(); // namaz vakitleri (ana ekranda gösterilmese de araç için)
    // "İmsaka 6 sa 21 dk kaldı" dakikada bir tazelenir (metin değişmezse gönderilmez)
    Timer.periodic(const Duration(minutes: 1), (_) {
      prayer.ensure();
      _soon();
    });
    _soon();
  }

  /// Çok sık değişikliklerde yükü azaltmak için 1,5 sn bekleyip gönderir
  void _soon() {
    if (_pending != null) _tryPending();
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 1500), push);
  }

  String _wxEmoji(int? c, bool night) {
    if (c == null) return '';
    if (c == 0 || c == 1) return night ? '🌙' : '☀️';
    if (c == 2) return '⛅';
    if (c == 3) return '☁️';
    if (c == 45 || c == 48) return '🌫️';
    if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82)) return '🌧️';
    if ((c >= 71 && c <= 77) || c == 85 || c == 86) return '❄️';
    if (c >= 95) return '⛈️';
    return '☁️';
  }

  String _wxLine() {
    final d = weather.data;
    if (!store.wxOn || d == null || d.nowTemp == null) return '';
    final hr = DateTime.now().hour;
    final code = d.nowCode;
    final desc = code == null ? '' : wxText(code);
    return '${_wxEmoji(code, hr < 6 || hr >= 20)} ${d.nowTemp!.round()}° $desc'.trim();
  }

  /// Bugünün rutinleri: (yapılan, toplam, yapılmayan ilk üç adı)
  (int, int, List<String>) _routines() {
    final now = DateTime.now();
    final date = dKey(now);
    var met = 0, total = 0;
    final open = <String>[];
    for (final c in store.cats) {
      for (final s in c.subs) {
        if (!s.scheduledOn(now)) continue;
        total++;
        final e = store.entryFor(s.id, date);
        final ok = e != null && goalMet(s, e.value);
        if (ok) {
          met++;
        } else if (open.length < 3) {
          open.add(s.name);
        }
      }
    }
    return (met, total, open);
  }

  /// Rutinler + Yapılacaklar listesi (kaydırılabilir araç için): [tür, yazı, tamam]
  /// tür: "h" başlık, "r" rutin, "t" yapılacak
  List<List<Object>> _listItems() {
    final now = DateTime.now();
    final date = dKey(now);
    final out = <List<Object>>[];
    var met = 0, total = 0;
    final rows = <List<Object>>[];
    for (final c in store.cats) {
      for (final sb in c.subs) {
        if (!sb.scheduledOn(now)) continue;
        total++;
        final e = store.entryFor(sb.id, date);
        final ok = e != null && goalMet(sb, e.value);
        if (ok) met++;
        if (rows.length < 60) rows.add(['r', sb.name, ok]);
      }
    }
    out.add(['h', '${tx('Rutinler')} $met/$total', false]);
    if (rows.isEmpty) out.add(['r', tx('Bugün için rutin yok'), false]);
    out.addAll(rows);
    final todos = store.todosFor(date);
    final open = todos.where((t) => !t.done).length;
    out.add(['h', '${tx('Yapılacaklar')}${open > 0 ? ' $open' : ''}', false]);
    if (todos.isEmpty) out.add(['t', tx('Bugün için yapılacak yok'), false]);
    for (final t in todos.take(40)) {
      out.add(['t', t.text, t.done]);
    }
    return out;
  }

  /// Bildirimler aracı: hava, ikazlar, yaklaşan namaz vakti
  List<String> _noteLines() {
    final out = <String>[];
    final w = wxSummaryNow();
    if (w.isNotEmpty) out.add(w);
    final d = weather.data;
    if (store.wxOn && d != null) {
      final al = wxAlertLine(wxAlerts(d), 0);
      if (al.isNotEmpty) out.add(al);
    }
    final pr = prayerNextText();
    if (pr.isNotEmpty) out.add(pr);
    return out;
  }

  String _mediaTitle(String kind) {
    final active = media.nowId != null;
    final isKind = active &&
        ((kind == 'radio' && media.isRadio) ||
            (kind == 'podcast' && media.isPod) ||
            (kind == 'music' && (media.isSong || media.isOnline)));
    if (isKind) return media.nowTitle;
    return dockLastTitle(kind);
  }

  /// Araçta hangi bölümler görünsün (Ayarlar > Ana ekran > Ana ekran aracı bölümleri)
  static const sections = <(String, String)>[
    ('radio', 'Radyo'),
    ('tv', 'TV'),
    ('rt', 'Rutinler'),
    ('todo', 'Yapılacaklar'),
    ('note', 'Günlük'),
    ('rem', 'Hatırlatıcı'),
    ('pray', 'Namaz vakti'),
    ('wx', 'Hava durumu'),
    ('date', 'Tarih ve sıcaklık'),
  ];

  bool _dark() {
    switch (store.themeMode) {
      case ThemeMode.dark:
        return true;
      case ThemeMode.light:
        return false;
      case ThemeMode.system:
        return WidgetsBinding.instance.platformDispatcher.platformBrightness ==
            Brightness.dark;
    }
  }

  bool _wetCode(int c) =>
      (c >= 51 && c <= 67) || (c >= 71 && c <= 77) || (c >= 80 && c <= 86) || c >= 95;

  /// Saatlik şerit: önümüzdeki 48 saat. [ms, "HH:00", gün kısaltması, simge, sıcaklık, yağış %, yağışlı mı]
  List<List<Object>> _hourly() {
    final d = weather.data;
    if (!store.wxOn || d == null) return [];
    final now = DateTime.now();
    final out = <List<Object>>[];
    for (var k = 0; k < 3; k++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: k));
      final hs = d.hours[dKey(day)] ?? const <HourW>[];
      for (final h in hs) {
        final t = DateTime(day.year, day.month, day.day, h.hour);
        if (t.isBefore(DateTime(now.year, now.month, now.day, now.hour))) continue;
        if (t.difference(now).inHours >= 48) break;
        final pop = h.rain >= 0 ? h.rain : (h.mm > 0 ? 100 : 0);
        final wet = _wetCode(h.code) && (h.rain < 0 || h.rain >= 30);
        out.add([
          t.millisecondsSinceEpoch,
          '${h.hour.toString().padLeft(2, '0')}:00',
          wdShort(t.weekday),
          _wxEmoji(h.code, h.hour < 6 || h.hour >= 20),
          '${h.temp.round()}°',
          pop,
          wet,
        ]);
      }
    }
    return out;
  }

  /// Namaz vakitleri şeridi: bugün, yarın ve ertesi gün. [ms, ad, "HH:mm", gün adı]
  List<List<Object>> _prayerStrip() {
    if (!store.prayOn) return [];
    final now = DateTime.now();
    final out = <List<Object>>[];
    for (var k = 0; k < 3; k++) {
      final day = DateTime(now.year, now.month, now.day).add(Duration(days: k));
      final t = k == 0 ? prayer.times : prayer.timesFor(day);
      if (t == null || t.length < 6) continue;
      for (var i = 0; i < 6; i++) {
        final p = t[i].split(':');
        if (p.length < 2) continue;
        final at = DateTime(day.year, day.month, day.day, int.tryParse(p[0]) ?? 0, int.tryParse(p[1]) ?? 0);
        out.add([
          at.millisecondsSinceEpoch,
          tx(prayerNames[i]),
          t[i],
          k == 0 ? '' : (k == 1 ? tx('Yarın') : wdShort(day.weekday)),
        ]);
      }
    }
    return out;
  }

  /// Hava satırı tek metin: "☁️ 15° bulutlu, yağış yok. En yakın yağış yarın (Pazar): yağmur %95"
  String _wxFull() {
    final d = weather.data;
    if (!store.wxOn || d == null || d.nowTemp == null) return '';
    final hr = DateTime.now().hour;
    final sum = wxSummaryNow();
    final head = '${_wxEmoji(d.nowCode, hr < 6 || hr >= 20)} ${d.nowTemp!.round()}°';
    return sum.isEmpty ? _wxLine() : '$head $sum';
  }

  /// Tek satır bildirim: hava uyarısı, yoksa önemli gün
  String _oneNote() {
    final d = weather.data;
    if (store.wxOn && d != null) {
      final al = wxAlertLine(wxAlerts(d), 0);
      if (al.isNotEmpty) return al;
    }
    return holidayBanner();
  }

  List<List<String>> _favs(bool radio) {
    final out = <List<String>>[];
    if (radio) {
      for (final c in store.radCats) {
        for (final st in c.stations) {
          if (st.fav) out.add([st.id, favShort(st.name)]);
        }
      }
    } else {
      for (final c in store.tvChans) {
        if (c.fav) out.add([c.id, favShort(c.name)]);
      }
    }
    return out;
  }

  Future<void> push() async {
    try {
      final active = media.nowId != null;
      final (artist, title) = media.nowSong;
      final song = title.isEmpty ? '' : (artist.isEmpty ? title : '$artist - $title');
      final (met, total, open) = _routines();
      final now = DateTime.now();
      final day = dKey(now);
      final todoN = store.todosFor(day).where((t) => !t.done).length;
      final remN = store.reminders
          .where((r) => r.enabled && !reminderFinished(r))
          .length;
      String two(int n) => n.toString().padLeft(2, '0');
      final wd = weather.data;
      final json = jsonEncode({
        'dark': _dark(),
        'mkind': !active
            ? ''
            : (media.isRadio
                ? 'radio'
                : (media.isPod
                    ? 'podcast'
                    : ((media.isSong || media.isOnline) ? 'music' : ''))),
        'mplay': active && media.playing,
        'm_radio': _mediaTitle('radio'),
        'm_music': _mediaTitle('music'),
        'm_podcast': _mediaTitle('podcast'),
        'm_tv': dockLastTitle('tv'),
        'mt_radio': tx('Radyo'),
        'mt_tv': tx('TV'),
        'mt_podcast': tx('Podcast'),
        'mt_music': tx('Müzik'),
        'rl': _listItems(),
        'nl': _noteLines(),
        'wxsum': wxSummaryNow(),
        'wxl': _wxFull(),
        'hr': _hourly(),
        'prl': _prayerStrip(),
        'wnote': _oneNote(),
        'rfav': _favs(true),
        'tfav': _favs(false),
        'mid': active ? (media.nowId ?? '') : '',
        'tvid': tvPop.chan?.id ?? '',
        'wxhead': tx('Hava durumu'),
        'nlhead': tx('Bildirimler'),
        'nlnone': tx('Şimdilik bildirim yok'),
        for (final sc in sections) 's_${sc.$1}': store.pBool('wg_${sc.$1}', true),
        'pray': prayerNextText(),
        'tttodo': tx('Yapılacaklar'),
        'todon': todoN > 0 ? '$todoN' : '',
        'ttnote': tx('Günlük'),
        'noteb': store.noteOf(day).isNotEmpty ? '•' : '',
        'ttrem': tx('Hatırlatıcı'),
        'remn': remN > 0 ? '$remN' : '',
        'date': tx('Bugün') +
            ' ${two(now.day)}.${two(now.month)}.${now.year} ${wdName(now.weekday)}',
        'wtemp': (store.wxOn && wd != null && wd.nowTemp != null)
            ? '${wd.nowTemp!.round()}°'
            : '',
        'wx': _wxLine(),
        'rname': active ? media.nowTitle : dockLastTitle('radio'),
        'rsong': active ? song : '',
        'ractive': active,
        'rplaying': active && media.playing,
        'tv': dockLastTitle('tv'),
        'rtmet': met,
        'rttotal': total,
        'rt': open,
        'rthead': tx('Rutinler'),
        'rtnone': tx('Bugün için rutin yok'),
        'rtall': tx('Hepsi tamam'),
        'radiodef': tx('Radyo'),
        'tvdef': tx('TV'),
      });
      if (json == _last) return;
      _last = json;
      await _ch.invokeMethod('update', {'json': json});
    } catch (_) {
      // araç yoksa ya da kanal hazır değilse sessizce geçilir
    }
  }

  /// Telefonda widget kayıtlı mı: (kayıtlı sağlayıcı sayısı, ana ekrana konmuş sayısı); eski sürümde null
  Future<(int, int)?> status() async {
    try {
      final m = await _ch.invokeMapMethod<String, dynamic>('status');
      if (m == null) return null;
      return (((m['providers'] ?? 0) as num).toInt(), ((m['placed'] ?? 0) as num).toInt());
    } catch (_) {
      return null;
    }
  }

  /// Ana ekrana widget eklemeyi ister (telefon onay penceresi gösterir); desteklenmiyorsa false
  Future<bool> pin([String kind = 'all']) async {
    try {
      return (await _ch.invokeMethod<bool>('pin', {'kind': kind})) ?? false;
    } catch (_) {
      return false;
    }
  }

  String? _pending; // araçtan gelen ama henüz işlenmemiş istek (uygulama açılırken kaybolmasın)
  Timer? _retry;

  /// Araçtan gelen istek: "radio" / "music" / "podcast" (hiçbir şey çalmıyordu) ya da "tv".
  /// Uygulama soğuk açılıyorsa ekran / kilit hazır olana kadar istek saklanır ve tekrar denenir.
  Future<void> takeAction() async {
    try {
      final a = await _ch.invokeMethod<String>('take');
      if (a != null && a.isNotEmpty) _pending = a;
    } catch (_) {}
    if (_pending == null) return;
    _tryPending();
    var n = 0;
    _retry?.cancel();
    _retry = Timer.periodic(const Duration(seconds: 1), (t) {
      n++;
      if (_pending == null || n > 60) {
        t.cancel();
        return;
      }
      _tryPending();
    });
  }

  void _tryPending() {
    final a = _pending;
    if (a == null) return;
    final ctx = navKey.currentContext;
    if (ctx == null || store.locked) return; // hazır değil: istek saklı kalır
    _pending = null;
    _retry?.cancel();
    _run(ctx, a);
  }

  Future<void> _run(BuildContext ctx, String a) async {
    try {
      if (a == 'radio') {
        if (media.nowId == null || !media.isRadio) {
          await dockLaunch(ctx, 'radio');
        } else {
          media.toggle();
        }
      } else if (a.startsWith('radio:')) {
        final id = a.substring(6);
        for (final c in store.radCats) {
          for (final st in c.stations) {
            if (st.id == id) {
              tvPop.close();
              await media.playStation(st);
              return;
            }
          }
        }
      } else if (a.startsWith('tv:')) {
        final id = a.substring(3);
        for (final c in store.tvChans) {
          if (c.id == id) {
            tvPop.show(c);
            if (pip.enabled) {
              await Future.delayed(const Duration(milliseconds: 1200));
              if (tvPop.chan != null) pip.enter();
            }
            return;
          }
        }
      } else if (a == 'music' || a == 'podcast') {
        await dockLaunch(ctx, a);
      } else if (a == 'tv') {
        await dockLaunch(ctx, 'tv');
        // araçtan başlatılan TV: uygulama ekranı görünmeden hemen küçük pencereye geç
        if (pip.enabled && tvPop.chan != null) {
          await Future.delayed(const Duration(milliseconds: 1200));
          if (tvPop.chan != null) pip.enter();
        }
      }
    } catch (_) {}
  }
}

final widgetSvc = WidgetSvc();

/// Ayarlar > Ana ekran: araçta hangi bölümlerin görüneceği (açma / kapama anahtarları)
class WidgetSectionsTile extends StatelessWidget {
  const WidgetSectionsTile({super.key});

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => ExpansionTile(
        tilePadding: EdgeInsets.zero,
        leading: const Icon(Icons.dashboard_customize_outlined),
        title: Text(tx('Araçta görünecekler')),
        children: [
          for (final sc in WidgetSvc.sections)
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(tx(sc.$2)),
              value: store.pBool('wg_${sc.$1}', true),
              onChanged: (v) {
                store.setProf('wg_${sc.$1}', v);
                widgetSvc.push();
              },
            ),
        ],
      ),
    );
  }
}

/// Ayarlar > Ana ekran: widget durumu ve "Ana ekrana ekle" düğmesi
class WidgetSetupTile extends StatefulWidget {
  const WidgetSetupTile({super.key});

  @override
  State<WidgetSetupTile> createState() => _WidgetSetupTileState();
}

class _WidgetSetupTileState extends State<WidgetSetupTile> {
  String _st = '';

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final r = await widgetSvc.status();
    if (!mounted) return;
    setState(() {
      _st = r == null
          ? tx('Bu sürümde araç desteği yok (eski sürüm kurulu olabilir).')
          : r.$1 == 0
              ? tx('Telefonda kayıtlı değil (derleme eksik olabilir).')
              : r.$2 > 0
                  ? tx('Ana ekranda {0} adet var.', ['${r.$2}'])
                  : tx('Telefonda kayıtlı, henüz ana ekranda yok.');
    });
  }

  Future<void> _add(String kind) async {
    final m = ScaffoldMessenger.of(context);
    final ok = await widgetSvc.pin(kind);
    widgetSvc.push();
    m.clearSnackBars();
    m.showSnackBar(SnackBar(
        content: Text(ok
            ? tx('Telefon onay isterse "Ekle"ye dokun.')
            : tx('Telefon eklemeyi desteklemiyor ya da izin kapalı. Uygulama izinlerinde "Ana ekrana kısayol oluştur"u aç ya da ana ekranda boş yere uzun basıp Widget\'lar\'dan ekle.'))));
    _load();
  }

  @override
  Widget build(BuildContext context) {
    const kinds = <(String, String)>[
      ('all', 'Hepsi bir arada'),
      ('media', 'Medya'),
      ('list', 'Rutin ve yapılacaklar'),
      ('wx', 'Hava ve imsak'),
      ('notes', 'Bildirimler'),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.widgets_outlined),
          title: Text(tx('Ana ekran araçları (widget)')),
          subtitle: Text(_st),
        ),
        Wrap(
          spacing: 8,
          runSpacing: 0,
          children: [
            for (final k in kinds)
              ActionChip(
                avatar: const Icon(Icons.add_rounded, size: 18),
                label: Text(tx(k.$2)),
                onPressed: () => _add(k.$1),
              ),
          ],
        ),
        const SizedBox(height: 8),
      ],
    );
  }
}
