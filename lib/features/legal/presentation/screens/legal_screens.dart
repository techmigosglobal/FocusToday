import 'package:flutter/material.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../core/services/post_translation_service.dart';
import '../../../../main.dart';

class PrivacyPolicyScreen extends StatelessWidget {
  const PrivacyPolicyScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang =
        FocusTodayApp.languageService?.currentLanguage ?? AppLanguage.english;
    final l = AppLocalizations(lang);

    return _LegalDocumentScreen(
      title: l.privacyPolicy,
      dateLine: 'Last updated: March 2026',
      sections: const [
        _LegalSection(
          title: '1. Information We Collect',
          content:
              'Focus Today collects limited information when you register and use the app:\n'
              '• Personal information: Name, phone number, district, state\n'
              '• Usage data: Posts, comments, interactions within the app\n'
              '• Device information: Device type, operating system version\n'
              '• Location data: District and state (as provided by you)',
        ),
        _LegalSection(
          title: '2. How We Use Your Information',
          content:
              '• To provide and maintain news feed, meetings, and workspace features\n'
              '• To support account security and role-based access\n'
              '• To deliver app notifications and service messages\n'
              '• To improve reliability, performance, and user experience',
        ),
        _LegalSection(
          title: '3. Information Sharing',
          content:
              'Focus Today does not sell your personal information. Data may be shared only:\n'
              '• When required by law or government request\n'
              '• With trusted infrastructure providers required to run the service',
        ),
        _LegalSection(
          title: '4. Data Security',
          content:
              'We implement appropriate security measures to protect your personal information. '
              'Data is stored on secure servers and transmitted using encryption. '
              'However, no method of electronic storage is 100% secure.',
        ),
        _LegalSection(
          title: '5. Your Rights',
          content:
              '• Access your personal data at any time through the app\n'
              '• Request correction of inaccurate data\n'
              '• Request deletion of your account and associated data\n'
              '• Opt out of non-essential notifications',
        ),
        _LegalSection(
          title: '6. Children\'s Privacy',
          content:
              'Focus Today is not intended for children under 13. We do not knowingly collect '
              'personal information from children under 13.',
        ),
        _LegalSection(
          title: '7. Changes to This Policy',
          content:
              'We may update this Privacy Policy from time to time. We will notify '
              'you of any changes by posting the new policy within the app.',
        ),
        _LegalSection(
          title: '8. Contact Us',
          content:
              'For questions about this Privacy Policy, contact us through the app '
              'feedback section or email us at support@techmigos.com.',
        ),
      ],
    );
  }
}

class TermsOfUseScreen extends StatelessWidget {
  const TermsOfUseScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang =
        FocusTodayApp.languageService?.currentLanguage ?? AppLanguage.english;
    final l = AppLocalizations(lang);

    return _LegalDocumentScreen(
      title: l.termsOfUse,
      dateLine: 'Effective: March 2026',
      sections: const [
        _LegalSection(
          title: '1. Acceptance of Terms',
          content:
              'By accessing and using Focus Today, you agree to be bound by these Terms of Use. '
              'If you do not agree to these terms, please do not use the application.',
        ),
        _LegalSection(
          title: '2. User Accounts',
          content:
              '• You must provide accurate information during registration\n'
              '• You are responsible for maintaining the security of your account\n'
              '• One account per person; duplicate accounts may be removed\n'
              '• You must be at least 13 years old to create an account',
        ),
        _LegalSection(
          title: '3. Content Guidelines',
          content:
              '• All content must be respectful and appropriate\n'
              '• No hate speech, harassment, or discriminatory content\n'
              '• No false or misleading information\n'
              '• No spam, advertisements, or promotional content without approval\n'
              '• Content should be relevant to public information and community interest',
        ),
        _LegalSection(
          title: '4. Intellectual Property',
          content:
              '• Focus Today and TechMigos own rights to the app and its design\n'
              '• User-generated content remains the property of the user\n'
              '• By posting, you grant Focus Today a license to display your content\n'
              '• Respect copyright and intellectual property of others',
        ),
        _LegalSection(
          title: '5. Termination',
          content:
              'Focus Today reserves the right to suspend or terminate your account '
              'if you violate these terms, engage in harmful behavior, or disrupt '
              'the community platform.',
        ),
        _LegalSection(
          title: '6. Limitation of Liability',
          content:
              'Focus Today is provided "as is" without warranty. We are not liable for '
              'any direct, indirect, incidental, or consequential damages arising '
              'from your use of the application.',
        ),
        _LegalSection(
          title: '7. Governing Law',
          content:
              'These terms are governed by the laws of India. Any disputes shall '
              'be resolved in the courts of Telangana, India.',
        ),
      ],
    );
  }
}

