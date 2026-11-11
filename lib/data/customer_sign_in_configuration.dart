/// A staging provider must be explicitly enabled after its server configuration.
/// Legacy operational builds retain their existing methods; no provider is enabled remotely.
class CustomerSignInConfiguration {
  static bool enabled(
    String provider, {
    String environment = const String.fromEnvironment('CHAMAE_ENV'),
    bool google = const bool.fromEnvironment('CHAMAE_AUTH_GOOGLE_ENABLED'),
    bool apple = const bool.fromEnvironment('CHAMAE_AUTH_APPLE_ENABLED'),
  }) =>
      environment != 'STAGING' || (provider == 'google' ? google : apple);
}
