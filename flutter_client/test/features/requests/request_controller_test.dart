import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:m3u_tv/features/requests/request_controller.dart';
import 'package:m3u_tv/services/request_models.dart';

RequestSearchResult _sr(String id, String title) => RequestSearchResult(
  type: RequestMediaType.movie,
  externalId: id,
  integrationId: '7',
  integrationName: 'Radarr',
  title: title,
);

RequestSearchPage _sp(
  List<RequestSearchResult> results, {
  int current = 1,
  int total = 0,
  int last = 1,
}) => RequestSearchPage(
  results: results,
  currentPage: current,
  perPage: 20,
  total: total,
  lastPage: last,
);

RequestHistoryItem _hi(
  String id,
  String title, {
  RequestStatus status = RequestStatus.completed,
}) => RequestHistoryItem(
  id: id,
  type: RequestMediaType.movie,
  externalId: 'e$id',
  title: title,
  status: status,
  integrationId: '7',
  integrationName: 'Radarr',
);

RequestHistoryPage _hp(
  List<RequestHistoryItem> requests, {
  int current = 1,
  int total = 0,
  int last = 1,
}) => RequestHistoryPage(
  requests: requests,
  currentPage: current,
  perPage: 20,
  total: total,
  lastPage: last,
);

Future<RequestSearchPage> Function(
  String,
  RequestMediaType?, {
  int page,
  int perPage,
})
_searchRouter({
  required Completer<RequestSearchPage> page2Old,
  required RequestSearchPage oldPage1,
  required RequestSearchPage newPage1,
  Completer<RequestSearchPage>? page2New,
}) {
  return (term, type, {page = 1, perPage = 20}) async {
    if (term == 'old' && page == 1) return oldPage1;
    if (term == 'old' && page == 2) return page2Old.future;
    if (term == 'new' && page == 1) return newPage1;
    if (term == 'new' && page == 2 && page2New != null) {
      return page2New.future;
    }
    return _sp([]);
  };
}

Future<RequestHistoryPage> Function({int page, int perPage}) _historyRouter({
  required Completer<RequestHistoryPage> page2Old,
  required Completer<RequestHistoryPage> page1First,
  required Completer<RequestHistoryPage> page1Second,
  Completer<RequestHistoryPage>? page2New,
}) {
  var page1Calls = 0;
  var page2Calls = 0;
  return ({page = 1, perPage = 20}) async {
    if (page == 2) {
      page2Calls++;
      if (page2Calls == 1) return page2Old.future;
      if (page2New != null) return page2New.future;
      return _hp([]);
    }
    page1Calls++;
    if (page1Calls <= 1) return page1First.future;
    return page1Second.future;
  };
}

