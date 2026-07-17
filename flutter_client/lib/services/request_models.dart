enum RequestMediaType {
  movie('movie'),
  series('series');

  const RequestMediaType(this.wireName);

  final String wireName;

  static RequestMediaType fromWire(Object? value) => switch ('$value') {
    'series' => RequestMediaType.series,
    _ => RequestMediaType.movie,
  };
}

enum RequestStatus {
  pendingApproval('pending_approval'),
  approved('approved'),
  importing('importing'),
  completed('completed'),
  rejected('rejected'),
  monitored('monitored'),
  grabbing('grabbing'),
  downloading('downloading'),
  importPending('import_pending'),
  manualRequired('manual_required'),
  queued('queued'),
  paused('paused'),
  failed('failed'),
  error('error'),
  unknown('unknown');

  const RequestStatus(this.wireName);

  final String wireName;

  static RequestStatus fromWire(Object? value) => switch ('$value') {
    'pending_approval' => RequestStatus.pendingApproval,
    'approved' => RequestStatus.approved,
    'importing' => RequestStatus.importing,
    'completed' => RequestStatus.completed,
    'rejected' => RequestStatus.rejected,
    'monitored' => RequestStatus.monitored,
    'grabbing' => RequestStatus.grabbing,
    'downloading' => RequestStatus.downloading,
    'import_pending' => RequestStatus.importPending,
    'manual_required' => RequestStatus.manualRequired,
    'queued' => RequestStatus.queued,
    'paused' => RequestStatus.paused,
    'failed' => RequestStatus.failed,
    'error' => RequestStatus.error,
    _ => RequestStatus.unknown,
  };

  bool get isTerminal =>
      this == RequestStatus.completed || this == RequestStatus.rejected;

  bool get isActive => switch (this) {
    RequestStatus.monitored ||
    RequestStatus.grabbing ||
    RequestStatus.downloading ||
    RequestStatus.importPending ||
    RequestStatus.queued ||
    RequestStatus.paused ||
    RequestStatus.importing => true,
    _ => false,
  };

  bool get isFailed =>
      this == RequestStatus.failed || this == RequestStatus.error;
}

class RequestActions {
  const RequestActions({
    required this.search,
    required this.submit,
    required this.history,
    required this.status,
    required this.dismiss,
  });

  final String search;
  final String submit;
  final String history;
  final String status;
  final String dismiss;
}

class RequestContract {
  const RequestContract({required this.version, required this.actions});

  final int version;
  final RequestActions actions;

  static RequestContract? tryParse(Object? value) {
    if (value is! Map) return null;
    final json = value.cast<Object?, Object?>();
    final version = _asInt(json['api_version']);
    final rawActions = json['actions'];
    if (version != 1 || rawActions is! Map) return null;
    final actions = rawActions.cast<Object?, Object?>();
    final search = _nonEmptyString(actions['search']);
    final submit = _nonEmptyString(actions['submit']);
    final history = _nonEmptyString(actions['history']);
    final status = _nonEmptyString(actions['status']);
    final dismiss = _nonEmptyString(actions['dismiss']);
    if (search == null ||
        submit == null ||
        history == null ||
        status == null ||
        dismiss == null) {
      return null;
    }
    return RequestContract(
      version: version,
      actions: RequestActions(
        search: search,
        submit: submit,
        history: history,
        status: status,
        dismiss: dismiss,
      ),
    );
  }
}

class RequestSearchResult {
  const RequestSearchResult({
    required this.type,
    required this.externalId,
    required this.integrationId,
    required this.integrationName,
    required this.title,
    this.year,
    this.overview,
    this.posterUrl,
    this.fanartUrl,
    this.genres = const <String>[],
    this.rating,
    this.seasons = const <int>[],
    this.alreadyAvailable = false,
  });

  factory RequestSearchResult.fromJson(Map<String, Object?> json) {
    return RequestSearchResult(
      type: RequestMediaType.fromWire(json['type']),
      externalId: '${json['external_id'] ?? ''}',
      integrationId: '${json['integration_id'] ?? ''}',
      integrationName: '${json['integration_name'] ?? ''}',
      title: '${json['title'] ?? ''}',
      year: _nullableInt(json['year']),
      overview: _nonEmptyString(json['overview']),
      posterUrl: _nonEmptyString(json['poster']),
      fanartUrl: _nonEmptyString(json['fanart']),
      genres: _asList(json['genres'])
          .map((genre) => '$genre')
          .where((genre) => genre.isNotEmpty)
          .toList(growable: false),
      rating: _nullableDouble(json['rating']),
      seasons: _asList(
        json['seasons'],
      ).map(_nullableInt).whereType<int>().toList(growable: false),
      alreadyAvailable: json['already_available'] == true,
    );
  }

  final RequestMediaType type;
  final String externalId;
  final String integrationId;
  final String integrationName;
  final String title;
  final int? year;
  final String? overview;
  final String? posterUrl;
  final String? fanartUrl;
  final List<String> genres;
  final double? rating;
  final List<int> seasons;
  final bool alreadyAvailable;

  String get key => '${type.wireName}:$integrationId:$externalId';

