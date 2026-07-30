class AppConfig {
  static const String appName = 'Workforce Tracker';
  static const String appVersion = '1.0.0';

  // Environment Flags & Configuration
  static bool isOfflineDemoMode = true; // Switch to false when using live Supabase/Firebase backend keys
  
  static const String supabaseUrl = String.fromEnvironment('SUPABASE_URL', defaultValue: 'https://xyzcompany.supabase.co');
  static const String supabaseAnonKey = String.fromEnvironment('SUPABASE_ANON_KEY', defaultValue: 'ey...mock');
  
  static const String firebaseApiKey = String.fromEnvironment('FIREBASE_API_KEY', defaultValue: 'AIza...mock');

  static const double defaultGeofenceRadiusMeters = 200.0;
}
