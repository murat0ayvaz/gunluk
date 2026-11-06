import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

// ---------------------------------------------------------------
// İNTERNET YARDIMCILARI (ek paket yok, dart:io ile)
// Radyo rehberi (Radio Browser), podcast arama (Apple iTunes) ve
// podcast RSS okuma buradan yapılır.
// ---------------------------------------------------------------

const _ua = 'DailyRoutine/1.13 (Android)';

/// Adresten metin indirir (zaman aşımı + boyut sınırı vardır)
Future<String> httpGetText(Uri uri,
    {int seconds = 15,
    int maxBytes = 6000000,
    Map<String, String>? headers,
    String? ua}) async {
  final c = HttpClient();
  c.connectionTimeout = Duration(seconds: seconds);
  c.userAgent = ua ?? _ua;
  try {
    final req = await c.getUrl(uri).timeout(Duration(seconds: seconds));
    req.headers.set('Accept', '*/*');
    headers?.forEach((k, v) => req.headers.set(k, v));
    final res = await req.close().timeout(Duration(seconds: seconds));
    if (res.statusCode >= 400) {
      throw HttpException('HTTP ${res.statusCode}');
    }
    final bytes = <int>[];
    await for (final chunk in res.timeout(Duration(seconds: seconds))) {
      bytes.addAll(chunk);
      if (bytes.length > maxBytes) break;
    }
    return utf8.decode(bytes, allowMalformed: true);
  } finally {
    c.close(force: true);
  }
}

Future<dynamic> httpGetJson(Uri uri,
        {Map<String, String>? headers, String? ua}) async =>
    jsonDecode(await httpGetText(uri, headers: headers, ua: ua));

// ---------- Radyo rehberi (Radio Browser) ----------

const _rbHosts = [
  'de1.api.radio-browser.info',
  'nl1.api.radio-browser.info',
  'at1.api.radio-browser.info',
];

/// Rehber sunucularından ilk cevap vereni kullanır
Future<dynamic> rbGet(String path, [Map<String, String>? query]) async {
  Object? last;
  for (final h in _rbHosts) {
    try {
      return await httpGetJson(Uri.https(h, path, query));
    } catch (e) {
      last = e;
    }
  }
  throw last ?? Exception('no host');
}

class RbStation {
  final String name;
  final String url;
  final String country;
  final String tags;
  final int bitrate;
  RbStation(this.name, this.url, this.country, this.tags, this.bitrate);
}

class RbCountry {
  final String code;
  final String name;
  final int count;
  RbCountry(this.code, this.name, this.count);
}

/// Ülke listesi (bir kez indirilir, sonra bellekte tutulur)
List<RbCountry>? _countryCache;
Future<List<RbCountry>> rbCountries() async {
  final cached = _countryCache;
  if (cached != null) return cached;
  final data = await rbGet('/json/countries', {'order': 'name'});
  final out = <RbCountry>[];
  for (final e in (data as List)) {
    final m = e as Map;
    final code = (m['iso_3166_1'] ?? '').toString();
    final name = (m['name'] ?? '').toString();
    final n = (m['stationcount'] is num) ? (m['stationcount'] as num).toInt() : 0;
    if (code.isEmpty || name.isEmpty || n <= 0) continue;
    out.add(RbCountry(code, name, n));
  }
  _countryCache = out;
  return out;
}

/// Radyo ara: ad / ülke kodu / tür ile; en çok oy alandan başlar
Future<List<RbStation>> rbSearch(
    {String name = '',
    String country = '',
    String tag = '',
    int offset = 0,
    int limit = 30}) async {
  final q = <String, String>{
    'limit': '$limit',
    'offset': '$offset',
    'order': 'votes',
    'reverse': 'true',
    'hidebroken': 'true',
  };
  if (name.trim().isNotEmpty) q['name'] = name.trim();
  if (country.isNotEmpty) q['countrycode'] = country;
  if (tag.isNotEmpty) {
    q['tag'] = tag;
    q['tagExact'] = 'true';
  }
  final data = await rbGet('/json/stations/search', q);
  final out = <RbStation>[];
  for (final e in (data as List)) {
    final m = e as Map;
    var url = (m['url_resolved'] ?? '').toString().trim();
    if (url.isEmpty) url = (m['url'] ?? '').toString().trim();
    final nm = (m['name'] ?? '').toString().trim();
    if (url.isEmpty || nm.isEmpty) continue;
    final tags = (m['tags'] ?? '').toString().split(',').where((x) => x.trim().isNotEmpty).take(2).join(', ');
    final br = (m['bitrate'] is num) ? (m['bitrate'] as num).toInt() : 0;
    out.add(RbStation(nm, url, (m['country'] ?? '').toString(), tags, br));
  }
  return out;
}

