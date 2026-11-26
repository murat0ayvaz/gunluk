import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'dock.dart' show dockLaunch, dockLastTitle;
import 'main.dart' show navKey;
import 'media.dart';
import 'pip.dart';
import 'prayer.dart' show prayer, prayerNextText;
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
  Future<bool> pin() async {
    try {
      return (await _ch.invokeMethod<bool>('pin')) ?? false;
    } catch (_) {
      return false;
    }
  }

  /// Araçtan gelen istek: "radio" (hiçbir şey çalmıyordu) ya da "tv"
  Future<void> takeAction() async {
    try {
      final a = await _ch.invokeMethod<String>('take');
      if (a == null || a.isEmpty) return;
      final ctx = navKey.currentContext;
      if (ctx == null || store.locked) return;
      if (a == 'radio') {
        if (media.nowId == null) {
          await dockLaunch(ctx, 'radio');
        } else {
          media.toggle();
        }
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

  @override
  Widget build(BuildContext context) {
    return ListTile(
      contentPadding: EdgeInsets.zero,
      leading: const Icon(Icons.widgets_outlined),
      title: Text(tx('Ana ekran aracı (widget)')),
      subtitle: Text(_st),
      trailing: TextButton(
        onPressed: () async {
          final m = ScaffoldMessenger.of(context);
          final ok = await widgetSvc.pin();
          widgetSvc.push();
          m.clearSnackBars();
          m.showSnackBar(SnackBar(
              content: Text(ok
                  ? tx('Telefon onay isterse "Ekle"ye dokun.')
                  : tx('Telefon eklemeyi desteklemiyor ya da izin kapalı. Uygulama izinlerinde "Ana ekrana kısayol oluştur"u aç ya da ana ekranda boş yere uzun basıp Widget\'lar\'dan ekle.'))));
          _load();
        },
        child: Text(tx('Ana ekrana ekle')),
      ),
    );
  }
}
