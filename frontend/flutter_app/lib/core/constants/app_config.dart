enum Environment {
  dev,
  staging,
  production,
}

class AppConfig {
  static const Environment currentEnvironment = Environment.dev;

  static String get apiBaseUrl {
    switch (currentEnvironment) {
      case Environment.production:
        return 'https://vanirakshak-backend-docker.onrender.com';
      case Environment.staging:
        return 'https://vanirakshak-backend-docker.onrender.com';
      case Environment.dev:
        // Local Mac IP address (192.168.20.165) so emulators and physical devices on WiFi connect
        return 'http://192.168.20.165:8000';
    }
  }
}
