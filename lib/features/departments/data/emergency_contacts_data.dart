import 'package:flutter/material.dart';

enum EmergencyRegionScope { national, telangana }

enum EmergencyCategory {
  emergency,
  police,
  womenChild,
  cyber,
  health,
  civic,
  legal,
  land,
}

class EmergencyContactEntry {
  final String title;
  final IconData icon;
  final List<String> phones;
  final List<String> emails;
  final String? website;
  final EmergencyCategory category;
  final EmergencyRegionScope regionScope;
  final String verifiedAt;
  final String sourceUrl;

  const EmergencyContactEntry({
    required this.title,
    required this.icon,
    this.phones = const [],
    this.emails = const [],
    this.website,
    required this.category,
    required this.regionScope,
    required this.verifiedAt,
    required this.sourceUrl,
  });
}

class EmergencyContactSection {
  final EmergencyRegionScope scope;
  final List<EmergencyContactEntry> contacts;

  const EmergencyContactSection({required this.scope, required this.contacts});
}

class EmergencyContactsData {
  static const List<EmergencyContactSection> sections = [
    EmergencyContactSection(
      scope: EmergencyRegionScope.national,
      contacts: [
        EmergencyContactEntry(
          title: 'Emergency Response Support System',
          icon: Icons.sos_rounded,
          phones: ['112'],
          website: 'https://112.gov.in/',
          category: EmergencyCategory.emergency,
          regionScope: EmergencyRegionScope.national,
          verifiedAt: '2026-03-22',
          sourceUrl: 'https://112.gov.in/',
        ),
        EmergencyContactEntry(
          title: 'Police Emergency',
          icon: Icons.local_police_outlined,
          phones: ['100'],
          website: 'https://112.gov.in/states',
          category: EmergencyCategory.police,
          regionScope: EmergencyRegionScope.national,
          verifiedAt: '2026-03-22',
          sourceUrl: 'https://112.gov.in/states',
        ),
        EmergencyContactEntry(
          title: 'Fire Service Emergency',
          icon: Icons.fire_truck_outlined,
          phones: ['101'],
          website: 'https://112.gov.in/states',
          category: EmergencyCategory.emergency,
          regionScope: EmergencyRegionScope.national,
          verifiedAt: '2026-03-22',
          sourceUrl: 'https://112.gov.in/states',
        ),
        EmergencyContactEntry(
          title: 'Ambulance',
          icon: Icons.medical_services_outlined,
          phones: ['108'],
          website: 'https://112.gov.in/states',
          category: EmergencyCategory.health,
          regionScope: EmergencyRegionScope.national,
          verifiedAt: '2026-03-22',
          sourceUrl: 'https://112.gov.in/states',
        ),
        EmergencyContactEntry(
          title: 'Women Helpline',
          icon: Icons.woman_outlined,
          phones: ['181'],
          website: 'https://wcd.gov.in/',
          category: EmergencyCategory.womenChild,
          regionScope: EmergencyRegionScope.national,
          verifiedAt: '2026-03-22',
          sourceUrl: 'https://wcd.gov.in/',
        ),
        EmergencyContactEntry(
          title: 'Child Helpline',
          icon: Icons.child_care_outlined,
          phones: ['1098'],
          website: 'https://www.india.gov.in/',
          category: EmergencyCategory.womenChild,
          regionScope: EmergencyRegionScope.national,
          verifiedAt: '2026-03-22',
          sourceUrl: 'https://www.india.gov.in/',
        ),
        EmergencyContactEntry(
          title: 'Cyber Financial Fraud Helpline',
          icon: Icons.security_rounded,
          phones: ['1930'],
          website: 'https://www.cybercrime.gov.in/',
          category: EmergencyCategory.cyber,
          regionScope: EmergencyRegionScope.national,
          verifiedAt: '2026-03-22',
          sourceUrl: 'https://www.cybercrime.gov.in/',
        ),
        EmergencyContactEntry(
          title: 'National Legal Services Authority',
          icon: Icons.gavel_outlined,
          phones: ['15100'],
          emails: ['nalsa-dla@nic.in'],
          website: 'https://nalsa.gov.in/contact-us',
          category: EmergencyCategory.legal,
          regionScope: EmergencyRegionScope.national,
          verifiedAt: '2026-03-22',
          sourceUrl: 'https://nalsa.gov.in/contact-us',
        ),
      ],
    ),
    EmergencyContactSection(
      scope: EmergencyRegionScope.telangana,
      contacts: [
        EmergencyContactEntry(
          title: 'Telangana State Police',
          icon: Icons.local_police,
          phones: ['100', '112'],
          website: 'https://www.tspolice.gov.in/',
          category: EmergencyCategory.police,
          regionScope: EmergencyRegionScope.telangana,
          verifiedAt: '2026-03-22',
          sourceUrl: 'https://www.tspolice.gov.in/',
        ),
        EmergencyContactEntry(
          title: 'Hyderabad City Police',
          icon: Icons.location_city_rounded,
          website: 'https://www.hyderabadpolice.gov.in/',
          category: EmergencyCategory.police,
          regionScope: EmergencyRegionScope.telangana,
          verifiedAt: '2026-03-22',
          sourceUrl: 'https://www.hyderabadpolice.gov.in/',
        ),
        EmergencyContactEntry(
          title: 'MeeSeva Telangana',
          icon: Icons.miscellaneous_services_outlined,
          website: 'https://www.meeseva.telangana.gov.in/',
          category: EmergencyCategory.civic,
          regionScope: EmergencyRegionScope.telangana,
          verifiedAt: '2026-03-22',
          sourceUrl: 'https://www.meeseva.telangana.gov.in/',
        ),
        EmergencyContactEntry(
          title: 'Dharani Telangana',
          icon: Icons.landscape_outlined,
          website: 'https://dharani.telangana.gov.in/',
          category: EmergencyCategory.land,
          regionScope: EmergencyRegionScope.telangana,
          verifiedAt: '2026-03-22',
          sourceUrl: 'https://dharani.telangana.gov.in/',
        ),
        EmergencyContactEntry(
          title: 'Telangana State Legal Services Authority',
          icon: Icons.balance_outlined,
          phones: ['040-23446724'],
          website: 'https://telangana.nalsa.gov.in/',
          category: EmergencyCategory.legal,
          regionScope: EmergencyRegionScope.telangana,
          verifiedAt: '2026-03-22',
          sourceUrl: 'https://telangana.nalsa.gov.in/',
        ),
      ],
    ),
  ];
}
