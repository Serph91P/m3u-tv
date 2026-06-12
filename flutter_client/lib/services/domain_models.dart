// ignore_for_file: sort_constructors_first

enum ContentType { live, vod, episode }

class UserCredentials {
  const UserCredentials({required this.server, required this.username, required this.password});

  final String server;
  final String username;
  final String password;

  UserCredentials normalized() => UserCredentials(
        server: server.replaceAll(RegExp(r'/+$'), ''),
        username: username,
        password: password,
      );
}

class Category {
  const Category({required this.id, required this.name, this.parentId = 0});

  final String id;
  final String name;
  final int parentId;

  factory Category.fromXtream(Map<String, Object?> json) => Category(
        id: '${json['category_id'] ?? ''}',
        name: '${json['category_name'] ?? ''}',
        parentId: _asInt(json['parent_id']),
      );

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Category && id == other.id && name == other.name && parentId == other.parentId;

  @override
  int get hashCode => Object.hash(id, name, parentId);

  @override
  String toString() => 'Category(id: $id, name: $name)';
}

class Channel {
  const Channel({
    required this.id,
    required this.name,
    required this.streamUrl,
    this.logoUrl,
    this.categoryId,
    this.groupTitle,
    this.epgChannelId,
    this.tvgName,
    this.headers = const {},
  });

  final int id;
  final String name;
  final String streamUrl;
  final String? logoUrl;
  final String? categoryId;
  final String? groupTitle;
  final String? epgChannelId;
  final String? tvgName;
  final Map<String, String> headers;

  factory Channel.fromXtream(Map<String, Object?> json, String streamUrl) => Channel(
        id: _asInt(json['stream_id']),
        name: '${json['name'] ?? ''}',
        streamUrl: streamUrl,
        logoUrl: _asNullableString(json['stream_icon']),
        categoryId: _asNullableString(json['category_id']),
        epgChannelId: _asNullableString(json['epg_channel_id']),
      );
}

class VodItem {
  const VodItem({
    required this.id,
    required this.name,
    required this.streamUrl,
    required this.containerExtension,
    this.logoUrl,
    this.categoryId,
    this.rating,
  });

  final int id;
  final String name;
  final String streamUrl;
  final String containerExtension;
  final String? logoUrl;
  final String? categoryId;
  final double? rating;

  factory VodItem.fromXtream(Map<String, Object?> json, String streamUrl) => VodItem(
        id: _asInt(json['stream_id']),
        name: '${json['name'] ?? ''}',
        streamUrl: streamUrl,
        containerExtension: '${json['container_extension'] ?? 'mp4'}',
        logoUrl: _asNullableString(json['stream_icon']),
        categoryId: _asNullableString(json['category_id']),
        rating: _asDoubleOrNull(json['rating_5based'] ?? json['rating']),
      );
}

class Series {
  const Series({
    required this.id,
    required this.name,
    this.coverUrl,
    this.categoryId,
    this.plot,
    this.rating,
  });

  final int id;
  final String name;
  final String? coverUrl;
  final String? categoryId;
  final String? plot;
  final double? rating;

  factory Series.fromXtream(Map<String, Object?> json) => Series(
        id: _asInt(json['series_id']),
        name: '${json['name'] ?? ''}',
        coverUrl: _asNullableString(json['cover']),
        categoryId: _asNullableString(json['category_id']),
        plot: _asNullableString(json['plot']),
        rating: _asDoubleOrNull(json['rating_5based'] ?? json['rating']),
      );
}

class Season {
  const Season({required this.number, required this.name, this.episodeCount = 0});

  final int number;
  final String name;
  final int episodeCount;

  factory Season.fromXtream(Map<String, Object?> json) {
    final number = _asInt(json['season_number']);
    return Season(
      number: number,
      name: '${json['name'] ?? 'Season $number'}',
      episodeCount: _asInt(json['episode_count']),
    );
  }
}

class Episode {
  const Episode({
    required this.id,
    required this.episodeNumber,
    required this.title,
    required this.containerExtension,
    required this.seasonNumber,
    this.plot,
    this.streamUrl,
  });

  final String id;
  final int episodeNumber;
  final String title;
  final String containerExtension;
  final int seasonNumber;
  final String? plot;
  final String? streamUrl;

