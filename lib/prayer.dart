import 'dart:async';
import 'package:flutter/material.dart';
import 'data.dart';
import 'net.dart';
import 'strings.dart';
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
      times = cached;
      failed = false;
      notifyListeners();
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

int _mins(String hm) {
  final p = hm.split(':');
  if (p.length < 2) return -1;
  return (int.tryParse(p[0]) ?? 0) * 60 + (int.tryParse(p[1]) ?? 0);
}

class PrayerBar extends StatefulWidget {
  const PrayerBar({super.key});

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

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([prayer, store]),
      builder: (context, _) {
        if (!store.prayOn) return const SizedBox.shrink();
        final t = prayer.times;
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
          var next = 0; // hepsi geçtiyse yarının imsakı
          for (var i = 0; i < 6; i++) {
            if (_mins(t[i]) > nm) {
              next = i;
              break;
            }
          }
          inner = Row(
            children: [
              for (var i = 0; i < 6; i++)
                Expanded(
                  child: Container(
                    margin: const EdgeInsets.symmetric(horizontal: 2),
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
                                fontWeight: i == next
                                    ? FontWeight.w800
                                    : FontWeight.w500)),
                        const SizedBox(height: 2),
                        Text(t[i],
                            style: TextStyle(
                                fontSize: 14,
                                color: p.ink,
                                fontWeight: i == next
                                    ? FontWeight.w800
                                    : FontWeight.w600)),
                      ],
                    ),
                  ),
                ),
            ],
          );
        }
        return Container(
          margin: const EdgeInsets.fromLTRB(12, 0, 12, 4),
          padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.line),
          ),
          child: inner,
        );
      },
    );
  }
}
