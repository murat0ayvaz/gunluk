import 'package:flutter/material.dart';
import 'ambient.dart';
import 'data.dart';
import 'notify.dart';
import 'profile.dart';
import 'strings.dart';
import 'theme.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// KURULUM SİHİRBAZI ("Seni tanıyalım")
//  Tanıtımdan sonra yeni kurulumda bir kez açılır; hepsi atlanabilir.
//  Adımlar: kişisel bilgiler > günlük düzen ve spor > giriş hatırlatması >
//           hangi programlar > hangi rutinler.
//  Mevcut kullanıcı Ayarlar > Beni tanı > "Kurulum sorularını baştan sor" ile açar (fresh: false).
// ---------------------------------------------------------------
const _apps = <(String, String, IconData)>[
  ('todo', 'Yapılacaklar', Icons.task_alt_rounded),
  ('diary', 'Günlük', Icons.menu_book_rounded),
  ('rem', 'Hatırlatıcı', Icons.notifications_active_outlined),
  ('wallet', 'Cüzdan', Icons.account_balance_wallet_rounded),
  ('study', 'Ders çalışma', Icons.school_rounded),
  ('shortcuts', 'Kısayollar', Icons.apps_rounded),
  ('tools', 'Araçlar', Icons.handyman_outlined),
  ('media', 'Medya', Icons.play_circle_rounded),
];

const _mediaSubs = <(String, String)>[
  ('music', 'Müzik'),
  ('radio', 'Radyo'),
  ('tv', 'TV'),
  ('podcast', 'Podcast'),
  ('news', 'Haber'),
  ('online', 'Online'),
];

const _sportKeys = {'run', 'bike', 'swim', 'weights'};

class ProfileWizard extends StatefulWidget {
  final bool fresh; // true: yeni kurulum (hiçbir rutin işaretli başlamaz)
  final VoidCallback onDone;
  const ProfileWizard({super.key, required this.fresh, required this.onDone});

  @override
  State<ProfileWizard> createState() => _ProfileWizardState();
}

class _ProfileWizardState extends State<ProfileWizard> {
  final _ctrl = PageController();
  int _i = 0;
  static const _n = 5;
  late final Map<String, bool> _app = {
    for (final a in _apps) a.$1: !store.appHidden(a.$1),
    for (final m in _mediaSubs) m.$1: !store.appHidden(m.$1),
  };
  // hazır rutinler: alt kategori kimliği -> seçili mi
  late final Map<String, bool> _sel = {
    for (final c in store.cats)
      for (final s in c.subs)
        if (s.key != null) s.id: widget.fresh ? false : s.routine,
  };

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  void _go(int d) {
    final n = (_i + d).clamp(0, _n - 1).toInt();
    _ctrl.animateToPage(n,
        duration: const Duration(milliseconds: 280), curve: Curves.easeOut);
  }

  /// Seçimleri uygular: programlar ve rutinler (profile göre hedef ve günlerle)
  void _finish() {
    for (final a in _apps) {
      store.setAppHidden(a.$1, !(_app[a.$1] ?? true));
    }
    for (final m in _mediaSubs) {
      store.setAppHidden(m.$1, !(_app[m.$1] ?? true));
    }
    final w = store.pNum('weight');
    final goalW = store.pNum('goalW');
    final sport = store.pInt('sport', 0);
    final wake = store.pInt('wake', 480), sleep = store.pInt('sleep', 1320);
    final dur = (((wake + 1440 - sleep) % 1440) / 60 * 2).round() / 2;
    for (final c in List<Category>.of(store.cats)) {
      for (final s in List<SubCat>.of(c.subs)) {
        if (s.key == null) continue;
        final on = _sel[s.id] ?? false;
        final d = SubDraft.from(s)..routine = on;
        if (on) {
          switch (s.key) {
            case 'water':
              d.goal = w == null ? (s.goal ?? 2.0) : ((w * 0.033) * 10).round() / 10;
              break;
            case 'sleep':
              if (store.prof.containsKey('wake') || store.prof.containsKey('sleep')) d.goal = dur;
              break;
            case 'weight':
              d.summable = false;
              if (goalW != null) {
                d.goal = goalW;
                d.isMax = w != null && goalW < w;
              }
              d.days = {1};
              break;
          }
          if (_sportKeys.contains(s.key) && sport > 0) {
            d.days = Set<int>.from(sportDaySets[sport] ?? {1, 3, 5});
          }
        }
        store.updateSub(s.id, d);
      }
    }
    store.setProf('wiz', null); // sihirbaz bitti
    store.markEntryNow();
    entryRemSync();
    widget.onDone();
  }

