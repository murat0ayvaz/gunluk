import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math';
import 'package:crypto/crypto.dart';
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

/// Şifreyi tuzla birlikte 5000 tur SHA-256 ile özetler (düz şifre saklanmaz)
String hashPassword(String pw, String salt) {
  final saltBytes = utf8.encode(salt);
  List<int> bytes = utf8.encode('$salt:$pw');
  for (var i = 0; i < 5000; i++) {
    bytes = sha256.convert([...bytes, ...saltBytes]).bytes;
  }
  return base64Encode(bytes);
}

String _randomSalt() {
  final r = Random.secure();
  return base64Encode(List<int>.generate(16, (_) => r.nextInt(256)));
}

/// Bugünün hedef durumu: ulaşılan / toplam hedef sayısı
class GoalStat {
  final int met;
  final int total;
  const GoalStat(this.met, this.total);
  int get pct => total == 0 ? 0 : (met * 100 / total).round();
  bool get all => total > 0 && met >= total;
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
  'faith': ['Din', 'Faith'],
  'growth': ['Kişisel gelişim', 'Personal growth'],
  'edu': ['Eğitim', 'Education'],
  'fun': ['Eğlence', 'Entertainment'],
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
  'pill': ['İlaç', 'Medication', '', ''],
  'fast': ['Oruç Tut', 'Fasting', 'gün', 'days'],
  'quran': ['Kuran oku', 'Read Quran', 'sayfa', 'pages'],
  'hadith': ['Hadis Oku', 'Read Hadith', 'adet', 'items'],
  'listen': ['Süre dinle', 'Listen to Surah', '', ''],
  'book': ['Kitap', 'Book', 'sayfa', 'pages'],
  'meditate': ['Meditasyon', 'Meditation', 'dk', 'min'],
  'language': ['Yabancı dil', 'Foreign language', 'dk', 'min'],
  'hobby': ['Hobi', 'Hobby', '', ''],
  'science': ['Fen', 'Science', 'soru', 'questions'],
  'math': ['Matematik', 'Math', 'soru', 'questions'],
  'turkish': ['Türkçe', 'Turkish', 'soru', 'questions'],
  'mock': ['Deneme', 'Practice exam', '', ''],
  'series': ['Dizi', 'TV series', 'bölüm', 'episodes'],
  'movie': ['Film', 'Movie', '', ''],
  'game': ['Oyun', 'Games', 'dk', 'min'],
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
  Set<String> skip; // rutinin sadece o gün gizlendiği tarihler (yyyy-MM-dd)
  int rh; // rutin hatırlatma saati (-1 = hatırlatma yok)
  int rm; // rutin hatırlatma dakikası
  int nid; // bildirim numarası (0 = yok)

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
    Set<String>? skip,
    this.rh = -1,
    this.rm = 0,
    this.nid = 0,
  })  : days = days ?? {1, 2, 3, 4, 5, 6, 7},
        skip = skip ?? <String>{};

  /// Rutin bu tarihte listelenmeli mi? (seçili gün + o güne özel gizleme yok)
  bool scheduledOn(DateTime d) =>
      routine && days.contains(d.weekday) && !skip.contains(dKey(d));

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
        'skip': skip.toList()..sort(),
        'rh': rh,
        'rm': rm,
        'nid': nid,
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
        skip: ((j['skip'] as List?) ?? []).map((e) => e as String).toSet(),
        rh: (j['rh'] ?? -1) as int,
        rm: (j['rm'] ?? 0) as int,
        nid: (j['nid'] ?? 0) as int,
      );
}

/// Müzik listesindeki şarkı (dosya uygulamanın kendi klasörüne kopyalanır)
class Song {
  final String id;
  String title;
  String path;
  Song({required this.id, required this.title, required this.path});

  Map<String, dynamic> toJson() => {'id': id, 'title': title, 'path': path};

  factory Song.fromJson(Map<String, dynamic> j) => Song(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        path: (j['path'] ?? '') as String,
      );
}

/// Oynatma listesi (içindeki şarkıların sırası listenin sırasıdır)
/// Yapılan bir meditasyon seansı (Meditasyon sayfasındaki kayıt listesi)
class MedSession {
  final String id;
  final int ms; // seansın bittiği zaman
  final double minutes; // süre (dakika)
  String note;
  MedSession(this.id, this.ms, this.minutes, [this.note = '']);

  Map<String, dynamic> toJson() =>
      {'id': id, 'ms': ms, 'm': minutes, 'n': note};

  factory MedSession.fromJson(Map<String, dynamic> j) => MedSession(
      (j['id'] ?? '').toString(),
      (j['ms'] ?? 0) as int,
      ((j['m'] ?? 0) as num).toDouble(),
      (j['n'] ?? '').toString());
}

/// Online müzik parçası (Jamendo / Audius)
class OnTrack {
  final String id; // 'jam:123' / 'aud:abc'
  final String title;
  final String artist;
  final String url; // yayın adresi
  final String art; // kapak resmi
  OnTrack(this.id, this.title, this.artist, this.url, this.art);

  Map<String, dynamic> toJson() =>
      {'id': id, 't': title, 'a': artist, 'u': url, 'r': art};

  factory OnTrack.fromJson(Map<String, dynamic> j) => OnTrack(
      (j['id'] ?? '').toString(),
      (j['t'] ?? '').toString(),
      (j['a'] ?? '').toString(),
      (j['u'] ?? '').toString(),
      (j['r'] ?? '').toString());
}

