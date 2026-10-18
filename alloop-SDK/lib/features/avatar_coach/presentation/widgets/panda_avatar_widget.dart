import 'package:flutter/material.dart';

import '../../data/avatar_asset_registry.dart';
import '../../domain/models/avatar_coach_view_model.dart';

/// Renders the asset selected by the presentation registry at a stable size.
///
/// GIF playback is handled by Flutter's image codec. Loading or decode errors
/// never hide adjacent task or risk content.
class PandaAvatarWidget extends StatelessWidget {
  const PandaAvatarWidget({
    super.key,
    required this.state,
    required this.variant,
    required this.animationState,
    this.size = 176,
  });

  final AvatarState state;
  final String variant;
  final AnimationState animationState;
  final double size;

  @override
  Widget build(BuildContext context) {
    final asset = AvatarAssetRegistry.lookup(state, variant);

    return Semantics(
      image: true,
      label: '小熊猫 ${state.name}',
      child: SizedBox.square(
        key: const Key('panda-avatar-stable-frame'),
        dimension: size,
        child: Image.asset(
          asset.assetPath,
          key: ValueKey('panda-${state.name}-$variant'),
          width: size,
          height: size,
          fit: BoxFit.contain,
          gaplessPlayback: true,
          filterQuality: FilterQuality.medium,
          errorBuilder: (_, _, _) => _PandaFallback(
            size: size,
            state: state,
            registryFallback: asset.isFallback,
          ),
        ),
      ),
    );
  }
}

class _PandaFallback extends StatelessWidget {
  const _PandaFallback({
    required this.size,
    required this.state,
    required this.registryFallback,
  });

  final double size;
  final AvatarState state;
  final bool registryFallback;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('panda-avatar-fallback'),
      width: size,
      height: size,
      alignment: Alignment.center,
      decoration: const BoxDecoration(shape: BoxShape.circle),
      child: Icon(
        state == AvatarState.warning
            ? Icons.health_and_safety_outlined
            : Icons.sentiment_satisfied_alt_rounded,
        size: size * .42,
        color: Theme.of(context).colorScheme.primary,
        semanticLabel: registryFallback ? '熊猫占位图' : '熊猫资源加载失败',
      ),
    );
  }
}