// ---------- Podcast arama (Apple iTunes) ----------

class PodResult {
  final String title;
  final String author;
  final String feed;
  final String art;
  PodResult(this.title, this.author, this.feed, this.art);
}

Future<List<PodResult>> podSearch(String term, {bool turkey = true}) async {
  final q = <String, String>{
    'media': 'podcast',
    'entity': 'podcast',
    'term': term.trim(),
    'limit': '25',
  };
  if (turkey) q['country'] = 'TR';
  final data = await httpGetJson(Uri.https('itunes.apple.com', '/search', q));
  final out = <PodResult>[];
  final list = (data is Map ? data['results'] : null) as List? ?? [];
  for (final e in list) {
    final m = e as Map;
    final feed = (m['feedUrl'] ?? '').toString();
    final title = (m['collectionName'] ?? '').toString();
    if (feed.isEmpty || title.isEmpty) continue;
    out.add(PodResult(title, (m['artistName'] ?? '').toString(), feed,
        (m['artworkUrl100'] ?? '').toString()));
  }
  return out;
}

// ---------- Podcast RSS ----------

class Episode {
  final String key; // kayıt anahtarı: podcastId|ses adresi
  final String title;
  final String url;
  final String date;
  final String dur;
  Episode(this.key, this.title, this.url, this.date, this.dur);
}

String _decode(String s) {
  var t = s;
  t = t.replaceAll('<![CDATA[', '').replaceAll(']]>', '');
  t = t.replaceAll(RegExp(r'<[^>]*>'), '');
  t = t.replaceAllMapped(RegExp(r'&#(\d+);'), (m) {
    final n = int.tryParse(m.group(1)!);
    return n == null ? '' : String.fromCharCode(n);
  });
  t = t
      .replaceAll('&amp;', '&')
      .replaceAll('&lt;', '<')
      .replaceAll('&gt;', '>')
      .replaceAll('&quot;', '"')
      .replaceAll('&apos;', "'")
      .replaceAll('&nbsp;', ' ');
  return t.trim();
}

String _tag(String s, String name) {
  final m = RegExp('<$name(?:\\s[^>]*)?>(.*?)</$name>', dotAll: true)
      .firstMatch(s);
  return m == null ? '' : _decode(m.group(1)!);
}

String _shortDate(String d) {
  final p = d.split(' ');
  final i = (p.isNotEmpty && p[0].endsWith(',')) ? 1 : 0;
  if (p.length >= i + 3) return '${p[i]} ${p[i + 1]} ${p[i + 2]}';
  return d;
}

String _durText(String d) {
  if (d.isEmpty) return '';
  if (d.contains(':')) return d;
  final n = int.tryParse(d);
  if (n == null) return d;
  final h = n ~/ 3600;
  final m = (n % 3600) ~/ 60;
  final s = n % 60;
  final mm = m.toString().padLeft(2, '0');
  final ss = s.toString().padLeft(2, '0');
  return h > 0 ? '$h:$mm:$ss' : '$m:$ss';
}

/// Podcast RSS'inden bölümleri okur (en yeni en üstte, en çok 150)
Future<List<Episode>> fetchEpisodes(String podId, String feed) async {
  final xml = await httpGetText(Uri.parse(feed), maxBytes: 8000000);
  final out = <Episode>[];
  final items = RegExp(r'<item[\s>].*?</item>', dotAll: true).allMatches(xml);
  for (final m in items) {
    if (out.length >= 150) break;
    final s = m.group(0)!;
    final enc = RegExp(r'''<enclosure\b[^>]*?\burl\s*=\s*["']([^"']+)["']''',
            caseSensitive: false)
        .firstMatch(s);
    if (enc == null) continue;
    final url = _decode(enc.group(1)!);
    if (url.isEmpty) continue;
    var title = _tag(s, 'title');
    if (title.isEmpty) title = url;
    out.add(Episode('$podId|$url', title, url,
        _shortDate(_tag(s, 'pubDate')), _durText(_tag(s, 'itunes:duration'))));
  }
  return out;
}