  factory Episode.fromXtream(Map<String, Object?> json, {String? streamUrl}) {
    final info = (json['info'] as Map?)?.cast<String, Object?>() ?? const <String, Object?>{};
    return Episode(
      id: '${json['id'] ?? ''}',
      episodeNumber: _asInt(json['episode_num']),
      title: '${json['title'] ?? ''}',
      containerExtension: '${json['container_extension'] ?? 'mp4'}',
      seasonNumber: _asInt(json['season'] ?? info['season']),
      plot: _asNullableString(info['plot']),
      streamUrl: streamUrl,
    );
  }
}

class SeriesInfo {
  const SeriesInfo({required this.series, required this.seasons, required this.episodesBySeason});

  final Series series;
  final List<Season> seasons;
  final Map<int, List<Episode>> episodesBySeason;
}

class EpgProgram {
  const EpgProgram({
    required this.channelId,
    required this.title,
    required this.description,
    required this.start,
    required this.end,
  });

  final String channelId;
  final String title;
  final String description;
  final DateTime start;
  final DateTime end;
}

class EpgCurrentNext {
  const EpgCurrentNext({required this.current, this.next, required this.progress});

  final EpgProgram current;
  final EpgProgram? next;
  final double progress;
}

class Viewer {
  const Viewer({required this.id, required this.ulid, required this.name, required this.isAdmin});

  final int id;
  final String ulid;
  final String name;
  final bool isAdmin;

  factory Viewer.fromJson(Map<String, Object?> json) => Viewer(
        id: _asInt(json['id']),
        ulid: '${json['ulid'] ?? ''}',
        name: '${json['name'] ?? ''}',
        isAdmin: json['is_admin'] == true,
      );

  Map<String, Object?> toJson() => {'id': id, 'ulid': ulid, 'name': name, 'is_admin': isAdmin};

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Viewer && id == other.id && ulid == other.ulid && name == other.name && isAdmin == other.isAdmin;

  @override
  int get hashCode => Object.hash(id, ulid, name, isAdmin);
}

class Progress {
  const Progress({
    required this.viewerId,
    required this.contentType,
    required this.streamId,
    required this.positionSeconds,
    this.durationSeconds,
    this.completed = false,
    this.seriesId,
    this.seasonNumber,
  });

  final String viewerId;
  final ContentType contentType;
  final int streamId;
  final int positionSeconds;
  final int? durationSeconds;
  final bool completed;
  final int? seriesId;
  final int? seasonNumber;

  factory Progress.fromJson(Map<String, Object?> json, {String? viewerId}) => Progress(
        viewerId: viewerId ?? '${json['viewer_id'] ?? ''}',
        contentType: contentTypeFromWire('${json['content_type'] ?? 'vod'}'),
        streamId: _asInt(json['stream_id']),
        positionSeconds: _asInt(json['position_seconds']),
        durationSeconds: json.containsKey('duration_seconds') ? _asInt(json['duration_seconds']) : null,
        completed: json['completed'] == true || json['completed'] == 1,
        seriesId: json.containsKey('series_id') ? _asInt(json['series_id']) : null,
        seasonNumber: json.containsKey('season_number') ? _asInt(json['season_number']) : null,
      );

  Map<String, Object?> toJson() => {
        'viewer_id': viewerId,
        'content_type': contentType.wireName,
        'stream_id': streamId,
        'position_seconds': positionSeconds,
        if (durationSeconds != null) 'duration_seconds': durationSeconds,
        'completed': completed,
        if (seriesId != null) 'series_id': seriesId,
        if (seasonNumber != null) 'season_number': seasonNumber,
      };

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is Progress &&
          viewerId == other.viewerId &&
          contentType == other.contentType &&
          streamId == other.streamId &&
          positionSeconds == other.positionSeconds &&
          durationSeconds == other.durationSeconds &&
          completed == other.completed &&
          seriesId == other.seriesId &&
          seasonNumber == other.seasonNumber;

  @override
  int get hashCode => Object.hash(viewerId, contentType, streamId, positionSeconds, durationSeconds, completed, seriesId, seasonNumber);
}

extension ContentTypeWire on ContentType {
  String get wireName => switch (this) {
        ContentType.live => 'live',
        ContentType.vod => 'vod',
        ContentType.episode => 'episode',
      };
}

ContentType contentTypeFromWire(String value) => switch (value) {
      'live' => ContentType.live,
      'episode' => ContentType.episode,
      _ => ContentType.vod,
    };

int _asInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value') ?? 0;
}

double? _asDoubleOrNull(Object? value) {
  if (value == null) return null;
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

String? _asNullableString(Object? value) {
  if (value == null) return null;
  final text = '$value';
  return text.isEmpty ? null : text;
}
