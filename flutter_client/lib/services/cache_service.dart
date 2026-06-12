class CacheEntry<T> {
  const CacheEntry({required this.data, required this.isStale});

  final T data;
  final bool isStale;
}

class CacheService {
  CacheService({Map<String, Object?>? memory, this.refreshInterval = const Duration(hours: 1)}) : _memory = memory ?? <String, Object?>{};

  final Map<String, Object?> _memory;
  final Duration refreshInterval;

  Future<void> set<T>(String key, T data) async {
    _memory['m3ue_cache_$key'] = _StampedValue<T>(data, DateTime.now());
  }

  Future<CacheEntry<T>?> get<T>(String key) async {
    final value = _memory['m3ue_cache_$key'];
    if (value is! _StampedValue) return null;
    return CacheEntry<T>(
      data: value.data as T,
      isStale: DateTime.now().difference(value.timestamp) > refreshInterval,
    );
  }

  Future<void> clear() async {
    _memory.removeWhere((key, _) => key.startsWith('m3ue_cache_'));
  }
}

class _StampedValue<T> {
  const _StampedValue(this.data, this.timestamp);

  final T data;
  final DateTime timestamp;
}
