import '../../../../core/services/language_service.dart';

enum FocusLandingBlockType { text, image }

class FocusLandingBlock {
  final String id;
  final FocusLandingBlockType type;
  final String titleEn;
  final String titleTe;
  final String titleHi;
  final String bodyEn;
  final String bodyTe;
  final String bodyHi;
  final String imageUrl;

  const FocusLandingBlock({
    required this.id,
    required this.type,
    this.titleEn = '',
    this.titleTe = '',
    this.titleHi = '',
    this.bodyEn = '',
    this.bodyTe = '',
    this.bodyHi = '',
    this.imageUrl = '',
  });

  String localizedTitle(AppLanguage language) {
    switch (language) {
      case AppLanguage.telugu:
        return titleTe.trim().isNotEmpty ? titleTe : titleEn;
      case AppLanguage.hindi:
        return titleHi.trim().isNotEmpty ? titleHi : titleEn;
      case AppLanguage.english:
        return titleEn;
    }
  }

  String localizedBody(AppLanguage language) {
    switch (language) {
      case AppLanguage.telugu:
        return bodyTe.trim().isNotEmpty ? bodyTe : bodyEn;
      case AppLanguage.hindi:
        return bodyHi.trim().isNotEmpty ? bodyHi : bodyEn;
      case AppLanguage.english:
        return bodyEn;
    }
  }

  FocusLandingBlock copyWith({
    String? id,
    FocusLandingBlockType? type,
    String? titleEn,
    String? titleTe,
    String? titleHi,
    String? bodyEn,
    String? bodyTe,
    String? bodyHi,
    String? imageUrl,
  }) {
    return FocusLandingBlock(
      id: id ?? this.id,
      type: type ?? this.type,
      titleEn: titleEn ?? this.titleEn,
      titleTe: titleTe ?? this.titleTe,
      titleHi: titleHi ?? this.titleHi,
      bodyEn: bodyEn ?? this.bodyEn,
      bodyTe: bodyTe ?? this.bodyTe,
      bodyHi: bodyHi ?? this.bodyHi,
      imageUrl: imageUrl ?? this.imageUrl,
    );
  }

  factory FocusLandingBlock.fromJson(Map<String, dynamic> json) {
    return FocusLandingBlock(
      id: (json['id'] ?? '').toString(),
      type: (json['type'] ?? '').toString() == 'image'
          ? FocusLandingBlockType.image
          : FocusLandingBlockType.text,
      titleEn: (json['title_en'] ?? '').toString(),
      titleTe: (json['title_te'] ?? '').toString(),
      titleHi: (json['title_hi'] ?? '').toString(),
      bodyEn: (json['body_en'] ?? '').toString(),
      bodyTe: (json['body_te'] ?? '').toString(),
      bodyHi: (json['body_hi'] ?? '').toString(),
      imageUrl: (json['image_url'] ?? '').toString(),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type == FocusLandingBlockType.image ? 'image' : 'text',
      'title_en': titleEn,
      'title_te': titleTe,
      'title_hi': titleHi,
      'body_en': bodyEn,
      'body_te': bodyTe,
      'body_hi': bodyHi,
      'image_url': imageUrl,
    };
  }
}

class FocusLandingContent {
  final String introTitleEn;
  final String introTitleTe;
  final String introTitleHi;
  final String introBodyEn;
  final String introBodyTe;
  final String introBodyHi;
  final String heroImageUrl;
  final String secondaryTitleEn;
  final String secondaryTitleTe;
  final String secondaryTitleHi;
  final String secondaryBodyEn;
  final String secondaryBodyTe;
  final String secondaryBodyHi;
  final String secondaryImageUrl;
  final String tertiaryTitleEn;
  final String tertiaryTitleTe;
  final String tertiaryTitleHi;
  final String tertiaryBodyEn;
  final String tertiaryBodyTe;
  final String tertiaryBodyHi;
  final String tertiaryImageUrl;
  final bool showHeroImage;
  final bool showSecondarySection;
  final bool showTertiarySection;
  final bool autoShowForPublicUsers;
  final int autoShowDurationSeconds;
  final int autoShowFrequencyPerDay;
  final int autoShowStartHour24;
  final List<FocusLandingBlock> blocks;
  final String? updatedBy;
  final DateTime? updatedAt;

