import 'package:flutter/material.dart';
import 'data.dart';
import 'net.dart';
import 'strings.dart';
import 'theme.dart' show Pal;
import 'tools.dart' show ToolsButton, ToolsDrawer;
import 'ui.dart';
import 'weather.dart';

// ---------------------------------------------------------------
// HAVA DURUMU (Araçlar)
// Üstte gün aralığı (Günlük / Haftalık / 15 gün). Altında açılır başlıklar:
//   Sıcaklık  -> saat saat (ya da gün gün); bütün kaynakların değeri yan yana
//   Hissedilen, Nem, Rüzgar, Basınç, Yağış, UV, Görüş -> seçili kaynaktan tek değer
//   Deniz durumu -> dokununca yüklenir
//   Kaynaklar ve ayarlar -> en altta, kapalı: kaynak seçimi + ana ekran hava ayarları
// Kaynakta olmayan değer gösterilmez (tahmin yok).
// ---------------------------------------------------------------

const _srcChoices = <List<String>>[
  ['auto', 'Birleşik'],
  ['mgm', 'MGM'],
  ['om', 'Open-Meteo'],
  ['ecmwf', 'ECMWF'],
  ['icon', 'ICON'],
  ['gfs', 'GFS'],
  ['met', 'MET Norway'],
];

String _short(String s) {
  switch (s) {
    case 'Open-Meteo':
      return 'OM';
    case 'MET Norway':
      return 'MET';
    default:
      return s;
  }
}

String _compass(double deg) {
  const n = ['K', 'KD', 'D', 'GD', 'G', 'GB', 'B', 'KB'];
  return n[((deg % 360) / 45).round() % 8];
}

String _n(double v, [int d = 0]) {
  final s = v.toStringAsFixed(d);
  return s.contains('.')
      ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '')
      : s;
}

String _two(int n) => n.toString().padLeft(2, '0');

/// Açılır başlık: kendi durumunu tutar; ilk açılışta kapalı (Sıcaklık hariç)
class _Sec extends StatefulWidget {
  final String title;
  final IconData icon;
  final bool initOpen;
  final VoidCallback? onOpen;
  final Widget child;
  const _Sec(
      {super.key,
      required this.title,
      required this.icon,
      required this.child,
      this.initOpen = false,
      this.onOpen});

  @override
  State<_Sec> createState() => _SecState();
}

class _SecState extends State<_Sec> {
  late bool _open = widget.initOpen;

  @override
  void initState() {
    super.initState();
    if (_open) widget.onOpen?.call();
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Container(
      margin: const EdgeInsets.only(top: 10),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () {
              setState(() => _open = !_open);
              if (_open) widget.onOpen?.call();
            },
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 13),
              child: Row(
                children: [
                  Icon(widget.icon, color: p.accent),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(widget.title,
                        style: TextStyle(
                            color: p.ink,
                            fontSize: 16,
                            fontWeight: FontWeight.w600)),
                  ),
                  Icon(_open
                      ? Icons.expand_less_rounded
                      : Icons.expand_more_rounded),
                ],
              ),
            ),
          ),
          if (_open)
            Padding(
              padding: const EdgeInsets.fromLTRB(14, 0, 14, 12),
              child: widget.child,
            ),
        ],
      ),
    );
  }
}

class WxDetailPage extends StatefulWidget {
  /// false: Saatlik sayfa (saat saat); true: Günlük sayfa (16 gün)
  final bool daily;
  const WxDetailPage({super.key, this.daily = false});

  @override
  State<WxDetailPage> createState() => _WxDetailPageState();
}

class _WxDetailPageState extends State<WxDetailPage> {
  String _src = 'auto'; // diğer başlıklar için kaynak
  WxAll? _all;
  WxDetail? _sel;
  bool _loading = false;
  String? _err;
  late int _tab = widget.daily ? 2 : 0; // 0 saatlik, 2 günlük (16 gün)
  bool _sort = false; // bölüm sıralama kipi

