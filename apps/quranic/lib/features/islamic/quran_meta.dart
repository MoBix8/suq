/// Metadata for the 114 surahs of the Qur'an.
///
/// Page numbers follow the standard Madinah mushaf (604 pages) so they line up
/// with the printed page layout used by the reader.
class QuranChapter {
  const QuranChapter(
    this.number,
    this.nameSimple,
    this.nameArabic,
    this.meaning,
    this.startPage,
    this.endPage,
    this.verseCount,
  );

  final int number;
  final String nameSimple;
  final String nameArabic;
  final String meaning;
  final int startPage;
  final int endPage;
  final int verseCount;

  bool containsPage(int page) => page >= startPage && page <= endPage;

  /// Whether a separate bismillah line is printed above this surah.
  ///
  /// Al-Fatihah's bismillah is its first verse, and At-Tawbah has none.
  bool get hasBismillah => number != 1 && number != 9;
}

/// Total number of pages in the Madinah mushaf.
const quranPageCount = 604;

/// SharedPreferences key that remembers the last page the shop opened.
const quranLastPageKey = 'quran.lastPage';

/// SharedPreferences key for the chosen reciter.
const quranReciterKey = 'quran.reciterId';

/// SharedPreferences key for the chosen translation.
const quranTranslationKey = 'quran.translationId';

/// SharedPreferences key for the chosen Arabic tafsir.
const quranTafsirKey = 'quran.tafsirId';

/// SharedPreferences key for page vs list reading mode.
const quranViewModeKey = 'quran.viewMode';

/// SharedPreferences key for the shop's page bookmarks.
const quranBookmarksKey = 'quran.bookmarks';

/// How the reader presents a mushaf page.
enum QuranViewMode {
  page('page'),
  list('list');

  const QuranViewMode(this.value);

  final String value;

  static QuranViewMode fromValue(String? value) {
    for (final mode in QuranViewMode.values) {
      if (mode.value == value) return mode;
    }
    return QuranViewMode.page;
  }
}

