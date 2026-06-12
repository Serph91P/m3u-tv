/// Secure storage abstraction for persisting sensitive data like credentials.
///
/// Production implementations should use platform-specific encrypted storage
/// (e.g., flutter_secure_storage). The in-memory implementation is for tests.
abstract class SecureStorage {
  Future<String?> read(String key);
  Future<void> write(String key, String value);
  Future<void> delete(String key);
}

/// In-memory secure storage for tests. Does NOT log or expose stored values
/// through toString to prevent credential leakage in test output.
class InMemorySecureStorage implements SecureStorage {
  final Map<String, String> _store = {};

  @override
  Future<String?> read(String key) async => _store[key];

  @override
  Future<void> write(String key, String value) async {
    _store[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _store.remove(key);
  }

  @override
  String toString() => 'InMemorySecureStorage(${_store.length} keys)';
}