import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import 'data.dart';
import 'net.dart';
import 'strings.dart';
import 'ui.dart';

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
    if (!store.wxGps && (store.wxLat == null || store.wxLon == null)) return;
    final key0 =
        '${store.wxProvider}|${store.wxGps ? 'gps' : '${store.wxLat},${store.wxLon}'}';
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
      double? lat = store.wxLat;
      double? lon = store.wxLon;
      if (store.wxGps) {
        final pos = await _locate();
        lat = pos.latitude;
        lon = pos.longitude;
        store.setWxPos(lat, lon);
      }
      final d = await fetchWeatherFor(
          store.wxProvider, lat!, lon!, store.wxOwmKey,
          place: store.wxGps ? '' : store.wxCity);
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

bool _isToday(String date) => date == dKey(DateTime.now());

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
                Icon(
                    open
                        ? Icons.expand_less_rounded
                        : Icons.expand_more_rounded,
                    size: 16,
                    color: p.soft),
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
    // Bugünde şimdiki saate, diğer günlerde sabah 6'ya yakın başla
    final hr = _isToday(widget.date) ? DateTime.now().hour - 1 : 6;
    _sc = ScrollController(
        initialScrollOffset: (hr < 0 ? 0 : hr) * _cell);
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
        final hours = d?.hours[widget.date];
        if (d == null || hours == null || hours.isEmpty) {
          return const SizedBox.shrink();
        }
        final day = d.days[widget.date];
        final nowHr = DateTime.now().hour;
        final today = _isToday(widget.date);
        return Container(
          decoration: BoxDecoration(
            color: p.card,
            border: Border(bottom: BorderSide(color: p.line)),
          ),
          padding: const EdgeInsets.only(top: 8, bottom: 8),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
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
                  itemCount: hours.length,
                  itemBuilder: (context, i) {
                    final h = hours[i];
                    final isNow = today && h.hour == nowHr;
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
                          Text('${h.hour.toString().padLeft(2, '0')}:00',
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
        );
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
