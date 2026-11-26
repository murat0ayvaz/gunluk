import 'dart:async';
import 'package:flutter/material.dart';
import 'data.dart';
import 'net.dart';
import 'notify.dart';
import 'media.dart' show slideFromRight;
import 'tools.dart' show NamazPage;
import 'strings.dart';
import 'theme.dart' show Pal;
import 'ui.dart';
import 'weather.dart';

// ---------------------------------------------------------------
// NAMAZ VAKİTLERİ (ana ekran, hava durumunun altında)
// Aladhan servisi, Diyanet hesaplama yöntemi (method=13).
// Konum: hava durumunda seçili yer (Konumum = telefonun konumu).
// Günde bir kez çekilir ve saklanır; internet yoksa bugünün saklı verisi kullanılır.
// ---------------------------------------------------------------

const prayerNames = ['İmsak', 'Güneş', 'Öğle', 'İkindi', 'Akşam', 'Yatsı'];
const _apiKeys = ['Fajr', 'Sunrise', 'Dhuhr', 'Asr', 'Maghrib', 'Isha'];

class PrayerCtl extends ChangeNotifier {
  bool loading = false;
  bool failed = false;
  List<String>? times; // 6 adet "HH:mm"

  String _dayKey(DateTime d) => '${d.year}-${d.month}-${d.day}';

  // Başka günler için (yarın vb.) saatler; bellekte tutulur
  final Map<String, List<String>> _dayCache = {};
  final Set<String> _dayLoading = {};
  final Map<String, DateTime> _dayFailAt = {};

  String _locKeyNow() {
    final sel = store.wxSel;
    final fav = (sel >= 0 && sel < store.wxFavs.length) ? store.wxFavs[sel] : null;
    return fav == null ? 'gps' : '${fav.lat},${fav.lon}';
  }

  bool _isToday(DateTime d) {
    final n = DateTime.now();
    return d.year == n.year && d.month == n.month && d.day == n.day;
  }

  /// Seçili günün vakitleri: bugün = günlük veri, diğer günler = o güne ait çekilmiş veri
  /// (yoksa null döner ve arka planda çekilir)
  List<String>? timesFor(DateTime d) {
    if (_isToday(d)) return times;
    final k = '${_dayKey(d)}|${_locKeyNow()}';
    final c = _dayCache[k];
    if (c == null) ensureDate(d);
    return c;
  }

  Future<void> ensureDate(DateTime d) async {
    if (!store.prayOn || _isToday(d)) return;
    final k = '${_dayKey(d)}|${_locKeyNow()}';
    if (_dayCache.containsKey(k) || _dayLoading.contains(k)) return;
    final fail = _dayFailAt[k];
    if (fail != null && DateTime.now().difference(fail).inSeconds < 60) return;
    _dayLoading.add(k);
    try {
      final sel = store.wxSel;
      final fav = (sel >= 0 && sel < store.wxFavs.length) ? store.wxFavs[sel] : null;
      final double lat;
      final double lon;
      if (fav != null) {
        lat = fav.lat;
        lon = fav.lon;
      } else {
        final pos = await weather.locate();
        if (pos == null) throw Exception('gpsoff');
        lat = pos.$1;
        lon = pos.$2;
      }
      final ds =
          '${d.day.toString().padLeft(2, '0')}-${d.month.toString().padLeft(2, '0')}-${d.year}';
      final j = await httpGetJson(Uri.parse(
          'https://api.aladhan.com/v1/timings/$ds?latitude=$lat&longitude=$lon&method=13'));
      final t = (j as Map)['data']['timings'] as Map;
      final out = <String>[];
      for (final key in _apiKeys) {
        final v = '${t[key]}'.trim();
        out.add(v.length >= 5 ? v.substring(0, 5) : v);
      }
      _dayCache[k] = out;
      _dayFailAt.remove(k);
    } catch (_) {
      _dayFailAt[k] = DateTime.now();
    }
    _dayLoading.remove(k);
    notifyListeners();
  }