  const FocusLandingContent({
    required this.introTitleEn,
    required this.introTitleTe,
    required this.introTitleHi,
    required this.introBodyEn,
    required this.introBodyTe,
    required this.introBodyHi,
    required this.heroImageUrl,
    required this.secondaryTitleEn,
    required this.secondaryTitleTe,
    required this.secondaryTitleHi,
    required this.secondaryBodyEn,
    required this.secondaryBodyTe,
    required this.secondaryBodyHi,
    required this.secondaryImageUrl,
    this.tertiaryTitleEn = '',
    this.tertiaryTitleTe = '',
    this.tertiaryTitleHi = '',
    this.tertiaryBodyEn = '',
    this.tertiaryBodyTe = '',
    this.tertiaryBodyHi = '',
    this.tertiaryImageUrl = '',
    this.showHeroImage = true,
    this.showSecondarySection = true,
    this.showTertiarySection = false,
    this.autoShowForPublicUsers = true,
    this.autoShowDurationSeconds = 4,
    this.autoShowFrequencyPerDay = 1,
    this.autoShowStartHour24 = 8,
    this.blocks = const [],
    this.updatedBy,
    this.updatedAt,
  });

  factory FocusLandingContent.defaults() {
    return const FocusLandingContent(
      introTitleEn: 'Welcome to Focus Today',
      introTitleTe: 'ఫోకస్ టుడేకు స్వాగతం',
      introTitleHi: 'फोकस टुडे में आपका स्वागत है',
      introBodyEn:
          'Focus Today is a community-first civic news platform that connects people with verified local updates, emergency alerts, and public meetings.',
      introBodyTe:
          'ఫోకస్ టుడే ప్రజలను ధృవీకరించిన స్థానిక అప్‌డేట్‌లు, అత్యవసర హెచ్చరికలు మరియు ప్రజా సమావేశాలతో కలిపే కమ్యూనిటీ-ఫస్ట్ సివిక్ న్యూస్ ప్లాట్‌ఫారమ్.',
      introBodyHi:
          'फोकस टुडे एक कम्युनिटी-फर्स्ट सिविक न्यूज़ प्लेटफ़ॉर्म है जो लोगों को सत्यापित स्थानीय अपडेट, आपातकालीन अलर्ट और सार्वजनिक बैठकों से जोड़ता है।',
      heroImageUrl: '',
      secondaryTitleEn: 'What You Can Do Here',
      secondaryTitleTe: 'ఇక్కడ మీరు చేయగలిగేది',
      secondaryTitleHi: 'आप यहां क्या कर सकते हैं',
      secondaryBodyEn:
          'Read trusted stories, follow civic developments, and stay prepared with timely event and alert updates from your region.',
      secondaryBodyTe:
          'విశ్వసనీయ కథనాలు చదవండి, పౌర పరిణామాలను అనుసరించండి మరియు మీ ప్రాంతానికి సంబంధించిన ఈవెంట్, అలర్ట్ అప్‌డేట్‌లతో సిద్ధంగా ఉండండి.',
      secondaryBodyHi:
          'विश्वसनीय खबरें पढ़ें, नागरिक विकास पर नज़र रखें और अपने क्षेत्र के ईवेंट व अलर्ट अपडेट के साथ तैयार रहें।',
      secondaryImageUrl: '',
      tertiaryTitleEn: '',
      tertiaryTitleTe: '',
      tertiaryTitleHi: '',
      tertiaryBodyEn: '',
      tertiaryBodyTe: '',
      tertiaryBodyHi: '',
      tertiaryImageUrl: '',
      showHeroImage: true,
      showSecondarySection: true,
      showTertiarySection: false,
      autoShowForPublicUsers: true,
      autoShowDurationSeconds: 4,
      autoShowFrequencyPerDay: 1,
      autoShowStartHour24: 8,
      blocks: [
        FocusLandingBlock(
          id: 'hero_image',
          type: FocusLandingBlockType.image,
          imageUrl: '',
        ),
        FocusLandingBlock(
          id: 'intro_text',
          type: FocusLandingBlockType.text,
          titleEn: 'Welcome to Focus Today',
          titleTe: 'ఫోకస్ టుడేకు స్వాగతం',
          titleHi: 'फोकस टुडे में आपका स्वागत है',
          bodyEn:
              'Focus Today is a community-first civic news platform that connects people with verified local updates, emergency alerts, and public meetings.',
          bodyTe:
              'ఫోకస్ టుడే ప్రజలను ధృవీకరించిన స్థానిక అప్‌డేట్‌లు, అత్యవసర హెచ్చరికలు మరియు ప్రజా సమావేశాలతో కలిపే కమ్యూనిటీ-ఫస్ట్ సివిక్ న్యూస్ ప్లాట్‌ఫారమ్.',
          bodyHi:
              'फोकस टुडे एक कम्युनिटी-फर्स्ट सिविक न्यूज़ प्लेटफ़ॉर्म है जो लोगों को सत्यापित स्थानीय अपडेट, आपातकालीन अलर्ट और सार्वजनिक बैठकों से जोड़ता है।',
        ),
        FocusLandingBlock(
          id: 'secondary_text',
          type: FocusLandingBlockType.text,
          titleEn: 'What You Can Do Here',
          titleTe: 'ఇక్కడ మీరు చేయగలిగేది',
          titleHi: 'आप यहां क्या कर सकते हैं',
          bodyEn:
              'Read trusted stories, follow civic developments, and stay prepared with timely event and alert updates from your region.',
          bodyTe:
              'విశ్వసనీయ కథనాలు చదవండి, పౌర పరిణామాలను అనుసరించండి మరియు మీ ప్రాంతానికి సంబంధించిన ఈవెంట్, అలర్ట్ అప్‌డేట్‌లతో సిద్ధంగా ఉండండి.',
          bodyHi:
              'विश्वसनीय खबरें पढ़ें, नागरिक विकास पर नज़र रखें और अपने क्षेत्र के ईवेंट व अलर्ट अपडेट के साथ तैयार रहें।',
        ),
        FocusLandingBlock(
          id: 'secondary_image',
          type: FocusLandingBlockType.image,
          imageUrl: '',
        ),
      ],
    );
  }

