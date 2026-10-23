// ---------------------------------------------------------------
// ÖZLÜ SÖZLER: Motivasyon, Ayet, Hadis (Türkçe ve English)
//  - Motivasyon sözleri bu uygulama için yazılmış özgün sözlerdir.
//  - Ayet ve hadisler kısa meâl / anlam özetleridir; kaynak numaraları
//    baskıya göre değişebilir. Önemli bir yerde kullanmadan önce kaynağından
//    doğrulaman önerilir (Ayarlar'da da bu uyarı yazar).
// ---------------------------------------------------------------

/// Ekranda gösterilecek tek bir söz
class QuoteItem {
  final String text;
  final String ref; // kaynak (boş olabilir)
  const QuoteItem(this.text, this.ref);
}

class _Q {
  final String tr;
  final String en;
  final String refTr;
  final String refEn;
  const _Q(this.tr, this.en, [this.refTr = '', this.refEn = '']);
}

const _motivation = <_Q>[
  _Q('Küçük adımlar, her gün atıldığında büyük yolları bitirir.',
      'Small steps, taken every day, finish long roads.'),
  _Q('Bugün yaptığın küçük iş, yarının büyük farkıdır.',
      'The small thing you do today is tomorrow’s big difference.'),
  _Q('Mükemmel olmak şart değil; başlamak ve sürdürmek yeter.',
      'You do not need to be perfect; starting and continuing is enough.'),
  _Q('Zor olan başlamaktır; gerisi alışkanlığa dönüşür.',
      'Starting is the hard part; the rest becomes habit.'),
  _Q('Düştüğün yerde kalma; bir adım at, yeniden yoldasın.',
      'Do not stay where you fell; take one step and you are back on the road.'),
  _Q('Düzenli çalışmak, ara sıra gösterilen büyük çabadan güçlüdür.',
      'Steady effort beats an occasional big push.'),
  _Q('Her gün biraz daha iyi, bir yılda bambaşka biri.',
      'A little better every day is a different person in a year.'),
  _Q('Bugünün işini yarına bırakma; yarının huzuru bugünden başlar.',
      'Do not leave today’s work for tomorrow; tomorrow’s peace starts today.'),
  _Q('Hedefin büyükse adımlarını küçült, ama durma.',
      'If your goal is big, shrink your steps, but do not stop.'),
  _Q('Kendinle yaptığın sözü tutmak, güvenin ilk adımıdır.',
      'Keeping a promise to yourself is the first step of self-trust.'),
  _Q('Yorgunsan dinlen, vazgeçme.',
      'If you are tired, rest, but do not quit.'),
  _Q('İlerleme yavaş olabilir; önemli olan yönünün doğru olması.',
      'Progress may be slow; what matters is that you are heading the right way.'),
  _Q('Bugün ne kadar yaptığın değil, bırakmadığın önemli.',
      'What matters today is not how much you did, but that you did not give up.'),
  _Q('Disiplin, ne istediğini bilmekle başlar; her gün tekrarla devam eder.',
      'Discipline begins with knowing what you want and continues with daily repetition.'),
  _Q('Alışkanlıkların, seni bugünden yarına taşıyan sessiz köprüdür.',
      'Your habits are the quiet bridge that carries you from today to tomorrow.'),
  _Q('Sabırlı ol; ağaç da bir günde büyümez.',
      'Be patient; a tree does not grow in a day either.'),
  _Q('Bir gün diyerek bekleme; bugünden başla.',
      'Do not wait for “someday”; start today.'),
  _Q('Kendine nazik ol: dünden daha iyi olmak yeter.',
      'Be kind to yourself: being better than yesterday is enough.'),
  _Q('Plan yap, uygula, kutla: her küçük tamamlanan iş bir zaferdir.',
      'Plan, do, celebrate: every small finished task is a win.'),
  _Q('Zihnini sakin tut, işleri sırayla yap; kalabalık görevler tek tek biter.',
      'Keep your mind calm and do things one at a time; a crowd of tasks gets done one by one.'),
];

