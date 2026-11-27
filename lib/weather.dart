import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'data.dart';
import 'net.dart';
import 'strings.dart';
import 'package:url_launcher/url_launcher.dart';
import 'theme.dart' show Pal;
import 'media.dart' show slideFromRight;
import 'ui.dart';
import 'wxdetail.dart' show WxDetailPage;

// ---------------------------------------------------------------
// HAVA DURUMU (servis Ayarlar'dan seçilir; şehir adı veya GPS)
//  - Ana ekranda tarih yanında küçük simge: bugün = şimdiki durum,
//    diğer günler = o günün hava simgesi ve en yüksek sıcaklık
//  - Simgeye basınca saatlik hava aşağı doğru açılır
//  - Ayarlar > Hava durumu: açma/kapama ve şehir seçimi
// ---------------------------------------------------------------

class WeatherCtl extends ChangeNotifier {
  WeatherData? data;
  bool loading = false;
  bool failed = false;
  DateTime? _at;
  String _key = '';

  /// Veri yoksa veya 30 dakikadan eskiyse (ya da şehir değiştiyse) yeniler
  Future<void> ensure({bool force = false}) async {
    if (!store.wxOn) return;
    final sel = store.wxSel;
    final fav = (sel >= 0 && sel < store.wxFavs.length) ? store.wxFavs[sel] : null;
    final key0 =
        '${store.wxProvider}|${fav == null ? 'gps' : '${fav.lat},${fav.lon}'}';
    final fresh = _at != null &&
        _key == key0 &&
        DateTime.now().difference(_at!) < const Duration(minutes: 30);
    if (!force && data != null && fresh) return;
    if (loading) return;
    loading = true;
    failed = false;
    errText = null;
    notifyListeners();
    try {
      final double lat;
      final double lon;
      if (fav != null) {
        lat = fav.lat;
        lon = fav.lon;
      } else {
        final pos = await locate();
        if (pos == null) throw Exception('gpsoff');
        lat = pos.$1;
        lon = pos.$2;
      }
      final d = await fetchWeatherFor(
          store.wxProvider, lat, lon, store.wxOwmKey,
          place: fav?.name ?? '');
      data = d;
      _at = DateTime.now();
      _key = key0;
    } catch (e) {
      failed = true; // eski veri varsa o gösterilmeye devam eder
      errText = _explain(e);
    }
    loading = false;
    notifyListeners();
  }

  /// Telefonun konumu: bulunursa kaydeder; bulunamazsa son bilinen konum (yoksa hata)
  Future<(double, double)?> locate() async {
    try {
      final pos = await _locate();
      store.setWxPos(pos.latitude, pos.longitude);
      return (pos.latitude, pos.longitude);
    } catch (e) {
      final la = store.wxLat;
      final lo = store.wxLon;
      if (la != null && lo != null) return (la, lo);
      rethrow;
    }
  }

  String? errText;

  /// Hatanın nedenini kısa ve anlaşılır yazar (hangi servis, hangi adım, kod)
  String _explain(Object e) {
    final s = e.toString();
    if (s.contains('perm')) return tx('Konum izni verilmedi.');
    if (s.contains('gpsoff')) return tx('Telefonun konum servisi kapalı.');
    if (e is WxError) {
      final name = wxProviderName(e.provider);
      if (e.step == 'anahtar') {
        return tx('{0}: API anahtarı girilmemiş.', [name]);
      }
      if (e.provider == 'owm' && e.detail.contains('401')) {
        return tx('{0}: anahtar geçersiz veya henüz etkin değil (401). Yeni anahtarlar etkinleşmek için biraz bekleyebilir.', [name]);
      }
      return tx('{0}: {1} adımında hata ({2}).', [name, e.step, e.detail]);
    }
    return tx('{0}: bağlantı hatası.', [wxProviderName(store.wxProvider)]);
  }

  Future<Position> _locate() async {
    if (!await Geolocator.isLocationServiceEnabled()) {
      throw Exception('gpsoff');
    }
    var perm = await Geolocator.checkPermission();
    if (perm == LocationPermission.denied) {
      perm = await Geolocator.requestPermission();
    }
    if (perm == LocationPermission.denied ||
        perm == LocationPermission.deniedForever) {
      throw Exception('perm');
    }
    try {
      return await Geolocator.getCurrentPosition()
          .timeout(const Duration(seconds: 20));
    } catch (_) {
      final last = await Geolocator.getLastKnownPosition();
      if (last != null) return last;
      rethrow;
    }
  }

