import 'package:flutter/material.dart';
import 'data.dart';
import 'net.dart';
import 'strings.dart';
import 'theme.dart' show Pal;
import 'ui.dart';
import 'weather.dart' show wxIcon, wxColor;

// ---------------------------------------------------------------
// AYRINTILI HAVA (Araçlar): sıcaklık, hissedilen, nem, rüzgar, basınç,
// yağış, UV, görüş. Günlük (saatlik) / Haftalık / 15 günlük görünüm.
// Kaynak seçilebilir: Birleşik (MGM + Open-Meteo + MET), MGM, Open-Meteo,
// ECMWF, ICON, GFS, MET Norway. Kaynakta olmayan değer gösterilmez;
// her değerin altında kaynağı yazar. Deniz durumu dokununca açılır.
// ---------------------------------------------------------------

const _srcList = <List<String>>[
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
  return s.contains('.') ? s.replaceAll(RegExp(r'0+$'), '').replaceAll(RegExp(r'\.$'), '') : s;
}

class WxDetailPage extends StatefulWidget {
  const WxDetailPage({super.key});

  @override
  State<WxDetailPage> createState() => _WxDetailPageState();
}

class _WxDetailPageState extends State<WxDetailPage> {
  String _src = 'auto';
  WxDetail? _d;
  bool _loading = false;
  String? _err;
  int _tab = 0; // 0 günlük (saatlik), 1 haftalık, 2 15 gün