// ---------- Haber (RSS / Atom) ----------

class NewsItem {
  final String title;
  final String summary;
  final String link;
  final String date;
  NewsItem(this.title, this.summary, this.link, this.date);
}

/// RSS (item) veya Atom (entry) akışından en çok [max] haber okur
Future<List<NewsItem>> fetchNews(String url, {int max = 25}) async {
  final xml = await httpGetText(Uri.parse(url), maxBytes: 4000000);
  final out = <NewsItem>[];
  final blocks = RegExp(r'<(item|entry)[\s>].*?</\1>', dotAll: true)
      .allMatches(xml);
  for (final m in blocks) {
    if (out.length >= max) break;
    final s = m.group(0)!;
    final title = _tag(s, 'title');
    if (title.isEmpty) continue;
    var sum = _tag(s, 'description');
    if (sum.isEmpty) sum = _tag(s, 'summary');
    if (sum.isEmpty) sum = _tag(s, 'content');
    sum = sum.replaceAll(RegExp(r'<[^>]*>'), ' ');
    sum = sum.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (sum.length > 400) sum = '${sum.substring(0, 400).trim()}...';
    var link = _tag(s, 'link');
    if (link.isEmpty) {
      final a = RegExp(r'''<link\b[^>]*?\bhref\s*=\s*["']([^"']+)["']''')
          .firstMatch(s);
      if (a != null) link = _decode(a.group(1)!);
    }
    var date = _tag(s, 'pubDate');
    if (date.isEmpty) date = _tag(s, 'dc:date');
    if (date.isEmpty) date = _tag(s, 'updated');
    out.add(NewsItem(title, sum, link, date.isEmpty ? '' : _shortDate(date)));
  }
  return out;
}

// ---------- Hava durumu (Open-Meteo, ücretsiz, anahtarsız) ----------

class GeoCity {
  final String name;
  final String region;
  final String country;
  final double lat;
  final double lon;
  GeoCity(this.name, this.region, this.country, this.lat, this.lon);

  String get label =>
      [name, region, country].where((x) => x.trim().isNotEmpty).join(', ');
}

/// Şehir adıyla arama (ör. "Ankara")
Future<List<GeoCity>> geoSearch(String q, String lang) async {
  final data = await httpGetJson(Uri.https(
      'geocoding-api.open-meteo.com', '/v1/search', {
    'name': q.trim(),
    'count': '8',
    'language': lang,
    'format': 'json',
  }));
  final list = (data is Map ? data['results'] : null) as List? ?? [];
  final out = <GeoCity>[];
  for (final e in list) {
    final m = e as Map;
    final lat = m['latitude'];
    final lon = m['longitude'];
    final name = (m['name'] ?? '').toString();
    if (lat is! num || lon is! num || name.isEmpty) continue;
    out.add(GeoCity(name, (m['admin1'] ?? '').toString(),
        (m['country'] ?? '').toString(), lat.toDouble(), lon.toDouble()));
  }
  return out;
}

class HourW {
  final int hour;
  final double temp;
  final int code;
  final int rain; // yağış ihtimali (%), bilinmiyorsa -1
  final double mm; // yağış miktarı (mm), bilinmiyorsa -1
  HourW(this.hour, this.temp, this.code, {this.rain = -1, this.mm = -1});
}

class DayW {
  final int code;
  final double tmax;
  final double tmin;
  final int rain; // %, bilinmiyorsa -1
  DayW(this.code, this.tmax, this.tmin, {this.rain = -1});
}

