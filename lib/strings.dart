// ---------------------------------------------------------------
// ÇEVİRİLER: Türkçe metin anahtardır. Dil Türkçeyse metin aynen
// gösterilir; English ise aşağıdaki tablodan karşılığı alınır
// (tabloda olmayan metin Türkçe kalır).
// Parametreli metinlerde {0}, {1} yer tutucu olarak kullanılır.
// ---------------------------------------------------------------

/// Geçerli uygulama dili: 'tr' veya 'en' (AppStore günceller)
String appLang = 'tr';

String tx(String tr, [List<Object> args = const []]) {
  var s = appLang == 'en' ? (_en[tr] ?? tr) : tr;
  for (var i = 0; i < args.length; i++) {
    s = s.replaceAll('{$i}', args[i].toString());
  }
  return s;
}

const _wdTr = [
  'Pazartesi',
  'Salı',
  'Çarşamba',
  'Perşembe',
  'Cuma',
  'Cumartesi',
  'Pazar',
];
const _wdEn = [
  'Monday',
  'Tuesday',
  'Wednesday',
  'Thursday',
  'Friday',
  'Saturday',
  'Sunday',
];
const _monTr = [
  'Ocak',
  'Şubat',
  'Mart',
  'Nisan',
  'Mayıs',
  'Haziran',
  'Temmuz',
  'Ağustos',
  'Eylül',
  'Ekim',
  'Kasım',
  'Aralık',
];
const _monEn = [
  'January',
  'February',
  'March',
  'April',
  'May',
  'June',
  'July',
  'August',
  'September',
  'October',
  'November',
  'December',
];

/// Gün adı (1 = pazartesi ... 7 = pazar)
String wdName(int weekday) =>
    (appLang == 'en' ? _wdEn : _wdTr)[weekday - 1];

const _wdShortTr = ['Pzt', 'Sal', 'Çar', 'Per', 'Cum', 'Cmt', 'Paz'];
const _wdShortEn = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];

/// Kısa gün adı (1 = pazartesi ... 7 = pazar)
String wdShort(int weekday) =>
    (appLang == 'en' ? _wdShortEn : _wdShortTr)[weekday - 1];

/// Ay adı (1 = ocak ... 12 = aralık)
String monName(int month) => (appLang == 'en' ? _monEn : _monTr)[month - 1];

/// "19 Ekim Pazartesi" / "Monday, 19 October"
String dateLabel(DateTime d) => appLang == 'en'
    ? '${wdName(d.weekday)}, ${d.day} ${monName(d.month)}'
    : '${d.day} ${monName(d.month)} ${wdName(d.weekday)}';

