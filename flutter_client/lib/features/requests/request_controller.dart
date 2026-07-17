import 'package:flutter/foundation.dart';
import 'package:m3u_tv/services/request_models.dart';
import 'package:m3u_tv/services/xtream_service.dart';

enum RequestValidationError { tooShort, tooLong }

typedef RequestSearchCallback =
    Future<RequestSearchPage> Function(
      String term,
      RequestMediaType? type, {
      int page,
      int perPage,
    });
typedef RequestSubmitCallback =
    Future<RequestSubmission> Function(
      RequestSearchResult result, {
      List<int> seasons,
    });
typedef RequestHistoryCallback =
    Future<RequestHistoryPage> Function({
      int page,
      int perPage,
    });
typedef RequestStatusCallback =
    Future<RequestHistoryItem> Function(String requestId);
typedef RequestDismissCallback = Future<void> Function(String requestId);

class RequestController extends ChangeNotifier {
  RequestController(XtreamService service)
    : onSearch = ((term, type, {page = 1, perPage = 20}) => service
          .searchRequests(term, type: type, page: page, perPage: perPage)),
      onSubmit = ((result, {seasons = const <int>[]}) =>
          service.submitRequest(result, seasons: seasons)),
      onLoadHistory = (({page = 1, perPage = 20}) =>
          service.getRequestHistory(page: page, perPage: perPage)),
      onGetStatus = service.getRequestStatus,
      onDismiss = service.dismissRequest;

  RequestController.forTest({
    RequestSearchCallback? onSearch,
    RequestSubmitCallback? onSubmit,
    RequestHistoryCallback? onLoadHistory,
    RequestStatusCallback? onGetStatus,
    RequestDismissCallback? onDismiss,
  }) : onSearch =
           onSearch ??
           ((_, _, {page = 1, perPage = 20}) async => const RequestSearchPage(
             results: [],
             currentPage: 1,
             perPage: 20,
             total: 0,
             lastPage: 1,
           )),
       onSubmit =
           onSubmit ??
           ((result, {seasons = const <int>[]}) async => RequestSubmission(
             status: RequestStatus.pendingApproval,
             request: RequestHistoryItem(
               id: result.key,
               type: result.type,
               externalId: result.externalId,
               title: result.title,
               status: RequestStatus.pendingApproval,
               integrationId: result.integrationId,
               integrationName: result.integrationName,
             ),
             selectedSeasons: seasons,
           )),
       onLoadHistory =
           onLoadHistory ??
           (({page = 1, perPage = 20}) async => const RequestHistoryPage(
             requests: [],
             currentPage: 1,
             perPage: 20,
             total: 0,
             lastPage: 1,
           )),
       onGetStatus =
           onGetStatus ??
           ((id) async => RequestHistoryItem(
             id: id,
             type: RequestMediaType.movie,
             externalId: '',
             title: '',
             status: RequestStatus.unknown,
             integrationId: '',
             integrationName: '',
           )),
       onDismiss = onDismiss ?? ((_) async {});

  RequestSearchCallback onSearch;
  RequestSubmitCallback onSubmit;
  RequestHistoryCallback onLoadHistory;
  RequestStatusCallback onGetStatus;
  RequestDismissCallback onDismiss;

  List<RequestSearchResult> _results = const [];
  RequestSearchPage? _searchPage;
  List<RequestHistoryItem> _history = const [];
  RequestHistoryPage? _historyPage;
  Set<String> _submitting = const {};
  Map<String, RequestStatus> _submitted = const {};
  Set<String> _dismissing = const {};
  bool _isSearching = false;
  bool _isLoadingMore = false;
  bool _isHistoryLoading = false;
  bool _isLoadingMoreHistory = false;
  bool _hasSearched = false;
  RequestValidationError? _validationError;
  String? _searchError;
  String? _historyError;
  String? _currentSearchTerm;
  RequestMediaType? _currentSearchType;
  int _searchGeneration = 0;
  int _historyGeneration = 0;

  List<RequestSearchResult> get results => _results;
  RequestSearchPage? get searchPage => _searchPage;
  List<RequestHistoryItem> get history => _history;
  RequestHistoryPage? get historyPage => _historyPage;
  Set<String> get submitting => _submitting;
  Map<String, RequestStatus> get submitted => _submitted;
  Set<String> get dismissing => _dismissing;
  bool get isSearching => _isSearching;
  bool get isLoadingMore => _isLoadingMore;
  bool get isHistoryLoading => _isHistoryLoading;
  bool get isLoadingMoreHistory => _isLoadingMoreHistory;
  bool get hasSearched => _hasSearched;
  bool get hasMoreSearchPages => _searchPage?.hasMorePages ?? false;
  bool get hasMoreHistoryPages => _historyPage?.hasMorePages ?? false;
  RequestValidationError? get validationError => _validationError;
  String? get searchError => _searchError;
  String? get historyError => _historyError;

