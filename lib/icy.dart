import 'dart:async';
import 'dart:convert';
import 'dart:io';

// ---------------------------------------------------------------
// RADYO YAYININDAN ŞARKI ADI OKUMA (ICY / Shoutcast / Icecast)
//  Çaladan bağımsız: yayına küçük ayrı bir bağlantı açılır ("Icy-MetaData: 1"), sunucu belirli
//  aralıkla "StreamTitle='Sanatçı - Şarkı';" bloğu gönderir. İlk bloğu okuyup bağlantıyı kapatırız.
//  Bağlantı ham soketle kurulur: Shoutcast sunucuları "ICY 200 OK" diye cevap verir, Dart'ın
//  HttpClient'ı bunu reddeder. Yönlendirmeler (301/302/307/308) elle izlenir; https desteklenir.
//  state:  ok    = şarkı adı geldi
//          empty = sunucu bilgi gönderiyor ama şarkı adı boş / istasyon adı
//          none  = sunucu bu bilgiyi vermiyor (HLS, icy-metaint yok)
//          err   = geçici hata (tekrar denenir)
// ---------------------------------------------------------------
class IcyInfo {
  final String state;
  final String title; // StreamTitle ('' olabilir)
  final String url; // StreamUrl ('' olabilir)
  final String diag; // ham bilgi (küçük teşhis satırı için)
  const IcyInfo(this.state, this.title, this.url, [this.diag = '']);
  static const none = IcyInfo('none', '', '');
  bool get supported => state == 'ok' || state == 'empty';
}

String _decode(List<int> b) {
  try {
    return utf8.decode(b);
  } catch (_) {
    return latin1.decode(b);
  }
}

String _field(String meta, String key) {
  final m = RegExp("$key='(.*?)';", dotAll: true).firstMatch(meta) ??
      RegExp("$key='(.*)'", dotAll: true).firstMatch(meta);
  return m == null ? '' : m.group(1)!.trim();
}

/// Başlık bölümünün bittiği yer (gövdenin başladığı indeks); yoksa -1
int _headEnd(List<int> b) {
  for (var i = 0; i + 1 < b.length; i++) {
    if (b[i] == 10 && b[i + 1] == 10) return i + 2;
    if (i + 3 < b.length &&
        b[i] == 13 && b[i + 1] == 10 && b[i + 2] == 13 && b[i + 3] == 10) {
      return i + 4;
    }
  }
  return -1;
}

/// Sunucunun gönderdiği ilk metadata bloğundan şarkı bilgisini okur
Future<IcyInfo> icyFetch(String url) async {
  var cur = Uri.tryParse(url);
  for (var hop = 0; hop < 6; hop++) {
    if (cur == null || !(cur.isScheme('http') || cur.isScheme('https'))) {
      return const IcyInfo('none', '', '', 'adres geçersiz');
    }
    if (cur.path.toLowerCase().endsWith('.m3u8')) {
      return const IcyInfo('none', '', '', 'HLS yayın (m3u8)');
    }
    final r = await _once(cur);
    final redir = r.$2;
    if (redir != null && redir.isNotEmpty) {
      cur = cur.resolveUri(Uri.parse(redir));
      continue;
    }
    return r.$1;
  }
  return const IcyInfo('err', '', '', 'çok fazla yönlendirme');
}

