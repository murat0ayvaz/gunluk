import 'dart:convert';
import 'dart:io';
import 'dart:typed_data';
import 'package:archive/archive.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'data.dart';
import 'notify.dart';
import 'shortcuts.dart' show AppsChannel;
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// YEDEKLEME
//  1) Dosya yedeği: tek bir .zip (veriler + ses kayıtları). "Kaydet" ile telefonun dosya
//     seçicisinden istediğin yere (İndirilenler, Drive...) yazılır.
//  2) Dosyadan geri yükleme: .zip ya da eski .json yedeği.
//  3) Otomatik yedek: haftada / günde bir veriler İndirilenler/GunlukYedek klasörüne
//     .json olarak yazılır (Android 10+). Uygulama kaldırılsa da dosya silinmez.
//  4) Hatırlatma: son yedekten 7 gün geçtiyse ana ekranda ve telefon bildiriminde uyarı.
//  Ayarlar anahtarları (store.prof): abk (0 kapalı, 1 haftalık, 2 günlük),
//  lastbk (son yedek, ms), lastabk (son otomatik yedek, ms), bkbase (ilk açılış, ms).
// ---------------------------------------------------------------
const int _kDay = 86400000;
const int _kRemId = 790020;

String _stamp() {
  final n = DateTime.now();
  String t(int v) => v.toString().padLeft(2, '0');
  return '${n.year}${t(n.month)}${t(n.day)}-${t(n.hour)}${t(n.minute)}';
}

/// Yedek dosyasının baytları: yedek.json + (istenirse) voice/ klasöründeki ses kayıtları
Future<Uint8List> buildBackupZip({bool withVoice = true}) async {
  final a = Archive();
  final js = utf8.encode(store.exportBackup());
  a.addFile(ArchiveFile('yedek.json', js.length, js));
  if (withVoice) {
    try {
      final d = await store.voiceDir();
      await for (final e in d.list()) {
        if (e is File) {
          final b = await e.readAsBytes();
          final name = e.path.split('/').last;
          a.addFile(ArchiveFile('voice/$name', b.length, b));
        }
      }
    } catch (_) {}
  }
  final out = ZipEncoder().encode(a);
  return Uint8List.fromList(out ?? <int>[]);
}

/// Yedek baytlarını geri yükler (.zip ya da düz .json). Başarılıysa null, değilse hata metni.
Future<String?> restoreFromBytes(Uint8List bytes) async {
  String text;
  final voices = <(String, List<int>)>[];
  try {
    if (bytes.length > 3 && bytes[0] == 0x50 && bytes[1] == 0x4B) {
      final a = ZipDecoder().decodeBytes(bytes);
      String? js;
      for (final f in a) {
        if (!f.isFile) continue;
        final data = List<int>.from(f.content as List);
        if (f.name == 'yedek.json') {
          js = utf8.decode(data);
        } else if (f.name.startsWith('voice/')) {
          final nm = f.name.substring(6).split('/').last;
          if (nm.isNotEmpty && !nm.startsWith('.')) voices.add((nm, data));
        }
      }
      if (js == null) return tx('Bu bir Daily Routine yedeği gibi görünmüyor.');
      text = js;
    } else {
      text = utf8.decode(bytes);
    }
  } catch (e) {
    return tx('Yedek okunamadı: {0}', ['$e']);
  }
  final err = store.importBackup(text);
  if (err != null) return err;
  try {
    final d = await store.voiceDir();
    for (final v in voices) {
      await File('${d.path}/${v.$1}').writeAsBytes(v.$2);
    }
  } catch (_) {}
  Notifier.rescheduleAll();
  backupRemSync();
  return null;
}

void _snack(BuildContext c, String m) {
  ScaffoldMessenger.of(c)
    ..hideCurrentSnackBar()
    ..showSnackBar(SnackBar(content: Text(m)));
}

/// "Yedeği dosya olarak kaydet": telefonun kaydetme penceresi açılır
Future<void> saveBackupFile(BuildContext context) async {
  try {
    final bytes = await buildBackupZip();
    final path = await FilePicker.platform.saveFile(
      dialogTitle: tx('Yedeği nereye kaydedeyim?'),
      fileName: 'DailyRoutine-yedek-${_stamp()}.zip',
      bytes: bytes,
    );
    if (path == null) return; // vazgeçildi
    final now = DateTime.now().millisecondsSinceEpoch;
    store.setProf('lastbk', now);
    backupRemSync();
    if (context.mounted) _snack(context, tx('Yedek dosyası kaydedildi.'));
  } catch (e) {
    if (context.mounted) {
      _snack(context, tx('Yedek kaydedilemedi: {0}', ['$e']));
    }
  }
}

