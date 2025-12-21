import '../services/language_service.dart';

/// App Localizations
/// Translation strings for all supported languages
class AppLocalizations {
  final AppLanguage language;

  AppLocalizations(this.language);

  // Common UI
  String get home => _translate('Home', 'హోమ్', 'होम');
  String get explore => _translate('Explore', 'అన్వేషించండి', 'एक్सप्लोर');
  String get profile => _translate('Profile', 'ప్రొఫైల్', 'प्रोफ़ाइल');
  String get search => _translate('Search', 'వెతకండి', 'खोजें');
  String get logout => _translate('Logout', 'లాగౌట్', 'लॉगआउट');
  String get settings => _translate('Settings', 'సెట్టింగ్‌లు', 'सेटिंग्स');

  // Actions
  String get like => _translate('Like', 'ఇష్టం', 'पसंद');
  String get comment => _translate('Comment', 'వ్యాఖ్య', 'टिप्पणी');
  String get share => _translate('Share', 'షేర్', 'साझा करें');
  String get more => _translate('More', 'మరిన్ని', 'और');
  String get edit => _translate('Edit', 'ఎడిట్', 'संपादित करें');
  String get delete => _translate('Delete', 'తొలగించు', 'हटाएं');
  String get save => _translate('Save', 'సేవ్', 'सहेजें');
  String get cancel => _translate('Cancel', 'రద్దు', 'रद्द करें');
  String get submit => _translate('Submit', 'సమర్పించు', 'जमा करें');
  String get ok => _translate('OK', 'సరే', 'ठीक है');

  // Categories
  String get news => _translate('News', 'వార్తలు', 'समाचार');
  String get entertainment => _translate('Entertainment', 'వినోదం', 'मनोरंजन');
  String get sports => _translate('Sports', 'క్రీడలు', 'खेल');
  String get politics => _translate('Politics', 'రాజకీయాలు', 'राजनीति');
  String get technology =>
      _translate('Technology', 'టెక్నాలజీ', 'प्रौद्योगिकी');
  String get health => _translate('Health', 'ఆరోగ్యం', 'स्वास्थ्य');
  String get business => _translate('Business', 'వ్యాపారం', 'व्यापार');
  String get education => _translate('Education', 'విద్య', 'शिक्षा');
  String get other => _translate('Other', 'ఇతర', 'अन्य');

  // Profile
  String get posts => _translate('Posts', 'పోస్ట్‌లు', 'पोस्ट');
  String get bookmarks => _translate('Bookmarks', 'బుక్‌మార్క్‌లు', 'बुकमार्क');
  String get editProfile =>
      _translate('Edit Profile', 'ప్రొఫైల్ ఎడిట్', 'प्रोफ़ाइल संपादित करें');
  String get displayName => _translate('Display Name', 'పేరు', 'नाम');
  String get bio => _translate('Bio', 'బయో', 'बायो');

  // Search
  String get searchHint => _translate(
    'Search posts, users, hashtags...',
    'పోస్ట్‌లు, వినియోగదారులు, హ్యాష్‌ట్యాగ్‌లు వెతకండి...',
    'पोस्ट, उपयोगकर्ता, हैशटैग खोजें...',
  );
  String get recent => _translate('Recent', 'ఇటీవలి', 'हाल ही में');
  String get trending => _translate('Trending', 'ట్రెండింగ్', 'ट्रेंडिंग');
  String get popular => _translate('Popular', 'ప్రసిద్ధమైనది', 'लोकप्रिय');

  // Content Creation
  String get createPost =>
      _translate('Create Post', 'పోస్ట్ సృష్టించు', 'पोस्ट बनाएं');
  String get caption => _translate('Caption', 'శీర్షిక', 'कैप्शन');
  String get category => _translate('Category', 'వర్గం', 'श्रेणी');
  String get uploadMedia =>
      _translate('Upload Media', 'మీడియా అప్‌లోడ్', 'मीडिया अपलोड करें');
  String get captionHint =>
      _translate('What\'s happening?', 'ఏమి జరుగుతోంది?', 'क्या हो रहा है?');
  String get captionRequired => _translate(
    'Please enter a caption',
    'దయచేసి శీర్షిక నమోదు చేయండి',
    'कृपया कैप्शन दर्ज करें',
  );
  String get captionMinLength => _translate(
    'Caption must be at least 10 characters',
    'శీర్షిక కనీసం 10 అక్షరాలు ఉండాలి',
    'कैप्शन कम से कम 10 अक्षर होना चाहिए',
  );
  String get mediaPreview =>
      _translate('Media Preview', 'మీడియా ప్రివ్యూ', 'मीडिया प्रीव्यू');
  String get addMedia => _translate(
    'Add Media (Optional)',
    'మీడియా జోడించండి (ఐచ్ఛికం)',
    'मीडिया जोड़ें (वैकल्पिक)',
  );
  String get imageLabel => _translate('Image', 'చిత్రం', 'छवि');
  String get videoLabel => _translate('Video', 'వీడియో', 'वीडियो');
  String get pdfLabel =>
      _translate('PDF Document', 'PDF డాక్యుమెంట్', 'PDF दस्तावेज़');
  String get postReviewInfo => _translate(
    'Your post will be reviewed by admins before publishing',
    'మీ పోస్ట్ ప్రచురణకు ముందు అడ్మిన్‌లు సమీక్షిస్తారు',
    'आपकी पोस्ट प्रकाशन से पहले एडमिन द्वारा समीक्षा की जाएगी',
  );
  String get postSubmitted => _translate(
    'Post Submitted!',
    'పోస్ట్ సమర్పించబడింది!',
    'पोस्ट सबमिट हो गई!',
  );
  String get postPendingReview => _translate(
    'Your content is now pending review. You\'ll be notified once it\'s approved.',
    'మీ కంటెంట్ ఇప్పుడు సమీక్షలో ఉంది. ఆమోదించబడిన తర్వాత మీకు తెలియజేయబడుతుంది.',
    'आपकी सामग्री अब समीक्षाधीन है। स्वीकृत होने पर आपको सूचित किया जाएगा।',
  );

