import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() => runApp(const GunlukApp());

// ---------------------------------------------------------------
// MODEL: tek bir kayıt (ör. Spor > Yürüyüş > "5000 adım")
// ---------------------------------------------------------------
class Entry {
  final String id;
  final String date; // yyyy-MM-dd
  final String cat; // kategori (başlık)
  final String sub; // alt kategori
  final String value; // serbest metin veri

  Entry({
    required this.id,
    required this.date,
    required this.cat,
    required this.sub,
    required this.value,
  });

  Map<String, dynamic> toJson() =>
      {'id': id, 'date': date, 'cat': cat, 'sub': sub, 'value': value};

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        id: j['id'],
        date: j['date'],
        cat: j['cat'],
        sub: j['sub'],
        value: j['value'],
      );
}

// Alt sayfadan ana sayfaya dönen sonuç: kayıt + (güncellenmiş) kategori listesi
class SheetResult {
  final Entry entry;
  final Map<String, List<String>> cats;
  SheetResult(this.entry, this.cats);
}

// İlk açılışta gelen hazır kategoriler (sonradan istediğin kadar eklenebilir)
Map<String, List<String>> defaultCats() => {
      'Spor': ['Yürüyüş', 'Koşu', 'Bisiklet', 'Yüzme', 'Ağırlık'],
      'Sağlık': ['Su', 'Uyku', 'Kilo'],
      'Beslenme': ['Kahvaltı', 'Öğle', 'Akşam', 'Atıştırmalık'],
      'Diğer': [],
    };

String two(int n) => n.toString().padLeft(2, '0');
String dateKey(DateTime d) => '${d.year}-${two(d.month)}-${two(d.day)}';

// ---------------------------------------------------------------
// UYGULAMA
// ---------------------------------------------------------------
class GunlukApp extends StatelessWidget {
  const GunlukApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Günlük',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(useMaterial3: true, colorSchemeSeed: Colors.teal),
      darkTheme: ThemeData(
        useMaterial3: true,
        colorSchemeSeed: Colors.teal,
        brightness: Brightness.dark,
      ),
      home: const HomePage(),
    );
  }
}

// ---------------------------------------------------------------
// ANA EKRAN: gün seçici + o günün kayıtları
// ---------------------------------------------------------------
class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  List<Entry> entries = [];
  Map<String, List<String>> cats = defaultCats();
  DateTime day = DateTime.now();
  bool loaded = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  // Telefondaki kayıtlı veriyi oku
  Future<void> _load() async {
    final p = await SharedPreferences.getInstance();
    final e = p.getString('entries');
    final c = p.getString('cats');
    if (e != null) {
      entries = (jsonDecode(e) as List)
          .map((x) => Entry.fromJson(x as Map<String, dynamic>))
          .toList();
    }
    if (c != null) {
      final raw = jsonDecode(c) as Map<String, dynamic>;
      cats = raw.map((k, v) => MapEntry(k, List<String>.from(v as List)));
    }
    setState(() => loaded = true);
  }

  // Her değişiklikten sonra telefona yaz
  Future<void> _save() async {
    final p = await SharedPreferences.getInstance();
    await p.setString('entries', jsonEncode(entries.map((e) => e.toJson()).toList()));
    await p.setString('cats', jsonEncode(cats));
  }

  Map<String, List<String>> _copyCats() =>
      cats.map((k, v) => MapEntry(k, List<String>.from(v)));

  // Ekle / düzenle penceresi
  Future<void> _openSheet([Entry? e]) async {
    final res = await showModalBottomSheet<SheetResult>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => EntrySheet(cats: _copyCats(), entry: e, date: dateKey(day)),
    );
    if (res == null) return;
    setState(() {
      cats = res.cats;
      final i = entries.indexWhere((x) => x.id == res.entry.id);
      if (i >= 0) {
        entries[i] = res.entry;
      } else {
        entries.add(res.entry);
      }
    });
    _save();
  }

  Future<void> _pickDate() async {
    final d = await showDatePicker(
      context: context,
      initialDate: day,
      firstDate: DateTime(2020),
      lastDate: DateTime(2100),
    );
    if (d != null) setState(() => day = d);
  }

  void _shift(int n) =>
      setState(() => day = DateTime(day.year, day.month, day.day + n));

  String _label() {
    final now = DateTime.now();
    final s = '${two(day.day)}.${two(day.month)}.${day.year}';
    return dateKey(day) == dateKey(now) ? 'Bugün • $s' : s;
  }

  @override
  Widget build(BuildContext context) {
    final todays = entries.where((e) => e.date == dateKey(day)).toList();

    return Scaffold(
      appBar: AppBar(title: const Text('Günlük')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _openSheet(),
        icon: const Icon(Icons.add),
        label: const Text('Ekle'),
      ),
      body: !loaded
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                // Gün seçici
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    IconButton(
                        onPressed: () => _shift(-1),
                        icon: const Icon(Icons.chevron_left)),
                    TextButton(onPressed: _pickDate, child: Text(_label())),
                    IconButton(
                        onPressed: () => _shift(1),
                        icon: const Icon(Icons.chevron_right)),
                  ],
                ),
                const Divider(height: 1),
                Expanded(
                  child: todays.isEmpty
                      ? const Center(child: Text('Bu güne kayıt yok'))
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 88),
                          itemCount: todays.length,
                          itemBuilder: (_, i) {
                            final e = todays[i];
                            return Dismissible(
                              key: ValueKey(e.id),
                              background: Container(
                                color: Colors.red,
                                alignment: Alignment.centerRight,
                                padding: const EdgeInsets.only(right: 20),
                                child: const Icon(Icons.delete, color: Colors.white),
                              ),
                              direction: DismissDirection.endToStart,
                              onDismissed: (_) {
                                final idx = entries.indexOf(e);
                                setState(() => entries.remove(e));
                                _save();
                                ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                                  content: const Text('Silindi'),
                                  action: SnackBarAction(
                                    label: 'Geri al',
                                    onPressed: () {
                                      setState(() => entries.insert(
                                          idx > entries.length ? entries.length : idx, e));
                                      _save();
                                    },
                                  ),
                                ));
                              },
                              child: ListTile(
                                title: Text(e.sub),
                                subtitle: Text(e.cat),
                                trailing: Text(e.value,
                                    style: Theme.of(context).textTheme.titleMedium),
                                onTap: () => _openSheet(e), // dokununca düzenle
                              ),
                            );
                          },
                        ),
                ),
              ],
            ),
    );
  }
}

