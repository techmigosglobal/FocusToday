import '../../../shared/models/post.dart';

/// Enhanced Sample Post Data Generator
/// Creates diverse content types including images, videos, and PDF
class SamplePostDataEnhanced {
  static List<Post> generateSamplePosts() {
    final now = DateTime.now();

    return [
      // 1. Image Post - Breaking News
      Post(
        id: 'img_post_1',
        authorId: 'eagle_reporter_1',
        authorName: 'Eagle News Reporter',
        caption:
            'Breaking: Major Development in Technology Sector! '
            'Tech giants announce groundbreaking AI collaboration that will reshape the industry. '
            'Experts predict revolutionary changes in how we interact with technology.',
        captionTe:
            'బ్రేకింగ్: టెక్నాలజీ రంగంలో పెద్ద పురోగతి! '
            'టెక్ దిగ్గజాలు పరిశ్రమను పునర్నిర్మించే AI సహకారాన్ని ప్రకటించారు. '
            'టెక్నాలజీతో మనం ఎలా ఇంటరాక్ట్ అవుతామో విప్లవాత్మక మార్పులు జరుగుతాయని నిపుణులు అంచనా.',
        captionHi:
            'ब्रेकिंग: प्रौद्योगिकी क्षेत्र में बड़ा विकास! '
            'टेक दिग्गजों ने उद्योग को नया आकार देने वाले AI सहयोग की घोषणा की। '
            'विशेषज्ञों का अनुमान है कि प्रौद्योगिकी के साथ हमारी बातचीत में क्रांतिकारी बदलाव आएंगे।',
        category: 'Technology',
        contentType: ContentType.image,
        mediaUrl: 'https://picsum.photos/seed/tech1/800/1200',
        status: PostStatus.approved,
        createdAt: now.subtract(const Duration(hours: 2)),
        publishedAt: now.subtract(const Duration(hours: 2)),
        hashtags: ['Technology', 'AI', 'Innovation', 'BreakingNews'],
        likesCount: 1245,
        sharesCount: 342,
        bookmarksCount: 567,
      ),

      // 2. Image Post - Sports
      Post(
        id: 'img_post_2',
        authorId: 'sports_desk',
        authorName: 'Sports Desk',
        caption:
            'Historic Victory! National Team Clinches Championship Title '
            'in thrilling finale. Fans celebrate across the nation as underdogs '
            'claim their first major trophy in decades. #Champions #Victory',
        captionTe:
            'చారిత్రాత్మక విజయం! జాతీయ జట్టు ఛాంపియన్‌షిప్ టైటిల్ సాధించింది '
            'ఉత్కంఠభరిత ఫైనల్‌లో. అండర్‌డాగ్స్ దశాబ్దాలలో మొదటి ట్రోఫీని సాధించడంతో '
            'దేశవ్యాప్తంగా అభిమానులు సంబరాలు జరుపుకున్నారు. #ఛాంపియన్లు #విజయం',
        captionHi:
            'ऐतिहासिक जीत! राष्ट्रीय टीम ने चैम्पियनशिप खिताब जीता '
            'रोमांचक फाइनल में। अंडरडॉग्स ने दशकों में पहली बड़ी ट्रॉफी जीती '
            'पूरे देश में प्रशंसकों ने जश्न मनाया। #चैंपियंस #विजय',
        category: 'Sports',
        contentType: ContentType.image,
        mediaUrl: 'https://picsum.photos/seed/sports1/800/1200',
        status: PostStatus.approved,
        createdAt: now.subtract(const Duration(hours: 5)),
        publishedAt: now.subtract(const Duration(hours: 5)),
        hashtags: ['Sports', 'Championship', 'Victory'],
        likesCount: 2890,
        sharesCount: 876,
        bookmarksCount: 1234,
      ),

      // 3. Video Post - Entertainment
      Post(
        id: 'video_post_1',
        authorId: 'entertainment_hub',
        authorName: 'Entertainment Hub',
        caption:
            '🎬 EXCLUSIVE: Behind The Scenes Footage! '
            'Get an exclusive look at the making of the year\'s most anticipated film. '
            'Director shares insights into the creative process and special effects magic.',
        captionTe:
            '🎬 ఎక్స్‌క్లూసివ్: బిహైండ్ ద సీన్స్ ఫుటేజ్! '
            'సంవత్సరంలో అత్యంత ఆశించిన చిత్రం తయారీలో ఎక్స్‌క్లూసివ్ లుక్ పొందండి. '
            'దర్శకుడు క్రియేటివ్ ప్రాసెస్ మరియు స్పెషల్ ఎఫెక్ట్స్ మ్యాజిక్ గురించి అంతర్దృష్టులు పంచుకున్నారు.',
        captionHi:
            '🎬 एक्सक्लूसिव: बिहाइंड द सीन्स फुटेज! '
            'साल की सबसे प्रतीक्षित फिल्म की मेकिंग पर एक्सक्लूसिव नज़र डालें। '
            'निर्देशक ने रचनात्मक प्रक्रिया और स्पेशल इफेक्ट्स के जादू के बारे में जानकारी साझा की।',
        category: 'Entertainment',
        contentType: ContentType.video,
        mediaUrl:
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/BigBuckBunny.mp4',
        status: PostStatus.approved,
        createdAt: now.subtract(const Duration(hours: 8)),
        publishedAt: now.subtract(const Duration(hours: 8)),
        hashtags: ['Entertainment', 'Movies', 'BehindTheScenes', 'Exclusive'],
        likesCount: 4567,
        sharesCount: 1234,
        bookmarksCount: 2345,
      ),

      // 4. Video Post - News
      Post(
        id: 'video_post_2',
        authorId: 'field_reporter',
        authorName: 'Field Reporter',
        caption:
            '📹 LIVE UPDATE: Climate Summit Concludes with Historic Agreement '
            'World leaders commit to ambitious carbon reduction targets. '
            'Environmental activists celebrate this milestone in climate action.',
        category: 'Environment',
        contentType: ContentType.video,
        mediaUrl:
            'https://commondatastorage.googleapis.com/gtv-videos-bucket/sample/ElephantsDream.mp4',
        status: PostStatus.approved,
        createdAt: now.subtract(const Duration(hours: 12)),
        publishedAt: now.subtract(const Duration(hours: 12)),
        hashtags: ['Climate', 'Environment', 'Breaking', 'LiveUpdate'],
        likesCount: 3421,
        sharesCount: 987,
        bookmarksCount: 1567,
      ),

      // 5. PDF Post - Quick Reference Guide
      Post(
        id: 'pdf_post_1',
        authorId: 'eagle_admin',
        authorName: 'Eagle TV Admin',
        caption:
            '📄 QUICK REFERENCE GUIDE: Everything You Need to Know! '
            'Comprehensive guide covering key topics and essential information. '
            'Download and save for offline reading. #Guide #Reference #MustRead',
        category: 'Education',
        contentType: ContentType.pdf,
        pdfFilePath:
            '/home/vinay/Desktop/EagleTV_Flutter/docs/QUICK_REFERENCE.pdf',
        status: PostStatus.approved,
        createdAt: now.subtract(const Duration(hours: 24)),
        publishedAt: now.subtract(const Duration(hours: 24)),
        hashtags: ['Education', 'Reference', 'Guide', 'PDF'],
        likesCount: 2156,
        sharesCount: 654,
        bookmarksCount: 3456,
      ),

      // 6. Article Post - Opinion Piece
      Post(
        id: 'article_post_1',
        authorId: 'opinion_writer',
        authorName: 'Opinion Writer',
        caption: 'The Future of Remote Work: A New Era Begins',
        category: 'Business',
        contentType: ContentType.article,
        articleContent:
            '''As we navigate through unprecedented times, the landscape of work has undergone a dramatic transformation. Remote work, once considered a luxury or perk, has now become the norm for millions around the world.

This shift brings both opportunities and challenges. Companies are discovering that productivity doesn't necessarily require physical office spaces, while employees are learning to balance professional responsibilities with home life.

The question is no longer whether remote work will continue, but how we can make it more effective, sustainable, and inclusive for all.

Key considerations include:
• Work-life balance strategies
• Technology infrastructure requirements
• Team collaboration in virtual environments
• Mental health and wellbeing support
• Future of office spaces

As we move forward, one thing is certain: the workplace of tomorrow will look very different from the one we knew before.''',
        status: PostStatus.approved,
        createdAt: now.subtract(const Duration(days: 1)),
        publishedAt: now.subtract(const Duration(days: 1)),
        hashtags: ['RemoteWork', 'Future', 'Business', 'Opinion'],
        likesCount: 892,
        sharesCount: 234,
        bookmarksCount: 567,
      ),

      // 7. Poetry Post - Creative Content
      Post(
        id: 'poetry_post_1',
        authorId: 'creative_corner',
        authorName: 'Creative Corner',
        caption: '✨ "Digital Dreams" - A Modern Reflection',
        category: 'Lifestyle',
        contentType: ContentType.poetry,
        poemVerses: [
          'In pixels and bytes, our stories unfold,',
          'Through screens of glass, connections of gold.',
          '',
          'A world united, yet apart we stand,',
          'Digital hearts in a virtual land.',
          '',
          'We scroll and tap, we like and share,',
          'Seeking meaning in the digital air.',
          '',
          'But beneath it all, we\'re still the same,',
          'Human souls who long to proclaim:',
          '',
          'That love transcends the wires and code,',
          'And hope still lights our earthly road.',
        ],
        status: PostStatus.approved,
        createdAt: now.subtract(const Duration(days: 2)),
        publishedAt: now.subtract(const Duration(days: 2)),
        hashtags: ['Poetry', 'Creative', 'Digital', 'Modern'],
        likesCount: 456,
        sharesCount: 89,
        bookmarksCount: 234,
      ),

      // 8. Story Post - Narrative
      Post(
        id: 'story_post_1',
        authorId: 'storyteller',
        authorName: 'The Storyteller',
        caption: '📖 The Last Train Home - A Short Story',
        category: 'Lifestyle',
        contentType: ContentType.story,
        articleContent:
            '''The platform was empty, save for an old man sitting on a worn wooden bench. His weathered hands clutched a leather suitcase, its surface scarred with the memories of countless journeys.

"Last train to anywhere," he muttered to himself, a sad smile crossing his face.

Sarah approached cautiously, her footsteps echoing in the vast, dimly lit station. "Excuse me," she said softly, "is this the platform for the midnight express?"

The old man looked up, his eyes twinkling with an otherworldly light. "Depends on where you're trying to go, young lady."

"Home," she replied without hesitation.

"Ah," he nodded knowingly, "the most important destination of all. Please, sit."

As Sarah settled onto the bench, the old man began to speak of his own journey—decades of searching, wandering, and finally understanding that home was never a place, but a feeling carried within.

When the train finally arrived, illuminated against the darkness like a beacon of hope, they both boarded. And as it pulled away from the station, Sarah realized she wasn't just going home—she was already there.''',
        status: PostStatus.approved,
        createdAt: now.subtract(const Duration(days: 3)),
        publishedAt: now.subtract(const Duration(days: 3)),
        hashtags: ['Story', 'Fiction', 'ShortStory', 'Creative'],
        likesCount: 678,
        sharesCount: 145,
        bookmarksCount: 423,
      ),
    ];
  }
}
