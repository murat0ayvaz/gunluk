import 'dart:async';
import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'dock.dart' show dockLaunch, dockLastTitle;
import 'main.dart' show navKey;
import 'media.dart';
import 'strings.dart';
import 'weather.dart';

// ---------------------------------------------------------------
// Ana ekran aracı (widget): hava durumu, radyo, TV ve rutinler.
//  - Uygulama bilgiyi buradan Android tarafına gönderir (kanal: gunluk/widget, "update").
//    Android tarafı kodu .github/workflows/build.yml içinde üretilir (GunlukWidget.kt).
//  - Araçtaki radyo düğmeleri çalan medyayı doğrudan denetler. Hiçbir şey çalmıyorsa uygulama açılır
//    ve son radyo çalınır. TV düğmesi uygulamayı açar ve TV'yi küçük pop-up olarak başlatır.
//  - Araçtan gelen istek (radyo / tv) "take" ile okunur: uygulama açılırken ve arka plandan dönerken.
// ---------------------------------------------------------------

class WidgetSvc {
  static const _ch = MethodChannel('gunluk/widget');
  Timer? _t;
  String _last = '';
  bool _started = false;

  /// Dinleyicileri kurar (bir kez) ve ilk bilgiyi gönderir
  void init() {
    if (_started) return;
    _started = true;
    store.addListener(_soon);
    media.addListener(_soon);
    weather.addListener(_soon);
    _soon();
  }

  /// Çok sık değişikliklerde yükü azaltmak için 1,5 sn bekleyip gönderir
  void _soon() {
    _t?.cancel();
    _t = Timer(const Duration(milliseconds: 1500), push);
  }

  String _wxEmoji(int? c, bool night) {
    if (c == null) return '';
    if (c == 0 || c == 1) return night ? '🌙' : '☀️';
    if (c == 2) return '⛅';
    if (c == 3) return '☁️';
    if (c == 45 || c == 48) return '🌫️';
    if ((c >= 51 && c <= 67) || (c >= 80 && c <= 82)) return '🌧️';
    if ((c >= 71 && c <= 77) || c == 85 || c == 86) return '❄️';
    if (c >= 95) return '⛈️';
    return '☁️';
  }

  String _wxLine() {
    final d = weather.data;
    if (!store.wxOn || d == null || d.nowTemp == null) return '';
    final hr = DateTime.now().hour;
    final code = d.nowCode;
    final desc = code == null ? '' : wxText(code);
    return '${_wxEmoji(code, hr < 6 || hr >= 20)} ${d.nowTemp!.round()}° $desc'.trim();
  }

  /// Bugünün rutinleri: (yapılan, toplam, yapılmayan ilk üç adı)
  (int, int, List<String>) _routines() {
    final now = DateTime.now();
    final date = dKey(now);
    var met = 0, total = 0;
    final open = <String>[];
    for (final c in store.cats) {
      for (final s in c.subs) {
        if (!s.scheduledOn(now)) continue;
        total++;
        final e = store.entryFor(s.id, date);
        final ok = e != null && goalMet(s, e.value);
        if (ok) {
          met++;
        } else if (open.length < 3) {
          open.add(s.name);
        }
      }
    }
    return (met, total, open);
  }

  Future<void> push() async {
    try {
      final active = media.nowId != null;
      final (artist, title) = media.nowSong;
      final song = title.isEmpty ? '' : (artist.isEmpty ? title : '$artist - $title');
      final (met, total, open) = _routines();
      final json = jsonEncode({
        'wx': _wxLine(),
        'rname': active ? media.nowTitle : dockLastTitle('radio'),
        'rsong': active ? song : '',
        'ractive': active,
        'rplaying': active && media.playing,
        'tv': dockLastTitle('tv'),
        'rtmet': met,
        'rttotal': total,
        'rt': open,
        'rthead': tx('Rutinler'),
        'rtnone': tx('Bugün için rutin yok'),
        'rtall': tx('Hepsi tamam'),
        'radiodef': tx('Radyo'),
        'tvdef': tx('TV'),
      });
      if (json == _last) return;
      _last = json;
      await _ch.invokeMethod('update', {'json': json});
    } catch (_) {
      // araç yoksa ya da kanal hazır değilse sessizce geçilir
    }
  }

  /// Araçtan gelen istek: "radio" (hiçbir şey çalmıyordu) ya da "tv"
  Future<void> takeAction() async {
    try {
      final a = await _ch.invokeMethod<String>('take');
      if (a == null || a.isEmpty) return;
      final ctx = navKey.currentContext;
      if (ctx == null || store.locked) return;
      if (a == 'radio') {
        if (media.nowId == null) {
          await dockLaunch(ctx, 'radio');
        } else {
          media.toggle();
        }
      } else if (a == 'tv') {
        await dockLaunch(ctx, 'tv');
      }
    } catch (_) {}
  }
}

final widgetSvc = WidgetSvc();
