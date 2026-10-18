import 'package:flutter_test/flutter_test.dart';

import 'package:alloop/features/avatar_coach/data/avatar_asset_registry.dart';
import 'package:alloop/features/avatar_coach/domain/models/avatar_coach_view_model.dart';

void main() {
  test(
    'all eight avatar states resolve their default GIF without fallback',
    () {
      for (final state in AvatarState.values) {
        final variant = AvatarAssetRegistry.defaultVariantFor(state);
        final lookup = AvatarAssetRegistry.lookup(state, variant);

        expect(lookup.assetPath, endsWith('.gif'), reason: state.name);
        expect(lookup.isFallback, isFalse, reason: state.name);
      }
    },
  );

  test('unknown variant uses stable state-specific fallback', () {
    final lookup = AvatarAssetRegistry.lookup(
      AvatarState.sleepy,
      'unknown_variant',
    );

    expect(lookup.assetPath, 'assets/avatar/panda/sleepy.gif');
    expect(lookup.isFallback, isTrue);
  });

  test('warning thermometer variant maps to warning GIF', () {
    final lookup = AvatarAssetRegistry.lookup(
      AvatarState.warning,
      'warning_cooling_patch_thermometer',
    );

    expect(lookup.assetPath, 'assets/avatar/panda/warning.gif');
    expect(lookup.isFallback, isFalse);
  });
}
