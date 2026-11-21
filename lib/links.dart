import 'package:flutter/material.dart';
import 'data.dart';
import 'diary.dart';
import 'media.dart';
import 'settings.dart';
import 'shortcuts.dart';
import 'strings.dart';
import 'study.dart';
import 'tools.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// RUTİNE BAĞLAMA
//  Rutine uygulama içi bir yer (Ders çalışma, bir araç, Müzik/Radyo...) ya da
//  telefondaki bir uygulama bağlanır. Rutinin adına dokununca (veya hatırlatma
//  bildirimine dokununca) bağlı yer açılır.
//  Kayıt biçimi: in:study | in:study:lgs | in:tool:<araç> | in:media:<sekme> |
//                in:diary | in:shortcuts | in:settings | app:<paket>|<ad>
// ---------------------------------------------------------------

class LinkTarget {
  final String id;
  final String label;
  final IconData icon;
  const LinkTarget(this.id, this.label, this.icon);
}

/// Uygulama içi bağlanabilir yerler
List<LinkTarget> inAppTargets() => [
      LinkTarget('in:study', tx('Ders çalışma'), Icons.school_rounded),
      LinkTarget('in:study:lgs', '${tx('Ders çalışma')}: ${tx('LGS')}',
          Icons.menu_book_rounded),
      LinkTarget('in:study:dil', '${tx('Ders çalışma')}: ${tx('Yabancı dil')}',
          Icons.translate_rounded),
      for (final t in toolList())
        LinkTarget('in:tool:${t.$1}', '${tx('Araçlar')}: ${t.$2}', t.$3),
      LinkTarget('in:media:music', '${tx('Müzik ve Radyo')}: ${tx('Müzik')}',
          Icons.music_note_rounded),
      LinkTarget('in:media:radio', '${tx('Müzik ve Radyo')}: ${tx('Radyo')}',
          Icons.radio_rounded),
      LinkTarget('in:media:tv', '${tx('Müzik ve Radyo')}: ${tx('TV')}',
          Icons.live_tv_rounded),
      LinkTarget('in:media:podcast', '${tx('Müzik ve Radyo')}: ${tx('Podcast')}',
          Icons.podcasts_rounded),
      LinkTarget('in:media:news', '${tx('Müzik ve Radyo')}: ${tx('Haber')}',
          Icons.newspaper_rounded),
      LinkTarget('in:media:online', '${tx('Müzik ve Radyo')}: ${tx('Online')}',
          Icons.cloud_queue_rounded),
      LinkTarget('in:diary', tx('Günlük'), Icons.menu_book_rounded),
      LinkTarget('in:shortcuts', tx('Kısayollar'), Icons.apps_rounded),
      LinkTarget('in:settings', tx('Ayarlar'), Icons.settings_outlined),
    ];

/// Bağlantının görünen adı ('' ise bağlantı yok)
String linkLabel(String link) {
  if (link.isEmpty) return '';
  if (link.startsWith('app:')) {
    final i = link.indexOf('|');
    return i < 0 ? link.substring(4) : link.substring(i + 1);
  }
  for (final t in inAppTargets()) {
    if (t.id == link) return t.label;
  }
  return '';
}

IconData linkIcon(String link) {
  if (link.startsWith('app:')) return Icons.open_in_new_rounded;
  for (final t in inAppTargets()) {
    if (t.id == link) return t.icon;
  }
  return Icons.link_rounded;
}

/// Bağlı yeri açar; kapalı bölüm ya da açılamayan uygulama için kısa uyarı verir
Future<void> openLink(BuildContext context, String link) async {
  if (link.isEmpty) return;
  void warn(String m) {
    if (!context.mounted) return;
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(SnackBar(content: Text(m)));
  }

  final nav = Navigator.of(context);
  if (link.startsWith('app:')) {
    final rest = link.substring(4);
    final i = rest.indexOf('|');
    final pkg = i < 0 ? rest : rest.substring(0, i);
    final ok = await AppsChannel.launch(pkg);
    if (!ok) warn(tx('Uygulama açılamadı. Silinmiş olabilir.'));
    return;
  }
  final parts = link.split(':'); // in, tür, [ayrıntı]
  if (parts.length < 2) return;
  switch (parts[1]) {
    case 'study':
      if (store.appHidden('study')) return warn(tx('Bu bölüm kapalı.'));
      if (parts.length > 2) {
        if (store.appHidden('study_${parts[2]}')) {
          return warn(tx('Bu bölüm kapalı.'));
        }
        store.setStudyTab(parts[2]);
      }
      nav.push(slideFromRight(const StudyPage()));
      break;
    case 'tool':
      final id = parts.length > 2 ? parts[2] : '';
      if (store.hiddenTools.contains(id) ||
          (id == 'wallet' && store.appHidden('wallet'))) {
        return warn(tx('Bu bölüm kapalı.'));
      }
      final page = toolPageOf(id);
      if (page == null) return warn(tx('Bu bölüm bulunamadı.'));
      nav.push(slideFromRight(page));
      break;
    case 'media':
      final tab = parts.length > 2 ? parts[2] : null;
      if (store.appHidden('media') ||
          (tab != null && store.appHidden(tab))) {
        return warn(tx('Bu bölüm kapalı.'));
      }
      nav.push(slideFromRight(MediaPage(initial: tab)));
      break;
    case 'diary':
      if (store.appHidden('diary')) return warn(tx('Bu bölüm kapalı.'));
      nav.push(MaterialPageRoute<void>(builder: (_) => const DiaryCalendarPage()));
      break;
    case 'shortcuts':
      if (store.appHidden('shortcuts')) return warn(tx('Bu bölüm kapalı.'));
      nav.push(slideFromRight(const ShortcutsPage()));
      break;
    case 'settings':
      nav.push(MaterialPageRoute<void>(builder: (_) => const SettingsPage()));
      break;
  }
}

/// Bağlanacak yeri seçtirir: "Uygulama içi" listesi + "Telefon uygulaması".
/// Dönen: bağlantı metni; vazgeçilirse null.
Future<String?> pickLink(BuildContext context) {
  return showDialog<String>(
    context: context,
    builder: (ctx) {
      final p = palOf(ctx);
      final list = inAppTargets();
      return AlertDialog(
        title: Text(tx('Bağla')),
        content: SizedBox(
          width: double.maxFinite,
          height: 440,
          child: ListView(
            children: [
              ListTile(
                dense: true,
                leading: const Icon(Icons.phone_android_rounded),
                title: Text(tx('Telefondaki uygulama seç…'),
                    style: const TextStyle(fontWeight: FontWeight.w700)),
                onTap: () async {
                  final r = await pickPhoneApp(ctx);
                  if (r != null && ctx.mounted) {
                    Navigator.pop(ctx, 'app:${r.$2}|${r.$1}');
                  }
                },
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 10, 16, 4),
                child: Text(tx('Uygulama içi'),
                    style: TextStyle(color: p.soft, fontSize: 12.5)),
              ),
              for (final t in list)
                ListTile(
                  dense: true,
                  leading: Icon(t.icon),
                  title: Text(t.label),
                  onTap: () => Navigator.pop(ctx, t.id),
                ),
            ],
          ),
        ),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: Text(tx('Kapat'))),
        ],
      );
    },
  );
}
