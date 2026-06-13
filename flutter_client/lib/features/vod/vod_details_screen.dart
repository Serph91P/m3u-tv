import 'package:flutter/material.dart';
import 'package:m3u_tv/navigation/app_router.dart';
import 'package:m3u_tv/navigation/route_names.dart';
import 'package:m3u_tv/services/domain_models.dart';
import 'package:m3u_tv/shared/media_browsing_widgets.dart';

class VodDetailsScreen extends StatelessWidget {
  const VodDetailsScreen({super.key, required this.item});

  final VodItem item;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(item.name)),
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(
                width: 220,
                child: AspectRatio(
                  aspectRatio: 0.68,
                  child: ResilientMediaImage(
                    imageUrl: item.logoUrl,
                    fallbackIcon: Icons.movie,
                    borderRadius: 16,
                  ),
                ),
              ),
              const SizedBox(width: 32),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(item.name, style: theme.textTheme.headlineMedium),
                    const SizedBox(height: 12),
                    Wrap(
                      spacing: 12,
                      runSpacing: 8,
                      children: [
                        _MetadataChip(label: item.containerExtension.toUpperCase()),
                        if (item.rating != null)
                          _MetadataChip(label: 'Rating ${item.rating}'),
                      ],
                    ),
                    const SizedBox(height: 24),
                    Text(
                      'Movie details',
                      style: theme.textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Ready to play in-app.',
                      style: theme.textTheme.bodyLarge?.copyWith(
                        color: theme.colorScheme.onSurfaceVariant,
                      ),
                    ),
                    const Spacer(),
                    FilledButton.icon(
                      autofocus: true,
                      onPressed: () => _play(context),
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('Play movie'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _play(BuildContext context) {
    Navigator.of(context).pushNamed(
      RouteNames.player,
      arguments: PlayerArgs(
        streamUrl: item.streamUrl,
        title: item.name,
        type: 'vod',
        streamId: item.id,
        metadata: <String, Object?>{
          'container_extension': item.containerExtension,
        },
      ),
    );
  }
}

class _MetadataChip extends StatelessWidget {
  const _MetadataChip({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;
    return Chip(
      label: Text(label),
      backgroundColor: colorScheme.surfaceContainerHighest,
      side: BorderSide(color: colorScheme.outlineVariant),
    );
  }
}