  /// Şehir değişince eski veriyi at ve yeniden çek
  void reset() {
    data = null;
    _at = null;
    errText = null;
    notifyListeners();
    ensure(force: true);
  }
}

final weather = WeatherCtl();

// ---------- WMO hava kodu -> simge ----------
IconData wxIcon(int code, {bool night = false}) {
  if (code == 0 || code == 1) {
    return night ? Icons.nightlight_round : Icons.wb_sunny_rounded;
  }
  if (code == 2) return Icons.filter_drama_rounded;
  if (code == 3) return Icons.cloud_rounded;
  if (code == 45 || code == 48) return Icons.blur_on_rounded;
  if (code >= 51 && code <= 57) return Icons.grain_rounded;
  if ((code >= 61 && code <= 67) || (code >= 80 && code <= 82)) {
    return Icons.water_drop_rounded;
  }
  if ((code >= 71 && code <= 77) || code == 85 || code == 86) {
    return Icons.ac_unit_rounded;
  }
  if (code >= 95) return Icons.flash_on_rounded;
  return Icons.cloud_rounded;
}

Color wxColor(int code) {
  if (code <= 1) return const Color(0xFFF2B63D);
  if (code == 2) return const Color(0xFFE0A84A);
  if (code == 3 || code == 45 || code == 48) return const Color(0xFF9AA3AE);
  if (code >= 95) return const Color(0xFF9B7FD1);
  if (code >= 71 && code <= 77) return const Color(0xFF7FB6DE);
  return const Color(0xFF5E9BD6);
}

String _deg(double t) => '${t.round()}°';

/// Türkçede saat eki: sıfır->da, bir->de, üç->te ... (örn. 15'te, 16'da)
String _atHour(int h, bool tomorrow) {
  final two = h.toString().padLeft(2, '0');
  if (appLang == 'en') return '${tomorrow ? 'tomorrow ' : ''}$two:00';
  const suf = [
    'da', 'de', 'de', 'te', 'te', 'te', 'da', 'de', 'de', 'da', 'da', 'de',
    'de', 'te', 'te', 'te', 'da', 'de', 'de', 'da', 'de', 'de', 'de', 'te'
  ];
  return '${tomorrow ? 'yarın ' : ''}$two\'${suf[h]}';
}

/// Hava yazısı, yağış odaklı: "bulutlu, 15'te yağmur %50" ya da "bulutlu, yağış yok"
String _precipText(WeatherData d, String date, String desc) {
  final now = DateTime.now();
  final cells = wxCells(d, date);
  for (final c in cells) {
    final isToday = c.key == date;
    if (isToday && c.h.hour < now.hour) continue;
    if (!isToday && c.h.hour > now.hour) continue; // yalnız önümüzdeki 24 saat
    final h = c.h;
    final snow = (h.code >= 71 && h.code <= 77) || h.code == 85 || h.code == 86;
    final wet = (h.code >= 51 && h.code <= 67) || (h.code >= 80 && h.code <= 86);
    final storm = h.code >= 95;
    final strong = h.rain >= 40 || (h.rain < 0 && h.mm >= 0.2);
    if (!(storm || (wet && strong))) continue;
    final kind = storm ? tx('fırtına') : (snow ? tx('kar') : tx('yağmur'));
    final at = _atHour(h.hour, !isToday);
    if (h.rain >= 0) return tx('{0}, {1} {2} %{3}', [desc, at, kind, h.rain]);
    return tx('{0}, {1} {2} ({3} mm)', [desc, at, kind, h.mm.toStringAsFixed(1)]);
  }
  return _noRainNear(d, desc);
}

