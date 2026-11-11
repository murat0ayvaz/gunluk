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
      tx('Haber: okuma hızı − / + ile ayarlanır; sesler Erkek 1-2 ve Bayan 1-2; "Hepsi" seçeneği ve Hazır kaynaklar (çalışanları uygulama kendisi bulur).'),
      tx('Hava durumu tek sayfada: Saatlik / Günlük sekmeleri, bölümler sıralanabilir, yerler ilk kelimeyle; konum ayarı buraya taşındı ve ana ekran seçili yeri gösterir.'),
      tx('Araçlar: büyük, açılıp kapanan grup başlıkları.'),
      tx('Online müzik: Audius önde ve seçili, çalan parça listenin başında, sonuç sayısı elle girilebilir ve Daha fazla düğmesi.'),
      tx('Ders çalışma: haftalık programda gün başlıkları büyük ve siyah.'),
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
