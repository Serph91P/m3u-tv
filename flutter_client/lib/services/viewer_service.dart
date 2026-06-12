import 'domain_models.dart';

class ViewerService {
  ViewerService({Map<String, Object?>? memory}) : _memory = memory ?? <String, Object?>{};

  static const _activeViewerKey = 'm3ue_tv_active_viewer';

  final Map<String, Object?> _memory;

  Future<Viewer?> resolveActiveViewer(List<Viewer> viewers) async {
    if (viewers.isEmpty) return null;
    final savedUlid = _memory[_activeViewerKey] as String?;
    final saved = savedUlid == null ? null : viewers.where((viewer) => viewer.ulid == savedUlid).firstOrNull;
    final active = saved ?? viewers.where((viewer) => viewer.isAdmin).firstOrNull ?? viewers.first;
    _memory[_activeViewerKey] = active.ulid;
    return active;
  }

  Future<void> setActiveViewer(Viewer viewer) async {
    _memory[_activeViewerKey] = viewer.ulid;
  }
}

extension _FirstOrNull<T> on Iterable<T> {
  T? get firstOrNull => isEmpty ? null : first;
}