/// 24 saatte yağış yok: tahmindeki günlerde en yakın yağışlı günü söyler
/// ("parçalı bulutlu, yağış yok. En yakın yağış 2 gün sonra (Pazar): yağmur %60")
String _noRainNear(WeatherData d, String desc) {
  final now = DateTime.now();
  var future = 0;
  for (var i = 1; i <= 14; i++) {
    final dt = now.add(Duration(days: i));
    final day = d.days[dKey(dt)];
    if (day == null) continue;
    future++;
    final snow = (day.code >= 71 && day.code <= 77) || day.code == 85 || day.code == 86;
    final wet = (day.code >= 51 && day.code <= 67) || (day.code >= 80 && day.code <= 86);
    final storm = day.code >= 95;
    final strong = day.rain < 0 || day.rain >= 40;
    if (!(storm || (wet && strong))) continue;
    final kind = storm ? tx('fırtına') : (snow ? tx('kar') : tx('yağmur'));
    final what = day.rain >= 0 ? '$kind %${day.rain}' : kind;
    final when = i == 1 ? tx('yarın') : tx('{0} gün sonra', [i]);
    return tx('{0}, yağış yok. En yakın yağış {1} ({2}): {3}',
        [desc, when, wdName(dt.weekday), what]);
  }
  if (future >= 1) {
    return tx('{0}, yağış yok. Önümüzdeki {1} gün yağış görünmüyor.', [desc, future]);
  }
  return tx('{0}, yağış yok', [desc]);
}

/// Bugünün hava yazısı (ana ekran aracı için); veri yoksa boş
String wxSummaryNow() {
  final d = weather.data;
  if (!store.wxOn || d == null) return '';
  final date = dKey(DateTime.now());
  final code = d.nowCode ?? d.days[date]?.code;
  if (code == null) return '';
  return _precipText(d, date, wxText(code));
}

/// WMO hava kodu -> kısa Türkçe açıklama ("açık", "yağmurlu" gibi)
String wxText(int code) {
  if (code == 0) return tx('hava açık');
  if (code == 1) return tx('çoğunlukla açık');
  if (code == 2) return tx('parçalı bulutlu');
  if (code == 3) return tx('bulutlu');
  if (code == 45 || code == 48) return tx('sisli');
  if (code >= 51 && code <= 57) return tx('çisenti');
  if (code == 66 || code == 67) return tx('dondurucu yağmurlu');
  if (code >= 61 && code <= 65) return tx('yağmurlu');
  if (code >= 80 && code <= 82) return tx('sağanak yağışlı');
  if (code == 85 || code == 86) return tx('kar sağanaklı');
  if (code >= 71 && code <= 77) return tx('karlı');
  if (code >= 95) return tx('gök gürültülü fırtınalı');
  return tx('bulutlu');
}

bool _isToday(String date) => date == dKey(DateTime.now());

/// Saatlik listedeki bir hücre: saat verisi + hangi güne ait olduğu
class WxCell {
  final HourW h;
  final String key;
  WxCell(this.h, this.key);
}

/// Saatlik liste gece yarısında kesilmez: seçili günün saatlerinin ardından
/// ertesi günün saatleri de gelir. Bugünde liste şimdiki saatin 3 saat
/// gerisinden başlar (gerisi gösterilmez).
List<WxCell> wxCells(WeatherData d, String date) {
  final base = parseKey(date);
  final prev = dKey(DateTime(base.year, base.month, base.day - 1));
  final next = dKey(DateTime(base.year, base.month, base.day + 1));
  final all = <WxCell>[];
  for (final k in [prev, date, next]) {
    for (final h in d.hours[k] ?? const <HourW>[]) {
      all.add(WxCell(h, k));
    }
  }
  final now = DateTime.now();
  var start = 0;
  if (_isToday(date)) {
    final from = DateTime(now.year, now.month, now.day, now.hour)
        .subtract(const Duration(hours: 3));
    start = all.indexWhere((c) {
      final t = parseKey(c.key);
      return !DateTime(t.year, t.month, t.day, c.h.hour).isBefore(from);
    });
  } else {
    start = all.indexWhere((c) => c.key == date);
  }
  if (start < 0) start = 0;
  return all.sublist(start);
}

/// Saat etiketi; gün başında (00:00) günün adı da yazılır
String wxCellLabel(WxCell c) {
  if (c.h.hour != 0) return _hh(c.h.hour);
  final t = parseKey(c.key);
  final tom = DateTime.now().add(const Duration(days: 1));
  final tag = dKey(tom) == c.key
      ? tx('Yarın')
      : '${t.day.toString().padLeft(2, '0')}.${t.month.toString().padLeft(2, '0')}';
  return '$tag 00';
}



