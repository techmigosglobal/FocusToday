import '../services/language_service.dart';

/// App Localizations
/// Translation strings for all supported languages
class AppLocalizations {
  final AppLanguage language;

  AppLocalizations(this.language);

  // Common UI
  String get home => _translate('Home', 'హోమ్', 'होम');
  String get explore => _translate('Explore', 'అన్వేషించండి', 'एक्सप्लोर');
  String get profile => _translate('Profile', 'ప్రొఫైల్', 'प्रोफ़ाइल');
  String get search => _translate('Search', 'వెతకండి', 'खोजें');
  String get logout => _translate('Logout', 'లాగౌట్', 'लॉगआउट');
  
  // Actions
  String get like => _translate('Like', 'ఇష్టం', 'पसंद');
  String get comment => _translate('Comment', 'వ్యాఖ్య', 'टिप्पणी');
  String get share => _translate('Share', 'షేర్', 'साझा करें');
  String get more => _translate('More', 'మరిన్ని', 'और');
  String get edit => _translate('Edit', 'ఎడిట్', 'संपादित करें');
  String get delete => _translate('Delete', 'తొలగించు', 'हटाएं');
  String get save => _translate('Save', 'సేవ్', 'सहेजें');
  String get cancel => _translate('Cancel', 'రద్దు', 'रद्द करें');
  
  // Categories
  String get news => _translate('News', 'వార్తలు', 'समाचार');
  String get entertainment => _translate('Entertainment', 'వినోదం', 'मनोरंजन');
  String get sports => _translate('Sports', 'క్రీడలు', 'खेल');
  String get politics => _translate('Politics', 'రాజకీయాలు', 'राजनीति');
  String get technology => _translate('Technology', 'టెక్నాలజీ', 'प्रौद्योगिकी');
  String get health => _translate('Health', 'ఆరోగ్యం', 'स्वास्थ्य');
  String get business => _translate('Business', 'వ్యాపారం', 'व्यापार');
  String get other => _translate('Other', 'ఇతర', 'अन्य');
  
  // Profile
  String get posts => _translate('Posts', 'పోస్ట్‌లు', 'पोस्ट');
  String get bookmarks => _translate('Bookmarks', 'బుక్‌మార్క్‌లు', 'बुकमार्क');
  String get editProfile => _translate('Edit Profile', 'ప్రొఫైల్ ఎడిట్', 'प्रोफ़ाइल संपादित करें');
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
  String get createPost => _translate('Create Post', 'పోస్ట్ సృష్టించు', 'पोस्ट बनाएं');
  String get caption => _translate('Caption', 'శీర్షిక', 'कैप्शन');
  String get category => _translate('Category', 'వర్గం', 'श्रेणी');
  String get uploadMedia => _translate('Upload Media', 'మీడియా అప్‌లోడ్', 'मीडिया अपलोड करें');
  String get submit => _translate('Submit', 'సమర్పించు', 'जमा करें');
  
  // Moderation
  String get moderation => _translate('Moderation', 'మోడరేషన్', 'मॉडरेशन');
  String get approve => _translate('Approve', 'ఆమోదించు', 'स्वीकृत करें');
  String get reject => _translate('Reject', 'తిరస్కరించు', 'अस्वीकार करें');
  String get pending => _translate('Pending', 'పెండింగ్', 'लंबित');
  
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
  String get noPostsYet => _translate('No posts yet', 'ఇంకా పోస్ట్‌లు లేవు', 'अभी तक कोई पोस्ट नहीं');
  String get noResults => _translate('No results found', 'ఫలితాలు లేవు', 'कोई परिणाम नहीं मिला');
  String get loading => _translate('Loading...', 'లోడ్ అవుతోంది...', 'लोड हो रहा है...');
  
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
      default:
        return other;
    }
  }
}
