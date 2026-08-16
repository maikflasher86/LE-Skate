import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Manages sensitive configuration values (e.g. API keys) using the platform's
/// secure storage (Keychain on iOS/macOS, Keystore on Android, DPAPI on
/// Windows, libsecret on Linux).
///
/// A value passed via `--dart-define` (e.g. through `secrets.json` and
/// `--dart-define-from-file`) always takes precedence and is synced into
/// secure storage on every start. This way a new key in `secrets.json` is
/// picked up immediately. If the app is started without `--dart-define`
/// (e.g. a plain `flutter run`), the last synced value from secure storage
/// is used instead, so the key doesn't need to be passed on every launch.
class SecureConfigService {
  SecureConfigService._();

  static const _storage = FlutterSecureStorage();

  static const _llmApiKeyStorageKey = 'llm_api_key';

  /// Compile-time fallback, only used to seed secure storage on first run.
  static const String _defaultLlmApiKey = String.fromEnvironment(
    'LLM_API_KEY',
    defaultValue: '',
  );

  /// Returns the LLM API key. If a compile-time value was passed via
  /// `--dart-define`, it is synced into secure storage (overwriting any
  /// previously stored value) and returned. Otherwise falls back to
  /// whatever is currently stored.
  static Future<String> getLlmApiKey() async {
    if (_defaultLlmApiKey.isNotEmpty) {
      final stored = await _storage.read(key: _llmApiKeyStorageKey);
      if (stored != _defaultLlmApiKey) {
        await _storage.write(
          key: _llmApiKeyStorageKey,
          value: _defaultLlmApiKey,
        );
      }
      return _defaultLlmApiKey;
    }

    return await _storage.read(key: _llmApiKeyStorageKey) ?? '';
  }

  /// Overwrites the stored LLM API key (e.g. from a settings screen).
  static Future<void> setLlmApiKey(String value) async {
    await _storage.write(key: _llmApiKeyStorageKey, value: value);
  }

  /// Removes the stored LLM API key.
  static Future<void> clearLlmApiKey() async {
    await _storage.delete(key: _llmApiKeyStorageKey);
  }
}