// ---------------------------------------------------------------
// Tarih yanındaki küçük simge
// ---------------------------------------------------------------
class WxChip extends StatelessWidget {
  final String date;
  final bool open;
  final VoidCallback onTap;
  const WxChip(
      {super.key, required this.date, required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([weather, store]),
      builder: (context, _) {
        if (!store.wxOn) return const SizedBox.shrink();
        final d = weather.data;
        if (d == null) {
          if (weather.loading) {
            return const Padding(
              padding: EdgeInsets.symmetric(horizontal: 8),
              child: SizedBox(
                  width: 14,
                  height: 14,
                  child: CircularProgressIndicator(strokeWidth: 2)),
            );
          }
          return weather.failed
              ? IconButton(
                  tooltip: weather.errText ?? tx('Hava durumu alınamadı. Dokun, yeniden dene.'),
                  visualDensity: VisualDensity.compact,
                  onPressed: () {
                    final msg = weather.errText;
                    if (msg != null) {
                      ScaffoldMessenger.of(context)
                        ..clearSnackBars()
                        ..showSnackBar(SnackBar(
                            duration: const Duration(seconds: 6),
                            content: Text(msg)));
                    }
                    weather.ensure(force: true);
                  },
                  icon: Icon(Icons.cloud_off_rounded, size: 18, color: p.soft))
              : const SizedBox.shrink();
        }
        final day = d.days[date];
        IconData icon;
        Color color;
        String text;
        if (_isToday(date) && d.nowCode != null && d.nowTemp != null) {
          final hr = DateTime.now().hour;
          icon = wxIcon(d.nowCode!, night: hr < 6 || hr >= 20);
          color = wxColor(d.nowCode!);
          text = _deg(d.nowTemp!);
        } else if (day != null) {
          icon = wxIcon(day.code);
          color = wxColor(day.code);
          text = _deg(day.tmax);
        } else {
          return const SizedBox.shrink(); // bu gün için veri yok
        }
        return InkWell(
          borderRadius: BorderRadius.circular(10),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 4),
            decoration: BoxDecoration(
              color: open ? p.card : null,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(icon, size: 18, color: color),
                const SizedBox(width: 3),
                Text(text,
                    style: TextStyle(
                        fontSize: 12.5,
                        fontWeight: FontWeight.w600,
                        color: p.ink)),
                if (wxAlerts(d).isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(left: 3),
                    child: Icon(Icons.warning_amber_rounded,
                        size: 17,
                        color: wxAlerts(d).any((a) => a.level >= 2)
                            ? const Color(0xFFD1495B)
                            : const Color(0xFFE8883A)),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

// ---------------------------------------------------------------
// Saatlik hava şeridi (aşağı doğru açılan panel)
// ---------------------------------------------------------------
class WxPanel extends StatefulWidget {
  final String date;
  const WxPanel({super.key, required this.date});

  @override
  State<WxPanel> createState() => _WxPanelState();
}

class _WxPanelState extends State<WxPanel> {
  static const double _cell = 58;
  late final ScrollController _sc;

  @override
  void initState() {
    super.initState();
    // Bugünde liste şimdiki saatin 3 saat gerisinden başlar; diğer günlerde sabah 6'ya yakın
    _sc = ScrollController(
        initialScrollOffset: _isToday(widget.date) ? 0 : 6 * _cell);
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: weather,
      builder: (context, _) {
        final d = weather.data;
        final cells = d == null ? <WxCell>[] : wxCells(d, widget.date);
        if (d == null || cells.isEmpty) {
          return const SizedBox.shrink();
        }
        final day = d.days[widget.date];
        final nowHr = DateTime.now().hour;
        final today = _isToday(widget.date);
        final alerts = wxAlerts(d);
        return GestureDetector(
          behavior: HitTestBehavior.translucent,
          onTap: () => Navigator.of(context)
              .push(slideFromRight(const WxDetailPage())),
          child: Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 10),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.line),
          ),
          padding: const EdgeInsets.only(top: 10, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (alerts.isNotEmpty) wxAlertRows(context, p, alerts),
              if (day != null)
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 6),
                  child: Text(
                    day.rain >= 0
                        ? tx('En yüksek {0} • en düşük {1} • yağış %{2}',
                            [_deg(day.tmax), _deg(day.tmin), day.rain])
                        : tx('En yüksek {0} • en düşük {1}',
                            [_deg(day.tmax), _deg(day.tmin)]),
                    style: TextStyle(fontSize: 12.5, color: p.soft),
                  ),
                ),
              SizedBox(
                height: 82,
                child: ListView.builder(
                  controller: _sc,
                  scrollDirection: Axis.horizontal,
                  itemExtent: _cell,
                  itemCount: cells.length,
                  itemBuilder: (context, i) {
                    final c = cells[i];
                    final h = c.h;
                    final isNow = today && c.key == widget.date && h.hour == nowHr;
                    return Container(
                      margin: const EdgeInsets.symmetric(horizontal: 2),
                      decoration: BoxDecoration(
                        color: isNow ? p.bg : null,
                        borderRadius: BorderRadius.circular(10),
                        border: isNow ? Border.all(color: p.line) : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(wxCellLabel(c),
                              style: TextStyle(fontSize: 11, color: p.soft)),
                          const SizedBox(height: 2),
                          Icon(
                              wxIcon(h.code,
                                  night: h.hour < 6 || h.hour >= 20),
                              size: 22,
                              color: wxColor(h.code)),
                          const SizedBox(height: 2),
                          Text(_deg(h.temp),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w600,
                                  color: p.ink)),
                          Text(
                              h.rain >= 20
                                  ? '%${h.rain}'
                                  : (h.rain < 0 && h.mm >= 0.1
                                      ? '${h.mm.toStringAsFixed(1)}mm'
                                      : ''),
                              style: const TextStyle(
                                  fontSize: 10, color: Color(0xFF5E9BD6))),
                        ],
                      ),
                    );
                  },
                ),
              ),
            ],
          ),
        ));
      },
    );
  }
}

