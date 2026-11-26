import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:speech_to_text/speech_to_text.dart';
import 'ambient.dart';
import 'data.dart';
import 'dock.dart' show dockLaunch;
import 'links.dart';
import 'media.dart';
import 'news.dart';
import 'notify.dart';
import 'reminders.dart';
import 'shortcuts.dart';
import 'strings.dart';
import 'wake.dart';
import 'tools.dart';
import 'tv.dart';
import 'tvpop.dart';
import 'ui.dart';
import 'wallet.dart' show parseMoney, money;

// ---------------------------------------------------------------
// SESLİ KOMUT
//  Üst bardaki mikrofona basınca konuşulan cümle telefonun ses tanıma motoruyla
//  yazıya çevrilir, sonra KURAL TABANLI olarak (yapay zekasız) anlaşılır:
//   - hatırlat ...        : hatırlatıcı (tarih + saat cümleden alınır)
//   - yapılacak ...       : Yapılacaklar'a madde
//   - cüzdana 1200 lira peşin market harcaması ekle : cüzdana gider/gelir
//   - rutin kitap 5 sayfa : rutin değeri
//   - radyo aç / müzik aç / WhatsApp'ı aç ... : ilgili yeri açar
//   - haber oku, radyo çal [ad], durdur
//  Kayıt ekleyen komutlar önce onay penceresi gösterir; anlaşılmazsa hiçbir şey kaydedilmez.
// ---------------------------------------------------------------

/// Türkçe harfleri sadeleştirip küçük harfe çevirir (eşleştirme için)
String vNorm(String s) {
  final b = StringBuffer();
  for (final r in s.runes) {
    switch (r) {
      case 0x130: // İ
      case 0x49: // I
      case 0x131: // ı
        b.write('i');
        break;
      case 0xC7:
      case 0xE7:
        b.write('c');
        break;
      case 0x11E:
      case 0x11F:
        b.write('g');
        break;
      case 0xD6:
      case 0xF6:
        b.write('o');
        break;
      case 0x15E:
      case 0x15F:
        b.write('s');
        break;
      case 0xDC:
      case 0xFC:
        b.write('u');
        break;
      default:
        b.write(String.fromCharCode(r).toLowerCase());
    }
  }
  return b.toString();
}

String _capFirst(String s) {
  if (s.isEmpty) return s;
  final f = s.substring(0, 1);
  final up = f == 'i' ? 'İ' : (f == 'ı' ? 'I' : f.toUpperCase());
  return up + s.substring(1);
}

// ---------- Sayılar ----------
const _numWords = <String, int>{
  'bir': 1,
  'iki': 2,
  'uc': 3,
  'dort': 4,
  'bes': 5,
  'alti': 6,
  'yedi': 7,
  'sekiz': 8,
  'dokuz': 9,
  'on': 10,
  'yirmi': 20,
  'otuz': 30,
  'kirk': 40,
  'elli': 50,
  'altmis': 60,
  'yetmis': 70,
  'seksen': 80,
  'doksan': 90,
};

List<String> _numKeys() {
  final k = <String>[..._numWords.keys, 'yuz', 'bin', 'milyon'];
  k.sort((a, b) => b.length.compareTo(a.length));
  return k;
}

final List<String> _numKeyList = _numKeys();

/// "binikiyuz" / "bin iki yuz" (boşluksuz da olur) -> 1200; sayı değilse null
int? wordNum(String s) {
  if (s.isEmpty) return null;
  var pos = 0;
  var total = 0;
  var cur = 0;
  while (pos < s.length) {
    String? hit;
    for (final k in _numKeyList) {
      if (s.startsWith(k, pos)) {
        hit = k;
        break;
      }
    }
    if (hit == null) return null;
    pos += hit.length;
    if (hit == 'yuz') {
      cur = (cur == 0 ? 1 : cur) * 100;
    } else if (hit == 'bin') {
      total += (cur == 0 ? 1 : cur) * 1000;
      cur = 0;
    } else if (hit == 'milyon') {
      total += (cur == 0 ? 1 : cur) * 1000000;
      cur = 0;
    } else {
      cur += _numWords[hit]!;
    }
  }
  return total + cur;
}

final RegExp _digitTok = RegExp(r'^\d[\d.,]*$');

/// Cümledeki tutarı kuruş olarak bulur ("1200 lira", "bin iki yüz lira", "30 bin lira")
int? _amountKurus(List<String> nt, Set<int> used) {
  for (var i = 0; i < nt.length; i++) {
    final t = nt[i];
    if (!(t == 'tl' || t == 'try' || t.startsWith('lira'))) continue;
    final j = i - 1;
    if (j < 0) continue;
    if (_digitTok.hasMatch(nt[j])) {
      final v = parseMoney(nt[j]);
      if (v != null) {
        used.addAll([i, j]);
        return v;
      }
    }
    final run = <String>[];
    var k = j;
    while (k >= 0 && wordNum(nt[k]) != null) {
      run.insert(0, nt[k]);
      k--;
    }
    if (run.isEmpty) continue;
    final joined = run.join();
    if (k >= 0 &&
        RegExp(r'^\d+$').hasMatch(nt[k]) &&
        (joined == 'bin' || joined == 'milyon')) {
      final v = int.parse(nt[k]) * (wordNum(joined) ?? 0);
      if (v > 0) {
        for (var x = k; x <= i; x++) {
          used.add(x);
        }
        return v * 100;
      }
    }
    final v = wordNum(joined);
    if (v != null && v > 0) {
      for (var x = k + 1; x <= i; x++) {
        used.add(x);
      }
      return v * 100;
    }
  }
  for (var i = 0; i < nt.length; i++) {
    if (_digitTok.hasMatch(nt[i])) {
      final v = parseMoney(nt[i]);
      if (v != null) {
        used.add(i);
        return v;
      }
    }
  }
  return null;
}

// ---------- Tarih ve saat ----------
const _months = <String, int>{
  'ocak': 1,
  'subat': 2,
  'mart': 3,
  'nisan': 4,
  'mayis': 5,
  'haziran': 6,
  'temmuz': 7,
  'agustos': 8,
  'eylul': 9,
  'ekim': 10,
  'kasim': 11,
  'aralik': 12,
};

const _weekdays = <String, int>{
  'pazartesi': 1,
  'sali': 2,
  'carsamba': 3,
  'persembe': 4,
  'cumartesi': 6,
  'cuma': 5,
  'pazar': 7,
};

class _When {
  DateTime? date; // yalnız gün
  int? h;
  int? m;
  final Set<int> used = {};
}

final RegExp _hmStrictRe =
    RegExp(r"^(\d{1,2})(?:[:.](\d{2}))?(?:'?(?:te|ta|de|da|ye|ya))?$");

/// (saat, dakika); [strict] true ise ya ':' ya da ek (te/ta/de/da) şart
(int, int)? _hm(String t, {required bool strict}) {
  final m = _hmStrictRe.firstMatch(t);
  if (m != null) {
    final hasMin = m.group(2) != null;
    final hasSuffix = RegExp(r"(te|ta|de|da|ye|ya)$").hasMatch(t) &&
        !RegExp(r'^\d+[:.]\d+$').hasMatch(t);
    if (strict && !hasMin && !hasSuffix) return null;
    final h = int.parse(m.group(1)!);
    final mi = hasMin ? int.parse(m.group(2)!) : 0;
    if (h <= 24 && mi < 60) return (h, mi);
    return null;
  }
  final w = t.replaceFirst(RegExp(r"'?(te|ta|de|da|ye|ya)$"), '');
  if (strict && w == t) return null;
  final v = wordNum(w);
  if (v != null && v >= 1 && v <= 24) return (v, 0);
  return null;
}

