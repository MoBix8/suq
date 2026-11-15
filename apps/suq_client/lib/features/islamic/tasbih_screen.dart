import 'dart:async';
import 'dart:math' as math;
import 'dart:ui';

import 'package:audioplayers/audioplayers.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/theme.dart';
import '../../providers.dart';

class _Dhikr {
  const _Dhikr({
    required this.category,
    required this.arabic,
    required this.amharic,
    required this.english,
    required this.target,
  });

  final String category;
  final String arabic;
  final String amharic;
  final String english;
  final int target;
}

/// Order in which categories appear in the bottom sheet.
const _dhikrCategories = <String>[
  'After prayer',
  'Tahlil & Tawhid',
  'Istighfar',
  'Tasbih & Tahmid',
  'Salawat',
  'Morning & evening',
  'Duas',
  'Names of Allah',
];

// NOTE: the first 10 entries keep their original positions so a previously
// saved selection still points to the same dhikr. Append new ones at the end.
const _dhikrs = <_Dhikr>[
  _Dhikr(category: 'After prayer', arabic: 'سُبْحَانَ ٱللَّٰهِ', amharic: 'ሱብሃና አላህ', english: 'Glory be to Allah', target: 33),
  _Dhikr(category: 'After prayer', arabic: 'ٱلْحَمْدُ لِلَّٰهِ', amharic: 'አልሃምዱሊላህ', english: 'All praise is due to Allah', target: 33),
  _Dhikr(category: 'After prayer', arabic: 'ٱللَّٰهُ أَكْبَرُ', amharic: 'አላሁ አክበር', english: 'Allah is the Greatest', target: 34),
  _Dhikr(category: 'Tahlil & Tawhid', arabic: 'لَا إِلَٰهَ إِلَّا ٱللَّٰهُ', amharic: 'ላ ኢላሃ ኢላ አላህ', english: 'There is no god but Allah', target: 100),
  _Dhikr(category: 'Istighfar', arabic: 'أَسْتَغْفِرُ ٱللَّٰهَ', amharic: 'አስታግፊሩላህ', english: 'I seek forgiveness from Allah', target: 100),
  _Dhikr(category: 'Tasbih & Tahmid', arabic: 'سُبْحَانَ ٱللَّٰهِ وَبِحَمْدِهِ', amharic: 'ሱብሃና አላህ ወቢሃምዲሂ', english: 'Glory and praise be to Allah', target: 100),
  _Dhikr(category: 'Tasbih & Tahmid', arabic: 'سُبْحَانَ ٱللَّٰهِ ٱلْعَظِيمِ', amharic: 'ሱብሃና አላህ አልዓዚም', english: 'Glory be to Allah, the Magnificent', target: 100),
  _Dhikr(category: 'Duas', arabic: 'حَسْبُنَا ٱللَّٰهُ وَنِعْمَ ٱلْوَكِيلُ', amharic: 'ሐስቡና አላህ ወኒዕማ አልወኪል', english: 'Allah is sufficient for us', target: 7),
  _Dhikr(category: 'Salawat', arabic: 'اللَّهُمَّ صَلِّ عَلَىٰ مُحَمَّدٍ', amharic: 'አላሁማ ሰሊ ዓላ ሙሐመድ', english: 'O Allah, send blessings upon Muhammad', target: 100),
  _Dhikr(category: 'Tasbih & Tahmid', arabic: 'لَا حَوْلَ وَلَا قُوَّةَ إِلَّا بِٱللَّٰهِ', amharic: 'ላ ሐውላ ወላ ቁወተ ኢላ ቢአላህ', english: 'There is no power except with Allah', target: 100),

  // ---- Tahlil & Tawhid ----
  _Dhikr(category: 'Tahlil & Tawhid', arabic: 'لَا إِلَٰهَ إِلَّا ٱللَّٰهُ وَحْدَهُ لَا شَرِيكَ لَهُ، لَهُ ٱلْمُلْكُ وَلَهُ ٱلْحَمْدُ وَهُوَ عَلَىٰ كُلِّ شَيْءٍ قَدِيرٌ', amharic: 'ላ ኢላሃ ኢልለላሁ ወሕደሁ ላ ሸሪከ ለሁ፣ ለሁል ሙልኩ ወለሁል ሐምዱ ወሁወ ዓላ ኩሊ ሸይኢን ቀዲር', english: 'There is no god but Allah alone, without partner. His is the dominion and the praise, and He has power over all things', target: 100),
  _Dhikr(category: 'Tahlil & Tawhid', arabic: 'لَا إِلَٰهَ إِلَّا ٱللَّٰهُ مُحَمَّدٌ رَسُولُ ٱللَّٰهِ', amharic: 'ላ ኢላሃ ኢላ አላህ ሙሐመዱን ረሱሉላህ', english: 'There is no god but Allah, Muhammad is the Messenger of Allah', target: 100),
  _Dhikr(category: 'Tahlil & Tawhid', arabic: 'لَا إِلَٰهَ إِلَّا أَنْتَ سُبْحَانَكَ إِنِّي كُنْتُ مِنَ ٱلظَّالِمِينَ', amharic: 'ላ ኢላሃ ኢላ አንተ ሱብሃነከ ኢኒ ኩንቱ ሚነዝ ዟሊሚን', english: 'There is no god but You, glory be to You; I was among the wrongdoers (Dua of Yunus)', target: 100),

  // ---- Istighfar ----
  _Dhikr(category: 'Istighfar', arabic: 'أَسْتَغْفِرُ ٱللَّٰهَ وَأَتُوبُ إِلَيْهِ', amharic: 'አስተግፊሩላሃ ወአቱቡ ኢለይሂ', english: 'I seek forgiveness from Allah and repent to Him', target: 100),
  _Dhikr(category: 'Istighfar', arabic: 'رَبِّ ٱغْفِرْ لِي وَتُبْ عَلَيَّ إِنَّكَ أَنْتَ ٱلتَّوَّابُ ٱلرَّحِيمُ', amharic: 'ረቢግፊር ሊ ወቱብ ዐለይየ ኢነከ አንተት ተዋቡር ረሒም', english: 'My Lord, forgive me and accept my repentance; You are the Accepting, the Merciful', target: 100),
  _Dhikr(category: 'Istighfar', arabic: 'أَسْتَغْفِرُ ٱللَّٰهَ ٱلْعَظِيمَ ٱلَّذِي لَا إِلَٰهَ إِلَّا هُوَ ٱلْحَيَّ ٱلْقَيُّومَ وَأَتُوبُ إِلَيْهِ', amharic: 'አስተግፊሩላሀል ዐዚም አለዚ ላ ኢላሃ ኢላ ሁወል ሐየል ቀዩም ወአቱቡ ኢለይሂ', english: 'I seek forgiveness from Allah the Mighty, besides whom there is no god, the Ever-Living, the Sustainer, and I repent to Him', target: 3),

  // ---- Tasbih & Tahmid ----
  _Dhikr(category: 'Tasbih & Tahmid', arabic: 'سُبْحَانَ ٱللَّٰهِ وَبِحَمْدِهِ سُبْحَانَ ٱللَّٰهِ ٱلْعَظِيمِ', amharic: 'ሱብሃናላሂ ወቢሃምዲሂ ሱብሃናላሂል ዐዚም', english: 'Glory and praise be to Allah, glory be to Allah the Magnificent', target: 100),
  _Dhikr(category: 'Tasbih & Tahmid', arabic: 'سُبْحَانَ ٱللَّٰهِ وَٱلْحَمْدُ لِلَّٰهِ وَلَا إِلَٰهَ إِلَّا ٱللَّٰهُ وَٱللَّٰهُ أَكْبَرُ', amharic: 'ሱብሃኒላሂ ወልሐምዱ ሊላሂ ወላ ኢላሃ ኢልለላሁ ወላሁ አክበር', english: 'Glory be to Allah, praise be to Allah, there is no god but Allah, and Allah is the Greatest', target: 100),
  _Dhikr(category: 'Tasbih & Tahmid', arabic: 'سُبْحَانَ ٱللَّٰهِ وَبِحَمْدِهِ عَدَدَ خَلْقِهِ وَرِضَا نَفْسِهِ وَزِنَةَ عَرْشِهِ وَمِدَادَ كَلِمَاتِهِ', amharic: 'ሱብሃናላሂ ወቢሃምዲሂ ዐደደ ኸልቂሂ ወሪዷ ነፍሲሂ ወዚነተ ዐርሺሂ ወሚዳደ ከሊማቲሂ', english: 'Glory and praise be to Allah as many as His creation, as pleases Him, as heavy as His Throne, and as the ink of His words', target: 3),
  _Dhikr(category: 'Tasbih & Tahmid', arabic: 'ٱللَّٰهُ أَكْبَرُ كَبِيرًا وَٱلْحَمْدُ لِلَّٰهِ كَثِيرًا وَسُبْحَانَ ٱللَّٰهِ بُكْرَةً وَأَصِيلًا', amharic: 'አላሁ አክበር ከቢራ ወልሐምዱ ሊላሂ ከሲራ ወሱብሃናላሂ ቡክረተን ወአሲላ', english: 'Allah is the Greatest, abundantly; praise be to Allah, abundantly; glory be to Allah morning and evening', target: 3),
  _Dhikr(category: 'Tasbih & Tahmid', arabic: 'ٱلْحَمْدُ لِلَّٰهِ رَبِّ ٱلْعَالَمِينَ', amharic: 'አልሐምዱ ሊላሂ ረቢል ዐለሚን', english: 'All praise is due to Allah, Lord of the worlds', target: 100),
  _Dhikr(category: 'Tasbih & Tahmid', arabic: 'مَا شَاءَ ٱللَّٰهُ لَا قُوَّةَ إِلَّا بِٱللَّٰهِ', amharic: 'ማሻአላህ ላ ቁወተ ኢላ ቢላህ', english: 'What Allah wills; there is no power except with Allah', target: 100),

  // ---- Salawat ----
  _Dhikr(category: 'Salawat', arabic: 'صَلَّىٰ ٱللَّٰهُ عَلَيْهِ وَسَلَّمَ', amharic: 'ሰለላሁ ዐለይሂ ወሰለም', english: 'May Allah send blessings and peace upon him', target: 100),
  _Dhikr(category: 'Salawat', arabic: 'ٱللَّٰهُمَّ صَلِّ وَسَلِّمْ عَلَىٰ نَبِيِّنَا مُحَمَّدٍ', amharic: 'አላሁማ ሰሊ ወሰሊም ዐላ ነቢዪና ሙሐመድ', english: 'O Allah, send blessings and peace upon our Prophet Muhammad', target: 100),

  // ---- Morning & evening ----
  _Dhikr(category: 'Morning & evening', arabic: 'حَسْبِيَ ٱللَّٰهُ لَا إِلَٰهَ إِلَّا هُوَ عَلَيْهِ تَوَكَّلْتُ وَهُوَ رَبُّ ٱلْعَرْشِ ٱلْعَظِيمِ', amharic: 'ሐስቢየላሁ ላ ኢላሃ ኢላ ሁወ ዐለይሂ ተወክልቱ ወሁወ ረቡል ዐርሺል ዐዚም', english: 'Allah is enough for me; there is no god but Him. In Him I trust, and He is Lord of the Mighty Throne', target: 7),
  _Dhikr(category: 'Morning & evening', arabic: 'بِسْمِ ٱللَّٰهِ ٱلَّذِي لَا يَضُرُّ مَعَ ٱسْمِهِ شَيْءٌ فِي ٱلْأَرْضِ وَلَا فِي ٱلسَّمَاءِ وَهُوَ ٱلسَّمِيعُ ٱلْعَلِيمُ', amharic: 'ቢስሚላሂ ለዚ ላ የዱሩ መዐ ኢስሚሂ ሸይኡን ፊል አርዲ ወላ ፊስ ሰማኢ ወሁወ ሰሚዑል ዐሊም', english: 'In the name of Allah, with whose name nothing on earth or in heaven can cause harm; He is the All-Hearing, All-Knowing', target: 3),
  _Dhikr(category: 'Morning & evening', arabic: 'أَعُوذُ بِكَلِمَاتِ ٱللَّٰهِ ٱلتَّامَّاتِ مِنْ شَرِّ مَا خَلَقَ', amharic: 'አዑዙ ቢከሊማቲላሂት ታማቲ ሚን ሸሪ ማ ኸለቅ', english: 'I seek refuge in the perfect words of Allah from the evil of what He created', target: 3),
  _Dhikr(category: 'Morning & evening', arabic: 'رَضِيتُ بِٱللَّٰهِ رَبًّا وَبِٱلْإِسْلَامِ دِينًا وَبِمُحَمَّدٍ نَبِيًّا', amharic: 'ረዲቱ ቢላሂ ረባን ወቢልኢስላሚ ዲናን ወቢሙሐመዲን ነቢያ', english: 'I am pleased with Allah as Lord, Islam as religion, and Muhammad as Prophet', target: 3),

  // ---- Duas ----
  _Dhikr(category: 'Duas', arabic: 'ٱللَّٰهُمَّ إِنَّكَ عَفُوٌّ تُحِبُّ ٱلْعَفْوَ فَٱعْفُ عَنِّي', amharic: 'አላሁማ ኢነከ ዐፉውን ቱሒቡል ዐፍወ ፈዕፉ ዐኒ', english: 'O Allah, You are the Pardoner and love to pardon, so pardon me', target: 100),
  _Dhikr(category: 'Duas', arabic: 'رَبَّنَا آتِنَا فِي ٱلدُّنْيَا حَسَنَةً وَفِي ٱلْآخِرَةِ حَسَنَةً وَقِنَا عَذَابَ ٱلنَّارِ', amharic: 'ረቢና አቲና ፊድ ዱንያ ሐሰነተን ወፊል አኺረቲ ሐሰነተን ወቂና ዐዛበን ናር', english: 'Our Lord, give us good in this world and good in the Hereafter, and protect us from the Fire', target: 100),
  _Dhikr(category: 'Duas', arabic: 'يَا مُقَلِّبَ ٱلْقُلُوبِ ثَبِّتْ قَلْبِي عَلَىٰ دِينِكَ', amharic: 'ያ ሙቀሊበል ቁሉቢ ሰቢት ቀልቢ ዐላ ዲኒከ', english: 'O Turner of hearts, keep my heart firm upon Your religion', target: 100),
  _Dhikr(category: 'Duas', arabic: 'رَبِّ زِدْنِي عِلْمًا', amharic: 'ረቢ ዚድኒ ዒልማ', english: 'My Lord, increase me in knowledge', target: 100),
  _Dhikr(category: 'Duas', arabic: 'رَبِّ ٱشْرَحْ لِي صَدْرِي وَيَسِّرْ لِي أَمْرِي', amharic: 'ረቢሽረሕ ሊ ሰድሪ ወየሲር ሊ አምሪ', english: 'My Lord, expand my chest and ease my task for me', target: 100),
  _Dhikr(category: 'Duas', arabic: 'إِنَّا لِلَّٰهِ وَإِنَّا إِلَيْهِ رَاجِعُونَ', amharic: 'ኢና ሊላሂ ወኢና ኢለይሂ ራጂዑን', english: 'Indeed we belong to Allah, and to Him we shall return', target: 100),
  _Dhikr(category: 'Duas', arabic: 'ٱللَّٰهُمَّ أَعِنِّي عَلَىٰ ذِكْرِكَ وَشُكْرِكَ وَحُسْنِ عِبَادَتِكَ', amharic: 'አላሁማ ኣዒኒ ዐላ ዚክሪከ ወሹክሪከ ወሑስኒ ዒባደቲከ', english: 'O Allah, help me to remember You, thank You, and worship You well', target: 33),
  _Dhikr(category: 'Duas', arabic: 'تَوَكَّلْتُ عَلَى ٱللَّٰهِ', amharic: 'ተወክልቱ ዐለላህ', english: 'I put my trust in Allah', target: 100),

  // ---- Names of Allah ----
  _Dhikr(category: 'Names of Allah', arabic: 'يَا ٱللَّٰهُ', amharic: 'ያ አላህ', english: 'O Allah', target: 100),
  _Dhikr(category: 'Names of Allah', arabic: 'يَا رَحْمَٰنُ يَا رَحِيمُ', amharic: 'ያ ረሕማን ያ ረሒም', english: 'O Most Gracious, O Most Merciful', target: 100),
  _Dhikr(category: 'Names of Allah', arabic: 'يَا غَفَّارُ', amharic: 'ያ ገፋር', english: 'O Oft-Forgiving', target: 100),
  _Dhikr(category: 'Names of Allah', arabic: 'يَا رَزَّاقُ', amharic: 'ያ ረዛቅ', english: 'O Provider', target: 100),
  _Dhikr(category: 'Names of Allah', arabic: 'يَا فَتَّاحُ', amharic: 'ያ ፈታሕ', english: 'O Opener of all good', target: 100),
  _Dhikr(category: 'Names of Allah', arabic: 'يَا لَطِيفُ', amharic: 'ያ ለጢፍ', english: 'O Most Gentle, the Subtle', target: 100),
  _Dhikr(category: 'Names of Allah', arabic: 'يَا حَيُّ يَا قَيُّومُ بِرَحْمَتِكَ أَسْتَغِيثُ', amharic: 'ያ ሐዩ ያ ቀዩም ቢረሕመቲከ አስተጊስ', english: 'O Ever-Living, O Sustainer, in Your mercy I seek relief', target: 100),
];

