import 'dart:math' show ceil;
import 'package:flutter/material.dart';
import 'ambient.dart';
import 'data.dart';
import 'notify.dart';
import 'strings.dart';
import 'theme.dart';

// ---------------------------------------------------------------
// ÖNEMLİ GÜNLER: milli günler + dini günler (bayram, kandil...).
// Bildirim: 1 hafta önce ("1 hafta sonra Cumhuriyet Bayramı") ve gününde ("Bugün Cumhuriyet Bayramı").
// Dini günler: 2026-2027 Diyanet takviminden; sonraki yıllar hicri takvim hesabıyla (tahmini, ±1 gün).
// Ayarlar (prof): 'hol_on' (bildirimler, varsayılan açık), 'hol_dini', 'hol_milli' (varsayılan açık).
// ---------------------------------------------------------------

class Holiday {
  final DateTime date; // yalnız tarih (saat 00:00)
  final String name; // Türkçe ad (tx ile çevrilir)
  final bool religious;
  final bool approx; // hesapla bulundu (Diyanet tablosunda yok)
  const Holiday(this.date, this.name, this.religious, {this.approx = false});
}

DateTime _d(int y, int m, int d) => DateTime(y, m, d);

// Diyanet 2026-2027 dinî günler (kaynak: Diyanet İşleri Başkanlığı takvimi)
final List<Holiday> _diyanet = [
  Holiday(_d(2026, 3, 19), 'Ramazan Bayramı Arifesi', true),
  Holiday(_d(2026, 3, 20), 'Ramazan Bayramı', true),
  Holiday(_d(2026, 5, 26), 'Kurban Bayramı Arifesi', true),
  Holiday(_d(2026, 5, 27), 'Kurban Bayramı', true),
  Holiday(_d(2026, 6, 16), 'Hicri Yılbaşı', true),
  Holiday(_d(2026, 6, 25), 'Aşure Günü', true),
  Holiday(_d(2026, 8, 24), 'Mevlid Kandili', true),
  Holiday(_d(2026, 12, 10), 'Regaip Kandili', true),
  Holiday(_d(2027, 1, 4), 'Miraç Kandili', true),
  Holiday(_d(2027, 1, 22), 'Berat Kandili', true),
  Holiday(_d(2027, 2, 8), 'Ramazan Başlangıcı', true),
  Holiday(_d(2027, 3, 5), 'Kadir Gecesi', true),
  Holiday(_d(2027, 3, 8), 'Ramazan Bayramı Arifesi', true),
  Holiday(_d(2027, 3, 9), 'Ramazan Bayramı', true),
  Holiday(_d(2027, 5, 15), 'Kurban Bayramı Arifesi', true),
  Holiday(_d(2027, 5, 16), 'Kurban Bayramı', true),
  Holiday(_d(2027, 6, 6), 'Hicri Yılbaşı', true),
  Holiday(_d(2027, 6, 15), 'Aşure Günü', true),
  Holiday(_d(2027, 8, 13), 'Mevlid Kandili', true),
  Holiday(_d(2027, 12, 2), 'Regaip Kandili', true),
  Holiday(_d(2027, 12, 24), 'Miraç Kandili', true),
];

/// Hicri (yıl, ay, gün) -> miladi (tablolu hesap; Diyanet'e göre 1 gün düzeltilir)
DateTime _hijri(int y, int m, int d) {
  final jd = d +
      ceil(29.5 * (m - 1)) +
      (y - 1) * 354 +
      ((3 + 11 * y) ~/ 30) +
      1948439.5 -
      1;
  final days = (jd - 2440587.5).round() - 1;
  return DateTime(1970, 1, 1).add(Duration(days: days));
}

