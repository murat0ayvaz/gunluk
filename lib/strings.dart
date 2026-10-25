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
  'Sağ alttaki DR düğmesine dokun; kategori ve alt kategori seç, “Rutin olsun” anahtarını aç ve günlük hedefini yaz. Hedefe ulaşınca satır yeşile döner. Satırı sola kaydırarak o günün verisini sil, sağa kaydırarak düzenle; 2 saniye basılı tutarak sırala. Boş yere sağa veya sola kaydırarak günler arasında geçebilirsin.':
      'Tap the DR button at the bottom right; pick a category and subcategory, turn on “Make it a routine” and enter your daily goal. The row turns green when you reach it. Swipe a row left to delete the entry for that day, right to edit it; press and hold for 2 seconds to reorder. Swipe left or right on an empty spot to move between days.',
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
  'Ekle için sağ alttaki DR düğmesine dokun.':
      'Tap the DR button at the bottom right to add.',
  'Bir satırı sağa kaydırınca düzenlenir, sola kaydırınca o günün verisi silinir.':
      'Swipe a row right to edit it, swipe left to delete that day’s entry.',
  'Satıra 2 saniye basılı tutarak rutinlerini sıralayabilirsin.':
      'Press and hold a row for 2 seconds to reorder your routines.',
  'Boş yere sağa veya sola kaydırarak günler arasında geçebilirsin.':
      'Swipe left or right on an empty spot to move between days.',
  'En alttaki Günlük başlığına dokunup günün notunu yazabilirsin.':
      'Tap the Diary title at the bottom to write the note of the day.',
  'Yapılacaklar listesi ekranın altında; dokununca yukarı doğru tüm ekrana açılır.':
      'The to-do list is at the bottom of the screen; tap it to open it to full screen.',
  'Soldaki menüden kategorilerin istatistiklerine ulaşabilirsin.':
      'Use the left menu to see statistics for your categories.',
  'Soldaki menüde Günlük’e dokunarak notlarını takvimden görebilirsin.':
      'Tap Diary in the left menu to see your notes on a calendar.',
  'Rutin oluştururken hangi günlerde görüneceğini seçebilirsin.':
      'When you create a routine you can choose the days it appears on.',
  'Ayarlar’dan tema, dil ve özlü sözleri değiştirebilirsin.':
      'You can change the theme, language and quotes in Settings.',
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
  'Rutinler artık sadece seçtiğin günlerde görünebilir (örneğin yalnızca Salı ve Perşembe).':
      'Routines can now appear only on the days you choose (for example only Tuesday and Thursday).',
  'Soldaki menüde Günlük: notu olan günler takvimde işaretli, tarihe basınca o günün notu görünür.':
      'Diary in the left menu: days with a note are marked on the calendar; tap a date to see that day’s note.',
  'Yeni açılış ekranı ve kurulum sayfaları; geri tuşunda çıkış onayı.':
      'New launch screen and intro pages; exit confirmation on the back button.',
  'Üstteki “Daily” yazısına dokun: soldaki menüde kategori istatistiklerini ve notu olan günlerin takvimini (Günlük) görürsün. Yapılacaklar ve Günlük ekranın altında; ayarlar menünün içinde. Tüm verilerin sadece telefonunda saklanır.':
      'Tap “Daily” at the top: in the left menu you will find your category statistics and a calendar of the days that have a note (Diary). To-do and Diary are at the bottom of the screen; settings are inside the menu. All your data is stored only on your phone.',
};
