import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';

// ---------------------------------------------------------------
// RADYO YAYININDAN ŞARKI ADI OKUMA (ICY / Shoutcast / Icecast)
//  Çaladan bağımsız: yayına küçük ayrı bir istek açılır ("Icy-MetaData: 1"), sunucu belirli
//  aralıkla "StreamTitle='Sanatçı - Şarkı';" bloğu gönderir. İlk bloğu okuyup bağlantıyı kapatırız.
//  Yayın bu bilgiyi göndermiyorsa (HLS / m3u8 ya da sunucu desteklemiyorsa) supported = false.
// ---------------------------------------------------------------
class IcyInfo {
  final bool supported; // sunucu metadata gönderiyor mu
  final String title; // StreamTitle ('' olabilir)
  final String url; // StreamUrl ('' olabilir)
  const IcyInfo(this.supported, this.title, this.url);
  static const none = IcyInfo(false, '', '');
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

/// Sunucunun gönderdiği ilk metadata bloğundan şarkı bilgisini okur
Future<IcyInfo> icyFetch(String url) async {
  final u = Uri.tryParse(url);
  if (u == null || !(u.isScheme('http') || u.isScheme('https'))) return IcyInfo.none;
  if (u.path.toLowerCase().endsWith('.m3u8')) return IcyInfo.none; // HLS: ICY yok
  final client = HttpClient()
    ..connectionTimeout = const Duration(seconds: 8)
    ..userAgent = 'Mozilla/5.0 (Linux; Android) DailyRoutine';
  try {
    final req = await client.getUrl(u);
    req.headers.set('Icy-MetaData', '1');
    req.followRedirects = true;
    req.maxRedirects = 5;
    final res = await req.close().timeout(const Duration(seconds: 10));
    final mi = int.tryParse(res.headers.value('icy-metaint') ?? '') ?? 0;
    if (mi <= 0 || mi > 200000) return IcyInfo.none;
    final buf = BytesBuilder(copy: false);
    var total = 0;
    var need = mi + 1; // ses verisi + 1 uzunluk baytı
    var lenKnown = false;
    final done = Completer<IcyInfo>();
    late StreamSubscription<List<int>> sub;
    sub = res.listen((chunk) {
      buf.add(chunk);
      total += chunk.length;
      if (!lenKnown && total >= mi + 1) {
        final all = buf.toBytes();
        need = mi + 1 + all[mi] * 16;
        lenKnown = true;
      }
      if (lenKnown && total >= need) {
        final all = buf.toBytes();
        final len = all[mi] * 16;
        if (len == 0) {
          // bu aralıkta şarkı bilgisi yok (değişmedi): sonraki bloğu bekle
          buf.clear();
          buf.add(Uint8List.sublistView(all, need));
          total = total - need;
          lenKnown = false;
          need = mi + 1;
          return;
        }
        final meta = _decode(Uint8List.sublistView(all, mi + 1, mi + 1 + len)
            .where((x) => x != 0)
            .toList());
        if (!done.isCompleted) {
          done.complete(IcyInfo(true, _field(meta, 'StreamTitle'), _field(meta, 'StreamUrl')));
        }
        sub.cancel();
      } else if (total > 400000 && !done.isCompleted) {
        done.complete(const IcyInfo(true, '', '')); // çok bekledik, bilgi yok
        sub.cancel();
      }
    }, onError: (_) {
      if (!done.isCompleted) done.complete(IcyInfo.none);
    }, onDone: () {
      if (!done.isCompleted) done.complete(const IcyInfo(true, '', ''));
    }, cancelOnError: true);
    return await done.future.timeout(const Duration(seconds: 25),
        onTimeout: () {
      sub.cancel();
      return const IcyInfo(true, '', '');
    });
  } catch (_) {
    return IcyInfo.none;
  } finally {
    client.close(force: true);
  }
}
