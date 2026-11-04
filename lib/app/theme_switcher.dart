import 'package:flutter/material.dart';
import 'package:get/get.dart';
import 'package:vardhman_b2b/app/theme_variants.dart';
import 'package:vardhman_b2b/common/adaptive_dialog.dart';

/// Dialog listing every [ThemeVariants.all] entry as a preview tile. Tapping
/// one closes the dialog, then applies and saves the theme.
class ThemeSwitcherDialog extends StatefulWidget {
  const ThemeSwitcherDialog({super.key});

  @override
  State<ThemeSwitcherDialog> createState() => _ThemeSwitcherDialogState();
}

class _ThemeSwitcherDialogState extends State<ThemeSwitcherDialog> {
  final _themeController = Get.find<ThemeController>();

  late final String _selectedId = _themeController.rxVariant.value.id;

  bool _isClosing = false;

  void _choose(AppThemeVariant variant) {
    if (_isClosing) {
      return;
    }

    _isClosing = true;

    final route = ModalRoute.of(context);

    // Removed without its closing animation and switched in the same frame:
    // the new theme shows on the very next frame. (Animating the dialog out
    // while the app rebuilds made the close stutter, and waiting for the
    // animation first made the switch feel slow.)
    if (route != null && route.isActive) {
      Navigator.of(context).removeRoute(route);
    }

    _themeController.select(variant);
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    return AdaptiveDialog(
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 760),
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Icon(Icons.palette_outlined,
                      color: theme.colorScheme.primary),
                  const SizedBox(width: 8),
                  Expanded(
                    child: Text(
                      'Choose a theme',
                      style: theme.textTheme.titleMedium?.copyWith(
                        fontWeight: FontWeight.bold,
                        color: theme.colorScheme.secondary,
                      ),
                    ),
                  ),
                  IconButton(
                    tooltip: 'Close',
                    icon: const Icon(Icons.close),
                    onPressed: Get.back,
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: SingleChildScrollView(
                  child: Wrap(
                    spacing: 12,
                    runSpacing: 12,
                    children: [
                      for (final variant in ThemeVariants.all)
                        _VariantPreviewTile(
                          key: ValueKey(variant.id),
                          variant: variant,
                          isSelected: _selectedId == variant.id,
                          onTap: () => _choose(variant),
                        ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'The choice is saved on this device.',
                style: theme.textTheme.bodySmall,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Miniature of the app in [variant]'s colours: the patterned header with
/// the theme's icon, a gradient primary button, and status markers.
class _VariantPreviewTile extends StatelessWidget {
  final AppThemeVariant variant;

  final bool isSelected;

  final VoidCallback onTap;

  const _VariantPreviewTile({
    super.key,
    required this.variant,
    required this.isSelected,
    required this.onTap,
  });

  Widget _dot(Color color, String label, TextStyle? style) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Container(
          width: 8,
          height: 8,
          decoration: BoxDecoration(color: color, shape: BoxShape.circle),
        ),
        const SizedBox(width: 3),
        Text(label, style: style),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);

    final onPrimary =
        ThemeData.estimateBrightnessForColor(variant.primary) == Brightness.dark
            ? Colors.white
            : Colors.black87;

    final smallStyle =
        theme.textTheme.labelSmall?.copyWith(color: variant.accent);

    return RepaintBoundary(
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(12),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 150),
            width: 228,
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color: isSelected ? variant.primary : theme.dividerColor,
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                        color: variant.primary.withAlpha(60),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                    ]
                  : null,
            ),
            clipBehavior: Clip.antiAlias,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                SizedBox(
                  height: 56,
                  child: ThemeBackdrop(
                    variant: variant,
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    child: Padding(
                      padding: const EdgeInsets.symmetric(horizontal: 10),
                      child: Row(
                        children: [
                          Container(
                            width: 32,
                            height: 32,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              gradient: variant.primaryFill(
                                begin: Alignment.topLeft,
                                end: Alignment.bottomRight,
                              ),
                              border: Border.all(
                                color: Colors.white.withAlpha(140),
                              ),
                            ),
                            child:
                                Icon(variant.icon, size: 18, color: onPrimary),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              variant.name,
                              overflow: TextOverflow.ellipsis,
                              style: theme.textTheme.labelLarge?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          if (variant.hasBackdrop) ...[
                            Icon(
                              variant.backgroundImage != null
                                  ? Icons.image_outlined
                                  : Icons.blur_on,
                              size: 14,
                              color: Colors.white70,
                            ),
                            const SizedBox(width: 4),
                          ],
                          if (isSelected)
                            const Icon(Icons.check_circle,
                                size: 18, color: Colors.white),
                        ],
                      ),
                    ),
                  ),
                ),
                Container(
                  color: variant.surface,
                  padding: const EdgeInsets.all(10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              gradient: variant.primaryFill(),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text(
                              'Submit',
                              style: theme.textTheme.labelSmall?.copyWith(
                                color: onPrimary,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 12,
                              vertical: 5,
                            ),
                            decoration: BoxDecoration(
                              border: Border.all(color: variant.accent),
                              borderRadius: BorderRadius.circular(6),
                            ),
                            child: Text('Cancel', style: smallStyle),
                          ),
                        ],
                      ),
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 8,
                        children: [
                          _dot(variant.success, 'Success', smallStyle),
                          _dot(variant.warning, 'Warning', smallStyle),
                          _dot(variant.error, 'Error', smallStyle),
                        ],
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