  WxMarine? _marine;
  bool _marineAsked = false;
  bool _marineLoading = false;
  String? _marineErr;

  @override
  void initState() {
    super.initState();
    _load();
  }

  /// Şu an gösterilen yerin (enlem, boylam, ad); seçili favori ya da Konumum
  (double?, double?, String) _pos() {
    final i = store.wxSel;
    if (i >= 0 && i < store.wxFavs.length) {
      final f = store.wxFavs[i];
      return (f.lat, f.lon, f.name);
    }
    return (store.wxLat, store.wxLon, '');
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _err = null;
    });
    if (store.wxSel < 0) {
      // Konumum: telefonun konumundan bul (olmazsa son bilinen konum)
      try {
        await weather.locate();
      } catch (_) {}
      if (!mounted) return;
    }
    final pos = _pos();
    final lat = pos.$1;
    final lon = pos.$2;
    if (lat == null || lon == null) {
      setState(() {
        _loading = false;
        _err = tx('Konum alınamadı. Konum iznini aç ya da yukarıdan "Yer ekle" ile bir yer seç.');
      });
      return;
    }
    try {
      final a = await fetchWxAll(lat, lon, place: pos.$3);
      if (!mounted) return;
      setState(() {
        _all = a;
        _loading = false;
        _pickSel();
      });
    } catch (e) {
      if (!mounted) return;
      final t = e is WxError ? '${e.step}: ${e.detail}' : e.toString();
      setState(() {
        _loading = false;
        _all = null;
        _sel = null;
        _err = tx('Veri alınamadı: {0}', [t.length > 120 ? t.substring(0, 120) : t]);
      });
    }
  }

  /// Seçili kaynağa göre "diğer başlıklar"ın verisini hazırlar
  void _pickSel() {
    final a = _all;
    if (a == null) {
      _sel = null;
      return;
    }
    if (_src == 'auto') {
      _sel = mergeWx([
        for (final k in const ['mgm', 'om', 'met'])
          if (a.by[k] != null) a.by[k]!
      ]);
    } else {
      _sel = a.by[_src];
    }
  }

  Future<void> _loadMarine() async {
    final pos = _pos();
    final lat = pos.$1;
    final lon = pos.$2;
    if (lat == null || lon == null || _marineAsked) return;
    setState(() {
      _marineAsked = true;
      _marineLoading = true;
      _marineErr = null;
    });
    try {
      final m = await fetchMarine(lat, lon);
      if (!mounted) return;
      setState(() {
        _marine = m;
        _marineLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _marineLoading = false;
        _marine = null;
        _marineErr = tx('Bu konumda deniz verisi yok.');
      });
    }
  }

  // ---------- zaman penceresi ----------
  bool _inWindow(DateTime t) {
    final now = DateTime.now();
    return !t.isBefore(now.subtract(const Duration(minutes: 90))) &&
        !t.isAfter(now.add(const Duration(hours: 30)));
  }

  int get _dayCount => 16;

  static const _shortTr = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
  static const _shortEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

  /// Kısa gün adı + tarih (iki satır; sütuna hep sığar)
  String _dayLabel(DateTime t) =>
      '${(appLang == 'en' ? _shortEn : _shortTr)[t.weekday - 1]}\n${_two(t.day)}.${_two(t.month)}';

  /// Gün başlığı: büyük, koyu
  Widget _dayHead(Pal p, String text) => Padding(
        padding: const EdgeInsets.only(top: 10, bottom: 4),
        child: Text(text,
            style: TextStyle(
                color: p.ink, fontSize: 19, fontWeight: FontWeight.w800)),
      );

  String _headFor(DateTime t) {
    final now = DateTime.now();
    final k = wxDayKey(t);
    if (k == wxDayKey(now)) return tx('Bugün');
    if (k == wxDayKey(now.add(const Duration(days: 1)))) return tx('Yarın');
    return wdName(t.weekday);
  }

  Widget _label(Pal p, String text, {double w = 52}) => SizedBox(
        width: w,
        child: Text(text,
            style: TextStyle(
                color: p.soft, fontSize: 12.5, fontWeight: FontWeight.w600)),
      );

  // ---------- Sıcaklık: kaynaklar sütun, değerler alt alta ----------
  // Kaynak adları en üstte bir kez; her satırda ikon üstte, sıcaklık altta.
  Widget _tempSection(Pal p) {
    final a = _all;
    if (a == null) return const SizedBox.shrink();
    final srcs = <String>[];
    final rows = <Widget>[];
    // satır verisi: etiket, kaynak -> (ikon kodu, metin)
    final data = <_TRow>[];
    if (_tab == 0) {
      final times = <String, DateTime>{};
      for (final d in a.by.values) {
        for (final x in d.hourly) {
          if (_inWindow(x.t)) times[wxHourKey(x.t)] = x.t;
        }
      }
      final keys = times.keys.toList()..sort();
      String lastDay = '';
      for (final k in keys) {
        final t = times[k]!;
        final dk = wxDayKey(t);
        final cells = <String, _TCell>{};
        for (final sk in wxSourceKeys) {
          final d = a.by[sk];
          if (d == null) continue;
          WxPt? hit;
          for (final x in d.hourly) {
            if (wxHourKey(x.t) == k) {
              hit = x;
              break;
            }
          }
          final v = hit?.v['temp'];
          if (v != null) {
            cells[sk] = _TCell(hit!.code, '${_n(v)}°', t.hour < 6 || t.hour >= 20);
          }
        }
        if (cells.isEmpty) continue;
        String? head;
        if (dk != lastDay) {
          lastDay = dk;
          head = _headFor(t);
        }
        data.add(_TRow(head, '${_two(t.hour)}:00', cells));
      }
    } else {
      final days = <String, DateTime>{};
      final today = DateTime.now();
      final t0 = DateTime(today.year, today.month, today.day);
      for (final d in a.by.values) {
        for (final x in d.daily) {
          if (!x.t.isBefore(t0)) days[wxDayKey(x.t)] = x.t;
        }
      }
      final keys = days.keys.toList()..sort();
      for (final k in keys.take(_dayCount)) {
        final t = days[k]!;
        final cells = <String, _TCell>{};
        for (final sk in wxSourceKeys) {
          final d = a.by[sk];
          if (d == null) continue;
          WxPt? hit;
          for (final x in d.daily) {
            if (wxDayKey(x.t) == k) {
              hit = x;
              break;
            }
          }
          final hi = hit?.v['tmax'];
          final lo = hit?.v['tmin'];
          if (hi != null || lo != null) {
            cells[sk] = _TCell(hit!.code, hi == null ? '–' : '${_n(hi)}°', false,
                sub: lo == null ? '' : '${_n(lo)}°');
          }
        }
        if (cells.isEmpty) continue;
        data.add(_TRow(null, _dayLabel(t), cells));
      }
    }
    if (data.isEmpty) return _empty(p);
    for (final sk in wxSourceKeys) {
      if (data.any((r) => r.cells.containsKey(sk))) srcs.add(sk);
    }
    final line = Container(width: 1, color: p.soft.withOpacity(0.25));
    const lw = 44.0;
    // başlık: kaynak adları bir kez
    rows.add(IntrinsicHeight(
      child: Row(children: [
        const SizedBox(width: lw),
        for (var i = 0; i < srcs.length; i++) ...[
          if (i > 0) line,
          Expanded(
              child: Center(
                  child: Text(wxSourceShort[srcs[i]]!,
                      style: TextStyle(
                          color: p.soft,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w700)))),
        ],
      ]),
    ));
    rows.add(Divider(height: 8, color: p.soft.withOpacity(0.25)));
    for (final r in data) {
      if (r.head != null) rows.add(_dayHead(p, r.head!));
      rows.add(Divider(height: 1, color: p.soft.withOpacity(0.3)));
      rows.add(Padding(
        padding: const EdgeInsets.symmetric(vertical: 6),
        child: IntrinsicHeight(
          child: Row(children: [
            SizedBox(
                width: lw,
                child: Text(r.label,
                    maxLines: 2,
                    style: TextStyle(
                        color: p.ink,
                        fontSize: 12,
                        height: 1.25,
                        fontWeight: FontWeight.w700))),
            for (var i = 0; i < srcs.length; i++) ...[
              if (i > 0) line,
              Expanded(child: _tcell(p, r.cells[srcs[i]])),
            ],
          ]),
        ),
      ));
    }
    return Column(children: rows);
  }

  Widget _tcell(Pal p, _TCell? c) {
    if (c == null) {
      return Center(child: Text('–', style: TextStyle(color: p.soft)));
    }
    return Column(mainAxisSize: MainAxisSize.min, children: [
      if (c.code != null)
        Icon(wxIcon(c.code!, night: c.night), size: 20, color: wxColor(c.code!)),
      Text(c.text,
          maxLines: 1,
          style: TextStyle(
              color: p.ink, fontSize: 15, fontWeight: FontWeight.w700)),
      if (c.sub.isNotEmpty)
        Text(c.sub,
            maxLines: 1,
            style: TextStyle(
                color: p.soft, fontSize: 13, fontWeight: FontWeight.w500)),
    ]);
  }

  Widget _empty(Pal p) => Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(tx('Seçili kaynakta bu veri yok.'),
            style: TextStyle(color: p.soft)),
      );

  /// Diğer başlıklar: seçili kaynaktan tek değer; saat saat ya da gün gün
  Widget _metricSection(Pal p, String Function(WxPt) fmt, {bool dailyToo = true}) {
    final d = _sel;
    if (d == null) return _empty(p);
    final rows = <Widget>[];
    if (_tab == 0) {
      String lastDay = '';
      for (final x in d.hourly) {
        if (!_inWindow(x.t)) continue;
        final s = fmt(x);
        if (s.isEmpty) continue;
        final dk = wxDayKey(x.t);
        if (dk != lastDay) {
          lastDay = dk;
          rows.add(_dayHead(p, _headFor(x.t)));
        }
        rows.add(_metricRow(p, '${_two(x.t.hour)}:00', s, x));
      }
    } else {
      final now = DateTime.now();
      final t0 = DateTime(now.year, now.month, now.day);
      var c = 0;
      for (final x in d.daily) {
        if (x.t.isBefore(t0)) continue;
        if (c >= _dayCount) break;
        final s = fmt(x);
        if (s.isEmpty) continue;
        c++;
        rows.add(Divider(height: 1, color: p.soft.withOpacity(0.3)));
        rows.add(_metricRow(p, _dayLabel(x.t), s, x, w: 46));
      }
    }
    if (rows.isEmpty) return _empty(p);
    return Column(children: rows);
  }

  Widget _metricRow(Pal p, String label, String value, WxPt x, {double w = 52}) {
    final set = <String>{
      for (final v in x.s.values)
        if (v.isNotEmpty) _short(v)
    };
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _label(p, label, w: w),
          Expanded(
            child: Text(value,
                style: TextStyle(
                    color: p.ink, fontSize: 15, fontWeight: FontWeight.w600)),
          ),
          if (_src == 'auto' && set.length > 1)
            Text(set.join('+'), style: TextStyle(color: p.soft, fontSize: 9)),
        ],
      ),
    );
  }

  // ---------- değer biçimleri ----------
  String _fFeels(WxPt x) {
    final v = x.v['feels'];
    return v == null ? '' : '${_n(v)}°';
  }

  String _fHum(WxPt x) {
    final v = x.v['hum'];
    return v == null ? '' : '%${_n(v)}';
  }

  String _fWind(WxPt x) {
    final w = x.v['wind'];
    if (w == null) return '';
    final dir = x.v['dir'];
    final g = x.v['gust'];
    final b = StringBuffer('${_n(w)} ${tx('km/sa')}');
    if (dir != null) b.write(' ${_compass(dir)}');
    if (g != null) b.write('  (${tx('hamle')} ${_n(g)})');
    return b.toString();
  }

  String _fPress(WxPt x) {
    final v = x.v['press'];
    return v == null ? '' : '${_n(v)} hPa';
  }

  String _fRain(WxPt x) {
    final parts = <String>[];
    final pop = x.v['pop'];
    if (pop != null) parts.add('%${_n(pop)}');
    final r = x.v['rain'];
    if (r != null) parts.add('${_n(r, 1)} mm');
    return parts.join('  •  ');
  }

  String _fUv(WxPt x) {
    final v = x.v['uv'];
    return v == null ? '' : _n(v, 1);
  }

  String _fVis(WxPt x) {
    final v = x.v['vis'];
    return v == null ? '' : '${_n(v, 1)} km';
  }

  // ---------- Şimdi kartı ----------
  Widget _nowCard(Pal p) {
    final n = _sel?.now ?? _all?.by.values.first.now;
    if (n == null) return const SizedBox.shrink();
    final t = n.v['temp'];
    final code = n.code;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          if (code != null) Icon(wxIcon(code), size: 44, color: wxColor(code)),
          const SizedBox(width: 12),
          if (t != null)
            Text('${_n(t)}°',
                style: TextStyle(
                    fontSize: 44, fontWeight: FontWeight.w300, color: p.ink)),
          const Spacer(),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(tx('Şimdi'), style: TextStyle(color: p.soft)),
              if (n.v['feels'] != null)
                Text('${tx('Hissedilen')} ${_n(n.v['feels']!)}°',
                    style: TextStyle(color: p.soft, fontSize: 12)),
            ],
          ),
        ],
      ),
    );
  }

  // ---------- Deniz ----------
  String _seaState(double h) {
    if (h < 0.1) return tx('Aynalı');
    if (h < 0.5) return tx('Sakin');
    if (h < 1.25) return tx('Hafif dalgalı');
    if (h < 2.5) return tx('Orta dalgalı');
    if (h < 4) return tx('Dalgalı');
    return tx('Çok dalgalı');
  }

  Widget _marineBody(Pal p) {
    if (_marineLoading) {
      return const Padding(
          padding: EdgeInsets.all(16),
          child: Center(child: CircularProgressIndicator()));
    }
    final m = _marine;
    if (m == null) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 8),
        child: Text(_marineErr ?? tx('Bu konumda deniz verisi yok.'),
            style: TextStyle(color: p.soft)),
      );
    }
    final n = m.now;
    Widget line(String k, String v) => Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Expanded(child: Text(k, style: TextStyle(color: p.soft))),
              Text(v,
                  style: TextStyle(
                      color: p.ink, fontWeight: FontWeight.w600, fontSize: 15)),
            ],
          ),
        );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        if (n != null) ...[
          if (n.v['wave'] != null)
            line(tx('Dalga yüksekliği'),
                '${_n(n.v['wave']!, 1)} m • ${_seaState(n.v['wave']!)}'),
          if (n.v['wdir'] != null)
            line(tx('Dalga yönü'),
                '${_compass(n.v['wdir']!)} (${_n(n.v['wdir']!)}°)'),
          if (n.v['wper'] != null)
            line(tx('Dalga periyodu'), '${_n(n.v['wper']!, 1)} ${tx('sn')}'),
          if (n.v['sst'] != null)
            line(tx('Deniz suyu sıcaklığı'), '${_n(n.v['sst']!, 1)}°'),
          if (n.v['swell'] != null)
            line(tx('Dalga (uzun)'), '${_n(n.v['swell']!, 1)} m'),
        ],
        if (m.daily.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(tx('Günlere göre en yüksek dalga'),
              style: TextStyle(color: p.soft, fontSize: 12)),
          for (final x in m.daily)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 4),
              child: Row(
                children: [
                  SizedBox(
                      width: 84,
                      child: Text(
                          '${wdName(x.t.weekday)} ${_two(x.t.day)}.${_two(x.t.month)}',
                          style: TextStyle(color: p.ink, fontSize: 13))),
                  Expanded(
                    child: Text(
                        [
                          if (x.v['wave'] != null)
                            '${_n(x.v['wave']!, 1)} m • ${_seaState(x.v['wave']!)}',
                          if (x.v['wper'] != null)
                            '${_n(x.v['wper']!, 1)} ${tx('sn')}',
                          if (x.v['wdir'] != null) _compass(x.v['wdir']!),
                        ].join(' • '),
                        style: TextStyle(color: p.soft, fontSize: 12)),
                  ),
                ],
              ),
            ),
        ],
      ],
    );
  }

  // ---------- Kaynaklar ve ayarlar (en altta, kapalı) ----------
  Widget _settingsBody(Pal p) {
    final a = _all;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(tx('Diğer başlıkların kaynağı'),
            style: TextStyle(color: p.soft, fontSize: 12.5)),
        const SizedBox(height: 6),
        Wrap(
          spacing: 8,
          runSpacing: 4,
          children: [
            for (final s in _srcChoices)
              ChoiceChip(
                label: Text(s[0] == 'auto' ? tx(s[1]) : s[1]),
                selected: _src == s[0],
                onSelected: (_) => setState(() {
                  _src = s[0];
                  _pickSel();
                }),
              ),
          ],
        ),
        if (a != null) ...[
          const SizedBox(height: 8),
          Text(
              tx('Alınan kaynaklar: {0}', [
                a.by.keys.map((k) => wxSourceShort[k] ?? k).join(', ')
              ]) +
                  (a.notes.isEmpty
                      ? ''
                      : '\n${tx('alınamayan')}: ${a.notes.join('; ')}'),
              style: TextStyle(color: p.soft, fontSize: 11)),
        ],
        const Divider(height: 24),
        Text(tx('Ana ekrandaki hava durumu'),
            style: TextStyle(color: p.soft, fontSize: 12.5)),
        SwitchListTile(
          contentPadding: EdgeInsets.zero,
          title: Text(tx('Hava durumunu göster')),
          subtitle: Text(tx('Ana ekranda seçili yerin havası gösterilir.')),
          value: store.wxOn,
          onChanged: (v) {
            store.setWxOn(v);
            if (v) weather.ensure();
          },
        ),
        ListTile(
          contentPadding: EdgeInsets.zero,
          leading: const Icon(Icons.cloud_queue_rounded),
          title: Text(tx('Hava durumu servisi')),
          subtitle: DropdownButton<String>(
            isExpanded: true,
            value: store.wxProvider,
            underline: const SizedBox.shrink(),
            items: [
              for (final pr in wxProviders)
                DropdownMenuItem(
                    value: pr[0],
                    child: Text(pr[1], style: const TextStyle(fontSize: 13))),
            ],
            onChanged: (v) async {
              if (v == null) return;
              store.setWxProvider(v);
              if (v == 'owm' && store.wxOwmKey.isEmpty) {
                final k = await askText(context, tx('OpenWeatherMap anahtarı'),
                    label: tx('API anahtarı'));
                if (k != null) store.setWxOwmKey(k.trim());
              }
              weather.reset();
            },
          ),
        ),
        if (store.wxProvider == 'owm')
          ListTile(
            contentPadding: EdgeInsets.zero,
            leading: const Icon(Icons.key_rounded),
            title: Text(tx('OpenWeatherMap anahtarı')),
            subtitle:
                Text(store.wxOwmKey.isEmpty ? tx('Girilmedi') : tx('Girildi')),
            onTap: () async {
              final k = await askText(context, tx('OpenWeatherMap anahtarı'),
                  initial: store.wxOwmKey, label: tx('API anahtarı'));
              if (k != null) {
                store.setWxOwmKey(k.trim());
                weather.reset();
              }
            },
          ),
        Text(
          store.wxProvider == 'mgm'
              ? tx('MGM verisi resmi olmayan yoldan alınır; çalışmazsa başka bir servis seç.')
              : tx('Hava durumu internetten alınır. Bugünde şimdiki durum, tarihin yanındaki simgeye basınca saatlik hava açılır.'),
          style: TextStyle(fontSize: 12.5, color: p.soft, height: 1.4),
        ),
      ],
    );
  }

  void _select(int i) {
    if (store.wxSel == i) return;
    store.setWxSel(i);
    _marineAsked = false;
    _marine = null;
    weather.ensure(); // ana ekran da seçili yere uysun
    _load();
  }

  /// Çipte yalnız ilk kelime: "Serdivan, Sakarya" -> Serdivan
  String _first(String name) {
    final t = name.trim().split(RegExp(r'[\s,]+'));
    return t.isEmpty || t.first.isEmpty ? name : t.first;
  }

  /// Üstte yerler: Konumum + eklenen yerler + (+)
  Widget _favRow(Pal p) {
    final sel = store.wxSel;
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(
        children: [
          Padding(
            padding: const EdgeInsets.only(right: 8),
            child: ChoiceChip(
              avatar: const Icon(Icons.my_location_rounded, size: 16),
              label: Text(tx('Konumum')),
              selected: sel < 0,
              onSelected: (_) => _select(-1),
            ),
          ),
          for (var i = 0; i < store.wxFavs.length; i++)
            Padding(
              padding: const EdgeInsets.only(right: 8),
              child: GestureDetector(
                onLongPress: () async {
                  final f = store.wxFavs[i];
                  final ok = await confirmDialog(
                      context,
                      tx('Favoriden çıkarılsın mı?'),
                      f.name,
                      okLabel: tx('Çıkar'));
                  if (!ok) return;
                  store.removeWxFav(i);
                  _marineAsked = false;
                  _marine = null;
                  weather.ensure();
                  _load();
                },
                child: ChoiceChip(
                  label: Text(_first(store.wxFavs[i].name)),
                  selected: sel == i,
                  onSelected: (_) => _select(i),
                ),
              ),
            ),
          ActionChip(
            avatar: const Icon(Icons.add_rounded, size: 18),
            label: Text(tx('Yer ekle')),
            onPressed: () async {
              final c = await pickGeoCity(context);
              if (c == null) return;
              store.addWxFav(c.label, c.lat, c.lon);
              final k = store.wxFavs.indexWhere((f) => f.name == c.label);
              store.setWxSel(k);
              _marineAsked = false;
              _marine = null;
              weather.ensure();
              _load();
            },
          ),
        ],
      ),
    );
  }

  // ---------- Bölümler (sıralanabilir) ----------
  static const _secIds = [
    'temp', 'feels', 'hum', 'wind', 'press', 'rain', 'uv', 'vis', 'sea'
  ];

  List<String> _order() => [
        ...store.wxSecOrder.where(_secIds.contains),
        ..._secIds.where((x) => !store.wxSecOrder.contains(x)),
      ];

  (String, IconData) _secInfo(String id) {
    switch (id) {
      case 'temp':
        return (tx('Sıcaklık'), Icons.thermostat_rounded);
      case 'feels':
        return (tx('Hissedilen'), Icons.device_thermostat_rounded);
      case 'hum':
        return (tx('Nem'), Icons.water_drop_outlined);
      case 'wind':
        return (tx('Rüzgar'), Icons.air_rounded);
      case 'press':
        return (tx('Basınç'), Icons.speed_rounded);
      case 'rain':
        return (tx('Yağış'), Icons.grain_rounded);
      case 'uv':
        return (tx('UV'), Icons.wb_sunny_outlined);
      case 'vis':
        return (tx('Görüş'), Icons.visibility_outlined);
      default:
        return (tx('Deniz durumu'), Icons.sailing_rounded);
    }
  }

  Widget _secBody(Pal p, String id) {
    switch (id) {
      case 'temp':
        return _tempSection(p);
      case 'feels':
        return _metricSection(p, _fFeels);
      case 'hum':
        return _metricSection(p, _fHum);
      case 'wind':
        return _metricSection(p, _fWind);
      case 'press':
        return _metricSection(p, _fPress);
      case 'rain':
        return _metricSection(p, _fRain);
      case 'uv':
        return _metricSection(p, _fUv);
      case 'vis':
        return _metricSection(p, _fVis);
      default:
        return _marineBody(p);
    }
  }

  Widget _sec(Pal p, String id) {
    final info = _secInfo(id);
    return _Sec(
        key: ValueKey('s_$id'),
        title: info.$1,
        icon: info.$2,
        initOpen: id == 'temp',
        onOpen: id == 'sea' ? _loadMarine : null,
        child: _secBody(p, id));
  }

  /// Sıralama kipi: bölümleri sürükleyerek yeniden dizer
  Widget _sortList(Pal p) {
    final ids = _order();
    return ReorderableListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      buildDefaultDragHandles: false,
      onReorder: (o, n) {
        if (n > o) n -= 1;
        final l = [...ids];
        final x = l.removeAt(o);
        l.insert(n, x);
        store.setWxSecOrder(l);
      },
      children: [
        for (var i = 0; i < ids.length; i++)
          Container(
            key: ValueKey('o_${ids[i]}'),
            margin: const EdgeInsets.only(top: 8),
            decoration: BoxDecoration(
              color: p.card,
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: p.line),
            ),
            child: ListTile(
              leading: Icon(_secInfo(ids[i]).$2, color: p.accent),
              title: Text(_secInfo(ids[i]).$1,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              trailing: ReorderableDragStartListener(
                  index: i, child: Icon(Icons.drag_handle_rounded, color: p.soft)),
            ),
          ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final p = palOf(context);
        final has = _all != null && !_loading;
        return Scaffold(
          backgroundColor: p.bg,
          endDrawer: const ToolsDrawer(replace: true),
          appBar: AppBar(
            title: Text(tx('Hava durumu')),
            actions: [
              const ToolsButton(),
              IconButton(
                  tooltip: _sort ? tx('Tamam') : tx('Sırala'),
                  onPressed: () => setState(() => _sort = !_sort),
                  icon: Icon(_sort ? Icons.check_rounded : Icons.swap_vert_rounded)),
              IconButton(
                  tooltip: tx('Yenile'),
                  onPressed: _loading
                      ? null
                      : () {
                          _marineAsked = false;
                          _marine = null;
                          _load();
                        },
                  icon: const Icon(Icons.refresh_rounded)),
            ],
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
            children: [
              _favRow(p),
              const SizedBox(height: 10),
              SegmentedButton<int>(
                showSelectedIcon: false,
                segments: [
                  ButtonSegment(value: 0, label: Text(tx('Saatlik'))),
                  ButtonSegment(value: 2, label: Text(tx('Günlük'))),
                ],
                selected: {_tab},
                onSelectionChanged: (v) => setState(() => _tab = v.first),
              ),
              const SizedBox(height: 4),
              if (_loading)
                const Padding(
                    padding: EdgeInsets.all(30),
                    child: Center(child: CircularProgressIndicator())),
              if (_err != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  child: Text(_err!,
                      style: TextStyle(
                          color: Theme.of(context).colorScheme.error)),
                ),
              if (has) ...[
                if (!_sort) _nowCard(p),
                if (_sort)
                  _sortList(p)
                else
                  for (final id in _order()) _sec(p, id),
              ],
              _Sec(
                  key: const ValueKey('s_set'),
                  title: tx('Kaynaklar ve ayarlar'),
                  icon: Icons.tune_rounded,
                  child: _settingsBody(p)),
            ],
          ),
        );
      },
    );
  }
}


class _TCell {
  final int? code;
  final String text;
  final bool night;
  final String sub; // ikinci satır (günlükte en düşük sıcaklık)
  _TCell(this.code, this.text, this.night, {this.sub = ''});
}

class _TRow {
  final String? head;
  final String label;
  final Map<String, _TCell> cells;
  _TRow(this.head, this.label, this.cells);
}
