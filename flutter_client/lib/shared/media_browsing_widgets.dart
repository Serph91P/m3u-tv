import 'package:flutter/material.dart';

class CategoryTabData {
  const CategoryTabData({required this.id, required this.name});

  final String id;
  final String name;
}

class MediaBrowsingMetrics {
  const MediaBrowsingMetrics._();

  static const double pagePadding = 24;
  static const double contentPadding = 16;
  static const double itemGap = 12;
  static const double chipGap = 8;
  static const double chipRadius = 20;
  static const double cardRadius = 12;
  static const double posterRadius = 8;
  static const double logoSize = 56;
  static const double previewCardWidth = 172;
  static const double previewCardHeight = 148;
}

class ResilientMediaImage extends StatelessWidget {
  const ResilientMediaImage({
    required this.imageUrl,
    required this.fallbackIcon,
    this.width,
    this.height,
    this.fit = BoxFit.cover,
    this.borderRadius = MediaBrowsingMetrics.posterRadius,
    super.key,
  });

  final String? imageUrl;
  final IconData fallbackIcon;
  final double? width;
  final double? height;
  final BoxFit fit;
  final double borderRadius;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    final fallback = _MediaImageFallback(icon: fallbackIcon);
    final url = imageUrl;

    return ClipRRect(
      borderRadius: BorderRadius.circular(borderRadius),
      child: SizedBox(
        width: width,
        height: height,
        child: DecoratedBox(
          decoration: BoxDecoration(color: colorScheme.surfaceContainerHighest),
          child: url == null || url.isEmpty
              ? fallback
              : Image.network(
                  url,
                  fit: fit,
                  width: width,
                  height: height,
                  gaplessPlayback: true,
                  frameBuilder:
                      (context, child, frame, wasSynchronouslyLoaded) {
                        if (wasSynchronouslyLoaded || frame != null) {
                          return child;
                        }
                        return fallback;
                      },
                  loadingBuilder: (context, child, loadingProgress) {
                    if (loadingProgress == null) return child;
                    return fallback;
                  },
                  errorBuilder: (_, __, ___) => fallback,
                ),
        ),
      ),
    );
  }
}

class _MediaImageFallback extends StatelessWidget {
  const _MediaImageFallback({required this.icon});

  final IconData icon;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Center(
      child: Icon(icon, size: 48, color: colorScheme.onSurfaceVariant),
    );
  }
}

class ScrollableCategoryBar extends StatefulWidget {
  const ScrollableCategoryBar({
    required this.tabs,
    required this.selectedId,
    required this.onSelected,
    this.leading,
    super.key,
  });

  final List<CategoryTabData> tabs;
  final String selectedId;
  final ValueChanged<String> onSelected;
  final Widget? leading;

  @override
  State<ScrollableCategoryBar> createState() => _ScrollableCategoryBarState();
}

class _ScrollableCategoryBarState extends State<ScrollableCategoryBar> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  void _page(double direction) {
    if (!_controller.hasClients) return;
    final viewport = _controller.position.viewportDimension;
    final next = (_controller.offset + direction * viewport * 0.72).clamp(
      _controller.position.minScrollExtent,
      _controller.position.maxScrollExtent,
    );
    _controller.animateTo(
      next,
      duration: const Duration(milliseconds: 220),
      curve: Curves.easeOutCubic,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 72,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: MediaBrowsingMetrics.chipGap,
          vertical: MediaBrowsingMetrics.chipGap,
        ),
        child: Row(
          children: [
            if (widget.leading != null) ...[
              widget.leading!,
              const SizedBox(width: MediaBrowsingMetrics.chipGap),
            ],
            _CategoryScrollButton(
              icon: Icons.chevron_left,
              tooltip: 'Scroll categories left',
              onPressed: () => _page(-1),
            ),
            const SizedBox(width: MediaBrowsingMetrics.chipGap),
            Expanded(
              child: Scrollbar(
                controller: _controller,
                thumbVisibility: true,
                trackVisibility: true,
                child: ListView.separated(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: widget.tabs.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: MediaBrowsingMetrics.chipGap),
                  itemBuilder: (context, index) {
                    final tab = widget.tabs[index];
                    return CategoryFilterChip(
                      label: tab.name,
                      isSelected: widget.selectedId == tab.id,
                      onTap: () => widget.onSelected(tab.id),
                    );
                  },
                ),
              ),
            ),
            const SizedBox(width: MediaBrowsingMetrics.chipGap),
            _CategoryScrollButton(
              icon: Icons.chevron_right,
              tooltip: 'Scroll categories right',
              onPressed: () => _page(1),
            ),
          ],
        ),
      ),
    );
  }
}

class _CategoryScrollButton extends StatelessWidget {
  const _CategoryScrollButton({
    required this.icon,
    required this.tooltip,
    required this.onPressed,
  });

  final IconData icon;
  final String tooltip;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return IconButton.filledTonal(
      icon: Icon(icon),
      tooltip: tooltip,
      onPressed: onPressed,
    );
  }
}