_When parseWhen(List<String> nt) {
  final w = _When();
  final now = DateTime.now();
  final today = DateTime(now.year, now.month, now.day);
  String? period; // am | noon | pm | night
  for (var i = 0; i < nt.length; i++) {
    final t = nt[i];
    String? next(int o) => i + o < nt.length ? nt[i + o] : null;
    if (t == 'bugun') {
      w.date = today;
      w.used.add(i);
    } else if (t.startsWith('yarin')) {
      w.date = today.add(const Duration(days: 1));
      w.used.add(i);
    } else if (t == 'obur' && next(1) == 'gun') {
      w.date = today.add(const Duration(days: 2));
      w.used.addAll([i, i + 1]);
    } else if (t == 'haftaya') {
      w.date = today.add(const Duration(days: 7));
      w.used.add(i);
    } else if (next(1) == 'gun' && next(2) == 'sonra') {
      final n = int.tryParse(t) ?? wordNum(t);
      if (n != null && n > 0 && n < 1000) {
        w.date = today.add(Duration(days: n));
        w.used.addAll([i, i + 1, i + 2]);
      }
    } else if (RegExp(r'^\d{1,2}$').hasMatch(t) &&
        next(1) != null &&
        _months.keys.any((m) => next(1)!.startsWith(m))) {
      final d = int.parse(t);
      final mon = _months.entries.firstWhere((e) => next(1)!.startsWith(e.key)).value;
      if (d >= 1 && d <= 31) {
        var dt = DateTime(now.year, mon, d);
        if (dt.isBefore(today)) dt = DateTime(now.year + 1, mon, d);
        w.date = dt;
        w.used.addAll([i, i + 1]);
      }
    } else {
      for (final e in _weekdays.entries) {
        if (t.startsWith(e.key)) {
          var delta = (e.value - today.weekday + 7) % 7;
          if (delta == 0) delta = 7;
          w.date = today.add(Duration(days: delta));
          w.used.add(i);
          if (next(1) == 'gunu') w.used.add(i + 1);
          break;
        }
      }
    }
  }
  // saat
  for (var i = 0; i < nt.length; i++) {
    final t = nt[i];
    if (t == 'sabah' || t == 'sabahleyin') {
      period = 'am';
      w.used.add(i);
    } else if (t == 'ogleden' && i + 1 < nt.length && nt[i + 1] == 'sonra') {
      period = 'pm';
      w.used.addAll([i, i + 1]);
    } else if (t.startsWith('ogle')) {
      period = 'noon';
      w.used.add(i);
    } else if (t == 'aksam' || t == 'aksamleyin' || t == 'ikindi') {
      period = 'pm';
      w.used.add(i);
    } else if (t == 'gece') {
      period = 'night';
      w.used.add(i);
    }
  }
  (int, int)? hm;
  for (var i = 0; i < nt.length && hm == null; i++) {
    if (nt[i] == 'saat' && i + 1 < nt.length) {
      final r = _hm(nt[i + 1], strict: false);
      if (r != null) {
        hm = r;
        w.used.addAll([i, i + 1]);
      }
    }
  }
  if (hm == null && period != null) {
    // "akşam 7", "sabah 9'da"
    for (var i = 0; i < nt.length - 1 && hm == null; i++) {
      if (w.used.contains(i) && !w.used.contains(i + 1)) {
        final r = _hm(nt[i + 1], strict: false);
        if (r != null) {
          hm = r;
          w.used.add(i + 1);
        }
      }
    }
  }
  if (hm == null) {
    for (var i = 0; i < nt.length && hm == null; i++) {
      if (w.used.contains(i)) continue;
      final r = _hm(nt[i], strict: true);
      if (r != null) {
        hm = r;
        w.used.add(i);
      }
    }
  }
  if (hm != null) {
    var h = hm.$1;
    if (period == 'pm' && h < 12) {
      h += 12;
    } else if (period == 'noon' && h >= 1 && h <= 6) {
      h += 12;
    } else if (period == 'night' && h == 12) {
      h = 0;
    } else if (period == null && h >= 1 && h <= 6) {
      h += 12; // "3'te" -> 15:00 (onay penceresinde görülür)
    }
    if (h == 24) h = 0;
    w.h = h;
    w.m = hm.$2;
  }
  return w;
}

// ---------- Dinleme penceresi ----------
Future<String?> _listen(BuildContext context) => showDialog<String>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const _ListenDialog());

class _ListenDialog extends StatefulWidget {
  const _ListenDialog();

  @override
  State<_ListenDialog> createState() => _ListenDialogState();
}

class _ListenDialogState extends State<_ListenDialog> {
  final SpeechToText _stt = SpeechToText();
  String _text = '';
  String? _err;
  bool _done = false;
  bool _on = false;
  Timer? _auto; // konuşma durunca (1,5 sn) komut kendiliğinden çalışır

  @override
  void initState() {
    super.initState();
    _start();
  }

  @override
  void dispose() {
    _auto?.cancel();
    try {
      _stt.cancel();
    } catch (_) {}
    super.dispose();
  }

  Future<void> _start() async {
    var ok = false;
    try {
      ok = await _stt.initialize(
        onError: (e) {
          if (mounted && !_done && _text.isEmpty) {
            setState(() {
              _on = false;
              _err = tx('Ses anlaşılamadı. Tekrar dene.');
            });
          }
        },
        onStatus: (s) {
          if ((s == 'done' || s == 'notListening') && mounted && !_done) {
            if (_text.trim().isNotEmpty) {
              _finish(_text);
            } else {
              setState(() => _on = false);
            }
          }
        },
      );
    } catch (_) {
      ok = false;
    }
    if (!mounted) return;
    if (!ok) {
      setState(() => _err = tx(
          'Ses tanıma kullanılamıyor. Mikrofon iznini ve telefondaki Google ses tanımayı kontrol et.'));
      return;
    }
    setState(() {
      _on = true;
      _err = null;
    });
    try {
      await _stt.listen(
        onResult: (r) {
          if (!mounted || _done) return;
          setState(() => _text = r.recognizedWords);
          _auto?.cancel();
          if (r.finalResult && r.recognizedWords.trim().isNotEmpty) {
            _finish(r.recognizedWords);
          } else if (r.recognizedWords.trim().isNotEmpty) {
            // yeni kelime gelmezse 1,5 sn sonra bitir ("Bitti"ye basmaya gerek kalmaz)
            _auto = Timer(const Duration(milliseconds: 1500), () {
              if (mounted && !_done) _finish(_text);
            });
          }
        },
        localeId: 'tr_TR',
        listenFor: const Duration(seconds: 30),
        pauseFor: const Duration(seconds: 4),
      );
    } catch (_) {
      if (mounted) {
        setState(() {
          _on = false;
          _err = tx('Ses anlaşılamadı. Tekrar dene.');
        });
      }
    }
  }

  void _finish(String t) {
    if (_done) return;
    _done = true;
    _auto?.cancel();
    try {
      _stt.stop();
    } catch (_) {}
    Navigator.of(context).pop(t.trim());
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return AlertDialog(
      title: Text(tx('Sesli komut')),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedContainer(
            duration: const Duration(milliseconds: 400),
            width: _on ? 84 : 68,
            height: _on ? 84 : 68,
            decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: p.accent.withOpacity(_on ? 0.30 : 0.14)),
            child: Icon(_err != null ? Icons.mic_off_rounded : Icons.mic_rounded,
                size: 36, color: p.accent),
          ),
          const SizedBox(height: 12),
          Text(
              _err ??
                  (_text.isEmpty
                      ? (_on ? tx('Dinliyorum…') : tx('Hazırlanıyor…'))
                      : _text),
              textAlign: TextAlign.center,
              style: TextStyle(
                  fontSize: 16,
                  fontWeight: _text.isEmpty ? FontWeight.w400 : FontWeight.w600)),
          if (_text.isEmpty && _err == null) ...[
            const SizedBox(height: 10),
            Text(tx('Örnek: “Yarın saat 3\'te muayene hatırlat”'),
                textAlign: TextAlign.center,
                style: TextStyle(color: p.soft, fontSize: 12.5)),
          ],
        ],
      ),
      actions: [
        IconButton(
            tooltip: tx('Komut listesi'),
            icon: const Icon(Icons.help_outline_rounded),
            onPressed: () {
              _done = true;
              final nav = Navigator.of(context);
              nav.pop();
              nav.push(slideFromRight(const VoiceCommandsPage()));
            }),
        TextButton(
            onPressed: () {
              _done = true;
              Navigator.of(context).pop();
            },
            child: Text(tx('Vazgeç'))),
        if (_err != null)
          TextButton(
              onPressed: () {
                setState(() {
                  _err = null;
                  _text = '';
                });
                _start();
              },
              child: Text(tx('Tekrar dene'))),
        if (_err == null)
          FilledButton(
              onPressed: _text.trim().isEmpty ? null : () => _finish(_text),
              child: Text(tx('Bitti'))),
      ],
    );
  }
}

// ---------- Ana giriş ----------

/// Mikrofon düğmesi: dinler, anlar, çalıştırır
Future<void> voiceCommand(BuildContext context) async {
  final heard = await _listen(context);
  if (heard == null || heard.trim().isEmpty || !context.mounted) return;
  await runVoiceText(context, heard);
}

void _snack(BuildContext context, String m) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
}

FlutterTts? _sayTts;

/// Kısa sesli yanıt (Ayarlar > Sesli komut > Sesli yanıt açıksa)
Future<void> _say(String m) async {
  if (!store.voiceSpeak) return;
  try {
    final t = _sayTts ?? FlutterTts();
    if (_sayTts == null) {
      _sayTts = t;
      await t.setLanguage('tr-TR');
      await t.awaitSpeakCompletion(true);
    }
    await t.speak(m);
  } catch (_) {}
}

