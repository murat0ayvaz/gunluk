import 'dart:async';
import 'package:flutter/material.dart';
import 'data.dart';
import 'net.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// HAZIR HABER KAYNAKLARI
// Aşağıdaki adresler ADAY listesidir. Dokununca uygulama her birini kendisi
// dener (adres açılıyor mu, içinde haber var mı); yalnız çalışanlar listelenir.
// Adresler siteler tarafından değiştirilebilir; çalışmayan görünmez.
// Biçim: [konu, ad, adres]
// ---------------------------------------------------------------
const newsPresets = <List<String>>[
  // Gündem
  ['Gündem', 'TRT Haber - Gündem', 'https://www.trthaber.com/gundem.rss'],
  ['Gündem', 'TRT Haber - Son dakika', 'https://www.trthaber.com/sondakika.rss'],
  ['Gündem', 'BBC Türkçe', 'https://feeds.bbci.co.uk/turkce/rss.xml'],
  ['Gündem', 'DW Türkçe', 'https://rss.dw.com/rdf/rss-tur-all'],
  ['Gündem', 'Anadolu Ajansı - Güncel', 'https://www.aa.com.tr/tr/rss/default?cat=guncel'],
  ['Gündem', 'Euronews Türkçe', 'https://tr.euronews.com/rss?format=mrss'],
  ['Gündem', 'NTV - Gündem', 'https://www.ntv.com.tr/gundem.rss'],
  ['Gündem', 'CNN Türk', 'https://www.cnnturk.com/feed/rss/all/news'],
  ['Gündem', 'Habertürk', 'https://www.haberturk.com/rss'],
  ['Gündem', 'Hürriyet - Gündem', 'https://www.hurriyet.com.tr/rss/gundem'],
  ['Gündem', 'Milliyet - Gündem', 'https://www.milliyet.com.tr/rss/rssnew/gundemrss.xml'],
  ['Gündem', 'Cumhuriyet', 'https://www.cumhuriyet.com.tr/rss/son_dakika.xml'],
  ['Gündem', 'Sözcü', 'https://www.sozcu.com.tr/feeds-rss-category-gundem'],
  ['Gündem', 'Sabah - Gündem', 'https://www.sabah.com.tr/rss/gundem.xml'],
  ['Gündem', 'Yeni Şafak', 'https://www.yenisafak.com/rss?xml=anasayfa'],
  ['Gündem', 'Karar', 'https://www.karar.com/rss'],
  ['Gündem', 'T24', 'https://t24.com.tr/rss'],
  ['Gündem', 'Bianet', 'https://bianet.org/rss/bianet'],
  ['Gündem', 'Independent Türkçe', 'https://www.indyturk.com/rss.xml'],
  ['Gündem', 'Sakarya Yenihaber', 'https://www.sakaryayenihaber.com/rss'],
  // Ekonomi / borsa / finans
  ['Ekonomi ve borsa', 'TRT Haber - Ekonomi', 'https://www.trthaber.com/ekonomi.rss'],
  ['Ekonomi ve borsa', 'Bloomberg HT', 'https://www.bloomberght.com/rss'],
  ['Ekonomi ve borsa', 'Dünya', 'https://www.dunya.com/rss'],
  ['Ekonomi ve borsa', 'Ekonomim', 'https://www.ekonomim.com/rss'],
  ['Ekonomi ve borsa', 'NTV - Ekonomi', 'https://www.ntv.com.tr/ekonomi.rss'],
  ['Ekonomi ve borsa', 'Anadolu Ajansı - Ekonomi', 'https://www.aa.com.tr/tr/rss/default?cat=ekonomi'],
  ['Ekonomi ve borsa', 'Investing.com Türkçe', 'https://tr.investing.com/rss/news.rss'],
  ['Ekonomi ve borsa', 'Para Analiz', 'https://www.paraanaliz.com/feed/'],
  ['Ekonomi ve borsa', 'Borsagündem', 'https://www.borsagundem.com/rss'],
  ['Ekonomi ve borsa', 'Hürriyet - Ekonomi', 'https://www.hurriyet.com.tr/rss/ekonomi'],
  ['Ekonomi ve borsa', 'BBC Türkçe - Ekonomi', 'https://feeds.bbci.co.uk/turkce/ekonomi/rss.xml'],
  // Teknoloji ve bilim
  ['Teknoloji ve bilim', 'Webrazzi', 'https://webrazzi.com/feed/'],
  ['Teknoloji ve bilim', 'ShiftDelete.Net', 'https://shiftdelete.net/feed'],
  ['Teknoloji ve bilim', 'Donanım Haber', 'https://www.donanimhaber.com/rss/tum/'],
  ['Teknoloji ve bilim', 'Webtekno', 'https://www.webtekno.com/rss.xml'],
  ['Teknoloji ve bilim', 'Evrim Ağacı', 'https://evrimagaci.org/rss.xml'],
  ['Teknoloji ve bilim', 'Bilim ve Teknik (TÜBİTAK)', 'https://bilimteknik.tubitak.gov.tr/rss.xml'],
  ['Teknoloji ve bilim', 'TRT Haber - Bilim ve teknoloji', 'https://www.trthaber.com/bilim_teknoloji.rss'],
  ['Teknoloji ve bilim', 'NTV - Teknoloji', 'https://www.ntv.com.tr/teknoloji.rss'],
  ['Teknoloji ve bilim', 'Technopat', 'https://www.technopat.net/feed/'],
  ['Teknoloji ve bilim', 'Log', 'https://www.log.com.tr/feed/'],
  ['Teknoloji ve bilim', 'BBC Türkçe - Bilim ve teknoloji', 'https://feeds.bbci.co.uk/turkce/bilim-ve-teknoloji/rss.xml'],
  // Spor, kültür-sanat, sağlık
  ['Spor, kültür ve sağlık', 'TRT Haber - Spor', 'https://www.trthaber.com/spor.rss'],
  ['Spor, kültür ve sağlık', 'TRT Spor', 'https://www.trtspor.com.tr/rss/anasayfa.rss'],
  ['Spor, kültür ve sağlık', 'NTV - Spor', 'https://www.ntv.com.tr/spor.rss'],
  ['Spor, kültür ve sağlık', 'Fanatik', 'https://www.fanatik.com.tr/rss/anasayfa'],
  ['Spor, kültür ve sağlık', 'Fotomaç', 'https://www.fotomac.com.tr/rss/anasayfa.xml'],
  ['Spor, kültür ve sağlık', 'BBC Türkçe - Spor', 'https://feeds.bbci.co.uk/turkce/spor/rss.xml'],
  ['Spor, kültür ve sağlık', 'TRT Haber - Kültür sanat', 'https://www.trthaber.com/kultur_sanat.rss'],
  ['Spor, kültür ve sağlık', 'NTV - Sanat', 'https://www.ntv.com.tr/sanat.rss'],
  ['Spor, kültür ve sağlık', 'Hürriyet - Kültür sanat', 'https://www.hurriyet.com.tr/rss/kultur-sanat'],
  ['Spor, kültür ve sağlık', 'TRT Haber - Sağlık', 'https://www.trthaber.com/saglik.rss'],
  ['Spor, kültür ve sağlık', 'NTV - Sağlık', 'https://www.ntv.com.tr/saglik.rss'],
  ['Spor, kültür ve sağlık', 'Hürriyet - Sağlık', 'https://www.hurriyet.com.tr/rss/saglik'],
  // Yazarlar / köşe yazıları
  ['Köşe yazıları', 'Hürriyet - Yazarlar', 'https://www.hurriyet.com.tr/rss/yazarlar'],
  ['Köşe yazıları', 'Milliyet - Yazarlar', 'https://www.milliyet.com.tr/rss/rssnew/yazarlar.xml'],
  ['Köşe yazıları', 'Cumhuriyet - Yazarlar', 'https://www.cumhuriyet.com.tr/rss/yazarlar.xml'],
  ['Köşe yazıları', 'Habertürk - Yazarlar', 'https://www.haberturk.com/rss/yazarlar.xml'],
  ['Köşe yazıları', 'Sabah - Yazarlar', 'https://www.sabah.com.tr/rss/yazarlar.xml'],
  ['Köşe yazıları', 'Yeni Şafak - Yazarlar', 'https://www.yenisafak.com/rss?xml=yazarlar'],
  ['Köşe yazıları', 'Karar - Yazarlar', 'https://www.karar.com/rss/yazarlar'],
  ['Köşe yazıları', 'Sözcü - Yazarlar', 'https://www.sozcu.com.tr/feeds-rss-category-yazarlar'],
  // Resmi duyurular
  ['Resmi duyurular', 'Resmî Gazete', 'https://www.resmigazete.gov.tr/rss/gunluk.xml'],
  ['Resmi duyurular', 'Resmî Gazete (ana)', 'https://www.resmigazete.gov.tr/rss'],
  ['Resmi duyurular', 'KAP duyuruları', 'https://www.kap.org.tr/tr/rss/bildirim'],
  ['Resmi duyurular', 'SPK duyuruları', 'https://www.spk.gov.tr/RSS/Duyurular'],
  ['Resmi duyurular', 'TCMB duyuruları', 'https://www.tcmb.gov.tr/wps/wcm/connect/TR/TCMB+TR/Main+Menu/Duyurular/RSS'],
  ['Resmi duyurular', 'AFAD duyuruları', 'https://www.afad.gov.tr/rss'],
  ['Resmi duyurular', 'Adapazarı Belediyesi', 'https://www.adapazari.bel.tr/rss'],
  ['Resmi duyurular', 'Sakarya Büyükşehir Belediyesi', 'https://www.sakarya.bel.tr/rss'],
  ['Resmi duyurular', 'Sakarya Valiliği', 'https://www.sakarya.gov.tr/rss'],
  ['Resmi duyurular', 'Karasu Belediyesi', 'https://www.karasu.bel.tr/rss'],
];

