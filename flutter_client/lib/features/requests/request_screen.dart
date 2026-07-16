import 'dart:async';

import 'package:dpad/dpad.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:m3u_tv/features/requests/request_controller.dart';
import 'package:m3u_tv/l10n/app_localizations.dart';
import 'package:m3u_tv/providers/app_providers.dart';
import 'package:m3u_tv/services/request_models.dart';
import 'package:m3u_tv/shared/dpad_ink_well.dart';
import 'package:m3u_tv/shared/media_browsing_widgets.dart';

class RequestScreen extends ConsumerStatefulWidget {
  const RequestScreen({
    super.key,
    required this.onSearch,
    required this.onSubmit,
    required this.onLoadHistory,
    required this.onRefreshItem,
    required this.onDismiss,
    this.onSidebarActivate,
  });

  final Future<void> Function(String term, [RequestMediaType? type]) onSearch;
  final Future<void> Function(RequestSearchResult result) onSubmit;
  final Future<void> Function() onLoadHistory;
  final Future<void> Function(String requestId) onRefreshItem;
  final Future<void> Function(String requestId) onDismiss;
  final VoidCallback? onSidebarActivate;

  @override
  ConsumerState<RequestScreen> createState() => _RequestScreenState();
}

class _RequestScreenState extends ConsumerState<RequestScreen> {
  final _searchController = TextEditingController();
  RequestMediaType? _type;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) unawaited(widget.onLoadHistory());
    });
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _search() => unawaited(widget.onSearch(_searchController.text, _type));

  @override
  Widget build(BuildContext context) {
    final configured = ref.watch(isConfiguredProvider);
    final state = ref.watch(requestControllerProvider);
    final l = AppLocalizations.of(context);
    if (!configured) {
      return Scaffold(
        appBar: AppBar(title: Text(l.requestsTitle)),
        body: Center(
          child: Text(
            l.appNotConfigured,
            style: Theme.of(context).textTheme.titleMedium,
          ),
        ),
      );
    }

    return Scaffold(
      body: DpadRegion(
        memoryKey: 'requests/workflow',
        horizontalEdge: DpadEdgeBehavior.stop,
        onEdge: (direction) {
          if (direction == TraversalDirection.left) {
            widget.onSidebarActivate?.call();
          }
        },
        child: Padding(
          padding: const EdgeInsets.all(MediaBrowsingMetrics.pagePadding),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                l.requestsTitle,
                style: Theme.of(context).textTheme.headlineMedium,
              ),
              const SizedBox(height: 4),
              Text(
                l.requestsSubtitle,
                style: Theme.of(context).textTheme.bodyMedium,
              ),
              const SizedBox(height: 16),
              _SearchBar(
                controller: _searchController,
                selectedType: _type,
                isSearching: state.isSearching,
                onTypeChanged: (type) => setState(() => _type = type),
                onSearch: _search,
              ),
              if (state.validationError != null || state.searchError != null)
                Padding(
                  padding: const EdgeInsets.only(top: 8),
                  child: Text(
                    state.searchError ??
                        switch (state.validationError!) {
                          RequestValidationError.tooShort =>
                            l.requestsValidationTooShort,
                          RequestValidationError.tooLong =>
                            l.requestsValidationTooLong,
                        },
                    style: TextStyle(
                      color: Theme.of(context).colorScheme.error,
                    ),
                  ),
                ),
              const SizedBox(height: 16),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final results = _SearchResults(
                      state: state,
                      onSubmit: widget.onSubmit,
                    );
                    final history = _RequestHistory(
                      state: state,
                      onRefreshItem: widget.onRefreshItem,
                      onDismiss: widget.onDismiss,
                    );
                    if (constraints.maxWidth < 720) {
                      return Column(
                        children: [
                          Expanded(child: results),
                          const Divider(height: 24),
                          SizedBox(height: 180, child: history),
                        ],
                      );
                    }
                    return Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Expanded(flex: 2, child: results),
                        const VerticalDivider(width: 32),
                        Expanded(child: history),
                      ],
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({
    required this.controller,
    required this.selectedType,
    required this.isSearching,
    required this.onTypeChanged,
    required this.onSearch,
  });

  final TextEditingController controller;
  final RequestMediaType? selectedType;
  final bool isSearching;
  final ValueChanged<RequestMediaType?> onTypeChanged;
  final VoidCallback onSearch;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                autofocus: true,
                decoration: InputDecoration(
                  hintText: l.requestsSearchHint,
                  prefixIcon: const Icon(Icons.search),
                  border: const OutlineInputBorder(),
                ),
                textInputAction: TextInputAction.search,
                onSubmitted: (_) => onSearch(),
              ),
            ),
            const SizedBox(width: 12),
            DpadFocusable(
              onSelect: isSearching ? null : onSearch,
              child: FilledButton.icon(
                onPressed: isSearching ? null : onSearch,
                icon: isSearching
                    ? const SizedBox.square(
                        dimension: 16,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.search),
                label: Text(l.requestsSearchAction),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          children: [
            _TypeButton(
              label: l.requestsTypeAll,
              selected: selectedType == null,
              onPressed: () => onTypeChanged(null),
            ),
            _TypeButton(
              label: l.requestsTypeMovies,
              selected: selectedType == RequestMediaType.movie,
              onPressed: () => onTypeChanged(RequestMediaType.movie),
            ),
            _TypeButton(
              label: l.requestsTypeSeries,
              selected: selectedType == RequestMediaType.series,
              onPressed: () => onTypeChanged(RequestMediaType.series),
            ),
          ],
        ),
      ],
    );
  }
}

