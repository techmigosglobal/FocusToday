import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../../app/theme/app_colors.dart';
import '../../../../core/localization/app_localizations.dart';
import '../../../../core/services/language_service.dart';
import '../../../../main.dart';
import '../../data/emergency_contacts_data.dart';

class DepartmentsScreen extends StatelessWidget {
  const DepartmentsScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final lang =
        FocusTodayApp.languageService?.currentLanguage ?? AppLanguage.english;
    final l = AppLocalizations(lang);

    return Scaffold(
      appBar: AppBar(
        title: Text(l.emergencyContacts),
        backgroundColor: AppColors.primary,
        foregroundColor: AppColors.onPrimaryOf(context),
      ),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              l.departmentInfo,
              style: TextStyle(
                fontSize: 14,
                color: AppColors.textSecondaryOf(context),
                height: 1.5,
              ),
            ),
            const SizedBox(height: 20),
            _ContactSection(
              title: l.emergencyNumbers,
              icon: Icons.public_rounded,
              entries: EmergencyContactsData.sections
                  .firstWhere((s) => s.scope == EmergencyRegionScope.national)
                  .contacts,
            ),
            _ContactSection(
              title: l.telanganaContacts,
              icon: Icons.location_city_rounded,
              entries: EmergencyContactsData.sections
                  .firstWhere((s) => s.scope == EmergencyRegionScope.telangana)
                  .contacts,
            ),
            const SizedBox(height: 12),
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: AppColors.primary.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: AppColors.primary.withValues(alpha: 0.15),
                ),
              ),
              child: Row(
                children: [
                  Icon(Icons.info_outline, color: AppColors.primary, size: 20),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      l.deptDisclaimer,
                      style: TextStyle(
                        fontSize: 12,
                        color: AppColors.textSecondaryOf(context),
                        height: 1.4,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

class _ContactSection extends StatelessWidget {
  final String title;
  final IconData icon;
  final List<EmergencyContactEntry> entries;

  const _ContactSection({
    required this.title,
    required this.icon,
    required this.entries,
  });

  @override
  Widget build(BuildContext context) {
    final color = AppColors.primaryOf(context);
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.08),
              borderRadius: const BorderRadius.vertical(
                top: Radius.circular(16),
              ),
            ),
            child: Row(
              children: [
                Icon(icon, color: color, size: 22),
                const SizedBox(width: 10),
                Text(
                  title,
                  style: TextStyle(
                    fontSize: 16,
                    fontWeight: FontWeight.bold,
                    color: color,
                  ),
                ),
              ],
            ),
          ),
          ...entries.map((entry) => _ContactTile(entry: entry)),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  final EmergencyContactEntry entry;

  const _ContactTile({required this.entry});

  Future<void> _launchUrlString(String url) async {
    final uri = Uri.parse(url);
    await launchUrl(uri, mode: LaunchMode.externalApplication);
  }

  Future<void> _dial(String rawPhone) async {
    final digits = rawPhone.replaceAll(RegExp(r'[^0-9+]'), '');
    if (digits.isEmpty) return;
    await _launchUrlString('tel:$digits');
  }

  Future<void> _mail(String email) async {
    await _launchUrlString('mailto:$email');
  }

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations(
      FocusTodayApp.languageService?.currentLanguage ?? AppLanguage.english,
    );
    final primary = AppColors.primaryOf(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final hasWebsite = (entry.website?.trim().isNotEmpty ?? false);
    final hasPhones = entry.phones.isNotEmpty;
    final hasEmails = entry.emails.isNotEmpty;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 12, 12),
      decoration: BoxDecoration(
        border: Border(
          top: BorderSide(color: AppColors.dividerOf(context), width: 0.8),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 34,
                height: 34,
                decoration: BoxDecoration(
                  color: primary.withValues(alpha: isDark ? 0.3 : 0.12),
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(
                    color: primary.withValues(alpha: isDark ? 0.55 : 0.24),
                  ),
                ),
                child: Icon(
                  entry.icon,
                  size: 18,
                  color: isDark ? Colors.white : primary,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  entry.title,
                  style: TextStyle(
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    color: AppColors.textPrimaryOf(context),
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              ...entry.phones.map(
                (phone) => _ActionChip(
                  icon: Icons.call_rounded,
                  label: '${l.callAction} $phone',
                  onTap: () => _dial(phone),
                ),
              ),
              ...entry.emails.map(
                (email) => _ActionChip(
                  icon: Icons.email_rounded,
                  label: '${l.emailAction} ${email.toLowerCase()}',
                  onTap: () => _mail(email),
                ),
              ),
              if (hasWebsite)
                _ActionChip(
                  icon: Icons.language_rounded,
                  label: l.websiteAction,
                  onTap: () => _launchUrlString(entry.website!),
                ),
            ],
          ),
          if (hasEmails) ...[
            const SizedBox(height: 6),
            Text(
              entry.emails.join('  |  '),
              style: TextStyle(
                fontSize: 12,
                color: AppColors.textSecondaryOf(context),
              ),
            ),
          ],
          if (hasPhones || hasWebsite) const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Text(
                  '${l.verifiedOnLabel}: ${entry.verifiedAt}',
                  style: TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondaryOf(context),
                  ),
                ),
              ),
              GestureDetector(
                onTap: () => _launchUrlString(entry.sourceUrl),
                child: Text(
                  l.sourceLabel,
                  style: TextStyle(
                    fontSize: 12,
                    color: primary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _ActionChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Future<void> Function() onTap;

  const _ActionChip({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final bg = isDark
        ? AppColors.primaryOf(context).withValues(alpha: 0.24)
        : AppColors.primary.withValues(alpha: 0.1);
    final fg = isDark ? Colors.white : AppColors.primary;

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 11, vertical: 7),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppColors.primaryOf(
              context,
            ).withValues(alpha: isDark ? 0.55 : 0.25),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 15, color: fg),
            const SizedBox(width: 5),
            Text(
              label,
              style: TextStyle(
                fontSize: 12,
                color: fg,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
