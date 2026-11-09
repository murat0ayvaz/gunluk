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
      tx('Hava durumu sıcaklık tablosu yenilendi: kaynak adları bir kez en üstte, değerler alt alta; her değerin üstünde hava simgesi.'),
      tx('Meditasyon ve Nefes\'te nefes al/ver tınısı Tibet çanı sesi oldu.'),
      tx('Rutini sağa çekince Hedef girilebiliyor ve Alt kategoriyi düzenle düğmesi çıkıyor.'),
      tx('Ders çalışma yenilendi: her derste Ders çalış ve Tekrar et. Ders çalış\'ta 8. sınıf konu özetleri (her bilgi ayrı, Tekrar et düğmesiyle tekrar listesine eklenir).'),
      tx('Her konuda not yazabilir ve ses kaydı alabilirsin. LGS ve Yabancı dil paketleri isteğe bağlı yüklenir, dersler silinebilir.'),
      tx('Haftalık çalışma programı: gün + ders + saat aralığı, isteğe bağlı hatırlatma.'),
      tx('Araçlar\'a Zamanlama: Uyku zamanlayıcısı, Alarm ve Başlatıcı.'),
      tx('Ayarlar\'daki başlıklar açılır kapanır oldu.'),
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
