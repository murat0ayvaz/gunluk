import 'package:flutter/material.dart';
import 'data.dart';
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// İSTATİSTİK EKRANI (soldaki menüden bir alt kategoriye dokununca)
//  - Dönem seçici: Gün / Hafta / Ay (‹ › ile önceki dönemlere geçilir)
//  - Hedef, toplam, gün gün döküm
//  - Toplanamayan veriler (kilo): toplam yerine son değer, değişim,
//    ortalama, en düşük / en yüksek ve hedefe kalan
// ---------------------------------------------------------------
class StatsPage extends StatefulWidget {
  final String subId;
  const StatsPage({super.key, required this.subId});

  @override
  State<StatsPage> createState() => _StatsPageState();
}

class _Range {
  final DateTime start;
  final DateTime end; // dahil
  _Range(this.start, this.end);
}

class _StatsPageState extends State<StatsPage> {
  int period = 1; // 0: gün, 1: hafta, 2: ay
  int offset = 0; // 0: bu dönem, -1: önceki ...

  _Range _range() {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    if (period == 0) {
      final d = DateTime(today.year, today.month, today.day + offset);
      return _Range(d, d);
    }
    if (period == 1) {
      // Hafta pazartesi başlar
      final monday = DateTime(
          today.year, today.month, today.day - (today.weekday - 1) + offset * 7);
      final sunday = DateTime(monday.year, monday.month, monday.day + 6);
      return _Range(monday, sunday);
    }
    final first = DateTime(today.year, today.month + offset, 1);
    final last = DateTime(first.year, first.month + 1, 0);
    return _Range(first, last);
  }

  String _label(_Range r) {
    if (period == 0) {
      if (offset == 0) return tx('Bugün');
      if (offset == -1) return tx('Dün');
      return '${r.start.day} ${monName(r.start.month)} ${r.start.year}';
    }
    if (period == 1) {
      if (offset == 0) return tx('Bu hafta');
      if (offset == -1) return tx('Geçen hafta');
      return '${r.start.day} ${monName(r.start.month)} – ${r.end.day} ${monName(r.end.month)}';
    }
    if (offset == 0) return tx('Bu ay');
    if (offset == -1) return tx('Geçen ay');
    return '${monName(r.start.month)} ${r.start.year}';
  }

  Widget _mini(Pal p, String title, String value) => Expanded(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(title, style: TextStyle(fontSize: 12.5, color: p.soft)),
            const SizedBox(height: 2),
            Text(value,
                style: TextStyle(
                    fontSize: 16, fontWeight: FontWeight.w600, color: p.ink)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        final sub = store.subById(widget.subId);
        final cat = store.catOfSub(widget.subId);
        if (sub == null || cat == null) {
          return Scaffold(
            appBar: AppBar(),
            body: Center(child: Text(tx('Bu alt kategori bulunamadı'))),
          );
        }

        final unit = sub.unit;
        final r = _range();
        final startK = dKey(r.start);
        final endK = dKey(r.end);

        // Alt kategorinin tüm kayıtları (tarihe göre sıralı)
        final all = store.entriesOf(sub.id)
          ..sort((a, b) => a.date.compareTo(b.date));
        final inRange = all
            .where((e) =>
                e.date.compareTo(startK) >= 0 && e.date.compareTo(endK) <= 0)
            .toList();
        final byDate = <String, double>{for (final e in inRange) e.date: e.value};

        // Dönemdeki günler
        final days = <DateTime>[];
        for (var d = r.start;
            !d.isAfter(r.end);
            d = DateTime(d.year, d.month, d.day + 1)) {
          days.add(d);
        }

        // Dönem sonuna kadarki en son kayıt (kilo gibi veriler için)
        Entry? latestEntry;
        for (final e in all) {
          if (e.date.compareTo(endK) <= 0) latestEntry = e;
        }
        final latest = latestEntry;

        final g = sub.goal;
        final summary = <Widget>[];

        if (sub.summable) {
          // ----- Toplanan veri: toplam, ortalama, hedefe kalan -----
          final total = inRange.fold<double>(0, (a, e) => a + e.value);
          final count = inRange.length;
          summary.addAll([
            Text(tx('Toplam'), style: TextStyle(color: p.soft)),
            const SizedBox(height: 2),
            Text('${fmt(total)} $unit',
                style: TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w700, color: p.ink)),
            const SizedBox(height: 14),
            Row(children: [
              _mini(p, tx('Veri girilen gün'), '$count / ${days.length}'),
              _mini(p, tx('Ortalama'),
                  count > 0 ? '${fmt(total / count)} $unit' : '—'),
            ]),
          ]);
          if (g != null) {
            final target = g * days.length;
            final diff = target - total;
            final String remain;
            if (sub.isMax) {
              remain = diff >= 0
                  ? tx('{0} {1} kaldı', [fmt(diff), unit])
                  : tx('{0} {1} aşıldı', [fmt(-diff), unit]);
            } else {
              remain = diff > 0
                  ? tx('{0} {1} kaldı', [fmt(diff), unit])
                  : tx('Hedefe ulaşıldı');
            }
            summary.addAll([
              const SizedBox(height: 14),
              Row(children: [
                _mini(p, sub.isMax ? tx('Üst sınır') : tx('Hedef'),
                    '${fmt(target)} $unit'),
                _mini(p, tx('Durum'), remain),
              ]),
              if (!sub.isMax && target > 0) ...[
                const SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(6),
                  child: LinearProgressIndicator(
                    value: (total / target).clamp(0.0, 1.0).toDouble(),
                    minHeight: 8,
                    backgroundColor: p.line,
                    color: p.accent,
                  ),
                ),
              ],
            ]);
          }
        } else {
          // ----- Toplanamayan veri (kilo gibi): istatistikler -----
          double? minV;
          double? maxV;
          double sum = 0;
          for (final e in inRange) {
            sum += e.value;
            if (minV == null || e.value < minV) minV = e.value;
            if (maxV == null || e.value > maxV) maxV = e.value;
          }
          String change = '—';
          if (inRange.length >= 2) {
            final dv = inRange.last.value - inRange.first.value;
            change = '${dv > 0 ? '+' : ''}${fmt(dv)} $unit';
          }
          summary.addAll([
            Text(tx('Son değer'), style: TextStyle(color: p.soft)),
            const SizedBox(height: 2),
            Text(latest == null ? '—' : '${fmt(latest.value)} $unit',
                style: TextStyle(
                    fontSize: 34, fontWeight: FontWeight.w700, color: p.ink)),
            if (latest != null)
              Text(
                  '${parseKey(latest.date).day} ${monName(parseKey(latest.date).month)} ${parseKey(latest.date).year}',
                  style: TextStyle(fontSize: 12.5, color: p.soft)),
            const SizedBox(height: 14),
            Row(children: [
              _mini(p, tx('Değişim'), change),
              _mini(
                  p,
                  tx('Ortalama'),
                  inRange.isEmpty
                      ? '—'
                      : '${fmt(sum / inRange.length)} $unit'),
            ]),
            const SizedBox(height: 14),
            Row(children: [
              _mini(p, tx('En düşük'),
                  minV == null ? '—' : '${fmt(minV)} $unit'),
              _mini(p, tx('En yüksek'),
                  maxV == null ? '—' : '${fmt(maxV)} $unit'),
            ]),
          ]);
          if (g != null) {
            final String status;
            if (latest == null) {
              status = '—';
            } else if ((g - latest.value).abs() < 0.0001) {
              status = tx('Hedefe ulaşıldı');
            } else {
              status = tx('{0} {1} kaldı', [fmt((g - latest.value).abs()), unit]);
            }
            summary.addAll([
              const SizedBox(height: 14),
              Row(children: [
                _mini(p, tx('Hedef'), '${fmt(g)} $unit'),
                _mini(p, tx('Hedefe kalan'), status),
              ]),
            ]);
          }
        }

