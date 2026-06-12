import 'package:m3u_tv/navigation/app_router.dart';
import 'package:m3u_tv/playback/player_adapter.dart';
import 'package:m3u_tv/services/domain_models.dart';

class ProductionStreamFixture {
  const ProductionStreamFixture({
    required this.id,
    required this.title,
    required this.type,
    required this.path,
    required this.videoCodec,
    required this.audioCodec,
    this.streamId,
    this.categoryId,
    this.containerExtension = 'm3u8',
    this.isLive = false,
    this.userAgent = productionFixtureUserAgent,
    this.headers = const <String, String>{},
    this.metadata = const <String, Object?>{},
  });

  final String id;
  final String title;
  final String type;
  final String path;
  final String videoCodec;
  final String audioCodec;
  final int? streamId;
  final String? categoryId;
  final String containerExtension;
  final bool isLive;
  final String userAgent;
  final Map<String, String> headers;
  final Map<String, Object?> metadata;

  Uri uriFor(Uri serverUri) => serverUri.resolve(path);

  PlayerArgs playerArgs(Uri serverUri, {double? startPosition}) {
    return PlayerArgs(
      streamUrl: uriFor(serverUri).toString(),
      title: title,
      type: type,
      streamId: streamId,
      startPosition: startPosition,
      videoCodec: videoCodec,
      audioCodec: audioCodec,
      userAgent: userAgent,
      headers: headers,
      metadata: metadata,
    );
  }

  PlaybackSource playbackSource(
    Uri serverUri, {
    Duration startPosition = Duration.zero,
  }) {
    return PlaybackSource(
      uri: uriFor(serverUri).toString(),
      title: title,
      startPosition: startPosition,
      isLive: isLive,
      videoCodec: videoCodec,
      audioCodec: audioCodec,
      userAgent: userAgent,
      headers: headers,
      metadata: metadata,
    );
  }

  Channel channel(Uri serverUri) {
    return Channel(
      id: streamId ?? 0,
      name: title,
      streamUrl: uriFor(serverUri).toString(),
      categoryId: categoryId,
      epgChannelId: metadata['epg_channel_id'] as String?,
      headers: headers,
    );
  }

  VodItem vodItem(Uri serverUri) {
    return VodItem(
      id: streamId ?? 0,
      name: title,
      streamUrl: uriFor(serverUri).toString(),
      containerExtension: containerExtension,
      categoryId: categoryId,
    );
  }
}

const productionFixtureUserAgent = 'm3u-tv-production-fixture/1.0';

const productionFixtureCategories = <Category>[
  Category(id: 'production-live', name: 'Production Live'),
  Category(id: 'production-vod', name: 'Production VOD'),
];

const hlsLiveFixture = ProductionStreamFixture(
  id: 'hls-live',
  title: 'Fixture HLS Live',
  type: 'live',
  path: '/fixture/hls-live/master.m3u8',
  videoCodec: 'h264',
  audioCodec: 'aac',
  streamId: 1001,
  categoryId: 'production-live',
  isLive: true,
  headers: <String, String>{'Referer': 'https://fixture.invalid/app'},
  metadata: <String, Object?>{
    'fixture_id': 'hls-live',
    'epg_channel_id': 'fixture.hls.live',
    'broadcast_network_id': 'fixture-hls-live',
  },
);

const mp4VodFixture = ProductionStreamFixture(
  id: 'mp4-vod',
  title: 'Fixture MP4 VOD',
  type: 'vod',
  path: '/fixture/mp4-vod/movie.mp4',
  videoCodec: 'h264',
  audioCodec: 'aac',
  streamId: 2001,
  categoryId: 'production-vod',
  containerExtension: 'mp4',
  metadata: <String, Object?>{'fixture_id': 'mp4-vod'},
);

const unsupportedCodecFixture = ProductionStreamFixture(
  id: 'unsupported-codec',
  title: 'Fixture Unsupported Codec',
  type: 'vod',
  path: '/fixture/unsupported-codec/movie.mkv',
  videoCodec: 'vp9',
  audioCodec: 'opus',
  streamId: 2002,
  categoryId: 'production-vod',
  containerExtension: 'mkv',
  metadata: <String, Object?>{
    'fixture_id': 'unsupported-codec',
    'fallback_reason': 'unsupported_codec',
  },
);

const deadUrlFixture = ProductionStreamFixture(
  id: 'dead-url',
  title: 'Fixture Dead URL',
  type: 'live',
  path: '/fixture/dead-stream/master.m3u8',
  videoCodec: 'h264',
  audioCodec: 'aac',
  streamId: 1002,
  categoryId: 'production-live',
  isLive: true,
  metadata: <String, Object?>{'fixture_id': 'dead-url'},
);

const expiredTokenFixture = ProductionStreamFixture(
  id: 'expired-token',
  title: 'Fixture Expired Token',
  type: 'live',
  path: '/fixture/expired-token/master.m3u8?token=expired-fixture-token',
  videoCodec: 'h264',
  audioCodec: 'aac',
  streamId: 1003,
  categoryId: 'production-live',
  isLive: true,
  metadata: <String, Object?>{'fixture_id': 'expired-token'},
);

const stalledTranscodeFixture = ProductionStreamFixture(
  id: 'stalled-transcode',
  title: 'Fixture Stalled Transcode',
  type: 'vod',
  path: '/fixture/stalled-transcode/source.ts',
  videoCodec: 'vp9',
  audioCodec: 'opus',
  streamId: 2003,
  categoryId: 'production-vod',
  metadata: <String, Object?>{
    'fixture_id': 'stalled-transcode',
    'scenario': 'stalled',
  },
);

const subtitlesAndAudioFixture = ProductionStreamFixture(
  id: 'subtitles-audio',
  title: 'Fixture Tracks',
  type: 'vod',
  path: '/fixture/subtitles-audio/movie.mp4',
  videoCodec: 'h264',
  audioCodec: 'aac',
  streamId: 2004,
  categoryId: 'production-vod',
  containerExtension: 'mp4',
  metadata: <String, Object?>{
    'fixture_id': 'subtitles-audio',
    'audio_tracks': <Map<String, String>>[
      <String, String>{'id': 'eng', 'label': 'English', 'language': 'en'},
      <String, String>{'id': 'spa', 'label': 'Spanish', 'language': 'es'},
    ],
    'subtitle_tracks': <Map<String, String>>[
      <String, String>{'id': 'eng-cc', 'label': 'English CC', 'language': 'en'},
      <String, String>{'id': 'spa-sub', 'label': 'Spanish', 'language': 'es'},
    ],
  },
);

const productionStreamCatalog = <ProductionStreamFixture>[
  hlsLiveFixture,
  mp4VodFixture,
  unsupportedCodecFixture,
  deadUrlFixture,
  expiredTokenFixture,
  stalledTranscodeFixture,
  subtitlesAndAudioFixture,
];