/// Hazır kaynak penceresi: adayları dener, çalışanları işaretlenebilir listeler
Future<void> showNewsPresets(BuildContext context) => showDialog<void>(
    context: context, builder: (_) => const _PresetDialog());

class _PresetDialog extends StatefulWidget {
  const _PresetDialog();

  @override
  State<_PresetDialog> createState() => _PresetDialogState();
}

class _PresetDialogState extends State<_PresetDialog> {
  final List<List<String>> _ok = []; // çalışan adaylar
  final Set<String> _pick = {}; // seçilen adresler
  int _done = 0;
  bool _stop = false;

  Set<String> _have() =>
      {for (final c in store.newsCats) for (final s in c.srcs) s.url};

  @override
  void initState() {
    super.initState();
    _run();
  }

  @override
  void dispose() {
    _stop = true;
    super.dispose();
  }

  Future<bool> _test(String url) async {
    try {
      final l = await fetchNews(url, max: 3).timeout(const Duration(seconds: 10));
      return l.isNotEmpty;
    } catch (_) {
      return false;
    }
  }

  Future<void> _run() async {
    final have = _have();
    final todo = [
      for (final p in newsPresets)
        if (!have.contains(p[2])) p
    ];
    var next = 0;
    // aynı anda 6 adres denenir
    Future<void> worker() async {
      while (!_stop) {
        if (next >= todo.length) return;
        final p = todo[next++];
        final good = await _test(p[2]);
        if (_stop || !mounted) return;
        setState(() {
          _done++;
          if (good) _ok.add(p);
        });
      }
    }

    await Future.wait([for (var i = 0; i < 6; i++) worker()]);
    if (mounted) setState(() => _done = todo.length);
  }