// ---------------------------------------------------------------
// Şehir seçme penceresi (Ayarlar'dan)
// ---------------------------------------------------------------
Future<void> showCityDialog(BuildContext context) {
  return showDialog<void>(
      context: context, builder: (_) => const _CityDialog());
}

/// Şehir arar; seçileni döndürür (ayarları değiştirmez). Favori yer eklemek için.
Future<GeoCity?> pickGeoCity(BuildContext context) {
  return showDialog<GeoCity>(
      context: context, builder: (_) => const _CityDialog(forFav: true));
}

class _CityDialog extends StatefulWidget {
  final bool forFav;
  const _CityDialog({this.forFav = false});

  @override
  State<_CityDialog> createState() => _CityDialogState();
}

class _CityDialogState extends State<_CityDialog> {
  final _q = TextEditingController();
  List<GeoCity> _res = [];
  bool _loading = false;
  bool _searched = false;
  String? _err;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    final term = _q.text.trim();
    if (term.length < 2) return;
    setState(() {
      _loading = true;
      _err = null;
      _searched = true;
    });
    try {
      final r = await geoSearch(term, appLang == 'en' ? 'en' : 'tr');
      if (!mounted) return;
      setState(() {
        _res = r;
        _loading = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _res = [];
        _loading = false;
        _err = tx('Şehir aranamadı. İnternetini kontrol et.');
      });
    }
  }

  void _pick(GeoCity c) {
    if (widget.forFav) {
      Navigator.pop(context, c);
      return;
    }
    store.setWeatherCity(c.label, c.lat, c.lon);
    weather.reset();
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return AlertDialog(
      title: Text(tx('Şehir seç')),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _q,
                    autofocus: true,
                    textInputAction: TextInputAction.search,
                    onSubmitted: (_) => _search(),
                    decoration: InputDecoration(
                        hintText: tx('Şehir adı (ör. Ankara)'), isDense: true),
                  ),
                ),
                IconButton(
                    tooltip: tx('Ara'),
                    onPressed: _search,
                    icon: const Icon(Icons.search_rounded)),
              ],
            ),
            const SizedBox(height: 8),
            if (_loading)
              const Padding(
                  padding: EdgeInsets.all(16),
                  child: CircularProgressIndicator())
            else if (_err != null)
              Text(_err!, style: TextStyle(color: p.soft))
            else if (_searched && _res.isEmpty)
              Text(tx('Sonuç bulunamadı.'), style: TextStyle(color: p.soft))
            else
              Flexible(
                child: ListView.builder(
                  shrinkWrap: true,
                  itemCount: _res.length,
                  itemBuilder: (context, i) {
                    final c = _res[i];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text(c.name),
                      subtitle: Text(
                          [c.region, c.country]
                              .where((x) => x.isNotEmpty)
                              .join(', '),
                          style: TextStyle(color: p.soft, fontSize: 12)),
                      onTap: () => _pick(c),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(tx('Kapat'))),
      ],
    );
  }
}

