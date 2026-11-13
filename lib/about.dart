import 'package:flutter/material.dart';
import 'strings.dart';
import 'ui.dart';
import 'version.dart';

// ---------------------------------------------------------------
// YENİLİKLER: güncelleme sonrası ilk açılışta bir kez gösterilir;
// Ayarlar > Yenilikler ile tekrar açılabilir.
// Her sürümde aşağıdaki liste yeni sürümün maddeleriyle değiştirilir.
// ---------------------------------------------------------------
List<String> whatsNew() => [
      tx('Verilerin korundu.'),
      tx('Ders çalışma: her LGS dersinde Soru kalıpları (soru tipi, ne ölçtüğü, nelere bakılacağı, tuzaklar, çözüm adımları).'),
      tx('Hava durumu: hava simgesine dokununca bar açılır ve sabit kalır; ok kalktı. Bugün / yarın için sert hava uyarıları (tahmin verisinden).'),
      tx('Ayarlar > Ana ekran: hava ve namaz vakitleri için ayrı ayrı Üst bar veya Sol sütun seçimi; kartlar yuvarlak ve aralıklar eşit.'),
      tx('Aşağı çekince ana sayfaya dönüşte yazı yerine dönen yuvarlak gösterge.'),
      tx('Soldaki menüde Cüzdan (tüm harcamaların özeti) ve açılır Kategoriler.'),
      tx('Araçlar: Para başlığı kalktı, Cüzdan tek araç. Ayarlar > Hakkında altında Kullanım şartları; Ayarlar\'daki Tanıtım bölümü kaldırıldı.'),
    ];
Future<void> showWhatsNew(BuildContext context, {bool updated = false}) {
  return showDialog<void>(
    context: context,
    builder: (ctx) {
      final p = palOf(ctx);
      return AlertDialog(
        title: Text(updated ? tx('Uygulama güncellendi') : tx('Yenilikler')),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(tx('Sürüm {0}', ['$appVersion ($appBuild)']),
                  style: TextStyle(
                      fontWeight: FontWeight.w700, color: p.ink, fontSize: 16)),
              const SizedBox(height: 12),
              for (final line in whatsNew())
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('• ', style: TextStyle(color: p.soft)),
                      Expanded(
                          child: Text(line, style: TextStyle(height: 1.35))),
                    ],
                  ),
                ),
            ],
          ),
        ),
        actions: [
          FilledButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tx('Tamam'))),
        ],
      );
    },
  );
}

// ---------------------------------------------------------------
// NELER YAPABİLİR?: Ayarlar > Hakkında > açılır özellik kartları
// ---------------------------------------------------------------
class FeaturesPage extends StatelessWidget {
  const FeaturesPage({super.key});

