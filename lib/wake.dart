import 'dart:async';
import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:vosk_flutter/vosk_flutter.dart';
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

class WakeEngine extends ChangeNotifier {
  bool ready = false; // model yüklü, konuşma servisi hazır
  bool downloading = false;
  bool running = false; // şu an dinliyor
  String status = '';
  String? error;

  Recognizer? _rec;
  SpeechService? _svc;
  Model? _model;
  StreamSubscription<String>? _sp, _sr;

  bool get enabled => store.pBool('vosk', true);

  void _set(String s, {String? err}) {
    status = s;
    error = err;
    notifyListeners();
  }

  /// Model daha önce indirildiyse sessizce yükler (açılışta)
  Future<void> tryLoad() async {
    if (ready || downloading) return;
    try {
      final loader = ModelLoader();
      if (!await loader.isModelAlreadyLoaded('vosk-model-small-tr-0.3')) return;
      await _init();
    } catch (e) {
      _set(tx('Çevrimdışı motor başlatılamadı.'), err: '$e');
    }
  }

  /// Modeli indirir (kullanıcı istedi) ve motoru hazırlar
  Future<void> download() async {
    if (downloading) return;
    downloading = true;
    _set(tx('Model indiriliyor (~40 MB)...'));
    try {
      await ModelLoader().loadFromNetwork(_kModelUrl);
      await _init();
    } catch (e) {
      _set(tx('İndirme ya da kurulum başarısız.'), err: '$e');
    }
    downloading = false;
    notifyListeners();
  }

  Future<void> _init() async {
    final loader = ModelLoader();
    final path = await loader.loadFromNetwork(_kModelUrl);
    final vosk = VoskFlutterPlugin.instance();
    _model = await vosk.createModel(path);
    _rec = await vosk.createRecognizer(model: _model!, sampleRate: 16000);
    _svc = await vosk.initSpeechService(_rec!);
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
      await _svc!.start();
      running = true;
      notifyListeners();
      return true;
    } catch (e) {
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
