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
  'Üstteki “Daily” yazısına dokun, menüden bir alt kategori seç: günlük, haftalık ve aylık toplamlarını gör. Yapılacaklar listesi ve ayarlar da aynı menüde. Tüm verilerin sadece telefonunda saklanır.':
      'Tap “Daily” at the top, then pick a subcategory from the menu to see your daily, weekly and monthly totals. The to-do list and settings are in the same menu. All your data is stored only on your phone.',
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
};
