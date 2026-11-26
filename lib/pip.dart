import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'data.dart';

// ---------------------------------------------------------------
// KÜÇÜK PENCERE (Android "Resim içinde resim"): TV pop-up'ı açıkken ana ekrana / başka uygulamaya
// çıkınca TV, telefonun üstünde küçük yüzen pencerede devam eder. Pencereyi Android yönetir
// (sürükleme, çift dokunuşla büyütme). Pencerede yalnız görüntü gösterilir (tvpop.dart / tv.dart).
//  Kanal: gunluk/pip -> want{on}: Ana ekrana çıkınca otomatik geçilsin mi, enter: şimdi geç.
//  Android'den gelen: "pip" (true/false) = küçük pencereye girildi / çıkıldı.
//  Ayar: prof 'tvpip' (varsayılan açık).
// ---------------------------------------------------------------
class PipSvc {
  static const _ch = MethodChannel('gunluk/pip');
  final ValueNotifier<bool> inPip = ValueNotifier(false);
  bool _started = false;
  bool _want = false;

  bool get enabled => store.pBool('tvpip', true);

  void init() {
    if (_started) return;
    _started = true;
    _ch.setMethodCallHandler((call) async {
      if (call.method == 'pip') {
        final on = call.arguments == true;
        inPip.value = on;
        if (!on) _afterExit();
      }
    });
  }

  /// Küçük pencere kapatılınca (X) uygulama öne gelmez; o zaman TV de durmalı
  void Function()? onClosedInPip;
  void _afterExit() {
    Future.delayed(const Duration(milliseconds: 700), () {
      final st = WidgetsBinding.instance.lifecycleState;
      if (st != null && st != AppLifecycleState.resumed) onClosedInPip?.call();
    });
  }

  /// TV açıkken true: Ana ekran tuşuna basınca küçük pencereye geçilir
  Future<void> want(bool on) async {
    final v = on && enabled;
    if (v == _want) return;
    _want = v;
    try {
      await _ch.invokeMethod('want', {'on': v});
    } catch (_) {}
  }

  /// Şimdi küçük pencereye geç; desteklenmiyorsa false
  Future<bool> enter() async {
    try {
      return (await _ch.invokeMethod<bool>('enter')) ?? false;
    } catch (_) {
      return false;
    }
  }
}

final pip = PipSvc();
