import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3u_tv/services/domain_models.dart' hide ContentType;
import 'package:m3u_tv/services/request_models.dart';
import 'package:m3u_tv/services/xtream_service.dart';

void main() {
  const credentials = UserCredentials(
    server: 'https://xtream.example',
    username: 'demo',
    password: 'secret',
  );

  group('request contract', () {
    test('auth parses request v1 actions safely', () async {
      final service = XtreamService(
        transport: _RequestTransport(
          auth: _authPayload(requests: _requestContract),
        ).call,
      );

      final auth = await service.authenticate(credentials);

      expect(auth.requestContract?.version, 1);
      expect(auth.requestContract?.actions.search, 'request_search');
      expect(auth.hasRequests, isTrue);
    });

    test('malformed or unsupported request metadata is ignored', () async {
      for (final metadata in <Object?>[
        'invalid',
        const <String, Object?>{
          'api_version': 2,
          'actions': <String, Object?>{},
        },
        const <String, Object?>{
          'api_version': 1,
          'actions': <String, Object?>{'search': 'request_search'},
        },
      ]) {
        final service = XtreamService(
          transport: _RequestTransport(
            auth: _authPayload(requests: metadata),
          ).call,
        );

        final auth = await service.authenticate(credentials);

        expect(auth.requestContract, isNull);
      }
    });

    test('search uses advertised action and parses typed results', () async {
      final transport = _RequestTransport(
        auth: _authPayload(requests: _requestContract),
        responses: {
          'request_search': {
            'api_version': 1,
            'data': {
              'results': [
                {
                  'type': 'series',
                  'external_id': 1399,
                  'integration_id': 7,
                  'integration_name': 'Sonarr',
                  'title': 'Game of Thrones',
                  'year': 2011,
                  'overview': 'Nine noble families fight for control.',
                  'poster': 'https://img.example/poster.jpg',
                  'fanart': 'https://img.example/fanart.jpg',
                  'genres': ['Drama', 'Fantasy'],
                  'rating': 8.4,
                  'seasons': [0, 1, 2, 3],
                  'already_available': false,
                },
              ],
            },
            'meta': {
              'pagination': {
                'current_page': 1,
                'per_page': 20,
                'total': 1,
                'last_page': 1,
              },
              'partial': false,
              'unavailable_providers': 0,
            },
          },
        },
      );
      final service = XtreamService(transport: transport.call);
      await service.authenticate(credentials);

      final page = await service.searchRequests(
        'game of thrones',
        type: RequestMediaType.series,
      );

      expect(transport.lastRequest?.action, 'request_search');
      expect(transport.lastRequest?.params, {
        'query': 'game of thrones',
        'type': 'series',
        'page': '1',
        'per_page': '20',
      });
      expect(page.results.single.title, 'Game of Thrones');
      expect(page.results.single.externalId, '1399');
      expect(page.results.single.integrationId, '7');
      expect(page.results.single.genres, ['Drama', 'Fantasy']);
      expect(page.results.single.seasons, [0, 1, 2, 3]);
      expect(page.currentPage, 1);
      expect(page.perPage, 20);
      expect(page.total, 1);
      expect(page.lastPage, 1);
    });

    test('submit sends type and parses data envelope', () async {
      final transport = _RequestTransport(
        auth: _authPayload(requests: _requestContract),
        responses: {
          'request_submit': {
            'api_version': 1,
            'data': {
              'status': 'pending_approval',
              'request': {
                'id': 42,
                'type': 'movie',
                'external_id': '550',
                'title': 'Fight Club',
                'status': 'pending_approval',
                'integration_id': 7,
                'integration_name': 'Radarr',
                'requested_at': '2026-07-11T10:00:00Z',
                'can_dismiss': false,
              },
            },
          },
        },
      );
      final service = XtreamService(transport: transport.call);
      await service.authenticate(credentials);

      final submission = await service.submitRequest(
        const RequestSearchResult(
          type: RequestMediaType.movie,
          externalId: '550',
          integrationId: '7',
          integrationName: 'Radarr',
          title: 'Fight Club',
        ),
      );

      expect(transport.lastRequest?.action, 'request_submit');
      expect(transport.lastRequest?.method, 'POST');
      expect(transport.lastRequest?.body, {
        'type': 'movie',
        'integration_id': '7',
        'external_id': '550',
      });
      expect(submission.status, RequestStatus.pendingApproval);
      expect(submission.request.id, '42');
    });

    test('submit with seasons sends a typed JSON array', () async {
      final transport = _RequestTransport(
        auth: _authPayload(requests: _requestContract),
        responses: {
          'request_submit': {
            'api_version': 1,
            'data': {
              'status': 'pending_approval',
              'request': {
                'id': 42,
                'type': 'series',
                'external_id': '1399',
                'title': 'Game of Thrones',
                'status': 'pending_approval',
                'integration_id': 7,
                'integration_name': 'Sonarr',
                'requested_at': '2026-07-11T10:00:00Z',
                'can_dismiss': false,
              },
              'selected_seasons': [1, 2],
            },
          },
        },
      );
      final service = XtreamService(transport: transport.call);
      await service.authenticate(credentials);

      final submission = await service.submitRequest(
        const RequestSearchResult(
          type: RequestMediaType.series,
          externalId: '1399',
          integrationId: '7',
          integrationName: 'Sonarr',
          title: 'Game of Thrones',
        ),
        seasons: [1, 2],
      );

      expect(transport.lastRequest?.body, {
        'type': 'series',
        'integration_id': '7',
        'external_id': '1399',
        'seasons': [1, 2],
      });
      expect(submission.selectedSeasons, [1, 2]);
    });

    test('series submit sends an empty array for all seasons', () async {
      final transport = _RequestTransport(
        auth: _authPayload(requests: _requestContract),
        responses: {
          'request_submit': {
            'api_version': 1,
            'data': {
              'status': 'pending_approval',
              'request': {
                'id': 42,
                'type': 'series',
                'external_id': '1399',
                'title': 'Game of Thrones',
                'status': 'pending_approval',
                'integration_id': 7,
                'integration_name': 'Sonarr',
                'requested_at': '2026-07-11T10:00:00Z',
                'can_dismiss': false,
              },
              'selected_seasons': <int>[],
            },
          },
        },
      );
      final service = XtreamService(transport: transport.call);
      await service.authenticate(credentials);

      await service.submitRequest(
        const RequestSearchResult(
          type: RequestMediaType.series,
          externalId: '1399',
          integrationId: '7',
          integrationName: 'Sonarr',
          title: 'Game of Thrones',
        ),
      );

      expect(transport.lastRequest?.body, {
        'type': 'series',
        'integration_id': '7',
        'external_id': '1399',
        'seasons': <int>[],
      });
    });

    test('default HTTP transport sends seasons as a JSON array', () async {
      final server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
      Map<String, Object?>? submittedBody;
      server.listen((request) async {
        final Object response;
        if (request.uri.queryParameters['action'] == 'request_submit') {
          submittedBody =
              (jsonDecode(
                        await utf8.decoder.bind(request).join(),
                      )
                      as Map)
                  .cast<String, Object?>();
          response = {
            'api_version': 1,
            'data': {
              'status': 'pending_approval',
              'request': {
                'id': 42,
                'type': 'series',
                'external_id': '1399',
                'title': 'Game of Thrones',
                'status': 'pending_approval',
                'integration_id': 7,
                'integration_name': 'Sonarr',
                'requested_at': '2026-07-11T10:00:00Z',
                'can_dismiss': false,
              },
              'selected_seasons': [1, 2],
            },
          };
        } else {
          response = _authPayload(requests: _requestContract);
        }
        request.response
          ..headers.contentType = ContentType.json
          ..write(jsonEncode(response));
        await request.response.close();
      });

      try {
        final service = XtreamService();
        await service.authenticate(
          UserCredentials(
            server: 'http://${server.address.address}:${server.port}',
            username: 'demo',
            password: 'secret',
          ),
        );

        await service.submitRequest(
          const RequestSearchResult(
            type: RequestMediaType.series,
            externalId: '1399',
            integrationId: '7',
            integrationName: 'Sonarr',
            title: 'Game of Thrones',
          ),
          seasons: [1, 2],
        );

        expect(submittedBody?['seasons'], <int>[1, 2]);
      } finally {
        await server.close(force: true);
      }
    });

    test('history uses advertised action and parses data envelope', () async {
      final transport = _RequestTransport(
        auth: _authPayload(requests: _requestContract),
        responses: {
          'request_history': {
            'api_version': 1,
            'data': {
              'requests': [
                {
                  'id': 1,
                  'type': 'series',
                  'external_id': '1399',
                  'title': 'Game of Thrones',
                  'status': 'approved',
                  'integration_id': 7,
                  'integration_name': 'Sonarr',
                  'season_number': 2,
                  'episode_number': 4,
                  'requested_at': '2026-07-11T10:00:00Z',
                  'can_dismiss': false,
                },
              ],
            },
            'meta': {
              'pagination': {
                'current_page': 1,
                'per_page': 20,
                'total': 1,
                'last_page': 1,
              },
            },
          },
        },
      );
      final service = XtreamService(transport: transport.call);
      await service.authenticate(credentials);

      final page = await service.getRequestHistory();

      expect(transport.lastRequest?.action, 'request_history');
      expect(transport.lastRequest?.params, {
        'page': '1',
        'per_page': '20',
      });
      expect(page.requests.single.status, RequestStatus.approved);
      expect(page.requests.single.seasonNumber, 2);
      expect(page.requests.single.episodeNumber, 4);
      expect(page.requests.single.requestedAt, DateTime.utc(2026, 7, 11, 10));
      expect(page.currentPage, 1);
      expect(page.perPage, 20);
      expect(page.total, 1);
      expect(page.lastPage, 1);
    });

    test('status parses data envelope', () async {
      final transport = _RequestTransport(
        auth: _authPayload(requests: _requestContract),
        responses: {
          'request_status': {
            'api_version': 1,
            'data': {
              'request': {
                'id': 1,
                'type': 'movie',
                'external_id': '348',
                'title': 'Alien',
                'status': 'importing',
                'integration_id': 1,
                'integration_name': 'Radarr',
                'requested_at': '2026-07-11T10:00:00Z',
                'can_dismiss': false,
              },
            },
          },
        },
      );
      final service = XtreamService(transport: transport.call);
      await service.authenticate(credentials);

      final item = await service.getRequestStatus('1');

      expect(transport.lastRequest?.action, 'request_status');
      expect(transport.lastRequest?.params, {'request_id': '1'});
      expect(item.status, RequestStatus.importing);
    });

    test('dismiss sends request_id via POST', () async {
      final transport = _RequestTransport(
        auth: _authPayload(requests: _requestContract),
        responses: {
          'request_dismiss': {
            'api_version': 1,
            'data': {
              'dismissed': true,
              'request_id': 1,
            },
          },
        },
      );
      final service = XtreamService(transport: transport.call);
      await service.authenticate(credentials);

      await service.dismissRequest('1');

      expect(transport.lastRequest?.action, 'request_dismiss');
      expect(transport.lastRequest?.method, 'POST');
      expect(transport.lastRequest?.body, {'request_id': '1'});
    });

    test('JSON request errors retain backend code and message', () async {
      final service = XtreamService(
        transport: _RequestTransport(
          auth: _authPayload(requests: _requestContract),
          responses: {
            'request_submit': {
              'api_version': 1,
              'error': {
                'code': 'already_requested',
                'message': 'This title has already been requested.',
              },
            },
          },
        ).call,
      );
      await service.authenticate(credentials);

      await expectLater(
        service.submitRequest(
          const RequestSearchResult(
            type: RequestMediaType.series,
            externalId: '1399',
            integrationId: '7',
            integrationName: 'Sonarr',
            title: 'Game of Thrones',
          ),
        ),
        throwsA(
          isA<RequestApiException>()
              .having((error) => error.code, 'code', 'already_requested')
              .having(
                (error) => error.message,
                'message',
                'This title has already been requested.',
              ),
        ),
      );
    });

    test('HTTP request errors retain status and backend code', () async {
      final transport =
          _RequestTransport(
              auth: _authPayload(requests: _requestContract),
            )
            ..onRequest = (request) {
              if (request.action == 'request_submit') {
                throw XtreamHttpException(
                  statusCode: 409,
                  method: 'POST',
                  uri: Uri.parse(
                    'https://xtream.example/player_api.php?action=request_submit',
                  ),
                  serverCode: 'already_requested',
                  serverMessage: 'This title has already been requested.',
                );
              }
              return null;
            };
      final service = XtreamService(transport: transport.call);
      await service.authenticate(credentials);

      await expectLater(
        service.submitRequest(
          const RequestSearchResult(
            type: RequestMediaType.movie,
            externalId: '550',
            integrationId: '7',
            integrationName: 'Radarr',
            title: 'Fight Club',
          ),
        ),
        throwsA(
          isA<RequestApiException>()
              .having((error) => error.statusCode, 'statusCode', 409)
              .having((error) => error.code, 'code', 'already_requested'),
        ),
      );
    });
  });
}

const _requestContract = <String, Object?>{
  'api_version': 1,
  'actions': <String, Object?>{
    'search': 'request_search',
    'submit': 'request_submit',
    'history': 'request_history',
    'status': 'request_status',
    'dismiss': 'request_dismiss',
  },
};

Map<String, Object?> _authPayload({required Object? requests}) => {
  'user_info': {'auth': 1, 'status': 'Active'},
  'm3u_editor': {
    'version': '1.0.0',
    'features': ['requests'],
    'requests': requests,
  },
};

class _RequestTransport {
  _RequestTransport({required this.auth, this.responses = const {}});

  final Object? auth;
  final Map<String, Object?> responses;
  XtreamRequest? lastRequest;
  Object? Function(XtreamRequest request)? onRequest;

  Future<Object?> call(XtreamRequest request) async {
    lastRequest = request;
    if (request.action == null) return auth;
    if (onRequest != null) return onRequest!(request);
    return responses[request.action];
  }
}
