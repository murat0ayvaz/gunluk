import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'data.dart';
import 'notify.dart';
import 'strings.dart';
import 'timing.dart' show appLaunchOf, showAppSchedule;
import 'ui.dart';

// ---------------------------------------------------------------
// KISAYOLLAR
//  - Telefondaki yüklü uygulamalardan seçtiklerin burada kısayol olur; dokununca açılır.
//  - Her uygulama için otomatik başlatma: saati gelince bildirim gelir, dokununca
//    uygulama açılır (Android, uygulamayı bildirime dokunulmadan başlatmaya izin vermez).
//  - Android tarafı: MainActivity'deki "gunluk/apps" kanalı (derleme dosyası ekler).
// ---------------------------------------------------------------

class AppsChannel {
  static const _c = MethodChannel('gunluk/apps');

  /// Telefondaki başlatılabilir uygulamalar: (ad, paket)
  static Future<List<(String, String)>> list() async {
    try {
      final r = await _c.invokeMethod<List<dynamic>>('list');
      final out = <(String, String)>[];
      for (final e in r ?? const []) {
        final m = Map<String, dynamic>.from(e as Map);
        out.add(('${m['name']}', '${m['pkg']}'));
      }
      out.sort((a, b) => a.$1.toLowerCase().compareTo(b.$1.toLowerCase()));
      return out;
    } catch (_) {
      return [];
    }
  }

  static Future<bool> launch(String pkg) async {
    try {
      return (await _c.invokeMethod<bool>('launch', {'pkg': pkg})) ?? false;
    } catch (_) {
      return false;
    }
  }
}

/// Telefondaki uygulamalardan birini seçtirir: (ad, paket); vazgeçilirse null
Future<(String, String)?> pickPhoneApp(BuildContext context) =>
    showDialog<(String, String)>(
        context: context, builder: (_) => const _AppPicker());

class ShortcutsPage extends StatelessWidget {
  const ShortcutsPage({super.key});

  Future<void> _pick(BuildContext context) async {
    final r = await showDialog<(String, String)>(
        context: context, builder: (_) => const _AppPicker());
    if (r == null) return;
    store.addShortcut(r.$1, r.$2);
  }

  Future<void> _open(BuildContext context, AppShortcut s) async {
    final ok = await AppsChannel.launch(s.pkg);
    if (!ok && context.mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(tx('Uygulama açılamadı. Silinmiş olabilir.'))));
    }
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    return ListenableBuilder(
      listenable: store,
      builder: (context, _) {
        final list = store.shortcuts;
        return Scaffold(
          backgroundColor: p.bg,
          appBar: AppBar(title: Text(tx('Kısayollar'))),
          floatingActionButton: FloatingActionButton.extended(
            onPressed: () => _pick(context),
            icon: const Icon(Icons.add_rounded),
            label: Text(tx('Uygulama ekle')),
          ),
          body: ListView(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 90),
            children: [
              Text(
                  tx('Telefondaki bir uygulamayı ekle; dokununca açılır. Saat ayarlarsan o saatte bildirim gelir, bildirime dokununca uygulama açılır.'),
                  style: TextStyle(color: p.soft, fontSize: 13, height: 1.4)),
              const SizedBox(height: 12),
              if (list.isEmpty)
                Padding(
                  padding: const EdgeInsets.all(24),
                  child: Text(tx('Henüz kısayol yok.'),
                      textAlign: TextAlign.center,
                      style: TextStyle(color: p.soft)),
                ),
              for (final s in list)
                Builder(builder: (context) {
                  final a = appLaunchOf(s.pkg);
                  return Container(
                    margin: const EdgeInsets.only(bottom: 8),
                    decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.line),
                    ),
                    child: ListTile(
                      onTap: () => _open(context, s),
                      leading: CircleAvatar(
                        backgroundColor: p.accent.withOpacity(0.25),
                        child: Text(
                            s.name.isEmpty ? '?' : s.name.characters.first.toUpperCase(),
                            style: TextStyle(
                                color: p.ink, fontWeight: FontWeight.w800)),
                      ),
                      title: Text(s.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: p.ink, fontWeight: FontWeight.w700)),
                      subtitle: a == null
                          ? null
                          : Text(
                              '${a.h.toString().padLeft(2, '0')}:${a.m.toString().padLeft(2, '0')}${a.on ? '' : ' (${tx('kapalı')})'}',
                              style: TextStyle(color: p.soft)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: tx('Otomatik başlat'),
                            icon: Icon(
                                a != null && a.on
                                    ? Icons.alarm_on_rounded
                                    : Icons.alarm_add_outlined,
                                color: a != null && a.on ? p.accent : null),
                            onPressed: () => showAppSchedule(context, s),
                          ),
                          if (a != null)
                            Switch(
                              value: a.on,
                              onChanged: (v) async {
                                a.on = v;
                                store.touchLauncher();
                                await Notifier.syncLauncher(a);
                              },
                            ),
                          IconButton(
                            icon: const Icon(Icons.delete_outline_rounded),
                            onPressed: () async {
                              final ok = await confirmDialog(
                                  context, tx('Kısayol silinsin mi?'), s.name);
                              if (ok) {
                                final gone = store.removeShortcut(s.id);
                                for (final g in gone) {
                                  await Notifier.cancelLauncher(g);
                                }
                              }
                            },
                          ),
                        ],
                      ),
                    ),
                  );
                }),
            ],
          ),
        );
      },
    );
  }
}

/// Telefondaki uygulamalardan seçim (arama kutulu)
class _AppPicker extends StatefulWidget {
  const _AppPicker();

  @override
  State<_AppPicker> createState() => _AppPickerState();
}

class _AppPickerState extends State<_AppPicker> {
  List<(String, String)>? _all;
  String _q = '';

  @override
  void initState() {
    super.initState();
    AppsChannel.list().then((l) {
      if (mounted) setState(() => _all = l);
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final all = _all;
    final q = _q.toLowerCase();
    final list = all == null
        ? <(String, String)>[]
        : [
            for (final a in all)
              if (!store.hasShortcut(a.$2) &&
                  (q.isEmpty || a.$1.toLowerCase().contains(q)))
                a
          ];
    return AlertDialog(
      title: Text(tx('Uygulama seç')),
      content: SizedBox(
        width: double.maxFinite,
        height: 420,
        child: Column(
          children: [
            TextField(
              decoration: InputDecoration(
                  prefixIcon: const Icon(Icons.search_rounded),
                  hintText: tx('Ara'),
                  isDense: true),
              onChanged: (v) => setState(() => _q = v),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: all == null
                  ? const Center(child: CircularProgressIndicator())
                  : list.isEmpty
                      ? Center(
                          child: Text(
                              all.isEmpty
                                  ? tx('Uygulama listesi alınamadı.')
                                  : tx('Uygulama bulunamadı.'),
                              style: TextStyle(color: p.soft)))
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (context, i) => ListTile(
                            dense: true,
                            leading: CircleAvatar(
                              radius: 16,
                              backgroundColor: p.accent.withOpacity(0.25),
                              child: Text(
                                  list[i].$1.isEmpty
                                      ? '?'
                                      : list[i].$1.characters.first.toUpperCase(),
                                  style: TextStyle(color: p.ink)),
                            ),
                            title: Text(list[i].$1,
                                maxLines: 1, overflow: TextOverflow.ellipsis),
                            onTap: () => Navigator.pop(context, list[i]),
                          ),
                        ),
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
            onPressed: () => Navigator.pop(context), child: Text(tx('Kapat'))),
      ],
    );
  }
}