List<Holiday> _religiousCalc(int year) {
  final out = <Holiday>[];
  // o miladi yıla düşen hicri yılları tara
  final hy = ((year - 622) * 33 / 32).floor();
  for (var y = hy - 1; y <= hy + 2; y++) {
    void add(int m, int d, String n) {
      final t = _hijri(y, m, d);
      if (t.year == year) out.add(Holiday(t, n, true, approx: true));
    }

    add(1, 1, 'Hicri Yılbaşı');
    add(1, 10, 'Aşure Günü');
    add(3, 11, 'Mevlid Kandili');
    add(7, 1, 'Regaip Kandili');
    add(7, 26, 'Miraç Kandili');
    add(8, 14, 'Berat Kandili');
    add(9, 1, 'Ramazan Başlangıcı');
    add(9, 26, 'Kadir Gecesi');
    add(9, 30, 'Ramazan Bayramı Arifesi');
    add(10, 1, 'Ramazan Bayramı');
    add(12, 9, 'Kurban Bayramı Arifesi');
    add(12, 10, 'Kurban Bayramı');
  }
  return out;
}

List<Holiday> _national(int y) => [
      Holiday(_d(y, 1, 1), 'Yılbaşı', false),
      Holiday(_d(y, 4, 23), 'Ulusal Egemenlik ve Çocuk Bayramı', false),
      Holiday(_d(y, 5, 1), 'Emek ve Dayanışma Günü', false),
      Holiday(_d(y, 5, 19), 'Atatürk\'ü Anma, Gençlik ve Spor Bayramı', false),
      Holiday(_d(y, 7, 15), 'Demokrasi ve Milli Birlik Günü', false),
      Holiday(_d(y, 8, 30), 'Zafer Bayramı', false),
      Holiday(_d(y, 10, 28), 'Cumhuriyet Bayramı Arifesi', false),
      Holiday(_d(y, 10, 29), 'Cumhuriyet Bayramı', false),
      Holiday(_d(y, 11, 10), 'Atatürk\'ü Anma Günü', false),
    ];

/// Bir yılın tüm önemli günleri (tarihe göre sıralı); ayarlardaki türlere göre süzülür
List<Holiday> holidaysOfYear(int y, {bool filter = true}) {
  final dini = !filter || store.pBool('hol_dini', true);
  final milli = !filter || store.pBool('hol_milli', true);
  final l = <Holiday>[];
  if (milli) l.addAll(_national(y));
  if (dini) {
    final fixed = _diyanet.where((h) => h.date.year == y).toList();
    if (fixed.isNotEmpty) {
      l.addAll(fixed);
    } else {
      l.addAll(_religiousCalc(y));
    }
  }
  l.sort((a, b) => a.date.compareTo(b.date));
  return l;
}

/// Bir güne denk gelen önemli günler (takvimde işaret için)
List<Holiday> holidaysOn(DateTime d) => [
      for (final h in holidaysOfYear(d.year))
        if (h.date.year == d.year && h.date.month == d.month && h.date.day == d.day) h
    ];

/// Bugünden başlayarak [days] gün içindeki önemli günler
List<Holiday> holidaysAhead(int days) {
  final now = DateTime.now();
  final t0 = DateTime(now.year, now.month, now.day);
  final t1 = t0.add(Duration(days: days));
  return [
    for (final h in [...holidaysOfYear(t0.year), ...holidaysOfYear(t0.year + 1)])
      if (!h.date.isBefore(t0) && !h.date.isAfter(t1)) h
  ];
}

int _daysTo(DateTime d) {
  final now = DateTime.now();
  return d.difference(DateTime(now.year, now.month, now.day)).inDays;
}

String holidayWhen(Holiday h) {
  final n = _daysTo(h.date);
  final name = tx(h.name);
  if (n <= 0) return tx('Bugün {0}', [name]);
  if (n == 1) return tx('Yarın {0}', [name]);
  if (n == 7) return tx('1 hafta sonra {0}', [name]);
  return tx('{0} gün sonra {1}', ['$n', name]);
}

/// Ana ekranın alt bildirim alanı: 7 gün içinde önemli gün varsa tek satır
String holidayBanner() {
  if (!store.pBool('hol_on', true)) return '';
  final l = holidaysAhead(7);
  if (l.isEmpty) return '';
  return holidayWhen(l.first);
}

