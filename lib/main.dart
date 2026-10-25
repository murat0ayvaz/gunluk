import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'data.dart';
import 'home.dart';
import 'intro.dart';
import 'strings.dart';
import 'theme.dart';

// ---------------------------------------------------------------
// DAILY ROUTINE - günlük rutin, hedef, yapılacaklar ve günlük (not) uygulaması
// Dosyalar:
//   main.dart      uygulama girişi, tema, dil, açılış akışı
//   strings.dart   çeviriler (Türkçe / English), gün ve ay adları
//   theme.dart     pastel renkler ve temalar
//   data.dart      modeller + telefona kayıt
//   ui.dart        ortak pencereler ve yardımcılar
//   intro.dart     açılış ekranı + tanıtım sayfaları
//   home.dart      ana ekran (günlük rutinler + günün notu)
//   add_sheet.dart Ekle ekranı
//   notes.dart     günün notu (günlük) yazma ekranı
//   todos.dart     yapılacaklar (checkbox'lı liste)
//   drawer.dart    soldaki menü
//   settings.dart  ayarlar (dil + tema)
//   stats.dart     istatistik ekranı
//   manage.dart    kategorileri düzenle
// ---------------------------------------------------------------
void main() {
  WidgetsFlutterBinding.ensureInitialized();
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
        home: const Gate(),
      ),
    );
  }
}

/// Açılış akışı: açılış ekranı -> (ilk kurulumda tanıtım) -> ana ekran
class Gate extends StatefulWidget {
  const Gate({super.key});

  @override
  State<Gate> createState() => _GateState();
}

class _GateState extends State<Gate> {
  bool _ready = false;

  @override
  void initState() {
    super.initState();
    _boot();
  }

  Future<void> _boot() async {
    // Veri okuma ile en az 3 sn açılış ekranı birlikte beklenir.
    // store.init() hata olsa da takılmaz (içinde zaman aşımı var).
    await Future.wait([
      store.init(),
      Future<void>.delayed(const Duration(milliseconds: 3000)),
    ]);
    if (mounted) setState(() => _ready = true);
  }

  @override
  Widget build(BuildContext context) {
    if (!_ready) return const SplashPage();
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