/// Başarılı işlem: yazılı bildirim + (açıksa) sesli yanıt
void _ok(BuildContext context, String m) {
  _snack(context, m);
  _say(m);
}

/// Komut radyoyu bilerek duraklattı ya da TV açtı: komuttan sonra radyo kendiliğinden devam etmesin
bool voiceHold = false;

/// Sürekli dinlemeyi aç/kapat (ana ekranda mikrofona uzun basınca)
void toggleContinuousListen() {
  HapticFeedback.mediumImpact();
  store.setVoiceListen(!store.voiceListen);
  voiceListener.sync();
}

int _lev(String a, String b) {
  if (a == b) return 0;
  if (a.isEmpty) return b.length;
  if (b.isEmpty) return a.length;
  var prev = List<int>.generate(b.length + 1, (i) => i);
  for (var i = 1; i <= a.length; i++) {
    final cur = List<int>.filled(b.length + 1, 0);
    cur[0] = i;
    for (var j = 1; j <= b.length; j++) {
      final c = a.codeUnitAt(i - 1) == b.codeUnitAt(j - 1) ? 0 : 1;
      var m = prev[j - 1] + c;
      if (prev[j] + 1 < m) m = prev[j] + 1;
      if (cur[j - 1] + 1 < m) m = cur[j - 1] + 1;
      cur[j] = m;
    }
    prev = cur;
  }
  return prev[b.length];
}

/// Anlaşılmayan cümleye en yakın hazır komut (yoksa null)
String? _nearestCommand(String heard) {
  final h = vNorm(heard).trim();
  if (h.isEmpty || h.length > 40) return null;
  const cmds = [
    'Radyo aç', 'Radyo kapat', 'Favori radyo çal', 'TV aç', 'TV kapat', 'Müzik aç',
    'Durdur', 'Duraklat', 'Devam et', 'Sonraki', 'Önceki', 'Sesi kıs', 'Sesi aç',
    'Sessize al', 'Haber oku', 'Saat kaç', 'Bugün ne yaptım', 'Şarkı ne',
    'Komut listesi', 'Ana sayfaya git',
  ];
  String? best;
  var bd = 999;
  for (final c in cmds) {
    final nc = vNorm(c);
    final d = _lev(h, nc);
    final lim = (nc.length * 0.4).floor().clamp(2, 5);
    if (d <= lim && d < bd) {
      bd = d;
      best = c;
    }
  }
  return best;
}

String _num(double v) =>
    v == v.roundToDouble() ? v.round().toString() : v.toStringAsFixed(1);

/// Verilen günlerdeki girişlerin özeti: "Su 2 litre, Kilo 82"
String _daySummary(List<String> dates, {required bool sum}) {
  final tot = <String, double>{};
  final last = <String, double>{};
  for (final e in store.entries) {
    if (!dates.contains(e.date)) continue;
    final sc = store.subById(e.sub);
    if (sc == null) continue;
    tot[e.sub] = (tot[e.sub] ?? 0) + e.value;
    last[e.sub] = e.value;
  }
  final parts = <String>[];
  for (final id in tot.keys) {
    final sc = store.subById(id)!;
    final v = (sum && sc.summable) ? tot[id]! : last[id]!;
    parts.add('${sc.name} ${_num(v)}${sc.unit.isEmpty ? '' : ' ${sc.unit}'}');
    if (parts.length >= 8) break;
  }
  return parts.join(', ');
}

