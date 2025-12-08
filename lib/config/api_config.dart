import 'package:flutter/foundation.dart';

/// Configuration centralisée des clés API pour l'application Deliver
class ApiConfig {
  // Configuration Supabase
  static const String supabaseUrl = "https://fuvgfvonpivubkrvnsdt.supabase.co";
  static const String supabaseAnonKey =
      'eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6ImZ1dmdmdm9ucGl2dWJrcnZuc2R0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjI2OTM0MDUsImV4cCI6MjA3ODI2OTQwNX0.32onFnZ4vMQxkdh_oUS1oHsGUFX4SXhrb_388qnuS58';

  // Configuration Google Maps
  static const String googleMapsApiKey =
      'AIzaSyCtSGHbgwiNKhblSK7NpU7aVUvuxz-w-tM';

  // Configuration Agora
  static const String agoraAppId = 'YOUR_AGORA_APP_ID';

  // Configuration PayDunya
  static const String payDunyaMasterKey = 'YOUR_PAYDUNYA_MASTER_KEY';
  static const String payDunyaPrivateKey = 'YOUR_PAYDUNYA_PRIVATE_KEY';
  static const String payDunyaToken = 'YOUR_PAYDUNYA_TOKEN';

  // Configuration de l'environnement
  static const String environment = 'development';
  static const bool debugMode = kDebugMode;

  /// Vérifie si toutes les clés API sont configurées
  static bool get isFullyConfigured {
    return supabaseUrl.isNotEmpty &&
        supabaseAnonKey.isNotEmpty &&
        googleMapsApiKey != 'YOUR_GOOGLE_MAPS_API_KEY' &&
        googleMapsApiKey.isNotEmpty &&
        agoraAppId != 'YOUR_AGORA_APP_ID' &&
        payDunyaMasterKey != 'YOUR_PAYDUNYA_MASTER_KEY';
  }
}