  bool get isSeries => type == RequestMediaType.series;
  bool get hasSeasons => isSeries && seasons.isNotEmpty;
}

class RequestSearchPage {
  const RequestSearchPage({
    required this.results,
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
    this.partial = false,
    this.unavailableProviders = 0,
  });

  factory RequestSearchPage.fromJson(Map<String, Object?> json) {
    final data = _asMap(json['data']);
    final meta = _asMap(json['meta']);
    final pagination = _asMap(meta['pagination']);
    return RequestSearchPage(
      results: _asList(data['results'])
          .map((item) => RequestSearchResult.fromJson(_asMap(item)))
          .toList(growable: false),
      currentPage: _asInt(pagination['current_page']),
      perPage: _asInt(pagination['per_page']),
      total: _asInt(pagination['total']),
      lastPage: _asInt(pagination['last_page']),
      partial: meta['partial'] == true,
      unavailableProviders: _asInt(meta['unavailable_providers']),
    );
  }

  final List<RequestSearchResult> results;
  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;
  final bool partial;
  final int unavailableProviders;

  bool get hasMorePages => currentPage < lastPage;
  int get nextPage => currentPage + 1;
}

class RequestHistoryPage {
  const RequestHistoryPage({
    required this.requests,
    required this.currentPage,
    required this.perPage,
    required this.total,
    required this.lastPage,
  });

  factory RequestHistoryPage.fromJson(Map<String, Object?> json) {
    final data = _asMap(json['data']);
    final meta = _asMap(json['meta']);
    final pagination = _asMap(meta['pagination']);
    return RequestHistoryPage(
      requests: _asList(data['requests'])
          .map((item) => RequestHistoryItem.fromJson(_asMap(item)))
          .toList(growable: false),
      currentPage: _asInt(pagination['current_page']),
      perPage: _asInt(pagination['per_page']),
      total: _asInt(pagination['total']),
      lastPage: _asInt(pagination['last_page']),
    );
  }

  final List<RequestHistoryItem> requests;
  final int currentPage;
  final int perPage;
  final int total;
  final int lastPage;

  bool get hasMorePages => currentPage < lastPage;
  int get nextPage => currentPage + 1;
}

class RequestSubmission {
  const RequestSubmission({
    required this.status,
    required this.request,
    this.selectedSeasons = const <int>[],
  });

  factory RequestSubmission.fromJson(Map<String, Object?> json) {
    final data = _asMap(json['data']);
    final request = _asMap(data['request']);
    return RequestSubmission(
      status: RequestStatus.fromWire(data['status']),
      request: RequestHistoryItem.fromJson(request),
      selectedSeasons: _asList(
        data['selected_seasons'],
      ).map(_nullableInt).whereType<int>().toList(growable: false),
    );
  }

  final RequestStatus status;
  final RequestHistoryItem request;
  final List<int> selectedSeasons;
}

class RequestHistoryItem {
  const RequestHistoryItem({
    required this.id,
    required this.type,
    required this.externalId,
    required this.title,
    required this.status,
    required this.integrationId,
    required this.integrationName,
    this.seasonNumber,
    this.episodeNumber,
    this.requestedAt,
    this.canDismiss = false,
  });

  factory RequestHistoryItem.fromJson(Map<String, Object?> json) {
    return RequestHistoryItem(
      id: '${json['id'] ?? ''}',
      type: RequestMediaType.fromWire(json['type']),
      externalId: '${json['external_id'] ?? ''}',
      title: '${json['title'] ?? ''}',
      status: RequestStatus.fromWire(json['status']),
      integrationId: '${json['integration_id'] ?? ''}',
      integrationName: '${json['integration_name'] ?? ''}',
      seasonNumber: _nullableInt(json['season_number']),
      episodeNumber: _nullableInt(json['episode_number']),
      requestedAt: DateTime.tryParse('${json['requested_at'] ?? ''}')?.toUtc(),
      canDismiss: json['can_dismiss'] == true,
    );
  }

  final String id;
  final RequestMediaType type;
  final String externalId;
  final String title;
  final RequestStatus status;
  final String integrationId;
  final String integrationName;
  final int? seasonNumber;
  final int? episodeNumber;
  final DateTime? requestedAt;
  final bool canDismiss;
}

class RequestApiException implements Exception {
  const RequestApiException({
    required this.code,
    required this.message,
    this.statusCode,
  });

  final String code;
  final String message;
  final int? statusCode;

  @override
  String toString() => message;
}

Map<String, Object?> _asMap(Object? value) {
  if (value is! Map) return const <String, Object?>{};
  return value.map((key, value) => MapEntry('$key', value));
}

List<Object?> _asList(Object? value) =>
    value is List ? value.cast<Object?>() : const <Object?>[];

int _asInt(Object? value) => _nullableInt(value) ?? 0;

int? _nullableInt(Object? value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse('$value');
}

double? _nullableDouble(Object? value) {
  if (value is num) return value.toDouble();
  return double.tryParse('$value');
}

String? _nonEmptyString(Object? value) {
  if (value == null) return null;
  final text = '$value'.trim();
  return text.isEmpty ? null : text;
}