Future<(IcyInfo, String?)> _once(Uri u) async {
  Socket? sock;
  StreamSubscription<List<int>>? sub;
  try {
    final secure = u.isScheme('https');
    final port = u.hasPort ? u.port : (secure ? 443 : 80);
    sock = secure
        ? await SecureSocket.connect(u.host, port,
            timeout: const Duration(seconds: 8), onBadCertificate: (_) => true)
        : await Socket.connect(u.host, port, timeout: const Duration(seconds: 8));
    final path = (u.path.isEmpty ? '/' : u.path) + (u.hasQuery ? '?${u.query}' : '');
    final host = u.hasPort ? '${u.host}:${u.port}' : u.host;
    final req = 'GET $path HTTP/1.0\r\n'
        'Host: $host\r\n'
        'User-Agent: Mozilla/5.0 (Linux; Android) DailyRoutine\r\n'
        'Icy-MetaData: 1\r\n'
        'Accept: */*\r\n'
        'Connection: close\r\n\r\n';
    sock.add(latin1.encode(req));
    await sock.flush();

    final done = Completer<(IcyInfo, String?)>();
    void finish(IcyInfo i, [String? redir]) {
      if (!done.isCompleted) done.complete((i, redir));
    }

    final buf = <int>[];
    var inBody = false;
    var mi = 0;
    var zeros = 0;
    var total = 0;

    void process() {
      if (!inBody) {
        final end = _headEnd(buf);
        if (end < 0) {
          if (buf.length > 16000) finish(const IcyInfo('err', '', '', 'başlık okunamadı'));
          return;
        }
        final head = latin1.decode(buf.sublist(0, end), allowInvalid: true);
        final lines = head.split(RegExp(r'\r?\n'));
        final status = lines.first.trim();
        final code = int.tryParse(
                RegExp(r'\s(\d{3})(\s|$)').firstMatch(status)?.group(1) ?? '') ??
            0;
        final hdr = <String, String>{};
        for (final l in lines.skip(1)) {
          final i = l.indexOf(':');
          if (i > 0) hdr[l.substring(0, i).trim().toLowerCase()] = l.substring(i + 1).trim();
        }
        if (code >= 300 && code < 400 && (hdr['location'] ?? '').isNotEmpty) {
          finish(IcyInfo('err', '', '', 'yönlendirme'), hdr['location']);
          return;
        }
        if (code >= 400) {
          finish(IcyInfo('err', '', '', 'sunucu cevabı: $status'));
          return;
        }
        mi = int.tryParse(hdr['icy-metaint'] ?? '') ?? 0;
        if (mi <= 0 || mi > 200000) {
          finish(IcyInfo('none', '', '', 'sunucu şarkı bilgisi göndermiyor ($status)'));
          return;
        }
        buf.removeRange(0, end);
        inBody = true;
      }
      while (inBody && !done.isCompleted) {
        if (buf.length < mi + 1) break;
        final len = buf[mi] * 16;
        if (buf.length < mi + 1 + len) break;
        if (len == 0) {
          zeros++;
          buf.removeRange(0, mi + 1);
          if (zeros >= 4) {
            finish(const IcyInfo('empty', '', '', 'yayın boş bilgi gönderiyor'));
          }
          continue;
        }
        final meta = _decode(buf.sublist(mi + 1, mi + 1 + len).where((x) => x != 0).toList());
        final raw = meta.trim();
        finish(IcyInfo('ok', _field(meta, 'StreamTitle'), _field(meta, 'StreamUrl'),
            raw.length > 120 ? raw.substring(0, 120) : raw));
        break;
      }
    }

    sub = sock.listen((chunk) {
      total += chunk.length;
      buf.addAll(chunk);
      process();
      if (!done.isCompleted && total > 600000) {
        finish(const IcyInfo('empty', '', '', 'yayında şarkı adı yok'));
      }
    }, onError: (e) {
      finish(IcyInfo('err', '', '', 'bağlantı hatası'));
    }, onDone: () {
      finish(const IcyInfo('err', '', '', 'bağlantı kapandı'));
    }, cancelOnError: true);

    return await done.future.timeout(const Duration(seconds: 25),
        onTimeout: () => (const IcyInfo('err', '', '', 'zaman aşımı'), null));
  } catch (e) {
    return (IcyInfo('err', '', '', 'bağlanılamadı'), null);
  } finally {
    try {
      await sub?.cancel();
    } catch (_) {}
    try {
      sock?.destroy();
    } catch (_) {}
  }
}