// ---------------------------------------------------------------
// EKLE / DÜZENLE: kategori seç -> alt kategori seç -> veri yaz
// Her seviyede "+ Yeni" ile istenen yere yeni öğe eklenebilir
// ---------------------------------------------------------------
class EntrySheet extends StatefulWidget {
  final Map<String, List<String>> cats;
  final Entry? entry;
  final String date;

  const EntrySheet({
    super.key,
    required this.cats,
    required this.entry,
    required this.date,
  });

  @override
  State<EntrySheet> createState() => _EntrySheetState();
}

class _EntrySheetState extends State<EntrySheet> {
  late Map<String, List<String>> cats;
  String? cat;
  String? sub;
  late final TextEditingController valueCtrl;

  @override
  void initState() {
    super.initState();
    cats = widget.cats;
    cat = widget.entry?.cat;
    sub = widget.entry?.sub;
    valueCtrl = TextEditingController(text: widget.entry?.value ?? '');
  }

  @override
  void dispose() {
    valueCtrl.dispose();
    super.dispose();
  }

  Future<void> _newCat() async {
    final name = await askText(context, 'Yeni kategori');
    if (name == null) return;
    setState(() {
      cats.putIfAbsent(name, () => []);
      if (cat != name) sub = null;
      cat = name;
    });
  }

  // Seçili kategorinin altına yeni alt kategori ekler
  Future<void> _newSub() async {
    final name = await askText(context, '"$cat" altına yeni alt kategori');
    if (name == null) return;
    setState(() {
      final list = cats[cat]!;
      if (!list.contains(name)) list.add(name);
      sub = name;
    });
  }

  void _save() {
    final e = Entry(
      id: widget.entry?.id ?? DateTime.now().microsecondsSinceEpoch.toString(),
      date: widget.entry?.date ?? widget.date,
      cat: cat!,
      sub: sub!,
      value: valueCtrl.text.trim(),
    );
    Navigator.pop(context, SheetResult(e, cats));
  }

  @override
  Widget build(BuildContext context) {
    final canSave = cat != null && sub != null && valueCtrl.text.trim().isNotEmpty;

    return Padding(
      // Klavye açılınca içerik yukarı kalksın
      padding: EdgeInsets.fromLTRB(
          16, 16, 16, 16 + MediaQuery.of(context).viewInsets.bottom),
      child: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Kategori', style: Theme.of(context).textTheme.titleSmall),
            const SizedBox(height: 8),
            Wrap(spacing: 8, runSpacing: 4, children: [
              for (final c in cats.keys)
                ChoiceChip(
                  label: Text(c),
                  selected: cat == c,
                  onSelected: (_) => setState(() {
                    if (cat != c) sub = null;
                    cat = c;
                  }),
                ),
              ActionChip(
                  avatar: const Icon(Icons.add, size: 18),
                  label: const Text('Yeni'),
                  onPressed: _newCat),
            ]),
            if (cat != null) ...[
              const SizedBox(height: 16),
              Text('Alt kategori', style: Theme.of(context).textTheme.titleSmall),
              const SizedBox(height: 8),
              Wrap(spacing: 8, runSpacing: 4, children: [
                for (final s in cats[cat]!)
                  ChoiceChip(
                    label: Text(s),
                    selected: sub == s,
                    onSelected: (_) => setState(() => sub = s),
                  ),
                ActionChip(
                    avatar: const Icon(Icons.add, size: 18),
                    label: const Text('Yeni'),
                    onPressed: _newSub),
              ]),
            ],
            const SizedBox(height: 16),
            TextField(
              controller: valueCtrl,
              decoration: const InputDecoration(
                labelText: 'Veri',
                hintText: 'ör. 5000 adım',
                border: OutlineInputBorder(),
              ),
              onChanged: (_) => setState(() {}),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              child: FilledButton(
                onPressed: canSave ? _save : null,
                child: const Text('Kaydet'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------
// Küçük metin giriş penceresi (yeni kategori / alt kategori için)
// ---------------------------------------------------------------
Future<String?> askText(BuildContext context, String title) {
  return showDialog<String>(
    context: context,
    builder: (_) => _AskDialog(title: title),
  );
}

class _AskDialog extends StatefulWidget {
  final String title;
  const _AskDialog({required this.title});

  @override
  State<_AskDialog> createState() => _AskDialogState();
}

class _AskDialogState extends State<_AskDialog> {
  final ctrl = TextEditingController();

  @override
  void dispose() {
    ctrl.dispose();
    super.dispose();
  }

  void _ok() {
    final t = ctrl.text.trim();
    Navigator.pop(context, t.isEmpty ? null : t);
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: TextField(
        controller: ctrl,
        autofocus: true,
        textCapitalization: TextCapitalization.sentences,
        onSubmitted: (_) => _ok(),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context), child: const Text('İptal')),
        FilledButton(onPressed: _ok, child: const Text('Ekle')),
      ],
    );
  }
}