  Future<void> search(String term, [RequestMediaType? type]) async {
    final normalized = term.trim();
    if (normalized.length < 2) {
      _validationError = RequestValidationError.tooShort;
      _searchError = null;
      notifyListeners();
      return;
    }
    if (normalized.length > 100) {
      _validationError = RequestValidationError.tooLong;
      _searchError = null;
      notifyListeners();
      return;
    }
    _validationError = null;
    _searchError = null;
    _isSearching = true;
    _hasSearched = true;
    _currentSearchTerm = normalized;
    _currentSearchType = type;
    _searchGeneration++;
    _isLoadingMore = false;
    final generation = _searchGeneration;
    notifyListeners();
    try {
      final page = await onSearch(normalized, type, page: 1, perPage: 20);
      if (generation != _searchGeneration) return;
      _searchPage = page;
      _results = page.results;
    } on Object catch (error) {
      if (generation != _searchGeneration) return;
      _searchPage = null;
      _results = const [];
      _searchError = userFacingXtreamError(error);
    } finally {
      if (generation == _searchGeneration) {
        _isSearching = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreSearchResults() async {
    if (_isLoadingMore || !hasMoreSearchPages || _currentSearchTerm == null) {
      return;
    }
    _isLoadingMore = true;
    _searchError = null;
    final generation = _searchGeneration;
    notifyListeners();
    try {
      final nextPage = _searchPage!.nextPage;
      final page = await onSearch(
        _currentSearchTerm!,
        _currentSearchType,
        page: nextPage,
        perPage: _searchPage!.perPage,
      );
      if (generation != _searchGeneration) return;
      _searchPage = page;
      _results = [..._results, ...page.results];
    } on Object catch (error) {
      if (generation != _searchGeneration) return;
      _searchError = userFacingXtreamError(error);
    } finally {
      if (generation == _searchGeneration) {
        _isLoadingMore = false;
        notifyListeners();
      }
    }
  }

  Future<void> submit(
    RequestSearchResult result, {
    List<int> seasons = const <int>[],
  }) async {
    if (result.alreadyAvailable || _submitting.contains(result.key)) return;
    _submitting = {..._submitting, result.key};
    _searchError = null;
    notifyListeners();
    try {
      final submission = await onSubmit(result, seasons: seasons);
      _submitted = {..._submitted, result.key: submission.status};
      await loadHistory();
    } on Object catch (error) {
      _searchError = userFacingXtreamError(error);
    } finally {
      _submitting = {..._submitting}..remove(result.key);
      notifyListeners();
    }
  }

  Future<void> loadHistory() async {
    _isHistoryLoading = true;
    _historyError = null;
    _historyGeneration++;
    _isLoadingMoreHistory = false;
    final generation = _historyGeneration;
    notifyListeners();
    try {
      final page = await onLoadHistory(page: 1, perPage: 20);
      if (generation != _historyGeneration) return;
      _historyPage = page;
      _history = page.requests;
    } on Object catch (error) {
      if (generation != _historyGeneration) return;
      _historyPage = null;
      _history = const [];
      _historyError = userFacingXtreamError(error);
    } finally {
      if (generation == _historyGeneration) {
        _isHistoryLoading = false;
        notifyListeners();
      }
    }
  }

  Future<void> loadMoreHistory() async {
    if (_isLoadingMoreHistory || !hasMoreHistoryPages) return;
    _isLoadingMoreHistory = true;
    _historyError = null;
    final generation = _historyGeneration;
    notifyListeners();
    try {
      final nextPage = _historyPage!.nextPage;
      final page = await onLoadHistory(
        page: nextPage,
        perPage: _historyPage!.perPage,
      );
      if (generation != _historyGeneration) return;
      _historyPage = page;
      _history = [..._history, ...page.requests];
    } on Object catch (error) {
      if (generation != _historyGeneration) return;
      _historyError = userFacingXtreamError(error);
    } finally {
      if (generation == _historyGeneration) {
        _isLoadingMoreHistory = false;
        notifyListeners();
      }
    }
  }

  Future<void> refreshItem(String requestId) async {
    try {
      final updated = await onGetStatus(requestId);
      _history = [
        for (final item in _history)
          if (item.id == requestId) updated else item,
      ];
      notifyListeners();
    } on Object catch (error) {
      _historyError = userFacingXtreamError(error);
      notifyListeners();
    }
  }

  Future<void> dismiss(String requestId) async {
    if (_dismissing.contains(requestId)) return;
    _dismissing = {..._dismissing, requestId};
    _historyError = null;
    notifyListeners();
    try {
      await onDismiss(requestId);
      _history = _history.where((item) => item.id != requestId).toList();
      if (_historyPage != null) {
        _historyPage = RequestHistoryPage(
          requests: _history,
          currentPage: _historyPage!.currentPage,
          perPage: _historyPage!.perPage,
          total: _historyPage!.total,
          lastPage: _historyPage!.lastPage,
        );
      }
    } on Object catch (error) {
      _historyError = userFacingXtreamError(error);
    } finally {
      _dismissing = {..._dismissing}..remove(requestId);
      notifyListeners();
    }
  }
}
