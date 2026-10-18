import 'dart:ui' as ui;

import 'package:alloop/features/avatar_coach/data/avatar_asset_registry.dart';
import 'package:alloop/features/avatar_coach/domain/models/avatar_coach_view_model.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  test('all avatar states use real multi-frame looping GIFs', () async {
    for (final state in AvatarState.values) {
      final lookup = AvatarAssetRegistry.lookup(
        state,
        AvatarAssetRegistry.defaultVariantFor(state),
      );
      final data = await rootBundle.load(lookup.assetPath);
      final codec = await ui.instantiateImageCodec(
        data.buffer.asUint8List(data.offsetInBytes, data.lengthInBytes),
      );
      addTearDown(codec.dispose);

      expect(codec.frameCount, greaterThan(1), reason: state.name);
      expect(codec.repetitionCount, -1, reason: state.name);

      final firstFrame = await codec.getNextFrame();
      expect(firstFrame.image.width, 512, reason: state.name);
      expect(firstFrame.image.height, 512, reason: state.name);
      firstFrame.image.dispose();
    }
  });
}