  void _add() {
    for (final p in _ok) {
      if (!_pick.contains(p[2])) continue;
      var cat = store.newsCats.where((c) => c.name == p[0]).toList();
      if (cat.isEmpty) {
        store.addNewsCat(p[0]);
        cat = store.newsCats.where((c) => c.name == p[0]).toList();
      }
      store.saveNewsSrc(cat.first.id, null, p[1], p[2]);
    }
    Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final running = _done < _todoCount;
    final topics = <String>[];
    for (final x in _ok) {
      if (!topics.contains(x[0])) topics.add(x[0]);
    }
    return AlertDialog(
      title: Text(tx('Hazır kaynaklar')),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (running) ...[
              LinearProgressIndicator(
                  value: _todoCount == 0 ? null : _done / _todoCount),
              const SizedBox(height: 6),
              Text(tx('Kaynaklar deneniyor: {0}/{1}', ['$_done', '$_todoCount']),
                  style: TextStyle(color: p.soft, fontSize: 12.5)),
            ] else
              Text(
                  _ok.isEmpty
                      ? tx('Çalışan yeni kaynak bulunamadı. İnternetini kontrol edip tekrar dene.')
                      : tx('{0} çalışan kaynak bulundu.', ['${_ok.length}']),
                  style: TextStyle(color: p.soft, fontSize: 12.5)),
            const SizedBox(height: 6),
            Flexible(
              child: ListView(
                shrinkWrap: true,
                children: [
                  for (final t in topics) ...[
                    Padding(
                      padding: const EdgeInsets.only(top: 10, bottom: 2),
                      child: Text(tx(t),
                          style: TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w800,
                              color: p.ink)),
                    ),
                    for (final x in _ok.where((e) => e[0] == t))
                      CheckboxListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        controlAffinity: ListTileControlAffinity.leading,
                        title: Text(x[1]),
                        value: _pick.contains(x[2]),
                        onChanged: (v) => setState(() {
                          if (v == true) {
                            _pick.add(x[2]);
                          } else {
                            _pick.remove(x[2]);
                          }
                        }),
                      ),
                  ],
                ],
              ),
            ),
          ],
        ),
      ),
      actions: [
        if (_ok.isNotEmpty)
          TextButton(
              onPressed: () => setState(() {
                    if (_pick.length == _ok.length) {
                      _pick.clear();
                    } else {
                      _pick.addAll(_ok.map((e) => e[2]));
                    }
                  }),
              child: Text(_pick.length == _ok.length
                  ? tx('Seçimi kaldır')
                  : tx('Hepsini seç'))),
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(tx('Kapat'))),
        FilledButton(
            onPressed: _pick.isEmpty ? null : _add,
            child: Text(tx('Seçilenleri ekle'))),
      ],
    );
  }

  late final int _todoCount = () {
    final have = _have();
    return newsPresets.where((p) => !have.contains(p[2])).length;
  }();
}