/// "Dosyadan geri yükle": .zip ya da .json yedeğini seçtirir
Future<void> restoreBackupFile(BuildContext context) async {
  try {
    final r = await FilePicker.platform.pickFiles(withData: true);
    if (r == null || r.files.isEmpty) return;
    final f = r.files.first;
    Uint8List? bytes = f.bytes;
    if (bytes == null && f.path != null) {
      bytes = await File(f.path!).readAsBytes();
    }
    if (bytes == null) {
      if (context.mounted) _snack(context, tx('Dosya okunamadı.'));
      return;
    }
    if (!context.mounted) return;
    final ok = await confirmDialog(
      context,
      tx('Geri yüklensin mi?'),
      tx('Mevcut verilerin yedekteki verilerle değiştirilecek. Devam edilsin mi?'),
      okLabel: tx('Geri yükle'),
    );
    if (!ok) return;
    final err = await restoreFromBytes(bytes);
    if (context.mounted) _snack(context, err ?? tx('Yedek geri yüklendi.'));
  } catch (e) {
    if (context.mounted) {
      _snack(context, tx('Yedek okunamadı: {0}', ['$e']));
    }
  }
}

/// Otomatik yedek: süre dolduysa verileri İndirilenler/GunlukYedek'e yazar.
/// Açılışta ve uygulamaya dönüşte çağrılır.
Future<void> autoBackupTick() async {
  try {
    final now = DateTime.now().millisecondsSinceEpoch;
    if (store.pInt('bkbase', 0) == 0) {
      store.setProf('bkbase', now); // hatırlatma sayacı ilk açılıştan başlar
    }
    final mode = store.pInt('abk', 1);
    if (mode == 0) {
      backupRemSync();
      return;
    }
    final gap = mode == 2 ? _kDay : 7 * _kDay;
    if (now - store.pInt('lastabk', 0) >= gap) {
      final js = Uint8List.fromList(utf8.encode(store.exportBackup()));
      final ok = await AppsChannel.saveDownload(
          'DailyRoutine-otomatik-${_stamp()}.json', js);
      if (ok) {
        store.setProf('lastabk', now);
        store.setProf('lastbk', now);
      }
    }
    backupRemSync();
  } catch (_) {}
}

/// Son yedek (ya da ilk açılış) zamanı; yoksa 0
int _backupBase() {
  final last = store.pInt('lastbk', 0);
  return last > 0 ? last : store.pInt('bkbase', 0);
}

/// Son yedekten 7 günden fazla geçti mi?
bool backupDue() {
  final b = _backupBase();
  if (b == 0) return false;
  return DateTime.now().millisecondsSinceEpoch - b > 7 * _kDay;
}

int backupDaysAgo() {
  final b = _backupBase();
  if (b == 0) return 0;
  return (DateTime.now().millisecondsSinceEpoch - b) ~/ _kDay;
}

/// Telefon bildirimi: son yedekten 7 gün sonra tek seferlik uyarı (yedek alınınca ertelenir)
Future<void> backupRemSync() async {
  try {
    final b = _backupBase();
    if (b == 0) return;
    var when = DateTime.fromMillisecondsSinceEpoch(b + 7 * _kDay);
    final now = DateTime.now();
    if (when.isBefore(now)) {
      // süre geçmişse yarın 10:00'da hatırlat
      final t = now.add(const Duration(days: 1));
      when = DateTime(t.year, t.month, t.day, 10);
    } else {
      when = DateTime(when.year, when.month, when.day, 10);
      if (when.isBefore(now)) when = now.add(const Duration(hours: 1));
    }
    await Notifier.cancelOnce(_kRemId);
    await Notifier.scheduleOnce(
        _kRemId, tx('Bir haftadır yedek almadın. Ayarlar > Yedek\'ten kaydet.'), when);
  } catch (_) {}
}

/// Ana ekranda yedek hatırlatma satırı (yedek gerekmiyorsa boş)
class BackupLine extends StatelessWidget {
  final VoidCallback onTap;
  const BackupLine({super.key, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        if (!backupDue()) return const SizedBox.shrink();
        final d = backupDaysAgo();
        return Container(
          margin: const EdgeInsets.fromLTRB(16, 0, 16, 8),
          decoration: BoxDecoration(
            color: p.card,
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: p.accent.withOpacity(0.7)),
          ),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              child: Row(
                children: [
                  Icon(Icons.backup_rounded, size: 18, color: p.accent),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                        tx('{0} gündür yedek almadın. Dokun, yedekle.', [d]),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                            fontSize: 13,
                            color: p.ink,
                            fontWeight: FontWeight.w600)),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }
}
