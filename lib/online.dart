import 'package:flutter/material.dart';
import 'data.dart';
import 'media.dart';
import 'net.dart';
import 'strings.dart';
import 'ui.dart';

// ---------------------------------------------------------------
// ONLINE MÜZİK SEKMESİ
//  - Jamendo: bağımsız sanatçıların lisanslı müziği (ücretsiz anahtar ister)
//  - Audius: anahtarsız, topluluk müziği
//  - Favoriler: kalp ile işaretlediklerin (telefonda saklanır)
// Parçalar internetten akıtılır; çalar diğer sekmelerle aynıdır.
// ---------------------------------------------------------------
const _audiusApp = 'DailyRoutine';

// [görünen ad, Jamendo etiketi, Audius arama sözcüğü]
const _genres = <List<String>>[
  ['Pop', 'pop', 'pop'],
  ['Rock', 'rock', 'rock'],
  ['Elektronik', 'electronic', 'electronic'],
  ['Klasik', 'classical', 'classical'],
  ['Caz', 'jazz', 'jazz'],
  ['Hip-hop', 'hiphop', 'hip hop'],
  ['Ambient', 'ambient', 'ambient'],
  ['Lounge', 'lounge', 'lounge'],
];

String _s(dynamic x) => x == null ? '' : x.toString();

Future<List<OnTrack>> _jamendo(String key, String query, String tag) async {
  final q = <String, String>{
    'client_id': key,
    'format': 'json',
    'limit': '30',
    'audioformat': 'mp32',
    'order': 'popularity_week',
  };
  if (query.isNotEmpty) {
    q['search'] = query;
  } else if (tag.isNotEmpty) {
    q['tags'] = tag;
  }
  final j = await httpGetJson(Uri.https('api.jamendo.com', '/v3.0/tracks/', q));
  if (j is! Map) throw const FormatException('biçim');
  final h = j['headers'];
  if (h is Map && _s(h['status']) != 'success') {
    throw Exception(_s(h['error_message']).isEmpty
        ? 'Jamendo hata'
        : _s(h['error_message']));
  }
  final out = <OnTrack>[];
  for (final e in (j['results'] as List? ?? [])) {
    if (e is! Map) continue;
    final url = _s(e['audio']);
    if (url.isEmpty) continue;
    out.add(OnTrack('jam:${_s(e['id'])}', _s(e['name']), _s(e['artist_name']),
        url, _s(e['image'])));
  }
  return out;
}

Future<List<OnTrack>> _audius(String query) async {
  final j = query.isEmpty
      ? await httpGetJson(Uri.https('api.audius.co', '/v1/tracks/trending',
          {'app_name': _audiusApp, 'time': 'week', 'limit': '30'}))
      : await httpGetJson(Uri.https('api.audius.co', '/v1/tracks/search',
          {'query': query, 'app_name': _audiusApp, 'limit': '30'}));
  if (j is! Map) throw const FormatException('biçim');
  final out = <OnTrack>[];
  for (final e in (j['data'] as List? ?? [])) {
    if (e is! Map) continue;
    final id = _s(e['id']);
    if (id.isEmpty) continue;
    final user = e['user'];
    final art = e['artwork'];
    out.add(OnTrack(
        'aud:$id',
        _s(e['title']),
        user is Map ? _s(user['name']) : '',
        'https://api.audius.co/v1/tracks/$id/stream?app_name=$_audiusApp',
        art is Map ? _s(art['480x480'] ?? art['150x150']) : ''));
  }
  return out;
}

class OnlineTab extends StatefulWidget {
  const OnlineTab({super.key});

  @override
  State<OnlineTab> createState() => _OnlineTabState();
}

