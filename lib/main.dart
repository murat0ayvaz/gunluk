import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data.dart';
import 'home.dart';
import 'intro.dart';
import 'lock.dart';
import 'media.dart';
import 'notify.dart';
import 'strings.dart';
import 'theme.dart';
import 'timing.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// DAILY ROUTINE - günlük rutin, hedef, yapılacaklar ve günlük (not) uygulaması
// Dosyalar:
//   main.dart      uygulama girişi, tema, dil, açılış akışı, kilit tetikleme
//   strings.dart   çeviriler (Türkçe / English), gün ve ay adları
//   theme.dart     pastel renkler ve temalar
//   data.dart      modeller + telefona kayıt + şifre özeti
//   quotes.dart    özlü sözler (motivasyon, ayet, hadis)
//   version.dart   sürüm numarası
//   about.dart     "Yenilikler" penceresi
//   ui.dart        ortak pencereler ve yardımcılar
//   intro.dart     açılış ekranı + tanıtım sayfaları
//   lock.dart      uygulama kilidi (şifre ekranı ve pencereleri)
//   home.dart      ana ekran (günlük rutinler + alt panel)
//   add_sheet.dart Ekle ekranı
//   notes.dart     günlük (not) yazma
//   diary.dart     günlük takvimi
//   todos.dart     yapılacaklar
//   drawer.dart    soldaki menü (Your Book)
//   settings.dart  ayarlar (dil, tema, özlü sözler, kilit, yedek)
//   stats.dart     istatistik ekranı
//   manage.dart    kategorileri düzenle
//   media.dart     müzik çalar + radyo (sağdan açılan sayfa)
//   weather.dart   hava durumu (tarih yanı simge + saatlik panel)
// ---------------------------------------------------------------

/// Kilit ekranını tüm sayfaların (açık pencereler dahil) üstüne açabilmek için
final navKey = GlobalKey<NavigatorState>();

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initAudio(); // müzik çalar (arka planda çalma)
  await store.loadSplashLast(); // açılış sözü art arda tekrar etmesin
  store.prepareLang(); // açılış ekranı daha ilk karede doğru dilde görünsün
  runApp(const GunlukApp());
}

class GunlukApp extends StatelessWidget {
  const GunlukApp({super.key});

  @override
  Widget build(BuildContext context) {
    // Tema veya dil değişince uygulama yeniden çizilir
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) => MaterialApp(
        navigatorKey: navKey,
        title: 'Daily Routine',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(Brightness.light, store.accent),
        darkTheme: buildTheme(Brightness.dark, store.accent),
        themeMode: store.themeMode,
        // Seçili dile göre tarih seçici ve düğme metinleri
        locale: Locale(store.lang),
        supportedLocales: const [Locale('tr'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        builder: (context, child) =>
            PullHome(navKey: navKey, child: child ?? const SizedBox.shrink()),
        home: const Gate(),
      ),
    );
  }
}

/// Açılış akışı: açılış ekranı -> (kilit) -> (ilk kurulumda tanıtım) -> ana ekran
class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> with WidgetsBindingObserver {
  bool _ready = false;
  bool _splashDone = false; // kullanıcı "Geç"e bastı mı
  bool _lockShown = false; // kilit ekranı şu an açık mı
  DateTime? _pausedAt; // arka plana gidiş zamanı

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    store.addListener(_onStore);
    Notifier.tapped.addListener(_onTap);
    _boot();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    store.removeListener(_onStore);
    Notifier.tapped.removeListener(_onTap);
    super.dispose();
  }

  /// Başlatıcı bildirimine dokunuldu (uygulama açıkken)
  void _onTap() {
    final pl = Notifier.tapped.value;
    if (pl == null || !_ready || store.locked) return;
    Notifier.tapped.value = null;
    final nav = navKey.currentState;
    if (nav != null) handleNotifPayload(nav, pl);
  }

  Future<void> _boot() async {
    // store.init() hata olsa da takılmaz (içinde zaman aşımı var).
    await store.init();
    // Kilit açıksa şifre girilene kadar ana ekrana geçilmez
    if (store.lockEnabled) {
      store.lock();
      while (mounted && store.locked) {
        await Future<void>.delayed(const Duration(milliseconds: 200));
      }
    }
    // Hatırlatıcı bildirimlerini yeniden planla (arka planda, takılmaz)
    Notifier.init().then((_) => Notifier.rescheduleAll()).catchError((_) {});
    if (mounted) setState(() => _ready = true);
    // Bildirime dokunarak açıldıysa (uygulama kapalıydı) başlatıcıyı çalıştır
    final cold = await Notifier.coldStartPayload();
    final pending = Notifier.tapped.value;
    final pl = cold ?? pending;
    if (pl != null && mounted) {
      Notifier.tapped.value = null;
      await Future<void>.delayed(const Duration(milliseconds: 600));
      final nav = navKey.currentState;
      if (nav != null) handleNotifPayload(nav, pl);
    }
  }

  // Arka plana gidip 5 saniyeden uzun kalınca dönüşte kilitle
  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.paused) {
      _pausedAt = DateTime.now();
    } else if (state == AppLifecycleState.resumed) {
      final t = _pausedAt;
      _pausedAt = null;
      if (t != null &&
          DateTime.now().difference(t) > const Duration(seconds: 5)) {
        store.lock();
      }
    }
  }

  // store.locked true olunca kilit ekranını TÜM sayfaların üstüne açar
  void _onStore() {
    if (store.locked && !_lockShown) {
      _lockShown = true;
      navKey.currentState
          ?.push(PageRouteBuilder<void>(
            opaque: true,
            transitionDuration: Duration.zero,
            reverseTransitionDuration: const Duration(milliseconds: 120),
            pageBuilder: (context, a, b) => const LockScreen(),
          ))
          .then((_) => _lockShown = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    // Açılış ekranı kendiliğinden geçmez: veri hazır olunca "Geç" düğmesi çıkar.
    // İlk kurulumda (tanıtım henüz görülmediyse) doğrudan tanıtıma geçilir.
    if (!_ready || (!_splashDone && store.seenIntro)) {
      return SplashPage(
          ready: _ready, onGo: () => setState(() => _splashDone = true));
    }
    if (!store.seenIntro) {
      return IntroPage(
        onDone: () {
          store.markIntroSeen();
          setState(() {});
        },
      );
    }
    return const HomePage();
  }
}