// ---------------------------------------------------------------
// HAVA UYARILARI: tahmin verisinden bugün / yarın için sert hava işaretleri.
// Resmî uyarı DEĞİLDİR (resmî uyarılar için Meteoroloji bağlantısı verilir).
// ---------------------------------------------------------------
class WxAlert {
  final int level; // 1 dikkat, 2 uyarı
  final String text;
  final String when; // "Yarın 14:00-16:00" (ayrıntı penceresi için)
  final int day; // 0 = bugün, 1 = yarın
  final String at; // yalnız saat aralığı ("14:00-16:00"); günlük uyarılarda boş
  const WxAlert(this.level, this.text, this.when, {this.day = 0, this.at = ''});
}

String _lowerFirst(String s) =>
    s.isEmpty ? s : s.substring(0, 1).toLowerCase() + s.substring(1);

/// Hava satırının sonuna eklenecek uyarı yazısı. [viewDay]: satırın gösterdiği gün
/// (0 bugün, 1 yarın). Bugün satırında yarının uyarıları "yarın" diye belirtilir,
/// yarın satırında yalnız yarının uyarıları gösterilir. Boşsa '' döner.
String wxAlertLine(List<WxAlert> all, int viewDay) {
  final al = [
    for (final a in all)
      if (a.day == viewDay || (viewDay == 0 && a.day == 1)) a
  ];
  if (al.isEmpty) return '';
  String one(WxAlert a) {
    final pre = a.day > viewDay ? '${tx('yarın')} ' : '';
    final at = a.at.isEmpty ? '' : '${a.at} ';
    return '$pre$at${_lowerFirst(a.text)}';
  }

  final shown = al.take(2).map(one).join(' • ');
  final extra = al.length > 2 ? ' ${tx('+{0} uyarı daha', [al.length - 2])}' : '';
  return '${tx('Uyarı: {0}.', [shown])}$extra';
}

String _hh(int h) => '${h.toString().padLeft(2, '0')}:00';

List<WxAlert> wxAlerts(WeatherData d) {
  final out = <WxAlert>[];
  final now = DateTime.now();
  for (var k = 0; k < 2; k++) {
    final day = DateTime(now.year, now.month, now.day + k);
    final key = dKey(day);
    final label = k == 0 ? tx('Bugün') : tx('Yarın');
    final hours = d.hours[key] ?? const <HourW>[];
    final from = k == 0 ? now.hour : 0;

    String span(List<int> hs) =>
        hs.length == 1 ? _hh(hs.first) : '${_hh(hs.first)}-${_hh(hs.last + 1 > 23 ? 23 : hs.last + 1)}';

    final heavy = <int>[];
    var maxMm = 0.0;
    final storm = <int>[];
    final snow = <int>[];
    for (final h in hours) {
      if (h.hour < from) continue;
      if (h.mm >= 4 || (h.rain >= 70 && h.mm >= 2)) {
        heavy.add(h.hour);
        if (h.mm > maxMm) maxMm = h.mm;
      }
      if (h.code == 95 || h.code == 96 || h.code == 99) storm.add(h.hour);
      if ((h.code >= 71 && h.code <= 77) || h.code == 85 || h.code == 86) {
        snow.add(h.hour);
      }
    }
    if (heavy.isNotEmpty) {
      out.add(WxAlert(maxMm >= 10 ? 2 : 1, tx('Yoğun yağış bekleniyor'),
          '$label ${span(heavy)}', day: k, at: span(heavy)));
    }
    if (storm.isNotEmpty) {
      out.add(WxAlert(2, tx('Gök gürültülü fırtına bekleniyor'),
          '$label ${span(storm)}', day: k, at: span(storm)));
    }
    if (snow.isNotEmpty) {
      out.add(WxAlert(1, tx('Kar yağışı bekleniyor'), '$label ${span(snow)}',
          day: k, at: span(snow)));
    }
    final dd = d.days[key];
    if (dd != null) {
      if (dd.tmax >= 35) {
        out.add(WxAlert(dd.tmax >= 40 ? 2 : 1,
            tx('Çok sıcak (en yüksek {0})', [_deg(dd.tmax)]), label,
            day: k));
      }
      if (dd.tmin <= 0) {
        out.add(WxAlert(dd.tmin <= -5 ? 2 : 1,
            tx('Dondurucu soğuk (en düşük {0})', [_deg(dd.tmin)]), label,
            day: k));
      }
    }
  }
  return out;
}