  String localizedIntroTitle(AppLanguage language) =>
      _localized(language, introTitleEn, introTitleTe, introTitleHi);

  String localizedIntroBody(AppLanguage language) =>
      _localized(language, introBodyEn, introBodyTe, introBodyHi);

  String localizedSecondaryTitle(AppLanguage language) => _localized(
    language,
    secondaryTitleEn,
    secondaryTitleTe,
    secondaryTitleHi,
  );

  String localizedSecondaryBody(AppLanguage language) =>
      _localized(language, secondaryBodyEn, secondaryBodyTe, secondaryBodyHi);
  String localizedTertiaryTitle(AppLanguage language) =>
      _localized(language, tertiaryTitleEn, tertiaryTitleTe, tertiaryTitleHi);
  String localizedTertiaryBody(AppLanguage language) =>
      _localized(language, tertiaryBodyEn, tertiaryBodyTe, tertiaryBodyHi);

  static String _localized(
    AppLanguage language,
    String en,
    String te,
    String hi,
  ) {
    switch (language) {
      case AppLanguage.telugu:
        return te.trim().isNotEmpty ? te : en;
      case AppLanguage.hindi:
        return hi.trim().isNotEmpty ? hi : en;
      case AppLanguage.english:
        return en;
    }
  }

  FocusLandingContent copyWith({
    String? introTitleEn,
    String? introTitleTe,
    String? introTitleHi,
    String? introBodyEn,
    String? introBodyTe,
    String? introBodyHi,
    String? heroImageUrl,
    String? secondaryTitleEn,
    String? secondaryTitleTe,
    String? secondaryTitleHi,
    String? secondaryBodyEn,
    String? secondaryBodyTe,
    String? secondaryBodyHi,
    String? secondaryImageUrl,
    String? tertiaryTitleEn,
    String? tertiaryTitleTe,
    String? tertiaryTitleHi,
    String? tertiaryBodyEn,
    String? tertiaryBodyTe,
    String? tertiaryBodyHi,
    String? tertiaryImageUrl,
    bool? showHeroImage,
    bool? showSecondarySection,
    bool? showTertiarySection,
    bool? autoShowForPublicUsers,
    int? autoShowDurationSeconds,
    int? autoShowFrequencyPerDay,
    int? autoShowStartHour24,
    List<FocusLandingBlock>? blocks,
    String? updatedBy,
    DateTime? updatedAt,
  }) {
    return FocusLandingContent(
      introTitleEn: introTitleEn ?? this.introTitleEn,
      introTitleTe: introTitleTe ?? this.introTitleTe,
      introTitleHi: introTitleHi ?? this.introTitleHi,
      introBodyEn: introBodyEn ?? this.introBodyEn,
      introBodyTe: introBodyTe ?? this.introBodyTe,
      introBodyHi: introBodyHi ?? this.introBodyHi,
      heroImageUrl: heroImageUrl ?? this.heroImageUrl,
      secondaryTitleEn: secondaryTitleEn ?? this.secondaryTitleEn,
      secondaryTitleTe: secondaryTitleTe ?? this.secondaryTitleTe,
      secondaryTitleHi: secondaryTitleHi ?? this.secondaryTitleHi,
      secondaryBodyEn: secondaryBodyEn ?? this.secondaryBodyEn,
      secondaryBodyTe: secondaryBodyTe ?? this.secondaryBodyTe,
      secondaryBodyHi: secondaryBodyHi ?? this.secondaryBodyHi,
      secondaryImageUrl: secondaryImageUrl ?? this.secondaryImageUrl,
      tertiaryTitleEn: tertiaryTitleEn ?? this.tertiaryTitleEn,
      tertiaryTitleTe: tertiaryTitleTe ?? this.tertiaryTitleTe,
      tertiaryTitleHi: tertiaryTitleHi ?? this.tertiaryTitleHi,
      tertiaryBodyEn: tertiaryBodyEn ?? this.tertiaryBodyEn,
      tertiaryBodyTe: tertiaryBodyTe ?? this.tertiaryBodyTe,
      tertiaryBodyHi: tertiaryBodyHi ?? this.tertiaryBodyHi,
      tertiaryImageUrl: tertiaryImageUrl ?? this.tertiaryImageUrl,
      showHeroImage: showHeroImage ?? this.showHeroImage,
      showSecondarySection: showSecondarySection ?? this.showSecondarySection,
      showTertiarySection: showTertiarySection ?? this.showTertiarySection,
      autoShowForPublicUsers:
          autoShowForPublicUsers ?? this.autoShowForPublicUsers,
      autoShowDurationSeconds:
          autoShowDurationSeconds ?? this.autoShowDurationSeconds,
      autoShowFrequencyPerDay:
          autoShowFrequencyPerDay ?? this.autoShowFrequencyPerDay,
      autoShowStartHour24: autoShowStartHour24 ?? this.autoShowStartHour24,
      blocks: blocks ?? this.blocks,
      updatedBy: updatedBy ?? this.updatedBy,
      updatedAt: updatedAt ?? this.updatedAt,
    );
  }

