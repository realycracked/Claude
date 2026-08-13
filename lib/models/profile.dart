/// Un profil utilisateur (façon Netflix). Plusieurs par compte.
class Profile {
  Profile({
    required this.id,
    required this.name,
    this.avatar = 'avatar_1',
    this.preferences = const {},
  });

  final String id;
  final String name;
  final String avatar;
  final Map<String, dynamic> preferences;

  Profile copyWith({
    String? name,
    String? avatar,
    Map<String, dynamic>? preferences,
  }) {
    return Profile(
      id: id,
      name: name ?? this.name,
      avatar: avatar ?? this.avatar,
      preferences: preferences ?? this.preferences,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'name': name,
        'avatar': avatar,
        'preferences': preferences,
      };

  factory Profile.fromJson(Map<String, dynamic> j) => Profile(
        id: j['id']?.toString() ?? '',
        name: j['name']?.toString() ?? 'Profil',
        avatar: j['avatar']?.toString() ?? 'avatar_1',
        preferences:
            (j['preferences'] as Map?)?.cast<String, dynamic>() ?? const {},
      );
}
