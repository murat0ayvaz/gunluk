import 'dart:convert';
import 'dart:io';
import 'package:flutter/material.dart';
import 'quotes.dart';
import 'strings.dart';
import 'theme.dart';
import 'version.dart';

// ---------------------------------------------------------------
// VERİ KATMANI: modeller + telefona kayıt (eklentisiz, dosyaya JSON)
// Kayıtlar isme değil KİMLİK (id) numarasına bağlıdır; bu yüzden
// kategori / alt kategori adı değişse bile geçmiş veri bozulmaz.
// ---------------------------------------------------------------

/// Uygulama genelinde tek veri deposu
final store = AppStore();

// ---------- Yardımcı fonksiyonlar ----------

String _two(int n) => n.toString().padLeft(2, '0');

/// Tarihi "yyyy-MM-dd" anahtarına çevirir (kayıtlar bu anahtarla tutulur)
String dKey(DateTime d) => '${d.year}-${_two(d.month)}-${_two(d.day)}';

DateTime dayOnly(DateTime d) => DateTime(d.year, d.month, d.day);

/// "yyyy-MM-dd" anahtarını tarihe çevirir
DateTime parseKey(String k) {
  final p = k.split('-');
  return DateTime(int.parse(p[0]), int.parse(p[1]), int.parse(p[2]));
}

/// "1,5" veya "1.5" yazılmış sayıyı çevirir; geçersizse null
double? parseNum(String s) {
  final t = s.trim().replaceAll(',', '.');
  if (t.isEmpty) return null;
  final v = double.tryParse(t);
  if (v == null || v.isNaN || v.isInfinite) return null;
  return v;
}

String _group(int n) {
  final s = n.toString();
  final b = StringBuffer();
  for (var i = 0; i < s.length; i++) {
    if (i > 0 && (s.length - i) % 3 == 0) b.write('.');
    b.write(s[i]);
  }
  return b.toString();
}

/// Ekranda gösterim: 5000 -> "5.000", 1.5 -> "1,5"
String fmt(double v) {
  final neg = v < 0;
  final r = double.parse(v.abs().toStringAsFixed(2));
  final whole = r.truncate();
  final frac = ((r - whole) * 100).round();
  var out = _group(whole);
  if (frac != 0) {
    out += ',${frac % 10 == 0 ? (frac ~/ 10).toString() : frac.toString().padLeft(2, '0')}';
  }
  return neg ? '-$out' : out;
}

/// Metin kutusuna yazılacak sade biçim (binlik ayraçsız)
String plain(double v) {
  if (v == v.roundToDouble()) return v.toInt().toString();
  return v.toString().replaceAll('.', ',');
}

/// Hedefe ulaşıldı mı? (toplanan veriler için; en fazla = üst sınır)
bool goalMet(SubCat s, double v) {
  final g = s.goal;
  if (g == null || !s.summable) return false;
  return s.isMax ? v <= g : v >= g;
}

// ---------- Hazır liste (iki dilde) ----------
// Hazır kategorilere gizli bir etiket (key) konur. Dil değişince, adını
// kendin değiştirmediysen hazır öğeler yeni dile çevrilir; değiştirdiysen
// senin yazdığın ad kalır.

const _presetCat = <String, List<String>>{
  'sport': ['Spor', 'Sports'],
  'life': ['Yaşam', 'Life'],
  'food': ['Beslenme', 'Nutrition'],
};

// [trAd, enAd, trBirim, enBirim]
const _presetSub = <String, List<String>>{
  'walk': ['Yürüyüş', 'Walking', 'adım', 'steps'],
  'run': ['Koşu', 'Running', 'km', 'km'],
  'bike': ['Bisiklet', 'Cycling', 'km', 'km'],
  'swim': ['Yüzme', 'Swimming', 'dk', 'min'],
  'weights': ['Ağırlık', 'Weight training', 'dk', 'min'],
  'water': ['Su', 'Water', 'lt', 'L'],
  'sleep': ['Uyku', 'Sleep', 'saat', 'hours'],
  'calorie': ['Kalori', 'Calories', 'kcal', 'kcal'],
  'weight': ['Kilo', 'Body weight', 'kg', 'kg'],
};

