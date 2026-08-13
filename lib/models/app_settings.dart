/// Préférences de l'application (persistées localement et applicables à chaud).
class AppSettings {
  const AppSettings({
    this.contentLanguage = 'fr-FR',
    this.accent = 'red',
    this.preferredQuality = 'auto',
    this.autoplayNext = true,
    this.autoplayPreviews = false,
    this.rememberPosition = true,
    this.subtitlesEnabled = true,
    this.subtitleLanguage = 'Français',
    this.playbackSpeed = 1.0,
    this.seekSeconds = 10,
    this.wifiOnlyDownloads = true,
    this.dataSaver = false,
    this.hardwareAcceleration = true,
    this.showTop10 = true,
  });

  final String contentLanguage; // fr-FR, en-US, ...
  final String accent; // red, blue, purple, green, orange
  final String preferredQuality; // auto, 4K, 1080p, 720p
  final bool autoplayNext; // enchaîner l'épisode suivant
  final bool autoplayPreviews; // aperçus animés à l'accueil
  final bool rememberPosition; // "Continuer à regarder"
  final bool subtitlesEnabled;
  final String subtitleLanguage;
  final double playbackSpeed; // 0.5 .. 2.0
  final int seekSeconds; // avance/recul rapide
  final bool wifiOnlyDownloads;
  final bool dataSaver; // qualité réduite en mobile
  final bool hardwareAcceleration;
  final bool showTop10;

  AppSettings copyWith({
    String? contentLanguage,
    String? accent,
    String? preferredQuality,
    bool? autoplayNext,
    bool? autoplayPreviews,
    bool? rememberPosition,
    bool? subtitlesEnabled,
    String? subtitleLanguage,
    double? playbackSpeed,
    int? seekSeconds,
    bool? wifiOnlyDownloads,
    bool? dataSaver,
    bool? hardwareAcceleration,
    bool? showTop10,
  }) {
    return AppSettings(
      contentLanguage: contentLanguage ?? this.contentLanguage,
      accent: accent ?? this.accent,
      preferredQuality: preferredQuality ?? this.preferredQuality,
      autoplayNext: autoplayNext ?? this.autoplayNext,
      autoplayPreviews: autoplayPreviews ?? this.autoplayPreviews,
      rememberPosition: rememberPosition ?? this.rememberPosition,
      subtitlesEnabled: subtitlesEnabled ?? this.subtitlesEnabled,
      subtitleLanguage: subtitleLanguage ?? this.subtitleLanguage,
      playbackSpeed: playbackSpeed ?? this.playbackSpeed,
      seekSeconds: seekSeconds ?? this.seekSeconds,
      wifiOnlyDownloads: wifiOnlyDownloads ?? this.wifiOnlyDownloads,
      dataSaver: dataSaver ?? this.dataSaver,
      hardwareAcceleration: hardwareAcceleration ?? this.hardwareAcceleration,
      showTop10: showTop10 ?? this.showTop10,
    );
  }

  Map<String, dynamic> toJson() => {
        'contentLanguage': contentLanguage,
        'accent': accent,
        'preferredQuality': preferredQuality,
        'autoplayNext': autoplayNext,
        'autoplayPreviews': autoplayPreviews,
        'rememberPosition': rememberPosition,
        'subtitlesEnabled': subtitlesEnabled,
        'subtitleLanguage': subtitleLanguage,
        'playbackSpeed': playbackSpeed,
        'seekSeconds': seekSeconds,
        'wifiOnlyDownloads': wifiOnlyDownloads,
        'dataSaver': dataSaver,
        'hardwareAcceleration': hardwareAcceleration,
        'showTop10': showTop10,
      };

  factory AppSettings.fromJson(Map<String, dynamic> j) => AppSettings(
        contentLanguage: j['contentLanguage']?.toString() ?? 'fr-FR',
        accent: j['accent']?.toString() ?? 'red',
        preferredQuality: j['preferredQuality']?.toString() ?? 'auto',
        autoplayNext: j['autoplayNext'] as bool? ?? true,
        autoplayPreviews: j['autoplayPreviews'] as bool? ?? false,
        rememberPosition: j['rememberPosition'] as bool? ?? true,
        subtitlesEnabled: j['subtitlesEnabled'] as bool? ?? true,
        subtitleLanguage: j['subtitleLanguage']?.toString() ?? 'Français',
        playbackSpeed: (j['playbackSpeed'] as num?)?.toDouble() ?? 1.0,
        seekSeconds: (j['seekSeconds'] as num?)?.toInt() ?? 10,
        wifiOnlyDownloads: j['wifiOnlyDownloads'] as bool? ?? true,
        dataSaver: j['dataSaver'] as bool? ?? false,
        hardwareAcceleration: j['hardwareAcceleration'] as bool? ?? true,
        showTop10: j['showTop10'] as bool? ?? true,
      );

  /// Table des couleurs d'accent disponibles (nom → valeur ARGB).
  static const accentOptions = <String, int>{
    'red': 0xFFE50914,
    'blue': 0xFF2979FF,
    'purple': 0xFF8E24AA,
    'green': 0xFF00C853,
    'orange': 0xFFFF6D00,
  };

  static const languageOptions = <String, String>{
    'fr-FR': 'Français',
    'en-US': 'Anglais',
    'es-ES': 'Espagnol',
    'de-DE': 'Allemand',
    'it-IT': 'Italien',
    'ar-SA': 'Arabe',
  };
}
