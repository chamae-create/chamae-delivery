/// Public configuration for the explicitly selected, isolated staging project.
class CustomerStagingConfiguration {
  final String projectId, apiKey, appId, senderId, storageBucket, authDomain;
  const CustomerStagingConfiguration(
      {required this.projectId,
      required this.apiKey,
      required this.appId,
      required this.senderId,
      required this.storageBucket,
      required this.authDomain});

  factory CustomerStagingConfiguration.fromEnvironment() {
    if (const String.fromEnvironment('CHAMAE_ENV') != 'STAGING') {
      throw StateError('CHAMAE_STAGING_ENV_REQUIRED');
    }
    const config = CustomerStagingConfiguration(
        projectId: String.fromEnvironment('CHAMAE_FIREBASE_PROJECT_ID'),
        apiKey: String.fromEnvironment('CHAMAE_FIREBASE_API_KEY'),
        appId: String.fromEnvironment('CHAMAE_FIREBASE_APP_ID'),
        senderId: String.fromEnvironment('CHAMAE_FIREBASE_MESSAGING_SENDER_ID'),
        storageBucket: String.fromEnvironment('CHAMAE_FIREBASE_STORAGE_BUCKET'),
        authDomain: String.fromEnvironment('CHAMAE_FIREBASE_AUTH_DOMAIN'));
    config.validate();
    return config;
  }

  void validate() {
    if (!RegExp(r'^[a-z][a-z0-9-]{4,28}[a-z0-9]$').hasMatch(projectId) ||
        projectId == 'chamae-delivery' ||
        projectId.startsWith('demo-')) {
      throw StateError('CHAMAE_STAGING_PROJECT_INVALID');
    }
    if (apiKey.trim().isEmpty ||
        senderId == '302882774102' ||
        !RegExp(r'^\d+$').hasMatch(senderId) ||
        !RegExp('^1:$senderId:(web|android|ios):[a-fA-F0-9]+\$')
            .hasMatch(appId) ||
        !['$projectId.appspot.com', '$projectId.firebasestorage.app']
            .contains(storageBucket) ||
        authDomain != '$projectId.firebaseapp.com') {
      throw StateError('CHAMAE_STAGING_CONFIGURATION_INVALID');
    }
  }

  void checkExistingProject(String existingProject) {
    validate();
    if (existingProject != projectId) {
      throw StateError('CHAMAE_STAGING_EXISTING_APP_MISMATCH');
    }
  }
}