/// Bildirimleri yeniden kurar (uygulama açılışı, ayar değişimi, rescheduleAll): önümüzdeki 120 gün
Future<void> syncHolidays() async {
  const base = 900000000;
  final now = DateTime.now();
  final t0 = DateTime(now.year, now.month, now.day);
  // eski kayıtları temizle: 130 gün x 2
  for (var i = 0; i < 130; i++) {
    final k = base + (t0.add(Duration(days: i)).difference(DateTime(2024)).inDays) * 2;
    await Notifier.cancelOnce(k);
    await Notifier.cancelOnce(k + 1);
  }
  if (!store.pBool('hol_on', true)) return;
  for (final h in holidaysAhead(120)) {
    final key = base + h.date.difference(DateTime(2024)).inDays * 2;
    final name = tx(h.name);
    final eve = h.date.subtract(const Duration(days: 7));
    final w1 = DateTime(eve.year, eve.month, eve.day, 9, 0);
    if (w1.isAfter(now)) {
      await Notifier.scheduleOnce(key, tx('1 hafta sonra {0}', [name]), w1,
          title: tx('Önemli gün'));
    }
    final w2 = DateTime(h.date.year, h.date.month, h.date.day, 8, 0);
    if (w2.isAfter(now)) {
      await Notifier.scheduleOnce(key + 1, tx('Bugün {0}', [name]), w2,
          title: tx('Önemli gün'));
    }
  }
}

// ---------------------------------------------------------------
// SAYFA: yaklaşan önemli günler, ayarlar
// ---------------------------------------------------------------
class HolidaysPage extends StatelessWidget {
  const HolidaysPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final now = DateTime.now();
        final t0 = DateTime(now.year, now.month, now.day);
        final list = [
          for (final h in [...holidaysOfYear(t0.year), ...holidaysOfYear(t0.year + 1)])
            if (!h.date.isBefore(t0)) h
        ].take(40).toList();
        String two(int n) => n.toString().padLeft(2, '0');
        return AmbScaffold(
          kind: 'settings',
          backgroundColor: ambBg(p),
          appBar: AppBar(
            backgroundColor: ambBg(p),
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text(tx('Önemli günler')),
          ),
          body: ListView(
            padding: const EdgeInsets.only(bottom: 40),
            children: [
              SwitchListTile(
                secondary: const Icon(Icons.notifications_active_outlined),
                title: Text(tx('Bildirim')),
                subtitle: Text(tx('1 hafta önce ve gününde (sabah)')),
                value: store.pBool('hol_on', true),
                onChanged: (v) {
                  store.setProf('hol_on', v);
                  syncHolidays();
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.flag_outlined),
                title: Text(tx('Milli günler')),
                value: store.pBool('hol_milli', true),
                onChanged: (v) {
                  store.setProf('hol_milli', v);
                  syncHolidays();
                },
              ),
              SwitchListTile(
                secondary: const Icon(Icons.mosque_rounded),
                title: Text(tx('Dini günler')),
                value: store.pBool('hol_dini', true),
                onChanged: (v) {
                  store.setProf('hol_dini', v);
                  syncHolidays();
                },
              ),
              const Divider(),
              for (final h in list)
                ListTile(
                  leading: Icon(
                      h.religious ? Icons.mosque_rounded : Icons.flag_rounded,
                      color: h.religious ? const Color(0xFF2E9E8F) : const Color(0xFFD64545)),
                  title: Text(tx(h.name), style: TextStyle(color: p.ink)),
                  subtitle: Text(
                      '${two(h.date.day)} ${monName(h.date.month)} ${h.date.year}${h.approx ? ' · ${tx('tahmini')}' : ''}',
                      style: TextStyle(color: p.soft)),
                  trailing: Text(() {
                    final n = _daysTo(h.date);
                    return n == 0 ? tx('Bugün') : tx('{0} gün', ['$n']);
                  }(), style: TextStyle(color: p.soft)),
                ),
            ],
          ),
        );
      },
    );
  }
}