Future<void> runVoiceText(BuildContext context, String heard) async {
  final raw = heard
      .replaceAll('₺', ' TL ')
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();
  final nt = [
    for (final r in raw) vNorm(r).replaceAll(RegExp(r'[.,!?;]+$'), '')
  ];
  final n = nt.join(' ');
  bool has(String k) => n.contains(k);
  final wantsOpen =
      RegExp(r'\b(ac\w*|git|goster\w*|baslat\w*|calistir\w*|izle\w*)\b').hasMatch(n);

  // 0) Komut listesi
  if ((has('komut') && (has('liste') || n.trim() == 'komutlar' || n.trim() == 'komut')) ||
      has('neler yapabilirsin') ||
      n.trim() == 'komutlar') {
    if (context.mounted) {
      await Navigator.of(context).push(slideFromRight(const VoiceCommandsPage()));
    }
    return;
  }
  final noData = !has('hatirla') && !has('yapilacak') && !has('cuzdan');
  final wantsStop =
      RegExp(r'\b(durdur\w*|sustur\w*|dur|kapat\w*|kapa|kapansin)\b').hasMatch(n);
  final tvWord = RegExp(r'\b(tv|televizyon)\b').hasMatch(n);
  final pageWord = RegExp(r'\b(sayfa\w*|ekran\w*|menu\w*|liste\w*|rehber\w*)\b').hasMatch(n);
  final playWord = RegExp(r'\b(cal\w*|ac\w*|baslat\w*|dinle\w*)\b').hasMatch(n);

  // 0b) Sürekli dinlemeyi kapat
  if (noData && wantsStop && has('dinle') && (has('surekli') || has('dinleme'))) {
    store.setVoiceListen(false);
    voiceListener.sync();
    _ok(context, tx('Sürekli dinleme kapatıldı.'));
    return;
  }
  // 0c) Ana sayfaya dön
  if ((has('ana sayfa') || has('ana ekran')) &&
      RegExp(r'\b(git|don\w*|gel\w*|ac\w*)\b').hasMatch(n)) {
    Navigator.of(context).popUntil((r) => r.isFirst);
    return;
  }
  // 0d) Bilgi soruları
  if (noData) {
    final now = DateTime.now();
    if (has('saat') && has('kac')) {
      final t = '${now.hour.toString().padLeft(2, '0')}:${now.minute.toString().padLeft(2, '0')}';
      _ok(context, tx('Saat {0}', [t]));
      return;
    }
    if (has('gunlerden') ||
        has('ne gun') ||
        (RegExp(r'\btarih').hasMatch(n) && nt.length <= 4 && !RegExp(r'\d').hasMatch(n))) {
      _ok(context, dateLabel(now));
      return;
    }
    if (has('bugun') && (has('yaptim') || has('ozet') || has('girdim'))) {
      final sm = _daySummary([dKey(now)], sum: true);
      _ok(context, sm.isEmpty ? tx('Bugün henüz veri girmedin.') : tx('Bugün: {0}', [sm]));
      return;
    }
    if (has('hafta') && (has('toplam') || has('yaptim') || has('ozet'))) {
      final mon = now.subtract(Duration(days: now.weekday - 1));
      final days = [for (var i = 0; i < 7; i++) dKey(mon.add(Duration(days: i)))];
      final sm = _daySummary(days, sum: true);
      _ok(context, sm.isEmpty ? tx('Bu hafta henüz veri yok.') : tx('Bu hafta: {0}', [sm]));
      return;
    }
    if (has('caliyor') || (has('sarki') && (has('hangi') || has('kim') || n.endsWith(' ne')))) {
      final (artist, title) = media.nowSong;
      if (title.isEmpty) {
        _snack(context, tx('Şu an çalan şarkı bilgisi yok.'));
      } else {
        _ok(context, artist.isEmpty ? title : '$artist - $title');
      }
      return;
    }
    if (has('istek') && has('ekle')) {
      final (artist, title) = media.nowSong;
      if (title.isEmpty) {
        _snack(context, tx('Şu an çalan şarkı bilgisi yok.'));
      } else {
        final added = store.addWish(
            title, artist, media.isRadio ? media.nowTitle : tx('Müzik'));
        _ok(context, added ? tx('İsteklerime eklendi.') : tx('Bu şarkı zaten İsteklerimde.'));
      }
      return;
    }
  }
  // 0e) Ses düzeyi (radyo, müzik, podcast)
  if ((noData && nt.length <= 5 && RegExp(r'\b(ses|sesi|sesini)\b').hasMatch(n)) ||
      has('sessize')) {
    if (media.nowId == null) {
      _snack(context, tx('Şu an bir şey çalmıyor.'));
      return;
    }
    var v = media.player.volume;
    if (has('sessize') || has('sessiz')) {
      v = 0;
    } else if (RegExp(r'\b(kis\w*|azalt\w*|alcalt\w*|dusur\w*)\b').hasMatch(n)) {
      v = (v - 0.2).clamp(0.0, 1.0).toDouble();
    } else if (RegExp(r'\b(ac\w*|arttir\w*|yukselt\w*|artir\w*|coalt\w*|yukari)\b').hasMatch(n) ||
        has('tam')) {
      v = has('tam') ? 1.0 : (v + 0.2).clamp(0.0, 1.0).toDouble();
    } else {
      v = -1;
    }
    if (v >= 0) {
      await media.player.setVolume(v);
      _ok(context, v == 0 ? tx('Ses kapatıldı.') : tx('Ses: %{0}', ['${(v * 100).round()}']));
      return;
    }
  }
  // 0f) Çalma kontrolü: duraklat, devam, sonraki, önceki
  if (noData && nt.length <= 4) {
    if (RegExp(r'\b(duraklat\w*|beklet\w*)\b').hasMatch(n)) {
      voiceHold = true;
      if (media.nowId != null && media.playing) media.toggle();
      if (newsReader.reading) await newsReader.pause();
      _snack(context, tx('Duraklatıldı.'));
      return;
    }
    if (RegExp(r'\b(devam\w*|surdur\w*|oynat\w*)\b').hasMatch(n)) {
      if (media.nowId != null && !media.playing) {
        media.toggle();
        _snack(context, tx('Devam ediyor.'));
      } else if (media.nowId == null) {
        _snack(context, tx('Devam edecek bir şey yok.'));
      }
      return;
    }
    final nextW = RegExp(r'\b(sonraki\w*|ileri|atla\w*)\b').hasMatch(n);
    final prevW = RegExp(r'\b(onceki\w*)\b').hasMatch(n);
    if ((nextW || prevW) && (media.nowId != null || tvPop.chan != null)) {
      final d = nextW ? 1 : -1;
      if (tvPop.chan != null) {
        tvPop.step(d);
      } else if (media.isRadio) {
        media.radioStep(d);
      } else if (media.isOnline) {
        media.nextOnline(step: d);
      } else if (media.isSong) {
        if (d > 0) {
          media.next();
        } else {
          media.prev();
        }
      } else if (media.isPod) {
        media.skipBy(d > 0 ? 30 : -10);
      }
      return;
    }
  }
  // 1) Durdur / kapat (hedef: radyo, TV, müzik, podcast, haber; hedef yoksa her şey)
  if (noData && wantsStop) {
    final radW = has('radyo');
    final musW = has('muzik') || has('sarki');
    final podW = has('podcast');
    if (tvWord) {
      if (tvPop.chan != null) {
        tvPop.close();
        _ok(context, tx('Durduruldu.'));
      } else {
        _snack(context, tx('TV açık değil.'));
      }
      return;
    }
    if (radW || musW || podW) {
      final match = (radW && media.isRadio) ||
          (musW && (media.isSong || media.isOnline)) ||
          (podW && media.isPod);
      if (match) {
        await media.stop();
        _ok(context, tx('Durduruldu.'));
      } else {
        _snack(context, tx('Şu an çalmıyor.'));
      }
      return;
    }
    if (has('haber')) {
      if (newsReader.reading) await newsReader.stop();
      _ok(context, tx('Durduruldu.'));
      return;
    }
    if (newsReader.reading) await newsReader.stop();
    if (media.nowId != null) await media.stop();
    tvPop.close();
    _ok(context, tx('Durduruldu.'));
    return;
  }
  // 2) Haber oku
  if (has('haber') && RegExp(r'\boku\w*').hasMatch(n)) {
    if (store.appHidden('media') || store.appHidden('news')) {
      {
      _snack(context, tx('Bu bölüm kapalı.'));
      return;
    }
    }
    _snack(context, tx('Haberler okunuyor…'));
    await startNewsReading(context);
    return;
  }
  // 3) Radyo çal
  if (has('radyo') &&
      RegExp(r'\b(cal(sin|sana|ar|abilir|si)?|ac\w*|baslat\w*|dinle\w*)\b').hasMatch(n) &&
      !RegExp(r'\b(sayfa\w*|ekran\w*|menu\w*|liste\w*)\b').hasMatch(n)) {
    await _playRadio(context, n); // "radyo aç": son çalan istasyon doğrudan çalar
    return;
  }
  // 3b) Müzik çal (son şarkı), son çalan
  if (has('muzik') && playWord && !pageWord) {
    if (store.appHidden('media') || store.appHidden('music')) {
      _snack(context, tx('Bu bölüm kapalı.'));
      return;
    }
    await dockLaunch(context, 'music');
    return;
  }
  if (has('son') && RegExp(r'\bcalan\w*').hasMatch(n)) {
    await dockLaunch(context, store.lastRadioId.isNotEmpty ? 'radio' : 'music');
    return;
  }
  // 4) Cüzdan
  if (has('cuzdan') || RegExp(r'\b(harcama\w*|gider\w*|maas\w*)\b').hasMatch(n)) {
    final used = <int>{};
    final amount = _amountKurus(nt, used);
    if (amount != null) {
      await _doWallet(context, heard, raw, nt, amount, used);
      return;
    }
    if (has('cuzdan')) {
      await openLink(context, 'in:tool:wallet');
      return;
    }
  }
  // 5) Hatırlatıcı
  if (has('hatirla')) {
    if (store.appHidden('rem')) {
      _snack(context, tx('Bu bölüm kapalı.'));
      return;
    }
    await _doReminder(context, heard, raw, nt);
    return;
  }
  // 6) Yapılacak
  if (has('yapilacak')) {
    if (store.appHidden('todo')) {
      _snack(context, tx('Bu bölüm kapalı.'));
      return;
    }
    await _doTodo(context, heard, raw, nt);
    return;
  }
  // 7) Aç (TV kanalı, kısayol uygulamaları, sonra uygulama içi yerler)
  if ((wantsOpen || nt.length <= 3) && !has('radyo')) {
    final chans = tvSorted()
      ..sort((a, b) => b.name.length.compareTo(a.name.length));
    for (final c in chans) {
      final nm = vNorm(c.name);
      if (nm.length >= 3 && n.contains(nm)) {
        if (store.appHidden('media') || store.appHidden('tv')) {
          _snack(context, tx('Bu bölüm kapalı.'));
          return;
        }
        voiceHold = true; // radyo komuttan sonra geri başlamasın
        tvPop.show(c);
        return;
      }
    }
    if (tvWord && !pageWord && wantsOpen) {
      if (store.appHidden('media') || store.appHidden('tv')) {
        _snack(context, tx('Bu bölüm kapalı.'));
        return;
      }
      voiceHold = true;
      await dockLaunch(context, 'tv');
      return;
    }
  }
  if (wantsOpen || nt.length <= 2) {
    for (final s in store.shortcuts) {
      final nm = vNorm(s.name);
      if (nm.length >= 3 && n.contains(nm)) {
        final ok = await AppsChannel.launch(s.pkg);
        if (!ok) _snack(context, tx('Uygulama açılamadı. Silinmiş olabilir.'));
        return;
      }
    }
    final link = _openTarget(n);
    if (link != null) {
      await openLink(context, link);
      return;
    }
  }
  // 8) Rutin değeri
  if (await _doRoutine(context, heard, nt)) return;
  // 9) Anlaşılmadı
  await _fallback(context, heard);
}

String? _openTarget(String n) {
  bool has(String k) => n.contains(k);
  if (has('radyo')) return 'in:media:radio';
  if (RegExp(r'\b(tv|televizyon|kanal\w*)\b').hasMatch(n)) return 'in:media:tv';
  if (has('muzik')) return 'in:media:music';
  if (has('podcast')) return 'in:media:podcast';
  if (has('haber')) return 'in:media:news';
  if (has('gunluk')) return 'in:diary';
  if (has('cuzdan')) return 'in:tool:wallet';
  if (has('kisayol')) return 'in:shortcuts';
  if (has('ayar')) return 'in:settings';
  if (has('kaza')) return 'in:tool:kaza';
  if (has('namaz') || has('vakit')) return 'in:tool:namaz';
  if (has('ders')) return 'in:study';
  for (final t in toolList()) {
    final nm = vNorm(t.$2);
    if (nm.length >= 3 && n.contains(nm)) return 'in:tool:${t.$1}';
  }
  return null;
}

