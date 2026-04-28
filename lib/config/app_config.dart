class AppConfig {
  static const serverUrl = String.fromEnvironment(
    'ECHO_SERVER_URL',
    defaultValue: 'http://103.76.55.70:8080',
  );
}