  factory FocusLandingContent.fromJson(Map<String, dynamic> json) {
    return FocusLandingContent(
      introTitleEn: (json['intro_title_en'] ?? '').toString(),
      introTitleTe: (json['intro_title_te'] ?? '').toString(),
      introTitleHi: (json['intro_title_hi'] ?? '').toString(),
      introBodyEn: (json['intro_body_en'] ?? '').toString(),
      introBodyTe: (json['intro_body_te'] ?? '').toString(),
      introBodyHi: (json['intro_body_hi'] ?? '').toString(),
      heroImageUrl: (json['hero_image_url'] ?? '').toString(),
      secondaryTitleEn: (json['secondary_title_en'] ?? '').toString(),
      secondaryTitleTe: (json['secondary_title_te'] ?? '').toString(),
      secondaryTitleHi: (json['secondary_title_hi'] ?? '').toString(),
      secondaryBodyEn: (json['secondary_body_en'] ?? '').toString(),
      secondaryBodyTe: (json['secondary_body_te'] ?? '').toString(),
      secondaryBodyHi: (json['secondary_body_hi'] ?? '').toString(),
      secondaryImageUrl: (json['secondary_image_url'] ?? '').toString(),
      tertiaryTitleEn: (json['tertiary_title_en'] ?? '').toString(),
      tertiaryTitleTe: (json['tertiary_title_te'] ?? '').toString(),
      tertiaryTitleHi: (json['tertiary_title_hi'] ?? '').toString(),
      tertiaryBodyEn: (json['tertiary_body_en'] ?? '').toString(),
      tertiaryBodyTe: (json['tertiary_body_te'] ?? '').toString(),
      tertiaryBodyHi: (json['tertiary_body_hi'] ?? '').toString(),
      tertiaryImageUrl: (json['tertiary_image_url'] ?? '').toString(),
      showHeroImage: json['show_hero_image'] != false,
      showSecondarySection: json['show_secondary_section'] != false,
      showTertiarySection: json['show_tertiary_section'] == true,
      autoShowForPublicUsers: json['auto_show_for_public_users'] != false,
      autoShowDurationSeconds: _clampInt(
        json['auto_show_duration_seconds'],
        fallback: 4,
        min: 3,
        max: 15,
      ),
      autoShowFrequencyPerDay: _clampInt(
        json['auto_show_frequency_per_day'],
        fallback: 1,
        min: 1,
        max: 6,
      ),
      autoShowStartHour24: _clampInt(
        json['auto_show_start_hour_24'],
        fallback: 8,
        min: 0,
        max: 23,
      ),
      blocks: _parseBlocks(json),
      updatedBy: json['updated_by']?.toString(),
      updatedAt: DateTime.tryParse((json['updated_at'] ?? '').toString()),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'intro_title_en': introTitleEn,
      'intro_title_te': introTitleTe,
      'intro_title_hi': introTitleHi,
      'intro_body_en': introBodyEn,
      'intro_body_te': introBodyTe,
      'intro_body_hi': introBodyHi,
      'hero_image_url': heroImageUrl,
      'secondary_title_en': secondaryTitleEn,
      'secondary_title_te': secondaryTitleTe,
      'secondary_title_hi': secondaryTitleHi,
      'secondary_body_en': secondaryBodyEn,
      'secondary_body_te': secondaryBodyTe,
      'secondary_body_hi': secondaryBodyHi,
      'secondary_image_url': secondaryImageUrl,
      'tertiary_title_en': tertiaryTitleEn,
      'tertiary_title_te': tertiaryTitleTe,
      'tertiary_title_hi': tertiaryTitleHi,
      'tertiary_body_en': tertiaryBodyEn,
      'tertiary_body_te': tertiaryBodyTe,
      'tertiary_body_hi': tertiaryBodyHi,
      'tertiary_image_url': tertiaryImageUrl,
      'show_hero_image': showHeroImage,
      'show_secondary_section': showSecondarySection,
      'show_tertiary_section': showTertiarySection,
      'auto_show_for_public_users': autoShowForPublicUsers,
      'auto_show_duration_seconds': autoShowDurationSeconds,
      'auto_show_frequency_per_day': autoShowFrequencyPerDay,
      'auto_show_start_hour_24': autoShowStartHour24,
      'blocks': blocks.map((block) => block.toJson()).toList(growable: false),
      if (updatedBy != null) 'updated_by': updatedBy,
      if (updatedAt != null) 'updated_at': updatedAt!.toIso8601String(),
    };
  }