        // ----- Gün gün döküm -----
        // Gün ve hafta: tüm günler; ay: sadece verisi olan günler
        final listDays = period == 2
            ? days.where((d) => byDate.containsKey(dKey(d))).toList()
            : days;
        final dayRows = <Widget>[
          for (final d in listDays)
            Builder(builder: (_) {
              final v = byDate[dKey(d)];
              final met = v != null && goalMet(sub, v);
              return Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding:
                    const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
                decoration: BoxDecoration(
                  color: met ? p.okBg : p.card,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(color: p.line),
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                          '${wdName(d.weekday)}  ${d.day} ${monName(d.month)}',
                          style: TextStyle(color: p.ink)),
                    ),
                    Text(v == null ? '—' : '${fmt(v)} $unit',
                        style: TextStyle(
                            fontWeight: FontWeight.w600,
                            color: v == null ? p.soft : p.ink)),
                  ],
                ),
              );
            }),
        ];

        final periodLabels = [tx('Gün'), tx('Hafta'), tx('Ay')];

        return Scaffold(
          appBar: AppBar(
            backgroundColor: p.bg,
            elevation: 0,
            scrolledUnderElevation: 0,
            title: Text('${cat.name} › ${sub.name}'),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
            children: [
              // Dönem seçici
              Wrap(spacing: 8, children: [
                for (var i = 0; i < 3; i++)
                  ChoiceChip(
                    label: Text(periodLabels[i]),
                    selected: period == i,
                    onSelected: (_) => setState(() {
                      period = i;
                      offset = 0;
                    }),
                  ),
              ]),
              // Önceki / sonraki dönem
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  IconButton(
                    onPressed: () => setState(() => offset -= 1),
                    icon: const Icon(Icons.chevron_left_rounded),
                  ),
                  Text(_label(r),
                      style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w600,
                          color: p.ink)),
                  IconButton(
                    onPressed:
                        offset < 0 ? () => setState(() => offset += 1) : null,
                    icon: const Icon(Icons.chevron_right_rounded),
                  ),
                ],
              ),
              // Özet kartı
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: p.card,
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: p.line),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: summary,
                ),
              ),
              const SizedBox(height: 18),
              Text(tx('Gün gün'), style: TextStyle(color: p.soft)),
              const SizedBox(height: 8),
              if (dayRows.isEmpty)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(tx('Bu dönemde veri yok'),
                      style: TextStyle(color: p.soft)),
                )
              else
                ...dayRows,
            ],
          ),
        );
      },
    );
  }
}