  // Moderation
  String get moderation => _translate('Moderation', 'మోడరేషన్', 'मॉडरेशन');
  String get approve => _translate('Approve', 'ఆమోదించు', 'स्वीकृत करें');
  String get reject => _translate('Reject', 'తిరస్కరించు', 'अस्वीकार करें');
  String get pending => _translate('Pending', 'పెండింగ్', 'लंबित');
  String get approved => _translate('Approved', 'ఆమోదించబడింది', 'स्वीकृत');
  String get rejected => _translate('Rejected', 'తిరస్కరించబడింది', 'अस्वीकृत');

  // Time
  String get justNow => _translate('Just now', 'ఇప్పుడే', 'अभी');
  String minutesAgo(int minutes) => _translate(
    '$minutes min ago',
    '$minutes నిమిషాల క్రితం',
    '$minutes मिनट पहले',
  );
  String hoursAgo(int hours) => _translate(
    '$hours hour${hours > 1 ? 's' : ''} ago',
    '$hours గంటల క్రితం',
    '$hours घंटे पहले',
  );
  String daysAgo(int days) => _translate(
    '$days day${days > 1 ? 's' : ''} ago',
    '$days రోజుల క్రితం',
    '$days दिन पहले',
  );

  // Messages
  String get noPostsYet => _translate(
    'No posts yet',
    'ఇంకా పోస్ట్‌లు లేవు',
    'अभी तक कोई पोस्ट नहीं',
  );
  String get noResults =>
      _translate('No results found', 'ఫలితాలు లేవు', 'कोई परिणाम नहीं मिला');
  String get loading =>
      _translate('Loading...', 'లోడ్ అవుతోంది...', 'लोड हो रहा है...');
  String get comingSoon =>
      _translate('Coming soon!', 'త్వరలో వస్తోంది!', 'जल्द आ रहा है!');

  // Profile specific
  String get upgradeToPremium => _translate(
    'Upgrade to Premium',
    'ప్రీమియమ్‌కు అప్‌గ్రేడ్ చేయండి',
    'प्रीमियम में अपग्रेड करें',
  );
  String get startCreatingContent => _translate(
    'Start creating content!',
    'కంటెంట్ సృష్టించడం ప్రారంభించండి!',
    'सामग्री बनाना शुरू करें!',
  );

  // Auth specific
  String get welcomeTo => _translate(
    'Welcome to EagleTV',
    'EagleTV కు స్వాగతం',
    'EagleTV में आपका स्वागत है',
  );
  String get enterPhoneNumber => _translate(
    'Enter your phone number to continue',
    'కొనసాగించడానికి మీ ఫోన్ నంబర్ నమోదు చేయండి',
    'जारी रखने के लिए अपना फ़ोन नंबर दर्ज करें',
  );
  String get sendOTP => _translate('Send OTP', 'OTP పంపండి', 'OTP भेजें');
  String get privacyPolicy =>
      _translate('Privacy Policy', 'గోప్యతా విధానం', 'गोपनीयता नीति');

  // Content Types
  String get tapToPlayVideo => _translate(
    'Tap to Play Video',
    'వీడియో ప్లే చేయడానికి నొక్కండి',
    'वीडियो चलाने के लिए टैप करें',
  );
  String get tapToReadPdf => _translate(
    'Tap to Read PDF',
    'PDF చదవడానికి నొక్కండి',
    'PDF पढ़ने के लिए टैप करें',
  );
  String get readMore => _translate('Read More', 'మరింత చదవండి', 'और पढ़ें');

  // Auth
  String get login => _translate('Login', 'లాగిన్', 'लॉगिन');
  String get phoneNumber =>
      _translate('Phone Number', 'ఫోన్ నంబర్', 'फ़ोन नंबर');
  String get verifyOtp =>
      _translate('Verify OTP', 'OTP ధృవీకరించండి', 'OTP सत्यापित करें');
  String get welcomeBack =>
      _translate('Welcome Back!', 'తిరిగి స్వాగతం!', 'वापस स्वागत है!');

  // Helper method to translate based on current language
  String _translate(String en, String te, String hi) {
    switch (language) {
      case AppLanguage.telugu:
        return te;
      case AppLanguage.hindi:
        return hi;
      default:
        return en;
    }
  }

  // Get category name by key
  String getCategoryName(String categoryKey) {
    switch (categoryKey.toLowerCase()) {
      case 'news':
        return news;
      case 'entertainment':
        return entertainment;
      case 'sports':
        return sports;
      case 'politics':
        return politics;
      case 'technology':
        return technology;
      case 'health':
        return health;
      case 'business':
        return business;
      case 'education':
        return education;
      default:
        return other;
    }
  }
}
