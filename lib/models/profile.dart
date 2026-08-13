/// Un profil utilisateur (façon Netflix). Plusieurs par compte.
class Profile {
  Profile({
    required this.id,
    required this.name,
    this.avatar = 'avatar_1',
    this.isKids = false,
    this.pinHash,
    this.adultUnlocked = false,
    this.preferences = const {},
  });

  final String id;
  final String name;
  final String avatar;
  final bool isKids;

  /// Code PIN hashé (contrôle parental). Null = pas de PIN.
  final String? pinHash;

  /// Le profil a-t-il déverrouillé les chaînes adultes (via /activeX) ?
  final bool adultUnlocked;

  final Map<String, dynamic> preferences;

  bool get hasPin => pinHash != null && pinHash!.isNotEmpty;

  Profile copyWith({
    String? name,
    String? avatar,
    bool? isKids,
    String? pinHash,
    bool clearPin = false,
    bool? adultUnlocked,
    Map<String, dynamic>? preferences,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      isKids: isKids ?? this.isKids,
      pinHash: clearPin ? null : (pinHash ?? this.pinHash),
      adultUnlocked: adultUnlocked ?? this.adultUnlocked,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'is_kids': isKids,
        'pin_hash': pinHash,
        'adult_unlocked': adultUnlocked,
        'preferences': preferences,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? 'Profil',
        avatar: j['avatar']?.toString() ?? 'avatar_1',
        isKids: j['is_kids'] as bool? ?? false,
        pinHash: j['pin_hash']?.toString(),
        adultUnlocked: j['adult_unlocked'] as bool? ?? false,
        preferences:
            (j['preferences'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}
