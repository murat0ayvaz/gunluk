import 'package:flutter/material.dart';

// ---------------------------------------------------------------
// TEMA: pastel, göz yormayan renkler (açık / koyu + vurgu rengi)
// ---------------------------------------------------------------

/// Tema menüsünden seçilebilen pastel vurgu renkleri
const accentNames = ['Mavi', 'Yeşil', 'Lavanta', 'Pembe', 'Şeftali'];
const accentColors = <Color>[
  Color(0xFF9CC3EC), // pastel mavi
  Color(0xFFA6D4B0), // pastel yeşil
  Color(0xFFC3B3EA), // lavanta
  Color(0xFFF0B3C8), // pastel pembe
  Color(0xFFF3C29C), // şeftali
];

/// Koyu temada vurgu rengi biraz sönükleştirilir (göz yormasın diye)
Color accentFor(int i, bool dark) {
  final c = accentColors[i];
  return dark ? Color.lerp(c, const Color(0xFF1F2125), 0.3)! : c;
}

/// Ekranlarda kullanılan renk paleti. Saf beyaz / saf siyah kullanılmaz.
class Pal {
  final bool dark;
  final Color accent;
  const Pal(this.dark, this.accent);

  Color get bg => dark ? const Color(0xFF1F2125) : const Color(0xFFF7F5F0);
  Color get card => dark ? const Color(0xFF2A2D33) : const Color(0xFFFFFFFF);
  Color get ink => dark ? const Color(0xFFE8E6E1) : const Color(0xFF2E3238);
  Color get soft => dark ? const Color(0xFFA7ABB3) : const Color(0xFF7A7F88);
  Color get line => dark ? const Color(0xFF3A3E45) : const Color(0xFFE6E2D9);

  // Hedefe ulaşılan satırın pastel yeşili
  Color get okBg => dark ? const Color(0xFF2E4A3A) : const Color(0xFFD6EDDC);
  // Kaydırma arka planları (sağa = düzenle, sola = sil)
  Color get editBg => dark ? const Color(0xFF34475E) : const Color(0xFFD6E5F6);
  Color get delBg => dark ? const Color(0xFF5B3B40) : const Color(0xFFF6D5D5);

  // Vurgu rengi üzerindeki yazı rengi
  Color get onAccent =>
      dark ? const Color(0xFFEDEBE6) : const Color(0xFF2E3238);
}

ThemeData buildTheme(Brightness b, int accent) {
  final dark = b == Brightness.dark;
  final pal = Pal(dark, accentFor(accent, dark));

  // Metin düğmeleri / anahtarlar için biraz daha koyu vurgu (okunabilirlik)
  final strong = dark
      ? pal.accent
      : Color.lerp(accentColors[accent], Colors.black, 0.45)!;

  final scheme = ColorScheme.fromSeed(
    seedColor: accentColors[accent],
    brightness: b,
  ).copyWith(
    surface: pal.bg,
    onSurface: pal.ink,
    primary: strong,
    onPrimary: dark ? const Color(0xFF1F2125) : Colors.white,
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    scaffoldBackgroundColor: pal.bg,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: pal.accent,
        foregroundColor: pal.onAccent,
        minimumSize: const Size(64, 48),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: pal.card,
      selectedColor: pal.accent,
      labelStyle: TextStyle(color: pal.ink),
      secondaryLabelStyle: TextStyle(color: pal.ink),
      checkmarkColor: pal.ink,
      side: BorderSide(color: pal.line),
    ),
  );
}