class CategoryFilterChip extends StatelessWidget {
  const CategoryFilterChip({
    required this.label,
    required this.isSelected,
    required this.onTap,
    super.key,
  });

  final String label;
  final bool isSelected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Focus(
      child: Material(
        color: isSelected
            ? colorScheme.primaryContainer
            : colorScheme.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(MediaBrowsingMetrics.chipRadius),
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(MediaBrowsingMetrics.chipRadius),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(
                MediaBrowsingMetrics.chipRadius,
              ),
              border: Border.all(
                color: isSelected ? colorScheme.primary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: isSelected
                    ? colorScheme.onPrimaryContainer
                    : colorScheme.onSurfaceVariant,
                fontWeight: isSelected ? FontWeight.w700 : FontWeight.w500,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class ScrollbarGridView extends StatefulWidget {
  const ScrollbarGridView({
    required this.itemCount,
    required this.itemBuilder,
    required this.gridDelegate,
    this.padding = const EdgeInsets.all(MediaBrowsingMetrics.contentPadding),
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final SliverGridDelegate gridDelegate;
  final EdgeInsetsGeometry padding;

  @override
  State<ScrollbarGridView> createState() => _ScrollbarGridViewState();
}

class _ScrollbarGridViewState extends State<ScrollbarGridView> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      trackVisibility: true,
      child: GridView.builder(
        controller: _controller,
        padding: widget.padding,
        gridDelegate: widget.gridDelegate,
        itemCount: widget.itemCount,
        itemBuilder: widget.itemBuilder,
      ),
    );
  }
}

class ScrollbarListView extends StatefulWidget {
  const ScrollbarListView({
    required this.itemCount,
    required this.itemBuilder,
    this.padding,
    super.key,
  });

  final int itemCount;
  final IndexedWidgetBuilder itemBuilder;
  final EdgeInsetsGeometry? padding;

  @override
  State<ScrollbarListView> createState() => _ScrollbarListViewState();
}

class _ScrollbarListViewState extends State<ScrollbarListView> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scrollbar(
      controller: _controller,
      thumbVisibility: true,
      trackVisibility: true,
      child: ListView.builder(
        controller: _controller,
        padding: widget.padding,
        itemCount: widget.itemCount,
        itemBuilder: widget.itemBuilder,
      ),
    );
  }
}

class MediaPreviewItem {
  const MediaPreviewItem({
    required this.title,
    required this.fallbackIcon,
    required this.onTap,
    this.imageUrl,
    this.subtitle,
  });

  final String title;
  final String? imageUrl;
  final String? subtitle;
  final IconData fallbackIcon;
  final VoidCallback onTap;
}

class MediaPreviewSection extends StatefulWidget {
  const MediaPreviewSection({
    required this.title,
    required this.emptyLabel,
    required this.items,
    super.key,
  });

  final String title;
  final String emptyLabel;
  final List<MediaPreviewItem> items;

  @override
  State<MediaPreviewSection> createState() => _MediaPreviewSectionState();
}

class _MediaPreviewSectionState extends State<MediaPreviewSection> {
  final ScrollController _controller = ScrollController();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final visibleItems = widget.items.take(12).toList(growable: false);
    return Padding(
      padding: const EdgeInsets.only(bottom: 28),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(widget.title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: MediaBrowsingMetrics.chipGap),
          if (visibleItems.isEmpty)
            Text(widget.emptyLabel)
          else
            SizedBox(
              height: MediaBrowsingMetrics.previewCardHeight + 16,
              child: Scrollbar(
                controller: _controller,
                thumbVisibility: true,
                trackVisibility: true,
                child: ListView.separated(
                  controller: _controller,
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.only(bottom: 12),
                  itemCount: visibleItems.length,
                  separatorBuilder: (_, __) =>
                      const SizedBox(width: MediaBrowsingMetrics.itemGap),
                  itemBuilder: (context, index) =>
                      MediaPreviewCard(item: visibleItems[index]),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class MediaPreviewCard extends StatelessWidget {
  const MediaPreviewCard({required this.item, super.key});

  final MediaPreviewItem item;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return SizedBox(
      width: MediaBrowsingMetrics.previewCardWidth,
      child: Focus(
        child: Material(
          color: colorScheme.surfaceContainerHigh,
          borderRadius: BorderRadius.circular(MediaBrowsingMetrics.cardRadius),
          clipBehavior: Clip.antiAlias,
          child: InkWell(
            onTap: item.onTap,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Expanded(
                  child: ResilientMediaImage(
                    imageUrl: item.imageUrl,
                    fallbackIcon: item.fallbackIcon,
                    borderRadius: 0,
                  ),
                ),
                Padding(
                  padding: const EdgeInsets.all(MediaBrowsingMetrics.chipGap),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        item.title,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontWeight: FontWeight.w700,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (item.subtitle != null) ...[
                        const SizedBox(height: 2),
                        Text(
                          item.subtitle!,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: colorScheme.onSurfaceVariant),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
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
