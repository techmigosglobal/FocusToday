/// Partner / Member model for CRII enrollment system
class Partner {
  final int? id;
  final String name;
  final String phoneNumber;
  final String district;
  final String state;
  final String profession;
  final String? institution;
  final String? placeOfWorship;
  final String? userId;
  final String status; // pending, approved, rejected
  final DateTime createdAt;

  Partner({
    this.id,
    required this.name,
    required this.phoneNumber,
    required this.district,
    required this.state,
    required this.profession,
    this.institution,
    this.placeOfWorship,
    this.userId,
    this.status = 'approved',
    DateTime? createdAt,
  }) : createdAt = createdAt ?? DateTime.now();

  Map<String, dynamic> toJson() => {
    'name': name,
    'phone_number': phoneNumber,
    'district': district,
    'state': state,
    'profession': profession,
    'institution': institution,
    'place_of_worship': placeOfWorship,
    'user_id': userId,
  };

  factory Partner.fromJson(Map<String, dynamic> json) => Partner(
    id: json['id'] is int
        ? json['id']
        : int.tryParse(json['id']?.toString() ?? ''),
    name: json['name'] ?? '',
    phoneNumber: json['phone_number'] ?? '',
    district: json['district'] ?? '',
    state: json['state'] ?? '',
    profession: json['profession'] ?? '',
    institution: json['institution'],
    placeOfWorship: json['place_of_worship'],
    userId: json['user_id'],
    status: json['status'] ?? 'approved',
    createdAt: json['created_at'] != null
        ? DateTime.tryParse(json['created_at'].toString()) ?? DateTime.now()
        : DateTime.now(),
  );
}