Future<void> _openMgm() async {
  try {
    await launchUrl(Uri.parse('https://www.mgm.gov.tr/meteouyari/turkiye.aspx'),
        mode: LaunchMode.externalApplication);
  } catch (_) {}
}

void showWxAlerts(BuildContext context, List<WxAlert> al) {
  showDialog<void>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tx('Hava uyarıları')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final a in al)
            Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 20,
                      color: a.level >= 2
                          ? const Color(0xFFD1495B)
                          : const Color(0xFFE8883A)),
                  const SizedBox(width: 8),
                  Expanded(child: Text('${a.when}: ${a.text}')),
                ],
              ),
            ),
          const SizedBox(height: 4),
          Text(
              tx('Bunlar tahmin verisinden çıkarılan işaretlerdir, resmî uyarı değildir.'),
              style: const TextStyle(fontSize: 12.5)),
        ],
      ),
      actions: [
        TextButton(onPressed: _openMgm, child: Text(tx('Resmî uyarılar (MGM)'))),
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(tx('Tamam'))),
      ],
    ),
  );
}

Widget wxAlertRows(BuildContext context, Pal p, List<WxAlert> al) {
  return InkWell(
    onTap: () => showWxAlerts(context, al),
    child: Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          for (final a in al)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Row(
                children: [
                  Icon(Icons.warning_amber_rounded,
                      size: 18,
                      color: a.level >= 2
                          ? const Color(0xFFD1495B)
                          : const Color(0xFFE8883A)),
                  const SizedBox(width: 6),
                  Expanded(
                    child: Text('${a.when}: ${a.text}',
                        style: TextStyle(
                            fontSize: 12.5,
                            fontWeight: FontWeight.w700,
                            color: p.ink)),
                  ),
                ],
              ),
            ),
        ],
      ),
    ),
  );
}

// ---------------------------------------------------------------
// Sol sütun: saatlik hava dikey (ana ekranın solunda dar sütun)
// ---------------------------------------------------------------
class WxSide extends StatefulWidget {
  final String date;
  const WxSide({super.key, required this.date});

  @override
  State<WxSide> createState() => _WxSideState();
}

class _WxSideState extends State<WxSide> {
  static const double _cell = 66;
  late final ScrollController _sc;

  @override
  void initState() {
    super.initState();
    _sc = ScrollController(
        initialScrollOffset: _isToday(widget.date) ? 0 : 6 * _cell);
  }