void main() {
  group('loadMoreSearchResults', () {
    test(
      'requests page 2 using current term and type, then appends results',
      () async {
        final pages = <Map<String, Object?>>[];
        final controller = RequestController.forTest(
          onSearch: (_, type, {page = 1, perPage = 20}) async {
            pages.add({'page': page, 'type': type});
            if (page == 1) {
              return _sp(
                [_sr('1', 'Page 1 Item')],
                total: 40,
                last: 2,
              );
            }
            return _sp(
              [_sr('2', 'Page 2 Item')],
              current: 2,
              total: 40,
              last: 2,
            );
          },
        );

        await controller.search('test query', RequestMediaType.movie);
        expect(controller.results, hasLength(1));
        expect(controller.results.first.title, 'Page 1 Item');
        expect(controller.hasMoreSearchPages, isTrue);

        await controller.loadMoreSearchResults();

        expect(pages, hasLength(2));
        expect(pages[1]['page'], 2);
        expect(controller.results, hasLength(2));
        expect(controller.results[1].title, 'Page 2 Item');
        expect(controller.hasMoreSearchPages, isFalse);
      },
    );

    test('skips duplicate call while loading is in progress', () async {
      var searchCalls = 0;
      final controller = RequestController.forTest(
        onSearch: (_, _, {page = 1, perPage = 20}) async {
          searchCalls++;
          if (page == 1) {
            return _sp(
              [_sr('1', 'Item')],
              total: 40,
              last: 2,
            );
          }
          return _sp(
            [_sr('2', 'Item 2')],
            current: 2,
            total: 40,
            last: 2,
          );
        },
      );

      await controller.search('query');
      expect(controller.isLoadingMore, isFalse);

      final first = controller.loadMoreSearchResults();
      await controller.loadMoreSearchResults();
      await first;

      expect(searchCalls, 2);
      expect(controller.results, hasLength(2));
    });

    test('preserves existing results on page 2 failure', () async {
      var failPage2 = false;
      final controller = RequestController.forTest(
        onSearch: (_, _, {page = 1, perPage = 20}) async {
          if (page == 1) {
            return _sp(
              [_sr('1', 'Existing')],
              total: 40,
              last: 2,
            );
          }
          if (failPage2) throw Exception('Network error');
          return _sp([], current: 2, total: 40, last: 2);
        },
      );

      await controller.search('query');
      expect(controller.results, hasLength(1));

      failPage2 = true;
      await controller.loadMoreSearchResults();

      expect(controller.results, hasLength(1));
      expect(controller.results.first.title, 'Existing');
      expect(controller.searchError, contains('Network error'));
      expect(controller.isLoadingMore, isFalse);
    });
  });

  group('loadMoreHistory', () {
    test('requests page 2 and appends history items', () async {
      final pages = <Map<String, Object?>>[];
      final controller = RequestController.forTest(
        onLoadHistory: ({page = 1, perPage = 20}) async {
          pages.add({'page': page});
          if (page == 1) {
            return _hp(
              [_hi('1', 'History Page 1')],
              total: 40,
              last: 2,
            );
          }
          return _hp(
            [
              _hi(
                '2',
                'History Page 2',
                status: RequestStatus.pendingApproval,
              ),
            ],
            current: 2,
            total: 40,
            last: 2,
          );
        },
      );

      await controller.loadHistory();
      expect(controller.history, hasLength(1));
      expect(controller.history.first.title, 'History Page 1');
      expect(controller.hasMoreHistoryPages, isTrue);

      await controller.loadMoreHistory();

      expect(pages, hasLength(2));
      expect(pages[1]['page'], 2);
      expect(controller.history, hasLength(2));
      expect(controller.history[1].title, 'History Page 2');
      expect(controller.hasMoreHistoryPages, isFalse);
    });

    test('skips duplicate call while loading is in progress', () async {
      var historyCalls = 0;
      final controller = RequestController.forTest(
        onLoadHistory: ({page = 1, perPage = 20}) async {
          historyCalls++;
          if (page == 1) {
            return _hp(
              [_hi('1', 'Item')],
              total: 40,
              last: 2,
            );
          }
          return _hp(
            [_hi('2', 'Item 2')],
            current: 2,
            total: 40,
            last: 2,
          );
        },
      );

      await controller.loadHistory();
      final first = controller.loadMoreHistory();
      await controller.loadMoreHistory();
      await first;

      expect(historyCalls, 2);
      expect(controller.history, hasLength(2));
    });

    test('preserves history on page 2 failure and allows retry', () async {
      var failPage2 = false;
      final controller = RequestController.forTest(
        onLoadHistory: ({page = 1, perPage = 20}) async {
          if (page == 1) {
            return _hp(
              [_hi('1', 'Existing History')],
              total: 40,
              last: 2,
            );
          }
          if (failPage2) throw Exception('Timeout');
          return _hp([], current: 2, total: 40, last: 2);
        },
      );

      await controller.loadHistory();
      expect(controller.history, hasLength(1));

      failPage2 = true;
      await controller.loadMoreHistory();

      expect(controller.history, hasLength(1));
      expect(controller.history.first.title, 'Existing History');
      expect(controller.historyError, contains('Timeout'));
      expect(controller.isLoadingMoreHistory, isFalse);

      failPage2 = false;
      await controller.loadMoreHistory();

      expect(controller.historyError, isNull);
      expect(controller.isLoadingMoreHistory, isFalse);
    });
  });

  group('stale search pagination race', () {
    test(
      'in-flight loadMoreSearchResults does not mutate state after new search',
      () async {
        final page2Old = Completer<RequestSearchPage>();

        final controller = RequestController.forTest(
          onSearch: _searchRouter(
            page2Old: page2Old,
            oldPage1: _sp(
              [_sr('old-1', 'Page 1 Old')],
              total: 40,
              last: 2,
            ),
            newPage1: _sp(
              [_sr('new-1', 'New Item')],
              total: 20,
            ),
          ),
        );

        await controller.search('old', RequestMediaType.movie);
        expect(controller.results, hasLength(1));
        expect(controller.results.first.title, 'Page 1 Old');
        expect(controller.hasMoreSearchPages, isTrue);

        final loadMore = controller.loadMoreSearchResults();
        expect(controller.isLoadingMore, isTrue);

        await controller.search('new', RequestMediaType.movie);
        await Future<void>.delayed(Duration.zero);

        expect(controller.results, hasLength(1));
        expect(controller.results.first.title, 'New Item');
        expect(controller.searchPage?.lastPage, 1);
        expect(controller.hasMoreSearchPages, isFalse);

        page2Old.complete(
          _sp(
            [_sr('stale-1', 'Stale Item')],
            current: 2,
            total: 40,
            last: 2,
          ),
        );
        await loadMore;

        expect(controller.results, hasLength(1));
        expect(controller.results.first.title, 'New Item');
        expect(controller.hasMoreSearchPages, isFalse);
        expect(controller.isLoadingMore, isFalse);
        expect(controller.searchError, isNull);
      },
    );

    test(
      'stale load-more result does not affect pagination metadata',
      () async {
        final page2Old = Completer<RequestSearchPage>();

        final controller = RequestController.forTest(
          onSearch: _searchRouter(
            page2Old: page2Old,
            oldPage1: _sp(
              [_sr('old-1', 'Old')],
              total: 40,
              last: 2,
            ),
            newPage1: _sp([], total: 5),
          ),
        );

        await controller.search('old', RequestMediaType.movie);
        final loadMore = controller.loadMoreSearchResults();

        await controller.search('new', RequestMediaType.movie);
        await Future<void>.delayed(Duration.zero);

        expect(controller.searchPage?.lastPage, 1);
        expect(controller.hasMoreSearchPages, isFalse);

        page2Old.complete(
          _sp([_sr('x', 'X')], current: 2, total: 40, last: 2),
        );
        await loadMore;

        expect(controller.hasMoreSearchPages, isFalse);
        expect(controller.searchPage?.lastPage, 1);
        expect(controller.searchPage?.total, 5);
        expect(controller.results, isEmpty);
      },
    );

    test(
      'starting newer search immediately invalidates old isLoadingMore',
      () async {
        final page2Old = Completer<RequestSearchPage>();

        final controller = RequestController.forTest(
          onSearch: _searchRouter(
            page2Old: page2Old,
            oldPage1: _sp(
              [_sr('old-1', 'Old')],
              total: 40,
              last: 2,
            ),
            newPage1: _sp(
              [_sr('new-1', 'New')],
              total: 20,
            ),
          ),
        );

        await controller.search('old', RequestMediaType.movie);
        final loadMore = controller.loadMoreSearchResults();
        expect(controller.isLoadingMore, isTrue);

        await controller.search('new', RequestMediaType.movie);
        expect(controller.isLoadingMore, isFalse);

        page2Old.complete(_sp([], current: 2, total: 40, last: 2));
        await loadMore;

        expect(controller.isLoadingMore, isFalse);
      },
    );

    test(
      'newer generation can start its own page-2 while old page-2 is in flight and old completion does not affect new state',
      () async {
        final page2Old = Completer<RequestSearchPage>();
        final page2New = Completer<RequestSearchPage>();

        final controller = RequestController.forTest(
          onSearch: _searchRouter(
            page2Old: page2Old,
            oldPage1: _sp(
              [_sr('old-1', 'Old Page 1')],
              total: 40,
              last: 2,
            ),
            newPage1: _sp(
              [_sr('new-1', 'New Page 1')],
              total: 40,
              last: 2,
            ),
            page2New: page2New,
          ),
        );

        await controller.search('old', RequestMediaType.movie);
        final oldLoadMore = controller.loadMoreSearchResults();
        expect(controller.isLoadingMore, isTrue);

        await controller.search('new', RequestMediaType.movie);
        expect(controller.isLoadingMore, isFalse);

        final newLoadMore = controller.loadMoreSearchResults();
        expect(controller.isLoadingMore, isTrue);

        page2Old.complete(
          _sp([_sr('stale', 'Stale')], current: 2, total: 40, last: 2),
        );
        await oldLoadMore;

        expect(controller.isLoadingMore, isTrue);
        expect(controller.searchError, isNull);
        expect(controller.results, hasLength(1));
        expect(controller.results.first.title, 'New Page 1');

        page2New.complete(
          _sp([_sr('new-2', 'New Page 2')], current: 2, total: 40, last: 2),
        );
        await newLoadMore;

        expect(controller.isLoadingMore, isFalse);
        expect(controller.results, hasLength(2));
        expect(controller.results[1].title, 'New Page 2');
      },
    );

    test(
      'stale full search completion does not clear newer unresolved search loading',
      () async {
        final page1Old = Completer<RequestSearchPage>();
        final page1New = Completer<RequestSearchPage>();

        final controller = RequestController.forTest(
          onSearch: (term, type, {page = 1, perPage = 20}) async {
            if (term == 'old') return page1Old.future;
            if (term == 'new') return page1New.future;
            return _sp([]);
          },
        );

        final oldSearch = controller.search('old', RequestMediaType.movie);
        expect(controller.isSearching, isTrue);

        final newSearch = controller.search('new', RequestMediaType.movie);
        expect(controller.isSearching, isTrue);

        page1Old.complete(
          _sp([_sr('stale', 'Stale')]),
        );
        await oldSearch;

        expect(controller.isSearching, isTrue);

        page1New.complete(
          _sp([_sr('new-1', 'New')]),
        );
        await newSearch;

        expect(controller.isSearching, isFalse);
        expect(controller.results, hasLength(1));
        expect(controller.results.first.title, 'New');
      },
    );
  });

  group('stale history pagination race', () {
    test(
      'in-flight loadMoreHistory does not mutate state after new loadHistory',
      () async {
        final page2Old = Completer<RequestHistoryPage>();
        final page1First = Completer<RequestHistoryPage>();
        final page1Second = Completer<RequestHistoryPage>();

        final controller = RequestController.forTest(
          onLoadHistory: _historyRouter(
            page2Old: page2Old,
            page1First: page1First,
            page1Second: page1Second,
          ),
        );

        page1First.complete(
          _hp([_hi('old-1', 'Old Page 1')], total: 40, last: 2),
        );
        await controller.loadHistory();
        expect(controller.history, hasLength(1));
        expect(controller.history.first.title, 'Old Page 1');
        expect(controller.hasMoreHistoryPages, isTrue);

        final loadMore = controller.loadMoreHistory();
        expect(controller.isLoadingMoreHistory, isTrue);

        page1Second.complete(
          _hp(
            [
              _hi(
                'new-1',
                'New Page 1',
                status: RequestStatus.pendingApproval,
              ),
            ],
            total: 10,
          ),
        );
        await controller.loadHistory();
        await Future<void>.delayed(Duration.zero);

        expect(controller.history, hasLength(1));
        expect(controller.history.first.title, 'New Page 1');
        expect(controller.hasMoreHistoryPages, isFalse);

        page2Old.complete(
          _hp(
            [_hi('stale-1', 'Stale Page 2')],
            current: 2,
            total: 40,
            last: 2,
          ),
        );
        await loadMore;

        expect(controller.history, hasLength(1));
        expect(controller.history.first.title, 'New Page 1');
        expect(controller.hasMoreHistoryPages, isFalse);
        expect(controller.isLoadingMoreHistory, isFalse);
      },
    );

    test(
      'stale load-more result does not affect history pagination metadata',
      () async {
        final page2Old = Completer<RequestHistoryPage>();
        final page1First = Completer<RequestHistoryPage>();
        final page1Second = Completer<RequestHistoryPage>();

        final controller = RequestController.forTest(
          onLoadHistory: _historyRouter(
            page2Old: page2Old,
            page1First: page1First,
            page1Second: page1Second,
          ),
        );

        page1First.complete(
          _hp([_hi('old-1', 'Old')], total: 40, last: 2),
        );
        await controller.loadHistory();
        final loadMore = controller.loadMoreHistory();

        page1Second.complete(_hp([], total: 3));
        await controller.loadHistory();
        await Future<void>.delayed(Duration.zero);

        expect(controller.hasMoreHistoryPages, isFalse);
        expect(controller.historyPage?.lastPage, 1);
        expect(controller.historyPage?.total, 3);

        page2Old.complete(
          _hp([_hi('stale', 'Stale')], current: 2, total: 40, last: 2),
        );
        await loadMore;

        expect(controller.hasMoreHistoryPages, isFalse);
        expect(controller.historyPage?.lastPage, 1);
        expect(controller.historyPage?.total, 3);
        expect(controller.history, isEmpty);
      },
    );

    test(
      'starting newer loadHistory immediately invalidates old isLoadingMoreHistory',
      () async {
        final page2Old = Completer<RequestHistoryPage>();
        final page1First = Completer<RequestHistoryPage>();
        final page1Second = Completer<RequestHistoryPage>();

        final controller = RequestController.forTest(
          onLoadHistory: _historyRouter(
            page2Old: page2Old,
            page1First: page1First,
            page1Second: page1Second,
          ),
        );

        page1First.complete(
          _hp([_hi('old-1', 'Old')], total: 40, last: 2),
        );
        await controller.loadHistory();
        final loadMore = controller.loadMoreHistory();
        expect(controller.isLoadingMoreHistory, isTrue);

        page1Second.complete(
          _hp(
            [
              _hi(
                'new-1',
                'New',
                status: RequestStatus.pendingApproval,
              ),
            ],
            total: 20,
          ),
        );
        await controller.loadHistory();
        expect(controller.isLoadingMoreHistory, isFalse);

        page2Old.complete(_hp([], current: 2, total: 40, last: 2));
        await loadMore;

        expect(controller.isLoadingMoreHistory, isFalse);
      },
    );

    test(
      'newer generation can start its own page-2 while old page-2 is in flight and old completion does not affect new state',
      () async {
        final page2Old = Completer<RequestHistoryPage>();
        final page2New = Completer<RequestHistoryPage>();
        final page1First = Completer<RequestHistoryPage>();
        final page1Second = Completer<RequestHistoryPage>();

        final controller = RequestController.forTest(
          onLoadHistory: _historyRouter(
            page2Old: page2Old,
            page1First: page1First,
            page1Second: page1Second,
            page2New: page2New,
          ),
        );

        page1First.complete(
          _hp(
            [_hi('old-1', 'Old Page 1')],
            total: 40,
            last: 2,
          ),
        );
        await controller.loadHistory();
        final oldLoadMore = controller.loadMoreHistory();
        expect(controller.isLoadingMoreHistory, isTrue);

        page1Second.complete(
          _hp(
            [
              _hi(
                'new-1',
                'New Page 1',
                status: RequestStatus.pendingApproval,
              ),
            ],
            total: 40,
            last: 2,
          ),
        );
        await controller.loadHistory();
        expect(controller.isLoadingMoreHistory, isFalse);

        final newLoadMore = controller.loadMoreHistory();
        expect(controller.isLoadingMoreHistory, isTrue);

        page2Old.complete(
          _hp([_hi('stale', 'Stale')], current: 2, total: 40, last: 2),
        );
        await oldLoadMore;

        expect(controller.isLoadingMoreHistory, isTrue);
        expect(controller.historyError, isNull);
        expect(controller.history, hasLength(1));
        expect(controller.history.first.title, 'New Page 1');

        page2New.complete(
          _hp(
            [_hi('new-2', 'New Page 2')],
            current: 2,
            total: 40,
            last: 2,
          ),
        );
        await newLoadMore;

        expect(controller.isLoadingMoreHistory, isFalse);
        expect(controller.history, hasLength(2));
        expect(controller.history[1].title, 'New Page 2');
      },
    );

    test(
      'stale full loadHistory completion does not clear newer unresolved history loading',
      () async {
        final page1Old = Completer<RequestHistoryPage>();
        final page1New = Completer<RequestHistoryPage>();
        var page1Calls = 0;

        final controller = RequestController.forTest(
          onLoadHistory: ({page = 1, perPage = 20}) async {
            if (page == 1) {
              page1Calls++;
              if (page1Calls == 1) return page1Old.future;
              return page1New.future;
            }
            return _hp([]);
          },
        );

        final oldHistory = controller.loadHistory();
        expect(controller.isHistoryLoading, isTrue);

        final newHistory = controller.loadHistory();
        expect(controller.isHistoryLoading, isTrue);

        page1Old.complete(
          _hp([_hi('stale', 'Stale')]),
        );
        await oldHistory;

        expect(controller.isHistoryLoading, isTrue);

        page1New.complete(
          _hp(
            [
              _hi(
                'new-1',
                'New',
                status: RequestStatus.pendingApproval,
              ),
            ],
          ),
        );
        await newHistory;

        expect(controller.isHistoryLoading, isFalse);
        expect(controller.history, hasLength(1));
        expect(controller.history.first.title, 'New');
      },
    );
  });
}
