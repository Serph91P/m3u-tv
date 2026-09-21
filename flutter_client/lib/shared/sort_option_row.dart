import 'package:flutter/material.dart';
import 'package:m3u_tv/shared/dpad_ink_well.dart';
import 'package:m3u_tv/shared/image_quality_scope.dart';

/// A single row in a "Sort By" modal (see `showMediaSortDialog` /
/// `showChannelSortDialog`) - the active option is bold, tinted, and
/// checked.
class SortOptionRow extends StatelessWidget {
  const SortOptionRow({
    super.key,
    required this.icon,
    required this.label,
    required this.onTap,
    this.isActive = false,
    this.autofocus = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isActive;

  /// The currently-active option gets autofocus, wherever it sits in the
  /// list, so d-pad down naturally walks from it through the rest.
  final bool autofocus;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final scale = FontSizeScope.scaleOf(context);
    return DpadInkWell(
      autofocus: autofocus,
      onTap: onTap,
      child: Padding(
        padding: EdgeInsets.symmetric(
          vertical: 10 * scale,
          horizontal: 24 * scale,
        ),
        child: Row(
          children: [
            Icon(icon, size: 20 * scale),
            SizedBox(width: 12 * scale),
            Expanded(
              child: Text(
                label,
                style: TextStyle(
                  fontWeight: isActive ? FontWeight.w700 : FontWeight.normal,
                  color: isActive ? colorScheme.primary : colorScheme.onSurface,
                ),
              ),
            ),
            if (isActive)
              Icon(Icons.check, color: colorScheme.primary, size: 24 * scale),
          ],
        ),
      ),
    );
  }
}
