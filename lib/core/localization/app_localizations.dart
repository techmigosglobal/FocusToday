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
  String get searchFieldSemantics => _translate(
    'Search posts, users, and hashtags',
    'పోస్ట్‌లు, వినియోగదారులు, హ్యాష్‌ట్యాగ్‌లను వెతకండి',
    'पोस्ट, उपयोगकर्ता और हैशटैग खोजें',
  );
  String get filters => _translate('Filters', 'ఫిల్టర్లు', 'फ़िल्टर');
  String get filterResults => _translate(
    'Filter Results',
    'ఫలితాలను ఫిల్టర్ చేయండి',
    'परिणाम फ़िल्टर करें',
  );
  String get clear => _translate('Clear', 'తుడిచివేయి', 'साफ़ करें');
  String get applyFilters =>
      _translate('Apply Filters', 'ఫిల్టర్లు వర్తింపజేయి', 'फ़िल्टर लागू करें');
  String get discover => _translate('Discover', 'కనుగొను', 'डिस्कवर');
  String get discoverSubtitle => _translate(
    'Top stories, trending topics & voices',
    'ముఖ్య కథలు, ట్రెండింగ్ అంశాలు & స్వరాలు',
    'शीर्ष कहानियां, ट्रेंडिंग विषय और आवाज़ें',
  );
  String get translating =>
      _translate('Translating...', 'అనువదిస్తోంది...', 'अनुवाद हो रहा है...');
  String postsCount(int count) =>
      _translate('$count Posts', '$count పోస్ట్‌లు', '$count पोस्ट');
  String usersCount(int count) =>
      _translate('$count Users', '$count వినియోగదారులు', '$count उपयोगकर्ता');
  String get noResultsFound => _translate(
    'No results found',
    'ఫలితాలు కనబడలేదు',
    'कोई परिणाम नहीं मिला',
  );
  String get tryDifferentKeywords => _translate(
    'Try different keywords',
    'వేరే కీవర్డ్‌లతో ప్రయత్నించండి',
    'अलग कीवर्ड आज़माएं',
  );
  String get tapToDiscoverPosts => _translate(
    'Tap to discover posts',
    'పోస్ట్‌లను కనుగొనడానికి తాకండి',
    'पोस्ट खोजने के लिए टैप करें',
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
  String get articleLabel => _translate('Article', 'వ్యాసం', 'लेख');
  String get storyLabel => _translate('Story', 'కథ', 'कहानी');
  String get poetryLabel => _translate('Poetry', 'కవిత్వం', 'कविता');
  String get textLabel => _translate('Text', 'పాఠ్యం', 'टेक्स्ट');
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
  String weeksAgo(int weeks) => _translate(
    '$weeks week${weeks > 1 ? 's' : ''} ago',
    '$weeks వారాల క్రితం',
    '$weeks हफ्ते पहले',
  );
  String monthsAgo(int months) => _translate(
    '$months month${months > 1 ? 's' : ''} ago',
    '$months నెలల క్రితం',
    '$months महीने पहले',
  );
  String yearsAgo(int years) => _translate(
    '$years year${years > 1 ? 's' : ''} ago',
    '$years సంవత్సరాల క్రితం',
    '$years साल पहले',
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
  String get flipToRead =>
      _translate('Flip to read', 'చదవడానికి తిప్పండి', 'पढ़ने के लिए पलटें');

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
    'Welcome to Focus Today',
    'Focus Today కు స్వాగతం',
    'Focus Today में आपका स्वागत है',
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
  String get tapToReadFull => _translate(
    'Tap to read full',
    'పూర్తిగా చదవడానికి నొక్కండి',
    'पूरा पढ़ने के लिए टैप करें',
  );
  String get readMore => _translate('Read More', 'మరింత చదవండి', 'और पढ़ें');

  // Auth
  String get login => _translate('Login', 'లాగిన్', 'लॉगिन');
  String get signUp => _translate('Sign Up', 'నమోదు', 'साइन अप');
  String get email => _translate('Email', 'ఇమెయిల్', 'ईमेल');
  String get password => _translate('Password', 'పాస్వర్డ్', 'पासवर्ड');
  String get phoneNumber =>
      _translate('Phone Number', 'ఫోన్ నంబర్', 'फ़ोन नंबर');
  String get verifyOtp =>
      _translate('Verify OTP', 'OTP ధృవీకరించండి', 'OTP सत्यापित करें');
  String get welcomeBack =>
      _translate('Welcome Back!', 'తిరిగి స్వాగతం!', 'वापस स्वागत है!');
  String get enterEmailPassword => _translate(
    'Enter your email and password to continue',
    'కొనసాగించడానికి మీ ఇమెయిల్ మరియు పాస్‌వర్డ్ నమోదు చేయండి',
    'जारी रखने के लिए अपना ईमेल और पासवर्ड दर्ज करें',
  );

  // Subscription
  String get subscription =>
      _translate('Subscription', 'సబ్‌స్క్రిప్షన్', 'सब्सक्रिप्शन');
  String get freePlan => _translate('Free', 'ఉచితం', 'मुफ़्त');
  String get premiumPlan => _translate('Premium', 'ప్రీమియమ్', 'प्रीमियम');
  String get elitePlan => _translate('Elite', 'ఎలైట్', 'एलीट');
  String get unlockPremiumFeatures => _translate(
    'Unlock Premium Features',
    'ప్రీమియమ్ ఫీచర్లను అన్‌లాక్ చేయండి',
    'प्रीमियम सुविधाएं अनलॉक करें',
  );
  String get getExclusiveAccess => _translate(
    'Get access to exclusive content and features',
    'ప్రత్యేక కంటెంట్ మరియు ఫీచర్లకు యాక్సెస్ పొందండి',
    'विशेष सामग्री और सुविधाओं तक पहुंच प्राप्त करें',
  );
  String get subscribeNow => _translate(
    'Subscribe Now',
    'ఇప్పుడే సబ్‌స్క్రైబ్ చేయండి',
    'अभी सब्सक्राइब करें',
  );
  String get continueWithFree => _translate(
    'Continue with Free',
    'ఉచితంగా కొనసాగించండి',
    'मुफ़्त जारी रखें',
  );
  String get subscriptionActivated => _translate(
    'Subscription Activated!',
    'సబ్‌స్క్రిప్షన్ యాక్టివేట్ అయింది!',
    'सब्सक्रिप्शन सक्रिय हो गया!',
  );
  String get enjoyPremiumFeatures => _translate(
    'Enjoy all premium features',
    'అన్ని ప్రీమియమ్ ఫీచర్లను ఆనందించండి',
    'सभी प्रीमियम सुविधाओं का आनंद लें',
  );
  String get basicNewsAccess => _translate(
    'Basic news access',
    'బేసిక్ న్యూస్ యాక్సెస్',
    'बेसिक न्यूज़ एक्सेस',
  );
  String get limitedContent =>
      _translate('Limited content', 'పరిమిత కంటెంట్', 'सीमित सामग्री');
  String get adsSupported =>
      _translate('Ads supported', 'యాడ్స్ మద్దతు ఉంది', 'विज्ञापन समर्थित');
  String get adFreeExperience => _translate(
    'Ad-free experience',
    'యాడ్-ఫ్రీ అనుభవం',
    'विज्ञापन-मुक्त अनुभव',
  );
  String get exclusiveArticles =>
      _translate('Exclusive articles', 'ప్రత్యేక ఆర్టికల్స్', 'विशेष लेख');
  String get offlineReading =>
      _translate('Offline reading', 'ఆఫ్‌లైన్ రీడింగ్', 'ऑफ़लाइन पढ़ना');
  String get prioritySupport =>
      _translate('Priority support', 'ప్రాధాన్య మద్దతు', 'प्राथमिकता समर्थन');
  String get earlyAccess => _translate(
    'Early access to content',
    'కంటెంట్‌కు ముందస్తు యాక్సెస్',
    'सामग्री तक शीघ्र पहुंच',
  );
  String get exclusiveInterviews => _translate(
    'Exclusive interviews',
    'ప్రత్యేక ఇంటర్వ్యూలు',
    'विशेष साक्षात्कार',
  );
  String get premiumBadge =>
      _translate('Premium badge', 'ప్రీమియమ్ బ్యాడ్జ్', 'प्रीमियम बैज');
  String get perMonth => _translate('/month', '/నెల', '/माह');
  String get forever => _translate('forever', 'ఎల్లప్పుడూ', 'हमेशा के लिए');

  // Settings
  String get preferences =>
      _translate('Preferences', 'ప్రాధాన్యతలు', 'प्राथमिकताएं');
  String get languageLabel => _translate('Language', 'భాష', 'भाषा');
  String get selectLanguage => _translate(
    'Select your preferred language',
    'మీకు ఇష్టమైన భాషను ఎంచుకోండి',
    'अपनी पसंदीदा भाषा चुनें',
  );
  String get darkMode => _translate('Dark Mode', 'డార్క్ మోడ్', 'डार्क मोड');
  String get enableDarkTheme => _translate(
    'Enable dark theme',
    'డార్క్ థీమ్ ఎనేబుల్ చేయండి',
    'डार्क थीम सक्षम करें',
  );
  String get autoPlayVideos =>
      _translate('Auto-play Videos', 'ఆటో-ప్లే వీడియోలు', 'ऑटो-प्ले वीडियो');
  String get playVideosInFeed => _translate(
    'Play videos automatically in feed',
    'ఫీడ్‌లో వీడియోలను స్వయంచాలకంగా ప్లే చేయండి',
    'फ़ीड में वीडियो स्वचालित रूप से चलाएं',
  );
  String get notifications =>
      _translate('Notifications', 'నోటిఫికేషన్లు', 'सूचनाएं');
  String get pushNotifications =>
      _translate('Push Notifications', 'పుష్ నోటిఫికేషన్లు', 'पुश नोटिफिकेशन');
  String get receiveUpdates => _translate(
    'Receive news and updates',
    'వార్తలు మరియు అప్‌డేట్లు స్వీకరించండి',
    'समाचार और अपडेट प्राप्त करें',
  );
  String get about => _translate('About', 'గురించి', 'के बारे में');
  String get termsOfService =>
      _translate('Terms of Service', 'సేవా నిబంధనలు', 'सेवा की शर्तें');
  String get appVersion => _translate('App Version', 'యాప్ వర్షన్', 'ऐप वर्शन');
  String get errorLabel => _translate('Error', 'లోపం', 'त्रुटि');
  String get admin => _translate('Admin', 'అడ్మిన్', 'एडमिन');
  String get reporter => _translate('Reporter', 'రిపోర్టర్', 'रिपोर्टर');
  String get user => _translate('User', 'యూజర్', 'उपयोगकर्ता');

  // Notifications Screen
  String get markAllRead => _translate(
    'Mark all read',
    'అన్నీ చదివినట్లు మార్క్ చేయండి',
    'सभी पढ़े हुए चिह्नित करें',
  );
  String get noNotifications =>
      _translate('No notifications', 'నోటిఫికేషన్లు లేవు', 'कोई सूचना नहीं');
  String get postApproved =>
      _translate('Post Approved', 'పోస్ట్ ఆమోదించబడింది', 'पोस्ट स्वीकृत');
  String get postRejectedNotif =>
      _translate('Post Rejected', 'పోస్ట్ తిరస్కరించబడింది', 'पोस्ट अस्वीकृत');
  String get newContentAvailable => _translate(
    'New Content Available',
    'కొత్త కంటెంట్ అందుబాటులో ఉంది',
    'नई सामग्री उपलब्ध',
  );
  String get systemUpdate =>
      _translate('System Update', 'సిస్టమ్ అప్‌డేట్', 'सिस्टम अपडेट');

  // Stories & Articles
  String get stories => _translate('Stories', 'కథలు', 'कहानियां');
  String get articles => _translate('Articles', 'వ్యాసాలు', 'लेख');
  String get noStoriesYet =>
      _translate('No stories yet', 'ఇంకా కథలు లేవు', 'अभी तक कोई कहानी नहीं');
  String get noArticlesYet => _translate(
    'No articles yet',
    'ఇంకా వ్యాసాలు లేవు',
    'अभी तक कोई लेख नहीं',
  );
  String get followers => _translate('Followers', 'ఫాలోవర్లు', 'फ़ॉलोअर्स');
  String get following =>
      _translate('Following', 'ఫాలో అవుతున్నారు', 'फ़ॉलो कर रहे हैं');
  String get saved => _translate('Saved', 'సేవ్ చేయబడింది', 'सहेजे गए');

  // Moderation
  String get noPostsHere => _translate(
    'No posts here',
    'ఇక్కడ పోస్ట్‌లు లేవు',
    'यहां कोई पोस्ट नहीं',
  );
  String get postsWillAppear => _translate(
    'Posts will appear here when available',
    'అందుబాటులో ఉన్నప్పుడు పోస్ట్‌లు ఇక్కడ కనిపిస్తాయి',
    'उपलब्ध होने पर पोस्ट यहां दिखाई देंगे',
  );
  String get rejectPost =>
      _translate('Reject Post', 'పోస్ట్ తిరస్కరించు', 'पोस्ट अस्वीकार करें');
  String get provideReason => _translate(
    'Provide a reason for rejection:',
    'తిరస్కరణకు కారణం తెలియజేయండి:',
    'अस्वीकृति का कारण बताएं:',
  );
  String get enterReason => _translate(
    'Enter reason...',
    'కారణం నమోదు చేయండి...',
    'कारण दर्ज करें...',
  );
  String get moderationAccessRequired => _translate(
    'Moderation Access Required',
    'మోడరేషన్ యాక్సెస్ అవసరం',
    'मॉडरेशन एक्सेस आवश्यक',
  );
  String get onlyAdminRolesCanModerate => _translate(
    'Only admin and super admin roles can moderate content.',
    'కేవలం అడ్మిన్ మరియు సూపర్ అడ్మిన్ పాత్రలకే కంటెంట్ మోడరేట్ చేసే అనుమతి ఉంది.',
    'केवल एडमिन और सुपर एडमिन भूमिकाएं सामग्री का मॉडरेशन कर सकती हैं।',
  );
  String get errorLoadingPosts => _translate(
    'Error loading posts',
    'పోస్ట్‌లను లోడ్ చేయడంలో లోపం',
    'पोस्ट लोड करने में त्रुटि',
  );
  String get postApprovedSuccess =>
      _translate('Post approved!', 'పోస్ట్ ఆమోదించబడింది!', 'पोस्ट स्वीकृत!');
  String get postRejectedSuccess =>
      _translate('Post rejected', 'పోస్ట్ తిరస్కరించబడింది', 'पोस्ट अस्वीकृत');
  String get bulkReject =>
      _translate('Bulk Reject', 'బల్క్ తిరస్కరణ', 'एक साथ अस्वीकृत');
  String get violationCategory =>
      _translate('Violation Category', 'ఉల్లంఘన వర్గం', 'उल्लंघन श्रेणी');
  String get additionalReasonOptional => _translate(
    'Additional Reason (optional)',
    'అదనపు కారణం (ఐచ్ఛికం)',
    'अतिरिक्त कारण (वैकल्पिक)',
  );
  String get rejectAll =>
      _translate('Reject All', 'అన్నీ తిరస్కరించు', 'सभी अस्वीकृत करें');
  String get policyViolation =>
      _translate('Policy violation', 'పాలసీ ఉల్లంఘన', 'नीति उल्लंघन');
  String selectedCount(int count) =>
      _translate('$count selected', '$count ఎంపిక చేశారు', '$count चयनित');
  String get selectAllLabel =>
      _translate('Select All', 'అన్నీ ఎంపిక చేయండి', 'सभी चुनें');
  String pendingCount(int count) =>
      _translate('Pending ($count)', 'పెండింగ్ ($count)', 'लंबित ($count)');
  String approvedCount(int count) => _translate(
    'Approved ($count)',
    'ఆమోదించబడినవి ($count)',
    'स्वीकृत ($count)',
  );
  String rejectedCount(int count) => _translate(
    'Rejected ($count)',
    'తిరస్కరించబడినవి ($count)',
    'अस्वीकृत ($count)',
  );
  String get noPendingPosts => _translate(
    'No Pending Posts',
    'పెండింగ్ పోస్ట్‌లు లేవు',
    'कोई लंबित पोस्ट नहीं',
  );
  String get pendingPosts =>
      _translate('Pending Posts', 'పెండింగ్ పోస్ట్‌లు', 'लंबित पोस्ट');
  String get noApprovedPosts => _translate(
    'No Approved Posts',
    'ఆమోదించిన పోస్ట్‌లు లేవు',
    'कोई स्वीकृत पोस्ट नहीं',
  );
  String get noRejectedPosts => _translate(
    'No Rejected Posts',
    'తిరస్కరించిన పోస్ట్‌లు లేవు',
    'कोई अस्वीकृत पोस्ट नहीं',
  );
  String get newSubmissionsWillAppearHere => _translate(
    'New submissions will appear here for review.',
    'కొత్త సమర్పణలు సమీక్ష కోసం ఇక్కడ కనిపిస్తాయి.',
    'नई सबमिशन समीक्षा के लिए यहां दिखाई देंगी।',
  );
  String get approvedPostsWillAppearHere => _translate(
    'Approved posts will appear here.',
    'ఆమోదించిన పోస్ట్‌లు ఇక్కడ కనిపిస్తాయి.',
    'स्वीकृत पोस्ट यहां दिखाई देंगी।',
  );
  String get rejectedPostsWillAppearHere => _translate(
    'Rejected posts will appear here.',
    'తిరస్కరించిన పోస్ట్‌లు ఇక్కడ కనిపిస్తాయి.',
    'अस्वीकृत पोस्ट यहां दिखाई देंगी।',
  );

  // Comments
  String get noCommentsYet => _translate(
    'No comments yet',
    'ఇంకా వ్యాఖ్యలు లేవు',
    'अभी तक कोई टिप्पणी नहीं',
  );
  String get beFirstToComment => _translate(
    'Be the first to comment!',
    'మొదట వ్యాఖ్యానించండి!',
    'टिप्पणी करने वाले पहले व्यक्ति बनें!',
  );
  String get writeCommentHint => _translate(
    'Write a comment...',
    'వ్యాఖ్య రాయండి...',
    'एक टिप्पणी लिखें...',
  );
  String get comments => _translate('Comments', 'వ్యాఖ్యలు', 'टिप्पणियाँ');

  // Post Options
  String get copyLink =>
      _translate('Copy Link', 'లింక్ కాపీ చేయండి', 'लिंक कॉपी करें');
  String get reportPost =>
      _translate('Report Post', 'పోస్ట్‌ను నివేదించండి', 'पोस्ट रिपोर्ट करें');
  String get hidePost =>
      _translate('Hide Post', 'పోస్ట్‌ను దాచండి', 'पोस्ट छिपाएं');
  String get blockUser => _translate(
    'Block User',
    'యూజర్‌ను బ్లాక్ చేయండి',
    'उपयोगकर्ता को ब्लॉक करें',
  );

  // Dialogs
  String get reportPostTitle =>
      _translate('Report Post', 'పోస్ట్‌ను నివేదించండి', 'पोस्ट रिपोर्ट करें');
  String get reportPostMessage => _translate(
    'Are you sure you want to report this post?',
    'మీరు ఖచ్చితంగా ఈ పోస్ట్‌ను నివేదించాలనుకుంటున్నారా?',
    'क्या आप वाकई इस पोस्ट की रिपोर्ट करना चाहते हैं?',
  );
  String get reportConfirmation => _translate(
    'Post reported',
    'పోస్ట్ నివేదించబడింది',
    'पोस्ट रिपोर्ट की गई',
  );

  String get deletePostTitle =>
      _translate('Delete Post', 'పోస్ట్‌ను తొలగించండి', 'पोस्ट हटाएं');
  String get deletePostMessage => _translate(
    'Are you sure you want to delete this post?',
    'మీరు ఖచ్చితంగా ఈ పోస్ట్‌ను తొలగించాలనుకుంటున్నారా?',
    'क्या आप वाकई इस पोस्ट को हटाना चाहते हैं?',
  );
  String get deleteConfirmation =>
      _translate('Post deleted', 'పోస్ట్ తొలగించబడింది', 'पोस्ट हटा दी गई');

  String get blockUserTitle => _translate(
    'Block User',
    'యూజర్‌ను బ్లాక్ చేయండి',
    'उपयोगकर्ता को ब्लॉक करें',
  );
  String get blockUserMessage => _translate(
    'Are you sure you want to block this user?',
    'మీరు ఖచ్చితంగా ఈ వినియోగదారుని బ్లాక్ చేయాలనుకుంటున్నారా?',
    'क्या आप वाकई इस उपयोगकर्ता को ब्लॉक करना चाहते हैं?',
  );
  String get blockConfirmation => _translate(
    'User blocked',
    'వినియోగదారు బ్లాక్ చేయబడ్డారు',
    'उपयोगकर्ता अवरुद्ध',
  );

  // Actions
  String get report => _translate('Report', 'నివేదించండి', 'रिपोर्ट करें');
  String get block => _translate('Block', 'బ్లాక్ చేయండి', 'ब्लॉक करें');

  // Errors/Snackbars
  String get linkCopied => _translate(
    'Link copied to clipboard!',
    'లింక్ క్లిప్‌బోర్డ్‌కు కాపీ చేయబడింది!',
    'लिंक क्लिपबोर्ड पर कॉपी किया गया!',
  );
  String get postHidden => _translate(
    'Post hidden from feed',
    'ఫీడ్ నుండి పోస్ట్ దాచబడింది',
    'पोस्ट फ़ीड से छिपी हुई है',
  );
  String get failedToLoadPdf => _translate(
    'Failed to load PDF',
    'PDF లోడ్ చేయడం విఫలమైంది',
    'PDF लोड करने में विफल',
  );
  String get shareComingSoon => _translate(
    'Share feature coming soon',
    'షేర్ ఫీచర్ త్వరలో వస్తుంది',
    'शेयर फीचर जल्द आ रहा है',
  );

  // Continue button
  String get continueLabel => _translate('Continue', 'కొనసాగించు', 'जारी रखें');

  // Profile Dialogs & Extras
  String get logoutTitle => _translate('Logout', 'లాగౌట్', 'लॉग आउट');
  String get logoutMessage => _translate(
    'Are you sure you want to logout?',
    'మీరు ఖచ్చితంగా లాగౌట్ చేయాలనుకుంటున్నారా?',
    'क्या आप लॉग आउट करना चाहते हैं?',
  );

  String get publicUser =>
      _translate('PUBLIC USER', 'పబ్లిక్ యూజర్', 'पब्लिक यूजर');
  // Stats
  String likesCount(int count) => _translate(
    '$count ${count == 1 ? 'like' : 'likes'}',
    '$count ${count == 1 ? 'లైక్' : 'లైక్స్'}',
    '$count ${count == 1 ? 'लाइक' : 'लाइक्स'}',
  );
  String sharesCount(int count) => _translate(
    '$count ${count == 1 ? 'share' : 'shares'}',
    '$count ${count == 1 ? 'షేర్' : 'షేర్స్'}',
    '$count ${count == 1 ? 'शेयर' : 'शेयर्स'}',
  );
  String bookmarksCount(int count) => _translate(
    '$count ${count == 1 ? 'bookmark' : 'bookmarks'}',
    '$count ${count == 1 ? 'బుక్‌మార్క్' : 'బుక్‌మార్క్‌లు'}',
    '$count ${count == 1 ? 'बुकमार्क' : 'बुकमार्क'}',
  );

  String get checkOutPost => _translate(
    'Check out this post:',
    'ఈ పోస్ట్‌ను చూడండి:',
    'इस पोस्ट को देखें:',
  );
  String get commentsComingSoon => _translate(
    'Comments coming soon!',
    'వ్యాఖ్యలు త్వరలో వస్తాయి!',
    'टिप्पणियाँ जल्द आ रही हैं!',
  );

  String get upgradeToUnlock => _translate(
    'Upgrade to unlock premium features',
    'ప్రీమియం ఫీచర్‌లను అన్‌లాక్ చేయడానికి అప్‌గ్రేడ్ చేయండి',
    'प्रीमियम सुविधाओं को अनलॉक करने के लिए अपग्रेड करें',
  );
  String get active => _translate('ACTIVE', 'యాక్టివ్', 'सक्रिय');

  String get errorLoadingProfile => _translate(
    'Error loading profile',
    'ప్రొఫైల్ లోడ్ చేయడంలో లోపం',
    'प्रोफ़ाइल लोड करने में त्रुटि',
  );
  String get bookmarkRemoved => _translate(
    'Bookmark removed',
    'బుక్‌మార్క్ తీసివేయబడింది',
    'बुकमार्क हटा दिया गया',
  );
  String get errorRemovingBookmark => _translate(
    'Error removing bookmark',
    'బుక్‌మార్క్ తీసివేయడంలో లోపం',
    'बुकमार्क हटाने में त्रुटि',
  );

  // Edit Profile
  String get chooseFromGallery => _translate(
    'Choose from Gallery',
    'గ్యాలరీ నుండి ఎంచుకోండి',
    'गैलरी से चुनें',
  );
  String get takePhoto => _translate('Take Photo', 'ఫోటో తీయండి', 'फोटो लें');
  String get tapToChangeProfilePicture => _translate(
    'Tap to change profile picture',
    'ప్రొఫైల్ చిత్రాన్ని మార్చడానికి నొక్కండి',
    'प्रोफ़ाइल चित्र बदलने के लिए टैप करें',
  );
  String get bioHint => _translate(
    'Tell us about yourself...',
    'మీ గురించి మాకు చెప్పండి...',
    'अपने बारे में बताएं...',
  );
  String get profileVisibilityInfo => _translate(
    'Your profile information will be visible to all users',
    'మీ ప్రొఫైల్ సమాచారం వినియోగదారులందరికీ కనిపిస్తుంది',
    'आपकी प्रोफ़ाइल जानकारी सभी उपयोगकर्ताओं को दिखाई देगी',
  );
  String get profileUpdatedSuccess => _translate(
    'Profile updated successfully!',
    'ప్రొఫైల్ విజయవంతంగా నవీకరించబడింది!',
    'प्रोफ़ाइल सफलतापूर्वक अपडेट हो गई!',
  );

  String get nameRequired => _translate(
    'Please enter a display name',
    'దయచేసి పేరు నమోదు చేయండి',
    'कृपया नाम दर्ज करें',
  );
  String get nameMinLength => _translate(
    'Name must be at least 2 characters',
    'పేరు కనీసం 2 అక్షరాలు ఉండాలి',
    'नाम कम से कम 2 अक्षरों का होना चाहिए',
  );

  String get optional => _translate('Optional', 'ఐచ్ఛికం', 'वैकल्पिक');

  // ===== Feed / Subscription =====
  String get premiumContent =>
      _translate('Premium Content', 'ప్రీమియం కంటెంట్', 'प्रीमियम सामग्री');
  String subscriptionGateMessage(int days) => _translate(
    'This content is available to subscribers. It will be free for everyone in $days day${days == 1 ? '' : 's'}.',
    'ఈ కంటెంట్ సబ్‌స్క్రైబర్లకు మాత్రమే. $days రోజు${days == 1 ? '' : 'ల'}లో అందరికీ ఉచితం.',
    'यह सामग्री सदस्यों के लिए उपलब्ध है। $days दिन${days == 1 ? '' : 'ों'} में सबके लिए मुफ़्त होगी।',
  );
  String get maybeLater =>
      _translate('Maybe later', 'తర్వాత చూద్దాం', 'बाद में');
  String premiumFreeIn(int days) => _translate(
    'Premium · Free in ${days}d',
    'ప్రీమియం · $daysరో. ఉచితం',
    'प्रीमियम · $daysदि. में मुफ़्त',
  );
  String get tapToCreateFirstPost => _translate(
    'Tap + below to create your first post',
    'మీ మొదటి పోస్ట్ రాయడానికి + నొక్కండి',
    'अपनी पहली पोस्ट बनाने के लिए + दबाएं',
  );
  String get pullDownToRefresh => _translate(
    'Pull down to refresh',
    'రిఫ్రెష్ కోసం కిందకి లాగండి',
    'रीफ़्रेश करने के लिए नीचे खींचें',
  );
  String get failedToUpdateLikeTryAgain => _translate(
    'Failed to update like. Try again.',
    'లైక్ అప్‌డేట్ కాలేదు. మళ్లీ ప్రయత్నించండి.',
    'लाइक अपडेट नहीं हुआ। फिर से कोशिश करें।',
  );
  String get failedToUpdateBookmarkTryAgain => _translate(
    'Failed to update bookmark. Try again.',
    'బుక్‌మార్క్ అప్‌డేట్ కాలేదు. మళ్లీ ప్రయత్నించండి.',
    'बुकमार्क अपडेट नहीं हुआ। फिर से कोशिश करें।',
  );
  String get failedToTrackShareTryAgain => _translate(
    'Failed to track share. Try again.',
    'షేర్ ట్రాక్ కాలేదు. మళ్లీ ప్రయత్నించండి.',
    'शेयर ट्रैक नहीं हुआ। फिर से कोशिश करें।',
  );
  String get changeLanguageLabel =>
      _translate('Change language', 'భాష మార్చండి', 'भाषा बदलें');
  String get openNotificationsLabel => _translate(
    'Open notifications',
    'నోటిఫికేషన్‌లు తెరవండి',
    'सूचनाएं खोलें',
  );
  String get openProfileLabel =>
      _translate('Open profile', 'ప్రొఫైల్ తెరవండి', 'प्रोफ़ाइल खोलें');
  String get openSettingsLabel =>
      _translate('Open Settings', 'సెట్టింగ్‌లు తెరవండి', 'सेटिंग्स खोलें');
  String get scrollToRead => _translate(
    'Scroll to read',
    'చదవడానికి స్క్రోల్ చేయండి',
    'पढ़ने के लिए स्क्रॉल करें',
  );
  String get completeYourAccount => _translate(
    'Complete Your Account',
    'మీ ఖాతాను పూర్తి చేయండి',
    'अपना खाता पूरा करें',
  );
  String get addNamePhotoPreferencesInSettings => _translate(
    'Add your name, photo and preferences in settings',
    'సెట్టింగ్‌లలో మీ పేరు, ఫోటో మరియు ప్రాధాన్యతలను జోడించండి',
    'सेटिंग्स में अपना नाम, फोटो और प्राथमिकताएं जोड़ें',
  );

  // ===== Post Detail =====
  String minRead(int minutes) => _translate(
    '$minutes min read',
    '$minutes ని. చదవడం',
    '$minutes मिनट पठन',
  );
  String get endOfArticle =>
      _translate('End of article', 'వ్యాసం ముగిసింది', 'लेख समाप्त');
  String get tapToOpenPdf => _translate(
    'Tap to open PDF',
    'PDF తెరవడానికి నొక్కండి',
    'PDF खोलने के लिए टैप करें',
  );
  String get source => _translate('Source', 'మూలం', 'स्रोत');
  String endOfContent(String type) =>
      _translate('End of $type', '$type ముగిసింది', '$type समाप्त');
  String get small => _translate('Small', 'చిన్నది', 'छोटा');
  String get medium => _translate('Medium', 'మధ్యస్థం', 'मध्यम');
  String get large => _translate('Large', 'పెద్దది', 'बड़ा');
  String get extraLarge =>
      _translate('Extra Large', 'అత్యంత పెద్దది', 'अतिरिक्त बड़ा');
  String get read => _translate('Read', 'చదవండి', 'पढ़ें');

  // ===== Create Post =====
  String get draftFound =>
      _translate('Draft Found', 'డ్రాఫ్ట్ దొరికింది', 'ड्राफ्ट मिला');
  String get restoreDraftQuestion => _translate(
    'Would you like to restore your previous unfinished post draft?',
    'మునుపటి పూర్తి కాని పోస్ట్ డ్రాఫ్ట్‌ను పునరుద్ధరించాలనుకుంటున్నారా?',
    'क्या आप पिछला अधूरा पोस्ट ड्राफ्ट पुनर्स्थापित करना चाहते हैं?',
  );
  String get discard => _translate('Discard', 'తొలగించు', 'हटाएं');
  String get restore =>
      _translate('Restore', 'పునరుద్ధరించు', 'पुनर्स्थापित करें');
  String get draftSavedSuccessfully => _translate(
    'Draft saved successfully',
    'డ్రాఫ్ట్ విజయవంతంగా సేవ్ అయింది',
    'ड्राफ्ट सफलतापूर्वक सहेजा गया',
  );
  String get pleaseSelectContentType => _translate(
    'Please select a content type',
    'దయచేసి కంటెంట్ రకాన్ని ఎంచుకోండి',
    'कृपया सामग्री प्रकार चुनें',
  );
  String get atLeast3CharactersRequired => _translate(
    'At least 3 characters required',
    'కనీసం 3 అక్షరాలు అవసరం',
    'कम से कम 3 अक्षर आवश्यक हैं',
  );
  String get contentRequiredForTextPosts => _translate(
    'Content is required for text posts',
    'టెక్స్ట్ పోస్టులకు కంటెంట్ అవసరం',
    'टेक्स्ट पोस्ट के लिए सामग्री आवश्यक है',
  );
  String get pleaseAddMedia => _translate(
    'Please add media',
    'దయచేసి మీడియా జోడించండి',
    'कृपया मीडिया जोड़ें',
  );
  String get selectFromYourPhotos => _translate(
    'Select from your photos',
    'మీ ఫోటోల నుంచి ఎంచుకోండి',
    'अपनी तस्वीरों में से चुनें',
  );
  String get recordVideo => _translate(
    'Record Video',
    'వీడియో రికార్డ్ చేయండి',
    'वीडियो रिकॉर्ड करें',
  );
  String get useCamera =>
      _translate('Use camera', 'కెమెరా ఉపయోగించండి', 'कैमरा उपयोग करें');
  String errorWithMessage(String message) =>
      _translate('Error: $message', 'లోపం: $message', 'त्रुटि: $message');
  String get postPublished => _translate(
    'Post Published!',
    'పోస్ట్ ప్రచురించబడింది!',
    'पोस्ट प्रकाशित!',
  );
  String get postNowLiveInFeed => _translate(
    'Your post is now live in the feed!',
    'మీ పోస్ట్ ఇప్పుడు ఫీడ్‌లో లైవ్‌లో ఉంది!',
    'आपकी पोस्ट अब फ़ीड में लाइव है!',
  );
  String get done => _translate('Done', 'పూర్తైంది', 'पूर्ण');
  String get postingAccessRequired => _translate(
    'Posting Access Required',
    'పోస్ట్ చేయడానికి అనుమతి అవసరం',
    'पोस्ट करने की अनुमति आवश्यक',
  );
  String get postingAccessDescription => _translate(
    'This module is available for reporters and admin roles.',
    'ఈ మాడ్యూల్ రిపోర్టర్లు మరియు అడ్మిన్ పాత్రలకు అందుబాటులో ఉంది.',
    'यह मॉड्यूल रिपोर्टर और एडमिन भूमिकाओं के लिए उपलब्ध है।',
  );
  String get applyAsReporter => _translate(
    'Apply as Reporter',
    'రిపోర్టర్‌గా అప్లై చేయండి',
    'रिपोर्टर के रूप में आवेदन करें',
  );
  String get saveDraft =>
      _translate('Save Draft', 'డ్రాఫ్ట్ సేవ్ చేయండి', 'ड्राफ्ट सहेजें');
  String get typeStep => _translate('Type', 'రకం', 'प्रकार');
  String get contentStep => _translate('Content', 'కంటెంట్', 'सामग्री');
  String get previewStep => _translate('Preview', 'ప్రివ్యూ', 'पूर्वावलोकन');
  String get titleCaption =>
      _translate('Title / Caption', 'శీర్షిక / క్యాప్షన్', 'शीर्षक / कैप्शन');
  String get contentDescription =>
      _translate('Content / Description', 'కంటెంట్ / వివరణ', 'सामग्री / विवरण');
  String get writeCompellingHeadline => _translate(
    'Write a compelling headline...',
    'ఆకట్టుకునే శీర్షిక రాయండి...',
    'एक आकर्षक शीर्षक लिखें...',
  );
  String get writeYourContentHere => _translate(
    'Write your content here...',
    'మీ కంటెంట్ ఇక్కడ రాయండి...',
    'अपनी सामग्री यहाँ लिखें...',
  );
  String get addDescriptionStoryContext => _translate(
    'Add description, story, or additional context...',
    'వివరణ, కథ లేదా అదనపు సందర్భం జోడించండి...',
    'विवरण, कहानी या अतिरिक्त संदर्भ जोड़ें...',
  );
  String get writeFullContentOfPost => _translate(
    'Write the full content of your post',
    'మీ పోస్ట్ యొక్క పూర్తి కంటెంట్ రాయండి',
    'अपनी पोस्ट की पूरी सामग्री लिखें',
  );
  String get addAdditionalDetailsOptional => _translate(
    'Add additional details about your media (optional)',
    'మీడియా గురించి అదనపు వివరాలు జోడించండి (ఐచ్ఛికం)',
    'अपने मीडिया के बारे में अतिरिक्त विवरण जोड़ें (वैकल्पिक)',
  );
  String tapToAddMediaType(String mediaType) => _translate(
    'Tap to add $mediaType',
    '$mediaType జోడించడానికి నొక్కండి',
    '$mediaType जोड़ने के लिए टैप करें',
  );
  String get yourCaptionWillAppearHere => _translate(
    'Your caption will appear here...',
    'మీ క్యాప్షన్ ఇక్కడ కనిపిస్తుంది...',
    'आपका कैप्शन यहाँ दिखाई देगा...',
  );
  String get editContent =>
      _translate('Edit Content', 'కంటెంట్ సవరించండి', 'सामग्री संपादित करें');
  String get back => _translate('Back', 'వెనక్కి', 'वापस');
  String get next => _translate('Next', 'తదుపరి', 'अगला');
  String get submitForReview => _translate(
    'Submit for Review',
    'సమీక్షకు పంపండి',
    'समीक्षा हेतु सबमिट करें',
  );
  String uploadingPercent(String percent) => _translate(
    'Uploading $percent%',
    '$percent% అప్‌లోడ్ అవుతోంది',
    '$percent% अपलोड हो रहा है',
  );
  String get whatWouldYouLikeToShare => _translate(
    'What would you like to share?',
    'మీరు ఏమి పంచుకోవాలనుకుంటున్నారు?',
    'आप क्या साझा करना चाहेंगे?',
  );
  String get chooseContentTypeToCreate => _translate(
    'Choose the type of content you want to create',
    'మీరు సృష్టించాలనుకుంటున్న కంటెంట్ రకాన్ని ఎంచుకోండి',
    'आप जो सामग्री बनाना चाहते हैं उसका प्रकार चुनें',
  );
  String get imagePost => _translate('Image Post', 'చిత్ర పోస్ట్', 'छवि पोस्ट');
  String get sharePhotoWithAudience => _translate(
    'Share a photo with your audience',
    'మీ ప్రేక్షకులతో ఫోటో పంచుకోండి',
    'अपने दर्शकों के साथ एक फोटो साझा करें',
  );
  String get videoPost =>
      _translate('Video Post', 'వీడియో పోస్ట్', 'वीडियो पोस्ट');
  String get uploadVideoClip => _translate(
    'Upload a video clip',
    'వీడియో క్లిప్ అప్‌లోడ్ చేయండి',
    'वीडियो क्लिप अपलोड करें',
  );
  String get textPost =>
      _translate('Text Post', 'టెక్స్ట్ పోస్ట్', 'टेक्स्ट पोस्ट');
  String get writeArticleStoryNews => _translate(
    'Write an article, story, or news',
    'వ్యాసం, కథ, లేదా వార్త రాయండి',
    'एक लेख, कहानी, या समाचार लिखें',
  );
  String get uploadPdfFileToShare => _translate(
    'Upload a PDF file to share',
    'పంచుకోవడానికి PDF ఫైల్ అప్‌లోడ్ చేయండి',
    'साझा करने के लिए PDF फ़ाइल अपलोड करें',
  );
  String get preview => _translate('Preview', 'ప్రివ్యూ', 'पूर्वावलोकन');
  String get thisIsHowYourPostWillAppear => _translate(
    'This is how your post will appear',
    'మీ పోస్ట్ ఇలా కనిపిస్తుంది',
    'आपकी पोस्ट इस तरह दिखाई देगी',
  );
  String get uploadPdf =>
      _translate('Upload PDF', 'PDF అప్‌లోడ్ చేయండి', 'PDF अपलोड करें');
  String get tapToSelectPdfFile => _translate(
    'Tap to select a PDF file',
    'PDF ఫైల్ ఎంచుకోవడానికి నొక్కండి',
    'PDF फ़ाइल चुनने के लिए टैप करें',
  );
  String get max20Mb =>
      _translate('Max 20 MB', 'గరిష్టం 20 MB', 'अधिकतम 20 MB');

  // ===== Analytics =====
  String get analytics => _translate('Analytics', 'విశ్లేషణలు', 'विश्लेषण');
  String get content => _translate('Content', 'కంటెంట్', 'सामग्री');
  String get users => _translate('Users', 'వాడుకరులు', 'उपयोगकर्ता');
  String get overview => _translate('Overview', 'సారాంశం', 'अवलोकन');
  String get totalPosts =>
      _translate('Total Posts', 'మొత్తం పోస్ట్‌లు', 'कुल पोस्ट');
  String get engagement => _translate('Engagement', 'ఎంగేజ్‌మెంట్', 'जुड़ाव');
  String get likes => _translate('Likes', 'ఇష్టాలు', 'पसंद');
  String get shares => _translate('Shares', 'షేర్‌లు', 'शेयर');
  String get statusDistribution =>
      _translate('Status Distribution', 'స్థితి పంపిణీ', 'स्थिति वितरण');
  String get contentTypes =>
      _translate('Content Types', 'కంటెంట్ రకాలు', 'सामग्री प्रकार');
  String get categories => _translate('Categories', 'వర్గాలు', 'श्रेणियाँ');
  String get userOverview =>
      _translate('User Overview', 'వాడుకరి సారాంశం', 'उपयोगकर्ता अवलोकन');
  String get totalUsers =>
      _translate('Total Users', 'మొత్తం వాడుకరులు', 'कुल उपयोगकर्ता');
  String get reporters => _translate('Reporters', 'రిపోర్టర్లు', 'रिपोर्टर');
  String get admins => _translate('Admins', 'అడ్మిన్లు', 'एडमिन');
  String get publicUsers => _translate('Public', 'పబ్లిక్', 'सार्वजनिक');
  String get roleDistribution =>
      _translate('Role Distribution', 'పాత్ర పంపిణీ', 'भूमिका वितरण');
  String get quickStats =>
      _translate('Quick Stats', 'త్వరిత గణాంకాలు', 'त्वरित आँकड़े');
  String get avgPostsPerUser => _translate(
    'Avg Posts per User',
    'వాడుకరికి సగటు పోస్ట్‌లు',
    'प्रति उपयोगकर्ता औसत पोस्ट',
  );
  String get approvalRate =>
      _translate('Approval Rate', 'ఆమోద రేటు', 'अनुमोदन दर');
  String get avgLikesPerPost => _translate(
    'Avg Likes per Post',
    'పోస్ట్‌కు సగటు ఇష్టాలు',
    'प्रति पोस्ट औसत पसंद',
  );
  String get noData => _translate('No data', 'డేటా లేదు', 'कोई डेटा नहीं');
  String get noDataAvailable => _translate(
    'No data available',
    'డేటా అందుబాటులో లేదు',
    'कोई डेटा उपलब्ध नहीं',
  );

  // ===== Profile Extras =====
  String get failedToLoadProfile => _translate(
    'Failed to load profile',
    'ప్రొఫైల్ లోడ్ కాలేదు',
    'प्रोफ़ाइल लोड करने में विफल',
  );
  String get retry => _translate('Retry', 'మళ్లీ ప్రయత్నించు', 'पुनः प्रयास');
  String get notSubscribed =>
      _translate('Not subscribed', 'సబ్‌స్క్రయిబ్ కాలేదు', 'सदस्यता नहीं है');
  String get superAdminLabel =>
      _translate('SUPER ADMIN', 'సూపర్ అడ్మిన్', 'सुपर एडमिन');

  // ===== Partner Enrollment =====
  String get becomePartner =>
      _translate('Become a Partner', 'భాగస్వామి అవ్వండి', 'भागीदार बनें');
  String get partnerEnrollment =>
      _translate('Partner Enrollment', 'భాగస్వామి నమోదు', 'भागीदार नामांकन');
  String get partnerEnrollmentSubtitle => _translate(
    'Join the Focus Today community as a partner and make a difference',
    'భాగస్వామిగా Focus Today సమాజంలో చేరండి, మార్పు తీసుకురండి',
    'Focus Today समुदाय में भागीदार बनें और बदलाव लाएं',
  );
  String get fullName => _translate('Full Name', 'పూర్తి పేరు', 'पूरा नाम');
  String get profession => _translate('Profession', 'వృత్తి', 'पेशा');
  String get institutionOrg => _translate(
    'Institution / Organization',
    'సంస్థ / ఆర్గనైజేషన్',
    'संस्था / संगठन',
  );
  String get placeOfWorship =>
      _translate('Place of Worship', 'ప్రార్థనా స్థలం', 'पूजा स्थल');
  String get enrollNow =>
      _translate('Enroll Now', 'ఇప్పుడే నమోదు చేయండి', 'अभी नामांकन करें');
  String get submitting =>
      _translate('Submitting...', 'సమర్పిస్తోంది...', 'जमा कर रहे हैं...');

  // ===== Legal & Disclaimer =====
  String get termsOfUse =>
      _translate('Terms of Use', 'వినియోగ నిబంధనలు', 'उपयोग की शर्तें');
  String get disclaimer => _translate('Disclaimer', 'నిరాకరణ', 'अस्वीकरण');

  // ===== Departments =====
  String get emergencyContacts => _translate(
    'Emergency Contacts',
    'అత్యవసర సంప్రదింపులు',
    'आपातकालीन संपर्क',
  );
  String get departmentLinkages => emergencyContacts;
  String get departmentInfo => _translate(
    'Verified emergency and public-service contacts. Use Call, Email or Website actions as available.',
    'ధృవీకరించిన అత్యవసర మరియు ప్రజా సేవా సంప్రదింపులు. అందుబాటులో ఉన్నట్లయితే కాల్, ఇమెయిల్ లేదా వెబ్‌సైట్ ఎంపికలను ఉపయోగించండి.',
    'सत्यापित आपातकालीन और सार्वजनिक सेवा संपर्क। उपलब्ध होने पर कॉल, ईमेल या वेबसाइट विकल्प का उपयोग करें।',
  );
  String get emergencyNumbers =>
      _translate('Emergency Numbers', 'అత్యవసర నంబర్లు', 'आपातकालीन नंबर');
  String get telanganaContacts => _translate(
    'Telangana Contacts',
    'తెలంగాణ సంప్రదింపులు',
    'तेलंगाना संपर्क',
  );
  String get policeDept =>
      _translate('Police Department', 'పోలీస్ విభాగం', 'पुलिस विभाग');
  String get revenueDept =>
      _translate('Revenue Department', 'రెవెన్యూ విభాగం', 'राजस्व विभाग');
  String get legalAid => _translate(
    'Legal Aid & Rights',
    'న్యాయ సహాయం & హక్కులు',
    'कानूनी सहायता और अधिकार',
  );
  String get healthWelfare => _translate(
    'Health & Welfare',
    'ఆరోగ్యం & సంక్షేమం',
    'स्वास्थ्य और कल्याण',
  );
  String get deptDisclaimer => _translate(
    'These numbers are for reference. Availability may vary by region. Always verify with local authorities.',
    'ఈ నంబర్లు సందర్భం కోసం. అందుబాటు ప్రాంతాన్ని బట్టి మారవచ్చు. స్థానిక అధికారులతో ధృవీకరించండి.',
    'ये नंबर संदर्भ के लिए हैं। उपलब्धता क्षेत्र के अनुसार भिन्न हो सकती है। स्थानीय अधिकारियों से सत्यापित करें।',
  );
  String get callAction => _translate('Call', 'కాల్', 'कॉल');
  String get emailAction => _translate('Email', 'ఇమెయిల్', 'ईमेल');
  String get websiteAction => _translate('Website', 'వెబ్‌సైట్', 'वेबसाइट');
  String get verifiedOnLabel =>
      _translate('Verified on', 'ధృవీకరించిన తేదీ', 'सत्यापित तिथि');
  String get sourceLabel => _translate('Source', 'మూలం', 'स्रोत');

  // ===== Workspace =====
  String get reporterWorkspace => _translate(
    'Reporter Workspace',
    'రిపోర్టర్ వర్క్‌స్పేస్',
    'रिपोर्टर कार्यक्षेत्र',
  );
  String get adminWorkspace => _translate(
    'Admin Workspace',
    'అడ్మిన్ వర్క్‌స్పేస్',
    'एडमिन कार्यक्षेत्र',
  );
  String get workspaceAccessRequired => _translate(
    'Workspace Access Required',
    'వర్క్‌స్పేస్ యాక్సెస్ అవసరం',
    'वर्कस्पेस एक्सेस आवश्यक',
  );
  String get workspaceToolsAvailable => _translate(
    'Workspace tools are available for reporter and admin roles.',
    'వర్క్‌స్పేస్ టూల్స్ రిపోర్టర్ మరియు అడ్మిన్ పాత్రలకు అందుబాటులో ఉంటాయి.',
    'वर्कस्पेस टूल्स रिपोर्टर और एडमिन भूमिकाओं के लिए उपलब्ध हैं।',
  );
  String get management => _translate('Management', 'నిర్వహణ', 'प्रबंधन');
  String get allPostsQueue =>
      _translate('All Posts Queue', 'అన్ని పోస్ట్‌ల క్యూ', 'सभी पोस्ट कतार');
  String get userManagement =>
      _translate('User Management', 'వాడుకరి నిర్వహణ', 'उपयोगकर्ता प्रबंधन');
  String get analyticsDashboard => _translate(
    'Analytics Dashboard',
    'విశ్లేషణ డ్యాష్‌బోర్డ్',
    'एनालिटिक्स डैशबोर्ड',
  );
  String get storageLimits =>
      _translate('Storage Limits', 'స్టోరేజ్ పరిమితులు', 'स्टोरेज सीमाएं');
  String get operations => _translate('Operations', 'కార్యకలాపాలు', 'संचालन');
  String get storageConfig =>
      _translate('Storage Config', 'స్టోరేజ్ కాన్ఫిగ్', 'स्टोरेज कॉन्फ़िग');
  String get storageUsage =>
      _translate('Storage Usage', 'స్టోరేజ్ వినియోగం', 'स्टोरेज उपयोग');
  String get auditLogs =>
      _translate('Audit Logs', 'ఆడిట్ లాగ్‌లు', 'ऑडिट लॉग्स');
  String get breakingNews =>
      _translate('Breaking News', 'బ్రేకింగ్ న్యూస్', 'ब्रेकिंग न्यूज़');
  String get sendBreakingNews => _translate(
    'Send Breaking News',
    'బ్రేకింగ్ న్యూస్ పంపండి',
    'ब्रेकिंग न्यूज़ भेजें',
  );
  String get meetingsTitle => _translate('Meetings', 'సమావేశాలు', 'बैठकें');
  String get boardMeetings =>
      _translate('Board Meetings', 'బోర్డు సమావేశాలు', 'बोर्ड बैठकें');
  String get contentCreation =>
      _translate('Content Creation', 'కంటెంట్ సృష్టి', 'सामग्री निर्माण');
  String get performance => _translate('Performance', 'పనితీరు', 'प्रदर्शन');
  String get rejectedPosts => _translate(
    'Rejected Posts',
    'తిరస్కరించబడిన పోస్ట్‌లు',
    'अस्वीकृत पोस्ट',
  );
  String get myAnalytics =>
      _translate('My Analytics', 'నా విశ్లేషణలు', 'मेरे एनालिटिक्स');
  String get upcomingMeetings =>
      _translate('Upcoming Meetings', 'రాబోయే సమావేశాలు', 'आगामी बैठकें');
  String get eventsComingUp => _translate(
    'events coming up',
    'కార్యక్రమాలు వస్తున్నాయి',
    'कार्यक्रम आने वाले हैं',
  );
  String get upcomingEvents =>
      _translate('Upcoming Events', 'రాబోయే ఈవెంట్లు', 'आगामी कार्यक्रम');
  String get landingContent =>
      _translate('Landing Content', 'ల్యాండింగ్ కంటెంట్', 'लैंडिंग सामग्री');
  String get manageLandingContent => _translate(
    'Manage Landing Content',
    'ల్యాండింగ్ కంటెంట్ నిర్వహణ',
    'लैंडिंग सामग्री प्रबंधन',
  );
  String get groupNotifications => _translate(
    'Group Notifications',
    'నోటిఫికేషన్‌లను సమూహంగా చూపించండి',
    'सूचनाओं को समूहित करें',
  );
  String get groupNotificationsHint => _translate(
    'Bundle similar alerts in notification panel',
    'సమానమైన అలర్ట్‌లను నోటిఫికేషన్ ప్యానెల్‌లో కలిపి చూపించండి',
    'समान अलर्ट को नोटिफिकेशन पैनल में एक साथ दिखाएं',
  );
  String get quietHours => _translate('Quiet Hours', 'శాంతి సమయం', 'शांत समय');
  String get quietHoursHint => _translate(
    'Silence local alerts during selected hours',
    'ఎంచుకున్న గంటల్లో స్థానిక అలర్ట్‌లను మౌనం చేయండి',
    'चयनित समय में स्थानीय अलर्ट शांत रखें',
  );
  String get quietHoursSchedule => _translate(
    'Quiet Hours Schedule',
    'శాంతి సమయ షెడ్యూల్',
    'शांत समय शेड्यूल',
  );
  String get quietStart =>
      _translate('Quiet Start', 'శాంతి ప్రారంభం', 'शांत समय शुरू');
  String get quietEnd =>
      _translate('Quiet End', 'శాంతి ముగింపు', 'शांत समय समाप्त');
  String get maintainedByTechMigos => _translate(
    'Maintained by TechMigos',
    'TechMigos ద్వారా నిర్వహించబడుతుంది',
    'TechMigos द्वारा संचालित',
  );
  String get fcmCampaigns =>
      _translate('FCM Campaigns', 'FCM ప్రచారాలు', 'FCM अभियान');
  String get sendCustomPushToSegments => _translate(
    'Send custom push notifications to specific user segments.',
    'నిర్దిష్ట యూజర్ విభాగాలకు కస్టమ్ పుష్ నోటిఫికేషన్‌లు పంపండి.',
    'विशिष्ट उपयोगकर्ता समूहों को कस्टम पुश नोटिफिकेशन भेजें।',
  );
  String get notificationTitle => _translate(
    'Notification Title',
    'నోటిఫికేషన్ శీర్షిక',
    'नोटिफिकेशन शीर्षक',
  );
  String get notificationBody =>
      _translate('Notification Body', 'నోటిఫికేషన్ సందేశం', 'नोटिफिकेशन संदेश');
  String get requiredField => _translate('Required', 'తప్పనిసరి', 'आवश्यक');
  String get targetAudience =>
      _translate('Target Audience', 'లక్ష్య ప్రేక్షకులు', 'लक्षित दर्शक');
  String get byTopic =>
      _translate('By Topic', 'టాపిక్ ద్వారా', 'विषय के अनुसार');
  String get byRole =>
      _translate('By Role', 'పాత్ర ద్వారా', 'भूमिका के अनुसार');
  String get allUsers =>
      _translate('All Users', 'అన్ని యూజర్లు', 'सभी उपयोगकर्ता');
  String get selectTopic =>
      _translate('Select Topic', 'టాపిక్ ఎంచుకోండి', 'विषय चुनें');
  String get selectRole =>
      _translate('Select Role', 'పాత్ర ఎంచుకోండి', 'भूमिका चुनें');
  String get breakingNewsSubscribers => _translate(
    'Breaking News Subscribers',
    'బ్రేకింగ్ న్యూస్ సభ్యులు',
    'ब्रेकिंग न्यूज़ सब्सक्राइबर',
  );
  String get publicUsersLabel =>
      _translate('Public Users', 'పబ్లిక్ యూజర్లు', 'पब्लिक यूजर्स');
  String get reportersLabel =>
      _translate('Reporters', 'రిపోర్టర్లు', 'रिपोर्टर');
  String get adminsLabel => _translate('Admins', 'అడ్మిన్లు', 'एडमिन');
  String get superAdminsLabel =>
      _translate('Super Admins', 'సూపర్ అడ్మిన్లు', 'सुपर एडमिन');
  String get sending =>
      _translate('Sending...', 'పంపిస్తోంది...', 'भेजा जा रहा है...');
  String get sendCampaign =>
      _translate('Send Campaign', 'ప్రచారం పంపండి', 'अभियान भेजें');
  String get campaignSentSuccessfully => _translate(
    'Campaign sent successfully!',
    'ప్రచారం విజయవంతంగా పంపబడింది!',
    'अभियान सफलतापूर्वक भेजा गया!',
  );
  String get failedToSendCampaign => _translate(
    'Failed to send campaign',
    'ప్రచారం పంపడంలో విఫలమైంది',
    'अभियान भेजने में विफल',
  );
  String get mainHeadingRequired => _translate(
    'Main Heading (Required)',
    'ప్రధాన శీర్షిక (తప్పనిసరి)',
    'मुख्य शीर्षक (आवश्यक)',
  );
  String get subtitleOptional => _translate(
    'Subtitle (Optional)',
    'ఉపశీర్షిక (ఐచ్ఛికం)',
    'उपशीर्षक (वैकल्पिक)',
  );
  String get breakingNewsBannerInfo => _translate(
    'This will appear as a red banner at the top of the feed for all users.',
    'ఇది అన్ని యూజర్లకు ఫీడ్ పైభాగంలో ఎరుపు బ్యానర్‌గా కనిపిస్తుంది.',
    'यह सभी उपयोगकर्ताओं के लिए फ़ीड के शीर्ष पर लाल बैनर के रूप में दिखेगा।',
  );
  String get notifyUsersAfterMinutes => _translate(
    'Notify users after (minutes)',
    'యూజర్లకు ఎన్ని నిమిషాల తర్వాత తెలియజేయాలి',
    'उपयोगकर्ताओं को कितने मिनट बाद सूचित करें',
  );
  String get sendTo => _translate('Send to', 'ఎవరికి పంపాలి', 'किसे भेजें');
  String get specificUsers =>
      _translate('Specific Users', 'నిర్దిష్ట యూజర్లు', 'विशिष्ट उपयोगकर्ता');
  String get searchUsersByNamePhoneEmail => _translate(
    'Search users by name/phone/email',
    'పేరు/ఫోన్/ఇమెయిల్ ద్వారా యూజర్లను వెతకండి',
    'नाम/फोन/ईमेल से उपयोगकर्ता खोजें',
  );
  String get pleaseEnterTitle => _translate(
    'Please enter a title',
    'దయచేసి శీర్షికను నమోదు చేయండి',
    'कृपया शीर्षक दर्ज करें',
  );
  String get pleaseSelectAtLeastOneRole => _translate(
    'Please select at least one role',
    'కనీసం ఒక పాత్రను ఎంచుకోండి',
    'कृपया कम से कम एक भूमिका चुनें',
  );
  String get pleaseSelectAtLeastOneUser => _translate(
    'Please select at least one user',
    'కనీసం ఒక యూజర్‌ను ఎంచుకోండి',
    'कृपया कम से कम एक उपयोगकर्ता चुनें',
  );
  String get breakingNewsSentSuccessfully => _translate(
    'Breaking News sent successfully!',
    'బ్రేకింగ్ న్యూస్ విజయవంతంగా పంపబడింది!',
    'ब्रेकिंग न्यूज़ सफलतापूर्वक भेजी गई!',
  );
  String get errorSendingBreakingNews => _translate(
    'Error sending breaking news',
    'బ్రేకింగ్ న్యూస్ పంపడంలో లోపం',
    'ब्रेकिंग न्यूज़ भेजने में त्रुटि',
  );
  String get breakingNewsManagement => _translate(
    'Breaking News Management',
    'బ్రేకింగ్ న్యూస్ నిర్వహణ',
    'ब्रेकिंग न्यूज़ प्रबंधन',
  );
  String get breakingNewsDeactivated => _translate(
    'Breaking news deactivated',
    'బ్రేకింగ్ న్యూస్ నిలిపివేయబడింది',
    'ब्रेकिंग न्यूज़ निष्क्रिय की गई',
  );
  String get breakingNewsActivated => _translate(
    'Breaking news activated',
    'బ్రేకింగ్ న్యూస్ సక్రియమైంది',
    'ब्रेकिंग न्यूज़ सक्रिय की गई',
  );
  String get breakingNewsDeleted => _translate(
    'Breaking news deleted',
    'బ్రేకింగ్ న్యూస్ తొలగించబడింది',
    'ब्रेकिंग न्यूज़ हटाई गई',
  );
  String get breakingNewsUpdated => _translate(
    'Breaking news updated',
    'బ్రేకింగ్ న్యూస్ నవీకరించబడింది',
    'ब्रेकिंग न्यूज़ अपडेट की गई',
  );
  String get noBreakingNews => _translate(
    'No Breaking News',
    'బ్రేకింగ్ న్యూస్ లేదు',
    'कोई ब्रेकिंग न्यूज़ नहीं',
  );
  String get createFirstBreakingNews => _translate(
    'Create your first breaking news to alert users',
    'యూజర్లకు తెలియజేయడానికి మీ మొదటి బ్రేకింగ్ న్యూస్ సృష్టించండి',
    'उपयोगकर्ताओं को सूचित करने के लिए अपनी पहली ब्रेकिंग न्यूज़ बनाएं',
  );
  String get titleLabel => _translate('Title', 'శీర్షిక', 'शीर्षक');
  String get subtitleLabel => _translate('Subtitle', 'ఉపశీర్షిక', 'उपशीर्षक');
  String get unknown => _translate('Unknown', 'తెలియదు', 'अज्ञात');
  String get reporterApplications => _translate(
    'Reporter Applications',
    'రిపోర్టర్ అప్లికేషన్లు',
    'रिपोर्टर आवेदन',
  );
  String get rejectApplication => _translate(
    'Reject Application',
    'అప్లికేషన్ తిరస్కరణ',
    'आवेदन अस्वीकार करें',
  );
  String get enterRejectionReason => _translate(
    'Enter rejection reason...',
    'తిరస్కరణ కారణం నమోదు చేయండి...',
    'अस्वीकृति का कारण दर्ज करें...',
  );
  String get reporterApprovedMessage => _translate(
    'Application approved! User is now a Reporter.',
    'అప్లికేషన్ ఆమోదించబడింది! యూజర్ ఇప్పుడు రిపోర్టర్.',
    'आवेदन स्वीकृत! उपयोगकर्ता अब रिपोर्टर है।',
  );
  String get reporterRejectedMessage => _translate(
    'Application rejected.',
    'అప్లికేషన్ తిరస్కరించబడింది.',
    'आवेदन अस्वीकृत।',
  );
  String noApplications(String statusLabel) => _translate(
    'No $statusLabel applications',
    '$statusLabel అప్లికేషన్లు లేవు',
    '$statusLabel आवेदन नहीं हैं',
  );
  String get showHeroImage => _translate(
    'Show Hero Image',
    'హీరో చిత్రాన్ని చూపించు',
    'हीरो इमेज दिखाएं',
  );
  String get showSecondarySection => _translate(
    'Show Secondary Section',
    'సెకండరీ సెక్షన్ చూపించు',
    'सेकेंडरी सेक्शन दिखाएं',
  );
  String get heroImage => _translate('Hero Image', 'హీరో చిత్రం', 'हीरो इमेज');
  String get secondaryImage =>
      _translate('Secondary Image', 'సెకండరీ చిత్రం', 'सेकेंडरी इमेज');
  String get introSection =>
      _translate('Intro Section', 'పరిచయ విభాగం', 'परिचय अनुभाग');
  String get secondarySection =>
      _translate('Secondary Section', 'సెకండరీ విభాగం', 'सेकेंडरी अनुभाग');
  String get saveChanges =>
      _translate('Save Changes', 'మార్పులు సేవ్ చేయండి', 'परिवर्तन सहेजें');
  String get saving =>
      _translate('Saving...', 'సేవ్ అవుతోంది...', 'सहेजा जा रहा है...');
  String get all => _translate('All', 'అన్నీ', 'सभी');
  String get noPostsInCategory => _translate(
    'No posts in this category',
    'ఈ వర్గంలో పోస్ట్‌లు లేవు',
    'इस श्रेणी में कोई पोस्ट नहीं',
  );

  String get today => _translate('TODAY', 'నేడు', 'आज');
  String get tomorrow => _translate('TOMORROW', 'రేపు', 'कल');
  String get interested => _translate('Interested', 'ఆసక్తి ఉంది', 'रुचि है');
  String get tapToView =>
      _translate('Tap to view', 'చూడడానికి నొక్కండి', 'देखने के लिए टैप करें');
  String get viewAll => _translate('View All', 'అన్నీ చూడండి', 'सभी देखें');
  String get breakingNewsLabel =>
      _translate('BREAKING NEWS', 'బ్రేకింగ్ న్యూస్', 'ब्रेकिंग न्यूज़');
  String get publicLandingSchedule =>
      _translate('Landing Schedule', 'ల్యాండింగ్ షెడ్యూల్', 'लैंडिंग शेड्यूल');
  String get autoShowLandingForPublic => _translate(
    'Auto show landing for users, reporters, admins and super admins',
    'యూజర్, రిపోర్టర్, అడ్మిన్, సూపర్ అడ్మిన్‌లకు ల్యాండింగ్ ఆటోగా చూపించు',
    'यूज़र, रिपोर्टर, एडमिन और सुपर एडमिन के लिए लैंडिंग स्वतः दिखाएं',
  );
  String get autoShowFrequency =>
      _translate('Auto Show Frequency', 'ఆటో చూపించే సారి', 'ऑटो शो आवृत्ति');
  String get oncePerDay =>
      _translate('Once per day', 'రోజుకు ఒకసారి', 'दिन में एक बार');
  String get twicePerDay =>
      _translate('Twice per day', 'రోజుకు రెండుసార్లు', 'दिन में दो बार');
  String get landingDisplayDuration => _translate(
    'Landing Display Duration',
    'ల్యాండింగ్ చూపించే వ్యవధి',
    'लैंडिंग दिखाने की अवधि',
  );
  String secondsLabel(String seconds) =>
      _translate('$seconds seconds', '$seconds సెకన్లు', '$seconds सेकंड');
  String get autoShowStartTime => _translate(
    'Auto Show Start Time',
    'ఆటో చూపే ప్రారంభ సమయం',
    'ऑटो शो शुरू होने का समय',
  );

  // ===== Additional Localization Coverage =====
  String get failedToLoadStorageData => _translate(
    'Failed to load storage data',
    'స్టోరేజ్ డేటా లోడ్ చేయడంలో విఫలమైంది',
    'स्टोरेज डेटा लोड करने में विफल',
  );
  String get noChangesToSave => _translate(
    'No changes to save',
    'సేవ్ చేయడానికి మార్పులు లేవు',
    'सहेजने के लिए कोई बदलाव नहीं',
  );
  String get storageConfigUpdated => _translate(
    'Storage config updated!',
    'స్టోరేజ్ కాన్ఫిగ్ నవీకరించబడింది!',
    'स्टोरेज कॉन्फ़िग अपडेट किया गया!',
  );
  String get failedToSave =>
      _translate('Failed to save', 'సేవ్ చేయడంలో విఫలమైంది', 'सहेजने में विफल');
  String get noAccessToPage => _translate(
    'You do not have access to this page.',
    'ఈ పేజీకి మీకు యాక్సెస్ లేదు.',
    'आपके पास इस पेज की पहुंच नहीं है।',
  );
  String get saveStorageConfig => _translate(
    'Save Storage Config',
    'స్టోరేజ్ కాన్ఫిగ్ సేవ్ చేయండి',
    'स्टोरेज कॉन्फ़िग सहेजें',
  );
  String get configuredStorage => _translate(
    'Configured Storage',
    'కాన్ఫిగర్ చేసిన స్టోరేజ్',
    'कॉन्फ़िगर किया गया स्टोरेज',
  );
  String get postsStorage =>
      _translate('Posts Storage', 'పోస్ట్‌ల స్టోరేజ్', 'पोस्ट स्टोरेज');
  String get interactionsStorage => _translate(
    'Interactions Storage',
    'ఇంటరాక్షన్ స్టోరేజ్',
    'इंटरैक्शन स्टोरेज',
  );
  String get usersStorage =>
      _translate('Users Storage', 'యూజర్ల స్టోరేజ్', 'यूज़र स्टोरेज');
  String get systemFilesLimitLabel =>
      _translate('System Files', 'సిస్టమ్ ఫైళ్లు', 'सिस्टम फाइलें');
  String get totalStorage =>
      _translate('Total Storage', 'మొత్తం స్టోరేజ్', 'कुल स्टोरेज');
  String get configuredUtilisedGb => _translate(
    'Configured Utilised (GB)',
    'కాన్ఫిగర్ చేసిన వినియోగం (GB)',
    'कॉन्फ़िगर उपयोग (GB)',
  );
  String get configuredTotalGb => _translate(
    'Configured Total (GB)',
    'కాన్ఫిగర్ చేసిన మొత్తం (GB)',
    'कॉन्फ़िगर कुल (GB)',
  );

  String get adminAccessRequired => _translate(
    'Admin Access Required',
    'అడ్మిన్ యాక్సెస్ అవసరం',
    'एडमिन एक्सेस आवश्यक',
  );
  String get allPostsQueueModerationOnly => _translate(
    'All Posts Queue is available for moderation roles only.',
    'అన్ని పోస్ట్‌ల క్యూ మోడరేషన్ పాత్రలకు మాత్రమే అందుబాటులో ఉంది.',
    'सभी पोस्ट कतार केवल मॉडरेशन भूमिकाओं के लिए उपलब्ध है।',
  );
  String get allPosts =>
      _translate('All Posts', 'అన్ని పోస్ట్‌లు', 'सभी पोस्ट');
  String visibleItems(int count) => _translate(
    '$count visible items',
    '$count కనిపిస్తున్న అంశాలు',
    '$count दृश्य आइटम',
  );
  String get rejectionReasonLabel =>
      _translate('Rejection reason', 'తిరస్కరణ కారణం', 'अस्वीकृति का कारण');
  String get postUpdated =>
      _translate('Post updated', 'పోస్ట్ నవీకరించబడింది', 'पोस्ट अपडेट की गई');
  String get statusUpdateFailed => _translate(
    'Status update failed',
    'స్థితి అప్‌డేట్ విఫలమైంది',
    'स्थिति अपडेट विफल',
  );
  String get deleteFailed =>
      _translate('Delete failed', 'తొలగింపు విఫలమైంది', 'हटाना विफल');
  String get clearSearchAndFilters => _translate(
    'Clear Search & Filters',
    'సెర్చ్ & ఫిల్టర్‌లను క్లియర్ చేయండి',
    'खोज और फ़िल्टर साफ करें',
  );
  String get tryDifferentSearchTermOrClearFilters => _translate(
    'Try a different search term or clear filters.',
    'వేరే శోధన పదం ప్రయత్నించండి లేదా ఫిల్టర్‌లను క్లియర్ చేయండి.',
    'कोई अलग खोज शब्द आज़माएं या फ़िल्टर साफ करें।',
  );
  String get showLess => _translate('Show less', 'తక్కువ చూపు', 'कम दिखाएं');
  String get showFullContent => _translate(
    'Show full content',
    'పూర్తి కంటెంట్ చూపు',
    'पूरा कंटेंट दिखाएं',
  );

  String get failedToLoadUsers => _translate(
    'Failed to load users',
    'యూజర్లను లోడ్ చేయడంలో విఫలమైంది',
    'उपयोगकर्ताओं को लोड करने में विफल',
  );
  String get deleteUserTitle =>
      _translate('Delete User', 'యూజర్ తొలగించు', 'उपयोगकर्ता हटाएं');
  String deleteUserPrompt(String name, String phone) => _translate(
    'Delete $name ($phone)? This action cannot be undone.',
    '$name ($phone) ను తొలగించాలా? ఈ చర్యను వెనక్కి తీసుకోలేరు.',
    '$name ($phone) को हटाएं? यह कार्रवाई वापस नहीं की जा सकती।',
  );
  String userDeletedSuccessfully(String name) => _translate(
    '$name deleted successfully',
    '$name విజయవంతంగా తొలగించబడింది',
    '$name सफलतापूर्वक हटाया गया',
  );
  String get failedToDeleteUser => _translate(
    'Failed to delete user',
    'యూజర్‌ను తొలగించడంలో విఫలమైంది',
    'उपयोगकर्ता हटाने में विफल',
  );
  String get changeRole =>
      _translate('Change Role', 'పాత్ర మార్చు', 'भूमिका बदलें');
  String get noEmail => _translate('No email', 'ఇమెయిల్ లేదు', 'कोई ईमेल नहीं');
  String get selectNewRole => _translate(
    'Select new role:',
    'కొత్త పాత్రను ఎంచుకోండి:',
    'नई भूमिका चुनें:',
  );
  String get updateRole =>
      _translate('Update Role', 'పాత్రను నవీకరించు', 'भूमिका अपडेट करें');
  String userRoleUpdated(String name, String role) => _translate(
    '$name is now $role',
    '$name ఇప్పుడు $role',
    '$name अब $role है',
  );
  String get failedToUpdateRole => _translate(
    'Failed to update role',
    'పాత్రను నవీకరించడంలో విఫలమైంది',
    'भूमिका अपडेट करने में विफल',
  );
  String get onlySuperAdminsCanChangeAdminRoles => _translate(
    'Only Super Admins can change admin roles',
    'అడ్మిన్ పాత్రలను కేవలం సూపర్ అడ్మిన్‌లు మాత్రమే మార్చగలరు',
    'केवल सुपर एडमिन ही एडमिन भूमिकाएँ बदल सकते हैं',
  );
  String get fullSystemAccessUserManagement => _translate(
    'Full system access, user management',
    'పూర్తి సిస్టమ్ యాక్సెస్, యూజర్ నిర్వహణ',
    'पूर्ण सिस्टम एक्सेस, उपयोगकर्ता प्रबंधन',
  );
  String get contentModerationPostManagement => _translate(
    'Content moderation, post management',
    'కంటెంట్ మోడరేషన్, పోస్ట్ నిర్వహణ',
    'सामग्री मॉडरेशन, पोस्ट प्रबंधन',
  );
  String get createAndPublishContent => _translate(
    'Create and publish content',
    'కంటెంట్ సృష్టించి ప్రచురించండి',
    'सामग्री बनाएं और प्रकाशित करें',
  );
  String get viewCommentInteract => _translate(
    'View content, comment, interact',
    'కంటెంట్ చూడండి, వ్యాఖ్య చేయండి, ఇంటరాక్ట్ అవండి',
    'सामग्री देखें, टिप्पणी करें, इंटरैक्ट करें',
  );
  String get searchUsersPlaceholder => _translate(
    'Search users...',
    'యూజర్లను వెతకండి...',
    'उपयोगकर्ता खोजें...',
  );
  String totalUsersCount(int count) =>
      _translate('$count users', '$count యూజర్లు', '$count उपयोगकर्ता');
  String get addUser =>
      _translate('Add User', 'యూజర్ జోడించు', 'उपयोगकर्ता जोड़ें');
  String get addReporter =>
      _translate('Add Reporter', 'రిపోర్టర్ జోడించు', 'रिपोर्टर जोड़ें');
  String get phoneNumberRequiredLabel =>
      _translate('Phone Number *', 'ఫోన్ నంబర్ *', 'फोन नंबर *');
  String get tenDigitMobileNumber => _translate(
    '10-digit mobile number',
    '10 అంకెల మొబైల్ నంబర్',
    '10-अंकों का मोबाइल नंबर',
  );
  String get phoneNumberRequired => _translate(
    'Phone number is required',
    'ఫోన్ నంబర్ అవసరం',
    'फोन नंबर आवश्यक है',
  );
  String get enterValidTenDigitNumber => _translate(
    'Enter a valid 10-digit number',
    'చెల్లుబాటు అయ్యే 10 అంకెల నంబర్ ఇవ్వండి',
    'सही 10-अंकों का नंबर दर्ज करें',
  );
  String get fullNameRequiredLabel =>
      _translate('Full Name *', 'పూర్తి పేరు *', 'पूरा नाम *');
  String get nameIsRequired =>
      _translate('Name is required', 'పేరు అవసరం', 'नाम आवश्यक है');
  String get emailOptionalLabel =>
      _translate('Email (optional)', 'ఇమెయిల్ (ఐచ్ఛికం)', 'ईमेल (वैकल्पिक)');
  String get assignRole =>
      _translate('Assign Role:', 'పాత్ర కేటాయించండి:', 'भूमिका असाइन करें:');
  String addRole(String role) =>
      _translate('Add $role', '$role జోడించు', '$role जोड़ें');
  String updatedToRoleForExistingUser(String name, String phone, String role) =>
      _translate(
        '$name ($phone) updated to $role',
        '$name ($phone) ను $role గా మార్చారు',
        '$name ($phone) को $role में अपडेट किया गया',
      );
  String get failedToUpdateExistingUserRole => _translate(
    'Failed to update role for existing user',
    'ఉన్న యూజర్ పాత్రను నవీకరించడంలో విఫలమైంది',
    'मौजूदा उपयोगकर्ता की भूमिका अपडेट करने में विफल',
  );
  String userAddedAsRole(String name, String phone, String role) => _translate(
    '$name ($phone) added as $role!',
    '$name ($phone) ను $role గా జోడించారు!',
    '$name ($phone) को $role के रूप में जोड़ा गया!',
  );
  String get failedToAddUser => _translate(
    'Failed to add user',
    'యూజర్‌ను జోడించడంలో విఫలమైంది',
    'उपयोगकर्ता जोड़ने में विफल',
  );
  String get noUsersMatchSearch => _translate(
    'No Users Match Your Search',
    'మీ శోధనకు సరిపడే యూజర్లు లేరు',
    'आपकी खोज से मेल खाने वाले उपयोगकर्ता नहीं मिले',
  );
  String get noUsersFound => _translate(
    'No Users Found',
    'యూజర్లు కనబడలేదు',
    'कोई उपयोगकर्ता नहीं मिला',
  );
  String get tryDifferentSearchKeywords => _translate(
    'Try different search keywords.',
    'వేరే శోధన కీవర్డ్‌లను ప్రయత్నించండి.',
    'अलग खोज शब्द आज़माएं।',
  );
  String get usersWillAppearOnceRegistered => _translate(
    'Users will appear here once they register.',
    'వారు రిజిస్టర్ అయిన తర్వాత యూజర్లు ఇక్కడ కనిపిస్తారు.',
    'उपयोगकर्ता पंजीकरण के बाद यहां दिखाई देंगे।',
  );
  String get notSet => _translate('Not set', 'సెట్ చేయలేదు', 'सेट नहीं है');
  String get joined => _translate('Joined', 'చేరిన తేదీ', 'जुड़ा');

  String get postUpdatedSuccessfully => _translate(
    'Post updated successfully!',
    'పోస్ట్ విజయవంతంగా నవీకరించబడింది!',
    'पोस्ट सफलतापूर्वक अपडेट की गई!',
  );
  String get errorUpdatingPost => _translate(
    'Error updating post',
    'పోస్ట్ నవీకరించడంలో లోపం',
    'पोस्ट अपडेट करने में त्रुटि',
  );
  String get categoryRequired =>
      _translate('Category is required', 'వర్గం అవసరం', 'श्रेणी आवश्यक है');
  String get pleaseVerifyPostDetails => _translate(
    'Please verify post details',
    'దయచేసి పోస్ట్ వివరాలను ధృవీకరించండి',
    'कृपया पोस्ट विवरण सत्यापित करें',
  );
  String get discardChangesQuestion => _translate(
    'Discard changes?',
    'మార్పులను తీసివేయాలా?',
    'परिवर्तन हटाएं?',
  );
  String get unsavedEditsForPost => _translate(
    'You have unsaved edits for this post.',
    'ఈ పోస్ట్‌కు మీరు సేవ్ చేయని మార్పులు ఉన్నాయి.',
    'इस पोस्ट में आपके असहेजे बदलाव हैं।',
  );
  String get unsavedChangesSaveDraftPrompt => _translate(
    'You have unsaved changes. Save draft before exit?',
    'మీకు సేవ్ చేయని మార్పులు ఉన్నాయి. బయటకు వెళ్లే ముందు డ్రాఫ్ట్ సేవ్ చేయాలా?',
    'आपके पास असहेजे बदलाव हैं। बाहर निकलने से पहले ड्राफ्ट सहेजें?',
  );
  String get editPostTitle =>
      _translate('Edit Post', 'పోస్ట్ సవరించు', 'पोस्ट संपादित करें');
  String previouslyEditedTimes(int count) => _translate(
    'Previously edited $count time(s)',
    'ఇప్పటికే $count సార్లు సవరించారు',
    'पहले $count बार संपादित किया गया',
  );
  String get enterPostCaption => _translate(
    'Enter post caption...',
    'పోస్ట్ క్యాప్షన్ నమోదు చేయండి...',
    'पोस्ट कैप्शन दर्ज करें...',
  );
  String get contentTypeLabel =>
      _translate('Content Type', 'కంటెంట్ రకం', 'सामग्री प्रकार');
  String get mediaLabel => _translate('Media', 'మీడియా', 'मीडिया');
  String get addImage =>
      _translate('Add Image', 'చిత్రం జోడించండి', 'छवि जोड़ें');
  String get addVideo =>
      _translate('Add Video', 'వీడియో జోడించండి', 'वीडियो जोड़ें');
  String get noChangesToResubmit => _translate(
    'No changes to resubmit',
    'మళ్లీ సమర్పించడానికి మార్పులు లేవు',
    'पुनः सबमिट करने के लिए कोई बदलाव नहीं',
  );
  String get editAndResubmitTitle => _translate(
    'Edit & Resubmit',
    'సవరించి మళ్లీ సమర్పించు',
    'संपादित करें और पुनः सबमिट करें',
  );
  String get resubmit =>
      _translate('Resubmit', 'మళ్లీ సమర్పించు', 'पुनः सबमिट करें');
  String get previousRejectionReason => _translate(
    'Previous Rejection Reason:',
    'మునుపటి తిరస్కరణ కారణం:',
    'पिछला अस्वीकृति कारण:',
  );
  String get makeChangesAndResubmitInfo => _translate(
    'Make changes and resubmit for review. Your post will be sent to moderators again.',
    'మార్పులు చేసి మళ్లీ సమీక్షకు పంపండి. మీ పోస్ట్ మళ్లీ మోడరేటర్లకు పంపబడుతుంది.',
    'बदलाव करें और समीक्षा के लिए पुनः सबमिट करें। आपकी पोस्ट फिर से मॉडरेटर्स को भेजी जाएगी।',
  );
  String get failedToResubmitPost => _translate(
    'Failed to resubmit post',
    'పోస్ట్‌ను మళ్లీ సమర్పించడంలో విఫలమైంది',
    'पोस्ट पुनः सबमिट करने में विफल',
  );
  String get resubmitForReview => _translate(
    'Resubmit for Review',
    'సమీక్ష కోసం మళ్లీ సమర్పించు',
    'समीक्षा हेतु पुनः सबमिट करें',
  );

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
      case 'article':
      case 'articles':
        return articles;
      case 'story':
      case 'stories':
        return stories;
      case 'poetry':
      case 'poem':
        return _translate('Poetry', 'కవిత్వం', 'कविता');
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
      case 'world':
        return _translate('World', 'ప్రపంచం', 'विश्व');
      case 'others':
      case 'other':
        return other;
      default:
        return other;
    }
  }

  // Location / User Details
  String get locationDetails =>
      _translate('Location Details', 'స్థాన వివరాలు', 'स्थान विवरण');
  String get area => _translate(
    'Area / Village / Town',
    'ప్రాంతం / గ్రామం / పట్టణం',
    'क्षेत्र / गाँव / शहर',
  );
  String get district => _translate('District', 'జిల్లా', 'जिला');
  String get stateLabel => _translate('State', 'రాష్ట్రం', 'राज्य');
  String get areaHint => _translate(
    'Enter your area, village or town',
    'మీ ప్రాంతం, గ్రామం లేదా పట్టణం నమోదు చేయండి',
    'अपना क्षेत्र, गाँव या शहर दर्ज करें',
  );
  String get districtHint => _translate(
    'Enter your district',
    'మీ జిల్లా నమోదు చేయండి',
    'अपना जिला दर्ज करें',
  );
  String get stateHint => _translate(
    'Enter your state',
    'మీ రాష్ట్రం నమోదు చేయండి',
    'अपना राज्य दर्ज करें',
  );
  String get locationSavedSuccess => _translate(
    'Location details updated successfully',
    'స్థాన వివరాలు విజయవంతంగా నవీకరించబడ్డాయి',
    'स्थान विवरण सफलतापूर्वक अपडेट किए गए',
  );
  String get whereAreYouFrom => _translate(
    'Where are you from?',
    'మీరు ఎక్కడ నుండి వచ్చారు?',
    'आप कहाँ से हैं?',
  );
  String get locationNotSet => _translate(
    'Location not set',
    'స్థానం సెట్ చేయబడలేదు',
    'स्थान सेट नहीं किया गया',
  );
  String get tapToAddLocation => _translate(
    'Tap to add your location',
    'మీ స్థానాన్ని జోడించడానికి నొక్కండి',
    'अपना स्थान जोड़ने के लिए टैप करें',
  );

  // Meetings Management Details
  String get createMeeting =>
      _translate('Create Meeting', 'సమావేశాన్ని సృష్టించండి', 'बैठक बनाएं');
  String get editMeeting =>
      _translate('Edit Meeting', 'సమావేశాన్ని సవరించండి', 'बैठक संपादित करें');
  String get titleEn => _translate(
    'Title (English) *',
    'శీర్షిక (ఇంగ్లీష్) *',
    'शीर्षक (अंग्रेजी) *',
  );
  String get titleTe =>
      _translate('Title (Telugu)', 'శీర్షిక (తెలుగు)', 'शीर्षक (तेलुगु)');
  String get titleHi =>
      _translate('Title (Hindi)', 'శీర్షిక (హిందీ)', 'शीर्षक (हिंदी)');
  String get descEn => _translate(
    'Description (English)',
    'వివరణ (ఇంగ్లీష్)',
    'विवरण (अंग्रेजी)',
  );
  String get descTe =>
      _translate('Description (Telugu)', 'వివరణ (తెలుగు)', 'विवरण (तेलुगु)');
  String get descHi =>
      _translate('Description (Hindi)', 'వివరణ (హిందీ)', 'विवरण (हिंदी)');
  String get venueEn => _translate(
    'Venue (English) *',
    'వేదిక (ఇంగ్లీష్) *',
    'स्थान (अंग्रेजी) *',
  );
  String get venueTe =>
      _translate('Venue (Telugu)', 'వేదిక (తెలుగు)', 'स्थान (तेलुगु)');
  String get venueHi =>
      _translate('Venue (Hindi)', 'వేదిక (హిందీ)', 'स्थान (हिंदी)');
  String get dateLabel => _translate('Date', 'తేదీ', 'तारीख');
  String get timeLabel => _translate('Time', 'సమయం', 'समय');
  String get displayDaysLabel =>
      _translate('Display Days', 'ప్రదర్శన రోజులు', 'प्रदर्शन के दिन');
  String get displayDaysHint => _translate(
    'How many days before to show popup',
    'పాపప్ చూపించడానికి ఎన్ని రోజుల ముందు',
    'पॉपअप दिखाने से कितने दिन पहले',
  );
  String get fieldsRequired => _translate(
    'Title and venue are required',
    'శీర్షిక మరియు వేదిక అవసరం',
    'शीर्षक और स्थान आवश्यक हैं',
  );
  String get noMeetingsMessage => _translate(
    'No meetings scheduled yet.',
    'ఇంకా సమావేశాలు ఏవీ నిర్ణయించబడలేదు.',
    'अभी तक कोई बैठक निर्धारित नहीं है।',
  );
  String get upcoming => _translate('Upcoming', 'రాబోయే', 'आगामी');
  String get ongoing => _translate('Ongoing', 'జరుగుతోంది', 'चल रही');
  String get completed => _translate('Completed', 'పూర్తయింది', 'पूर्ण');
  String get cancelled => _translate('Cancelled', 'రద్దు చేయబడింది', 'रद्द');
  String get changeStatus =>
      _translate('Change Status', 'స్థితి మార్చు', 'स्थिति बदलें');
  String setMeetingStatusTo(String status) => _translate(
    'Set meeting status to "$status"?',
    'సమావేశ స్థితిని "$status" గా మార్చాలా?',
    'बैठक की स्थिति "$status" पर सेट करें?',
  );
  String get markAsOngoing => _translate(
    'Mark as Ongoing',
    'జరుగుతోందిగా గుర్తించు',
    'चल रही के रूप में चिह्नित करें',
  );
  String get markAsCompleted => _translate(
    'Mark as Completed',
    'పూర్తయిందిగా గుర్తించు',
    'पूर्ण के रूप में चिह्नित करें',
  );
  String get viewInterestedUsers => _translate(
    'View Interested Users',
    'ఆసక్తి ఉన్న యూజర్లను చూడండి',
    'रुचि रखने वाले उपयोगकर्ता देखें',
  );
  String get viewRsvpResponses => _translate(
    'View RSVP Responses',
    'RSVP సమాధానాలు చూడండి',
    'RSVP प्रतिक्रियाएँ देखें',
  );
  String get dayWindow => _translate('day window', 'రోజుల విండో', 'दिन विंडो');
  String get atLabel => _translate('at', 'కు', 'पर');
  String get allMeetings =>
      _translate('All Meetings', 'అన్ని సమావేశాలు', 'सभी बैठकें');
  String get interestedQuestion =>
      _translate('Interested?', 'ఆసక్తి ఉందా?', 'रुचि है?');
  String get notInterestedLabel =>
      _translate('Not Interested', 'ఆసక్తి లేదు', 'रुचि नहीं');
  String interestedCountLabel(int count) => _translate(
    '$count interested',
    '$count ఆసక్తి ఉంది',
    '$count रुचि रखते हैं',
  );
  String notInterestedCountLabel(int count) => _translate(
    '$count not interested',
    '$count ఆసక్తి లేదు',
    '$count रुचि नहीं',
  );
  String get meetingDetails =>
      _translate('Meeting Details', 'సమావేశ వివరాలు', 'बैठक विवरण');
  String get venue => _translate('Venue', 'వేదిక', 'स्थान');
  String get organiser => _translate('Organiser', 'నిర్వాహకుడు', 'आयोजक');
  String get rsvpLabel => _translate('RSVP', 'RSVP', 'RSVP');
  String get rsvpDescription => _translate(
    'Let the organiser know if you\'re attending.',
    'మీరు హాజరవుతారా అని నిర్వాహకుడికి తెలియజేయండి.',
    'यदि आप शामिल हो रहे हैं तो आयोजक को बताएं।',
  );
  String get nameLabel => _translate('Name', 'పేరు', 'नाम');
  String get phoneLabel => _translate('Phone', 'ఫోన్', 'फोन');
  String get detailsOptionalLabel =>
      _translate('Details (optional)', 'వివరాలు (ఐచ్చికం)', 'विवरण (वैकल्पिक)');
  String get going => _translate('Going', 'వస్తున్నాను', 'आ रहा/रही हूँ');
  String get maybe => _translate('Maybe', 'బహుశా', 'शायद');
  String get noLabel => _translate('No', 'కాదు', 'नहीं');
  String interestedPeople(int count) => _translate(
    '$count ${count == 1 ? 'person' : 'people'} interested',
    '$count మంది ఆసక్తి చూపించారు',
    '$count ${count == 1 ? 'व्यक्ति' : 'लोग'} रुचि रखते हैं',
  );
  String get markInterest =>
      _translate('Mark Interest', 'ఆసక్తిని గుర్తించండి', 'रुचि दर्ज करें');
  String get confirmLabel =>
      _translate('Confirm', 'నిర్ధారించు', 'पुष्टि करें');
  String interestedUsersCount(int count) => _translate(
    'Interested Users ($count)',
    'ఆసక్తి ఉన్న వినియోగదారులు ($count)',
    'रुचि रखने वाले उपयोगकर्ता ($count)',
  );
  String get noInterestedUsersYet => _translate(
    'No users have shown interest yet.',
    'ఇప్పటివరకు ఎవరూ ఆసక్తి చూపలేదు.',
    'अभी तक किसी ने रुचि नहीं दिखाई है।',
  );
  String get noResponsesYet => _translate(
    'No responses yet.',
    'ఇంకా సమాధానాలు లేవు.',
    'अभी तक कोई प्रतिक्रिया नहीं।',
  );
  String get rsvpResponsesTitle =>
      _translate('RSVP Responses', 'RSVP సమాధానాలు', 'RSVP प्रतिक्रियाएँ');
  String goingCountTab(int count) =>
      _translate('Going ($count)', 'వస్తున్నారు ($count)', 'आ रहे ($count)');
  String maybeCountTab(int count) =>
      _translate('Maybe ($count)', 'బహుశా ($count)', 'शायद ($count)');
  String notGoingCountTab(int count) =>
      _translate('Not Going ($count)', 'రారు ($count)', 'नहीं आ रहे ($count)');
  String get meetingTitleHint =>
      _translate('Meeting title', 'సమావేశ శీర్షిక', 'बैठक शीर्षक');
  String get meetingLocationHint =>
      _translate('Meeting location', 'సమావేశ స్థలం', 'बैठक स्थान');
  String get daysLabel => _translate('days', 'రోజులు', 'दिन');
  String get daysLabelTe => _translate('days', 'రోజులు', 'दिन');
  String get meetingUpdated =>
      _translate('Meeting updated', 'సమావేశం నవీకరించబడింది', 'बैठक अपडेट हुई');
  String get meetingCreated =>
      _translate('Meeting created', 'సమావేశం సృష్టించబడింది', 'बैठक बनाई गई');
  String get updateLabel => _translate('Update', 'నవీకరించు', 'अपडेट');
  String get createLabel => _translate('Create', 'సృష్టించు', 'बनाएं');
  String get auditHistory =>
      _translate('Audit History', 'ఆడిట్ చరిత్ర', 'ऑडिट इतिहास');
  String get auditTimeline =>
      _translate('Audit Timeline', 'ఆడిట్ టైమ్‌లైన్', 'ऑडिट टाइमलाइन');
  String get noAuditLogsYet => _translate(
    'No audit logs yet',
    'ఇంకా ఆడిట్ లాగ్స్ లేవు',
    'अभी तक कोई ऑडिट लॉग नहीं',
  );
  String actorLabel(String actor) =>
      _translate('Actor: $actor', 'కర్త: $actor', 'अभिनेता: $actor');
  String get activeBreakingNews => _translate(
    'Active Breaking News',
    'సక్రియ బ్రేకింగ్ న్యూస్',
    'सक्रिय ब्रेकिंग न्यूज़',
  );
  String get pastBreakingNews => _translate(
    'Past Breaking News',
    'గత బ్రేకింగ్ న్యూస్',
    'पुरानी ब्रेकिंग न्यूज़',
  );
  String get liveLabel => _translate('LIVE', 'ప్రత్యక్షం', 'लाइव');
  String get inactiveLabel => _translate('INACTIVE', 'నిష్క్రియ', 'निष्क्रिय');
  String get noTitle =>
      _translate('No title', 'శీర్షిక లేదు', 'कोई शीर्षक नहीं');
  String get deactivateLabel =>
      _translate('Deactivate', 'నిష్క్రియం చేయి', 'निष्क्रिय करें');
  String get activateLabel =>
      _translate('Activate', 'సక్రియం చేయి', 'सक्रिय करें');
  String get breakingNewsTitleHint => _translate(
    'e.g., Major accident on Highway 1',
    'ఉదా., హైవే 1 పై పెద్ద ప్రమాదం',
    'उदा., हाईवे 1 पर बड़ी दुर्घटना',
  );
  String get breakingNewsSubtitleHint => _translate(
    'Additional details or location',
    'అదనపు వివరాలు లేదా స్థానం',
    'अतिरिक्त विवरण या स्थान',
  );
  String get breakingNewsDelayHint => _translate(
    '0 = immediate, e.g. 5',
    '0 = వెంటనే, ఉదా. 5',
    '0 = तुरंत, जैसे 5',
  );
  String get broadcastNow =>
      _translate('Broadcast Now', 'ఇప్పుడే ప్రసారం చేయి', 'अभी प्रसारित करें');
  String get performanceOverview =>
      _translate('Performance Overview', 'పనితీరు సమీక్ష', 'प्रदर्शन अवलोकन');
  String get topCategories =>
      _translate('Top Categories', 'అగ్ర విభాగాలు', 'शीर्ष श्रेणियाँ');
  String get noCategoryDataYet => _translate(
    'No category data yet',
    'ఇంకా విభాగ డేటా లేదు',
    'अभी तक कोई श्रेणी डेटा नहीं',
  );
  String get topPosts =>
      _translate('Top Posts', 'అగ్ర పోస్టులు', 'शीर्ष पोस्ट');
  String get untitledPost =>
      _translate('Untitled post', 'శీర్షికలేని పోస్ట్', 'बिना शीर्षक पोस्ट');
  String likesSharesSummary(int likes, int shares) => _translate(
    'Likes: $likes • Shares: $shares',
    'ఇష్టాలు: $likes • షేర్‌లు: $shares',
    'पसंद: $likes • शेयर: $shares',
  );
}