class _TypeButton extends StatelessWidget {
  const _TypeButton({
    required this.label,
    required this.selected,
    required this.onPressed,
  });

  final String label;
  final bool selected;
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) {
    return DpadFocusable(
      onSelect: onPressed,
      child: selected
          ? FilledButton(onPressed: onPressed, child: Text(label))
          : FilledButton.tonal(onPressed: onPressed, child: Text(label)),
    );
  }
}

class _SearchResults extends StatelessWidget {
  const _SearchResults({required this.state, required this.onSubmit});

  final RequestController state;
  final Future<void> Function(RequestSearchResult result) onSubmit;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    if (state.isSearching && state.results.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }
    if (!state.hasSearched) {
      return Center(child: Text(l.requestsSearchPrompt));
    }
    if (state.results.isEmpty) {
      return Center(child: Text(l.requestsNoResults));
    }
    return ListView.separated(
      itemCount: state.results.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final result = state.results[index];
        final submitting = state.submitting.contains(result.key);
        final submitted = state.submitted[result.key];
        return DpadInkWell(
          autofocus: index == 0,
          borderRadius: BorderRadius.circular(8),
          color: Theme.of(context).colorScheme.surfaceContainerHigh,
          onTap: result.alreadyAvailable || submitted != null || submitting
              ? null
              : () => unawaited(onSubmit(result)),
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Row(
              children: [
                Icon(
                  result.type == RequestMediaType.movie
                      ? Icons.movie_outlined
                      : Icons.tv_outlined,
                  size: 36,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        result.title,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      if (result.year != null ||
                          result.integrationName.isNotEmpty)
                        Text(
                          [
                            if (result.year != null) '${result.year}',
                            if (result.integrationName.isNotEmpty)
                              result.integrationName,
                          ].join('  '),
                          style: Theme.of(context).textTheme.bodySmall,
                        ),
                      if (result.overview != null) ...[
                        const SizedBox(height: 4),
                        Text(
                          result.overview!,
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ],
                  ),
                ),
                const SizedBox(width: 12),
                if (submitting)
                  const SizedBox.square(
                    dimension: 22,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                else
                  Text(
                    result.alreadyAvailable
                        ? l.requestsAlreadyAvailable
                        : submitted == null
                        ? (result.type == RequestMediaType.movie
                              ? l.requestsRequestMovie
                              : l.requestsRequestSeries)
                        : _statusLabel(l, submitted),
                    style: Theme.of(context).textTheme.labelLarge,
                  ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _RequestHistory extends StatelessWidget {
  const _RequestHistory({
    required this.state,
    required this.onRefreshItem,
    required this.onDismiss,
  });

  final RequestController state;
  final Future<void> Function(String requestId) onRefreshItem;
  final Future<void> Function(String requestId) onDismiss;

  @override
  Widget build(BuildContext context) {
    final l = AppLocalizations.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                l.requestsHistoryTitle,
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ),
            if (state.history.isNotEmpty)
              DpadFocusable(
                child: IconButton(
                  icon: const Icon(Icons.refresh),
                  onPressed: state.isHistoryLoading
                      ? null
                      : () {
                          for (final item in state.history) {
                            unawaited(onRefreshItem(item.id));
                          }
                        },
                ),
              ),
          ],
        ),
        const SizedBox(height: 8),
        if (state.isHistoryLoading && state.history.isEmpty)
          const Expanded(child: Center(child: CircularProgressIndicator()))
        else if (state.historyError != null)
          Expanded(
            child: Center(
              child: Text(
                state.historyError!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ),
          )
        else if (state.history.isEmpty)
          Expanded(child: Center(child: Text(l.requestsHistoryEmpty)))
        else
          Expanded(
            child: ListView.separated(
              itemCount: state.history.length,
              separatorBuilder: (_, _) => const Divider(),
              itemBuilder: (context, index) {
                final item = state.history[index];
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: Icon(
                    item.type == RequestMediaType.movie
                        ? Icons.movie_outlined
                        : Icons.tv_outlined,
                  ),
                  title: Text(item.title),
                  subtitle: Text(item.integrationName),
                  trailing: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(_statusLabel(l, item.status)),
                      if (item.canDismiss &&
                          !state.dismissing.contains(item.id)) ...[
                        const SizedBox(width: 8),
                        DpadFocusable(
                          child: IconButton(
                            icon: const Icon(Icons.close, size: 20),
                            onPressed: () => unawaited(onDismiss(item.id)),
                          ),
                        ),
                      ],
                      if (state.dismissing.contains(item.id))
                        const Padding(
                          padding: EdgeInsets.only(left: 8),
                          child: SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(strokeWidth: 2),
                          ),
                        ),
                    ],
                  ),
                );
              },
            ),
          ),
      ],
    );
  }
}

String _statusLabel(AppLocalizations l, RequestStatus status) =>
    switch (status) {
      RequestStatus.pendingApproval => l.requestsStatusPendingApproval,
      RequestStatus.approved => l.requestsStatusApproved,
      RequestStatus.importing => l.requestsStatusImporting,
      RequestStatus.completed => l.requestsStatusCompleted,
      RequestStatus.rejected => l.requestsStatusRejected,
      RequestStatus.unknown => l.requestsStatusUnknown,
    };