// ---------- Radyo ----------
Future<void> _playRadio(BuildContext context, String n) async {
  if (store.appHidden('media') || store.appHidden('radio')) {
    {
      _snack(context, tx('Bu bölüm kapalı.'));
      return;
    }
  }
  final all = <Station>[for (final c in store.radCats) ...c.stations];
  if (all.isEmpty) {
    _snack(context, tx('Radyo listesi boş. Radyo sayfasından istasyon ekle.'));
    await openLink(context, 'in:media:radio');
    return;
  }
  // "radyo çal TRT FM": ad geçiyorsa onu bul
  var q = n
      .replaceAll(RegExp(r'\b(radyo\w*|cal\w*|ac\w*|baslat\w*|dinle\w*|lutfen|bir|bana|favori\w*)\b'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  Station? pick;
  if (q.isNotEmpty) {
    for (final s in all) {
      final nm = vNorm(s.name);
      if (nm.contains(q) || q.contains(nm)) {
        pick = s;
        break;
      }
    }
    if (pick == null) {
      for (final s in all) {
        final first = vNorm(s.name).split(' ').first;
        if (first.length >= 3 && q.contains(first)) {
          pick = s;
          break;
        }
      }
    }
  }
  Station chosen = all.first;
  final wantsFav = n.contains('favori');
  if (pick != null) {
    chosen = pick;
  } else if (wantsFav && all.any((x) => x.fav)) {
    final favs = all.where((x) => x.fav).toList();
    chosen = favs.firstWhere((x) => x.id == store.lastRadioId, orElse: () => favs.first);
  } else {
    var found = false;
    for (final s in all) {
      if (s.id == store.lastRadioId) {
        chosen = s;
        found = true;
        break;
      }
    }
    if (!found) {
      for (final s in all) {
        if (s.fav) {
          chosen = s;
          break;
        }
      }
    }
  }
  tvPop.close();
  await media.playStation(chosen);
  if (context.mounted) _snack(context, tx('Çalıyor: {0}', [chosen.name]));
}

// ---------- Onay penceresi ----------
Future<bool> _confirm(BuildContext context, String title,
    Widget Function(BuildContext, StateSetter) body,
    {bool Function()? canOk, String okLabel = '', bool skip = false}) async {
  // Ayarlarda "onay iste" kapalıysa ve komut eksiksiz anlaşıldıysa pencere açılmaz
  if (skip && !store.voiceConfirm) return true;
  final r = await showDialog<bool>(
    context: context,
    builder: (ctx) => StatefulBuilder(
      builder: (ctx, set) => AlertDialog(
        title: Text(title),
        content: SingleChildScrollView(child: body(ctx, set)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text(tx('Vazgeç'))),
          FilledButton(
              onPressed: (canOk == null || canOk())
                  ? () => Navigator.pop(ctx, true)
                  : null,
              child: Text(okLabel.isEmpty ? tx('Ekle') : okLabel)),
        ],
      ),
    ),
  );
  return r == true;
}

Widget _heardLine(BuildContext context, String heard) => Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Text('${tx('Duyduğum')}: “$heard”',
          style: TextStyle(color: palOf(context).soft, fontSize: 12.5)),
    );

String _fmtWhen(DateTime d) {
  String two(int x) => x.toString().padLeft(2, '0');
  return '${two(d.day)}.${two(d.month)}.${d.year} ${two(d.hour)}:${two(d.minute)}';
}

// ---------- Hatırlatıcı ----------
const _reminderStop = {
  'bana', 'ekle', 'lutfen', 'saat', 'misin', 'misiniz', 'olarak', 'rica'
};

Future<void> _doReminder(BuildContext context, String heard, List<String> raw,
    List<String> nt) async {
  final w = parseWhen(nt);
  final now = DateTime.now();
  int? ms;
  if (w.h != null) {
    final d = w.date ?? DateTime(now.year, now.month, now.day);
    var dt = DateTime(d.year, d.month, d.day, w.h!, w.m ?? 0);
    if (w.date == null && !dt.isAfter(now)) {
      dt = dt.add(const Duration(days: 1));
    }
    ms = dt.millisecondsSinceEpoch;
  }
  final words = <String>[];
  for (var i = 0; i < raw.length; i++) {
    if (w.used.contains(i)) continue;
    final t = nt[i];
    if (t.startsWith('hatirla') || _reminderStop.contains(t)) continue;
    words.add(raw[i]);
  }
  final c = TextEditingController(text: _capFirst(words.join(' ')));
  final ok = await _confirm(
    context,
    tx('Hatırlatıcı eklensin mi?'),
    (ctx, set) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heardLine(ctx, heard),
        TextField(
          controller: c,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => set(() {}),
          decoration: InputDecoration(
              labelText: tx('Ne hatırlatılsın?'),
              border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 10),
        Row(children: [
          Icon(Icons.alarm_rounded, size: 20, color: palOf(ctx).accent),
          const SizedBox(width: 8),
          Expanded(
              child: Text(
                  ms == null
                      ? tx('Zaman seçilmedi')
                      : _fmtWhen(DateTime.fromMillisecondsSinceEpoch(ms!)),
                  style: const TextStyle(
                      fontSize: 16, fontWeight: FontWeight.w700))),
          TextButton(
              onPressed: () async {
                final v = await pickDateTime(ctx, initialMs: ms);
                if (v != null) set(() => ms = v);
              },
              child: Text(ms == null ? tx('Seç') : tx('Değiştir'))),
        ]),
      ],
    ),
    canOk: () => c.text.trim().isNotEmpty && ms != null,
    skip: ms != null && c.text.trim().isNotEmpty,
  );
  final text = c.text.trim();
  c.dispose();
  if (!ok || ms == null || text.isEmpty) return;
  final dt = DateTime.fromMillisecondsSinceEpoch(ms!);
  final r = store.addReminder(Reminder(
    id: store.newId(),
    nid: store.newNid(),
    text: text,
    kind: 'once',
    startMs: ms!,
    count: 1,
    hour: dt.hour,
    minute: dt.minute,
  ));
  final msg = await permissionMessage();
  await Notifier.syncReminder(r);
  if (context.mounted) {
    _snack(context, msg ?? tx('Hatırlatıcı eklendi.'));
    _say(tx('Hatırlatıcı eklendi.'));
  }
}

// ---------- Yapılacak ----------
Future<void> _doTodo(BuildContext context, String heard, List<String> raw,
    List<String> nt) async {
  final w = parseWhen(nt);
  final words = <String>[];
  for (var i = 0; i < raw.length; i++) {
    if (w.used.contains(i)) continue;
    final t = nt[i];
    if (t.startsWith('yapilacak') || t == 'ekle' || t == 'lutfen') continue;
    words.add(raw[i]);
  }
  final day = w.date ?? DateTime.now();
  final c = TextEditingController(text: _capFirst(words.join(' ')));
  final ok = await _confirm(
    context,
    tx('Yapılacaklara eklensin mi?'),
    (ctx, set) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heardLine(ctx, heard),
        TextField(
          controller: c,
          textCapitalization: TextCapitalization.sentences,
          onChanged: (_) => set(() {}),
          decoration: InputDecoration(
              labelText: tx('Madde'), border: const OutlineInputBorder()),
        ),
        const SizedBox(height: 8),
        Text(dKey(day), style: TextStyle(color: palOf(ctx).soft)),
      ],
    ),
    canOk: () => c.text.trim().isNotEmpty,
    skip: c.text.trim().isNotEmpty,
  );
  final text = c.text.trim();
  c.dispose();
  if (!ok || text.isEmpty) return;
  store.addTodo(text, day: dKey(day));
  _ok(context, tx('Yapılacaklara eklendi.'));
}

// ---------- Cüzdan ----------
const _walletStop = {
  'cuzdan', 'cuzdana', 'cuzdanima', 'cuzdanda', 'lira', 'tl', 'ekle', 'harcama',
  'harcamasi', 'gider', 'gideri', 'gelir', 'geliri', 'pesin', 'pesinle',
  'kredi', 'karti', 'kartla', 'banka', 'bankakarti', 'lutfen', 'olarak', 'maas'
};

