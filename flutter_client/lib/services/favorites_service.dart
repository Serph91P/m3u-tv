class FavoritesService {
  FavoritesService({Map<String, Object?>? memory}) : _memory = memory ?? <String, Object?>{};

  static const _favoritesKey = 'm3ue_favorites';
  static const _lastCategoryKey = 'm3ue_last_category';

  final Map<String, Object?> _memory;

  Future<bool> add(int streamId) async {
    final ids = await all();
    ids.add(streamId);
    _memory[_favoritesKey] = ids.toList()..sort();
    return true;
  }

  Future<bool> remove(int streamId) async {
    final ids = await all();
    ids.remove(streamId);
    _memory[_favoritesKey] = ids.toList()..sort();
    return false;
  }

  Future<bool> toggle(int streamId) async => await isFavorite(streamId) ? remove(streamId) : add(streamId);

  Future<bool> isFavorite(int streamId) async => (await all()).contains(streamId);

  Future<Set<int>> all() async {
    final raw = _memory[_favoritesKey];
    if (raw is Iterable) return raw.map((value) => int.parse('$value')).toSet();
    return <int>{};
  }

  Future<void> setLastCategory(String? categoryId) async {
    _memory[_lastCategoryKey] = categoryId;
  }

  Future<String?> getLastCategory() async => _memory[_lastCategoryKey] as String?;
}