  Future<void> ensure({bool force = false}) async {
    if (!store.prayOn) return;
    final today = _dayKey(DateTime.now());
    final c = store.prayCache;
    final sel = store.wxSel;
    final fav =
        (sel >= 0 && sel < store.wxFavs.length) ? store.wxFavs[sel] : null;
    final locKey = fav == null ? 'gps' : '${fav.lat},${fav.lon}';
    final cached = (c['t'] is List) ? [for (final x in c['t'] as List) '$x'] : null;
    final okCache = cached != null &&
        cached.length == 6 &&
        c['d'] == today &&
        c['k'] == locKey;
    if (okCache && !force) {
      final fresh = times == null;
      times = cached;
      failed = false;
      notifyListeners();
      if (fresh) Notifier.syncPrayer(cached);
      return;
    }
    if (loading) return;
    loading = true;
    failed = false;
    notifyListeners();
    try {
      final double lat;
      final double lon;
      if (fav != null) {
        lat = fav.lat;
        lon = fav.lon;
      } else {
        final pos = await weather.locate();
        if (pos == null) throw Exception('gpsoff');
        lat = pos.$1;
        lon = pos.$2;
      }
      final n = DateTime.now();
      final ds =
          '${n.day.toString().padLeft(2, '0')}-${n.month.toString().padLeft(2, '0')}-${n.year}';
      final j = await httpGetJson(Uri.parse(
          'https://api.aladhan.com/v1/timings/$ds?latitude=$lat&longitude=$lon&method=13'));
      final t = (j as Map)['data']['timings'] as Map;
      final out = <String>[];
      for (final k in _apiKeys) {
        final v = '${t[k]}'.trim();
        out.add(v.length >= 5 ? v.substring(0, 5) : v);
      }
      times = out;
      store.setPrayCache({'d': today, 'k': locKey, 't': out});
      Notifier.syncPrayer(out);
    } catch (_) {
      failed = true;
      // bugünün saklı verisi (konum farklı olsa da) yoksa boş kalır
      if (cached != null && cached.length == 6 && c['d'] == today) {
        times = cached;
        failed = false;
      }
    }
    loading = false;
    notifyListeners();
  }
}

final prayer = PrayerCtl();

/// Bildirim kurulumu için bugünün vakitleri (yoksa null)
List<String>? prayerTimesNow() => prayer.times;

int _mins(String hm) {
  final p = hm.split(':');
  if (p.length < 2) return -1;
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

class PrayerBar extends StatefulWidget {
  /// vertical: sol sütunda alt alta
  final bool vertical;
  final DateTime? day; // seçili gün (başka günse o günün vakitleri gösterilir)
  const PrayerBar({super.key, this.vertical = false, this.day});

  @override
  State<PrayerBar> createState() => _PrayerBarState();
}

class _PrayerBarState extends State<PrayerBar> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    prayer.ensure();
    _t = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      prayer.ensure(); // gün değiştiyse yeniler
      setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  Widget _cellW(Pal p, List<String> t, int i, int next) => Container(
        margin: const EdgeInsets.symmetric(horizontal: 2, vertical: 1),
        padding: const EdgeInsets.symmetric(vertical: 6),
        decoration: BoxDecoration(
          color: i == next ? p.accent.withOpacity(0.25) : null,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(tx(prayerNames[i]),
                maxLines: 1,
                style: TextStyle(
                    fontSize: 11.5,
                    color: p.soft,
                    fontWeight: i == next ? FontWeight.w800 : FontWeight.w500)),
            const SizedBox(height: 2),
            Text(t[i],
                style: TextStyle(
                    fontSize: 14,
                    color: p.ink,
                    fontWeight: i == next ? FontWeight.w800 : FontWeight.w600)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([prayer, store]),
      builder: (context, _) {
        if (!store.prayOn) return const SizedBox.shrink();
        final other = widget.day != null && !prayer._isToday(widget.day!);
        final t = other ? prayer.timesFor(widget.day!) : prayer.times;
        Widget inner;
        if (t == null) {
          inner = Padding(
            padding: const EdgeInsets.symmetric(vertical: 10),
            child: Center(
              child: prayer.loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : widget.vertical
                      ? IconButton(
                          visualDensity: VisualDensity.compact,
                          onPressed: () => prayer.ensure(force: true),
                          icon: const Icon(Icons.refresh_rounded))
                      : TextButton.icon(
                      onPressed: () => prayer.ensure(force: true),
                      icon: const Icon(Icons.refresh_rounded, size: 18),
                      label: Text(tx('Namaz vakitleri alınamadı. Dokun, yeniden dene.')),
                    ),
            ),
          );
        } else {
          final now = DateTime.now();
          final nm = now.hour * 60 + now.minute;
          var next = other ? -1 : 0; // hepsi geçtiyse yarının imsakı
          if (!other) {
            for (var i = 0; i < 6; i++) {
              if (_mins(t[i]) > nm) {
                next = i;
                break;
              }
            }
          }
          final cells = [
              for (var i = 0; i < 6; i++)
                _cellW(p, t, i, next),
          ];
          inner = widget.vertical
              ? Column(children: cells)
              : Row(children: [for (final c in cells) Expanded(child: c)]);
        }
        return GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: () => Navigator.of(context).push(slideFromRight(const NamazPage())),
          child: Container(
          width: widget.vertical ? 68 : null,
          margin: widget.vertical
              ? const EdgeInsets.fromLTRB(8, 0, 0, 10)
              : const EdgeInsets.fromLTRB(16, 0, 16, 10),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 4),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.line),
          ),
          child: inner,
        ));
      },
    );
  }
}