Future<void> _doWallet(BuildContext context, String heard, List<String> raw,
    List<String> nt, int amount, Set<int> used) async {
  if (store.appHidden('wallet') || store.hiddenTools.contains('wallet')) {
    {
      _snack(context, tx('Bu bölüm kapalı.'));
      return;
    }
  }
  if (store.wallets.isEmpty) {
    _snack(context, tx('Önce Cüzdan\'da bir cüzdan oluştur.'));
    await openLink(context, 'in:tool:wallet');
    return;
  }
  final n = nt.join(' ');
  final income = RegExp(r'\b(gelir\w*|maas\w*|gelen)\b').hasMatch(n);
  var pay = 0;
  if (n.contains('kredi')) {
    pay = 1;
  } else if (n.contains('banka')) {
    pay = 2;
  }
  // Cüzdan: adı geçiyorsa o, yoksa seçili / ilk
  Wallet wal = store.wallets.first;
  final sel = store.walletSel;
  for (final x in store.wallets) {
    if (x.id == sel) wal = x;
  }
  for (final x in store.wallets) {
    final nm = vNorm(x.name);
    if (nm.length >= 2 && n.contains(nm)) wal = x;
  }
  final cats = income ? store.walletIncCats : store.walletExpCats;
  String? cat;
  final catTokens = <int>{};
  for (final cname in cats) {
    final cn = vNorm(cname);
    if (cn.length >= 3 && n.contains(cn)) {
      cat = cname;
      for (var i = 0; i < nt.length; i++) {
        if (nt[i].contains(cn)) catTokens.add(i);
      }
      break;
    }
  }
  cat ??= () {
    for (final cname in cats) {
      if (vNorm(cname).contains('diger')) return cname;
    }
    return cats.isEmpty ? '' : cats.first;
  }();
  final noteWords = <String>[];
  for (var i = 0; i < raw.length; i++) {
    if (used.contains(i) || catTokens.contains(i)) continue;
    if (_walletStop.contains(nt[i])) continue;
    if (nt[i].startsWith('cuzdan')) continue;
    noteWords.add(raw[i]);
  }
  final note = TextEditingController(text: noteWords.join(' '));
  var curCat = cat ?? '';
  var curPay = pay;
  var curIncome = income;
  var curWal = wal;
  final names = [tx('Peşin'), tx('Kredi kartı'), tx('Banka kartı')];
  final ok = await _confirm(
    context,
    tx('Cüzdana eklensin mi?'),
    (ctx, set) {
      final list = curIncome ? store.walletIncCats : store.walletExpCats;
      if (!list.contains(curCat) && list.isNotEmpty) curCat = list.first;
      return Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _heardLine(ctx, heard),
          Text(money(amount),
              style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w800)),
          const SizedBox(height: 8),
          Wrap(spacing: 8, children: [
            ChoiceChip(
                label: Text(tx('Gider')),
                selected: !curIncome,
                onSelected: (_) => set(() => curIncome = false)),
            ChoiceChip(
                label: Text(tx('Gelir')),
                selected: curIncome,
                onSelected: (_) => set(() => curIncome = true)),
          ]),
          if (!curIncome) ...[
            const SizedBox(height: 6),
            Wrap(spacing: 8, children: [
              for (var i = 0; i < 3; i++)
                ChoiceChip(
                    label: Text(names[i]),
                    selected: curPay == i,
                    onSelected: (_) => set(() => curPay = i)),
            ]),
          ],
          const SizedBox(height: 6),
          if (list.isNotEmpty)
            DropdownButton<String>(
              isExpanded: true,
              value: curCat,
              items: [
                for (final c in list)
                  DropdownMenuItem(value: c, child: Text(c))
              ],
              onChanged: (v) => set(() => curCat = v ?? curCat),
            ),
          if (store.wallets.length > 1)
            DropdownButton<String>(
              isExpanded: true,
              value: curWal.id,
              items: [
                for (final x in store.wallets)
                  DropdownMenuItem(value: x.id, child: Text(x.name))
              ],
              onChanged: (v) => set(() {
                for (final x in store.wallets) {
                  if (x.id == v) curWal = x;
                }
              }),
            ),
          TextField(
            controller: note,
            decoration: InputDecoration(labelText: tx('Not')),
          ),
        ],
      );
    },
    skip: true,
  );
  final noteText = note.text.trim();
  note.dispose();
  if (!ok) return;
  final d = DateTime.now();
  store.walletAddTx(WalletTx(
      store.newId(),
      curWal.id,
      DateTime(d.year, d.month, d.day).millisecondsSinceEpoch,
      amount,
      curIncome,
      curCat,
      curIncome ? 0 : curPay,
      noteText));
  _ok(context, tx('Cüzdana eklendi.'));
}

// ---------- Rutin değeri ----------
Future<bool> _doRoutine(
    BuildContext context, String heard, List<String> nt) async {
  final n = nt.join(' ');
  SubCat? best;
  for (final c in store.cats) {
    for (final s in c.subs) {
      final nm = vNorm(s.name);
      if (nm.length < 3 || !n.contains(nm)) continue;
      if (best == null || nm.length > vNorm(best.name).length) best = s;
    }
  }
  if (best == null) return false;
  double? v;
  for (final t in nt) {
    if (RegExp(r'^\d+(?:[.,]\d+)?$').hasMatch(t)) {
      v = double.tryParse(t.replaceAll(',', '.'));
      break;
    }
  }
  if (v == null) {
    final run = <String>[];
    for (final t in nt) {
      if (wordNum(t) != null) {
        run.add(t);
      } else if (run.isNotEmpty) {
        break;
      }
    }
    if (run.isNotEmpty) v = wordNum(run.join())?.toDouble();
  }
  if (v == null) return false;
  final sub = best;
  final val = v;
  final date = dKey(DateTime.now());
  final ex = store.entryFor(sub.id, date);
  final ok = await _confirm(
    context,
    tx('Rutin değeri girilsin mi?'),
    (ctx, set) => Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _heardLine(ctx, heard),
        Text('${sub.name}: ${plain(val)} ${sub.unit}'.trim(),
            style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w800)),
        if (ex != null) ...[
          const SizedBox(height: 8),
          Text(
              tx('Bugün için mevcut değer {0}; yenisi bunun yerine yazılır.',
                  [plain(ex.value)]),
              style: TextStyle(color: palOf(ctx).soft)),
        ],
      ],
    ),
    okLabel: tx('Gir'),
    skip: true,
  );
  if (!ok) return true;
  store.setEntry(sub.id, date, val);
  _ok(context, tx('Değer girildi.'));
  return true;
}

// ---------- Anlaşılmadı ----------
Future<void> _fallback(BuildContext context, String heard) async {
  final sug = _nearestCommand(heard);
  final r = await showDialog<String>(
    context: context,
    builder: (ctx) => AlertDialog(
      title: Text(tx('Anlayamadım')),
      content: Text(sug == null
          ? '“$heard”\n\n${tx('Ne yapılsın?')}'
          : '“$heard”\n\n${tx('Şunu mu demek istedin: “{0}”?', [sug])}'),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(ctx), child: Text(tx('Vazgeç'))),
        if (sug != null)
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'sug'),
              child: Text(tx('Evet, bunu yap'))),
        TextButton(
            onPressed: () => Navigator.pop(ctx, 'again'),
            child: Text(tx('Tekrar söyle'))),
        if (!store.appHidden('todo'))
          FilledButton(
              onPressed: () => Navigator.pop(ctx, 'todo'),
              child: Text(tx('Yapılacaklara ekle'))),
      ],
    ),
  );
  if (!context.mounted) return;
  if (r == 'again') {
    await voiceCommand(context);
  } else if (r == 'sug' && sug != null) {
    await runVoiceText(context, sug);
  } else if (r == 'todo') {
    final raw = heard.trim().split(RegExp(r'\s+'));
    await _doTodo(context, heard, raw, [for (final x in raw) vNorm(x)]);
  }
}


// ---------------------------------------------------------------
// SÜREKLİ DİNLEME (Ayarlar > Sesli komut > Sürekli dinle)
//  Uygulama ön plandayken mikrofon uyandırma kelimesini ("Günlük" ...) bekler.
//  Cümle uyandırma kelimesiyle başlıyorsa kalanı komut olarak çalıştırılır;
//  yalnız kelime söylenirse dinleme penceresi açılır. Kelime yoksa cümle yok sayılır.
//  Uygulama arka plana geçince ya da komut çalışırken dinleme durur.
// ---------------------------------------------------------------
class VoiceListener extends ChangeNotifier with WidgetsBindingObserver {
  final SpeechToText _stt = SpeechToText();
  BuildContext? ctx; // ana ekranın bağlamı (pencereler bunun üstünde açılır)
  bool listening = false; // şu an mikrofon açık mı (göstergede görünür)
  String lastHeard = ''; // en son duyulan söz (ana ekran şeridinde ve durum panelinde görünür)

  void _hear(String t) {
    final x = t.trim();
    if (x.isEmpty || x == lastHeard) return;
    lastHeard = x.length > 60 ? '…${x.substring(x.length - 60)}' : x;
    notifyListeners();
  }
  bool _want = false; // dinleme istendi mi
  bool _busy = false; // komut işleniyor / başka mikrofon kullanımı
  bool _inited = false;
  bool _observing = false;
  bool _fg = true; // uygulama ön planda mı
  int _gen = 0;

  /// Ayara göre başlatır ya da durdurur
  Future<void> sync() async {
    if (!_observing) {
      _observing = true;
      WidgetsBinding.instance.addObserver(this);
    }
    if (store.voiceListen) {
      _want = true;
      await _loop();
    } else {
      _want = false;
      await _halt();
    }
  }

  /// Çevrimdışı motor hazır olunca dinlemeyi o motorla yeniden başlatır
  Future<void> engineChanged() async {
    if (!_want || !store.voiceListen) return;
    await _halt();
    _loop();
  }