const quranChapters = <QuranChapter>[
  QuranChapter(1, 'Al-Fatihah', 'الفاتحة', 'The Opener', 1, 1, 7),
  QuranChapter(2, 'Al-Baqarah', 'البقرة', 'The Cow', 2, 49, 286),
  QuranChapter(3, 'Ali \'Imran', 'آل عمران', 'Family of Imran', 50, 76, 200),
  QuranChapter(4, 'An-Nisa', 'النساء', 'The Women', 77, 106, 176),
  QuranChapter(5, 'Al-Ma\'idah', 'المائدة', 'The Table Spread', 106, 127, 120),
  QuranChapter(6, 'Al-An\'am', 'الأنعام', 'The Cattle', 128, 150, 165),
  QuranChapter(7, 'Al-A\'raf', 'الأعراف', 'The Heights', 151, 176, 206),
  QuranChapter(8, 'Al-Anfal', 'الأنفال', 'The Spoils of War', 177, 186, 75),
  QuranChapter(9, 'At-Tawbah', 'التوبة', 'The Repentance', 187, 207, 129),
  QuranChapter(10, 'Yunus', 'يونس', 'Jonah', 208, 221, 109),
  QuranChapter(11, 'Hud', 'هود', 'Hud', 221, 235, 123),
  QuranChapter(12, 'Yusuf', 'يوسف', 'Joseph', 235, 248, 111),
  QuranChapter(13, 'Ar-Ra\'d', 'الرعد', 'The Thunder', 249, 255, 43),
  QuranChapter(14, 'Ibrahim', 'ابراهيم', 'Abraham', 255, 261, 52),
  QuranChapter(15, 'Al-Hijr', 'الحجر', 'The Rocky Tract', 262, 267, 99),
  QuranChapter(16, 'An-Nahl', 'النحل', 'The Bee', 267, 281, 128),
  QuranChapter(17, 'Al-Isra', 'الإسراء', 'The Night Journey', 282, 293, 111),
  QuranChapter(18, 'Al-Kahf', 'الكهف', 'The Cave', 293, 304, 110),
  QuranChapter(19, 'Maryam', 'مريم', 'Mary', 305, 312, 98),
  QuranChapter(20, 'Taha', 'طه', 'Ta-Ha', 312, 321, 135),
  QuranChapter(21, 'Al-Anbya', 'الأنبياء', 'The Prophets', 322, 331, 112),
  QuranChapter(22, 'Al-Hajj', 'الحج', 'The Pilgrimage', 332, 341, 78),
  QuranChapter(23, 'Al-Mu\'minun', 'المؤمنون', 'The Believers', 342, 349, 118),
  QuranChapter(24, 'An-Nur', 'النور', 'The Light', 350, 359, 64),
  QuranChapter(25, 'Al-Furqan', 'الفرقان', 'The Criterion', 359, 366, 77),
  QuranChapter(26, 'Ash-Shu\'ara', 'الشعراء', 'The Poets', 367, 376, 227),
  QuranChapter(27, 'An-Naml', 'النمل', 'The Ant', 377, 385, 93),
  QuranChapter(28, 'Al-Qasas', 'القصص', 'The Stories', 385, 396, 88),
  QuranChapter(29, 'Al-\'Ankabut', 'العنكبوت', 'The Spider', 396, 404, 69),
  QuranChapter(30, 'Ar-Rum', 'الروم', 'The Romans', 404, 410, 60),
  QuranChapter(31, 'Luqman', 'لقمان', 'Luqman', 411, 414, 34),
  QuranChapter(32, 'As-Sajdah', 'السجدة', 'The Prostration', 415, 417, 30),
  QuranChapter(33, 'Al-Ahzab', 'الأحزاب', 'The Combined Forces', 418, 427, 73),
  QuranChapter(34, 'Saba', 'سبأ', 'Sheba', 428, 434, 54),
  QuranChapter(35, 'Fatir', 'فاطر', 'Originator', 434, 440, 45),
  QuranChapter(36, 'Ya-Sin', 'يس', 'Ya Sin', 440, 445, 83),
  QuranChapter(37, 'As-Saffat', 'الصافات', 'Those who set the Ranks', 446, 452, 182),
  QuranChapter(38, 'Sad', 'ص', 'The Letter "Saad"', 453, 458, 88),
  QuranChapter(39, 'Az-Zumar', 'الزمر', 'The Troops', 458, 467, 75),
  QuranChapter(40, 'Ghafir', 'غافر', 'The Forgiver', 467, 476, 85),
  QuranChapter(41, 'Fussilat', 'فصلت', 'Explained in Detail', 477, 482, 54),
  QuranChapter(42, 'Ash-Shuraa', 'الشورى', 'The Consultation', 483, 489, 53),
  QuranChapter(43, 'Az-Zukhruf', 'الزخرف', 'The Ornaments of Gold', 489, 495, 89),
  QuranChapter(44, 'Ad-Dukhan', 'الدخان', 'The Smoke', 496, 498, 59),
  QuranChapter(45, 'Al-Jathiyah', 'الجاثية', 'The Crouching', 499, 502, 37),
  QuranChapter(46, 'Al-Ahqaf', 'الأحقاف', 'The Wind-Curved Sandhills', 502, 506, 35),
  QuranChapter(47, 'Muhammad', 'محمد', 'Muhammad', 507, 510, 38),
  QuranChapter(48, 'Al-Fath', 'الفتح', 'The Victory', 511, 515, 29),
  QuranChapter(49, 'Al-Hujurat', 'الحجرات', 'The Rooms', 515, 517, 18),
  QuranChapter(50, 'Qaf', 'ق', 'The Letter "Qaf"', 518, 520, 45),
  QuranChapter(51, 'Adh-Dhariyat', 'الذاريات', 'The Winnowing Winds', 520, 523, 60),
  QuranChapter(52, 'At-Tur', 'الطور', 'The Mount', 523, 525, 49),
  QuranChapter(53, 'An-Najm', 'النجم', 'The Star', 526, 528, 62),
  QuranChapter(54, 'Al-Qamar', 'القمر', 'The Moon', 528, 531, 55),
  QuranChapter(55, 'Ar-Rahman', 'الرحمن', 'The Beneficent', 531, 534, 78),
  QuranChapter(56, 'Al-Waqi\'ah', 'الواقعة', 'The Inevitable', 534, 537, 96),
  QuranChapter(57, 'Al-Hadid', 'الحديد', 'The Iron', 537, 541, 29),
  QuranChapter(58, 'Al-Mujadila', 'المجادلة', 'The Pleading Woman', 542, 545, 22),
  QuranChapter(59, 'Al-Hashr', 'الحشر', 'The Exile', 545, 548, 24),
  QuranChapter(60, 'Al-Mumtahanah', 'الممتحنة', 'She that is to be examined', 549, 551, 13),
  QuranChapter(61, 'As-Saf', 'الصف', 'The Ranks', 551, 552, 14),
  QuranChapter(62, 'Al-Jumu\'ah', 'الجمعة', 'The Congregation, Friday', 553, 554, 11),
  QuranChapter(63, 'Al-Munafiqun', 'المنافقون', 'The Hypocrites', 554, 555, 11),
  QuranChapter(64, 'At-Taghabun', 'التغابن', 'The Mutual Disillusion', 556, 557, 18),
  QuranChapter(65, 'At-Talaq', 'الطلاق', 'The Divorce', 558, 559, 12),
  QuranChapter(66, 'At-Tahrim', 'التحريم', 'The Prohibition', 560, 561, 12),
  QuranChapter(67, 'Al-Mulk', 'الملك', 'The Sovereignty', 562, 564, 30),
  QuranChapter(68, 'Al-Qalam', 'القلم', 'The Pen', 564, 566, 52),
  QuranChapter(69, 'Al-Haqqah', 'الحاقة', 'The Reality', 566, 568, 52),
  QuranChapter(70, 'Al-Ma\'arij', 'المعارج', 'The Ascending Stairways', 568, 570, 44),
  QuranChapter(71, 'Nuh', 'نوح', 'Noah', 570, 571, 28),
  QuranChapter(72, 'Al-Jinn', 'الجن', 'The Jinn', 572, 573, 28),
  QuranChapter(73, 'Al-Muzzammil', 'المزمل', 'The Enshrouded One', 574, 575, 20),
  QuranChapter(74, 'Al-Muddaththir', 'المدثر', 'The Cloaked One', 575, 577, 56),
  QuranChapter(75, 'Al-Qiyamah', 'القيامة', 'The Resurrection', 577, 578, 40),
  QuranChapter(76, 'Al-Insan', 'الانسان', 'The Man', 578, 580, 31),
  QuranChapter(77, 'Al-Mursalat', 'المرسلات', 'The Emissaries', 580, 581, 50),
  QuranChapter(78, 'An-Naba', 'النبإ', 'The Tidings', 582, 583, 40),
  QuranChapter(79, 'An-Nazi\'at', 'النازعات', 'Those who drag forth', 583, 584, 46),
  QuranChapter(80, '\'Abasa', 'عبس', 'He Frowned', 585, 585, 42),
  QuranChapter(81, 'At-Takwir', 'التكوير', 'The Overthrowing', 586, 586, 29),
  QuranChapter(82, 'Al-Infitar', 'الإنفطار', 'The Cleaving', 587, 587, 19),
  QuranChapter(83, 'Al-Mutaffifin', 'المطففين', 'The Defrauding', 587, 589, 36),
  QuranChapter(84, 'Al-Inshiqaq', 'الإنشقاق', 'The Sundering', 589, 589, 25),
  QuranChapter(85, 'Al-Buruj', 'البروج', 'The Mansions of the Stars', 590, 590, 22),
  QuranChapter(86, 'At-Tariq', 'الطارق', 'The Nightcommer', 591, 591, 17),
  QuranChapter(87, 'Al-A\'la', 'الأعلى', 'The Most High', 591, 592, 19),
  QuranChapter(88, 'Al-Ghashiyah', 'الغاشية', 'The Overwhelming', 592, 592, 26),
  QuranChapter(89, 'Al-Fajr', 'الفجر', 'The Dawn', 593, 594, 30),
  QuranChapter(90, 'Al-Balad', 'البلد', 'The City', 594, 594, 20),
  QuranChapter(91, 'Ash-Shams', 'الشمس', 'The Sun', 595, 595, 15),
  QuranChapter(92, 'Al-Layl', 'الليل', 'The Night', 595, 596, 21),
  QuranChapter(93, 'Ad-Duhaa', 'الضحى', 'The Morning Hours', 596, 596, 11),
  QuranChapter(94, 'Ash-Sharh', 'الشرح', 'The Relief', 596, 596, 8),
  QuranChapter(95, 'At-Tin', 'التين', 'The Fig', 597, 597, 8),
  QuranChapter(96, 'Al-\'Alaq', 'العلق', 'The Clot', 597, 597, 19),
  QuranChapter(97, 'Al-Qadr', 'القدر', 'The Power', 598, 598, 5),
  QuranChapter(98, 'Al-Bayyinah', 'البينة', 'The Clear Proof', 598, 599, 8),
  QuranChapter(99, 'Az-Zalzalah', 'الزلزلة', 'The Earthquake', 599, 599, 8),
  QuranChapter(100, 'Al-\'Adiyat', 'العاديات', 'The Courser', 599, 600, 11),
  QuranChapter(101, 'Al-Qari\'ah', 'القارعة', 'The Calamity', 600, 600, 11),
  QuranChapter(102, 'At-Takathur', 'التكاثر', 'The Rivalry in world increase', 600, 600, 8),
  QuranChapter(103, 'Al-\'Asr', 'العصر', 'The Declining Day', 601, 601, 3),
  QuranChapter(104, 'Al-Humazah', 'الهمزة', 'The Traducer', 601, 601, 9),
  QuranChapter(105, 'Al-Fil', 'الفيل', 'The Elephant', 601, 601, 5),
  QuranChapter(106, 'Quraysh', 'قريش', 'Quraysh', 602, 602, 4),
  QuranChapter(107, 'Al-Ma\'un', 'الماعون', 'The Small kindnesses', 602, 602, 7),
  QuranChapter(108, 'Al-Kawthar', 'الكوثر', 'The Abundance', 602, 602, 3),
  QuranChapter(109, 'Al-Kafirun', 'الكافرون', 'The Disbelievers', 603, 603, 6),
  QuranChapter(110, 'An-Nasr', 'النصر', 'The Divine Support', 603, 603, 3),
  QuranChapter(111, 'Al-Masad', 'المسد', 'The Palm Fiber', 603, 603, 5),
  QuranChapter(112, 'Al-Ikhlas', 'الإخلاص', 'The Sincerity', 604, 604, 4),
  QuranChapter(113, 'Al-Falaq', 'الفلق', 'The Daybreak', 604, 604, 5),
  QuranChapter(114, 'An-Nas', 'الناس', 'Mankind', 604, 604, 6),
];

/// The surah to show in the reader header for [page].
///
/// A page that starts with the end of the previous surah is still that surah's
/// page: the reader opens at the top of the page, where those verses are
/// printed. So a surah that began on an earlier page wins over one that only
/// starts at the bottom of this page (for example page 106 is the end of
/// An-Nisa, not the start of Al-Ma'idah). Pages where several surahs begin,
/// like the last page of the mushaf, keep the earliest of them.
QuranChapter quranChapterForPage(int page) {
  QuranChapter? spanning;
  QuranChapter? starting;
  for (final chapter in quranChapters) {
    if (chapter.startPage < page && chapter.containsPage(page)) {
      spanning ??= chapter;
    } else if (chapter.startPage == page) {
      starting ??= chapter;
    }
  }
  return spanning ?? starting ?? quranChapters.first;
}

/// The surah with [number] (1–114).
QuranChapter quranChapterByNumber(int number) {
  final index = number - 1;
  if (index < 0 || index >= quranChapters.length) return quranChapters.first;
  return quranChapters[index];
}
