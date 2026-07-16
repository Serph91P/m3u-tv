import 'package:flutter/foundation.dart';
import 'package:m3u_tv/services/request_models.dart';
import 'package:m3u_tv/services/xtream_service.dart';

enum RequestValidationError { tooShort, tooLong }

typedef RequestSearchCallback =
    Future<List<RequestSearchResult>> Function(
      String term,
      RequestMediaType? type,
    );
typedef RequestSubmitCallback =
    Future<RequestSubmission> Function(RequestSearchResult result);
typedef RequestHistoryCallback = Future<List<RequestHistoryItem>> Function();
typedef RequestStatusCallback =
    Future<RequestHistoryItem> Function(String requestId);
typedef RequestDismissCallback = Future<void> Function(String requestId);

class RequestController extends ChangeNotifier {
  RequestController(XtreamService service)
    : onSearch = ((term, type) => service.searchRequests(term, type: type)),
      onSubmit = service.submitRequest,
      onLoadHistory = service.getRequestHistory,
      onGetStatus = service.getRequestStatus,
      onDismiss = service.dismissRequest;

  RequestController.forTest({
    RequestSearchCallback? onSearch,
    RequestSubmitCallback? onSubmit,
    RequestHistoryCallback? onLoadHistory,
    RequestStatusCallback? onGetStatus,
    RequestDismissCallback? onDismiss,
  }) : onSearch = onSearch ?? ((_, _) async => const []),
       onSubmit =
           onSubmit ??
           ((result) async => RequestSubmission(
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
           )),
       onLoadHistory = onLoadHistory ?? (() async => const []),
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
  List<RequestHistoryItem> _history = const [];
  Set<String> _submitting = const {};
  Map<String, RequestStatus> _submitted = const {};
  Set<String> _dismissing = const {};
  bool _isSearching = false;
  bool _isHistoryLoading = false;
  bool _hasSearched = false;
  RequestValidationError? _validationError;
  String? _searchError;
  String? _historyError;

  List<RequestSearchResult> get results => _results;
  List<RequestHistoryItem> get history => _history;
  Set<String> get submitting => _submitting;
  Map<String, RequestStatus> get submitted => _submitted;
  Set<String> get dismissing => _dismissing;
  bool get isSearching => _isSearching;
  bool get isHistoryLoading => _isHistoryLoading;
  bool get hasSearched => _hasSearched;
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
    notifyListeners();
    try {
      _results = await onSearch(normalized, type);
    } on Object catch (error) {
      _results = const [];
      _searchError = userFacingXtreamError(error);
    } finally {
      _isSearching = false;
      notifyListeners();
    }
  }

  Future<void> submit(RequestSearchResult result) async {
    if (result.alreadyAvailable || _submitting.contains(result.key)) return;
    _submitting = {..._submitting, result.key};
    _searchError = null;
    notifyListeners();
    try {
      final submission = await onSubmit(result);
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
    notifyListeners();
    try {
      _history = await onLoadHistory();
    } on Object catch (error) {
      _historyError = userFacingXtreamError(error);
    } finally {
      _isHistoryLoading = false;
      notifyListeners();
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
    } on Object catch (error) {
      _historyError = userFacingXtreamError(error);
    } finally {
      _dismissing = {..._dismissing}..remove(requestId);
      notifyListeners();
    }
  }
}