String presetCatName(String key, String lang) =>
    _presetCat[key]![lang == 'en' ? 1 : 0];
String presetSubName(String key, String lang) =>
    _presetSub[key]![lang == 'en' ? 1 : 0];
String presetSubUnit(String key, String lang) =>
    _presetSub[key]![lang == 'en' ? 3 : 2];

// ---------- Modeller ----------

class SubCat {
  String id;
  String? key; // hazır öğe etiketi (kendi eklediklerinde null)
  String name;
  String unit;
  bool routine; // her gün ana ekranda görünsün mü
  double? goal; // günlük hedef (toplanmayanlarda: hedef değer)
  bool isMax; // true: hedef üst sınırdır (ör. kalori)
  bool summable; // false: toplam anlamsız (ör. kilo)
  Set<int> days; // rutinin görüneceği günler (1 = pazartesi ... 7 = pazar)

  SubCat({
    required this.id,
    this.key,
    required this.name,
    this.unit = '',
    this.routine = false,
    this.goal,
    this.isMax = false,
    this.summable = true,
    Set<int>? days,
  }) : days = days ?? {1, 2, 3, 4, 5, 6, 7};

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'name': name,
        'unit': unit,
        'routine': routine,
        'goal': goal,
        'isMax': isMax,
        'summable': summable,
        'days': days.toList()..sort(),
      };

  factory SubCat.fromJson(Map<String, dynamic> j) => SubCat(
        id: j['id'] as String,
        key: j['key'] as String?,
        name: j['name'] as String,
        unit: (j['unit'] ?? '') as String,
        routine: (j['routine'] ?? false) as bool,
        goal: (j['goal'] as num?)?.toDouble(),
        isMax: (j['isMax'] ?? false) as bool,
        summable: (j['summable'] ?? true) as bool,
        days: ((j['days'] as List?) ?? [1, 2, 3, 4, 5, 6, 7])
            .map((e) => e as int)
            .toSet(),
      );
}

class Category {
  String id;
  String? key; // hazır öğe etiketi
  String name;
  List<SubCat> subs;
  Category(
      {required this.id, this.key, required this.name, required this.subs});

  Map<String, dynamic> toJson() => {
        'id': id,
        'key': key,
        'name': name,
        'subs': subs.map((s) => s.toJson()).toList(),
      };