  WxMarine? _marine;
  bool _marineAsked = false;
  bool _marineLoading = false;
  String? _marineErr;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final lat = store.wxLat;
    final lon = store.wxLon;
    if (lat == null || lon == null) {
      setState(() => _err = tx('Konum yok. Önce Ayarlar\'dan hava durumunu aç (konum ya da şehir seç).'));
      return;
    }
    setState(() {
      _loading = true;
      _err = null;
    });
    try {
      final d = await fetchWxDetail(_src, lat, lon,
          place: store.wxGps ? '' : store.wxCity);
      if (!mounted) return;
      setState(() {
        _d = d;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      final t = e is WxError ? '${e.step}: ${e.detail}' : e.toString();
      setState(() {
        _loading = false;
        _d = null;
        _err = tx('Veri alınamadı: {0}', [t.length > 120 ? t.substring(0, 120) : t]);
      });
    }
  }

  Future<void> _loadMarine() async {
    final lat = store.wxLat;
    final lon = store.wxLon;
    if (lat == null || lon == null) return;
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

  // ---------- parçalar ----------
  Widget _stat(Pal p, IconData icon, String label, String value, String? src) {
    final w = (MediaQuery.of(context).size.width - 32 - 10) / 2;
    return Container(
      width: w,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: p.line),
      ),
      child: Row(
        children: [
          Icon(icon, color: p.accent, size: 26),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: TextStyle(color: p.soft, fontSize: 12)),
                Text(value,
                    style: TextStyle(
                        color: p.ink,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                if (src != null && src.isNotEmpty)
                  Text(src, style: TextStyle(color: p.soft, fontSize: 10)),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// Şimdiki durum kartı: yalnızca verisi olan değerler gösterilir
  Widget _nowCard(Pal p, WxPt n) {
    final tiles = <Widget>[];
    void add(IconData ic, String label, String key, String Function(double) fmtv) {
      final x = n.v[key];
      if (x == null) return;
      tiles.add(_stat(p, ic, label, fmtv(x), _short(n.s[key] ?? '')));
    }

    add(Icons.thermostat_rounded, tx('Hissedilen'), 'feels', (x) => '${_n(x)}°');
    add(Icons.water_drop_outlined, tx('Nem'), 'hum', (x) => '%${_n(x)}');
    // Rüzgar: hız + yön + hamle
    final w = n.v['wind'];
    if (w != null) {
      final dir = n.v['dir'];
      final g = n.v['gust'];
      final txt = StringBuffer('${_n(w)} ${tx('km/sa')}');
      if (dir != null) txt.write(' ${_compass(dir)}');
      if (g != null) txt.write(' (${tx('hamle')} ${_n(g)})');
      tiles.add(_stat(p, Icons.air_rounded, tx('Rüzgar'), txt.toString(),
          _short(n.s['wind'] ?? '')));
    }
    add(Icons.speed_rounded, tx('Basınç'), 'press', (x) => '${_n(x)} hPa');
    add(Icons.grain_rounded, tx('Yağış'), 'rain', (x) => '${_n(x, 1)} mm');
    add(Icons.wb_sunny_outlined, tx('UV'), 'uv', (x) => _n(x, 1));
    add(Icons.visibility_outlined, tx('Görüş'), 'vis', (x) => '${_n(x, 1)} km');
    add(Icons.cloud_outlined, tx('Bulut'), 'cloud', (x) => '%${_n(x)}');

    final temp = n.v['temp'];
    final code = n.code;
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: p.card,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: p.line),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              if (code != null)
                Icon(wxIcon(code), size: 46, color: wxColor(code)),
              const SizedBox(width: 12),
              if (temp != null)
                Text('${_n(temp)}°',
                    style: TextStyle(
                        fontSize: 46,
                        fontWeight: FontWeight.w300,
                        color: p.ink)),
              const Spacer(),
              Text(tx('Şimdi'), style: TextStyle(color: p.soft)),
            ],
          ),
          if (tiles.isNotEmpty) ...[
            const SizedBox(height: 12),
            Wrap(spacing: 10, runSpacing: 10, children: tiles),
          ],
        ],
      ),
    );
  }

  /// Satırdaki değerlerin kaynak kısaltmaları (tek kaynaksa gösterilmez)
  String _srcOf(WxPt x) {
    final set = <String>{for (final v in x.s.values) _short(v)};
    return set.length > 1 ? set.join('+') : '';
  }

  List<String> _parts(WxPt x, {bool daily = false}) {
    final o = <String>[];
    final pop = x.v['pop'];
    if (pop != null) o.add('%${_n(pop)} ${tx('yağış ihtimali')}');
    final rain = x.v['rain'];
    if (rain != null && rain > 0) o.add('${_n(rain, 1)} mm');
    final w = x.v['wind'];
    if (w != null) {
      final dir = x.v['dir'];
      o.add('${_n(w)} ${tx('km/sa')}${dir != null ? ' ${_compass(dir)}' : ''}');
    }
    final hum = x.v['hum'];
    if (hum != null) o.add('${tx('nem')} %${_n(hum)}');
    final uv = x.v['uv'];
    if (uv != null) o.add('UV ${_n(uv, 1)}');
    return o;
  }

  Widget _hourRow(Pal p, WxPt x) {
    final t = x.v['temp'];
    final code = x.code;
    final parts = _parts(x);
    final src = _srcOf(x);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          SizedBox(
            width: 48,
            child: Text('${x.t.hour.toString().padLeft(2, '0')}:00',
                style: TextStyle(color: p.soft, fontWeight: FontWeight.w600)),
          ),
          SizedBox(
            width: 30,
            child: code == null
                ? null
                : Icon(wxIcon(code, night: x.t.hour < 6 || x.t.hour >= 20),
                    size: 22, color: wxColor(code)),
          ),
          SizedBox(
            width: 46,
            child: Text(t == null ? '' : '${_n(t)}°',
                style: TextStyle(
                    color: p.ink, fontSize: 16, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(parts.join(' • '),
                style: TextStyle(color: p.soft, fontSize: 12)),
          ),
          if (src.isNotEmpty)
            Text(src, style: TextStyle(color: p.soft, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _dayRow(Pal p, WxPt x) {
    final hi = x.v['tmax'];
    final lo = x.v['tmin'];
    final code = x.code;
    final parts = _parts(x, daily: true);
    final src = _srcOf(x);
    String two(int n) => n.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        children: [
          SizedBox(
            width: 74,
            child: Text('${wdName(x.t.weekday)}\n${two(x.t.day)}.${two(x.t.month)}',
                style: TextStyle(color: p.ink, fontSize: 13, height: 1.25)),
          ),
          SizedBox(
            width: 30,
            child: code == null
                ? null
                : Icon(wxIcon(code), size: 22, color: wxColor(code)),
          ),
          SizedBox(
            width: 70,
            child: Text(
                '${hi == null ? '' : '${_n(hi)}°'}${lo == null ? '' : ' / ${_n(lo)}°'}',
                style: TextStyle(
                    color: p.ink, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
          Expanded(
            child: Text(parts.join(' • '),
                style: TextStyle(color: p.soft, fontSize: 11.5)),
          ),
          if (src.isNotEmpty)
            Text(src, style: TextStyle(color: p.soft, fontSize: 9)),
        ],
      ),
    );
  }

  Widget _list(Pal p, WxDetail d) {
    final now = DateTime.now();
    final rows = <Widget>[];
    if (_tab == 0) {
      final from = now.subtract(const Duration(minutes: 90));
      final to = now.add(const Duration(hours: 30));
      String lastDay = '';
      for (final x in d.hourly) {
        if (x.t.isBefore(from) || x.t.isAfter(to)) continue;
        final dk = dKey(DateTime(x.t.year, x.t.month, x.t.day));
        if (dk != lastDay) {
          lastDay = dk;
          rows.add(Padding(
            padding: const EdgeInsets.only(top: 8, bottom: 2),
            child: Text(
                dk == dKey(DateTime(now.year, now.month, now.day))
                    ? tx('Bugün')
                    : wdName(x.t.weekday),
                style: TextStyle(
                    color: p.accent, fontWeight: FontWeight.w700)),
          ));
        }
        rows.add(_hourRow(p, x));
      }
    } else {
      final today = DateTime(now.year, now.month, now.day);
      final max = _tab == 1 ? 7 : 16;
      var c = 0;
      for (final x in d.daily) {
        if (x.t.isBefore(today)) continue;
        if (c++ >= max) break;
        rows.add(_dayRow(p, x));
      }
    }
    if (rows.isEmpty) {
      return Padding(
        padding: const EdgeInsets.all(16),
        child: Text(tx('Bu görünüm için veri yok.'),
            style: TextStyle(color: p.soft)),
      );
    }
    return Column(children: rows);
  }

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
        padding: const EdgeInsets.all(16),
        child: Text(_marineErr ?? tx('Bu konumda deniz verisi yok.'),
            style: TextStyle(color: p.soft)),
      );
    }
    final n = m.now;
    final tiles = <Widget>[];
    if (n != null) {
      final h = n.v['wave'];
      if (h != null) {
        tiles.add(_stat(p, Icons.waves_rounded, tx('Dalga yüksekliği'),
            '${_n(h, 1)} m • ${_seaState(h)}', _short(n.s['wave'] ?? '')));
      }
      final dir = n.v['wdir'];
      if (dir != null) {
        tiles.add(_stat(p, Icons.explore_outlined, tx('Dalga yönü'),
            '${_compass(dir)} (${_n(dir)}°)', _short(n.s['wdir'] ?? '')));
      }
      final per = n.v['wper'];
      if (per != null) {
        tiles.add(_stat(p, Icons.timelapse_rounded, tx('Dalga periyodu'),
            '${_n(per, 1)} ${tx('sn')}', _short(n.s['wper'] ?? '')));
      }
      final sst = n.v['sst'];
      if (sst != null) {
        tiles.add(_stat(p, Icons.thermostat_rounded, tx('Deniz suyu sıcaklığı'),
            '${_n(sst, 1)}°', _short(n.s['sst'] ?? '')));
      }
      final sw = n.v['swell'];
      if (sw != null) {
        tiles.add(_stat(p, Icons.water_rounded, tx('Dalga (uzun)'),
            '${_n(sw, 1)} m', _short(n.s['swell'] ?? '')));
      }
    }
    String two(int n) => n.toString().padLeft(2, '0');
    return Padding(
      padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (tiles.isNotEmpty)
            Wrap(spacing: 10, runSpacing: 10, children: tiles),
          if (m.daily.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text(tx('Günlere göre en yüksek dalga'),
                style: TextStyle(color: p.soft, fontSize: 12)),
            for (final x in m.daily)
              Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    SizedBox(
                        width: 80,
                        child: Text(
                            '${wdName(x.t.weekday)} ${two(x.t.day)}.${two(x.t.month)}',
                            style: TextStyle(color: p.ink, fontSize: 13))),
                    Text(
                        [
                          if (x.v['wave'] != null)
                            '${_n(x.v['wave']!, 1)} m • ${_seaState(x.v['wave']!)}',
                          if (x.v['wper'] != null)
                            '${_n(x.v['wper']!, 1)} ${tx('sn')}',
                          if (x.v['wdir'] != null) _compass(x.v['wdir']!),
                        ].join(' • '),
                        style: TextStyle(color: p.soft, fontSize: 12)),
                  ],
                ),
              ),
          ],
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final d = _d;
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        title: Text(tx('Ayrıntılı hava')),
        actions: [
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
          Wrap(
            spacing: 8,
            runSpacing: 4,
            children: [
              for (final s in _srcList)
                ChoiceChip(
                  label: Text(s[0] == 'auto' ? tx(s[1]) : s[1]),
                  selected: _src == s[0],
                  onSelected: (_) {
                    if (_src == s[0]) return;
                    setState(() => _src = s[0]);
                    _load();
                  },
                ),
            ],
          ),
          const SizedBox(height: 10),
          if (_loading)
            const Padding(
                padding: EdgeInsets.all(30),
                child: Center(child: CircularProgressIndicator())),
          if (_err != null)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text(_err!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error)),
            ),
          if (d != null && !_loading) ...[
            if (d.now != null) _nowCard(p, d.now!),
            const SizedBox(height: 6),
            Text(
                tx('Kaynak: {0}', [d.used.join(', ')]) +
                    (d.notes.isEmpty ? '' : '  •  ${tx('alınamayan')}: ${d.notes.join('; ')}'),
                style: TextStyle(color: p.soft, fontSize: 11)),
            const SizedBox(height: 12),
            SegmentedButton<int>(
              segments: [
                ButtonSegment(value: 0, label: Text(tx('Günlük'))),
                ButtonSegment(value: 1, label: Text(tx('Haftalık'))),
                ButtonSegment(value: 2, label: Text(tx('15 gün'))),
              ],
              selected: {_tab},
              showSelectedIcon: false,
              onSelectionChanged: (s) => setState(() => _tab = s.first),
            ),
            const SizedBox(height: 4),
            _list(p, d),
            if (_tab == 2 && d.daily.length < 16)
              Padding(
                padding: const EdgeInsets.only(top: 6),
                child: Text(tx('Seçili kaynak bu kadar gün veriyor.'),
                    style: TextStyle(color: p.soft, fontSize: 11)),
              ),
            const SizedBox(height: 10),
            // Deniz durumu: dokununca açılır, o zaman veri çekilir
            Container(
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.line),
              ),
              child: Theme(
                data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  leading: Icon(Icons.sailing_rounded, color: p.accent),
                  title: Text(tx('Deniz durumu'),
                      style: TextStyle(
                          color: p.ink, fontWeight: FontWeight.w600)),
                  onExpansionChanged: (open) {
                    if (open && !_marineAsked) _loadMarine();
                  },
                  children: [_marineBody(p)],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
