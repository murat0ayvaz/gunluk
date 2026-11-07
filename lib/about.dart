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
      tx('Ayrıntılı hava (Araçlar): günlük, haftalık, 15 günlük; nem, rüzgar, basınç, UV, görüş ve deniz durumu. Kaynak adı yazar.'),
      tx('Podcast, Spreaker, Internet Archive ve RSS ile bul; radyo ve podcast için yıldızlı favoriler.'),
      tx('DR paneli ekranın yarısına kadar açılır; Ayarlar\'da renk skalası.'),
      tx('Pomodoro süreleri ayarlanır, gong ve titreşim uyarısı; su sayacında ml girişi.'),
      tx('Nefes sesi hava sesi oldu; Nefes aracında da ses ve titreşim. Müzikte Tekrar/Karışık.'),
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
