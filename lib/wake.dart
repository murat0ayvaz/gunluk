import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:flutter/foundation.dart';
import 'package:vosk_flutter_2/vosk_flutter_2.dart';
import 'data.dart';
import 'strings.dart';

// ---------------------------------------------------------------
// ÇEVRİMDIŞI UYANDIRMA MOTORU (Vosk)
//  Telefonun konuşma tanıma servisi sık sık kapanıp bip sesi verir. Vosk ise telefonda,
//  internetsiz ve bipsiz sürekli dinler. Türkçe küçük model bir kez indirilir (~35 MB).
//  Model yoksa ya da başlamazsa eski yöntem (speech_to_text) devreye girer.
//  Ayar: store.prof['vosk'] (varsayılan açık).
// ---------------------------------------------------------------
const String _kModelUrl =
    'https://alphacephei.com/vosk/models/vosk-model-small-tr-0.3.zip';
const String _kModelName = 'vosk-model-small-tr-0.3';

class WakeEngine extends ChangeNotifier {
  bool ready = false; // model yüklü, konuşma servisi hazır
  bool downloading = false;
  bool running = false; // şu an dinliyor
  bool _startOk = false; // bu oturumda mikrofon başlatması bir kez sorunsuz geçti
  String status = '';
  String? error;

  Recognizer? _rec;
  SpeechService? _svc;
  Model? _model;
  StreamSubscription<String>? _sp, _sr;

  bool get enabled => store.pBool('vosk', true);

  /// Bir önceki native adım uygulamayı çökerttiyse motor kalıcı olarak devre dışıdır
  bool get bad => store.pBool('voskbad', false);

  void _set(String s, {String? err}) {
    status = s;
    error = err;
    notifyListeners();
  }

  // ---- Çökme koruması ----
  // Vosk'un yerel (native) kodu çökerse Dart'ta yakalanamaz ve uygulama kapanır. Bu yüzden
  // yerel adımdan önce bir işaret dosyası yazılır, adım bitince silinir. Açılışta işaret
  // duruyorsa önceki deneme çökmüştür: motor kapatılır, uygulama eski yöntemle çalışır.
  Future<File> _flag() async =>
      File('${(await store.voiceDir()).parent.path}/vosk_try.flag');

  Future<void> _mark() async {
    try {
      (await _flag()).writeAsStringSync('1', flush: true);
    } catch (_) {}
  }

  Future<void> _unmark() async {
    try {
      final f = await _flag();
      if (f.existsSync()) f.deleteSync();
    } catch (_) {}
  }

  /// Açılışta: önceki deneme çöktüyse motoru kapatır; daha önce başarıyla çalıştıysa sessizce yükler
  Future<void> tryLoad() async {
    if (ready || downloading || bad) return;
    try {
      final f = await _flag();
      if (f.existsSync()) {
        f.deleteSync();
        store.setProf('voskbad', true);
        store.setProf('voskok', false);
        _set(tx('Çevrimdışı motor bu telefonda uygulamayı kapattı; devre dışı bırakıldı. Eski yöntem kullanılıyor.'));
        return;
      }
      if (!store.pBool('voskok', false)) return; // yalnız daha önce sorunsuz çalıştıysa kendiliğinden yüklenir
      if (!await ModelLoader().isModelAlreadyLoaded(_kModelName)) return;
      await _init();
    } catch (e) {
      _set(tx('Çevrimdışı motor başlatılamadı.'), err: '$e');
    }
  }

  /// Kullanıcı "tekrar dene" derse engeli kaldırır
  void clearBad() {
    store.setProf('voskbad', false);
    store.setProf('voskok', false);
    _set('');
  }

  /// Modeli indirir (kullanıcı istedi) ve motoru hazırlar
  Future<void> download() async {
    if (downloading || bad) return;
    downloading = true;
    _set(tx('Model indiriliyor (~40 MB)...'));
    try {
      await _init();
    } catch (e) {
      _set(tx('İndirme ya da kurulum başarısız.'), err: '$e');
    }
    downloading = false;
    notifyListeners();
  }

  Future<void> _init() async {
    final path = await ModelLoader().loadFromNetwork(_kModelUrl); // indirme + açma (Dart)
    _set(tx('Model hazırlanıyor...'));
    await _mark(); // bundan sonrası yerel kod: çökerse işaret kalır
    final vosk = VoskFlutterPlugin.instance();
    _model = await vosk.createModel(path);
    _rec = await vosk.createRecognizer(model: _model!, sampleRate: 16000);
    _svc = await vosk.initSpeechService(_rec!);
    await _unmark();
    store.setProf('voskok', true);
    ready = true;
    _set(tx('Çevrimdışı motor hazır.'));
  }

  /// Dinlemeye başlar; ara ve son sonuçlar metin olarak gelir
  Future<bool> start(void Function(String) onPartial, void Function(String) onFinal) async {
    if (!ready || _svc == null) return false;
    try {
      await _sp?.cancel();
      await _sr?.cancel();
      _sp = _svc!.onPartial().listen((s) {
        final t = _text(s, 'partial');
        if (t.isNotEmpty) onPartial(t);
      });
      _sr = _svc!.onResult().listen((s) {
        final t = _text(s, 'text');
        if (t.isNotEmpty) onFinal(t);
      });
      if (!_startOk) await _mark(); // ilk mikrofon başlatması da yerel kod
      await _svc!.start();
      if (!_startOk) {
        _startOk = true;
        await _unmark();
      }
      running = true;
      notifyListeners();
      return true;
    } catch (e) {
      await _unmark();
      running = false;
      _set(tx('Çevrimdışı motor dinlemeye başlayamadı.'), err: '$e');
      return false;
    }
  }

  Future<void> stop() async {
    try {
      await _sp?.cancel();
      await _sr?.cancel();
      _sp = null;
      _sr = null;
      if (running) await _svc?.stop();
    } catch (_) {}
    if (running) {
      running = false;
      notifyListeners();
    }
  }

  String _text(String raw, String key) {
    try {
      final m = jsonDecode(raw);
      return (m[key] ?? '').toString().trim();
    } catch (_) {
      return '';
    }
  }
}

final wakeEngine = WakeEngine();