class DisclaimerScreen extends StatelessWidget {
  const DisclaimerScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang =
        FocusTodayApp.languageService?.currentLanguage ?? AppLanguage.english;
    final l = AppLocalizations(lang);

    return _LegalDocumentScreen(
      title: l.disclaimer,
      sections: const [
        _LegalSection(
          title: 'General Disclaimer',
          content:
              'Focus Today is a digital news and information platform maintained by '
              'TechMigos. Views and opinions expressed in user-generated content are '
              'those of the individual authors and do not necessarily reflect the '
              'official position of Focus Today or TechMigos.',
        ),
        _LegalSection(
          title: 'Content Accuracy',
          content:
              'While we strive to keep the information on Focus Today accurate and up-to-date, '
              'we make no representations or warranties of any kind, express or implied, '
              'about the completeness, accuracy, reliability, or suitability of the content. '
              'Any reliance you place on such information is strictly at your own risk.',
        ),
        _LegalSection(
          title: 'External Links',
          content:
              'Focus Today may contain links to external websites. We have no control over '
              'the nature, content, and availability of those sites. Inclusion of any '
              'links does not imply a recommendation.',
        ),
        _LegalSection(
          title: 'Platform Scope',
          content:
              'Focus Today provides publishing and discovery features for approved content. '
              'The app is not a substitute for legal, medical, financial, or official '
              'government advisory services. Please verify critical information from '
              'official sources before acting on it.',
        ),
      ],
    );
  }
}

class _LegalDocumentScreen extends StatelessWidget {
  final String title;
  final String? dateLine;
  final List<_LegalSection> sections;

  const _LegalDocumentScreen({
    required this.title,
    required this.sections,
    this.dateLine,
  });

  @override
  Widget build(BuildContext context) {
    final targetCode =
        (FocusTodayApp.languageService?.currentLanguage ?? AppLanguage.english)
            .code;
    final showTranslatedBody = targetCode != 'en';

    return Scaffold(
      appBar: AppBar(
        title: Text(title),
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            if (dateLine != null) ...[
              const SizedBox(height: 4),
              _TranslatedLegalText(
                dateLine!,
                targetLanguageCode: targetCode,
                style: TextStyle(
                  color: AppColors.textSecondaryOf(context),
                  fontSize: 13,
                ),
                enableTranslation: showTranslatedBody,
              ),
            ],
            const SizedBox(height: 20),
            ...sections.map(
              (section) => _LegalSectionView(
                section: section,
                targetLanguageCode: targetCode,
                enableTranslation: showTranslatedBody,
              ),
            ),
            const SizedBox(height: 40),
          ],
        ),
      ),
    );
  }
}

class _LegalSection {
  final String title;
  final String content;

  const _LegalSection({required this.title, required this.content});
}

class _LegalSectionView extends StatelessWidget {
  final _LegalSection section;
  final String targetLanguageCode;
  final bool enableTranslation;

  const _LegalSectionView({
    required this.section,
    required this.targetLanguageCode,
    required this.enableTranslation,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _TranslatedLegalText(
            section.title,
            targetLanguageCode: targetLanguageCode,
            style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            enableTranslation: enableTranslation,
          ),
          const SizedBox(height: 8),
          _TranslatedLegalText(
            section.content,
            targetLanguageCode: targetLanguageCode,
            style: TextStyle(
              fontSize: 14,
              height: 1.6,
              color: AppColors.textPrimaryOf(context),
            ),
            enableTranslation: enableTranslation,
          ),
        ],
      ),
    );
  }
}

class _TranslatedLegalText extends StatefulWidget {
  final String text;
  final String targetLanguageCode;
  final TextStyle style;
  final bool enableTranslation;

  const _TranslatedLegalText(
    this.text, {
    required this.targetLanguageCode,
    required this.style,
    required this.enableTranslation,
  });

  @override
  State<_TranslatedLegalText> createState() => _TranslatedLegalTextState();
}

class _TranslatedLegalTextState extends State<_TranslatedLegalText> {
  late Future<String> _textFuture;

  @override
  void initState() {
    super.initState();
    _textFuture = _resolveText();
  }

  @override
  void didUpdateWidget(covariant _TranslatedLegalText oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.text != widget.text ||
        oldWidget.targetLanguageCode != widget.targetLanguageCode ||
        oldWidget.enableTranslation != widget.enableTranslation) {
      _textFuture = _resolveText();
    }
  }

  Future<String> _resolveText() async {
    if (!widget.enableTranslation) return widget.text;
    return PostTranslationService.translate(
      text: widget.text,
      sourceLanguageCode: 'en',
      targetLanguageCode: widget.targetLanguageCode,
    );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String>(
      future: _textFuture,
      builder: (context, snapshot) {
        final text = snapshot.data ?? widget.text;
        return Text(text, style: widget.style);
      },
    );
  }
}