  /// Başka bir mikrofon kullanımı (ses kaydı gibi) için geçici durdurma
  Future<void> pause() async {
    _busy = true;
    await _halt();
  }

  void resume() {
    _busy = false;
    if (_want && store.voiceListen) _loop();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      _fg = true;
      if (_want && store.voiceListen && !_busy) _loop();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      _fg = false;
      _halt();
    }
  }

  Future<void> _halt() async {
    _gen++;
    _wakeTimer?.cancel();
    try {
      await wakeEngine.stop();
      await _stt.cancel();
    } catch (_) {}
    if (listening) {
      listening = false;
      notifyListeners();
    }
  }

  Future<void> _loop() async {
    if (!_want || _busy || !_fg || listening) return;
    final g = ++_gen;
    // Çevrimdışı motor hazırsa o dinler (bip yok, kesinti yok); değilse eski yöntem
    if (wakeEngine.ready && wakeEngine.enabled) {
      final ok = await wakeEngine.start(
        (t) {
          if (g == _gen) _onPartial(t);
        },
        (t) {
          if (g == _gen) _onFinal(t);
        },
      );
      if (ok) {
        listening = true;
        notifyListeners();
        return;
      }
    }
    if (!_inited) {
      try {
        _inited = await _stt.initialize(
          // Olaylar her zaman o anki dinleme turuna sayılır (_gen); ilk turun g'sine bağlı kalmaz
          onStatus: (s) {
            if (s == 'done' || s == 'notListening') _restart(_gen);
          },
          onError: (e) => _restart(_gen, delay: 1500),
        );
      } catch (_) {
        _inited = false;
      }
      if (!_inited) return;
    }
    if (g != _gen) return;
    try {
      listening = true;
      notifyListeners();
      await _stt.listen(
        onResult: (r) {
          if (g != _gen) return;
          if (r.finalResult) {
            _onFinal(r.recognizedWords);
          } else {
            _onPartial(r.recognizedWords); // ara sonuçlardan da uyandır
          }
        },
        localeId: 'tr_TR',
        listenFor: const Duration(seconds: 55),
        pauseFor: const Duration(seconds: 4),
      );
    } catch (_) {
      listening = false;
      notifyListeners();
      _restart(g, delay: 2000);
    }
  }

  void _restart(int g, {int delay = 500}) {
    if (g != _gen) return;
    listening = false;
    notifyListeners();
    Future<void>.delayed(Duration(milliseconds: delay), () {
      if (_want && !_busy && _fg && g == _gen && store.voiceListen) {
        _gen++; // eski oturumun olayları geçersiz
        _loop();
      }
    });
  }

  // ---- Uyandırma kelimesi ----
  Timer? _wakeTimer; // ara sonuçta kelime duyulunca kısa bekleme (cümle bitsin)
  bool _firing = false;

  // Küçük model uyandırma kelimesini sık yanlış duyar: yakın okunuşlar da kabul edilir
  static const _wakeAlias = <String, List<String>>{
    'gunluk': ['gunlu', 'gonluk', 'gunler', 'kunluk', 'gunluh', 'gunlug'],
    'asistan': ['asistam', 'asistant', 'sistan', 'asistani'],
    'bilgisayar': ['bilgisayer', 'bilgisayarr', 'bilgi sayar'],
    'kaptan': ['kapitan', 'kaptam'],
    'komutan': ['komutam', 'komutanm'],
  };

  bool _wakeTok(String a, String b) {
    if (a.startsWith(b)) return true;
    for (final al in _wakeAlias[b] ?? const <String>[]) {
      if (a == al || a.startsWith(al)) return true;
    }
    final tol = b.length >= 8 ? 2 : (b.length >= 5 ? 1 : 0);
    if (tol == 0) return false;
    for (final len in [b.length - 1, b.length, b.length + 1]) {
      if (len > 0 && len <= a.length && _lev(a.substring(0, len), b) <= tol) return true;
    }
    return false;
  }

  /// Kelimeler arasında uyandırma kelimesini arar: (başlangıç, kullanılan kelime sayısı)
  (int, int)? _wakeAt(List<String> nt) {
    final wake = vNorm(store.voiceWake)
        .trim()
        .split(RegExp(r'\s+'))
        .where((e) => e.isNotEmpty)
        .toList();
    if (wake.isEmpty) return null;
    for (var i = 0; i + wake.length <= nt.length && i <= 1; i++) {
      var ok = true;
      for (var j = 0; j < wake.length; j++) {
        final a = nt[i + j];
        final b = wake[j];
        if (!(j == wake.length - 1 ? _wakeTok(a, b) : a == b)) {
          ok = false;
          break;
        }
      }
      if (ok) return (i, wake.length);
    }
    // Tek kelimelik uyandırma "gün lük" gibi bölünerek duyulabilir
    if (wake.length == 1) {
      for (var i = 0; i + 1 < nt.length && i <= 1; i++) {
        if (nt[i].length >= 2 && (nt[i] + nt[i + 1]).startsWith(wake[0])) {
          return (i, 2);
        }
      }
    }
    return null;
  }

  List<String> _split(String text) => text
      .trim()
      .split(RegExp(r'\s+'))
      .where((e) => e.isNotEmpty)
      .toList();

  /// Konuşma sürerken gelen ara sonuç: kelime duyulur duyulmaz komut ekranı açılır
  void _onPartial(String text) {
    final raw = _split(text);
    if (raw.isEmpty || _firing) return;
    _hear(text);
    final nt = [for (final r in raw) vNorm(r).replaceAll(RegExp(r'[.,!?;]+$'), '')];
    final w = _wakeAt(nt);
    if (w == null) {
      _wakeTimer?.cancel();
      return;
    }
    final cmd = raw.sublist(w.$1 + w.$2).join(' ').trim();
    _wakeTimer?.cancel();
    // yalnız kelime: kısa bekle ve komut ekranını aç; komut da varsa cümle durana kadar bekle
    _wakeTimer = Timer(Duration(milliseconds: cmd.isEmpty ? 800 : 1600), () {
      _fire(cmd);
    });
  }

  Future<void> _onFinal(String text) async {
    final raw = _split(text);
    if (raw.isEmpty || _firing) return;
    _hear(text);
    final nt = [for (final r in raw) vNorm(r).replaceAll(RegExp(r'[.,!?;]+$'), '')];
    final w = _wakeAt(nt);
    if (w == null) return; // cümle uyandırma kelimesiyle başlamıyor
    _wakeTimer?.cancel();
    await _fire(raw.sublist(w.$1 + w.$2).join(' ').trim());
  }

  Future<void> _fire(String cmd) async {
    if (_firing) return;
    final c = ctx;
    if (c == null || !c.mounted) return;
    _firing = true;
    voiceHold = false;
    _wakeTimer?.cancel();
    _busy = true;
    HapticFeedback.mediumImpact(); // kelimeyi algıladım
    await _halt();
    // Komut aşamasında radyo/TV sesi komutu bastırmasın: çalan radyo duraklatılır
    final ducked = media.isRadio && media.playing;
    if (ducked) {
      try {
        media.toggle();
      } catch (_) {}
    }
    try {
      if (cmd.isEmpty) {
        await voiceCommand(c); // yalnız kelime: komutu sor
      } else {
        await runVoiceText(c, cmd);
      }
    } catch (_) {}
    // komut radyoyu kendisi değiştirmediyse (çalıyor ya da durdurulmadıysa) eski durumuna döner
    if (ducked && !voiceHold && tvPop.chan == null && media.nowId != null && !media.playing) {
      try {
        media.toggle();
      } catch (_) {}
    }
    _busy = false;
    _firing = false;
    if (_want && store.voiceListen) {
      await Future<void>.delayed(const Duration(milliseconds: 600));
      _loop();
    }
  }
}

final voiceListener = VoiceListener();


// ---------------------------------------------------------------
// KOMUT LİSTESİ
//  "Günlük, komut listesini aç" / Ayarlar > Sesli komut / komut penceresindeki ? düğmesi.
//  Kapattığın bölümlerin komutları görünmez. Dokununca denenebilenler (açma, radyo, haber,
//  durdurma) çalışır; veri ekleyenlerde yalnız örnek gösterilir.
// ---------------------------------------------------------------
class _CmdGroup {
  final String title;
  final IconData icon;
  final List<(String, bool)> items; // (örnek cümle, dokununca denenebilir mi)
  _CmdGroup(this.title, this.icon, this.items);
}