const _en = <String, String>{
  'Yeni kategori':
      'New category',
  'Kategori adı':
      'Category name',
  '“{0}” altına yeni alt kategori':
      'New subcategory under “{0}”',
  '{0} verisi zaten var':
      '{0} already has an entry',
  'Bu gün için {0} {1} girilmiş. Aynı alt kategoriye günde tek veri girilebilir.':
      '{0} {1} is already entered for this day. Only one entry per day is allowed for a subcategory.',
  'Tamam':
      'OK',
  'Düzenle':
      'Edit',
  '{0} verisi':
      '{0} entry',
  'Ekle':
      'Add',
  'Kategori':
      'Category',
  'Yeni':
      'New',
  'Alt kategori':
      'Subcategory',
  'Rutin olsun':
      'Make it a routine',
  'Her gün ana ekranda listelenir':
      'Listed on the home screen every day',
  'Hedef değer (isteğe bağlı)':
      'Target value (optional)',
  'Günlük üst sınır (isteğe bağlı)':
      'Daily limit (optional)',
  'Günlük hedef (isteğe bağlı)':
      'Daily goal (optional)',
  'Günün verisi (isteğe bağlı)':
      'Value for this day (optional)',
  'Veri':
      'Value',
  'Kaydet':
      'Save',
  'Kayıt alanı açılamadı; veriler şimdilik sadece bu oturumda tutulacak. ({0})':
      'Storage could not be opened; data will only be kept for this session. ({0})',
  'Bugün':
      'Today',
  'Yapılacaklar':
      'To-do',
  'Kategoriler':
      'Categories',
  'Alt kategori yok':
      'No subcategories',
  'Henüz kategori yok. “Kategorileri düzenle” veya Ekle ile oluşturabilirsin.':
      'No categories yet. Create one with “Edit categories” or Add.',
  'Kategorileri düzenle':
      'Edit categories',
  'Ayarlar':
      'Settings',
  'Bugün • {0}':
      'Today • {0}',
  'Dün • {0}':
      'Yesterday • {0}',
  'Yarın • {0}':
      'Tomorrow • {0}',
  'Bu gün için silinecek veri yok':
      'No entry to delete for this day',
  '{0} verisi silindi':
      '{0} entry deleted',
  'Geri al':
      'Undo',
  'Diğer kayıtlar':
      'Other entries',
  'Geçerli bir sayı gir':
      'Enter a valid number',
  'hedef':
      'goal',
  'en fazla':
      'max',
  '{0} {1} kaldı':
      '{0} {1} left',
  '{0} {1} aşıldı':
      '{0} {1} over',
  'Hedef tamam':
      'Goal reached',
  'Rutinlerin, hedeflerin, günlerin':
      'Your routines, goals, days',
  'Günün tek ekranda':
      'Your day on one screen',
  'Su, adım, çözülen soru, satılan ürün... Takip etmek istediğin her şeyi günlük olarak kaydet. Geçmiş günlere de veri girebilir, günün notunu yazabilirsin.':
      'Water, steps, solved questions, products sold... Record everything you want to track, every day. You can also add entries for past days and write a note for the day.',
  'Rutin oluştur, hedef koy':
      'Create routines, set goals',
  'İstatistikler soldaki menüde':
      'Statistics are in the left menu',
  'Atla':
      'Skip',
  'Başla':
      'Start',
  'İleri':
      'Next',
  '“{0}” silinsin mi?':
      'Delete “{0}”?',
  'Bu kategorideki {0} alt kategori ve {1} kayıt kalıcı olarak silinecek.':
      '{0} subcategories and {1} entries in this category will be permanently deleted.',
  'Sil':
      'Delete',
  '“{0}” altına alt kategori':
      'Subcategory under “{0}”',
  'Alt kategoriyi düzenle':
      'Edit subcategory',
  'Birim değişiyor':
      'Unit is changing',
  'Eski kayıtlar çevrilmez. Örneğin “3 lt” olarak girilmiş bir kayıt, yeni birimle “3 {0}” olarak görünür. Devam edilsin mi?':
      'Old entries are not converted. For example, an entry saved as “3 L” will appear as “3 {0}” with the new unit. Continue?',
  'Devam':
      'Continue',
  '{0} kayıt da kalıcı olarak silinecek.':
      '{0} entries will also be permanently deleted.',
  'rutin':
      'routine',
  'hedef değer {0}':
      'target value {0}',
  'üst sınır {0}':
      'limit {0}',
  'hedef {0}':
      'goal {0}',
  'toplanmaz':
      'not summed',
  'Ek ayar yok':
      'No extra settings',
  'Hiç kategori yok. Aşağıdan yeni kategori ekleyebilirsin.':
      'No categories. You can add a new category below.',
  'Adını değiştir':
      'Rename',
  'Kategoriyi sil':
      'Delete category',
  'Alt kategori ekle':
      'Add subcategory',
  'Kategori ekle':
      'Add category',
  'Bitti':
      'Done',
  'Bu gün neler oldu? Önemli olayları buraya yazabilirsin.':
      'What happened on this day? Write the important events here.',
  'Yazdıkların otomatik kaydedilir':
      'Your text is saved automatically',
  'Dil':
      'Language',
  'Kendi eklediğin kategori ve alt kategori adları çevrilmez. Adını değiştirmediğin hazır kategoriler yeni dile çevrilir.':
      'Category and subcategory names you add yourself are not translated. Preset categories you have not renamed are translated to the new language.',
  'Tema':
      'Theme',
  'Görünüm':
      'Appearance',
  'Telefona uy':
      'Follow phone',
  'Açık':
      'Light',
  'Koyu':
      'Dark',
  'Vurgu rengi':
      'Accent color',
  'Tanıtım':
      'Intro',
  'Tanıtımı göster':
      'Show intro',
  'Dün':
      'Yesterday',
  'Bu hafta':
      'This week',
  'Geçen hafta':
      'Last week',
  'Bu ay':
      'This month',
  'Geçen ay':
      'Last month',
  'Bu alt kategori bulunamadı':
      'This subcategory was not found',
  'Toplam':
      'Total',
  'Veri girilen gün':
      'Days with data',
  'Ortalama':
      'Average',
  'Hedefe ulaşıldı':
      'Goal reached',
  'Üst sınır':
      'Limit',
  'Hedef':
      'Goal',
  'Durum':
      'Status',
  'Son değer':
      'Latest value',
  'Değişim':
      'Change',
  'En düşük':
      'Lowest',
  'En yüksek':
      'Highest',
  'Hedefe kalan':
      'To goal',
  'Gün':
      'Day',
  'Hafta':
      'Week',
  'Ay':
      'Month',
  'Gün gün':
      'Day by day',
  'Bu dönemde veri yok':
      'No data in this period',
  'Tamamlananlar silinsin mi?':
      'Delete completed items?',
  '{0} madde silinecek.':
      '{0} items will be deleted.',
  'Madde silindi':
      'Item deleted',
  'Tamamlananları temizle':
      'Clear completed',
  'Yeni madde ekle':
      'Add a new item',
  'Henüz madde yok. Yukarıdan ekleyebilirsin.':
      'No items yet. You can add one above.',
  'Vazgeç':
      'Cancel',
  'Evet':
      'Yes',
  'Ad boş olamaz':
      'Name cannot be empty',
  'Hedef geçerli bir sayı olmalı':
      'Goal must be a valid number',
  'Ad (ör. Su)':
      'Name (e.g. Water)',
  'Birim (ör. lt, adım, soru)':
      'Unit (e.g. L, steps, questions)',
  'Rutin (her gün listede)':
      'Routine (listed every day)',
  'Değerler toplanır':
      'Values are summed',
  'Su, adım gibi. Kilo gibi veriler için kapat.':
      'For water, steps and similar. Turn off for data like body weight.',
  'Günlük hedef':
      'Daily goal',
  'Hedef değer':
      'Target value',
  'Hedef üst sınırdır':
      'Goal is an upper limit',
  'Kalori gibi aşılmaması gereken veriler için.':
      'For data that should not be exceeded, like calories.',
  'Mavi':
      'Blue',
  'Yeşil':
      'Green',
  'Lavanta':
      'Lavender',
  'Pembe':
      'Pink',
  'Şeftali':
      'Peach',
  'Kapat':
      'Close',
  'Kayıt dosyası okunamadı; eski dosya yedeklendi ve yeni liste açıldı. ({0})':
      'The data file could not be read; the old file was backed up and a fresh list was opened. ({0})',
  'Günlük':
      'Diary',
  'Sırala':
      'Reorder',
  'Sıralamak için tutamacı sürükle':
      'Drag the handle to reorder',
  'Özlü sözler':
      'Quotes',
  'Ana ekranda özlü söz göster':
      'Show a quote on the home screen',
  'Türler':
      'Types',
  'Motivasyon':
      'Motivation',
  'Ayet':
      'Ayah',
  'Hadis':
      'Hadith',
  'Kendi sözlerim':
      'My own quotes',
  'Ne sıklıkla değişsin?':
      'How often should it change?',
  'Her açılışta':
      'Every time I open',
  'Saatte bir':
      'Every hour',
  '3 saatte bir':
      'Every 3 hours',
  '6 saatte bir':
      'Every 6 hours',
  '12 saatte bir':
      'Every 12 hours',
  'Günde bir':
      'Once a day',
  'Kendi sözlerimi yönet':
      'Manage my quotes',
  'Yeni söz yaz':
      'Write a new quote',
  'Henüz kendi sözün yok. Yukarıdan ekleyebilirsin.':
      'You have no quotes of your own yet. You can add one above.',
  'Ayet ve hadisler kısa meâl / anlam özetleridir; kaynak numaraları baskıya göre değişebilir. Önemli bir yerde kullanmadan önce kaynağından doğrulamanı öneririz.':
      'Ayahs and hadiths are short translations / summaries of the meaning; source numbers may differ between editions. We recommend checking the original source before using them anywhere important.',
  'Bu gün için kayıt yok.\nSağ alttaki DR düğmesine dokunarak rutin veya kayıt ekleyebilirsin.':
      'No entries for this day.\nTap the DR button at the bottom right to add a routine or an entry.',
  'Bu bir Daily Routine yedeği gibi görünmüyor.':
      'This does not look like a Daily Routine backup.',
  'Yedek okunamadı: {0}':
      'The backup could not be read: {0}',
  'Yedek panoya kopyalandı. Güvenli bir yere yapıştırıp sakla.':
      'The backup was copied to the clipboard. Paste it somewhere safe and keep it.',
  'Geri yüklensin mi?':
      'Restore the backup?',
  'Mevcut verilerin yedekteki verilerle değiştirilecek. Devam edilsin mi?':
      'Your current data will be replaced with the data in the backup. Continue?',
  'Geri yükle':
      'Restore',
  'Yedek geri yüklendi.':
      'The backup was restored.',
  'Yedek':
      'Backup',
  'Uygulamayı kaldırırsan tüm verilerin silinir. Kaldırmadan önce yedek al: yedek metin olarak panoya kopyalanır; bir not uygulamasına ya da kendine mesaj olarak yapıştırıp sakla. Yedek, günlük notların dahil tüm verini içerir; sakladığın yeri başkalarıyla paylaşma.':
      'If you uninstall the app, all your data is deleted. Back up before uninstalling: the backup is copied to the clipboard as text; paste it into a notes app or a message to yourself and keep it. The backup includes all your data, diary notes too; do not share the place where you keep it.',
  'Yedeği kopyala':
      'Copy backup',
  'Yedeği geri yükle':
      'Restore backup',
  'Yedek metni boş':
      'The backup text is empty',
  'Yedek metnini buraya yapıştır':
      'Paste the backup text here',
  'Panodan yapıştır':
      'Paste from clipboard',
  'Uygulama güncellendi':
      'App updated',
  'Yenilikler':
      'What’s new',
  'Sürüm {0}':
      'Version {0}',
  'Sürüm':
      'Version',
  'Hakkında':
      'About',
  'Verilerin korundu.':
      'Your data was kept.',
  'Bugünün yanında şimdiki hava görünür; simgeye basınca saatlik hava aşağı açılır.':
      'Today shows the current weather; tap the icon to open the hourly forecast downward.',
  'Diğer günlerde tarihin yanında o günün hava simgesi görünür.':
      'On other days a weather icon for that day appears next to the date.',
  'En yüksek {0} • en düşük {1} • yağış %{2}':
      'High {0} • low {1} • rain {2}%',
  'Hava durumu':
      'Weather',
  'Hava durumu alınamadı. Dokun, yeniden dene.':
      'Could not load weather. Tap to retry.',
  'Hava durumu internetten (Open-Meteo) alınır. Bugünde şimdiki durum, tarihin yanındaki simgeye basınca saatlik hava açılır.':
      'Weather comes from the internet (Open-Meteo). Today shows the current conditions; tap the icon next to the date to open the hourly forecast.',
  'Hava durumunu göster':
      'Show weather',
  'Yeni: Hava durumu. Ayarlar > Hava durumu bölümünden şehrini seç.':
      'New: Weather. Choose your city in Settings > Weather.',
  'Önce bir şehir seç':
      'Choose a city first',
  'Şehir adı (ör. Ankara)':
      'City name (e.g. Ankara)',
  'Şehir aranamadı. İnternetini kontrol et.':
      'Could not search cities. Check your internet.',
  'Şehir seç':
      'Choose city',
  'Açılış ekranı 2 saniyeye indi; özlü sözler 100 oldu ve art arda tekrar etmez.':
      'The splash screen is now 2 seconds; there are 100 quotes and they do not repeat back to back.',
  'Rutin satırında sola kısa kaydırma sadece o günü, uzun kaydırma tüm günleri kaldırır (düzeltildi).':
      'In a routine row, a short left swipe removes only that day and a long swipe removes all days (fixed).',
  'Yarın':
      'Tomorrow',
  'Üstte tarih: Dün, Bugün, Yarın; bu haftanın günleri gün adıyla; diğerleri 07.04.2026 biçiminde.':
      'Date at the top: Yesterday, Today, Tomorrow; days of this week by name; others as 07.04.2026.',
  '"{0}" eklendi.':
      '"{0}" added.',
  '"{0}" silinir; içindeki radyolar ilk kategoriye geçer.':
      '"{0}" will be deleted; its radios move to the first category.',
  '"{0}" takip ediliyor.':
      'Following "{0}".',
  '"{0}" ve içindeki {1} şarkı silinecek.':
      '"{0}" and its {1} songs will be deleted.',
  '10 sn geri':
      'Back 10 s',
  '30 sn ileri':
      'Forward 30 s',
  'Ara':
      'Search',
  'Aramak istediğin podcast adını veya konuyu yaz.':
      'Type the podcast name or topic you want to find.',
  'Bu kategoride radyo yok.':
      'No radios in this category.',
  'Bu listede şarkı yok.':
      'No songs in this list.',
  'Bu podcast için bölüm bulunamadı.':
      'No episodes found for this podcast.',
  'Bölümler alınamadı. İnternetini kontrol et.':
      'Could not load episodes. Check your internet.',
  'Daha fazla':
      'Load more',
  'Dinle':
      'Listen',
  'Dinlendi olarak işaretle':
      'Mark as played',
  'Dinlenmedi olarak işaretle':
      'Mark as unplayed',
  'Dünya':
      'World',
  'Eklendi.':
      'Added.',
  'Eklenecek kategori:':
      'Add to category:',
  'Elle ekle':
      'Add manually',
  'En az bir kategori kalmalı.':
      'At least one category must remain.',
  'Genel':
      'General',
  'Haber':
      'News',
  'Henüz oynatma listesi yok. "Oynatma listesi ekle" ile başla, sonra listeye telefonundan şarkı ekle.':
      'No playlists yet. Start with "Add playlist", then add songs from your phone.',
  'Henüz takip ettiğin podcast yok. "Podcast ara" ile bul ve takip et; haber özeti, sohbet, eğitim gibi sesli yayınlar burada listelenir.':
      'You are not following any podcast yet. Use "Search podcast" to find and follow; audio shows like news summaries, talks and lessons are listed here.',
  'Hepsi':
      'All',
  'Kaldığın yer: {0}':
      'Resume at: {0}',
  'Kategori silinsin mi?':
      'Delete this category?',
  'Listem':
      'My list',
  'Müzik: birden fazla oynatma listesi; listeler aşağı açılır, şarkılar ≡ ile sıralanır.':
      'Music: multiple playlists; lists open downward and songs are reordered with the handle.',
  'Oynatma listesi adı':
      'Playlist name',
  'Oynatma listesi ekle':
      'Add playlist',
  'Oynatma listesi silinsin mi?':
      'Delete this playlist?',
  'Podcast':
      'Podcast',
  'Podcast adı veya konu (ör. haber özeti)':
      'Podcast name or topic (e.g. news summary)',
  'Podcast ara':
      'Search podcast',
  'Podcast rehberine bağlanılamadı. İnternetini kontrol et.':
      'Could not reach the podcast directory. Check your internet.',
  'Radyo adı (ör. TRT, Kral, Power)':
      'Radio name (e.g. TRT, Kral, Power)',
  'Radyo rehberine bağlanılamadı. İnternetini kontrol et veya "Elle ekle"yi kullan.':
      'Could not reach the radio directory. Check your internet or use "Add manually".',
  'Radyo: kategoriler, ≡ ile sıralama; ada, ülkeye ve türe göre radyo bulup dinleyerek ekle.':
      'Radio: categories and drag sorting; find stations by name, country and genre and add them after listening.',
  'Sonuç bulunamadı.':
      'No results found.',
  'Sırayla':
      'In order',
  'Takip et':
      'Follow',
  'Takipten çık':
      'Unfollow',
  'Takipten çıkılsın mı?':
      'Unfollow this podcast?',
  'Tek şarkı tekrar':
      'Repeat one song',
  'Türkiye':
      'Turkey',
  'Yeni: Podcast sekmesi. Ara, takip et, kaldığın yerden dinle.':
      'New: Podcast tab. Search, follow and resume where you left off.',
  'Yenile':
      'Refresh',
  'Çalma çubuğundaki düğme çalma stilini değiştirir: sırayla, tekrar, tek şarkı tekrar, karışık.':
      'The button on the player bar changes the play style: in order, repeat, repeat one, shuffle.',
  'Çık':
      'Unfollow',
  'Ülke ara':
      'Search country',
  'Ülke listesi alınamadı. İnternetini kontrol et.':
      'Could not load countries. Check your internet.',
  'Konuşma':
      'Talk',
  'Pop':
      'Pop',
  'Rock':
      'Rock',
  'Klasik':
      'Classical',
  'Caz':
      'Jazz',
  'Halk müziği':
      'Folk',
  'Elektronik':
      'Electronic',
  'Hit':
      'Hits',
  'Nostalji':
      'Oldies',
  'Dini':
      'Religious',
  'İslami':
      'Islamic',
  'Spor':
      'Sports',
  '"{0}" listeden çıkarılır.':
      '"{0}" will be removed from the list.',
  'Adres http:// veya https:// ile başlamalı.':
      'The address must start with http:// or https://',
  'Adı değiştir':
      'Rename',
  'Dosya bulunamadı; şarkıyı silip yeniden ekle.':
      'File not found; delete the song and add it again.',
  'Duraklat':
      'Pause',
  'Durdur':
      'Stop',
  'Henüz şarkı yok. "Şarkı ekle" ile telefonundan seç; seçtiklerin bu listeye girer.':
      'No songs yet. Use "Add song" to pick from your phone; they will appear in this list.',
  'Karışık':
      'Shuffle',
  'Müzik':
      'Music',
  'Müzik ve Radyo':
      'Music and Radio',
  'Müzik: telefondan şarkı seçip listene ekle; uygulama kapalıyken de çalar.':
      'Music: pick songs from your phone and add them to your list; they keep playing when the app is closed.',
  'Radyo':
      'Radio',
  'Radyo adı':
      'Radio name',
  'Radyo adı yaz.':
      'Enter a radio name.',
  'Radyo ekle':
      'Add radio',
  'Radyo internetten çalar. Adresler zamanla değişebilir; çalmazsa menüden adresi güncelle.':
      'Radio plays over the internet. Addresses can change over time; if one does not play, update its address from the menu.',
  'Radyo silinsin mi?':
      'Delete this radio?',
  'Radyo: istediğin radyonun adını ve yayın adresini ekleyip internetten dinle.':
      'Radio: add the name and stream address of any station and listen online.',
  'Radyoyu düzenle':
      'Edit radio',
  'Sonraki':
      'Next',
  'Yayın adresi':
      'Stream address',
  'Yayın adresi geçersiz.':
      'The stream address is not valid.',
  'Yeni: sağ üstteki kulaklık simgesiyle Müzik ve Radyo sayfası açılır.':
      'New: the headphones icon at the top right opens the Music and Radio page.',
  '{0} şarkı eklendi.':
      '{0} songs added.',
  'Çal':
      'Play',
  'Çalınamadı: {0}':
      'Could not play: {0}',
  'Önceki':
      'Previous',
  'Şarkı adı':
      'Song name',
  'Şarkı ekle':
      'Add song',
  'Şarkı eklenemedi: {0}':
      'Could not add song: {0}',
  'Şarkı silinsin mi?':
      'Delete this song?',
  'Yeni kurulumda hazır liste güncellendi: Spor, Yaşam, Din, Kişisel gelişim, Eğitim, Eğlence.':
      'The starter list for new installs was updated: Sports, Life, Faith, Personal growth, Education, Entertainment.',
  'Boş yere sağa veya sola kaydırarak günler arasında geçebilirsin.':
      'Swipe left or right on an empty spot to move between days.',
  'Soldaki menüden kategorilerin istatistiklerine ulaşabilirsin.':
      'Use the left menu to see statistics for your categories.',
  'Soldaki menüde Günlük’e dokunarak notlarını takvimden görebilirsin.':
      'Tap Diary in the left menu to see your notes on a calendar.',
  'Rutin oluştururken hangi günlerde görüneceğini seçebilirsin.':
      'When you create a routine you can choose the days it appears on.',
  'Uygulamayı kaldırmadan önce Ayarlar’dan yedek almayı unutma.':
      'Do not forget to make a backup in Settings before uninstalling the app.',
  'İpucu':
      'Tip',
  'Çıkış':
      'Exit',
  'Programdan çıkmak istediğinize emin misiniz?':
      'Are you sure you want to exit?',
  'Hayır':
      'No',
  'Hangi günler?':
      'Which days?',
  'Bu gün için not yok':
      'No note for this day',
  'Not yaz':
      'Write a note',
  'Ayarlar’dan tema, dil, özlü sözler ve uygulama kilidini ayarlayabilirsin.':
      'You can set the theme, language, quotes and app lock in Settings.',
  'Uygulama kilidi: Ayarlar’dan kendi şifreni belirleyebilirsin; uygulama açılırken ve arka plandan dönünce sorulur.':
      'App lock: you can set your own password in Settings; it is asked when the app opens and when you return from the background.',
  'Açılış ve kurulum görselleri artık ekrana tam sığıyor.':
      'The launch and intro images now fit the screen completely.',
  'Güvenlik':
      'Security',
  'Uygulama kilidi':
      'App lock',
  'Açıkken uygulama açılırken ve arka plandan 5 saniyeden uzun kaldıktan sonra dönünce şifre sorulur.':
      'When on, a password is asked when the app opens and when you return after more than 5 seconds in the background.',
  'Şifreyi değiştir':
      'Change password',
  'Bu kilit uygulamanın ekranını korur. Veri telefonda şifrelenmeden durur; “son uygulamalar” ekranındaki önizleme ve Ayarlar’daki yedek metni de korunmaz.':
      'This lock protects the app screen. Data is stored unencrypted on the phone; the preview in the recent apps screen and the backup text from Settings are not protected either.',
  'Uygulama kilidi açıldı.':
      'App lock turned on.',
  'Uygulama kilidi kapatıldı.':
      'App lock turned off.',
  'Şifre değiştirildi.':
      'Password changed.',
  'Şifre yanlış':
      'Wrong password',
  'Uygulama kilitli':
      'The app is locked',
  'Şifre':
      'Password',
  'İpucu: {0}':
      'Hint: {0}',
  'Aç':
      'Unlock',
  '{0} sn bekle':
      'Wait {0} s',
  'Şifreni belirle':
      'Set your password',
  'Yeni şifre':
      'New password',
  'Şifreyi tekrar yaz':
      'Repeat the password',
  'Şifre ipucu (isteğe bağlı)':
      'Password hint (optional)',
  'Şifre en az 4 karakter olmalı':
      'The password must be at least 4 characters',
  'Şifreler aynı değil':
      'The passwords do not match',
  'Şifreni unutursan sıfırlamanın tek yolu uygulamayı kaldırıp yeniden kurmaktır; bu da tüm verilerini siler. Önce Ayarlar’dan yedek al.':
      'If you forget your password, the only way to reset it is to uninstall and reinstall the app, which deletes all your data. Back up from Settings first.',
  'Mevcut şifre':
      'Current password',
  '1) Telefon Ayarlar > Uygulamalar > Daily Routine > Bildirimler açık olsun.\n2) "Alarmlar ve hatırlatıcılar" iznini aç.\n3) Pil ayarında Daily Routine için "Kısıtlama yok" seç.\n4) Xiaomi / Redmi: Ayarlar > Uygulamalar > Daily Routine > Otomatik başlat\'ı aç ve pil tasarrufunu "Kısıtlama yok" yap.\n5) Ayarlar menüsündeki "Deneme bildirimi" ile test et.':
      '1) In phone Settings > Apps > Daily Routine, make sure Notifications are on.\n2) Turn on the "Alarms and reminders" permission.\n3) In battery settings choose "No restrictions" for Daily Routine.\n4) Xiaomi / Redmi: Settings > Apps > Daily Routine > turn on Autostart and set battery saver to "No restrictions".\n5) Test with "Test notification" in the app Settings.',
  'Ana ekran satırları küçüldü; hedefi tamamlanan yeşil satırlar en alta iner.':
      'Home rows are smaller; green rows with a completed goal move to the bottom.',
  'Aralıklı':
      'Repeating',
  'Başlangıç':
      'Start',
  'Başlık':
      'Title',
  'Bildirim':
      'Notification',
  'Bildirim gelmiyorsa':
      'If notifications do not arrive',
  'Bildirim izni verilmedi. Telefon ayarlarından Daily Routine için bildirimleri aç.':
      'Notification permission was not granted. Turn on notifications for Daily Routine in phone settings.',
  'Deneme bildirimi':
      'Test notification',
  'Deneme bildirimi: çalışıyor!':
      'Test notification: it works!',
  'Ekle ekranında “Serbest satır”: başlığı ve verisi serbest bir satır ekle.':
      'Free row in the Add screen: add a row with a free title and free data.',
  'Günlük’e Kaydet düğmesi eklendi.':
      'A Save button was added to the Diary.',
  'Hatırlatma':
      'Reminder',
  'Hatırlatıcı':
      'Reminder',
  'Hatırlatıcı bildirimleri':
      'Reminder notifications',
  'Hatırlatıcı silindi':
      'Reminder deleted',
  'Hatırlatıcı: alttaki yeni sekmeden tek seferlik, aralıklı veya her gün bildirim kur.':
      'Reminder: from the new bottom tab, set one-time, repeating or daily notifications.',
  'Hatırlatıcılar':
      'Reminders',
  'Hatırlatıcıyı düzenle':
      'Edit reminder',
  'Henüz hatırlatıcı yok. Yukarıdan ekleyebilirsin.':
      'No reminders yet. You can add one above.',
  'Her gün':
      'Every day',
  'Her gün {0}':
      'Every day at {0}',
  'Kaldır':
      'Remove',
  'Kaydedildi':
      'Saved',
  'Maddeyi düzenle':
      'Edit item',
  'Ne hatırlatılsın?':
      'What should be reminded?',
  'Saat':
      'Time',
  'Satır silindi':
      'Row deleted',
  'Satırı düzenle':
      'Edit row',
  'Sağa kaydır: düzenle • Sola kaydır: sil. Bildirim gelmezse sağ üstteki ? simgesine bak.':
      'Swipe right: edit - Swipe left: delete. If notifications do not arrive, tap the ? icon at the top right.',
  'Serbest satır':
      'Free row',
  'Serbest veri':
      'Free data',
  'Tam zamanlı alarm':
      'Exact alarm',
  'Tam zamanlı alarm izni yok; bildirimler birkaç dakika gecikebilir. Ayarlardan "Alarmlar ve hatırlatıcılar" iznini açabilirsin.':
      'Exact alarm permission is missing; notifications may be delayed by a few minutes. You can turn on "Alarms and reminders" in settings.',
  'Tamamlandı':
      'Completed',
  'Tek sefer':
      'Once',
  'Tek seferlik':
      'One-time',
  'Tekrar':
      'Repeat',
  'Tekrar aralığı':
      'Repeat interval',
  'Toplam kaç kez':
      'How many times in total',
  'Yapılacaklar: sağa kaydırıp düzenle, ≡ ile sürükleyip sırala, zil ile hatırlatma koy.':
      'To-do: swipe right to edit, drag with the handle to reorder, use the bell to set a reminder.',
  'Yeni hatırlatıcı':
      'New reminder',
  'açık':
      'on',
  'kapalı':
      'off',
  '{0} dk':
      '{0} min',
  '{0} saat':
      '{0} h',
  '{0} • her {1} • {2} kez':
      '{0} - every {1} - {2} times',
  'Çalışmıyorsa ne yapmalı?':
      'What if it does not work?',
  'Önce hatırlatıcı metnini yaz.':
      'Write the reminder text first.',
  'İzin durumu':
      'Permission status',
  'İzin durumunu kontrol et':
      'Check permission status',
  'Şimdi':
      'Now',
  'Ana ekranda kategoriler ayrı ayrı süzülebilir: üstteki kategori düğmelerine dokun.':
      'Categories can be filtered on the home screen: tap the category buttons at the top.',
  'Serbest satıra hatırlatma ve gün seçimi eklendi; ileri bir güne not düşüp o gün bildirim alabilirsin.':
      'Free rows now have a reminder and a day picker; you can leave a note for a future day and get a notification then.',
  'Açılış ekranında resmin altında motivasyon sözü gösterilir.':
      'The launch screen shows a motivational quote under the picture.',
  'Tümü':
      'All',
  'Hangi günde görünsün?':
      'Which day should it appear on?',
  'Hatırlatma (isteğe bağlı)':
      'Reminder (optional)',
  'Hatırlatma ekle':
      'Add reminder',
  'Yeni uygulama simgesi.':
      'New app icon.',
  'Sol altta D: Yapılacaklar, Günlük ve Hatırlatıcı. Sağ altta R: Ekle.':
      'D at bottom left: To-do, Diary and Reminder. R at bottom right: Add.',
  'Tarih seçici en üste alındı; Daily yazısı ve sırala düğmesi kalktı.':
      'The date picker moved to the top; the Daily title and the sort button were removed.',
  'Ekle ekranında başlıklar belirginleşti; Kategori ekle / Alt kategori ekle.':
      'Headings in the Add screen are clearer; Add category / Add subcategory.',
  'Koyu temada satırlar zeminden daha belirgin.':
      'Rows stand out more from the background in the dark theme.',
  'Bu satır bu gün için bir rutin değil. Veriyi sağa kaydırıp silebilirsin.':
      'This row is not a routine for today. You can swipe right to delete its data.',
  'Günlük hatırlatma saati':
      'Daily reminder time',
  'Rutin kaldırılsın mı?':
      'Remove the routine?',
  'Rutinin görüneceği günlerde bu saatte bildirim gelir.':
      'A notification arrives at this time on the days the routine is shown.',
  'Sadece bu gün':
      'Only this day',
  'Satırlarda solda ≡ ile doğrudan sürükleyip sırala; sağda zil ile rutine günlük hatırlatma saati koy.':
      'Drag rows with the handle on the left to reorder; use the bell on the right to set a daily reminder time for a routine.',
  'Sağa kaydırınca veri, rutin günleri ve hatırlatma saati düzenlenir; veri de buradan silinir.':
      'Swipe right to edit the data, routine days and reminder time; data can be deleted there too.',
  'Sola kısa kaydır: rutin sadece o gün kalkar. Sola tamamen kaydır: rutin tüm günlerden kalkar (uyarı sorar).':
      'Short swipe left: the routine is removed for that day only. Full swipe left: the routine is removed from all days (asks first).',
  'Tüm günlerden':
      'From all days',
  'Veriyi sil':
      'Delete data',
  '{0} bu gün için kaldırıldı':
      '{0} removed for this day',
  '{0} hatırlatması':
      '{0} reminder',
  '{0} rutini kaldırıldı':
      '{0} routine removed',
  '“{0}” bugünden itibaren tüm günlerden kalkar ve hatırlatması silinir. Geçmiş veriler korunur. Tekrar eklemek için Ekle ekranında Rutin olsun anahtarını aç.':
      '“{0}” will be removed from today on and its reminder deleted. Past data is kept. To add it again, turn on the Routine switch in the Add screen.',
  'Ekle için sağ alttaki DR düğmesine dokun.':
      'For Add, tap the DR button at the bottom right.',
  'Bir satırı sağa kaydırınca düzenlenir; sola kısa kaydırınca rutin o gün kalkar, tamamen kaydırınca tüm günlerden kalkar.':
      'Swipe a row right to edit; swipe left a little to remove the routine for that day, or all the way to remove it from all days.',
  'Satırın solundaki ≡ simgesinden sürükleyerek rutinlerini sıralayabilirsin.':
      'Drag a row by the ≡ handle on its left to reorder your routines.',
  'Günün notunu yazmak için ana ekranda rutinlerin altındaki Günlük başlığını açabilirsin.':
      'To write the day’s note, open the Diary section under your routines on the home screen.',
  'Yapılacaklar, Günlük ve Hatırlatıcı ana ekranda rutinlerin altındaki açılır başlıklarda.':
      'To-do, Diary and Reminder are the expandable sections under your routines on the home screen.',
  'Sağ alttaki DR düğmesine dokun; kategori ve alt kategori seç, “Rutin olsun” anahtarını aç ve günlük hedefini yaz. Hedefe ulaşınca satır yeşile döner. Satırı sağa kaydırarak düzenle; sola kısa kaydırarak rutini o gün için, tamamen kaydırarak tüm günlerden kaldır; ≡ ile sürükleyip sırala. Boş yere sağa veya sola kaydırarak günler arasında geçebilirsin.':
      'Tap the DR button at the bottom right; pick a category and subcategory, turn on the “Routine” switch and enter a daily goal. The row turns green when you reach it. Swipe a row right to edit; swipe left a little to remove the routine for that day, or all the way to remove it from all days; drag with ≡ to reorder. Swipe left or right on empty space to move between days.',
  'Sol üstteki ≡ menüsüne dokun: kategori istatistiklerini ve notu olan günlerin takvimini (Günlük) görürsün. Yapılacaklar, Günlük ve Hatırlatıcı ana ekranda rutinlerin altındaki açılır başlıklarda; ayarlar menünün içinde. Tüm verilerin sadece telefonunda saklanır.':
      'Tap the ≡ menu at the top left: you will see category statistics and a calendar of days with notes (Diary). To-do, Diary and Reminder are the expandable sections under your routines on the home screen; settings are in the menu. All your data is stored only on your phone.',
  '"Podcast ara" ile bul ve takip et; haber özeti, sohbet, eğitim gibi sesli yayınlar kategorilerde listelenir.': 'Find and follow with "Search podcasts"; news summaries, talks and lessons are listed in categories.',
  '"{0}" silinir; içindeki podcast\'ler ilk kategoriye geçer.': '"{0}" will be deleted; its podcasts move to the first category.',
  'API anahtarı': 'API key',
  'Bu kategoride podcast yok.': 'No podcasts in this category.',
  'En yüksek {0} • en düşük {1}': 'High {0} • low {1}',
  'Girildi': 'Entered',
  'Girilmedi': 'Not entered',
  'Hava durumu internetten alınır. Bugünde şimdiki durum, tarihin yanındaki simgeye basınca saatlik hava açılır.': 'Weather is fetched online. Today shows the current conditions; tap the icon next to the date for the hourly forecast.',
  'Hava durumu için servis seçebilirsin (Open-Meteo, MET Norway, MGM, OpenWeatherMap...). Ayarlar > Hava durumu.': 'You can choose the weather service (Open-Meteo, MET Norway, MGM, OpenWeatherMap...). Settings > Weather.',
  'Hava durumu için şehir adı yerine telefonun konumunu kullanabilirsin.': 'You can use your phone location instead of a city name for the weather.',
  'Hava durumu servisi': 'Weather service',
  'Kategori değiştir': 'Change category',
  'Konum izni verilmedi.': 'Location permission was not granted.',
  'Konumum': 'My location',
  'Konumumu kullan': 'Use my location',
  'MGM verisi okunamadı. Başka bir servis seçebilirsin.': 'MGM data could not be read. You can choose another service.',
  'MGM verisi resmi olmayan yoldan alınır; çalışmazsa başka bir servis seç.': 'MGM data is obtained unofficially; if it fails, choose another service.',
  'OpenWeatherMap anahtarı': 'OpenWeatherMap key',
  'OpenWeatherMap anahtarı girilmemiş.': 'OpenWeatherMap key is missing.',
  'Podcast\'ler artık kategorilerde; sıralayabilir ve kategori değiştirebilirsin.': 'Podcasts are now in categories; you can reorder them and change category.',
  'Telefonun konum servisi kapalı.': 'Location service is turned off on the phone.',
  'Şehir adıyla seç': 'Choose by city name',
  '"{0}" silinir; içindeki kaynaklar ilk kategoriye geçer.': '"{0}" will be deleted; its sources move to the first category.',
  'Ad ve http ile başlayan RSS adresi gerekli.': 'A name and an RSS address starting with http are required.',
  'Bu kategoride kaynak yok.': 'No sources in this category.',
  'Bu kaynakta haber bulunamadı.': 'No news found in this source.',
  'Gündem': 'Headlines',
  'Günün özetini oku': 'Read the daily summary',
  'Haberler RSS adreslerinden okunur. Adresler değişebilir; çalışmazsa kaynağı düzenleyip yeni RSS adresini yaz. Kategori menüsünden "Günün özetini oku" ile telefon sesiyle dinle.': 'News is read from RSS addresses. Addresses may change; if one fails, edit the source and enter the new RSS address. Use "Read the daily summary" in the category menu to listen with the phone voice.',
  'Haberler alınamadı. İnternetini kontrol et.': 'News could not be loaded. Check your internet.',
  'Haberler alınamadı. İnternetini veya RSS adresini kontrol et.': 'News could not be loaded. Check your internet or the RSS address.',
  'Haberler alınıyor...': 'Loading news...',
  'Kategori menüsünden "Günün özetini oku" ile haberleri telefonun sesiyle dinleyebilirsin.': 'Use "Read the daily summary" in the category menu to listen to the news with the phone voice.',
  'Kaynak adreslerini sen ekleyip düzenleyebilirsin.': 'You can add and edit source addresses yourself.',
  'Kaynak adı': 'Source name',
  'Kaynak ekle': 'Add source',
  'Kaynak silinsin mi?': 'Delete source?',
  'Kaynağı düzenle': 'Edit source',
  'Oku': 'Read',
  'Okunuyor: {0}': 'Reading: {0}',
  'RSS adresi': 'RSS address',
  'Tarayıcıda aç': 'Open in browser',
  'Yeni: Haber sekmesi (Müzik ve Radyo içinde). RSS kaynakları kategorilerde, başlıklar ve özetler aşağı açılır.': 'New: News tab (inside Music and Radio). RSS sources in categories; headlines and summaries open downward.',
  'Özet yok.': 'No summary.',
  'Özeti oku': 'Read summary',
  'Ülke: {0}': 'Country: {0}',
  'Tür: {0}': 'Genre: {0}',
  'Radyo ekle ekranında seçimler "Ülke: Türkiye", "Tür: Hepsi" diye yazıyor.': 'On the Add radio screen, the selections now read "Country: Türkiye", "Genre: All".',
  'Bitir': 'Finish',
  'Kaydediliyor...': 'Recording...',
  'Kayıt başlatılamadı.': 'Could not start recording.',
  'Kayıt telefondan silinir.': 'The recording will be deleted from the phone.',
  'Madde başlığı': 'Item title',
  'Mikrofon izni verilmedi.': 'Microphone permission was not granted.',
  'Ses dosyası bulunamadı.': 'Audio file not found.',
  'Ses kaydı': 'Voice recording',
  'Ses kaydı ekle': 'Add voice recording',
  'Ses kaydı silinsin mi?': 'Delete voice recording?',
  'Ses kaydı • {0}': 'Voice recording • {0}',
  'Ses kayıtları sadece telefonda durur, yedek dosyasına girmez.': 'Voice recordings stay only on the phone and are not included in the backup file.',
  'Sesle ekle': 'Add by voice',
  'Yeni: Günlüğe ses kaydı ekleyebilirsin (Günlük sayfasında mikrofon düğmesi).': 'New: you can add a voice recording to the diary (microphone button on the Diary page).',
  'Yeni: Yapılacaklara sesle madde ekleyebilirsin; maddede başlık ve ses işareti görünür, dokununca dinlersin.': 'New: add to-do items by voice; the item shows a title and a mic mark, tap to listen.',
  'Bugün henüz bir hedefine ulaşmadın. Küçük bir adımla başla, hepsine ulaşman zor olmayacak.': 'You have not reached any goal yet today. Start with a small step; reaching them all will not be hard.',
  'Bugünkü tüm hedefler tamamlanınca havai fişek çıkar.': 'Fireworks appear when all of today\'s goals are completed.',
  'Geç': 'Continue',
  'Hedeflerinin %{0} kadarına ulaştın. Bitirmene çok az kaldı!': 'You have reached about {0}% of your goals. Almost there!',
  'Hedeflerinin %{0} kadarına ulaştın. Güzel bir başlangıç, hepsine ulaşman zor olmayacak.': 'You have reached about {0}% of your goals. A good start; reaching them all will not be hard.',
  'Hedeflerinin %{0} kadarına ulaştın. Yolun büyük kısmı geride, hepsine ulaşman zor olmayacak.': 'You have reached about {0}% of your goals. Most of the way is behind you; reaching them all will not be hard.',
  'Motivasyon sözü ana ekrandan kalktı, açılış ekranında görünür.': 'The motivation quote moved from the home screen to the opening screen.',
  'Tebrikler! Bugünkü hedeflerinin tamamına ulaştın.': 'Congratulations! You reached all of today\'s goals.',
  'Tebrikler! Bugünkü tüm hedeflerine ulaştın.': 'Congratulations! You reached all of today\'s goals.',
  'Yeni açılış ekranı: bugünkü hedeflerinin yüzdesi, açıklama ve motivasyon sözü. Kendiliğinden geçmez; "Geç" düğmesine bas.': 'New opening screen: today\'s goal percentage, a message and a motivation quote. It does not close by itself; tap "Continue".',
  '"{0}" silindi.': '"{0}" deleted.',
  '"{0}" takipten çıkarıldı.': 'Unfollowed "{0}".',
  'Alt kategori seç': 'Choose subcategory',
  'Araçlar': 'Tools',
  'Başlat': 'Start',
  'Bir bardak çıkar': 'Remove a glass',
  'Bu araç için hatırla': 'Remember for this tool',
  'Diğer kayıtlara (serbest satır)': 'To other records (free row)',
  'Diğer kayıtlara eklendi.': 'Added to other records.',
  'En az bir liste kalmalı.': 'At least one list must remain.',
  'Geçen süre: {0} dk': 'Elapsed: {0} min',
  'Hazır': 'Ready',
  'Hedef sayı': 'Target count',
  'Hedef: {0} {1}': 'Goal: {0} {1}',
  'Henüz bir su rutini seçilmedi': 'No water routine chosen yet',
  'Kalktım': 'I woke up',
  'Kategori seç': 'Choose category',
  'Kaç dakika?': 'How many minutes?',
  'Kronometre': 'Stopwatch',
  'Mola': 'Break',
  'Nefes': 'Breathing',
  'Nefes al': 'Breathe in',
  'Nefes ver': 'Breathe out',
  'Odaklanılan süre: {0} dk': 'Focused time: {0} min',
  'Podcast adı': 'Podcast name',
  'Pomodoro': 'Pomodoro',
  'Pomodoro: süre doldu.': 'Pomodoro: time is up.',
  'Rutin seç': 'Choose routine',
  'Rutine kaydet': 'Save to routine',
  'Sayaç': 'Timer',
  'Sayaç bitti.': 'Timer finished.',
  'Su': 'Water',
  'Su rutini': 'Water routine',
  'Su sayacı': 'Water counter',
  'Süre ve sayıları tek dokunuşla rutinlerine ekle.': 'Add times and counts to your routines with one tap.',
  'Sıfırla': 'Reset',
  'Tur': 'Lap',
  'Tut': 'Hold',
  'Uyku': 'Sleep',
  'Yatmadan önce "Yattım"a bas, kalkınca "Kalktım"a bas.': 'Tap "I went to bed" before sleeping and "I woke up" when you wake.',
  'Yattım': 'I went to bed',
  'Yattığın saat: {0}': 'Bedtime: {0}',
  'Zikirmatik': 'Tally counter',
  'dk': 'min',
  'lt': 'L',
  'saat': 'h',
  '{0}: API anahtarı girilmemiş.': '{0}: API key is missing.',
  '{0}: anahtar geçersiz veya henüz etkin değil (401). Yeni anahtarlar etkinleşmek için biraz bekleyebilir.': '{0}: the key is invalid or not active yet (401). New keys may take a while to activate.',
  '{0}: bağlantı hatası.': '{0}: connection error.',
  '{0}: {1} adımında hata ({2}).': '{0}: error at step {1} ({2}).',
  '{0}: {1} {2} eklendi.': '{0}: {1} {2} added.',
  'Çalışma • tur {0}/4': 'Work • round {0}/4',
  'Özel': 'Custom',
  'İptal': 'Cancel',
  'Yeni Araçlar menüsü (üstteki alet simgesi): kronometre, sayaç, pomodoro, nefes, zikirmatik, su sayacı, uyku. Sonuçlar rutinine yazılır.': 'New Tools menu (wrench icon on top): stopwatch, timer, pomodoro, breathing, tally counter, water counter, sleep. Results are written to your routine.',
  'Satır olan her yerde: sağa kaydır düzenle, sola kaydır sil, ≡ ile sırala.': 'On every row list: swipe right to edit, swipe left to delete, use ≡ to reorder.',
  'Ekle ekranında kategori ve alt kategori açılır liste; Kategorileri düzenle açılır listeli.': 'Category and subcategory are dropdowns in Add; Edit categories is now an accordion.',
  'Hava durumu hata mesajları daha açıklayıcı.': 'Weather error messages are clearer.',
  'Anahtar gir': 'Enter key',
  'Bir bölüme dokun, çalmaya başlar.': 'Tap an episode to start playing.',
  'Dosyadan seç': 'Pick from files',
  'Favoriler': 'Favorites',
  'Favorilerden çıkar': 'Remove from favorites',
  'Favorilere ekle': 'Add to favorites',
  'Henüz favori yok. Parçadaki kalbe dokun.': 'No favorites yet. Tap the heart on a track.',
  'Jamendo anahtarı': 'Jamendo key',
  'Jamendo anahtarı (client id)': 'Jamendo key (client id)',
  'Jamendo ücretsiz bir geliştirici anahtarı ister: devportal.jamendo.com adresinde hesap açıp bir uygulama oluştur, "Client ID" kodunu buraya yapıştır.': 'Jamendo needs a free developer key: create an account at devportal.jamendo.com, create an app and paste the "Client ID" here.',
  'Meditasyon': 'Meditation',
  'Meditasyon bitti.': 'Meditation finished.',
  'Online': 'Online',
  'Podcast listen boş.': 'Your podcast list is empty.',
  'Podcast\'lerimden': 'From my podcasts',
  'Ses': 'Sound',
  'Ses seçilemedi: {0}': 'Could not pick sound: {0}',
  'Ses yok': 'No sound',
  'Sesi kapat': 'Turn sound off',
  'Sonuç yok.': 'No results.',
  'Tebrikler!': 'Congratulations!',
  '{0}: {1}': '{0}: {1}',
  'Şarkı, sanatçı veya tür ara': 'Search song, artist or genre',
  'Hip-hop': 'Hip-hop',
  'Ambient': 'Ambient',
  'Lounge': 'Lounge',
  'Rahatça otur, gözlerini yavaşça kapat.': 'Sit comfortably and slowly close your eyes.',
  'Omuzlarını gevşet.': 'Relax your shoulders.',
  'Nefesini değiştirmeye çalışma, sadece izle.': 'Don\'t try to change your breath, just watch it.',
  'Aklına düşünceler gelirse onları fark et ve bırak.': 'If thoughts come, notice them and let them go.',
  'Karnının yükselip alçaldığını hisset.': 'Feel your belly rise and fall.',
  'Çeneni ve yüzünü gevşet.': 'Relax your jaw and face.',
  'Her nefes verişte biraz daha sakinleş.': 'Settle a little more with every exhale.',
  'Şu an burada olmanın tadını çıkar.': 'Enjoy being here, right now.',
  'MGM hava durumu düzeltildi: konumuna en yakın istasyon seçilir.': 'MGM weather fixed: the station nearest to you is chosen.',
  'Kutlama daha canlı: havai fişek, konfeti ve Tebrikler yazısı.': 'Livelier celebration: fireworks, confetti and a Congratulations message.',
  'Araçlar menüsüne Meditasyon eklendi; arka plan sesi podcast ya da dosyadan çalar.': 'Meditation added to Tools; background sound plays from a podcast or a file.',
  'Araçlar renkli ve animasyonlu; müzik, radyo, podcast ve haber kategorileri ayrı renklerde.': 'Tools are colorful and animated; music, radio, podcast and news categories have their own colors.',
  'Müzik bölümüne Online sekmesi: Jamendo ve Audius, favoriler.': 'New Online tab in Music: Jamendo and Audius, favorites.',
  'Bu gün için madde yok. Yukarıdan ekleyebilirsin.': 'No items for this day. You can add one above.',
  'Yarına': 'Tomorrow',
  'Yarına gönderildi': 'Sent to tomorrow',
  'Yapılacaklar, Günlük ve Hatırlatıcı artık ana ekranda rutinlerin altında açılır başlıklar.': 'To-do, Diary and Reminder are now expandable sections under your routines on the home screen.',
  'Yapılacaklar güne özel: sağa az kaydır düzenle, tam kaydır yarına gönder, sola kaydır sil. Bitmeyenler her gün bugüne taşınır.': 'To-dos are per day: short swipe right to edit, full swipe to send to tomorrow, swipe left to delete. Unfinished items roll over to today.',
  'Sağ altta yuvarlak DR düğmesi; Ekle paneli düğmeden büyüyerek açılır.': 'Round DR button at the bottom right; the Add panel grows from the button.',
  '10 sn ileri': '10 s forward',
  'Henüz kayıt yok. Biten seanslar buraya eklenir.': 'No records yet. Finished sessions are added here.',
  'Kayda ekle': 'Add to log',
  'Kayda eklendi': 'Added to log',
  'Kayıt silindi': 'Record deleted',
  'Meditasyon kayıtları': 'Meditation log',
  'Nefes sesi': 'Breath sounds',
  'Not': 'Note',
  'Not eklemek için dokun': 'Tap to add a note',
  'Online müzik': 'Online music',
  'Rutinler': 'Routines',
  'Tebrikler': 'Congratulations',
  'Titreşim': 'Vibration',
  'Bugünün hedeflerini bitirdin. Sen durdurulamazsın!': 'You finished today\'s goals. You\'re unstoppable!',
  'Söz verdin, tuttun. İşte bu!': 'You made a promise and kept it. That\'s it!',
  'Küçük adımlar büyük farkı yaratır. Bugün hepsini attın.': 'Small steps make a big difference. You took them all today.',
  'Bugün kendine kazandırdın. Devam!': 'You won today for yourself. Keep going!',
  'Disiplin sende. Yarın da aynısı.': 'Discipline is yours. Same again tomorrow.',
  'Meditasyon: nefes sesleri, gong, oynatıcı, online müzik, kayıt listesi ve notlar.': 'Meditation: breath sounds, gong, player, online music, log list and notes.',
  'Ana ekranda tek "Rutinler" başlığı; aşağı çekince ekran ilk haline döner.': 'A single "Routines" section on the home screen; pull down to reset the screen.',
  'Tebrikler ekranı daha sade; "Geri al" bildirimi kendiliğinden kapanır.': 'Simpler congratulations screen; the "Undo" notice now closes by itself.',
  '15 gün': '15 days',
  'Anahtar': 'Key',
  'Aynalı': 'Glassy',
  'Ayrıntılı hava': 'Detailed weather',
  'Basınç': 'Pressure',
  'Bu adreste podcast RSS\'i bulunamadı.': 'No podcast RSS found at this address.',
  'Bu görünüm için veri yok.': 'No data for this view.',
  'Bu konumda deniz verisi yok.': 'No sea data for this location.',
  'Bulut': 'Cloud cover',
  'Dalga (uzun)': 'Swell',
  'Dalga periyodu': 'Wave period',
  'Dalga yönü': 'Wave direction',
  'Dalga yüksekliği': 'Wave height',
  'Dalgalı': 'Rough',
  'Deniz durumu': 'Sea state',
  'Deniz suyu sıcaklığı': 'Sea temperature',
  'Doygunluk': 'Saturation',
  'Favori': 'Favorite',
  'Gong': 'Gong',
  'Görüş': 'Visibility',
  'Günlere göre en yüksek dalga': 'Highest wave by day',
  'Hafif dalgalı': 'Slight',
  'Haftalık': 'Weekly',
  'Henüz favori podcast yok. Podcast\'in yanındaki yıldıza dokun.': 'No favorite podcasts yet. Tap the star next to a podcast.',
  'Henüz favori radyo yok. Radyonun yanındaki yıldıza dokun.': 'No favorite stations yet. Tap the star next to a station.',
  'Hissedilen': 'Feels like',
  'Kaynak: {0}': 'Source: {0}',
  'Konum yok. Önce Ayarlar\'dan hava durumunu aç (konum ya da şehir seç).': 'No location. First turn on weather in Settings (pick location or city).',
  'Kısa mola': 'Short break',
  'Miktar': 'Amount',
  'Nefes sesi çalınamadı: {0}': 'Breath sound could not play: {0}',
  'Nem': 'Humidity',
  'Orta dalgalı': 'Moderate',
  'Parlaklık': 'Brightness',
  'Podcast Index API anahtarı': 'Podcast Index API key',
  'Podcast Index gizli anahtarı': 'Podcast Index secret',
  'Podcast Index için anahtar gerekli (podcastindex.org\'da ücretsiz kayıt).': 'Podcast Index needs a key (free signup at podcastindex.org).',
  'RSS adresi (https://...)': 'RSS address (https://...)',
  'Renk': 'Color',
  'Renk skalası': 'Color scale',
  'Rüzgar': 'Wind',
  'Sakin': 'Calm',
  'Seçili kaynak bu kadar gün veriyor.': 'The selected source provides this many days.',
  'Sürekli tekrar': 'Repeat all',
  'Süreleri ayarla': 'Set durations',
  'Tek parça tekrar': 'Repeat one',
  'Tekrar kapalı': 'Repeat off',
  'UV': 'UV',
  'Uygula': 'Apply',
  'Uzun mola (4 turda bir)': 'Long break (every 4 rounds)',
  'Veri alınamadı: {0}': 'Could not get data: {0}',
  'Yağış': 'Precipitation',
  'alınamayan': 'unavailable',
  'hamle': 'gust',
  'km/sa': 'km/h',
  'nem': 'humidity',
  'sn': 's',
  'yağış ihtimali': 'chance of rain',
  'Çalışma süresi': 'Work time',
  'Çok dalgalı': 'Very rough',
  'Üstü ekler, altı çıkarır': 'Top adds, bottom removes',
  'Podcast, Spreaker, Internet Archive ve RSS ile bul; radyo ve podcast için yıldızlı favoriler.': 'Find podcasts via Spreaker, Internet Archive and RSS; starred favorites for radio and podcasts.',
  'Ayrıntılı hava (Araçlar): günlük, haftalık, 15 günlük; nem, rüzgar, basınç, UV, görüş ve deniz durumu. Kaynak adı yazar.': 'Detailed weather (Tools): daily, weekly, 15-day; humidity, wind, pressure, UV, visibility and sea state. Shows the source.',
  'DR paneli ekranın yarısına kadar açılır; Ayarlar\'da renk skalası.': 'The DR panel opens up to half the screen; color scale in Settings.',
  'Pomodoro süreleri ayarlanır, gong ve titreşim uyarısı; su sayacında ml girişi.': 'Pomodoro durations are adjustable with gong and vibration alerts; ml input in the water tracker.',
  'Nefes sesi hava sesi oldu; Nefes aracında da ses ve titreşim. Müzikte Tekrar/Karışık.': 'Breath sound is now airy; sound and vibration in the Breath tool too. Repeat/Shuffle in music.',
  'Alınan kaynaklar: {0}': 'Sources used: {0}',
  'Ana ekrandaki hava durumu': 'Weather on the home screen',
  'Anladım, devam': 'Got it, next',
  'Açıklama': 'Explanation',
  'Biliyorum': 'I know it',
  'Bilmiyorum': 'I don\'t know it',
  'Bu konudaki tüm kartların da silinir.': 'All cards in this topic will be deleted too.',
  'Ders çalışma': 'Study',
  'Diğer başlıkların kaynağı': 'Source for the other sections',
  'Hazır içerikler yardımcı notlardır; kaynaklarla tek tek doğrulanmamıştır. Düzenleyebilir, silebilir ve kendi kartlarını ekleyebilirsin.': 'Ready-made content is a study aid and has not been verified against sources one by one. You can edit or delete it and add your own cards.',
  'Henüz kart yok. Kart ekle düğmesiyle başla.': 'No cards yet. Start with the Add card button.',
  'Hepsini yeniden çalış': 'Study all again',
  'Kalan: {0} / {1}': 'Left: {0} / {1}',
  'Kart ekle': 'Add card',
  'Kart silinsin mi?': 'Delete this card?',
  'Kartı düzenle': 'Edit card',
  'Kaynaklar ve ayarlar': 'Sources and settings',
  'Kelime / deyim': 'Word / idiom',
  'Konu adı': 'Topic name',
  'Konu başlığı': 'Topic title',
  'Konu ekle': 'Add topic',
  'Konu silinsin mi?': 'Delete this topic?',
  'Konum yok. Aşağıdaki Kaynaklar ve ayarlar bölümünden konum ya da şehir seç.': 'No location. Choose a location or city in Sources and settings below.',
  'LGS': 'LGS',
  'Seçili kaynakta bu veri yok.': 'This data is not available in the selected source.',
  'Silinen hazır kartları geri getir': 'Restore deleted ready-made cards',
  'Sıcaklık': 'Temperature',
  'Tekrar bitti': 'Review finished',
  'Tekrar et ({0})': 'Review ({0})',
  'Tekrar zamanı': 'Due for review',
  'Tüm konuları tekrar et ({0})': 'Review all topics ({0})',
  'Yabancı dil': 'Foreign language',
  'Yeni kart': 'New card',
  'Yeni konu': 'New topic',
  'hazır': 'ready-made',
  '{0} kart bilindi.': '{0} cards known.',
  '{0} kart • {1} tekrar bekliyor': '{0} cards • {1} due for review',
  'Örnek cümle': 'Example sentence',
  'Öğrenildi': 'Learned',
  'Şimdilik tekrar bekleyen kart yok.': 'No cards due for review right now.',
  'Yeni: Ders çalışma (üst çubukta sol). LGS dersleri ve İngilizce için hazır kartlar; kendi kartlarını ekle, Biliyorum/Bilmiyorum ile aralıklı tekrar yap.': 'New: Study (top bar, left). Ready-made cards for LGS subjects and English; add your own cards and use I know/I don\'t know for spaced repetition.',
  'Hava durumu sayfası yenilendi: kaynaklar yan yana, açılır başlıklar. Hava ayarları buraya taşındı.': 'Weather page redesigned: sources side by side, collapsible sections. Weather settings moved here.',
  'Ayarlar\'daki başlıklar açılır kapanır oldu.': 'Sections in Settings are now collapsible.',
  'Meditasyon ve Nefes\'te nefes al/ver için tek tını sesi.': 'A single chime for breathing in/out in Meditation and Breathing.',
  'Araç sayfalarının sağ üstünde Araçlar simgesi; sayfadan çıkınca süre sayan araçlar duraklar.': 'Tools icon at the top right of tool pages; timed tools pause when you leave the page.',
  'Su sayacında Geri al bildirimi kaldırıldı.': 'Undo notice removed from the water counter.',
  'Ders çalışmaya yeni içerik: Türkçe (anlam özellikleri, duygu durumları, söz sanatları, noktalama), İngilizce fiiller, zamanlar, zamirler, edatlar ve LGS İngilizce üniteleri.': 'New study content: Turkish (sentence meaning, emotions, figures of speech, punctuation), English verbs, tenses, pronouns, prepositions and LGS English units.',
  'Alarm': 'Alarm',
  'Alarm adı (isteğe bağlı)': 'Alarm name (optional)',
  'Alarm bildirimleri': 'Alarm notifications',
  'Alarm ekle': 'Add alarm',
  'Alarm silinsin mi?': 'Delete this alarm?',
  'Alarm, telefonun alarm sesiyle bildirim olarak çalar; kapatana kadar tekrarlar. Telefonun "Alarmlar ve hatırlatıcılar" iznini vermen gerekebilir.': 'The alarm rings as a notification with the phone\'s alarm sound and repeats until you dismiss it. You may need to allow "Alarms & reminders" for this app.',
  'Alarmı düzenle': 'Edit alarm',
  'Başlangıçta hatırlat': 'Remind at start',
  'Başlatıcı': 'Launcher',
  'Başlatıcı ekle': 'Add launcher',
  'Başlatıcı silinsin mi?': 'Delete this launcher?',
  'Başlatıcıyı düzenle': 'Edit launcher',
  'Bir seçim yap.': 'Pick one.',
  'Bu konuya henüz not yazılmadı.': 'No notes for this topic yet.',
  'Bu konuya henüz ses kaydı yok.': 'No voice recordings for this topic yet.',
  'Ders': 'Subject',
  'Ders ekle': 'Add lesson',
  'Ders çalış': 'Study',
  'Dersi düzenle': 'Edit lesson',
  'Dersi sil': 'Delete subject',
  'Haftalık çalışma programı': 'Weekly study schedule',
  'Hatırlatma isteğe bağlıdır; açık olan derslerin başlangıç saatinde bildirim gelir.': 'Reminders are optional; lessons with the switch on send a notification at their start time.',
  'Hazır dersler kaldırılır. Kendi kartların, notların ve ses kayıtların silinmez. İstediğin zaman yeniden yükleyebilirsin.': 'Built-in subjects are removed. Your own cards, notes and voice recordings are kept. You can reinstall any time.',
  'Hazır konular kaldırılır. Kendi kartların, notların ve ses kayıtların silinmez. İstediğin zaman yeniden yükleyebilirsin.': 'Built-in topics are removed. Your own cards, notes and voice recordings are kept. You can reinstall any time.',
  'Henüz alarm yok. Alarm ekle düğmesine bas.': 'No alarms yet. Tap Add alarm.',
  'Henüz başlatıcı yok.': 'No launchers yet.',
  'Henüz bilgi yok. Kart ekle düğmesiyle başla.': 'Nothing here yet. Start with the Add card button.',
  'Hepsini tekrar listesine ekle': 'Add all to review list',
  'Kayıt kalıcı olarak silinir.': 'The recording will be deleted permanently.',
  'Kendi kartın • tekrar listesinde': 'Your own card • in review list',
  'Konu özetleri ve kartlar yüklenir. İstediğin zaman dersleri silebilir ya da paketi yeniden yükleyebilirsin. Kendi kartların, notların ve ses kayıtların silinmez.': 'Topic summaries and cards will be installed. You can delete subjects or reinstall the package any time. Your own cards, notes and voice recordings are never deleted.',
  'Listeden çıkar': 'Remove from list',
  'Müzik, radyo ya da podcast durur': 'Music, radio or podcast stops',
  'Ne başlasın?': 'What should start?',
  'Not ekle': 'Add note',
  'Not silinsin mi?': 'Delete this note?',
  'Notlar': 'Notes',
  'Notu düzenle': 'Edit note',
  'Saati gelince bildirim gelir. Bildirime dokununca Daily Routine açılır ve seçtiğin şey başlar.': 'A notification arrives at the set time. Tap it and Daily Routine opens and starts what you chose.',
  'Sadece ses dursun': 'Only stop the sound',
  'Satır silinsin mi?': 'Delete this row?',
  'Ses dursun ve uygulama kapansın': 'Stop the sound and close the app',
  'Ses kayıtları': 'Voice recordings',
  'Ses kayıtları yedek dosyasına girmez; yalnız bu telefonda durur.': 'Voice recordings are not part of the backup file; they stay only on this phone.',
  'Süre': 'Duration',
  'Süre bitince ne olsun?': 'What happens when time is up?',
  'Süre bitince ses durur': 'Sound stops when time is up',
  'Süre bitince ses durur ve uygulama kapanır': 'Sound stops and the app closes when time is up',
  'Tekrar et': 'Review',
  'Tekrar listesi boş. Ders çalış bölümünde bir bilginin yanındaki Tekrar et düğmesine bas.': 'The review list is empty. In Study, tap Review next to a piece of information.',
  'Tekrar listesinde': 'In review list',
  'Uyku zamanlayıcısı': 'Sleep timer',
  'Yeni alarm': 'New alarm',
  'Yeni başlatıcı': 'New launcher',
  'Yeni not': 'New note',
  'Yükle': 'Install',
  'Zamanlama': 'Timing',
  'Zamanlayıcı uygulama açıkken ya da müzik arka planda çalarken işler. Son 10 saniyede ses yavaşça kısılır.': 'The timer runs while the app is open or music plays in the background. The sound fades out over the last 10 seconds.',
  'Zamanlayıcıyı iptal et': 'Cancel timer',
  'başlatmak için dokun': 'tap to start',
  '{0} bilgi • {1} tekrar listesinde': '{0} items • {1} in review list',
  '{0} ders saati': '{0} lessons',
  '{0} dersi silinsin mi?': 'Delete {0}?',
  '{0} dersini yükle': 'Install {0}',
  '{0} konu': '{0} topics',
  '{0} konu • {1} tekrar bekliyor': '{0} topics • {1} due for review',
  '{0} paketi silinsin mi?': 'Delete the {0} package?',
  '{0} paketi yüklü değil.': 'The {0} package is not installed.',
  '{0} paketini sil': 'Delete {0} package',
  '{0} paketini yükle': 'Install {0} package',
  '{0} paketini yükleyelim mi?': 'Shall we install the {0} package?',
  'Önce Müzik / Radyo / Podcast bölümünde bir şey ekle.': 'First add something in Music / Radio / Podcast.',
  'Şimdi değil': 'Not now',
  'Hava durumu sıcaklık tablosu yenilendi: kaynak adları bir kez en üstte, değerler alt alta; her değerin üstünde hava simgesi.': 'The weather temperature table was redesigned: source names appear once at the top, values are listed row by row, with a weather icon above each value.',
  'Meditasyon ve Nefes\'te nefes al/ver tınısı Tibet çanı sesi oldu.': 'The breath in/out tone in Meditation and Breath is now a Tibetan singing bowl sound.',
  'Rutini sağa çekince Hedef girilebiliyor ve Alt kategoriyi düzenle düğmesi çıkıyor.': 'Swipe a routine right to set its Goal; an Edit subcategory button is there too.',
  'Ders çalışma yenilendi: her derste Ders çalış ve Tekrar et. Ders çalış\'ta 8. sınıf konu özetleri (her bilgi ayrı, Tekrar et düğmesiyle tekrar listesine eklenir).': 'Study was redesigned: each subject has Study and Review. Study has 8th-grade topic summaries (each fact separate; the Review button adds it to your review list).',
  'Her konuda not yazabilir ve ses kaydı alabilirsin. LGS ve Yabancı dil paketleri isteğe bağlı yüklenir, dersler silinebilir.': 'You can write notes and record voice in every topic. LGS and Foreign language packages are optional and subjects can be deleted.',
  'Haftalık çalışma programı: gün + ders + saat aralığı, isteğe bağlı hatırlatma.': 'Weekly study schedule: day + subject + time range, with optional reminders.',
  'Araçlar\'a Zamanlama: Uyku zamanlayıcısı, Alarm ve Başlatıcı.': 'New Timing group in Tools: Sleep timer, Alarm and Launcher.',
  'Android sesin kadın mı erkek mi olduğunu bildirmez; dinleyerek seç.': 'Android doesn\'t tell whether a voice is female or male; choose by listening.',
  'Araçları tutup sürükle; grupları oklarla taşı.': 'Hold and drag the tools; move groups with the arrows.',
  'Aşağı': 'Down',
  'Yukarı': 'Up',
  'Çıkar': 'Remove',
  'Cevabı göster': 'Show answer',
  'Favoriden çıkarılsın mı?': 'Remove from favourites?',
  'Haber okuma': 'News reading',
  'Hava durumu: Günlük': 'Weather: Daily',
  'Hava durumu: Saatlik': 'Weather: Hourly',
  'Her kaynaktan kaç haber': 'News per source',
  'Okuma hızı: {0}x': 'Reading speed: {0}x',
  'Saat ve günlere göre çalar': 'Rings at set times and days',
  'Saati gelince seçtiğin şeyi başlat': 'Starts the chosen item at the set time',
  'Saatlik': 'Hourly',
  'Sağlık ve denge': 'Health and balance',
  'Ses ve hız': 'Voice and speed',
  'Ses {0}': 'Voice {0}',
  'Ses {0} ({1})': 'Voice {0} ({1})',
  'Sonraki haber': 'Next news',
  'Sonraki kaynak': 'Next source',
  'Önceki haber': 'Previous news',
  'Önceki kaynak': 'Previous source',
  'Süre bitince sesi durdur': 'Stop the sound when time is up',
  'Telefonda ek Türkçe ses bulunamadı. Ayarlar > Metin okuma bölümünden yeni ses indirebilirsin.': 'No extra Turkish voices found on the phone. You can download new voices in Settings > Text-to-speech.',
  'Tüm kaynaklar': 'All sources',
  'Varsayılan': 'Default',
  'Yer ekle': 'Add place',
  'Zaman ve sayaçlar': 'Time and counters',
  'erkek': 'male',
  'kadın': 'female',
  '{0} haber': '{0} news',
  'Şimdi {0}': 'Now: {0}',
  'Anlam bilgisi': 'Meaning',
  'Dil bilgisi': 'Grammar',
  'Yazım ve noktalama': 'Spelling and punctuation',
  'Anlatım ve metin': 'Expression and text',
  'Paragraf soruları ve okuma': 'Paragraph questions and reading',
  'Üniteler': 'Units',
  'Gramer ve kalıplar': 'Grammar and patterns',
  'Okuma parçaları · A1': 'Reading passages · A1',
  'Okuma parçaları · A2': 'Reading passages · A2',
  'Okuma parçaları · B1': 'Reading passages · B1',
  'Okuma parçaları · B2': 'Reading passages · B2',
  'Genel tekrar': 'General review',
  'LGS sınav dili': 'LGS exam language',
  'Diğer': 'Other',
  'Kendi konuların': 'Your own topics',
  'Kelime ve deyimler': 'Words and idioms',
  'Haber okuma: üstteki Oku düğmesi tüm kaynakları sırayla okur (her kaynaktan 3/5/10 haber); okuma hızı ve ses seçilebilir.': 'News reading: the Read button at the top reads all sources in order (3/5/10 items each); speed and voice are selectable.',
  'Direksiyon / kulaklık ileri-geri tuşları müzik, radyo, podcast ve haber okumada çalışacak şekilde düzenlendi (araca göre değişebilir).': 'Steering-wheel / headset next-previous buttons now work for music, radio, podcasts and news reading (may vary by car).',
  'Hava durumu: Saatlik ve Günlük ayrıldı; favori yerler üstte; günler siyah büyük başlık, çizgilerle ayrık.': 'Weather: Hourly and Daily are separate; favourite places on top; days have big black headings and separating lines.',
  'Araçlar gruplandı ve sıralanabilir; Uyku aracı menüden kalktı; Zamanlama tek kutuda.': 'Tools are grouped and reorderable; the Sleep tool left the menu; Timing is a single tile.',
  'LGS: dersler ünite ünite düzenlendi; İngilizce için Gramer ve kalıplar, 24 seviyeli okuma parçası; Türkçe için paragraf soru kalıpları ve 15 okuma parçası; Söz sanatları, Noktalama, Anlatım biçimleri, Yazı türleri.': 'LGS: subjects are organised unit by unit; English has Grammar and patterns and 24 leveled reading passages; Turkish has paragraph question patterns and 15 reading passages; Figures of speech, Punctuation, Modes of expression, Text types.',
};