  @override
  void dispose() {
    _sc.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: weather,
      builder: (context, _) {
        final d = weather.data;
        final cells = d == null ? <WxCell>[] : wxCells(d, widget.date);
        if (d == null || cells.isEmpty) {
          return const SizedBox.shrink();
        }
        final alerts = wxAlerts(d);
        final nowHr = DateTime.now().hour;
        final today = _isToday(widget.date);
        return Container(
          width: 68,
          margin: const EdgeInsets.fromLTRB(8, 0, 0, 10),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.line),
          ),
          child: Column(
            children: [
              if (alerts.isNotEmpty)
                IconButton(
                  visualDensity: VisualDensity.compact,
                  onPressed: () => showWxAlerts(context, alerts),
                  icon: Icon(Icons.warning_amber_rounded,
                      color: alerts.any((a) => a.level >= 2)
                          ? const Color(0xFFD1495B)
                          : const Color(0xFFE8883A)),
                ),
              Expanded(
                child: ListView.builder(
                  controller: _sc,
                  itemExtent: _cell,
                  itemCount: cells.length,
                  itemBuilder: (context, i) {
                    final c = cells[i];
                    final h = c.h;
                    final isNow = today && c.key == widget.date && h.hour == nowHr;
                    return Container(
                      margin: const EdgeInsets.symmetric(
                          horizontal: 4, vertical: 2),
                      decoration: BoxDecoration(
                        color: isNow ? p.bg : null,
                        borderRadius: BorderRadius.circular(10),
                        border: isNow ? Border.all(color: p.line) : null,
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Text(wxCellLabel(c),
                              style: TextStyle(fontSize: 11, color: p.soft)),
                          Icon(
                              wxIcon(h.code,
                                  night: h.hour < 6 || h.hour >= 20),
                              size: 20,
                              color: wxColor(h.code)),
                          Text(_deg(h.temp),
                              style: TextStyle(
                                  fontSize: 13,
                                  fontWeight: FontWeight.w700,
                                  color: p.ink)),
                        ],
                      ),
                    );
                  },
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
// Ana ekran: tek satır hava durumu yazısı ("Şu an açık, 12°. Bugün yağmurlu.")
// Dokununca saatlik panel açılır / kapanır.
// ---------------------------------------------------------------
class WxLine extends StatelessWidget {
  final String date;
  final bool open;
  final VoidCallback onTap;
  const WxLine(
      {super.key, required this.date, required this.open, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([weather, store]),
      builder: (context, _) {
        if (!store.wxOn) return const SizedBox.shrink();
        final d = weather.data;
        IconData icon = Icons.cloud_queue_rounded;
        Color color = p.soft;
        String text;
        var warn = false;
        if (d == null) {
          if (weather.loading) {
            text = tx('Hava durumu alınıyor…');
          } else if (weather.failed) {
            text = tx('Hava durumu alınamadı. Dokun, yeniden dene.');
          } else {
            return const SizedBox.shrink();
          }
        } else {
          final day = d.days[date];
          final todayKey = _isToday(date);
          final tomKey = dKey(DateTime.now().add(const Duration(days: 1))) == date;
          if (todayKey) {
            final hr = DateTime.now().hour;
            int? code = d.nowCode ?? day?.code;
            if (code == null) return const SizedBox.shrink();
            icon = wxIcon(code, night: hr < 6 || hr >= 20);
            color = wxColor(code);
            text = _precipText(d, date, wxText(code));
          } else if (day != null) {
            icon = wxIcon(day.code);
            color = wxColor(day.code);
            final t = parseKey(date);
            final lbl = tomKey ? tx('Yarın') : '${t.day} ${monName(t.month)}';
            text = day.rain >= 0
                ? tx('{0}: {1}, {2} / {3}, yağış %{4}',
                    [lbl, wxText(day.code), _deg(day.tmax), _deg(day.tmin), day.rain])
                : tx('{0}: {1}, {2} / {3}',
                    [lbl, wxText(day.code), _deg(day.tmax), _deg(day.tmin)]);
          } else {
            return const SizedBox.shrink();
          }
          // Uyarı: hangi gün ve saatte olduğuyla birlikte (yarının uyarısı bugünküymüş gibi görünmesin)
          final line = (todayKey || tomKey)
              ? wxAlertLine(wxAlerts(d), todayKey ? 0 : 1)
              : '';
          warn = line.isNotEmpty;
          if (warn) text = '$text $line';
        }
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.line),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: () {
              if (d == null && weather.failed) {
                weather.ensure(force: true);
                return;
              }
              onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(icon, size: 18, color: color),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(text,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: p.ink)),
                  ),
                  if (warn)
                    const Padding(
                      padding: EdgeInsets.only(left: 6),
                      child: Icon(Icons.warning_amber_rounded,
                          size: 18, color: Color(0xFFE8883A)),
                    ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
