import 'package:flutter/material.dart';

/// Floating controls displayed over the full-screen map.
///
/// This widget contains UI only.
/// It does not directly manipulate map controller.
class MapControls extends StatelessWidget {
  final VoidCallback? onMyLocation;

  final VoidCallback? onZoomIn;

  final VoidCallback? onZoomOut;




  /// Whether the map is currently obtaining
  /// the user's location.
  final bool isLoadingLocation;

  const MapControls({
    super.key,
    this.onMyLocation,
    this.onZoomIn,
    this.onZoomOut,


    this.isLoadingLocation = false,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        _MapControlButton(
          tooltip: 'My location',
          icon: isLoadingLocation
              ? Icons.location_searching_rounded
              : Icons.my_location_rounded,
          onPressed: isLoadingLocation
              ? null
              : onMyLocation,
        ),

        const SizedBox(height: 10),

        _ZoomControlGroup(
          onZoomIn: onZoomIn,
          onZoomOut: onZoomOut,
        ),
      ],
    );
  }
}

// ================================================================
// ZOOM CONTROL GROUP
// ================================================================

class _ZoomControlGroup
    extends StatelessWidget {
  final VoidCallback? onZoomIn;
  final VoidCallback? onZoomOut;

  const _ZoomControlGroup({
    required this.onZoomIn,
    required this.onZoomOut,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius:
          BorderRadius.circular(16),
      clipBehavior:
          Clip.antiAlias,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          _SmallMapButton(
            tooltip: 'Zoom in',
            icon: Icons.add_rounded,
            onPressed: onZoomIn,
          ),
          Container(
            height: 1,
            width: 30,
            color: colors
                .outlineVariant
                .withAlpha(80),
          ),
          _SmallMapButton(
            tooltip: 'Zoom out',
            icon: Icons.remove_rounded,
            onPressed: onZoomOut,
          ),
        ],
      ),
    );
  }
}

// ================================================================
// STANDARD MAP CONTROL
// ================================================================

class _MapControlButton
    extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _MapControlButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return Material(
      color: colors.surface,
      elevation: 4,
      shadowColor: Colors.black26,
      borderRadius:
          BorderRadius.circular(16),
      child: InkWell(
        onTap: onPressed,
        borderRadius:
            BorderRadius.circular(16),
        child: SizedBox(
          width: 48,
          height: 48,
          child: Tooltip(
            message: tooltip,
            child: Center(
              child: AnimatedSwitcher(
                duration:
                    const Duration(
                  milliseconds: 180,
                ),
                child: Icon(
                  icon,
                  key: ValueKey(icon),
                  size: 23,
                  color: onPressed == null
                      ? colors
                          .onSurfaceVariant
                          .withAlpha(100)
                      : colors.onSurface,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

// ================================================================
// SMALL MAP BUTTON
// ================================================================

class _SmallMapButton
    extends StatelessWidget {
  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;

  const _SmallMapButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    final colors =
        Theme.of(context).colorScheme;

    return InkWell(
      onTap: onPressed,
      child: Tooltip(
        message: tooltip,
        child: SizedBox(
          width: 48,
          height: 44,
          child: Center(
            child: Icon(
              icon,
              size: 23,
              color: onPressed == null
                  ? colors
                      .onSurfaceVariant
                      .withAlpha(100)
                  : colors.onSurface,
            ),
          ),
        ),
      ),
    );
  }
}