List<_CmdGroup> _cmdGroups() {
  final mediaOff = store.appHidden('media');
  return [
    if (!store.appHidden('rem'))
      _CmdGroup(tx('Hatırlatıcı'), Icons.notifications_active_outlined, [
        (tx('Yarın saat 9\'a toplantı hatırlat'), false),
        (tx('Cuma günü 14:30\'da doktor hatırlat'), false),
      ]),
    if (!store.appHidden('todo'))
      _CmdGroup(tx('Yapılacak'), Icons.task_alt_rounded, [
        (tx('Yapılacaklara market alışverişi ekle'), false),
      ]),
    if (!store.appHidden('wallet'))
      _CmdGroup(tx('Cüzdan'), Icons.account_balance_wallet_rounded, [
        (tx('Cüzdana binikiyüz lira market harcaması ekle'), false),
      ]),
    _CmdGroup(tx('Rutin değeri'), Icons.checklist_rounded, [
      (tx('Su 2 litre'), false),
      (tx('Kilo 82'), false),
    ]),
    _CmdGroup(tx('Açma'), Icons.open_in_new_rounded, [
      (tx('Cüzdanı aç'), true),
      (tx('Ana sayfaya git'), true),
      (tx('Kanal adıyla: TRT Haber aç'), false),
      (tx('Kısayol uygulaması adıyla aç'), false),
    ]),
    if (!mediaOff && !store.appHidden('radio'))
      _CmdGroup(tx('Radyo'), Icons.radio_rounded, [
        (tx('Radyo aç (son çalan istasyon)'), false),
        (tx('Favori radyo çal'), false),
        (tx('İstasyon adıyla: TRT FM çal'), false),
        (tx('Radyo kapat'), true),
        (tx('Radyo sayfasını aç'), true),
      ]),
    if (!mediaOff && !store.appHidden('tv'))
      _CmdGroup(tx('TV'), Icons.live_tv_rounded, [
        (tx('TV aç (son izlenen kanal, pop-up)'), false),
        (tx('TV kapat'), true),
        (tx('TV sayfasını aç'), true),
      ]),
    if (!mediaOff)
      _CmdGroup(tx('Müzik ve podcast'), Icons.music_note_rounded, [
        (tx('Müzik aç (son şarkı)'), false),
        (tx('Son çalanı aç'), false),
        (tx('Müzik kapat'), true),
        (tx('Podcast sayfasını aç'), true),
      ]),
    if (!mediaOff)
      _CmdGroup(tx('Çalma kontrolü'), Icons.play_circle_outline_rounded, [
        (tx('Duraklat'), true),
        (tx('Devam et'), true),
        (tx('Sonraki'), true),
        (tx('Önceki'), true),
        (tx('Sesi kıs'), true),
        (tx('Sesi aç'), true),
        (tx('Sessize al'), true),
      ]),
    if (!mediaOff && !store.appHidden('news'))
      _CmdGroup(tx('Haber ve durdurma'), Icons.newspaper_rounded, [
        (tx('Haber oku'), true),
        (tx('Durdur'), true),
      ]),
    _CmdGroup(tx('Bilgi'), Icons.info_outline_rounded, [
      (tx('Saat kaç'), true),
      (tx('Bugün günlerden ne'), true),
      (tx('Bugün ne yaptım'), true),
      (tx('Bu hafta ne yaptım'), true),
      (tx('Şarkı ne'), true),
      (tx('Bu şarkıyı isteklerime ekle'), false),
    ]),
    _CmdGroup(tx('Dinleme'), Icons.hearing_rounded, [
      (tx('Sürekli dinlemeyi kapat'), true),
    ]),
    _CmdGroup(tx('Yardım'), Icons.help_outline_rounded, [
      (tx('Komut listesini aç'), false),
    ]),
  ];
}

class VoiceCommandsPage extends StatelessWidget {
  const VoiceCommandsPage({super.key});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final groups = _cmdGroups();
    return AmbScaffold(
      kind: 'settings',
      appBar: AppBar(
        backgroundColor: ambBg(p),
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(tx('Komut listesi')),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 32),
        children: [
          Padding(
            padding: const EdgeInsets.only(top: 4, bottom: 6),
            child: Text(
                tx('Uyandırma kelimesini ("{0}") söyleyip komutu ekle: "{0}, radyo aç". Yalnız kelimeyi söylersen komut ekranı açılır. Yanında ▶ olan örneklere dokununca denenir.',
                    [store.voiceWake]),
                style: TextStyle(color: p.soft, fontSize: 12.5, height: 1.35)),
          ),
          const _VoiceStatus(),
          for (final g in groups)
            Container(
              margin: const EdgeInsets.only(top: 10),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: p.line),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Padding(
                    padding: const EdgeInsets.fromLTRB(14, 12, 14, 4),
                    child: Row(children: [
                      Icon(g.icon, size: 20, color: p.accent),
                      const SizedBox(width: 8),
                      Text(g.title,
                          style: const TextStyle(
                              fontSize: 15, fontWeight: FontWeight.w700)),
                    ]),
                  ),
                  for (final e in g.items)
                    ListTile(
                      dense: true,
                      title: Text('“${e.$1}”'),
                      trailing: e.$2
                          ? Icon(Icons.play_arrow_rounded, color: p.accent)
                          : null,
                      onTap: e.$2
                          ? () => runVoiceText(context, e.$1)
                          : null,
                    ),
                  const SizedBox(height: 4),
                ],
              ),
            ),
        ],
      ),
    );
  }
}


// ---------------------------------------------------------------
// DURUM PANELİ: hangi motor dinliyor, model indirildi mi, son hata ne
// ---------------------------------------------------------------
class _VoiceStatus extends StatelessWidget {
  const _VoiceStatus();

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([voiceListener, wakeEngine, store]),
      builder: (context, _) {
        final w = wakeEngine;
        final on = store.voiceListen;
        final engine = w.ready && w.enabled
            ? tx('Çevrimdışı motor (bipsiz)')
            : tx('Telefonun konuşma servisi (zaman zaman bip verir)');
        return Container(
          margin: const EdgeInsets.only(top: 10),
          padding: const EdgeInsets.all(14),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: p.line),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(children: [
                Icon(
                    voiceListener.listening
                        ? Icons.hearing_rounded
                        : Icons.hearing_disabled_rounded,
                    size: 20,
                    color: p.accent),
                const SizedBox(width: 8),
                Text(tx('Dinleme durumu'),
                    style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700)),
              ]),
              const SizedBox(height: 8),
              Text(
                  !on
                      ? tx('Sürekli dinleme kapalı (Ayarlar > Sesli komut).')
                      : voiceListener.listening
                          ? tx('Dinliyor. Uyandırma kelimesi: "{0}"', [store.voiceWake])
                          : tx('Şu an dinlemiyor (arka planda, komut sırasında ya da yeniden başlıyor).'),
                  style: TextStyle(color: p.ink, fontSize: 13)),
              const SizedBox(height: 4),
              Text(tx('Motor: {0}', [engine]), style: TextStyle(color: p.soft, fontSize: 12.5)),
              if (on)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                      tx('Son duyulan: {0}',
                          [voiceListener.lastHeard.isEmpty ? tx('(henüz yok)') : voiceListener.lastHeard]),
                      style: TextStyle(color: p.ink, fontSize: 12.5)),
                ),
              if (w.status.isNotEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(w.status, style: TextStyle(color: p.soft, fontSize: 12.5)),
                ),
              if (w.error != null)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(tx('Hata: {0}', [w.error!]),
                      style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                ),
              const SizedBox(height: 8),
              if (w.bad)
                OutlinedButton.icon(
                  onPressed: w.clearBad,
                  icon: const Icon(Icons.refresh_rounded),
                  label: Text(tx('Tekrar dene')),
                )
              else if (w.downloading)
                const LinearProgressIndicator()
              else if (!w.ready)
                FilledButton.icon(
                  onPressed: () async {
                    await w.download();
                    voiceListener.engineChanged();
                  },
                  icon: const Icon(Icons.download_rounded),
                  label: Text(tx('Çevrimdışı modeli indir (~40 MB)')),
                )
              else
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(tx('Çevrimdışı motoru kullan')),
                  value: w.enabled,
                  onChanged: (v) {
                    store.setProf('vosk', v);
                    voiceListener.engineChanged();
                  },
                ),
              if (w.ready)
                SwitchListTile(
                  contentPadding: EdgeInsets.zero,
                  dense: true,
                  title: Text(tx('Yalnız uyandırma kelimesini dinle')),
                  subtitle: Text(tx('Kelimeyi daha doğru bulur. Kelimeden sonra komutu söylersin. Uygulamayı yeniden açınca geçerli olur.')),
                  value: store.pBool('vgram', true),
                  onChanged: (v) => store.setProf('vgram', v),
                ),
            ],
          ),
        );
      },
    );
  }
}