const _ayet = <_Q>[
  _Q('Elbette zorluğun yanında bir kolaylık vardır. Gerçekten, zorlukla beraber bir kolaylık daha vardır.',
      'Indeed, with hardship comes ease. Indeed, with hardship comes ease.',
      'İnşirah, 94/5-6', 'Ash-Sharh 94:5-6'),
  _Q('Allah, kimseye gücünün yeteceğinden fazlasını yüklemez.',
      'Allah does not burden a soul beyond its capacity.',
      'Bakara, 2/286', 'Al-Baqarah 2:286'),
  _Q('Ey iman edenler! Sabır ve namazla yardım dileyin. Şüphesiz Allah sabredenlerle beraberdir.',
      'O you who believe, seek help through patience and prayer. Indeed, Allah is with the patient.',
      'Bakara, 2/153', 'Al-Baqarah 2:153'),
  _Q('Biliniz ki kalpler ancak Allah’ı anmakla huzur bulur.',
      'Surely, in the remembrance of Allah hearts find rest.',
      'Ra‘d, 13/28', 'Ar-Ra‘d 13:28'),
  _Q('Gevşemeyin, üzülmeyin; eğer (gerçekten) inanıyorsanız üstün olan sizsiniz.',
      'Do not weaken and do not grieve, for you will be superior if you are true believers.',
      'Âl-i İmrân, 3/139', 'Al-Imran 3:139'),
  _Q('Kim Allah’a güvenirse O, ona yeter.',
      'Whoever relies upon Allah, He is sufficient for him.',
      'Talâk, 65/3', 'At-Talaq 65:3'),
  _Q('İnsan için ancak çalışmasının karşılığı vardır.',
      'Man will have only what he strives for.',
      'Necm, 53/39', 'An-Najm 53:39'),
  _Q('Bir toplum kendini değiştirmedikçe Allah onların durumunu değiştirmez.',
      'Indeed, Allah does not change the condition of a people until they change what is in themselves.',
      'Ra‘d, 13/11', 'Ar-Ra‘d 13:11'),
  _Q('Allah’ın rahmetinden ümidinizi kesmeyin.',
      'Do not despair of the mercy of Allah.',
      'Zümer, 39/53', 'Az-Zumar 39:53'),
  _Q('Beni anın ki ben de sizi anayım.',
      'Remember Me, and I will remember you.',
      'Bakara, 2/152', 'Al-Baqarah 2:152'),
  _Q('Karar verdiğin zaman Allah’a tevekkül et.',
      'And when you have decided, then rely upon Allah.',
      'Âl-i İmrân, 3/159', 'Al-Imran 3:159'),
  _Q('Erkek olsun kadın olsun, inanarak iyi iş yapana güzel bir hayat yaşatırız.',
      'Whoever does righteous deeds, male or female, while a believer, We will surely cause him to live a good life.',
      'Nahl, 16/97', 'An-Nahl 16:97'),
];

const _hadis = <_Q>[
  _Q('Ameller niyetlere göredir.',
      'Actions are judged by intentions.',
      'Buhârî, 1; Müslim, 1907', 'Bukhari 1; Muslim 1907'),
  _Q('Allah katında amellerin en sevimlisi, az da olsa devamlı olanıdır.',
      'The most beloved deeds to Allah are those done consistently, even if small.',
      'Buhârî, 6464; Müslim, 783', 'Bukhari 6464; Muslim 783'),
  _Q('Güçlü mümin, zayıf müminden daha hayırlıdır. Sana faydalı olana sarıl, Allah’tan yardım dile ve acze düşme.',
      'The strong believer is better than the weak believer. Hold on to what benefits you, seek Allah’s help and do not give up.',
      'Müslim, 2664', 'Muslim 2664'),
  _Q('Güzel söz sadakadır.',
      'A good word is charity.',
      'Buhârî, 2989; Müslim, 1009', 'Bukhari 2989; Muslim 1009'),
  _Q('İki nimet vardır ki insanların çoğu onlarda aldanmıştır: sağlık ve boş vakit.',
      'There are two blessings in which many people are deceived: health and free time.',
      'Buhârî, 6412', 'Bukhari 6412'),
  _Q('Hiçbiriniz, kendisi için istediğini kardeşi için de istemedikçe iman etmiş olmaz.',
      'None of you truly believes until he loves for his brother what he loves for himself.',
      'Buhârî, 13; Müslim, 45', 'Bukhari 13; Muslim 45'),
  _Q('Sabır, (musibetin) ilk anındadır.',
      'Patience is at the first stroke of a calamity.',
      'Buhârî, 1283; Müslim, 926', 'Bukhari 1283; Muslim 926'),
  _Q('Kim ilim öğrenmek için bir yola girerse Allah ona cennete giden yolu kolaylaştırır.',
      'Whoever takes a path to seek knowledge, Allah makes easy for him the path to Paradise.',
      'Müslim, 2699', 'Muslim 2699'),
  _Q('Temizlik imanın yarısıdır.',
      'Cleanliness is half of faith.',
      'Müslim, 223', 'Muslim 223'),
  _Q('Kim bir hayra vesile olursa, onu yapan gibi sevap kazanır.',
      'Whoever guides to something good has a reward like the one who does it.',
      'Müslim, 1893', 'Muslim 1893'),
  _Q('Kolaylaştırın, zorlaştırmayın; müjdeleyin, nefret ettirmeyin.',
      'Make things easy and do not make them difficult; give glad tidings and do not drive people away.',
      'Buhârî, 69', 'Bukhari 69'),
  _Q('Mümin bir delikten iki defa ısırılmaz.',
      'A believer is not bitten twice from the same hole.',
      'Buhârî, 6133; Müslim, 2998', 'Bukhari 6133; Muslim 2998'),
];

/// kind: 'motivation' | 'ayet' | 'hadis' — lang: 'tr' | 'en'
List<QuoteItem> builtInQuotes(String kind, String lang) {
  final list = kind == 'ayet'
      ? _ayet
      : (kind == 'hadis' ? _hadis : _motivation);
  final en = lang == 'en';
  return [
    for (final q in list)
      QuoteItem(en ? q.en : q.tr, en ? q.refEn : q.refTr),
  ];
}