// ---------------------------------------------------------------
// Ana ekran: tek satır namaz yazısı ("Öğleye 20 dk kaldı.")
// Dokununca bugünün tüm vakitleri açılır.
// ---------------------------------------------------------------
const _dative = ['İmsaka', 'Güneşe', 'Öğleye', 'İkindiye', 'Akşama', 'Yatsıya'];

/// Bir sonraki vakte kalan süre metni ("İmsaka 6 sa 21 dk kaldı."); vakitler yoksa boş (ana ekran aracı için)
String prayerNextText() {
  final t = prayer.times;
  if (!store.prayOn || t == null || t.length < 6) return '';
  final now = DateTime.now();
  final nm = now.hour * 60 + now.minute;
  var next = -1;
  for (var i = 0; i < 6; i++) {
    if (_mins(t[i]) > nm) {
      next = i;
      break;
    }
  }
  int diff;
  if (next < 0) {
    next = 0;
    diff = 1440 - nm + _mins(t[0]);
  } else {
    diff = _mins(t[next]) - nm;
  }
  String left;
  if (diff >= 60) {
    final h = diff ~/ 60;
    final m = diff % 60;
    left = m == 0 ? tx('{0} sa', [h]) : tx('{0} sa {1} dk', [h, m]);
  } else {
    left = tx('{0} dk', [diff < 1 ? 1 : diff]);
  }
  return tx('{0} {1} kaldı.', [tx(_dative[next]), left]);
}

class PrayerLine extends StatefulWidget {
  final bool open;
  final DateTime day; // seçili gün
  final VoidCallback onTap;
  const PrayerLine(
      {super.key, required this.open, required this.day, required this.onTap});

  @override
  State<PrayerLine> createState() => _PrayerLineState();
}

class _PrayerLineState extends State<PrayerLine> {
  Timer? _t;

  @override
  void initState() {
    super.initState();
    prayer.ensure();
    _t = Timer.periodic(const Duration(minutes: 1), (_) {
      if (!mounted) return;
      prayer.ensure();
      setState(() {});
    });
  }

  @override
  void dispose() {
    _t?.cancel();
    super.dispose();
  }

  String _left(int diff) {
    if (diff >= 60) {
      final h = diff ~/ 60;
      final m = diff % 60;
      return m == 0 ? tx('{0} sa', [h]) : tx('{0} sa {1} dk', [h, m]);
    }
    return tx('{0} dk', [diff < 1 ? 1 : diff]);
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([prayer, store]),
      builder: (context, _) {
        if (!store.prayOn) return const SizedBox.shrink();
        final other = !prayer._isToday(widget.day);
        final t = other ? prayer.timesFor(widget.day) : prayer.times;
        String text;
        if (t == null) {
          text = (prayer.loading || other)
              ? tx('Namaz vakitleri alınıyor…')
              : tx('Namaz vakitleri alınamadı. Dokun, yeniden dene.');
        } else if (other) {
          final tom = DateTime.now().add(const Duration(days: 1));
          final dd = widget.day;
          final lbl = (dd.year == tom.year && dd.month == tom.month && dd.day == tom.day)
              ? tx('Yarın')
              : '${dd.day} ${monName(dd.month)}';
          text = tx('{0}: {1} {2} • {3} {4} • {5} {6}', [
            lbl,
            tx('İmsak'), t[0],
            tx('Öğle'), t[2],
            tx('Akşam'), t[4],
          ]);
        } else {
          final now = DateTime.now();
          final nm = now.hour * 60 + now.minute;
          var next = -1;
          for (var i = 0; i < 6; i++) {
            if (_mins(t[i]) > nm) {
              next = i;
              break;
            }
          }
          int diff;
          if (next < 0) {
            next = 0; // hepsi geçti: yarının imsakı
            diff = 1440 - nm + _mins(t[0]);
          } else {
            diff = _mins(t[next]) - nm;
          }
          text = tx('{0} {1} kaldı.', [tx(_dative[next]), _left(diff)]);
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
              if (t == null && !prayer.loading) {
                prayer.ensure(force: true);
                return;
              }
              widget.onTap();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.mosque_rounded, size: 18, color: p.accent),
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
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
