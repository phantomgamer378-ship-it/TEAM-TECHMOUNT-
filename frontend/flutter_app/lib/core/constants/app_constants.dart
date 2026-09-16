/// App-wide constants for VANIRAKSHAK.
class AppConstants {
  AppConstants._();

  static const appName = 'VANIRAKSHAK';
  static const tagline = 'LISTEN • DETECT • VERIFY • PROTECT';
  static const subtitle = 'Bharat Voice Shield';

  // Risk thresholds matching backend policy (§POLICY).
  static const int thresholdGuarded = 30;
  static const int thresholdSuspicious = 50;
  static const int thresholdHigh = 70;
  static const int thresholdCritical = 85;

  // SharedPreferences keys.
  static const prefBaseUrl = 'baseUrl';
  static const prefOnboardingDone = 'onboarding_done';
  static const prefLanguage = 'language';

  // Supported languages.
  static const languages = {
    'hi': 'हिंदी',
    'mr': 'मराठी',
    'en': 'English',
  };
}
