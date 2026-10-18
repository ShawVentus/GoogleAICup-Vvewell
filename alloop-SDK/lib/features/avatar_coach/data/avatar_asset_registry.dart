import '../domain/models/avatar_coach_view_model.dart';

class AvatarAssetLookup {
  const AvatarAssetLookup({required this.assetPath, required this.isFallback});

  final String assetPath;
  final bool isFallback;
}

class AvatarAssetRegistry {
  const AvatarAssetRegistry._();

  static const String stableFallbackAsset = 'assets/avatar/panda/normal.gif';

  static const Map<AvatarState, String> defaultVariants = {
    AvatarState.normal: 'normal_breathe_blink',
    AvatarState.happy: 'happy_wave',
    AvatarState.sleepy: 'sleepy_yawn_pillow',
    AvatarState.stressed: 'stressed_tense_breathe',
    AvatarState.inactive: 'inactive_neck_stretch',
    AvatarState.recovery: 'recovery_blanket_breathe',
    AvatarState.warning: 'warning_cooling_patch_thermometer',
    AvatarState.completedBoost: 'completed_boost_stars',
  };

  static const Map<AvatarState, String> _defaultAssets = {
    AvatarState.normal: 'assets/avatar/panda/normal.gif',
    AvatarState.happy: 'assets/avatar/panda/happy.gif',
    AvatarState.sleepy: 'assets/avatar/panda/sleepy.gif',
    AvatarState.stressed: 'assets/avatar/panda/stressed.gif',
    AvatarState.inactive: 'assets/avatar/panda/inactive.gif',
    AvatarState.recovery: 'assets/avatar/panda/recovery.gif',
    AvatarState.warning: 'assets/avatar/panda/warning.gif',
    AvatarState.completedBoost: 'assets/avatar/panda/completed_boost.gif',
  };

  static final Map<String, String> _assetsByStateAndVariant = {
    for (final entry in defaultVariants.entries)
      _key(entry.key, entry.value):
          _defaultAssets[entry.key] ?? stableFallbackAsset,
  };

  static AvatarAssetLookup lookup(
    AvatarState avatarState,
    String avatarVariant,
  ) {
    final exactAsset =
        _assetsByStateAndVariant[_key(avatarState, avatarVariant)];
    if (exactAsset != null) {
      return AvatarAssetLookup(assetPath: exactAsset, isFallback: false);
    }

    return AvatarAssetLookup(
      assetPath: _defaultAssets[avatarState] ?? stableFallbackAsset,
      isFallback: true,
    );
  }

  static String defaultVariantFor(AvatarState avatarState) {
    return defaultVariants[avatarState] ?? defaultVariants[AvatarState.normal]!;
  }

  static String _key(AvatarState state, String variant) =>
      '${state.name}:$variant';
}
