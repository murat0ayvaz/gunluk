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
      tx('Haber okuma: üstteki Oku düğmesi tüm kaynakları sırayla okur (her kaynaktan 3/5/10 haber); okuma hızı ve ses seçilebilir.'),
      tx('Direksiyon / kulaklık ileri-geri tuşları müzik, radyo, podcast ve haber okumada çalışacak şekilde düzenlendi (araca göre değişebilir).'),
      tx('Hava durumu: Saatlik ve Günlük ayrıldı; favori yerler üstte; günler siyah büyük başlık, çizgilerle ayrık.'),
      tx('Araçlar gruplandı ve sıralanabilir; Uyku aracı menüden kalktı; Zamanlama tek kutuda.'),
      tx('LGS: dersler ünite ünite düzenlendi; İngilizce için Gramer ve kalıplar, 24 seviyeli okuma parçası; Türkçe için paragraf soru kalıpları ve 15 okuma parçası; Söz sanatları, Noktalama, Anlatım biçimleri, Yazı türleri.'),
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