  Widget _title(Pal p, String t, String sub) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(t, style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
            const SizedBox(height: 4),
            Text(sub, style: TextStyle(color: p.soft, fontSize: 13, height: 1.35)),
          ],
        ),
      );

  @override
  Widget build(BuildContext context) {
    final p = palOf(context);
    final last = _i == _n - 1;
    return AmbScaffold(
      kind: 'settings',
      appBar: AppBar(
        backgroundColor: ambBg(p),
        elevation: 0,
        scrolledUnderElevation: 0,
        automaticallyImplyLeading: false,
        title: Text(tx('Seni tanıyalım')),
        actions: [
          if (!last)
            TextButton(
                onPressed: () => _go(1), child: Text(tx('Bu adımı atla'))),
        ],
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(4),
          child: LinearProgressIndicator(value: (_i + 1) / _n, minHeight: 4),
        ),
      ),
      body: Column(
        children: [
          Expanded(
            child: PageView(
              controller: _ctrl,
              physics: const NeverScrollableScrollPhysics(),
              onPageChanged: (v) => setState(() => _i = v),
              children: [
                _page(p, tx('Kişisel bilgiler'),
                    tx('Bu bilgiler yalnız telefonunda durur, hiçbir yere gönderilmez. Hepsi isteğe bağlı.'),
                    const ProfileForm(parts: {1})),
                _page(p, tx('Günlük düzen ve spor'),
                    tx('Hatırlatmalar uyanık olduğun saatlere ve mesaine göre ayarlanır.'),
                    const ProfileForm(parts: {2})),
                _page(p, tx('Hatırlatma'),
                    tx('Rutin girişi yapmayı unutursan seni uyarsın mı?'),
                    const ProfileForm(parts: {3})),
                _page(p, tx('Hangi programları kullanmak istiyorsun?'),
                    tx('İşaretlemediklerin ekrandan kalkar. Verilerin silinmez, Ayarlar > Uygulamalar\'dan tekrar açabilirsin.'),
                    _appsList(p)),
                _page(p, tx('Hangi rutinler olsun?'),
                    tx('Hazır rutinlerden istediklerini işaretle. Hedefler profiline göre doldurulur; sonradan hepsi değiştirilebilir.'),
                    _routinesList(p)),
              ],
            ),
          ),
          SafeArea(
            top: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 6, 16, 10),
              child: Row(
                children: [
                  if (_i > 0)
                    OutlinedButton(onPressed: () => _go(-1), child: Text(tx('Geri'))),
                  const Spacer(),
                  FilledButton(
                    onPressed: last ? _finish : () => _go(1),
                    child: Text(last ? tx('Bitir') : tx('İleri')),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _page(Pal p, String title, String sub, Widget body) => ListView(
        padding: const EdgeInsets.only(bottom: 16),
        children: [
          _title(p, title, sub),
          Padding(padding: const EdgeInsets.symmetric(horizontal: 16), child: body),
        ],
      );

  Widget _appsList(Pal p) => StatefulBuilder(
        builder: (context, set) => Column(
          children: [
            for (final a in _apps) ...[
              CheckboxListTile(
                contentPadding: EdgeInsets.zero,
                secondary: Icon(a.$3),
                title: Text(tx(a.$2)),
                value: _app[a.$1] ?? true,
                onChanged: (v) => set(() => _app[a.$1] = v ?? true),
              ),
              if (a.$1 == 'media' && (_app['media'] ?? true))
                Padding(
                  padding: const EdgeInsets.only(left: 12, bottom: 6),
                  child: Wrap(spacing: 6, children: [
                    for (final m in _mediaSubs)
                      FilterChip(
                        label: Text(tx(m.$2)),
                        selected: _app[m.$1] ?? true,
                        onSelected: (v) => set(() => _app[m.$1] = v),
                      ),
                  ]),
                ),
            ],
          ],
        ),
      );

  Widget _routinesList(Pal p) => StatefulBuilder(
        builder: (context, set) => Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            for (final c in store.cats)
              if (c.subs.any((s) => s.key != null)) ...[
                Padding(
                  padding: const EdgeInsets.only(top: 12, bottom: 2),
                  child: Text(c.name,
                      style: TextStyle(
                          color: p.soft, fontWeight: FontWeight.w700, fontSize: 13)),
                ),
                for (final s in c.subs)
                  if (s.key != null)
                    CheckboxListTile(
                      contentPadding: EdgeInsets.zero,
                      dense: true,
                      title: Text(s.unit.isEmpty ? s.name : '${s.name} (${s.unit})'),
                      value: _sel[s.id] ?? false,
                      onChanged: (v) => set(() => _sel[s.id] = v ?? false),
                    ),
              ],
          ],
        ),
      );
}