class Playlist {
  final String id;
  String name;
  bool open; // ekranda aşağı doğru açık mı
  List<Song> songs;
  Playlist(
      {required this.id,
      required this.name,
      this.open = true,
      List<Song>? songs})
      : songs = songs ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'open': open,
        'songs': songs.map((s) => s.toJson()).toList(),
      };

  factory Playlist.fromJson(Map<String, dynamic> j) => Playlist(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        open: (j['open'] ?? true) as bool,
        songs: ((j['songs'] as List?) ?? [])
            .map((e) => Song.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Radyo istasyonu (ad + yayın adresi)
class Station {
  final String id;
  String name;
  String url;
  bool fav; // favori (yıldız)
  Station({required this.id, required this.name, required this.url, this.fav = false});

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'url': url, 'fav': fav};

  factory Station.fromJson(Map<String, dynamic> j) => Station(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        url: (j['url'] ?? '') as String,
        fav: (j['fav'] ?? false) as bool,
      );
}

/// Radyo kategorisi (ör. Genel, Haber)
class RadioCat {
  final String id;
  String name;
  bool open;
  List<Station> stations;
  RadioCat(
      {required this.id,
      required this.name,
      this.open = true,
      List<Station>? stations})
      : stations = stations ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'open': open,
        'stations': stations.map((s) => s.toJson()).toList(),
      };

  factory RadioCat.fromJson(Map<String, dynamic> j) => RadioCat(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        open: (j['open'] ?? true) as bool,
        stations: ((j['stations'] as List?) ?? [])
            .map((e) => Station.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Takip edilen podcast (bölümler her açılışta internetten okunur)
class Podcast {
  final String id;
  String title;
  String author;
  String feed; // RSS adresi
  String art; // kapak resmi adresi
  bool open;
  bool fav; // favori (yıldız)
  Podcast(
      {required this.id,
      required this.title,
      this.author = '',
      required this.feed,
      this.art = '',
      this.open = false,
      this.fav = false});

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'author': author,
        'feed': feed,
        'art': art,
        'open': open,
        'fav': fav,
      };

  factory Podcast.fromJson(Map<String, dynamic> j) => Podcast(
        id: j['id'] as String,
        title: (j['title'] ?? '') as String,
        author: (j['author'] ?? '') as String,
        feed: (j['feed'] ?? '') as String,
        art: (j['art'] ?? '') as String,
        open: (j['open'] ?? false) as bool,
        fav: (j['fav'] ?? false) as bool,
      );
}

/// Podcast kategorisi (ör. Genel, Haber)
class PodCat {
  final String id;
  String name;
  bool open;
  List<Podcast> pods;
  PodCat(
      {required this.id,
      required this.name,
      this.open = true,
      List<Podcast>? pods})
      : pods = pods ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'open': open,
        'pods': pods.map((p) => p.toJson()).toList(),
      };

  factory PodCat.fromJson(Map<String, dynamic> j) => PodCat(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        open: (j['open'] ?? true) as bool,
        pods: ((j['pods'] as List?) ?? [])
            .map((e) => Podcast.fromJson(e as Map<String, dynamic>))
            .toList(),
      );
}

/// Haber kaynağı (RSS adresi)
class NewsSrc {
  final String id;
  String name;
  String url;
  bool open;
  NewsSrc(
      {required this.id,
      required this.name,
      required this.url,
      this.open = false});

  Map<String, dynamic> toJson() =>
      {'id': id, 'name': name, 'url': url, 'open': open};

  factory NewsSrc.fromJson(Map<String, dynamic> j) => NewsSrc(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        url: (j['url'] ?? '') as String,
        open: (j['open'] ?? false) as bool,
      );
}

/// Haber kategorisi (ör. Gündem, Spor)
class NewsCat {
  final String id;
  String name;
  bool open;
  List<NewsSrc> srcs;
  NewsCat(
      {required this.id,
      required this.name,
      this.open = true,
      List<NewsSrc>? srcs})
      : srcs = srcs ?? [];

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'open': open,
        'srcs': srcs.map((s) => s.toJson()).toList(),
      };

  factory NewsCat.fromJson(Map<String, dynamic> j) => NewsCat(
        id: j['id'] as String,
        name: (j['name'] ?? '') as String,
        open: (j['open'] ?? true) as bool,
        srcs: ((j['srcs'] as List?) ?? [])
            .map((e) => NewsSrc.fromJson(e as Map<String, dynamic>))
            .toList(),
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
  int nid; // bildirim numarası (0 = yok)
  int remindMs; // hatırlatma zamanı (0 = yok)
  int remindEvery; // tekrar aralığı (dakika, 0 = tek sefer)
  int remindCount; // toplam kaç kez bildirilecek
  String voice; // ses kaydı dosya adı ('' = yok)
  String day; // yapılacağı gün (yyyy-MM-dd)
  Todo(
      {required this.id,
      required this.text,
      this.done = false,
      required this.created,
      this.nid = 0,
      this.remindMs = 0,
      this.remindEvery = 0,
      this.remindCount = 1,
      this.voice = '',
      this.day = ''});

  Map<String, dynamic> toJson() => {
        'id': id,
        'day': day,
        'text': text,
        'voice': voice,
        'done': done,
        'created': created,
        'nid': nid,
        'rms': remindMs,
        'rev': remindEvery,
        'rct': remindCount,
      };

  factory Todo.fromJson(Map<String, dynamic> j) => Todo(
        id: j['id'] as String,
        text: j['text'] as String,
        done: (j['done'] ?? false) as bool,
        created: (j['created'] ?? 0) as int,
        nid: (j['nid'] ?? 0) as int,
        remindMs: (j['rms'] ?? 0) as int,
        remindEvery: (j['rev'] ?? 0) as int,
        remindCount: (j['rct'] ?? 1) as int,
        voice: (j['voice'] ?? '') as String,
        day: (j['day'] ?? '') as String,
      );
}

/// Hatırlatıcı: kind = once (tek sefer) | interval (aralıklı) | daily (her gün)
class Reminder {
  final String id;
  int nid; // bildirim numarası
  String text;
  bool enabled;
  String kind;
  int startMs; // once / interval için başlangıç
  int every; // interval: dakika
  int count; // interval: kaç kez
  int hour; // daily
  int minute; // daily
  Reminder({
    required this.id,
    required this.nid,
    required this.text,
    this.enabled = true,
    this.kind = 'once',
    this.startMs = 0,
    this.every = 15,
    this.count = 1,
    this.hour = 9,
    this.minute = 0,
  });

  Map<String, dynamic> toJson() => {
        'id': id,
        'nid': nid,
        'text': text,
        'on': enabled,
        'kind': kind,
        'start': startMs,
        'every': every,
        'count': count,
        'h': hour,
        'm': minute,
      };

  factory Reminder.fromJson(Map<String, dynamic> j) => Reminder(
        id: j['id'] as String,
        nid: (j['nid'] ?? 0) as int,
        text: (j['text'] ?? '') as String,
        enabled: (j['on'] ?? true) as bool,
        kind: (j['kind'] ?? 'once') as String,
        startMs: (j['start'] ?? 0) as int,
        every: (j['every'] ?? 15) as int,
        count: (j['count'] ?? 1) as int,
        hour: (j['h'] ?? 9) as int,
        minute: (j['m'] ?? 0) as int,
      );
}

/// Ana ekrandaki serbest satır: başlık + serbest metin (o güne ait)
class FreeRow {
  final String id;
  String date; // yyyy-MM-dd
  String title;
  String text;
  int nid; // bildirim numarası (0 = yok)
  int remindMs; // hatırlatma zamanı (0 = yok)
  FreeRow(
      {required this.id,
      required this.date,
      required this.title,
      this.text = '',
      this.nid = 0,
      this.remindMs = 0});

  Map<String, dynamic> toJson() => {
        'id': id,
        'date': date,
        'title': title,
        'text': text,
        'nid': nid,
        'rms': remindMs,
      };

  factory FreeRow.fromJson(Map<String, dynamic> j) => FreeRow(
        id: j['id'] as String,
        date: j['date'] as String,
        title: (j['title'] ?? '') as String,
        text: (j['text'] ?? '') as String,
        nid: (j['nid'] ?? 0) as int,
        remindMs: (j['rms'] ?? 0) as int,
      );
}

/// Bir hatırlatıcının planlanan bildirim zamanları (şimdiden sonrakiler)
List<DateTime> reminderTimes(Reminder r, DateTime now) {
  final out = <DateTime>[];
  if (r.kind == 'daily') {
    for (var d = 0; d < 14; d++) {
      final t = DateTime(now.year, now.month, now.day + d, r.hour, r.minute);
      if (t.isAfter(now)) out.add(t);
    }
  } else if (r.kind == 'interval') {
    final start = DateTime.fromMillisecondsSinceEpoch(r.startMs);
    for (var k = 0; k < r.count; k++) {
      final t = start.add(Duration(minutes: r.every * k));
      if (t.isAfter(now)) out.add(t);
    }
  } else {
    final t = DateTime.fromMillisecondsSinceEpoch(r.startMs);
    if (t.isAfter(now)) out.add(t);
  }
  return out;
}

/// Tek seferlik / aralıklı hatırlatıcı bitti mi? (her gün olanlar bitmez)
bool reminderFinished(Reminder r) {
  if (r.kind == 'daily') return false;
  return reminderTimes(r, DateTime.now()).isEmpty;
}

/// Yapılacak maddesinin planlanan bildirim zamanları
List<DateTime> todoRemindTimes(Todo t, DateTime now) {
  final out = <DateTime>[];
  if (t.remindMs <= 0) return out;
  final start = DateTime.fromMillisecondsSinceEpoch(t.remindMs);
  final n = t.remindEvery > 0 ? t.remindCount : 1;
  for (var k = 0; k < n; k++) {
    final x = start.add(Duration(minutes: t.remindEvery * k));
    if (x.isAfter(now)) out.add(x);
  }
  return out;
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
  List<Reminder> reminders = [];
  List<FreeRow> freeRows = [];
  int nextNid = 1000; // bildirim numarası sayacı
  Map<String, String> notes = {}; // tarih -> günün notu
  Map<String, List<String>> voices = {}; // tarih -> ses kaydı dosya adları
  ThemeMode themeMode = ThemeMode.system;
  int accent = 0;
  String lang = 'tr'; // 'tr' veya 'en'
  bool seenIntro = false;
  int lastBuild = 0; // en son açılan sürüm numarası (güncelleme tespiti için)
  bool _updateNotice = false; // bu açılışta "güncellendi" penceresi gösterilsin mi

  // Ana ekrandaki satır sırası (alt kategori kimlikleri; kullanıcı sürükleyerek değiştirir)
  List<String> homeOrder = [];

  // Uygulama kilidi (şifre): sadece tuzlu özet saklanır
  String? lockSalt;
  String? lockHash;
  String lockHint = '';
  bool locked = false; // çalışma anında: şu an kilitli mi

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

  // ----- Açılış ekranındaki söz: art arda aynı söz gelmesin -----
  int _splashLast = -1;

  Future<void> loadSplashLast() async {
    try {
      final d = await _baseDir().timeout(const Duration(seconds: 2));
      final f = File('${d.path}/splash_last.txt');
      if (await f.exists()) {
        _splashLast = int.tryParse((await f.readAsString()).trim()) ?? -1;
      }
    } catch (_) {}
  }

  /// 0..n-1 arasında rastgele bir sıra seçer (öncekinden farklı) ve kaydeder
  int pickSplashQuote(int n) {
    if (n <= 0) return 0;
    var i = Random().nextInt(n);
    if (n > 1 && i == _splashLast) i = (i + 1) % n;
    _splashLast = i;
    _baseDir().then((d) {
      try {
        File('${d.path}/splash_last.txt').writeAsStringSync('$i');
      } catch (_) {}
    }).catchError((_) {});
    return i;
  }

  // ----- Hava durumu ayarları -----
  bool wxOn = false;
  String wxCity = '';
  double? wxLat;
  double? wxLon;
  String wxProvider = 'om'; // om, ecmwf, icon, gfs, met, mgm, owm
  String wxOwmKey = ''; // OpenWeatherMap anahtarı (kullanıcı kendi yazar)
  bool wxGps = false; // true: telefonun konumu kullanılır

  void setWxProvider(String p) {
    wxProvider = p;
    _commit();
  }

  void setWxOwmKey(String k) {
    wxOwmKey = k.trim();
    _commit();
  }

  void setWxGps(bool v) {
    wxGps = v;
    if (v) wxOn = true;
    _commit();
  }

  /// Telefonun konumu bulununca kaydedilir (ekranı yenilemez)
  void setWxPos(double lat, double lon) {
    wxLat = lat;
    wxLon = lon;
    _persist();
  }

  void setWxOn(bool v) {
    wxOn = v;
    _commit();
  }

  void setWeatherCity(String name, double lat, double lon) {
    wxCity = name;
    wxLat = lat;
    wxLon = lon;
    wxOn = true;
    wxGps = false;
    _commit();
  }

  // ----- Müzik, radyo ve podcast -----

  List<Playlist> playlists = [];
  List<RadioCat> radCats = [];
  bool _radLoaded = false;
  List<PodCat> podCats = [];
  List<NewsCat> newsCats = [];

  // ----- Online müzik (Jamendo / Audius) -----
  String jamendoKey = '';
  List<OnTrack> onFavs = [];

  void setJamendoKey(String k) {
    jamendoKey = k.trim();
    _commit();
  }

  bool isOnFav(String id) => onFavs.any((t) => t.id == id);

  void toggleOnFav(OnTrack t) {
    final i = onFavs.indexWhere((x) => x.id == t.id);
    if (i >= 0) {
      onFavs.removeAt(i);
    } else {
      onFavs.insert(0, t);
    }
    _commit();
  }

  // ----- Meditasyon -----
  List<MedSession> medLog = [];
  bool medSound = true; // nefes sesleri ve gong
  bool medVibe = false; // nefeste titreşim

  MedSession addMed(double minutes, {String note = ''}) {
    final m = MedSession(
        newId(), DateTime.now().millisecondsSinceEpoch, minutes, note);
    medLog.insert(0, m);
    _commit();
    return m;
  }

  void setMedNote(String id, String note) {
    for (final m in medLog) {
      if (m.id == id) m.note = note.trim();
    }
    _commit();
  }

  void deleteMed(String id) {
    medLog.removeWhere((m) => m.id == id);
    _commit();
  }

  void restoreMed(MedSession m) {
    if (medLog.every((x) => x.id != m.id)) {
      medLog.add(m);
      medLog.sort((a, b) => b.ms.compareTo(a.ms));
      _commit();
    }
  }

  void setMedSound(bool v) {
    medSound = v;
    _commit();
  }

  // Pomodoro ayarları (dakika) ve süre bitiş uyarıları
  int pomoWork = 25;
  int pomoShort = 5;
  int pomoLong = 15;
  bool pomoSound = true; // süre bitince gong
  bool pomoVibe = true; // süre bitince titreşim

  void setPomo({int? work, int? short, int? long}) {
    if (work != null) pomoWork = work.clamp(1, 240).toInt();
    if (short != null) pomoShort = short.clamp(1, 120).toInt();
    if (long != null) pomoLong = long.clamp(1, 240).toInt();
    _commit();
  }

  void setPomoSound(bool v) {
    pomoSound = v;
    _commit();
  }

  void setPomoVibe(bool v) {
    pomoVibe = v;
    _commit();
  }

  void setMedVibe(bool v) {
    medVibe = v;
    _commit();
  }

  // ----- Araçlar -----
  Map<String, String> toolLinks = {}; // araç -> bağlı rutin (alt kategori) kimliği
  int zikirCount = 0;
  int zikirTarget = 33;
  int sleepStart = 0; // "Yattım" zamanı (ms), 0 = kapalı
  int glassMl = 250; // su sayacında bir bardak (ml)

  void setToolLink(String tool, String? subId) {
    if (subId == null || subId.isEmpty) {
      toolLinks.remove(tool);
    } else {
      toolLinks[tool] = subId;
    }
    _persist();
  }

  void setZikir(int count, {int? target}) {
    zikirCount = count;
    if (target != null) zikirTarget = target;
    _persist();
  }

  void setSleepStart(int ms) {
    sleepStart = ms;
    _persist();
  }

  void setGlassMl(int ml) {
    glassMl = ml;
    _commit();
  }

  NewsCat? newsCatById(String id) {
    for (final c in newsCats) {
      if (c.id == id) return c;
    }
    return null;
  }

  void addNewsCat(String name) {
    newsCats.add(NewsCat(id: newId(), name: name));
    _commit();
  }

  void renameNewsCat(String id, String name) {
    newsCatById(id)?.name = name;
    _commit();
  }

  bool removeNewsCat(String id) {
    if (newsCats.length < 2) return false;
    final c = newsCatById(id);
    if (c == null) return false;
    newsCats.removeWhere((x) => x.id == id);
    newsCats.first.srcs.addAll(c.srcs);
    _commit();
    return true;
  }

  void toggleNewsCat(String id) {
    final c = newsCatById(id);
    if (c == null) return;
    c.open = !c.open;
    _commit();
  }

  void toggleNewsSrc(String id) {
    for (final c in newsCats) {
      for (final s in c.srcs) {
        if (s.id == id) s.open = !s.open;
      }
    }
    _commit();
  }

  /// Kaynak ekler (id null) ya da düzenler / başka kategoriye taşır
  void saveNewsSrc(String catId, String? id, String name, String url) {
    if (id == null) {
      newsCatById(catId)?.srcs.add(NewsSrc(id: newId(), name: name, url: url));
    } else {
      NewsSrc? found;
      for (final c in newsCats) {
        final i = c.srcs.indexWhere((s) => s.id == id);
        if (i >= 0) {
          found = c.srcs[i];
          if (c.id != catId) c.srcs.removeAt(i);
          break;
        }
      }
      if (found != null) {
        found.name = name;
        found.url = url;
        final t = newsCatById(catId);
        if (t != null && !t.srcs.any((s) => s.id == id)) t.srcs.add(found);
      }
    }
    _commit();
  }

  void removeNewsSrc(String id) {
    for (final c in newsCats) {
      c.srcs.removeWhere((s) => s.id == id);
    }
    _commit();
  }

  void moveNewsSrc(String catId, int from, int to) {
    final c = newsCatById(catId);
    if (c == null || from < 0 || from >= c.srcs.length) return;
    final s = c.srcs.removeAt(from);
    c.srcs.insert(to.clamp(0, c.srcs.length).toInt(), s);
    _commit();
  }
  List<Podcast> get podcasts => [for (final c in podCats) ...c.pods];
  Map<String, int> epPos = {}; // podcast bölümü -> kaldığı yer (ms)
  Set<String> epDone = {}; // bitirilen bölümler
  int repeatMode = 0; // 0 kapalı, 1 sürekli tekrar (liste), 2 tek parça tekrar
  bool shuffleOn = false; // karışık çalma

  /// Radyo kategorileri hiç yoksa (ilk kurulum) hazır listeyi kurar
  void _mediaDefaults() {
    if (newsCats.isEmpty) {
      newsCats = [
        NewsCat(id: newId(), name: tx('Gündem'), srcs: [
          NewsSrc(
              id: newId(),
              name: 'TRT Haber',
              url: 'https://www.trthaber.com/sondakika_articles.rss'),
          NewsSrc(
              id: newId(),
              name: 'BBC Türkçe',
              url: 'https://feeds.bbci.co.uk/turkce/rss.xml'),
          NewsSrc(
              id: newId(),
              name: 'DW Türkçe',
              url: 'https://rss.dw.com/rdf/rss-tur-all'),
          NewsSrc(
              id: newId(),
              name: 'Anadolu Ajansı',
              url: 'https://www.aa.com.tr/tr/rss/default?cat=guncel'),
        ]),
      ];
    }
    if (podCats.isEmpty) {
      podCats = [
        PodCat(id: newId(), name: tx('Genel')),
        PodCat(id: newId(), name: tx('Haber')),
      ];
    }
    if (_radLoaded && radCats.isNotEmpty) return;
    radCats = [
      RadioCat(id: newId(), name: tx('Genel'), stations: [
        Station(
            id: newId(),
            name: 'SomaFM Groove Salad',
            url: 'https://ice1.somafm.com/groovesalad-128-mp3'),
        Station(
            id: newId(),
            name: 'BBC World Service',
            url: 'https://stream.live.vc.bbcmedia.co.uk/bbc_world_service'),
      ]),
      RadioCat(id: newId(), name: tx('Haber')),
    ];
  }

  /// Şarkı dosyalarının tutulduğu klasör (uygulamanın kendi alanı)
  Future<Directory> musicDir() async {
    final base = await _baseDir();
    final d = Directory('${base.path}/music');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

  void setRepeat(int m) {
    repeatMode = m.clamp(0, 2).toInt();
    _commit();
  }

  void setShuffle(bool v) {
    shuffleOn = v;
    _commit();
  }

  // --- oynatma listeleri ---
  Playlist? playlistById(String id) {
    for (final p in playlists) {
      if (p.id == id) return p;
    }
    return null;
  }

  void addPlaylist(String name) {
    playlists.add(Playlist(id: newId(), name: name));
    _commit();
  }

  void renamePlaylist(String id, String name) {
    playlistById(id)?.name = name;
    _commit();
  }

  void removePlaylist(String id) {
    final p = playlistById(id);
    if (p == null) return;
    for (final s in p.songs) {
      try {
        File(s.path).deleteSync();
      } catch (_) {}
    }
    playlists.removeWhere((x) => x.id == id);
    _commit();
  }

  void togglePlaylist(String id) {
    final p = playlistById(id);
    if (p == null) return;
    p.open = !p.open;
    _commit();
  }

  void addSong(String plId, String title, String path) {
    playlistById(plId)?.songs.add(Song(id: newId(), title: title, path: path));
    _commit();
  }

  void removeSong(String plId, String songId) {
    final p = playlistById(plId);
    if (p == null) return;
    final i = p.songs.indexWhere((s) => s.id == songId);
    if (i < 0) return;
    final s = p.songs.removeAt(i);
    // Dosya hemen silinmez: "Geri al" için 8 saniye beklenir
    _songTimers[s.id]?.cancel();
    _songTimers[s.id] = Timer(const Duration(seconds: 8), () {
      _songTimers.remove(s.id);
      try {
        File(s.path).deleteSync();
      } catch (_) {}
    });
    _commit();
  }

  final Map<String, Timer> _songTimers = {};

  /// Silinen şarkıyı yerine geri koyar (dosya henüz silinmediyse)
  void restoreSong(String plId, Song s, int index) {
    final p = playlistById(plId);
    if (p == null) return;
    _songTimers.remove(s.id)?.cancel();
    if (p.songs.any((x) => x.id == s.id)) return;
    p.songs.insert(index.clamp(0, p.songs.length).toInt(), s);
    _commit();
  }

  void movePlaylist(int from, int to) {
    if (from < 0 || from >= playlists.length) return;
    final x = playlists.removeAt(from);
    playlists.insert(to.clamp(0, playlists.length).toInt(), x);
    _commit();
  }

  void moveRadCat(int from, int to) {
    if (from < 0 || from >= radCats.length) return;
    final x = radCats.removeAt(from);
    radCats.insert(to.clamp(0, radCats.length).toInt(), x);
    _commit();
  }

  void movePodCat(int from, int to) {
    if (from < 0 || from >= podCats.length) return;
    final x = podCats.removeAt(from);
    podCats.insert(to.clamp(0, podCats.length).toInt(), x);
    _commit();
  }

  void moveNewsCat(int from, int to) {
    if (from < 0 || from >= newsCats.length) return;
    final x = newsCats.removeAt(from);
    newsCats.insert(to.clamp(0, newsCats.length).toInt(), x);
    _commit();
  }

  void restoreStation(String catId, Station s, int index) {
    final c = radCatById(catId) ?? (radCats.isEmpty ? null : radCats.first);
    if (c == null || c.stations.any((x) => x.id == s.id)) return;
    c.stations.insert(index.clamp(0, c.stations.length).toInt(), s);
    _commit();
  }

  void restorePodcast(String catId, Podcast p, int index) {
    final c = podCatById(catId) ?? (podCats.isEmpty ? null : podCats.first);
    if (c == null || podcasts.any((x) => x.id == p.id)) return;
    c.pods.insert(index.clamp(0, c.pods.length).toInt(), p);
    _commit();
  }

  void restoreNewsSrc(String catId, NewsSrc s, int index) {
    final c = newsCatById(catId) ?? (newsCats.isEmpty ? null : newsCats.first);
    if (c == null || c.srcs.any((x) => x.id == s.id)) return;
    c.srcs.insert(index.clamp(0, c.srcs.length).toInt(), s);
    _commit();
  }

  void renamePodcast(String id, String title) {
    for (final p in podcasts) {
      if (p.id == id) p.title = title;
    }
    _commit();
  }


  void renameSong(String plId, String songId, String title) {
    final p = playlistById(plId);
    if (p == null) return;
    for (final s in p.songs) {
      if (s.id == songId) s.title = title;
    }
    _commit();
  }

  void moveSong(String plId, int from, int to) {
    final p = playlistById(plId);
    if (p == null || from < 0 || from >= p.songs.length) return;
    final s = p.songs.removeAt(from);
    p.songs.insert(to.clamp(0, p.songs.length).toInt(), s);
    _commit();
  }

  // --- radyo kategorileri ve istasyonlar ---
  RadioCat? radCatById(String id) {
    for (final c in radCats) {
      if (c.id == id) return c;
    }
    return null;
  }

  void addRadCat(String name) {
    radCats.add(RadioCat(id: newId(), name: name));
    _commit();
  }

  void renameRadCat(String id, String name) {
    radCatById(id)?.name = name;
    _commit();
  }

  /// Kategoriyi siler; içindeki radyolar ilk kalan kategoriye geçer
  bool removeRadCat(String id) {
    if (radCats.length < 2) return false;
    final c = radCatById(id);
    if (c == null) return false;
    radCats.removeWhere((x) => x.id == id);
    radCats.first.stations.addAll(c.stations);
    _commit();
    return true;
  }

  void toggleRadCat(String id) {
    final c = radCatById(id);
    if (c == null) return;
    c.open = !c.open;
    _commit();
  }

  /// id == null: yeni radyo; değilse düzenle (kategori değiştiyse taşınır)
  void saveStation(String catId, String? id, String name, String url) {
    if (id == null) {
      radCatById(catId)?.stations
          .add(Station(id: newId(), name: name, url: url));
    } else {
      Station? found;
      for (final c in radCats) {
        final i = c.stations.indexWhere((s) => s.id == id);
        if (i >= 0) {
          found = c.stations[i];
          if (c.id != catId) c.stations.removeAt(i);
          break;
        }
      }
      if (found != null) {
        found.name = name;
        found.url = url;
        final target = radCatById(catId);
        if (target != null && !target.stations.any((s) => s.id == id)) {
          target.stations.add(found);
        }
      }
    }
    _commit();
  }

  void removeStation(String catId, String id) {
    radCatById(catId)?.stations.removeWhere((s) => s.id == id);
    _commit();
  }

  void moveStation(String catId, int from, int to) {
    final c = radCatById(catId);
    if (c == null || from < 0 || from >= c.stations.length) return;
    final s = c.stations.removeAt(from);
    c.stations.insert(to.clamp(0, c.stations.length).toInt(), s);
    _commit();
  }

  bool hasStationUrl(String url) {
    for (final c in radCats) {
      for (final s in c.stations) {
        if (s.url == url) return true;
      }
    }
    return false;
  }

  // --- podcast ---
  bool isFollowing(String feed) => podcasts.any((p) => p.feed == feed);

  PodCat? podCatById(String id) {
    for (final c in podCats) {
      if (c.id == id) return c;
    }
    return null;
  }

  void addPodCat(String name) {
    podCats.add(PodCat(id: newId(), name: name));
    _commit();
  }

  void renamePodCat(String id, String name) {
    podCatById(id)?.name = name;
    _commit();
  }

  /// Kategoriyi siler; içindeki podcast'ler ilk kalan kategoriye geçer
  bool removePodCat(String id) {
    if (podCats.length < 2) return false;
    final c = podCatById(id);
    if (c == null) return false;
    podCats.removeWhere((x) => x.id == id);
    podCats.first.pods.addAll(c.pods);
    _commit();
    return true;
  }

  void togglePodCat(String id) {
    final c = podCatById(id);
    if (c == null) return;
    c.open = !c.open;
    _commit();
  }

  void addPodcast(
      String catId, String title, String author, String feed, String art) {
    if (isFollowing(feed)) return;
    final c = podCatById(catId) ?? (podCats.isEmpty ? null : podCats.first);
    if (c == null) return;
    c.pods.add(Podcast(
        id: newId(), title: title, author: author, feed: feed, art: art));
    _commit();
  }

  /// Takipten çıkarır ama dinleme konumlarını silmez ("Geri al" için)
  void unfollowKeep(String id) {
    for (final c in podCats) {
      c.pods.removeWhere((p) => p.id == id);
    }
    _commit();
  }

  void removePodcast(String id) {
    for (final c in podCats) {
      c.pods.removeWhere((p) => p.id == id);
    }
    epPos.removeWhere((k, v) => k.startsWith('$id|'));
    epDone.removeWhere((k) => k.startsWith('$id|'));
    _commit();
  }

  /// Favori yıldızı (radyo / podcast)
  void toggleFavStation(String id) {
    for (final c in radCats) {
      for (final st in c.stations) {
        if (st.id == id) st.fav = !st.fav;
      }
    }
    _commit();
  }

  void toggleFavPodcast(String id) {
    for (final pd in podcasts) {
      if (pd.id == id) pd.fav = !pd.fav;
    }
    _commit();
  }

  // Podcast Index (ücretsiz anahtar + gizli anahtar)
  String pIdxKey = '';
  String pIdxSecret = '';

  void setPIdx(String key, String secret) {
    pIdxKey = key.trim();
    pIdxSecret = secret.trim();
    _commit();
  }

  void togglePodcast(String id) {
    for (final p in podcasts) {
      if (p.id == id) p.open = !p.open;
    }
    _commit();
  }

  void movePodcast(String catId, int from, int to) {
    final c = podCatById(catId);
    if (c == null || from < 0 || from >= c.pods.length) return;
    final p = c.pods.removeAt(from);
    c.pods.insert(to.clamp(0, c.pods.length).toInt(), p);
    _commit();
  }

  /// Podcast'i başka bir kategoriye taşır (sona eklenir)
  void setPodcastCat(String podId, String catId) {
    final target = podCatById(catId);
    if (target == null) return;
    Podcast? found;
    for (final c in podCats) {
      final i = c.pods.indexWhere((p) => p.id == podId);
      if (i >= 0) {
        if (c.id == catId) return;
        found = c.pods.removeAt(i);
        break;
      }
    }
    if (found != null) {
      target.pods.add(found);
      _commit();
    }
  }

  /// Dinleme konumu sık kaydedilir; ekranı yenilemeye gerek yok
  void setEpPos(String key, int ms) {
    if (ms <= 0) {
      epPos.remove(key);
    } else {
      epPos[key] = ms;
    }
    _persist();
  }

  void setEpDone(String key, bool done) {
    if (done) {
      epDone.add(key);
    } else {
      epDone.remove(key);
    }
    _commit();
  }

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
    // Eski sürümde yapılacaklar güne bağlı değildi: hepsi bugüne bağlanır
    final todayKey = dKey(DateTime.now());
    for (final t in todos) {
      if (t.day.isEmpty) t.day = todayKey;
    }
    // Bitmeyen geçmiş maddeler bugüne taşınır
    for (final t in todos) {
      if (!t.done && t.day.compareTo(todayKey) < 0) t.day = todayKey;
    }
    notes = ((j['notes'] as Map?) ?? {})
        .map((k, v) => MapEntry(k as String, v as String));
    voices = ((j['voices'] as Map?) ?? {}).map((k, v) => MapEntry(
        k as String, [for (final x in (v as List)) x as String]));
    reminders = ((j['reminders'] as List?) ?? [])
        .map((e) => Reminder.fromJson(e as Map<String, dynamic>))
        .toList();
    freeRows = ((j['free'] as List?) ?? [])
        .map((e) => FreeRow.fromJson(e as Map<String, dynamic>))
        .toList();
    nextNid = (j['nextNid'] as int?) ?? 1000;
    final s = (j['settings'] as Map?) ?? {};
    final l = s['lang'];
    if (l == 'tr' || l == 'en') {
      lang = l as String;
      appLang = lang;
    }
    themeMode = ThemeMode
        .values[((s['themeMode'] as int?) ?? 0).clamp(0, 2).toInt()];
    accent = ((s['accent'] as int?) ?? 0)
        .clamp(-1, accentColors.length - 1)
        .toInt();
    if (s['customAccent'] is int) customAccent = Color(s['customAccent'] as int);
    seenIntro = (s['seenIntro'] as bool?) ?? false;
    lastBuild = (s['lastBuild'] as int?) ?? 0;

    // Hava durumu ayarı: yedekte yoksa mevcut ayar korunur
    final wx = j['weather'];
    if (wx is Map) {
      wxOn = (wx['on'] as bool?) ?? false;
      wxCity = (wx['city'] as String?) ?? '';
      wxLat = (wx['lat'] as num?)?.toDouble();
      wxLon = (wx['lon'] as num?)?.toDouble();
      wxProvider = (wx['prov'] as String?) ?? 'om';
      wxOwmKey = (wx['owm'] as String?) ?? '';
      wxGps = (wx['gps'] as bool?) ?? false;
    }

    // Müzik / radyo / podcast: yedekte yoksa mevcut liste korunur
    if (j['lists'] is List) {
      playlists = (j['lists'] as List)
          .map((e) => Playlist.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (j['music'] is List) {
      // v16'daki tek liste -> "Listem"
      playlists = [
        Playlist(
          id: newId(),
          name: tx('Listem'),
          songs: (j['music'] as List)
              .map((e) => Song.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
      ];
    }
    if (j['radcats'] is List) {
      radCats = (j['radcats'] as List)
          .map((e) => RadioCat.fromJson(e as Map<String, dynamic>))
          .toList();
      _radLoaded = true;
    } else if (j['radios'] is List) {
      // v16'daki tek liste -> "Genel" kategorisi
      radCats = [
        RadioCat(
          id: newId(),
          name: tx('Genel'),
          stations: (j['radios'] as List)
              .map((e) => Station.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        RadioCat(id: newId(), name: tx('Haber')),
      ];
      _radLoaded = true;
    }
    if (j['podcats'] is List) {
      podCats = (j['podcats'] as List)
          .map((e) => PodCat.fromJson(e as Map<String, dynamic>))
          .toList();
    } else if (j['pods'] is List) {
      // v17-v18'deki tek liste -> "Genel" kategorisi
      podCats = [
        PodCat(
          id: newId(),
          name: tx('Genel'),
          pods: (j['pods'] as List)
              .map((e) => Podcast.fromJson(e as Map<String, dynamic>))
              .toList(),
        ),
        PodCat(id: newId(), name: tx('Haber')),
      ];
    }
    jamendoKey = (j['jamkey'] as String?) ?? '';
    if (j['medlog'] is List) {
      medLog = (j['medlog'] as List)
          .map((e) => MedSession.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    if (j['onfavs'] is List) {
      onFavs = (j['onfavs'] as List)
          .map((e) => OnTrack.fromJson(Map<String, dynamic>.from(e as Map)))
          .toList();
    }
    final tl = j['tools'];
    if (tl is Map) {
      toolLinks = ((tl['links'] as Map?) ?? {})
          .map((k, v) => MapEntry(k as String, v as String));
      zikirCount = (tl['zc'] as num?)?.toInt() ?? 0;
      zikirTarget = (tl['zt'] as num?)?.toInt() ?? 33;
      sleepStart = (tl['sleep'] as num?)?.toInt() ?? 0;
      glassMl = (tl['glass'] as num?)?.toInt() ?? 250;
      medSound = (tl['msnd'] as bool?) ?? true;
      medVibe = (tl['mvib'] as bool?) ?? false;
      pIdxKey = (tl['pik'] as String?) ?? '';
      pIdxSecret = (tl['pis'] as String?) ?? '';
      pomoWork = ((tl['pw'] as int?) ?? 25).clamp(1, 240).toInt();
      pomoShort = ((tl['ps'] as int?) ?? 5).clamp(1, 120).toInt();
      pomoLong = ((tl['pl'] as int?) ?? 15).clamp(1, 240).toInt();
      pomoSound = (tl['psnd'] as bool?) ?? true;
      pomoVibe = (tl['pvib'] as bool?) ?? true;
    }
    if (j['newscats'] is List) {
      newsCats = (j['newscats'] as List)
          .map((e) => NewsCat.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    if (j['eppos'] is Map) {
      epPos = (j['eppos'] as Map)
          .map((k, v) => MapEntry(k as String, (v as num).toInt()));
    }
    if (j['epdone'] is List) {
      epDone = (j['epdone'] as List).map((e) => e as String).toSet();
    }
    if (j['rep'] is int) {
      repeatMode = ((j['rep'] as int).clamp(0, 2)).toInt();
      shuffleOn = (j['shuf'] as bool?) ?? false;
    } else if (j['pmode'] is int) {
      // eski sürümden: 1 tekrar, 2 tek şarkı, 3 karışık
      final o = (j['pmode'] as int);
      repeatMode = o == 2 ? 2 : (o == 1 || o == 3 ? 1 : 0);
      shuffleOn = o == 3;
    }

    homeOrder = ((j['order'] as List?) ?? []).map((e) => e as String).toList();

    // Kilit bilgisi yedekte yoktur; yedek yüklenince mevcut kilit korunur
    final lk = j['lock'];
    if (lk is Map) {
      lockSalt = lk['salt'] as String?;
      lockHash = lk['hash'] as String?;
      lockHint = (lk['hint'] ?? '') as String;
    }

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
        reminders = [];
        freeRows = [];
        notes = {};
        voices = {};
        storageError = tx(
            'Kayıt dosyası okunamadı; eski dosya yedeklendi ve yeni liste açıldı. ({0})',
            [_short(e)]);
      }
    } else if (cats.isEmpty) {
      cats = _defaults();
    }

    _mediaDefaults();

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
    SubCat s(String key,
            {bool routine = false,
            double? goal,
            bool isMax = false,
            Set<int>? days}) =>
        SubCat(
          id: newId(),
          key: key,
          name: presetSubName(key, lang),
          unit: presetSubUnit(key, lang),
          routine: routine,
          goal: goal,
          isMax: isMax,
          days: days,
        );
    Category c(String key, List<SubCat> subs) => Category(
          id: newId(),
          key: key,
          name: presetCatName(key, lang),
          subs: subs,
        );
    return [
      c('sport', [
        s('walk', routine: true, goal: 5000),
        s('run'),
        s('bike'),
        s('swim'),
        s('weights', routine: true, goal: 30, days: {2, 4, 7}),
      ]),
      c('life', [
        s('pill', routine: true, goal: 1),
        s('water', routine: true, goal: 2),
        s('sleep', routine: true),
        s('calorie', routine: true, isMax: true),
      ]),
      c('faith', [
        s('fast', routine: true, goal: 1, days: {1, 4}),
        s('quran', routine: true, goal: 2),
        s('hadith', routine: true, goal: 3),
        s('listen', routine: true, goal: 3),
      ]),
      c('growth', [
        s('book', routine: true, goal: 5),
        s('meditate', routine: true, goal: 15),
        s('language', routine: true, goal: 15),
        s('hobby'),
      ]),
      c('edu', [
        s('science', routine: true),
        s('math', routine: true),
        s('turkish', routine: true),
        s('mock', routine: true, goal: 1, days: {7}),
      ]),
      c('fun', [
        s('series', routine: true, goal: 1, isMax: true),
        s('movie', routine: true, goal: 1, isMax: true, days: {7}),
        s('game', routine: true, goal: 30, isMax: true, days: {1, 4}),
      ]),
    ];
  }

  /// Kaydedilecek tüm veri (tek JSON dosyası)
  Map<String, dynamic> _snapshot() => {
        'v': 3,
        'cats': cats.map((c) => c.toJson()).toList(),
        'entries': entries.map((e) => e.toJson()).toList(),
        'todos': todos.map((t) => t.toJson()).toList(),
        'reminders': reminders.map((r) => r.toJson()).toList(),
        'free': freeRows.map((f) => f.toJson()).toList(),
        'nextNid': nextNid,
        'lists': playlists.map((p) => p.toJson()).toList(),
        'radcats': radCats.map((c) => c.toJson()).toList(),
        'podcats': podCats.map((c) => c.toJson()).toList(),
        'newscats': newsCats.map((c) => c.toJson()).toList(),
        'jamkey': jamendoKey,
        'medlog': medLog.map((m) => m.toJson()).toList(),
        'onfavs': onFavs.map((t) => t.toJson()).toList(),
        'tools': {
          'links': toolLinks,
          'zc': zikirCount,
          'zt': zikirTarget,
          'sleep': sleepStart,
          'glass': glassMl,
          'msnd': medSound,
          'mvib': medVibe,
          'pik': pIdxKey,
          'pis': pIdxSecret,
          'pw': pomoWork,
          'ps': pomoShort,
          'pl': pomoLong,
          'psnd': pomoSound,
          'pvib': pomoVibe,
        },
        'eppos': epPos,
        'epdone': epDone.toList(),
        'rep': repeatMode,
        'shuf': shuffleOn,
        'weather': {
          'on': wxOn,
          'city': wxCity,
          'lat': wxLat,
          'lon': wxLon,
          'prov': wxProvider,
          'owm': wxOwmKey,
          'gps': wxGps,
        },
        'notes': notes,
        'voices': voices,
        'order': homeOrder,
        'lock': lockHash == null
            ? null
            : {'salt': lockSalt, 'hash': lockHash, 'hint': lockHint},
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
          'customAccent': customAccent.value,
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

  /// Bugün listelenen rutinlerin hedef durumu. "En fazla" (üst sınır) türündeki
  /// hedefler sayılmaz: hiç veri girilmese de sınır aşılmış olmaz.
  GoalStat todayGoals() {
    final now = DateTime.now();
    final day = DateTime(now.year, now.month, now.day);
    final key = dKey(day);
    var met = 0;
    var total = 0;
    for (final c in cats) {
      for (final s in c.subs) {
        if (s.goal == null || !s.summable || s.isMax) continue;
        if (!s.scheduledOn(day)) continue;
        total++;
        final e = entryFor(s.id, key);
        if (e != null && goalMet(s, e.value)) met++;
      }
    }
    return GoalStat(met, total);
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

  void moveCategory(int from, int to) {
    if (from < 0 || from >= cats.length) return;
    final x = cats.removeAt(from);
    cats.insert(to.clamp(0, cats.length).toInt(), x);
    _commit();
  }

  void moveSub(String catId, int from, int to) {
    final c = catById(catId);
    if (c == null || from < 0 || from >= c.subs.length) return;
    final x = c.subs.removeAt(from);
    c.subs.insert(to.clamp(0, c.subs.length).toInt(), x);
    _commit();
  }

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
    if (!s.routine) s.rh = -1; // rutin kapanınca hatırlatması da kalkar
    _commit();
  }

  /// Rutini o güne özel gizler (diğer günlerde durur)
  void skipDay(String subId, String date) {
    subById(subId)?.skip.add(date);
    _commit();
  }

  void unskipDay(String subId, String date) {
    subById(subId)?.skip.remove(date);
    _commit();
  }

  /// Rutini bugünden itibaren tamamen kaldırır (geçmiş veriler durur)
  void setRoutineOff(String subId) {
    final s = subById(subId);
    if (s == null) return;
    s.routine = false;
    s.rh = -1;
    _commit();
  }

  void setRoutineOn(String subId) {
    subById(subId)?.routine = true;
    _commit();
  }

  /// Rutin günlerini ve günlük hatırlatma saatini kaydeder (rh = -1: hatırlatma yok)
  void setRoutineOptions(String subId,
      {required Set<int> days, required int rh, int rm = 0}) {
    final s = subById(subId);
    if (s == null) return;
    s.days = days.isEmpty ? {1, 2, 3, 4, 5, 6, 7} : Set<int>.from(days);
    s.rh = rh;
    s.rm = rm;
    if (rh >= 0 && s.nid == 0) s.nid = newNid();
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

  /// Verilen günün yapılacakları (kullanıcının sırasıyla)
  List<Todo> todosFor(String day) => [
        for (final t in todos)
          if (t.day == day) t
      ];

  void addTodo(String text, {String voice = '', String? day}) {
    final t = text.trim();
    if (t.isEmpty) return;
    todos.add(Todo(
        id: newId(),
        text: t,
        voice: voice,
        day: day ?? dKey(DateTime.now()),
        created: DateTime.now().millisecondsSinceEpoch));
    _commit();
  }

  /// Bitmeyen geçmiş maddeleri bugüne taşır (uygulama açılınca / gün değişince)
  void rollTodos() {
    final today = dKey(DateTime.now());
    var changed = false;
    for (final t in todos) {
      if (!t.done && t.day.compareTo(today) < 0) {
        t.day = today;
        changed = true;
      }
    }
    if (changed) _commit();
  }

  /// Maddeyi başka bir güne taşır; hatırlatma saati de aynı gün kadar kayar.
  /// Geri almak için eski gün ve hatırlatma saati verilir.
  void moveTodo(String id, String newDay, {int? remindMs}) {
    final t = todoById(id);
    if (t == null) return;
    if (remindMs != null) {
      t.remindMs = remindMs;
    } else if (t.remindMs > 0 && t.day.isNotEmpty) {
      final diff =
          parseKey(newDay).difference(parseKey(t.day)).inDays;
      final old = DateTime.fromMillisecondsSinceEpoch(t.remindMs);
      t.remindMs = DateTime(old.year, old.month, old.day + diff, old.hour,
              old.minute)
          .millisecondsSinceEpoch;
    }
    t.day = newDay;
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

  void restoreTodo(Todo t, {int? index}) {
    if (todos.every((x) => x.id != t.id)) {
      if (index != null && index >= 0 && index <= todos.length) {
        todos.insert(index, t);
      } else {
        todos.add(t);
      }
      _commit();
    }
  }

  int indexOfTodo(String id) => todos.indexWhere((t) => t.id == id);

  Todo? todoById(String id) {
    for (final t in todos) {
      if (t.id == id) return t;
    }
    return null;
  }

  void editTodo(String id, String text) {
    final t = todoById(id);
    final v = text.trim();
    if (t == null || v.isEmpty) return;
    t.text = v;
    _commit();
  }

  /// Sürükleyerek sıralama: verilen kimlik sırası listenin yeni sırası olur
  void setTodoOrder(List<String> ids) {
    final byId = {for (final t in todos) t.id: t};
    final out = <Todo>[for (final id in ids) if (byId[id] != null) byId[id]!];
    for (final t in todos) {
      if (!ids.contains(t.id)) out.add(t);
    }
    todos = out;
    _commit();
  }

  int newNid() => nextNid++;

  /// Maddeye hatırlatma koy (ms=0 → kaldır)
  void setTodoReminder(String id, {required int ms, int every = 0, int count = 1}) {
    final t = todoById(id);
    if (t == null) return;
    if (ms > 0 && t.nid == 0) t.nid = newNid();
    t.remindMs = ms;
    t.remindEvery = every;
    t.remindCount = count;
    _commit();
  }

  // ----- Hatırlatıcılar -----

  Reminder addReminder(Reminder r) {
    reminders.add(r);
    _commit();
    return r;
  }

  void updateReminder(Reminder r) {
    _commit();
  }

  void toggleReminder(String id) {
    for (final r in reminders) {
      if (r.id == id) {
        r.enabled = !r.enabled;
        break;
      }
    }
    _commit();
  }

  void deleteReminder(String id) {
    reminders.removeWhere((r) => r.id == id);
    _commit();
  }

  void restoreReminder(Reminder r, {int? index}) {
    if (reminders.every((x) => x.id != r.id)) {
      if (index != null && index >= 0 && index <= reminders.length) {
        reminders.insert(index, r);
      } else {
        reminders.add(r);
      }
      _commit();
    }
  }

  // ----- Serbest satırlar -----

  FreeRow addFree(String date, String title, String text, {int remindMs = 0}) {
    final f = FreeRow(
        id: newId(),
        date: date,
        title: title,
        text: text,
        remindMs: remindMs,
        nid: remindMs > 0 ? newNid() : 0);
    freeRows.add(f);
    _commit();
    return f;
  }

  /// Serbest satırı günceller (tarih ve hatırlatma da değişebilir)
  FreeRow? updateFree(String id, String title, String text,
      {String? date, int remindMs = 0}) {
    FreeRow? hit;
    for (final f in freeRows) {
      if (f.id == id) {
        f.title = title;
        f.text = text;
        if (date != null) f.date = date;
        f.remindMs = remindMs;
        if (remindMs > 0 && f.nid == 0) f.nid = newNid();
        hit = f;
        break;
      }
    }
    _commit();
    return hit;
  }

  void deleteFree(String id) {
    freeRows.removeWhere((f) => f.id == id);
    _commit();
  }

  void restoreFree(FreeRow f) {
    if (freeRows.every((x) => x.id != f.id)) {
      freeRows.add(f);
      _commit();
    }
  }

  void clearDoneTodos({String? day}) {
    todos.removeWhere((t) => t.done && (day == null || t.day == day));
    _commit();
  }

  // ----- Günün notu (günlük) -----

  String noteOf(String date) => notes[date] ?? '';

  List<String> voicesOf(String date) => voices[date] ?? const [];

  void addVoice(String date, String name) {
    (voices[date] ??= []).add(name);
    _commit();
  }

  void removeVoice(String date, String name) {
    voices[date]?.remove(name);
    if (voices[date]?.isEmpty ?? false) voices.remove(date);
    _commit();
    () async {
      try {
        final d = await voiceDir();
        final f = File('${d.path}/$name');
        if (await f.exists()) await f.delete();
      } catch (_) {}
    }();
  }

  /// Ses kayıtlarının tutulduğu klasör (uygulamanın kendi alanı)
  Future<Directory> voiceDir() async {
    final base = await _baseDir();
    final d = Directory('${base.path}/voice');
    if (!await d.exists()) await d.create(recursive: true);
    return d;
  }

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

  // ----- Uygulama kilidi -----

  bool get lockEnabled => lockHash != null;

  /// Kilidi devreye sokar (kilit ekranı açılır)
  void lock() {
    if (lockEnabled && !locked) {
      locked = true;
      notifyListeners();
    }
  }

  void unlock() {
    if (locked) {
      locked = false;
      notifyListeners();
    }
  }

  /// Yeni şifre belirler (eskisi varsa değiştirir)
  void setPassword(String pw, String hint) {
    lockSalt = _randomSalt();
    lockHash = hashPassword(pw, lockSalt!);
    lockHint = hint.trim();
    _commit();
  }

  bool checkPassword(String pw) {
    final s = lockSalt;
    final h = lockHash;
    if (s == null || h == null) return true;
    return hashPassword(pw, s) == h;
  }

  /// Kilidi tamamen kaldırır
  void removePassword() {
    lockSalt = null;
    lockHash = null;
    lockHint = '';
    locked = false;
    _commit();
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

  /// Renk skalasından özel vurgu rengi (accent = -1)
  void setCustomAccent(Color c) {
    customAccent = c;
    accent = -1;
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
      for (final f in freeRows) f.id,
    };
    final all = homeOrder.where(exists.contains).toList();
    for (final c in cats) {
      for (final s in c.subs) {
        if (!all.contains(s.id)) all.add(s.id);
      }
    }
    for (final f in freeRows) {
      if (!all.contains(f.id)) all.add(f.id);
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
  String exportBackup() {
    final m = _snapshot();
    m.remove('lock'); // şifre özeti yedek metnine girmez
    return jsonEncode(m);
  }

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
