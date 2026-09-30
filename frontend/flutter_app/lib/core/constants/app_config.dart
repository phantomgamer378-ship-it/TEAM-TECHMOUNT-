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
        // Local Mac IP address so physical phones on WiFi can connect
        return 'http://192.168.20.151:8000';
    }
  }
}