  static List<FocusLandingBlock> _parseBlocks(Map<String, dynamic> json) {
    final raw = json['blocks'];
    if (raw is List) {
      final parsed = raw
          .whereType<Map>()
          .map(
            (row) => FocusLandingBlock.fromJson(Map<String, dynamic>.from(row)),
          )
          .toList(growable: false);
      if (parsed.isNotEmpty) {
        return parsed;
      }
    }
    final fallback = <FocusLandingBlock>[
      if (json['show_hero_image'] != false)
        FocusLandingBlock(
          id: 'hero_image',
          type: FocusLandingBlockType.image,
          imageUrl: (json['hero_image_url'] ?? '').toString(),
        ),
      FocusLandingBlock(
        id: 'intro_text',
        type: FocusLandingBlockType.text,
        titleEn: (json['intro_title_en'] ?? '').toString(),
        titleTe: (json['intro_title_te'] ?? '').toString(),
        titleHi: (json['intro_title_hi'] ?? '').toString(),
        bodyEn: (json['intro_body_en'] ?? '').toString(),
        bodyTe: (json['intro_body_te'] ?? '').toString(),
        bodyHi: (json['intro_body_hi'] ?? '').toString(),
      ),
      if (json['show_secondary_section'] != false) ...[
        FocusLandingBlock(
          id: 'secondary_text',
          type: FocusLandingBlockType.text,
          titleEn: (json['secondary_title_en'] ?? '').toString(),
          titleTe: (json['secondary_title_te'] ?? '').toString(),
          titleHi: (json['secondary_title_hi'] ?? '').toString(),
          bodyEn: (json['secondary_body_en'] ?? '').toString(),
          bodyTe: (json['secondary_body_te'] ?? '').toString(),
          bodyHi: (json['secondary_body_hi'] ?? '').toString(),
        ),
        if ((json['secondary_image_url'] ?? '').toString().trim().isNotEmpty)
          FocusLandingBlock(
            id: 'secondary_image',
            type: FocusLandingBlockType.image,
            imageUrl: (json['secondary_image_url'] ?? '').toString(),
          ),
      ],
    ];
    return fallback
        .where((block) {
          if (block.type == FocusLandingBlockType.image) {
            return block.imageUrl.trim().isNotEmpty || block.id == 'hero_image';
          }
          return true;
        })
        .toList(growable: false);
  }

  static int _clampInt(
    dynamic raw, {
    required int fallback,
    required int min,
    required int max,
  }) {
    final value = raw is int
        ? raw
        : raw is num
        ? raw.toInt()
        : int.tryParse('${raw ?? ''}') ?? fallback;
    return value.clamp(min, max);
  }
}
