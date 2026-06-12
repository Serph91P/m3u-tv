import 'package:flutter/material.dart';
import 'package:m3u_tv/navigation/route_names.dart';
import 'package:m3u_tv/playback/player_adapter.dart';

/// Placeholder screen for routes not yet implemented.
/// Shows the route name so navigation is visually verifiable.
class PlaceholderScreen extends StatelessWidget {
  const PlaceholderScreen({super.key, required this.title});

  final String title;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Center(
        child: Text(title, style: Theme.of(context).textTheme.headlineMedium),
      ),
    );
  }
}

/// Player route arguments matching the RN RootStackParamList.Player type.
class PlayerArgs {
  const PlayerArgs({
    required this.streamUrl,
    required this.title,
    required this.type,
    this.streamId,
    this.seriesId,
    this.seasonNumber,
    this.startPosition,
    this.epgChannelId,
    this.videoCodec,
    this.audioCodec,
    this.userAgent,
    this.headers = const <String, String>{},
    this.metadata = const <String, Object?>{},
  });

  final String streamUrl;
  final String title;
  final String type; // 'live' | 'vod' | 'series'
  final int? streamId;
  final int? seriesId;
  final int? seasonNumber;
  final double? startPosition;
  final String? epgChannelId;
  final String? videoCodec;
  final String? audioCodec;
  final String? userAgent;
  final Map<String, String> headers;
  final Map<String, Object?> metadata;

  PlaybackSource toPlaybackSource({bool includeStartPosition = true}) {
    return PlaybackSource(
      uri: streamUrl,
      title: title,
      startPosition: includeStartPosition && startPosition != null
          ? Duration(seconds: startPosition!.round())
          : Duration.zero,
      isLive: type == 'live',
      videoCodec: videoCodec,
      audioCodec: audioCodec,
      userAgent: userAgent,
      headers: headers,
      metadata: <String, Object?>{
        ...metadata,
        if (epgChannelId != null) 'epg_channel_id': epgChannelId,
      },
    );
  }
}

/// Details route arguments for VOD items.
class DetailsArgs {
  const DetailsArgs({required this.vodId, required this.vodName});

  final int vodId;
  final String vodName;
}

/// Series details route arguments.
class SeriesDetailsArgs {
  const SeriesDetailsArgs({required this.seriesId, required this.seriesName});

  final int seriesId;
  final String seriesName;
}

/// Builds the app router using Navigator 2.0 with named routes.
///
/// Route structure mirrors the RN app:
/// - Main stack: Home, Search, LiveTV, VOD, Series, Settings
/// - Modal stack: Player (fullscreen), Details, SeriesDetails, ViewerSelection
RouteFactory buildAppRouter({
  Widget Function(String routeName)? mainRouteBuilder,
}) {
  return (RouteSettings settings) {
    final routeName = settings.name;

    // Main tab routes
    if (routeName == RouteNames.home) {
      return _buildRoute(
        settings,
        mainRouteBuilder?.call(RouteNames.home) ??
            const PlaceholderScreen(title: 'Home'),
      );
    }
    if (routeName == RouteNames.search) {
      return _buildRoute(
        settings,
        mainRouteBuilder?.call(RouteNames.search) ??
            const PlaceholderScreen(title: 'Search'),
      );
    }
    if (routeName == RouteNames.liveTv) {
      return _buildRoute(
        settings,
        mainRouteBuilder?.call(RouteNames.liveTv) ??
            const PlaceholderScreen(title: 'Live TV'),
      );
    }
    if (routeName == RouteNames.vod) {
      return _buildRoute(
        settings,
        mainRouteBuilder?.call(RouteNames.vod) ??
            const PlaceholderScreen(title: 'Movies'),
      );
    }
    if (routeName == RouteNames.series) {
      return _buildRoute(
        settings,
        mainRouteBuilder?.call(RouteNames.series) ??
            const PlaceholderScreen(title: 'Series'),
      );
    }
    if (routeName == RouteNames.settings) {
      return _buildRoute(
        settings,
        mainRouteBuilder?.call(RouteNames.settings) ??
            const PlaceholderScreen(title: 'Settings'),
      );
    }

    // Modal routes
    if (routeName == RouteNames.player) {
      final args = settings.arguments;
      String playerTitle = 'Player';
      if (args is PlayerArgs) {
        playerTitle = args.title;
      }
      return _buildModalRoute(settings, PlaceholderScreen(title: playerTitle));
    }
    if (routeName == RouteNames.details) {
      final args = settings.arguments;
      String detailTitle = 'Details';
      if (args is DetailsArgs) {
        detailTitle = args.vodName;
      }
      return _buildSlideRoute(settings, PlaceholderScreen(title: detailTitle));
    }
    if (routeName == RouteNames.seriesDetails) {
      final args = settings.arguments;
      String detailTitle = 'Series Details';
      if (args is SeriesDetailsArgs) {
        detailTitle = args.seriesName;
      }
      return _buildSlideRoute(settings, PlaceholderScreen(title: detailTitle));
    }
    if (routeName == RouteNames.viewerSelection) {
      return _buildModalRoute(
        settings,
        const PlaceholderScreen(title: 'Viewer Selection'),
      );
    }

    // Unknown route → Home
    return _buildRoute(
      const RouteSettings(name: RouteNames.home),
      const PlaceholderScreen(title: 'Home'),
    );
  };
}

MaterialPageRoute<void> _buildRoute(RouteSettings settings, Widget screen) {
  return MaterialPageRoute<void>(settings: settings, builder: (_) => screen);
}

PageRoute<void> _buildModalRoute(RouteSettings settings, Widget screen) {
  return PageRouteBuilder<void>(
    settings: settings,
    opaque: false,
    pageBuilder: (_, __, ___) => screen,
    transitionsBuilder: (_, animation, __, child) {
      return FadeTransition(opacity: animation, child: child);
    },
  );
}

PageRoute<void> _buildSlideRoute(RouteSettings settings, Widget screen) {
  return PageRouteBuilder<void>(
    settings: settings,
    pageBuilder: (_, __, ___) => screen,
    transitionsBuilder: (_, animation, __, child) {
      return SlideTransition(
        position: Tween<Offset>(
          begin: const Offset(1, 0),
          end: Offset.zero,
        ).animate(CurvedAnimation(parent: animation, curve: Curves.easeOut)),
        child: child,
      );
    },
  );
}