  factory Category.fromJson(Map<String, dynamic> j) => Category(
        id: j['id'] as String,
        key: j['key'] as String?,
        name: j['name'] as String,
        subs: (j['subs'] as List)
            .map((e) => SubCat.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

class Entry {
  final String id;
  final String date; // yyyy-MM-dd
  final String sub; // alt kategori kimliği
  double value;
  Entry(
      {required this.id,
      required this.date,
      required this.sub,
      required this.value});

  Map<String, dynamic> toJson() =>
      {'id': id, 'date': date, 'sub': sub, 'value': value};

  factory Entry.fromJson(Map<String, dynamic> j) => Entry(
        id: j['id'] as String,
        date: j['date'] as String,
        sub: j['sub'] as String,
        value: (j['value'] as num).toDouble(),
      );
}

/// Yapılacaklar listesindeki bir madde
class Todo {
  final String id;
  String text;
  bool done;
  final int created; // sıralama için (milisaniye)
  Todo(
      {required this.id,
      required this.text,
      this.done = false,
      required this.created});

  Map<String, dynamic> toJson() =>
      {'id': id, 'text': text, 'done': done, 'created': created};

  factory Todo.fromJson(Map<String, dynamic> j) => Todo(
        id: j['id'] as String,
        text: j['text'] as String,
        done: (j['done'] ?? false) as bool,
        created: (j['created'] ?? 0) as int,
      );
}

/// Alt kategori düzenleme penceresinden dönen taslak
class SubDraft {
  String name;
  String unit;
  bool routine;
  double? goal;
  bool isMax;
  bool summable;
  Set<int> days;
  SubDraft({
    this.name = '',
    this.unit = '',
    this.routine = false,
    this.goal,
    this.isMax = false,
    this.summable = true,
    Set<int>? days,
  }) : days = days ?? {1, 2, 3, 4, 5, 6, 7};

  factory SubDraft.from(SubCat s) => SubDraft(
        name: s.name,
        unit: s.unit,
        routine: s.routine,
        goal: s.goal,
        isMax: s.isMax,
        summable: s.summable,
        days: Set<int>.from(s.days),
      );
}

// ---------- Depo ----------

class AppStore extends ChangeNotifier {
  List<Category> cats = [];
  List<Entry> entries = [];
  List<Todo> todos = [];
  Map<String, String> notes = {}; // tarih -> günün notu
  ThemeMode themeMode = ThemeMode.system;
  int accent = 0;
  String lang = 'tr'; // 'tr' veya 'en'
  bool seenIntro = false;
  int lastBuild = 0; // en son açılan sürüm numarası (güncelleme tespiti için)
  bool _updateNotice = false; // bu açılışta "güncellendi" penceresi gösterilsin mi

  // Ana ekrandaki satır sırası (alt kategori kimlikleri; kullanıcı sürükleyerek değiştirir)
  List<String> homeOrder = [];

  // Özlü sözler ayarları
  bool quotesOn = true;
  Set<String> quoteKinds = {'motivation'}; // motivation, ayet, hadis, custom
  int quoteHours = 24; // 0 = her açılışta yeni söz, 24 = günde bir ...
  List<String> customQuotes = [];
  int _quoteBump = 0; // "sonraki söz" için
  int _hiddenSlot = -1; // kartı kapatınca o dilim boyunca gizlenir
  final int _openSeed = DateTime.now().millisecondsSinceEpoch;

  /// Kayıt alanı açılamazsa ekranda uyarı olarak gösterilir
  String? storageError;

  File? _file; // telefondaki veri dosyası
  bool _writing = false;
  bool _dirty = false;
  int _seq = 0;

  String newId() => '${DateTime.now().microsecondsSinceEpoch}_${_seq++}';

  /// Telefonun diline göre başlangıç dilini ayarlar (Türkçe değilse English)
  void prepareLang() {
    final dev = WidgetsBinding.instance.platformDispatcher.locale.languageCode;
    lang = dev == 'tr' ? 'tr' : 'en';
    appLang = lang;
  }

  /// Hata mesajını ekrana sığacak kadar kısaltır
  String _short(Object e) {
    final s = e.toString().replaceAll('\n', ' ');
    return s.length > 120 ? '${s.substring(0, 120)}…' : s;
  }

  /// Uygulamaya özel kalıcı klasörü bulur. EKLENTİ KULLANMAZ (önceki sürümlerde
  /// kayıt eklentisi yayın sürümünde çöktüğü için): Android'de önbellek klasörünün
  /// (.../cache) yanındaki "files" klasörü sadece bu uygulamaya aittir.
  Future<Directory> _baseDir() async {
    final t = Directory.systemTemp.path;
    if (t.startsWith('/data/') && t.endsWith('/cache')) {
      return Directory('${t.substring(0, t.length - '/cache'.length)}/files');
    }
    // Olmazsa süreç adından paket adını bul
    try {
      final raw = await File('/proc/self/cmdline').readAsBytes();
      final end = raw.indexOf(0);
      final pkg =
          String.fromCharCodes(end < 0 ? raw : raw.sublist(0, end)).trim();
      if (pkg.isNotEmpty) return Directory('/data/data/$pkg/files');
    } catch (_) {}
    return Directory.systemTemp;
  }

  Future<File> _dataFile() async {
    final dir = await _baseDir();
    if (!await dir.exists()) await dir.create(recursive: true);
    return File('${dir.path}/gunluk_data.json');
  }

  /// Dosyadaki veriyi belleğe yükler (eski sürümde olmayan alanlar boş başlar)
  void _load(Map<String, dynamic> j) {
    cats = ((j['cats'] as List?) ?? [])
        .map((e) => Category.fromJson(e as Map<String, dynamic>))
        .toList();
    entries = ((j['entries'] as List?) ?? [])
        .map((e) => Entry.fromJson(e as Map<String, dynamic>))
        .toList();
    todos = ((j['todos'] as List?) ?? [])
        .map((e) => Todo.fromJson(e as Map<String, dynamic>))
        .toList();
    notes = ((j['notes'] as Map?) ?? {})
        .map((k, v) => MapEntry(k as String, v as String));

    final s = (j['settings'] as Map?) ?? {};
    final l = s['lang'];
    if (l == 'tr' || l == 'en') {
      lang = l as String;
      appLang = lang;
    }
    themeMode = ThemeMode
        .values[((s['themeMode'] as int?) ?? 0).clamp(0, 2).toInt()];
    accent = ((s['accent'] as int?) ?? 0)
        .clamp(0, accentColors.length - 1)
        .toInt();
    seenIntro = (s['seenIntro'] as bool?) ?? false;
    lastBuild = (s['lastBuild'] as int?) ?? 0;

    homeOrder = ((j['order'] as List?) ?? []).map((e) => e as String).toList();

    final q = (j['quotes'] as Map?) ?? {};
    quotesOn = (q['on'] as bool?) ?? true;
    quoteKinds = ((q['kinds'] as List?) ?? ['motivation'])
        .map((e) => e as String)
        .toSet();
    quoteHours = (q['hours'] as int?) ?? 24;
    customQuotes =
        ((q['custom'] as List?) ?? []).map((e) => e as String).toList();
  }

  /// Açılışta veriyi okur. Ne olursa olsun TAMAMLANIR (takılıp kalmaz):
  /// okuma olmazsa uygulama geçici bellekle çalışır ve uyarı gösterir.
  Future<void> init() async {
    prepareLang(); // kayıtlı dil varsa aşağıda üzerine yazılır
    File? f;
    try {
      f = await _dataFile().timeout(const Duration(seconds: 5));
      _file = f;
    } catch (e) {
      storageError = tx(
          'Kayıt alanı açılamadı; veriler şimdilik sadece bu oturumda tutulacak. ({0})',
          [_short(e)]);
    }

    if (f != null) {
      try {
        if (await f.exists()) {
          final j = jsonDecode(await f.readAsString()) as Map<String, dynamic>;
          _load(j);
        } else {
          cats = _defaults();
          _persist(); // ilk kurulum: dosya oluşturulur
        }
      } catch (e) {
        // Dosya okunamadıysa üzerine yazmadan önce yedeğini al
        try {
          await f.copy('${f.path}.bak');
        } catch (_) {}
        cats = _defaults();
        entries = [];
        todos = [];
        notes = {};
        storageError = tx(
            'Kayıt dosyası okunamadı; eski dosya yedeklendi ve yeni liste açıldı. ({0})',
            [_short(e)]);
      }
    } else if (cats.isEmpty) {
      cats = _defaults();
    }

    // Sürüm numarası değiştiyse uygulama güncellenmiştir (ilk kurulumda değil)
    if (_file != null && lastBuild != appBuild) {
      _updateNotice = seenIntro;
      lastBuild = appBuild;
      _persist();
    }
    notifyListeners();
  }

  /// "Güncellendi" penceresi gösterilecekse true döner (bir kez)
  bool takeUpdateNotice() {
    final v = _updateNotice;
    _updateNotice = false;
    return v;
  }

  /// İlk açılışta gelen hazır liste (hepsi sonradan eklenebilir/silinebilir).
  /// Adlar o anki dilde gelir.
  List<Category> _defaults() {
    SubCat s(String key, {bool isMax = false, bool summable = true}) => SubCat(
          id: newId(),
          key: key,
          name: presetSubName(key, lang),
          unit: presetSubUnit(key, lang),
          isMax: isMax,
          summable: summable,
        );
    Category c(String key, List<SubCat> subs) => Category(
          id: newId(),
          key: key,
          name: presetCatName(key, lang),
          subs: subs,
        );
    return [
      c('sport', [s('walk'), s('run'), s('bike'), s('swim'), s('weights')]),
      c('life', [s('water'), s('sleep')]),
      c('food', [s('calorie', isMax: true), s('weight', summable: false)]),
    ];
  }

  /// Kaydedilecek tüm veri (tek JSON dosyası)
  Map<String, dynamic> _snapshot() => {
        'v': 3,
        'cats': cats.map((c) => c.toJson()).toList(),
        'entries': entries.map((e) => e.toJson()).toList(),
        'todos': todos.map((t) => t.toJson()).toList(),
        'notes': notes,
        'order': homeOrder,
        'quotes': {
          'on': quotesOn,
          'kinds': quoteKinds.toList(),
          'hours': quoteHours,
          'custom': customQuotes,
        },
        'settings': {
          'lang': lang,
          'themeMode': themeMode.index,
          'accent': accent,
          'seenIntro': seenIntro,
          'lastBuild': lastBuild,
        },
      };

  /// Veriyi dosyaya yazar. Art arda çağrılar birleştirilir; yazma önce
  /// geçici dosyaya yapılıp sonra yerine taşınır (yarım kalan yazma veriyi bozmaz).
  void _persist() {
    _dirty = true;
    if (!_writing) _flush();
  }

  Future<void> _flush() async {
    _writing = true;
    try {
      while (_dirty) {
        _dirty = false;
        final f = _file;
        if (f == null) break;
        final data = jsonEncode(_snapshot());
        final tmp = File('${f.path}.tmp');
        await tmp.writeAsString(data, flush: true);
        await tmp.rename(f.path);
      }
    } catch (e) {
      storageError = tx(
          'Kayıt alanı açılamadı; veriler şimdilik sadece bu oturumda tutulacak. ({0})',
          [_short(e)]);
      notifyListeners();
    } finally {
      _writing = false;
    }
  }

  void _commit() {
    _persist();
    notifyListeners();
  }

  // ----- Arama -----

  Category? catById(String id) {
    for (final c in cats) {
      if (c.id == id) return c;
    }
    return null;
  }

  SubCat? subById(String id) {
    for (final c in cats) {
      for (final s in c.subs) {
        if (s.id == id) return s;
      }
    }
    return null;
  }

  Category? catOfSub(String subId) {
    for (final c in cats) {
      for (final s in c.subs) {
        if (s.id == subId) return c;
      }
    }
    return null;
  }

  Entry? entryFor(String subId, String date) {
    for (final e in entries) {
      if (e.sub == subId && e.date == date) return e;
    }
    return null;
  }

  List<Entry> entriesOf(String subId) =>
      entries.where((e) => e.sub == subId).toList();

  int categoryEntryCount(String catId) {
    final c = catById(catId);
    if (c == null) return 0;
    final ids = c.subs.map((s) => s.id).toSet();
    return entries.where((e) => ids.contains(e.sub)).length;
  }

  // ----- Kategori işlemleri -----

  Category addCategory(String name) {
    final n = name.trim();
    for (final c in cats) {
      if (c.name.toLowerCase() == n.toLowerCase()) return c;
    }
    final nc = Category(id: newId(), name: n, subs: []);
    cats.add(nc);
    _commit();
    return nc;
  }

  void renameCategory(String id, String name) {
    final c = catById(id);
    if (c == null || name.trim().isEmpty) return;
    c.name = name.trim();
    _commit();
  }

  /// Kategoriyi ve altındaki tüm kayıtları siler
  void deleteCategory(String id) {
    final c = catById(id);
    if (c == null) return;
    final ids = c.subs.map((s) => s.id).toSet();
    entries.removeWhere((e) => ids.contains(e.sub));
    cats.removeWhere((x) => x.id == id);
    _commit();
  }

  // ----- Alt kategori işlemleri -----

  SubCat addSub(String catId, SubDraft d) {
    final c = catById(catId)!;
    final n = d.name.trim();
    for (final s in c.subs) {
      if (s.name.toLowerCase() == n.toLowerCase()) return s;
    }
    final ns = SubCat(
      id: newId(),
      name: n,
      unit: d.unit.trim(),
      routine: d.routine,
      goal: d.goal,
      isMax: d.isMax,
      summable: d.summable,
      days: Set<int>.from(d.days),
    );
    c.subs.add(ns);
    _commit();
    return ns;
  }

  void updateSub(String subId, SubDraft d) {
    final s = subById(subId);
    if (s == null) return;
    s.name = d.name.trim();
    s.unit = d.unit.trim();
    s.routine = d.routine;
    s.goal = d.goal;
    s.isMax = d.isMax;
    s.summable = d.summable;
    s.days = d.days.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : Set<int>.from(d.days);
    _commit();
  }

  /// Alt kategoriyi ve tüm kayıtlarını siler
  void deleteSub(String subId) {
    for (final c in cats) {
      c.subs.removeWhere((s) => s.id == subId);
    }
    entries.removeWhere((e) => e.sub == subId);
    _commit();
  }

  // ----- Kayıt (günlük veri) işlemleri -----

  /// Aynı alt kategoriye günde tek veri: varsa günceller, yoksa ekler
  void setEntry(String subId, String date, double v) {
    final e = entryFor(subId, date);
    if (e != null) {
      e.value = v;
    } else {
      entries.add(Entry(id: newId(), date: date, sub: subId, value: v));
    }
    _commit();
  }

  void deleteEntry(String id) {
    entries.removeWhere((e) => e.id == id);
    _commit();
  }

  /// "Geri al" için silinen kaydı geri koyar
  void restoreEntry(Entry e) {
    if (entryFor(e.sub, e.date) == null && subById(e.sub) != null) {
      entries.add(e);
      _commit();
    }
  }

  // ----- Yapılacaklar -----

  void addTodo(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    todos.add(Todo(
        id: newId(), text: t, created: DateTime.now().millisecondsSinceEpoch));
    _commit();
  }

  void toggleTodo(String id) {
    for (final t in todos) {
      if (t.id == id) {
        t.done = !t.done;
        break;
      }
    }
    _commit();
  }

  void deleteTodo(String id) {
    todos.removeWhere((t) => t.id == id);
    _commit();
  }

  void restoreTodo(Todo t) {
    if (todos.every((x) => x.id != t.id)) {
      todos.add(t);
      _commit();
    }
  }

  void clearDoneTodos() {
    todos.removeWhere((t) => t.done);
    _commit();
  }

  // ----- Günün notu (günlük) -----

  String noteOf(String date) => notes[date] ?? '';

  /// Boş metin notu siler. notify=false: yazarken ekranı yeniden çizmeden
  /// sadece telefona kaydeder (not ekranı bunu kullanır).
  void setNote(String date, String text, {bool notify = true}) {
    if (text.trim().isEmpty) {
      notes.remove(date);
    } else {
      notes[date] = text;
    }
    if (notify) {
      _commit();
    } else {
      _persist();
    }
  }

  // ----- Ayarlar -----

  void setThemeMode(ThemeMode m) {
    themeMode = m;
    _commit();
  }

  void setAccent(int i) {
    accent = i;
    _commit();
  }

  /// Dili değiştirir. Adı değiştirilmemiş hazır öğeler yeni dile çevrilir.
  void setLang(String l) {
    if (l == lang) return;
    final old = lang;
    for (final c in cats) {
      final ck = c.key;
      if (ck != null &&
          _presetCat.containsKey(ck) &&
          c.name == presetCatName(ck, old)) {
        c.name = presetCatName(ck, l);
      }
      for (final s in c.subs) {
        final sk = s.key;
        if (sk != null && _presetSub.containsKey(sk)) {
          if (s.name == presetSubName(sk, old)) s.name = presetSubName(sk, l);
          if (s.unit == presetSubUnit(sk, old)) s.unit = presetSubUnit(sk, l);
        }
      }
    }
    lang = l;
    appLang = l;
    _commit();
  }

  // ----- Ana ekran satır sırası -----

  /// Sıralama sırasında kullanılır: küçük sayı = daha üstte
  int rankOf(String subId) {
    final i = homeOrder.indexOf(subId);
    return i < 0 ? 1 << 30 : i;
  }

  /// Ekranda görünen satırların yeni sırasını kaydeder. Görünmeyen
  /// alt kategorilerin yerleri korunur (sadece görünenler kendi aralarında
  /// yer değiştirir).
  void setHomeOrder(List<String> visibleNew) {
    final exists = <String>{
      for (final c in cats)
        for (final s in c.subs) s.id,
    };
    final all = homeOrder.where(exists.contains).toList();
    for (final c in cats) {
      for (final s in c.subs) {
        if (!all.contains(s.id)) all.add(s.id);
      }
    }
    final vis = visibleNew.toSet();
    final slots = <int>[
      for (var i = 0; i < all.length; i++)
        if (vis.contains(all[i])) i,
    ];
    for (var k = 0; k < slots.length && k < visibleNew.length; k++) {
      all[slots[k]] = visibleNew[k];
    }
    homeOrder = all;
    _commit();
  }

  // ----- Özlü sözler -----

  /// Seçili türlerdeki sözlerin birleşik listesi
  List<QuoteItem> quotePool() {
    final out = <QuoteItem>[];
    for (final k in ['motivation', 'ayet', 'hadis']) {
      if (quoteKinds.contains(k)) out.addAll(builtInQuotes(k, lang));
    }
    if (quoteKinds.contains('custom')) {
      out.addAll(customQuotes.map((t) => QuoteItem(t, '')));
    }
    return out;
  }

  /// Zaman dilimi numarası: söz bu dilim boyunca aynı kalır
  int quoteSlot() => quoteHours == 0
      ? 0
      : DateTime.now().millisecondsSinceEpoch ~/ (quoteHours * 3600000);

  /// Şu an gösterilecek söz (kapalı / gizli / liste boşsa null)
  QuoteItem? currentQuote() {
    if (!quotesOn) return null;
    if (_hiddenSlot == quoteSlot()) return null;
    final pool = quotePool();
    if (pool.isEmpty) return null;
    final base = (quoteHours == 0 ? _openSeed : quoteSlot()) + _quoteBump;
    final idx = ((base * 1103515245 + 12345) & 0x7fffffff) % pool.length;
    return pool[idx];
  }

  void nextQuote() {
    _quoteBump++;
    notifyListeners();
  }

  void hideQuote() {
    _hiddenSlot = quoteSlot();
    notifyListeners();
  }

  void setQuotesOn(bool v) {
    quotesOn = v;
    _hiddenSlot = -1;
    _commit();
  }

  void toggleQuoteKind(String kind) {
    if (quoteKinds.contains(kind)) {
      quoteKinds.remove(kind);
    } else {
      quoteKinds.add(kind);
    }
    _hiddenSlot = -1;
    _commit();
  }

  void setQuoteHours(int h) {
    quoteHours = h;
    _hiddenSlot = -1;
    _commit();
  }

  void addCustomQuote(String text) {
    final t = text.trim();
    if (t.isEmpty) return;
    customQuotes.add(t);
    _commit();
  }

  void deleteCustomQuote(int index) {
    if (index < 0 || index >= customQuotes.length) return;
    customQuotes.removeAt(index);
    _commit();
  }

  // ----- Yedek (panoya kopyala / yapıştırarak geri yükle) -----

  /// Tüm veriyi (kategoriler, kayıtlar, yapılacaklar, günlük notları, ayarlar)
  /// tek bir metin olarak verir
  String exportBackup() => jsonEncode(_snapshot());

  /// Yedek metnini yükler. Başarılıysa null, değilse hata mesajı döner.
  /// Hata olursa mevcut veri korunur.
  String? importBackup(String text) {
    final before = _snapshot();
    try {
      final j = jsonDecode(text.trim());
      if (j is! Map<String, dynamic> ||
          (j['cats'] == null && j['entries'] == null)) {
        return tx('Bu bir Daily Routine yedeği gibi görünmüyor.');
      }
      _load(j);
      lastBuild = appBuild; // yedekten gelen eski sürüm numarası pencereyi tetiklemesin
      _commit();
      return null;
    } catch (e) {
      try {
        _load(before); // yarım kalan yüklemeyi geri al
      } catch (_) {}
      return tx('Yedek okunamadı: {0}', [_short(e)]);
    }
  }

  void markIntroSeen() {
    seenIntro = true;
    _commit();
  }
}