  static List<(IconData, Color, String, List<String>)> _items() => [
        (
          Icons.checklist_rounded,
          const Color(0xFF2E9E6B),
          tx('Rutin ve kayıtlar'),
          [
            tx('Günlük rutinlerini kategorilere ayırıp her gün işaretle.'),
            tx('Hedeflerini takip et; hepsi bitince küçük bir kutlama görürsün.'),
            tx('Geçmiş günlere bakıp istatistiklerini gör.'),
            tx('Ana sayfada sağa/sola kaydırarak günler arasında gez; aşağı çekince bugüne dön.'),
          ]
        ),
        (
          Icons.edit_note_rounded,
          const Color(0xFF8A6FD1),
          tx('Yapılacaklar ve Günlük'),
          [
            tx('Yapılacaklar listesi: hatırlatıcı ekle, bitmeyenler bugüne taşınır.'),
            tx('Günlüğüne not yaz; takvimden geçmiş notlara ulaş.'),
            tx('Hatırlatıcılar bildirimle gelir.'),
          ]
        ),
        (
          Icons.headphones_rounded,
          const Color(0xFFE8883A),
          tx('Müzik, radyo, podcast'),
          [
            tx('Telefondaki müziği çal; arka planda ve kilit ekranından kontrol et.'),
            tx('Online müzik: Audius ve Jamendo\'da ara, favorilere ekle.'),
            tx('Radyo ve podcast dinle.'),
            tx('Direksiyon / kulaklık tuşlarıyla sonraki - önceki parçaya geç.'),
          ]
        ),
        (
          Icons.newspaper_rounded,
          const Color(0xFFD1495B),
          tx('Haberler'),
          [
            tx('RSS kaynaklarından haber oku; kendi kaynağını ekle veya Hazır kaynaklardan seç.'),
            tx('Haberleri sesli oku: hızı ve sesi ayarla, kaç haber okunacağını seç.'),
          ]
        ),
        (
          Icons.wb_sunny_rounded,
          const Color(0xFF3E9FD6),
          tx('Hava durumu'),
          [
            tx('Saatlik ve günlük tahmin tek sayfada; bölümleri sıralayabilirsin.'),
            tx('Konumunu ve favori yerlerini seç; ana ekran seçili yeri gösterir.'),
            tx('Deniz durumunda dalga ve rüzgara göre tahmini bayrak rengi görürsün.'),
            tx('Ana ekranda hava durumunun altında namaz vakitleri gösterilebilir.'),
            tx('Bugün / yarın için yoğun yağış, fırtına, aşırı sıcak-soğuk gibi uyarılar.'),
          ]
        ),
        (
          Icons.handyman_rounded,
          const Color(0xFF4F8FA0),
          tx('Araçlar'),
          [
            tx('Sağlık ve denge: meditasyon, nefes, su sayacı.'),
            tx('Zaman ve sayaçlar: sayaç, pomodoro, kronometre, zamanlama (alarm ve başlatıcı).'),
            tx('Dini: zikirmatik ve kaza namazı sayaçları.'),
            tx('Ayarlar\'dan hangi araçların görüneceğini seçebilirsin.'),
            tx('Grupları açıp kapatabilir, sıralayabilirsin.'),
          ]
        ),
        (
          Icons.menu_book_rounded,
          const Color(0xFFC9A227),
          tx('Ders çalışma'),
          [
            tx('Haftalık ders programı ve çalışma planı.'),
            tx('Konu özetleri ve Tekrar et kartları: soruyu gör, cevabı aç.'),
            tx('Soru kalıpları: LGS derslerinde sık çıkan soru tipleri ve çözüm yolları.'),
            tx('Bilmediklerin tekrar karşına çıkar.'),
          ]
        ),
        (
          Icons.account_balance_wallet_rounded,
          const Color(0xFF2E9E6B),
          tx('Cüzdan'),
          [
            tx('Birden fazla cüzdan: Murat, Eymen gibi.'),
            tx('Harcama ve gelirleri kategori ve ödeme şekliyle kaydet (peşin, kredi kartı, banka kartı).'),
            tx('Günlük, haftalık, aylık, yıllık özet ve dağılım.'),
            tx('Borç ve alacakları kısmi ödemeler ve vade hatırlatmasıyla takip et.'),
          ]
        ),
        (
          Icons.shield_rounded,
          const Color(0xFF7A7F88),
          tx('Yedek ve veriler'),
          [
            tx('Tüm verilerini yedekleyip geri yükle.'),
            tx('Uygulama kilidi, tema ve dil seçenekleri.'),
            tx('Verilerin telefonunda saklanır.'),
          ]
        ),
      ];

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return Scaffold(
      backgroundColor: p.bg,
      appBar: AppBar(
        backgroundColor: p.bg,
        elevation: 0,
        scrolledUnderElevation: 0,
        title: Text(tx('Neler yapabilir?')),
      ),
      body: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 40),
        children: [
          for (final it in _items())
            Container(
              margin: const EdgeInsets.only(bottom: 10),
              decoration: BoxDecoration(
                color: p.card,
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: p.line),
              ),
              child: Theme(
                data: Theme.of(context)
                    .copyWith(dividerColor: Colors.transparent),
                child: ExpansionTile(
                  key: PageStorageKey('feat_${it.$3}'),
                  tilePadding: const EdgeInsets.symmetric(horizontal: 14),
                  childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 14),
                  expandedCrossAxisAlignment: CrossAxisAlignment.start,
                  leading: CircleAvatar(
                    radius: 22,
                    backgroundColor: it.$2,
                    child: Icon(it.$1, color: Colors.white, size: 24),
                  ),
                  title: Text(it.$3,
                      style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w800,
                          color: p.ink)),
                  children: [
                    for (final line in it.$4)
                      Padding(
                        padding: const EdgeInsets.only(bottom: 7),
                        child: Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Padding(
                              padding: const EdgeInsets.only(top: 7, right: 10),
                              child: Container(
                                width: 7,
                                height: 7,
                                decoration: BoxDecoration(
                                    color: it.$2, shape: BoxShape.circle),
                              ),
                            ),
                            Expanded(
                              child: Text(line,
                                  style: TextStyle(
                                      color: p.ink, fontSize: 14.5, height: 1.4)),
                            ),
                          ],
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
