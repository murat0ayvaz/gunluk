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

  // ---- Gramer: motor yalnız uyandırma kelimesini ve "bilinmeyen ses"i ayırt eder ----
  // Serbest konuşma tanıma kısa kelimeleri sık yanlış yazar; sınırlı seçenekte karar çok daha doğrudur.
  // Kelimeden sonraki komut ayrı dinlenir (kelime tek başına duyulunca komut ekranı açılır).
  // Ayar: store.prof['vgram'] (varsayılan açık); kapatınca uygulama yeniden açılınca serbest tanıma döner.
  bool _gramOn = false; // bu motor gramerle kuruldu
  String _gramKey = '';

  bool get gram => store.pBool('vgram', true);

  /// Türkçe harflere uygun küçük harf (İ -> i, I -> ı)
  String _lower(String s) => s.replaceAll('İ', 'i').replaceAll('I', 'ı').toLowerCase();

  List<String> _gramList() {
    final w = _lower(store.voiceWake).trim().replaceAll(RegExp(r'\s+'), ' ');
    return [if (w.isNotEmpty) w, '[unk]'];
  }

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
    _gramOn = gram;
    final gl = _gramList();
    _gramKey = gl.join('|');
    _rec = _gramOn && gl.length > 1
        ? await vosk.createRecognizer(model: _model!, sampleRate: 16000, grammar: gl)
        : await vosk.createRecognizer(model: _model!, sampleRate: 16000);
    if (!(_gramOn && gl.length > 1)) _gramOn = false;
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
      if (_gramOn) {
        // uyandırma kelimesi değiştiyse yeni kelimeyle gramer güncellenir
        final gl = _gramList();
        final key = gl.join('|');
        if (gl.length > 1 && key != _gramKey) {
          try {
            await _rec!.setGrammar(gl);
            _gramKey = key;
          } catch (_) {}
        }
      }
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
      final t = (m[key] ?? '').toString();
      if (!_gramOn) return t.trim();
      // gramerde bilinmeyen sesler "[unk]" olarak gelir; komut metni sanılmasın diye atılır
      return t.replaceAll('[unk]', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
    } catch (_) {
      return '';
    }
  }
}

final wakeEngine = WakeEngine();