class TasbihScreen extends ConsumerStatefulWidget {
  const TasbihScreen({super.key});

  @override
  ConsumerState<TasbihScreen> createState() => _TasbihScreenState();
}

class _TasbihScreenState extends ConsumerState<TasbihScreen>
    with SingleTickerProviderStateMixin {
  static const _indexKey = 'tasbih.index';
  static const _countKey = 'tasbih.count';
  static const _soundKey = 'tasbih.sound';
  static const _vibrateKey = 'tasbih.vibrate';
  static const _colorKey = 'tasbih.color';

  int _index = 0;
  int _count = 0;
  bool _sound = true;
  bool _vibrate = true;
  bool _collapsed = false;

  int _colorIndex = 0;
  final List<Color> _colors = const [
    Color(0xFF8B5A2B),
    Color(0xFF3E2723),
    Color(0xFF5D4037),
    Color(0xFFD4AF37),
    Color(0xFF9E9E9E),
    Color(0xFF1B5E20),
  ];

  final FlutterTts _tts = FlutterTts();

  // Bead "clack" sounds (assets/sounds/). A small pool of players lets fast
  // taps overlap instead of cutting each other off.
  static const _clickSounds = [
    'sounds/bead_click_1.wav',
    'sounds/bead_click_2.wav',
    'sounds/bead_click_3.wav',
  ];
  final List<AudioPlayer> _clickPlayers = [];
  int _nextPlayer = 0;
  final math.Random _rng = math.Random();
  bool _clickPlayed = false;
  late final AnimationController _animController;

  _Dhikr get _dhikr => _dhikrs[_index];
  Color get _beadColor => _colors[_colorIndex];

  @override
  void initState() {
    super.initState();
    final prefs = ref.read(prefsProvider);
    _index = (prefs.getInt(_indexKey) ?? 0).clamp(0, _dhikrs.length - 1);
    _count = prefs.getInt(_countKey) ?? 0;
    _sound = prefs.getBool(_soundKey) ?? true;
    _vibrate = prefs.getBool(_vibrateKey) ?? true;
    _colorIndex = (prefs.getInt(_colorKey) ?? 0).clamp(0, _colors.length - 1);

    _animController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 280),
      // Without this, if the phone has animations disabled (developer options,
      // battery saver, accessibility), Flutter finishes the animation almost
      // instantly and you see no movement at all.
      animationBehavior: AnimationBehavior.preserve,
    )
      ..addListener(_onTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) {
          // Keep counting even after the target is reached.
          setState(() => _count++);
          // Strong vibration each time a full round is completed.
          if (_count % _dhikr.target == 0 && _vibrate) {
            HapticFeedback.heavyImpact();
          }
          _save();
          _animController.reset();
        }
      });

    _initTts();
    _initClickPlayers();
  }

  @override
  void dispose() {
    _tts.stop();
    for (final p in _clickPlayers) {
      p.dispose();
    }
    _animController.dispose();
    super.dispose();
  }

  Future<void> _initTts() async {
    try {
      await _tts.setLanguage('ar');
      await _tts.setSpeechRate(0.45);
      await _tts.setVolume(1.0);
      await _tts.setPitch(1.0);
    } catch (_) {}
  }

  Future<void> _save() async {
    final prefs = ref.read(prefsProvider);
    await prefs.setInt(_indexKey, _index);
    await prefs.setInt(_countKey, _count);
    await prefs.setBool(_soundKey, _sound);
    await prefs.setBool(_vibrateKey, _vibrate);
    await prefs.setInt(_colorKey, _colorIndex);
  }

  Future<void> _initClickPlayers() async {
    try {
      for (var i = 0; i < 3; i++) {
        final player = AudioPlayer();
        await player.setPlayerMode(PlayerMode.lowLatency);
        await player.setReleaseMode(ReleaseMode.stop);
        _clickPlayers.add(player);
      }
    } catch (_) {}
  }

  /// Plays the bead clack just before the slide finishes (when the moving
  /// bead visually lands against the others), not after the animation ends.
  void _onTick() {
    if (!_clickPlayed &&
        _animController.isAnimating &&
        _animController.value >= 0.55) {
      _clickPlayed = true;
      _playClick();
    }
  }

  Future<void> _playClick() async {
    if (_vibrate) HapticFeedback.lightImpact();
    if (!_sound || _clickPlayers.isEmpty) return;
    try {
      final player = _clickPlayers[_nextPlayer];
      _nextPlayer = (_nextPlayer + 1) % _clickPlayers.length;
      await player.stop();
      await player.play(
        AssetSource(_clickSounds[_rng.nextInt(_clickSounds.length)]),
        volume: 1.0,
      );
    } catch (_) {}
  }

  void _triggerSlide() {
    if (_animController.isAnimating) return;
    _clickPlayed = false;
    _animController.forward(from: 0.0);
  }

  Future<void> _playDhikr() async {
    if (_vibrate) HapticFeedback.selectionClick();
    try {
      await _tts.stop();
      await _tts.speak(_dhikr.arabic);
    } catch (_) {}
  }

  void _reset() {
    HapticFeedback.selectionClick();
    _animController.reset();
    setState(() {
      _count = 0;
    });
    _save();
  }

  void _selectDhikr(int index) {
    HapticFeedback.selectionClick();
    _animController.reset();
    setState(() {
      _index = index;
      _count = 0;
    });
    _save();
  }

  Future<void> _openDhikrPicker() async {
    HapticFeedback.selectionClick();
    final picked = await showModalBottomSheet<int>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      showDragHandle: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (_) => _DhikrPickerSheet(selectedIndex: _index),
    );
    if (picked != null && picked != _index) _selectDhikr(picked);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Tasbih'),
        actions: [
          IconButton(
            tooltip: _sound ? 'Sound on' : 'Sound off',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _sound = !_sound);
              _save();
            },
            icon: Icon(_sound ? Icons.volume_up_rounded : Icons.volume_off_rounded),
          ),
          IconButton(
            tooltip: _vibrate ? 'Vibration on' : 'Vibration off',
            onPressed: () {
              HapticFeedback.selectionClick();
              setState(() => _vibrate = !_vibrate);
              _save();
            },
            icon: Icon(
              _vibrate ? Icons.vibration_rounded : Icons.do_not_disturb_on_rounded,
            ),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 12, 16, 8),
            child: Material(
              color: Colors.transparent,
              child: InkWell(
                borderRadius: BorderRadius.circular(12),
                onTap: _openDhikrPicker,
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Dhikr',
                              style: TextStyle(
                                color: AppColors.muted,
                                fontSize: 11.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              _dhikr.english,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.unfold_more_rounded, color: AppColors.muted),
                    ],
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.seed.withValues(alpha: 0.06),
                borderRadius: BorderRadius.circular(16),
                border: Border.all(color: AppColors.border),
              ),
              child: Column(
                children: [
                  Text(
                    _dhikr.arabic,
                    textAlign: TextAlign.center,
                    textDirection: TextDirection.rtl,
                    style: const TextStyle(
                      fontFamily: 'AmiriQuran',
                      fontSize: 24,
                      height: 1.5,
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    _dhikr.amharic,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      fontSize: 15,
                      fontWeight: FontWeight.w600,
                      color: AppColors.ink,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    _dhikr.english,
                    textAlign: TextAlign.center,
                    style: const TextStyle(
                      color: AppColors.muted,
                      fontSize: 12.5,
                    ),
                  ),
                ],
              ),
            ),
          ),
          Expanded(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = constraints.biggest;
                  return Container(
                    decoration: BoxDecoration(
                      color: Colors.grey.shade100,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: GestureDetector(
                      behavior: HitTestBehavior.opaque,
                      onTap: _triggerSlide,
                      onPanEnd: (details) {
                        final v = details.velocity.pixelsPerSecond;
                        if (v.dx < 0 || v.dy > 0) _triggerSlide();
                      },
                      child: RepaintBoundary(
                        child: AnimatedBuilder(
                          animation: _animController,
                          builder: (context, child) {
                            return CustomPaint(
                              size: size,
                              painter: _TasbihCanvasPainter(
                                progress: Curves.easeOutCubic.transform(_animController.value),
                                beadColor: _beadColor,
                              ),
                            );
                          },
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            child: Center(
              child: _PhysicalButton(
                baseColor: Theme.of(context).scaffoldBackgroundColor,
                onTap: _triggerSlide,
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Builder(builder: (context) {
              final rounds = _count ~/ _dhikr.target;
              final reached = rounds > 0;
              return Column(
                children: [
                  Text(
                    '$_count / ${_dhikr.target}',
                    style: TextStyle(
                      color: reached ? Colors.green.shade700 : AppColors.muted,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  if (reached)
                    Padding(
                      padding: const EdgeInsets.only(top: 2),
                      child: Text(
                        rounds == 1
                            ? 'Target reached  •  1 round'
                            : '$rounds rounds  •  +${_count - rounds * _dhikr.target} more',
                        style: TextStyle(
                          color: Colors.green.shade700,
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ),
                ],
              );
            }),
          ),
          const SizedBox(height: 8),
          if (!_collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(28),
                  boxShadow: [
                    BoxShadow(
                      color: Colors.black.withValues(alpha: 0.12),
                      blurRadius: 16,
                      offset: const Offset(0, 6),
                    ),
                  ],
                ),
                child: Row(
                  children: [
                    Expanded(
                      child: SingleChildScrollView(
                        scrollDirection: Axis.horizontal,
                        child: Row(
                          children: [
                            for (var i = 0; i < _colors.length; i++)
                              Padding(
                                padding: const EdgeInsets.symmetric(horizontal: 6),
                                child: GestureDetector(
                                  onTap: () {
                                    HapticFeedback.selectionClick();
                                    setState(() => _colorIndex = i);
                                    _save();
                                  },
                                  child: Container(
                                    width: 30,
                                    height: 30,
                                    decoration: BoxDecoration(
                                      color: _colors[i],
                                      shape: BoxShape.circle,
                                      border: Border.all(
                                        color: i == _colorIndex
                                            ? AppColors.ink
                                            : Colors.transparent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                ),
                              ),
                          ],
                        ),
                      ),
                    ),
                    IconButton(
                      onPressed: () {
                        HapticFeedback.selectionClick();
                        setState(() => _collapsed = !_collapsed);
                      },
                      icon: Icon(_collapsed ? Icons.expand_less : Icons.close),
                    ),
                    IconButton(
                      onPressed: _playDhikr,
                      icon: const Icon(Icons.play_arrow_rounded),
                    ),
                    IconButton(
                      onPressed: _reset,
                      icon: const Icon(Icons.refresh_rounded),
                    ),
                  ],
                ),
              ),
            ),
          if (_collapsed)
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
              child: TextButton.icon(
                onPressed: () {
                  HapticFeedback.selectionClick();
                  setState(() => _collapsed = false);
                },
                icon: const Icon(Icons.expand_more_rounded),
                label: const Text('Show controls'),
              ),
            ),
        ],
      ),
    );
  }
}

/// Shifts the lightness of [c] (HSL) by [amount] (-1..1).
Color _tone(Color c, double amount) {
  final hsl = HSLColor.fromColor(c);
  return hsl
      .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
      .toColor();
}

class _TasbihCanvasPainter extends CustomPainter {
  const _TasbihCanvasPainter({
    required this.progress,
    required this.beadColor,
  });

  final double progress;
  final Color beadColor;

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    final p0 = Offset(w + 15, h * 0.45);
    final p1 = Offset(w * 0.40, h * 0.46);
    final p2 = Offset(-15, h * 0.72);

    // 1. Cord (with a soft shadow and a thin highlight so it looks twisted/round)
    final path = Path()
      ..moveTo(p0.dx, p0.dy)
      ..quadraticBezierTo(p1.dx, p1.dy, p2.dx, p2.dy);
    canvas.drawPath(
      path.shift(const Offset(0, 4)),
      Paint()
        ..color = Colors.black.withValues(alpha: 0.16)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3.6
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path,
      Paint()
        ..color = const Color(0xFF4A3525)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 3
        ..strokeCap = StrokeCap.round,
    );
    canvas.drawPath(
      path.shift(const Offset(0, -0.8)),
      Paint()
        ..color = const Color(0xFFB08968).withValues(alpha: 0.55)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9
        ..strokeCap = StrokeCap.round,
    );

    final beadRadius = w * 0.0725;

    // Slots along the curve (t). Beads flow from the right end (t = 0)
    // toward the left end (t = 1). The first and last slots are off-screen:
    // a new bead enters from the first one, an old bead leaves through the
    // last one. The big jump (0.30 -> 0.68) is the gap between the groups.
    const slots = [-0.15, 0.04, 0.17, 0.30, 0.68, 0.82, 0.96, 1.15];

    // EVERY bead moves from its slot to the next slot, using the same progress.
    // At progress = 1 the layout is identical to progress = 0 (beads are
    // identical), so the reset after the animation is invisible.
    for (var i = 0; i < slots.length - 1; i++) {
      final t = slots[i] + (slots[i + 1] - slots[i]) * progress;
      final pos = _pointOnQuad(t, p0, p1, p2);
      final angle = _tangentAngle(t, p0, p1, p2);
      _drawBead(canvas, pos, angle, beadColor, beadRadius);
    }
  }

  Offset _pointOnQuad(double t, Offset p0, Offset p1, Offset p2) {
    final u = 1 - t;
    final x = u * u * p0.dx + 2 * u * t * p1.dx + t * t * p2.dx;
    final y = u * u * p0.dy + 2 * u * t * p1.dy + t * t * p2.dy;
    return Offset(x, y);
  }

  /// Direction of the cord at [t]; the bead's drilled hole follows it.
  double _tangentAngle(double t, Offset p0, Offset p1, Offset p2) {
    final u = 1 - t;
    final dx = 2 * u * (p1.dx - p0.dx) + 2 * t * (p2.dx - p1.dx);
    final dy = 2 * u * (p1.dy - p0.dy) + 2 * t * (p2.dy - p1.dy);
    return math.atan2(dy, dx);
  }

  /// Draws one realistic bead: contact shadow, material (grain, turned
  /// grooves, pores), sphere shading, bounce light, drilled cord holes and
  /// glossy highlights. Light comes from the top-left.
  void _drawBead(Canvas canvas, Offset c, double angle, Color color, double r) {
    final rect = Rect.fromCircle(center: c, radius: r);
    final light = _tone(color, 0.28);

    // --- 1. Shadows cast on the surface below the bead -------------------
    _softEllipse(canvas, c + Offset(r * 0.25, r * 1.0), r * 1.05, 0.34,
        Colors.black.withValues(alpha: 0.38));
    _softEllipse(canvas, c + Offset(r * 0.10, r * 0.90), r * 0.62, 0.26,
        Colors.black.withValues(alpha: 0.55));

    // --- 2. Base body + material texture (turns with the cord direction) ---
    canvas.drawCircle(c, r, Paint()..color = color);

    canvas.save();
    canvas.clipPath(Path()..addOval(rect));
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    _drawMaterial(canvas, r, color);
    canvas.restore();

    // --- 3. Sphere shading: bright lit area -> dark core shadow at the edge -
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(-0.38, -0.45),
          radius: 0.88,
          colors: [
            Colors.white.withValues(alpha: 0.40),
            Colors.white.withValues(alpha: 0.06),
            Colors.black.withValues(alpha: 0.28),
            Colors.black.withValues(alpha: 0.62),
          ],
          stops: const [0.0, 0.30, 0.78, 1.0],
        ).createShader(rect),
    );

    // --- 4. Bounce light reflected from the surface (lower-right) ---------
    canvas.drawCircle(
      c,
      r,
      Paint()
        ..shader = RadialGradient(
          center: const Alignment(0.62, 0.70),
          radius: 0.42,
          colors: [
            light.withValues(alpha: 0.38),
            light.withValues(alpha: 0.0),
          ],
        ).createShader(rect),
    );

    // --- 5. Drilled holes where the cord goes in and out ------------------
    canvas.save();
    canvas.translate(c.dx, c.dy);
    canvas.rotate(angle);
    for (final side in const [-1.0, 1.0]) {
      final hole = Rect.fromCenter(
        center: Offset(side * r * 0.93, 0),
        width: r * 0.17,
        height: r * 0.38,
      );
      canvas.drawOval(hole, Paint()..color = const Color(0xFF120A06));
      canvas.drawOval(
        hole.deflate(r * 0.03),
        Paint()..color = const Color(0xFF3A281B),
      );
    }
    canvas.restore();

    // --- 6. Rim definition + rim lights ------------------------------------
    canvas.drawCircle(
      c,
      r - 0.4,
      Paint()
        ..color = Colors.black.withValues(alpha: 0.35)
        ..style = PaintingStyle.stroke
        ..strokeWidth = 0.9,
    );
    // upper-left edge catches the light
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.90),
      math.pi * 1.02,
      math.pi * 0.52,
      false,
      Paint()
        ..color = Colors.white.withValues(alpha: 0.28)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.05
        ..strokeCap = StrokeCap.round,
    );
    // lower-right edge catches the bounce light
    canvas.drawArc(
      Rect.fromCircle(center: c, radius: r * 0.92),
      math.pi * 0.05,
      math.pi * 0.40,
      false,
      Paint()
        ..color = light.withValues(alpha: 0.30)
        ..style = PaintingStyle.stroke
        ..strokeWidth = r * 0.04
        ..strokeCap = StrokeCap.round,
    );

    // --- 7. Glossy highlights -----------------------------------------------
    // broad soft sheen
    canvas.save();
    canvas.translate(c.dx - r * 0.36, c.dy - r * 0.40);
    canvas.rotate(-0.65);
    canvas.scale(1.0, 0.55);
    final sheenCircle = Rect.fromCircle(center: Offset.zero, radius: r * 0.32);
    canvas.drawCircle(
      Offset.zero,
      r * 0.32,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.78),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(sheenCircle),
    );
    canvas.restore();
    // tiny sharp specular dot
    final dot = c + Offset(-r * 0.43, -r * 0.47);
    canvas.drawCircle(
      dot,
      r * 0.11,
      Paint()
        ..shader = RadialGradient(
          colors: [
            Colors.white.withValues(alpha: 0.98),
            Colors.white.withValues(alpha: 0.0),
          ],
        ).createShader(Rect.fromCircle(center: dot, radius: r * 0.11)),
    );
  }

  /// A flat ellipse filled with a radial fade (cheap soft shadow, no blur).
  void _softEllipse(Canvas canvas, Offset center, double radius, double squash,
      Color color) {
    canvas.save();
    canvas.translate(center.dx, center.dy);
    canvas.scale(1.0, squash);
    canvas.drawCircle(
      Offset.zero,
      radius,
      Paint()
        ..shader = RadialGradient(
          colors: [color, color.withValues(alpha: 0.0)],
        ).createShader(Rect.fromCircle(center: Offset.zero, radius: radius)),
    );
    canvas.restore();
  }

  /// Wood / resin look in the bead's local space (x axis = cord direction).
  /// Every bead gets the same pattern, so beads stay identical while moving.
  void _drawMaterial(Canvas canvas, double r, Color color) {
    // Grain lines running along the bead.
    const waves = [
      [0.10, -0.08, 0.06],
      [-0.07, 0.11, -0.05],
      [0.12, 0.04, -0.09],
      [-0.09, -0.10, 0.07],
      [0.06, 0.09, 0.10],
      [-0.11, 0.07, -0.04],
      [0.08, -0.06, 0.05],
    ];
    final grainDark = Paint()
      ..color = _tone(color, -0.20).withValues(alpha: 0.50)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.04;
    final grainLight = Paint()
      ..color = _tone(color, 0.16).withValues(alpha: 0.38)
      ..style = PaintingStyle.stroke
      ..strokeWidth = r * 0.03;
    for (var i = 0; i < waves.length; i++) {
      final y0 = (i - 3) * r * 0.29;
      final wv = waves[i];
      final grain = Path()
        ..moveTo(-r, y0 + wv[2] * r)
        ..cubicTo(-r * 0.35, y0 + wv[0] * r, r * 0.35, y0 + wv[1] * r, r,
            y0 - wv[2] * r);
      canvas.drawPath(grain, i.isEven ? grainDark : grainLight);
    }

    // Tiny pores / specks.
    const specks = [
      Offset(-0.45, -0.20), Offset(0.10, 0.35), Offset(0.50, -0.10),
      Offset(-0.20, 0.52), Offset(0.32, -0.52), Offset(-0.62, 0.28),
      Offset(0.62, 0.40), Offset(-0.05, -0.62), Offset(0.18, 0.05),
    ];
    final speckPaint = Paint()
      ..color = _tone(color, -0.30).withValues(alpha: 0.35);
    for (final sp in specks) {
      canvas.drawCircle(sp * r, r * 0.022, speckPaint);
    }

    // Two turned grooves (rings) around the bead.
    for (final side in const [-1.0, 1.0]) {
      final a = side * r * 0.52;
      final hh = math.sqrt(r * r - a * a);
      final groove = Path()
        ..moveTo(a, -hh)
        ..quadraticBezierTo(a + side * r * 0.16, 0, a, hh);
      canvas.drawPath(
        groove,
        Paint()
          ..color = Colors.black.withValues(alpha: 0.40)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.06,
      );
      canvas.drawPath(
        groove.shift(Offset(r * 0.055, 0)),
        Paint()
          ..color = Colors.white.withValues(alpha: 0.20)
          ..style = PaintingStyle.stroke
          ..strokeWidth = r * 0.035,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _TasbihCanvasPainter oldDelegate) {
    return oldDelegate.progress != progress ||
        oldDelegate.beadColor != beadColor;
  }
}

/// A push button that looks like a physical hardware button: a raised bezel
/// with a domed cap that physically sinks when pressed. Its colour is derived
/// from [baseColor] so it blends with the background.
class _PhysicalButton extends StatefulWidget {
  const _PhysicalButton({required this.baseColor, required this.onTap});

  final Color baseColor;
  final VoidCallback onTap;

  @override
  State<_PhysicalButton> createState() => _PhysicalButtonState();
}

class _PhysicalButtonState extends State<_PhysicalButton> {
  bool _down = false;

  static Color _shift(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl
        .withLightness((hsl.lightness + amount).clamp(0.0, 1.0))
        .toColor();
  }

  void _setDown(bool v) {
    if (_down != v) setState(() => _down = v);
  }

  @override
  Widget build(BuildContext context) {
    const outer = 88.0;
    const cap = 70.0;
    const travel = 5.0; // how far the cap sinks when pressed
    const dur = Duration(milliseconds: 90);

    final base = widget.baseColor;
    final light = _shift(base, 0.10);
    final dark = _shift(base, -0.14);
    final darker = _shift(base, -0.38);

    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => _setDown(true),
      onTapUp: (_) => _setDown(false),
      onTapCancel: () => _setDown(false),
      onTap: widget.onTap,
      child: SizedBox(
        width: outer,
        height: outer,
        child: Stack(
          alignment: Alignment.center,
          children: [
            // Bezel: the ring the button sits in, slightly raised from the surface.
            Container(
              width: outer,
              height: outer,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [dark, light],
                ),
                boxShadow: [
                  BoxShadow(
                    color: Colors.white.withValues(alpha: 0.9),
                    blurRadius: 8,
                    offset: const Offset(-4, -4),
                  ),
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.22),
                    blurRadius: 10,
                    offset: const Offset(4, 6),
                  ),
                ],
              ),
            ),
            // Dark well the cap sinks into (gives the feeling of depth).
            Container(
              width: cap + 8,
              height: cap + 8,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [
                    Colors.black.withValues(alpha: 0.30),
                    Colors.white.withValues(alpha: 0.65),
                  ],
                ),
              ),
            ),
            // The cap itself.
            AnimatedContainer(
              duration: dur,
              curve: Curves.easeOut,
              width: cap,
              height: cap,
              transform: Matrix4.translationValues(0, _down ? travel - 2 : -2, 0),
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: RadialGradient(
                  center: const Alignment(-0.35, -0.45),
                  radius: 1.0,
                  colors: _down
                      ? [base, _shift(base, -0.05), dark]
                      : [_shift(base, 0.16), base, dark],
                  stops: const [0.0, 0.55, 1.0],
                ),
                border: Border.all(
                  color: Colors.white.withValues(alpha: _down ? 0.25 : 0.7),
                  width: 1.2,
                ),
                boxShadow: _down
                    ? [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.30),
                          blurRadius: 2,
                          offset: const Offset(0, 1),
                        ),
                      ]
                    : [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.38),
                          blurRadius: 10,
                          offset: const Offset(0, 7),
                        ),
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.25),
                          blurRadius: 2,
                          offset: const Offset(0, 3),
                        ),
                      ],
              ),
              alignment: Alignment.center,
              child: Icon(
                Icons.touch_app_rounded,
                size: 30,
                color: darker,
                shadows: [
                  Shadow(
                    color: Colors.white.withValues(alpha: 0.9),
                    offset: const Offset(0, 1),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}


/// Bottom sheet to choose a dhikr: searchable, grouped by category.
class _DhikrPickerSheet extends StatefulWidget {
  const _DhikrPickerSheet({required this.selectedIndex});

  final int selectedIndex;

  @override
  State<_DhikrPickerSheet> createState() => _DhikrPickerSheetState();
}

class _DhikrPickerSheetState extends State<_DhikrPickerSheet> {
  String _query = '';

  bool _matches(_Dhikr d) {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return true;
    return d.english.toLowerCase().contains(q) ||
        d.category.toLowerCase().contains(q) ||
        d.amharic.contains(q) ||
        d.arabic.contains(q);
  }

  @override
  Widget build(BuildContext context) {
    // Flat list: category names (String) followed by dhikr indexes (int).
    final rows = <Object>[];
    for (final category in _dhikrCategories) {
      final indexes = <int>[
        for (var i = 0; i < _dhikrs.length; i++)
          if (_dhikrs[i].category == category && _matches(_dhikrs[i])) i,
      ];
      if (indexes.isEmpty) continue;
      rows
        ..add(category)
        ..addAll(indexes);
    }

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.85,
      minChildSize: 0.5,
      maxChildSize: 0.95,
      builder: (context, scrollController) {
        return Padding(
          padding: EdgeInsets.only(
            bottom: MediaQuery.of(context).viewInsets.bottom,
          ),
          child: Column(
            children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(20, 0, 20, 10),
                child: Row(
                  children: [
                    const Expanded(
                      child: Text(
                        'Choose dhikr',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                      ),
                    ),
                    Text(
                      '${_dhikrs.length} dhikrs',
                      style: const TextStyle(color: AppColors.muted, fontSize: 12.5),
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                child: TextField(
                  onChanged: (v) => setState(() => _query = v),
                  decoration: InputDecoration(
                    hintText: 'Search dhikr...',
                    prefixIcon: const Icon(Icons.search_rounded),
                    isDense: true,
                    border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                  ),
                ),
              ),
              Expanded(
                child: rows.isEmpty
                    ? const Center(
                        child: Text(
                          'No dhikr found',
                          style: TextStyle(color: AppColors.muted),
                        ),
                      )
                    : ListView.builder(
                        controller: scrollController,
                        padding: const EdgeInsets.fromLTRB(12, 0, 12, 24),
                        itemCount: rows.length,
                        itemBuilder: (context, i) {
                          final row = rows[i];
                          if (row is String) {
                            return Padding(
                              padding: const EdgeInsets.fromLTRB(6, 14, 6, 6),
                              child: Text(
                                row.toUpperCase(),
                                style: const TextStyle(
                                  color: AppColors.muted,
                                  fontSize: 11.5,
                                  fontWeight: FontWeight.w700,
                                  letterSpacing: 1.0,
                                ),
                              ),
                            );
                          }
                          return _tile(context, row as int);
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _tile(BuildContext context, int index) {
    final d = _dhikrs[index];
    final selected = index == widget.selectedIndex;
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Material(
        color: selected
            ? AppColors.seed.withValues(alpha: 0.10)
            : Colors.transparent,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(14),
          side: BorderSide(
            color: selected ? AppColors.seed : AppColors.border,
            width: selected ? 1.5 : 1,
          ),
        ),
        child: InkWell(
          borderRadius: BorderRadius.circular(14),
          onTap: () => Navigator.of(context).pop(index),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      SizedBox(
                        width: double.infinity,
                        child: Text(
                          d.arabic,
                          textDirection: TextDirection.rtl,
                          textAlign: TextAlign.right,
                          style: const TextStyle(
                            fontFamily: 'AmiriQuran',
                            fontSize: 20,
                            height: 1.5,
                          ),
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        d.amharic,
                        style: const TextStyle(
                          fontSize: 13.5,
                          fontWeight: FontWeight.w600,
                          color: AppColors.ink,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        d.english,
                        style: const TextStyle(
                          color: AppColors.muted,
                          fontSize: 12,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(width: 10),
                Column(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                      decoration: BoxDecoration(
                        color: AppColors.seed.withValues(alpha: 0.10),
                        borderRadius: BorderRadius.circular(10),
                      ),
                      child: Text(
                        '×${d.target}',
                        style: const TextStyle(
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    if (selected) ...[
                      const SizedBox(height: 8),
                      Icon(Icons.check_circle_rounded,
                          color: AppColors.seed, size: 22),
                    ],
                  ],
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