class _OnlineTabState extends State<OnlineTab>
    with AutomaticKeepAliveClientMixin {
  String _src = 'jam'; // jam | aud | fav
  final _q = TextEditingController();
  int _genre = -1;
  bool _loading = false;
  String? _err;
  List<OnTrack> _res = [];
  bool _loaded = false;

  @override
  bool get wantKeepAlive => true;

  @override
  void dispose() {
    _q.dispose();
    super.dispose();
  }

  Future<void> _search() async {
    if (_src == 'fav') return;
    if (_src == 'jam' && store.jamendoKey.isEmpty) return;
    setState(() {
      _loading = true;
      _err = null;
    });
    final query = _q.text.trim();
    try {
      final List<OnTrack> r;
      if (_src == 'jam') {
        r = await _jamendo(store.jamendoKey, query,
            _genre >= 0 ? _genres[_genre][1] : '');
      } else {
        final word = query.isNotEmpty
            ? query
            : (_genre >= 0 ? _genres[_genre][2] : '');
        r = await _audius(word);
      }
      if (!mounted) return;
      setState(() {
        _res = r;
        _loading = false;
        _loaded = true;
      });
    } catch (e) {
      if (!mounted) return;
      final t = e.toString();
      setState(() {
        _loading = false;
        _res = [];
        _err = tx('{0}: {1}', [
          _src == 'jam' ? 'Jamendo' : 'Audius',
          t.length > 90 ? t.substring(0, 90) : t
        ]);
      });
    }
  }

  Future<void> _setKey() async {
    final k = await askText(context, tx('Jamendo anahtarı (client id)'),
        initial: store.jamendoKey);
    if (k == null) return;
    store.setJamendoKey(k);
    if (k.trim().isNotEmpty) _search();
  }

  void _pickSrc(String s) {
    if (_src == s) return;
    setState(() {
      _src = s;
      _res = [];
      _err = null;
      _loaded = false;
    });
    _search();
  }

  @override
  Widget build(BuildContext context) {
    super.build(context);
    final p = palOf(context);
    return ListenableBuilder(
      listenable: Listenable.merge([store, media]),
      builder: (context, _) {
        final needKey = _src == 'jam' && store.jamendoKey.isEmpty;
        final list = _src == 'fav' ? store.onFavs : _res;
        if (!_loaded && !_loading && _err == null && !needKey && _src != 'fav') {
          WidgetsBinding.instance.addPostFrameCallback((_) {
            if (mounted && !_loaded && !_loading && _err == null) _search();
          });
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
              child: Wrap(
                spacing: 8,
                children: [
                  ChoiceChip(
                      label: const Text('Jamendo'),
                      selected: _src == 'jam',
                      onSelected: (_) => _pickSrc('jam')),
                  ChoiceChip(
                      label: const Text('Audius'),
                      selected: _src == 'aud',
                      onSelected: (_) => _pickSrc('aud')),
                  ChoiceChip(
                      avatar: const Icon(Icons.favorite_rounded, size: 16),
                      label: Text('${tx('Favoriler')} (${store.onFavs.length})'),
                      selected: _src == 'fav',
                      onSelected: (_) => _pickSrc('fav')),
                ],
              ),
            ),
            if (_src != 'fav') ...[
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 0),
                child: Row(
                  children: [
                    Expanded(
                      child: TextField(
                        controller: _q,
                        textInputAction: TextInputAction.search,
                        onSubmitted: (_) {
                          _genre = -1;
                          _search();
                        },
                        decoration: InputDecoration(
                          hintText: tx('Şarkı, sanatçı veya tür ara'),
                          isDense: true,
                          prefixIcon: const Icon(Icons.search_rounded),
                          border: OutlineInputBorder(
                              borderRadius: BorderRadius.circular(14)),
                        ),
                      ),
                    ),
                    if (_src == 'jam')
                      IconButton(
                          tooltip: tx('Jamendo anahtarı'),
                          onPressed: _setKey,
                          icon: const Icon(Icons.key_rounded)),
                  ],
                ),
              ),
              SizedBox(
                height: 46,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    for (var i = 0; i < _genres.length; i++)
                      Padding(
                        padding: const EdgeInsets.only(right: 8, top: 6),
                        child: ChoiceChip(
                          label: Text(tx(_genres[i][0])),
                          selected: _genre == i,
                          onSelected: (_) {
                            _q.clear();
                            _genre = _genre == i ? -1 : i;
                            _search();
                          },
                        ),
                      ),
                  ],
                ),
              ),
            ],
            if (needKey)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                      color: p.card,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(color: p.line)),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                          tx('Jamendo ücretsiz bir geliştirici anahtarı ister: devportal.jamendo.com adresinde hesap açıp bir uygulama oluştur, "Client ID" kodunu buraya yapıştır.'),
                          style: TextStyle(color: p.soft, height: 1.35)),
                      const SizedBox(height: 12),
                      FilledButton.icon(
                          onPressed: _setKey,
                          icon: const Icon(Icons.key_rounded),
                          label: Text(tx('Anahtar gir'))),
                    ],
                  ),
                ),
              )
            else if (_loading)
              const Padding(
                  padding: EdgeInsets.all(30),
                  child: Center(child: CircularProgressIndicator()))
            else if (_err != null)
              Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(_err!,
                        textAlign: TextAlign.center,
                        style: TextStyle(
                            color: Theme.of(context).colorScheme.error)),
                    TextButton(
                        onPressed: _search, child: Text(tx('Yenile'))),
                  ],
                ),
              )
            else if (list.isEmpty)
              Padding(
                padding: const EdgeInsets.all(24),
                child: Text(
                    _src == 'fav'
                        ? tx('Henüz favori yok. Parçadaki kalbe dokun.')
                        : tx('Sonuç yok.'),
                    textAlign: TextAlign.center,
                    style: TextStyle(color: p.soft)),
              )
            else
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: list.length,
                  itemBuilder: (_, i) => _row(context, list, i),
                ),
              ),
          ],
        );
      },
    );
  }

  Widget _row(BuildContext context, List<OnTrack> list, int i) {
    final p = palOf(context);
    final t = list[i];
    final tone = tagTone(t.id);
    final cur = media.nowId == t.id;
    final fav = store.isOnFav(t.id);
    return Container(
      margin: const EdgeInsets.fromLTRB(12, 3, 12, 3),
      decoration: BoxDecoration(
        color: cur
            ? Color.alphaBlend(tone.withOpacity(p.dark ? 0.25 : 0.16), p.card)
            : p.card,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: cur ? tone : p.line),
      ),
      child: ListTile(
        dense: true,
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: SizedBox(
            width: 46,
            height: 46,
            child: t.art.isEmpty
                ? ColoredBox(
                    color: tone.withOpacity(0.25),
                    child: Icon(Icons.music_note_rounded, color: tone))
                : Image.network(
                    t.art,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => ColoredBox(
                        color: tone.withOpacity(0.25),
                        child: Icon(Icons.music_note_rounded, color: tone)),
                  ),
          ),
        ),
        title: Text(t.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
                fontWeight: cur ? FontWeight.w800 : FontWeight.w600,
                color: p.ink)),
        subtitle: Text(t.artist,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(color: p.soft)),
        trailing: IconButton(
          tooltip: fav ? tx('Favorilerden çıkar') : tx('Favorilere ekle'),
          onPressed: () => store.toggleOnFav(t),
          icon: Icon(
              fav ? Icons.favorite_rounded : Icons.favorite_border_rounded,
              color: fav ? const Color(0xFFE95E8F) : p.soft),
        ),
        onTap: () => media.playOnline(list, i),
      ),
    );
  }
}