class WeatherData {
  final Map<String, DayW> days; // yyyy-MM-dd -> günlük özet
  final Map<String, List<HourW>> hours; // yyyy-MM-dd -> saatlik
  final double? nowTemp;
  final int? nowCode;
  WeatherData(this.days, this.hours, this.nowTemp, this.nowCode);
}

/// Hava servisleri: [anahtar, görünen ad]
const wxProviders = <List<String>>[
  ['om', 'Open-Meteo'],
  ['ecmwf', 'Open-Meteo • ECMWF'],
  ['icon', 'Open-Meteo • DWD ICON'],
  ['gfs', 'Open-Meteo • NOAA GFS'],
  ['met', 'MET Norway'],
  ['mgm', 'MGM (Meteoroloji Genel Müdürlüğü)'],
  ['owm', 'OpenWeatherMap'],
];

String wxProviderName(String key) {
  for (final p in wxProviders) {
    if (p[0] == key) return p[1];
  }
  return wxProviders.first[1];
}

double? _d(dynamic x) => x is num ? x.toDouble() : null;
int _i(dynamic x) => x is num ? x.round() : 0;
int _pct(dynamic x) => x is num ? x.round() : -1;
String _two(int n) => n.toString().padLeft(2, '0');
String _dk(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

/// Hava servisi hatası: hangi adımda ve neden düştüğünü taşır
class WxError implements Exception {
  final String provider;
  final String step;
  final String detail;
  WxError(this.provider, this.step, this.detail);
  @override
  String toString() => '$provider|$step|$detail';
}

/// Bir adımı çalıştırır; hata olursa hangi adım olduğu bilgisiyle fırlatır
Future<T> _wxStep<T>(String prov, String step, Future<T> Function() f) async {
  try {
    return await f();
  } on WxError {
    rethrow;
  } on HttpException catch (e) {
    throw WxError(prov, step, e.message);
  } on FormatException {
    throw WxError(prov, step, 'biçim');
  } on TypeError {
    throw WxError(prov, step, 'biçim');
  } catch (e) {
    final t = e.toString();
    throw WxError(prov, step, t.length > 60 ? t.substring(0, 60) : t);
  }
}

/// Seçilen servisten hava durumunu getirir (hepsi aynı biçimde döner)
Future<WeatherData> fetchWeatherFor(
    String prov, double lat, double lon, String owmKey,
    {String place = ''}) {
  return _wxStep(prov, 'veri', () => _fetchRaw(prov, lat, lon, owmKey, place));
}

Future<WeatherData> _fetchRaw(
    String prov, double lat, double lon, String owmKey, String place) {
  switch (prov) {
    case 'ecmwf':
      return _fetchOm(lat, lon, 'ecmwf_ifs025');
    case 'icon':
      return _fetchOm(lat, lon, 'icon_seamless');
    case 'gfs':
      return _fetchOm(lat, lon, 'gfs_seamless');
    case 'met':
      return _fetchMet(lat, lon);
    case 'mgm':
      return _fetchMgm(lat, lon, place);
    case 'owm':
      return _fetchOwm(lat, lon, owmKey);
    default:
      return _fetchOm(lat, lon, '');
  }
}

/// Günlük özetleri saatlikten türetir (servis günlük vermiyorsa)
Map<String, DayW> _daysFromHours(Map<String, List<HourW>> hours) {
  final out = <String, DayW>{};
  hours.forEach((k, list) {
    if (list.isEmpty) return;
    var hi = list.first.temp;
    var lo = list.first.temp;
    var rain = -1;
    HourW noon = list.first;
    for (final h in list) {
      if (h.temp > hi) hi = h.temp;
      if (h.temp < lo) lo = h.temp;
      if (h.rain > rain) rain = h.rain;
      if ((h.hour - 12).abs() < (noon.hour - 12).abs()) noon = h;
    }
    out[k] = DayW(noon.code, hi, lo, rain: rain);
  });
  return out;
}

// ---------- Open-Meteo (ve modelleri) ----------
Future<WeatherData> _fetchOm(double lat, double lon, String model) async {
  final q = <String, String>{
    'latitude': lat.toStringAsFixed(4),
    'longitude': lon.toStringAsFixed(4),
    'current': 'temperature_2m,weather_code',
    'hourly': 'temperature_2m,weather_code,precipitation_probability',
    'daily':
        'weather_code,temperature_2m_max,temperature_2m_min,precipitation_probability_max',
    'timezone': 'auto',
    'past_days': '7',
    'forecast_days': '16',
  };
  if (model.isNotEmpty) q['models'] = model;
  final j = await httpGetJson(Uri.https('api.open-meteo.com', '/v1/forecast', q));
  final m = j as Map;

  final days = <String, DayW>{};
  final d = m['daily'] as Map?;
  if (d != null) {
    final t = (d['time'] as List?) ?? [];
    final code = (d['weather_code'] as List?) ?? [];
    final mx = (d['temperature_2m_max'] as List?) ?? [];
    final mn = (d['temperature_2m_min'] as List?) ?? [];
    final pr = (d['precipitation_probability_max'] as List?) ?? [];
    for (var i = 0; i < t.length; i++) {
      final hi = i < mx.length ? _d(mx[i]) : null;
      final lo = i < mn.length ? _d(mn[i]) : null;
      if (hi == null || lo == null) continue;
      days[t[i].toString()] = DayW(i < code.length ? _i(code[i]) : 0, hi, lo,
          rain: i < pr.length ? _pct(pr[i]) : -1);
    }
  }

  final hours = <String, List<HourW>>{};
  final h = m['hourly'] as Map?;
  if (h != null) {
    final t = (h['time'] as List?) ?? [];
    final temp = (h['temperature_2m'] as List?) ?? [];
    final code = (h['weather_code'] as List?) ?? [];
    final pr = (h['precipitation_probability'] as List?) ?? [];
    for (var i = 0; i < t.length; i++) {
      final s = t[i].toString(); // 2026-11-04T14:00
      if (s.length < 13) continue;
      final tv = i < temp.length ? _d(temp[i]) : null;
      if (tv == null) continue;
      final hr = int.tryParse(s.substring(11, 13)) ?? 0;
      (hours[s.substring(0, 10)] ??= []).add(HourW(
          hr, tv, i < code.length ? _i(code[i]) : 0,
          rain: i < pr.length ? _pct(pr[i]) : -1));
    }
  }
  if (days.isEmpty && hours.isEmpty) throw Exception('empty');

  final c = m['current'] as Map?;
  return WeatherData(days, hours, c == null ? null : _d(c['temperature_2m']),
      c == null || c['weather_code'] is! num ? null : _i(c['weather_code']));
}

// ---------- MET Norway ----------
int _metCode(String s) {
  final b = s.split('_').first;
  if (b.contains('thunder')) return 95;
  if (b.contains('snow')) {
    return b.startsWith('heavy') ? 75 : (b.startsWith('light') ? 71 : 73);
  }
  if (b.contains('sleet')) return 67;
  if (b.contains('rain')) {
    return b.startsWith('heavy') ? 65 : (b.startsWith('light') ? 61 : 63);
  }
  if (b == 'fog') return 45;
  if (b == 'clearsky') return 0;
  if (b == 'fair') return 1;
  if (b == 'partlycloudy') return 2;
  return 3;
}

Future<WeatherData> _fetchMet(double lat, double lon) async {
  final j = await httpGetJson(
      Uri.https('api.met.no', '/weatherapi/locationforecast/2.0/compact', {
        'lat': lat.toStringAsFixed(4),
        'lon': lon.toStringAsFixed(4),
      }),
      ua: 'DailyRoutine/1.15 github.com/murat0ayvaz/gunluk');
  final ts = (((j as Map)['properties'] as Map?)?['timeseries'] as List?) ?? [];
  final hours = <String, List<HourW>>{};
  double? nowT;
  int? nowC;
  for (final e in ts) {
    final m = e as Map;
    final t = DateTime.tryParse((m['time'] ?? '').toString());
    final data = m['data'] as Map?;
    if (t == null || data == null) continue;
    final inst = (data['instant'] as Map?)?['details'] as Map?;
    final temp = _d(inst?['air_temperature']);
    if (temp == null) continue;
    final n1 = data['next_1_hours'] as Map?;
    final nx = n1 ?? (data['next_6_hours'] as Map?);
    final sym = ((nx?['summary'] as Map?)?['symbol_code'] ?? '').toString();
    final code = sym.isEmpty ? 3 : _metCode(sym);
    final lt = t.toLocal();
    nowT ??= temp;
    nowC ??= code;
    final mm = n1 == null
        ? -1.0
        : (_d((n1['details'] as Map?)?['precipitation_amount']) ?? -1.0);
    (hours[_dk(lt)] ??= []).add(HourW(lt.hour, temp, code, mm: mm));
  }
  if (hours.isEmpty) throw Exception('empty');
  return WeatherData(_daysFromHours(hours), hours, nowT, nowC);
}

// ---------- OpenWeatherMap (kullanıcının kendi ücretsiz anahtarı) ----------
int _owmCode(int id) {
  if (id >= 200 && id < 300) return 95;
  if (id >= 300 && id < 400) return 51;
  if (id == 500) return 61;
  if (id == 501) return 63;
  if (id >= 502 && id <= 504) return 65;
  if (id == 511) return 67;
  if (id >= 520 && id <= 531) return 80;
  if (id >= 611 && id <= 616) return 67;
  if (id == 600 || id == 620) return 71;
  if (id == 601 || id == 621) return 73;
  if (id == 602 || id == 622) return 75;
  if (id >= 700 && id < 800) return 45;
  if (id == 800) return 0;
  if (id == 801) return 1;
  if (id == 802) return 2;
  return 3;
}

Future<WeatherData> _fetchOwm(double lat, double lon, String key) async {
  if (key.trim().isEmpty) throw WxError('owm', 'anahtar', 'yok');
  final q = <String, String>{
    'lat': lat.toStringAsFixed(4),
    'lon': lon.toStringAsFixed(4),
    'units': 'metric',
    'appid': key.trim(),
  };
  final f = await _wxStep(
      'owm',
      'tahmin',
      () async => await httpGetJson(
          Uri.https('api.openweathermap.org', '/data/2.5/forecast', q))
          as Map);
  final tz = (f['city'] as Map?)?['timezone'];
  final off = tz is num ? tz.toInt() : 0;
  final list = (f['list'] as List?) ?? [];
  final hours = <String, List<HourW>>{};
  for (final e in list) {
    final m = e as Map;
    final dt = m['dt'];
    final temp = _d((m['main'] as Map?)?['temp']);
    if (dt is! num || temp == null) continue;
    final lt = DateTime.fromMillisecondsSinceEpoch(dt.toInt() * 1000,
            isUtc: true)
        .add(Duration(seconds: off));
    final w = (m['weather'] as List?) ?? [];
    final id = w.isNotEmpty ? _i((w.first as Map)['id']) : 800;
    final pop = _d(m['pop']);
    final mm = _d((m['rain'] as Map?)?['3h']) ?? -1.0;
    (hours[_dk(lt)] ??= []).add(HourW(lt.hour, temp, _owmCode(id),
        rain: pop == null ? -1 : (pop * 100).round(), mm: mm));
  }
  if (hours.isEmpty) throw WxError('owm', 'tahmin', 'boş');

  double? nowT;
  int? nowC;
  try {
    final c = await httpGetJson(
        Uri.https('api.openweathermap.org', '/data/2.5/weather', q)) as Map;
    nowT = _d((c['main'] as Map?)?['temp']);
    final w = (c['weather'] as List?) ?? [];
    if (w.isNotEmpty) nowC = _owmCode(_i((w.first as Map)['id']));
  } catch (_) {}
  if (nowT == null) {
    final first = hours.values.first.first;
    nowT = first.temp;
    nowC = first.code;
  }
  return WeatherData(_daysFromHours(hours), hours, nowT, nowC);
}

// ---------- MGM (resmi olmayan erişim; biçim doğrulanamadı) ----------
const _mgmHeaders = <String, String>{
  'Origin': 'https://mgm.gov.tr',
  'Referer': 'https://mgm.gov.tr/',
  'Accept': 'application/json, text/plain, */*',
  'Accept-Language': 'tr-TR,tr;q=0.9',
};
const _mgmUa =
    'Mozilla/5.0 (Windows NT 10.0; Win64; x64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/156.0.0.0 Safari/537.36';

int _mgmCode(String h) {
  final s = h.toUpperCase().trim().split(RegExp(r'[^A-Z]')).first;
  switch (s) {
    case 'A':
      return 0;
    case 'AB':
      return 1;
    case 'PB':
      return 2;
    case 'CB':
      return 3;
    case 'HY':
      return 61;
    case 'Y':
      return 63;
    case 'KY':
      return 65;
    case 'KKY':
      return 67;
    case 'HKY':
      return 71;
    case 'K':
      return 73;
    case 'YK':
      return 75;
    case 'HSY':
    case 'MSY':
      return 80;
    case 'SY':
      return 81;
    case 'KSY':
      return 82;
    case 'GSY':
      return 95;
    case 'DY':
      return 96;
    case 'S':
      return 45;
    case 'R':
      return 1;
    default:
      return 3;
  }
}

/// MGM isteği (tarayıcıdaki gibi Origin/Referer ile). Hata olursa adresi de yazar
Future<dynamic> _mgmGet(String path, Map<String, String> q) async {
  try {
    return await httpGetJson(Uri.https('servis.mgm.gov.tr', path, q),
        headers: _mgmHeaders, ua: _mgmUa);
  } on HttpException catch (e) {
    throw HttpException('${e.message} $path');
  }
}

String _cleanPlace(String s) => s
    .replaceAll(RegExp(r'\s+(Province|Ili|İli|District|Merkez)$'), '')
    .trim();

/// Koordinattan (ya da elle seçilen şehir adından) il/ilçe adlarını çıkarır
Future<List<String>> _mgmNames(double lat, double lon, String place) async {
  final out = <String>[];
  void add(dynamic x) {
    if (x is! String) return;
    final t = _cleanPlace(x);
    if (t.length >= 2 && !out.contains(t)) out.add(t);
  }

  if (place.isNotEmpty) {
    for (final part in place.split(RegExp(r'[,/;]'))) {
      add(part);
    }
    return out;
  }
  try {
    final j = await httpGetJson(
        Uri.https('api.bigdatacloud.net', '/data/reverse-geocode-client', {
      'latitude': lat.toStringAsFixed(5),
      'longitude': lon.toStringAsFixed(5),
      'localityLanguage': 'tr',
    }));
    if (j is Map) {
      add(j['locality']);
      add(j['city']);
      add(j['principalSubdivision']);
    }
  } catch (_) {}
  if (out.isEmpty) {
    try {
      final j = await httpGetJson(
          Uri.https('nominatim.openstreetmap.org', '/reverse', {
            'format': 'jsonv2',
            'lat': lat.toStringAsFixed(5),
            'lon': lon.toStringAsFixed(5),
            'zoom': '12',
            'accept-language': 'tr',
          }),
          ua: 'DailyRoutine/1.20 (Android)');
      final a = j is Map ? j['address'] : null;
      if (a is Map) {
        add(a['town']);
        add(a['city_district']);
        add(a['county']);
        add(a['city']);
        add(a['province']);
        add(a['state']);
      }
    } catch (_) {}
  }
  if (out.isEmpty) throw WxError('mgm', 'konum', 'ilçe adı bulunamadı');
  return out;
}

double _kmBetween(double la1, double lo1, double la2, double lo2) {
  final dy = (la2 - la1) * 111.2;
  final dx = (lo2 - lo1) * 111.2 * math.cos(la1 * math.pi / 180);
  return math.sqrt(dx * dx + dy * dy);
}

/// MGM istasyonlarını ada göre arar, koordinata en yakın olanı seçer
Future<Map> _mgmStation(double lat, double lon, String place) async {
  final names = await _mgmNames(lat, lon, place);
  final cands = <Map>[];
  final seen = <dynamic>{};
  void take(dynamic j) {
    if (j is! List) return;
    for (final e in j) {
      if (e is! Map) continue;
      if (e['enlem'] is! num || e['boylam'] is! num) continue;
      if (!seen.add(e['merkezId'] ?? '${e['il']}${e['ilce']}')) continue;
      cands.add(e);
    }
  }

  Object? err;
  for (final n in names) {
    try {
      take(await _mgmGet('/web/merkezler', {'sorgu': n, 'limit': '50'}));
    } catch (e) {
      err = e;
    }
  }
  if (cands.isEmpty) {
    for (final n in names) {
      try {
        take(await _mgmGet('/web/merkezler', {'il': n}));
      } catch (e) {
        err = e;
      }
    }
  }
  if (cands.isEmpty) {
    if (err != null) throw err;
    throw WxError('mgm', 'konum', 'istasyon yok: ${names.join(', ')}');
  }
  Map best = cands.first;
  var bestD = double.infinity;
  for (final c in cands) {
    final d = _kmBetween(
        lat, lon, (c['enlem'] as num).toDouble(), (c['boylam'] as num).toDouble());
    if (d < bestD) {
      bestD = d;
      best = c;
    }
  }
  if (bestD > 120) {
    throw WxError('mgm', 'konum', 'en yakın istasyon ${bestD.round()} km uzakta');
  }
  return best;
}

Map? _first(dynamic j) =>
    j is List ? (j.isEmpty ? null : j.first as Map) : (j is Map ? j : null);

Future<WeatherData> _fetchMgm(double lat, double lon, String place) async {
  final c = await _wxStep('mgm', 'konum', () => _mgmStation(lat, lon, place));
  final mid = c['merkezId'];
  final hIst = c['saatlikTahminIstNo'] ?? mid;
  final gIst = c['gunlukTahminIstNo'] ?? mid;

  // Saatlik tahmin (MGM 3 saatlik verir; olduğu gibi gösterilir)
  final hours = <String, List<HourW>>{};
  final hj = await _wxStep('mgm', 'saatlik',
      () => _mgmGet('/web/tahminler/saatlik', {'istno': '$hIst'}));
  final tahmin = (_first(hj)?['tahmin'] as List?) ?? [];
  for (final e in tahmin) {
    final m = e as Map;
    final t = DateTime.tryParse((m['tarih'] ?? '').toString());
    final temp = _d(m['sicaklik']);
    if (t == null || temp == null) continue;
    final lt = t.toLocal();
    (hours[_dk(lt)] ??= [])
        .add(HourW(lt.hour, temp, _mgmCode((m['hadise'] ?? '').toString())));
  }
  final days = _daysFromHours(hours);

  // Günlük tahmin: saatlikten türetilenin üzerine yazılır
  try {
    final g = _first(await _mgmGet('/web/tahminler/gunluk', {'istno': '$gIst'}));
    if (g != null) {
      final today = DateTime.now();
      for (var n = 1; n <= 5; n++) {
        final hi = _d(g['enYuksekGun$n']);
        final lo = _d(g['enDusukGun$n']);
        if (hi == null || lo == null) continue;
        final raw = (g['tarihGun$n'] ?? '').toString();
        final key = raw.length >= 10
            ? raw.substring(0, 10)
            : _dk(DateTime(today.year, today.month, today.day + n - 1));
        days[key] = DayW(_mgmCode((g['hadiseGun$n'] ?? '').toString()), hi, lo);
      }
    }
  } catch (_) {}

  // Şimdiki durum: son ölçüm, yoksa en yakın saatlik değer
  double? nowT;
  int? nowC;
  try {
    final s = _first(await _mgmGet('/web/sondurumlar', {'merkezid': '$mid'}));
    final t = _d(s?['sicaklik']);
    if (t != null && t > -90) {
      nowT = t;
      nowC = _mgmCode((s?['hadise'] ?? '').toString());
    }
  } catch (_) {}
  if (nowT == null) {
    final today = hours[_dk(DateTime.now())];
    if (today != null && today.isNotEmpty) {
      final hr = DateTime.now().hour;
      var best = today.first;
      for (final h in today) {
        if ((h.hour - hr).abs() < (best.hour - hr).abs()) best = h;
      }
      nowT = best.temp;
      nowC = best.code;
    }
  }
  if (days.isEmpty && hours.isEmpty) throw WxError('mgm', 'veri', 'boş');
  return WeatherData(days, hours, nowT, nowC);
}
