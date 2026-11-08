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
      tx('Yeni: Ders çalışma (üst çubukta sol). LGS dersleri ve İngilizce için hazır kartlar; kendi kartlarını ekle, Biliyorum/Bilmiyorum ile aralıklı tekrar yap.'),
      tx('Hava durumu sayfası yenilendi: kaynaklar yan yana, açılır başlıklar. Hava ayarları buraya taşındı.'),
      tx('Ayarlar\'daki başlıklar açılır kapanır oldu.'),
      tx('Meditasyon ve Nefes\'te nefes al/ver için tek tını sesi.'),
      tx('Araç sayfalarının sağ üstünde Araçlar simgesi; sayfadan çıkınca süre sayan araçlar duraklar.'),
      tx('Su sayacında Geri al bildirimi kaldırıldı.'),
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
